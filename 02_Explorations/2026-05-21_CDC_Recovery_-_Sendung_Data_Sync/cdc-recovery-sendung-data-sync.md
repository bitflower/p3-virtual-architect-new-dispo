# CDC Recovery - Sendung Data Sync

**Date:** 2026-05-21
**Status:** Accepted (Refinement 2026-05-22) — PBIs being created
**PoC Branch:** `feature/data-sync-poll-mechanism` (Disposition-Backend)
**PoC Author:** Yosif Mihaylov

---

## Problem Statement

When the CDC pipeline fails or has an extended outage, shipment (Sendung) data in New Dispo becomes stale. There is currently no mechanism to recover missed changes. Data loss can occur at multiple points along the CDC pipeline, for example:
- **WAL replication slot timeout:** Some branches have a 1-hour retention window; outages longer than that cause permanent data gaps
- **Network outages** between TMS and GCP
- **GCP Datastream failures**
- **Striim failures**
- **Pub/Sub, Cloud Function, or Backend processing disruptions**

This affects all branches simultaneously and leaves dispatchers working with outdated data without knowing it.

**Scope:** Recovery of the `sendung` table - the single CDC-synced entity between TMS and New Dispo.

**Decision rationale:** See [ADR-010](../../09_ADRs/ADR-010-cdc-recovery-sendung-data-sync/ADR-010-cdc-recovery-sendung-data-sync.md) for the evaluation of recovery strategies considered and why this approach was chosen.

---

## Solution Overview

A Backend-internal data sync mechanism that queries TMS for current shipment state and reconciles it against local state in New Dispo. It reuses the existing CDC resolver pipeline, meaning the recovery path exercises the exact same business logic as the live CDC path.

**Key properties:**
- Backend-only - no changes required to TMS Bridge or Frontend
- Full reuse of existing CDC business logic (resolvers)
- No new business logic required
- Operates on the `sendung` table via the TMS Bridge, same data source as CDC
- Watermark-based: recovers from a known-good timestamp, not full-state comparison
- TMS Bridge GraphQL already supports `updateTime` filtering — the HWM query capability exists, no TMS Bridge changes needed

**Key invariant (confirmed by Joachim Schreiner and Patrick Uschmann [PO], 2026-05-21):** Dispatched/planned shipments are never deleted in TMS. This is being enforced on the TMS side (Joachim/Reinhard). This means delete detection during recovery only needs to check **unplanned** legs — reducing the scope from hundreds of thousands to hundreds or thousands of shipment IDs per branch.

---

## Data Flow

```
                                        Recovery Trigger
                                        (manual endpoint call)
                                               |
                                               v
+----------+    SQL     +------------+  GraphQL  +-------------------+  EF Core   +----------+
|          | <--------- |            | <-------- |                   | ---------> |          |
|   TMS    |            | TMS Bridge |           |   New Dispo       | Read legs  | CloudSQL |
| Database | ---------> |            | --------> |   Backend         | Write chgs |          |
|          |   Results  |  (read-    |  Shipment |                   | <--------- |          |
+----------+            |   only)    |  DTOs     | DataSyncExecutor  |            +----------+
                        +------------+           |                   |
                                                 +-------------------+
                                                        |
                                                  CDC Resolvers
                                                  (insert/update/delete)
```

**Direction:** The recovery mechanism pulls data from TMS (via TMS Bridge) and pushes changes to CloudSQL. This is the reverse of CDC's push model (TMS pushes changes via Datastream/Pub/Sub), but both paths converge at the same resolver logic.

---

## Detailed Architecture

### Entry Point: `DataSyncExecutor`

**Location:** `Application/Features/DataSync/Services/DataSyncExecutor/DataSyncExecutor.cs`

The executor orchestrates the full recovery cycle. It has a single method `Execute()` which performs a complete reconciliation across all configured branches.

**Dependencies (injected):**

| Dependency | Role |
|------------|------|
| `IPickupPlanningShipmentProvider` | Fetches shipments from TMS via TMS Bridge (GraphQL) |
| `ITmsBranchKeysProvider` | Provides the list of branch keys from app settings |
| `AppDbContext` | Entity Framework context for reading/writing local CloudSQL |
| `IEnumerable<IShipmentUpdatedEventResolver>` | Collection of update resolvers (traffic mode changes, flat field updates, etc.) |
| `INewShipmentCreatedResolver` | Handles new shipment creation (leg extraction, lot assignment) |
| `IDeletedShipmentResolver` | Handles shipment deletion (leg removal, lot/assignment cleanup) |

### Algorithm Step by Step

#### Step 1: Load branch keys

```csharp
IEnumerable<string> allBranchKeys = tmsBranchKeysProvider.Get();
```

Branch keys come from app settings configuration. Each key identifies a TMS branch (Niederlassung). The recovery runs across all configured branches.

#### Step 2: Fetch all shipments from TMS (per branch, in parallel)

```csharp
PickupPlanningBranchShipmentsResponseDto?[] results =
    await Task.WhenAll(branchKeys.Select(key => Task.Run(async () => {
        return new PickupPlanningBranchShipmentsResponseDto {
            Shipments = await shipmentProvider.GetAllUnplanned(key),
            BranchKey = key
        };
    })));
```

For each branch, calls `IPickupPlanningShipmentProvider.GetAllUnplanned(branchKey)` which queries the TMS Bridge via GraphQL. This returns all current (unplanned) shipments for that branch as `PickupPlanningShipmentDto` objects.

**Error handling per branch:** If a branch request fails, it returns `null` and is filtered out. Other branches proceed. This prevents one branch failure from blocking the entire recovery.

**Data source:** The provider queries the TMS Bridge, which reads from the `sendung` table (or `v_shipment_all` view - see Performance section for why direct table access is preferred).

#### Step 3: Load existing local state (legs from CloudSQL)

```csharp
Dictionary<string, Dictionary<long, IEnumerable<LegEntity>>> branchShipmentLegsMap =
    await GetBranchShipmentLegsMap(branchShipments);
```

Loads all legs from CloudSQL whose `ShipmentId` matches any of the shipments retrieved from TMS. Groups them into a nested dictionary: `branch key -> shipment ID -> legs`.

**Design note:** The leg query filters by shipment IDs without branch correlation. This slightly over-fetches in edge cases where different branches share shipment IDs, but is correct because the branch key is checked during resolution.

#### Step 4: Classify and resolve changes

For each branch, for each shipment from TMS:

**Case A - UPDATE:** Local legs exist for this shipment ID in this branch.

```csharp
if (branchShipmentLegsMap.TryGetValue(branch, out var shipmentLegsMap)
    && shipmentLegsMap.TryGetValue(shipment.ShipmentId, out var shipmentLegs))
{
    var oldRecord = shipmentLegs.First().ToGoogleBucketShipmentData();
    var supportedResolvers = shipmentUpdatedResolvers
        .Where(x => x.Supports(oldRecord, shipment));
    foreach (var resolver in supportedResolvers)
        await resolver.Resolve(shipment, shipmentLegs, branchKey);
}
```

**Case B - INSERT:** No local legs exist for this shipment ID.

```csharp
else
{
    await newShipmentCreatedResolver.Resolve(shipment, branchKey);
}
```

**Case C - DELETE:** After processing all TMS shipments, scan local legs for shipment IDs that are NOT in the TMS response.

```csharp
foreach (var shipmentId in branchShipmentLegsMap[branchKey].Keys)
{
    if (!branchShipmentIds.Contains(shipmentId))
        await deletedShipmentResolver.Resolve(shipmentId, branchKey);
}
```

---

## Change Type Handling in Detail

### INSERT - New Shipment

**Trigger:** A shipment exists in TMS but has no corresponding legs in CloudSQL.

**What happens (via `NewShipmentCreatedResolver`):**
1. Select the appropriate `IShipmentLegExtractor` based on traffic mode (Direct, ClosestBranchConsignor, etc.)
2. Extract legs from the shipment DTO (1-2 legs depending on traffic mode)
3. For each extracted leg:
   - Assign a new `LegId` (GUID)
   - Find or create a suitable lot via `IPickupPlanningSuitableLotForLegProvider`
   - Add leg to lot, add leg to DB context
4. Persist new lots (if created) and recalculate lot aggregates for existing lots
5. `SaveChangesAsync()`

**Domain impact:** Creates legs, potentially creates lots, recalculates lot aggregates (weight, pallet spaces, unique clients count).

### UPDATE - Shipment Changed

**Trigger:** A shipment exists in TMS AND has corresponding legs in CloudSQL. At least one resolver's `Supports()` method returns true for the old/new comparison.

**How "old" state is derived:**

Since New Dispo doesn't store shipments directly, the old shipment state must be reconstructed from the existing `LegEntity`. The `DataSyncExecutorMapper.ToGoogleBucketShipmentData()` converts a leg back to the DTO format:

```csharp
public static GoogleBucketShipmentData ToGoogleBucketShipmentData(this LegEntity src) =>
    new() {
        ShipmentId = src.ShipmentId,
        Weight = src.Weight,
        FloorPalletSpaces = src.FloorPalletSpaces,
        VolumePalletSpaces = src.VolumePalletSpaces,
        TransportMode = src.TransportMode ?? 0,
        ModeOfTraffic = GetModeOfTraffic(src.TrafficFlow),
        // ... all shipment-level fields mapped from leg
    };
```

**Why this works:** Shipment-level fields (weight, volume, pallet spaces, traffic mode, addresses) are identical across all legs of a shipment. When a shipment changes, all its legs are updated atomically. So any leg accurately represents the "old" shipment state.

**Critical assumption (confirmed refinement 2026-05-22):** This derivation depends on leg-inherited fields never diverging per-leg. If future features introduce per-leg field changes (e.g., weight splitting across VL sub-legs), the derivation strategy must be updated (e.g., aggregate leg weights to reconstruct shipment weight). Maximilian confirmed that future leg splitting is planned but agreed this is a known future concern, not a Go-Live blocker.

**Resolver pipeline:**

Each `IShipmentUpdatedEventResolver` has:
- `Supports(oldRecord, newRecord)` - checks if this specific change is relevant (e.g., traffic mode changed from 30 to 34)
- `Resolve(shipmentInfo, shipmentLegs, branchKey)` - applies the business logic

There are 12 traffic mode resolvers (4 traffic modes x 3 transitions each) plus flat field resolvers and lot generation field resolvers. Each handles a specific transition:

| Resolver Group | What it handles |
|----------------|----------------|
| `TrafficMode1/` (ClosestBranchConsignor) | 3 resolvers: from mode 2, 3, or 4 to mode 1 |
| `TrafficMode2/` (BranchToBranch) | 3 resolvers: from mode 1, 3, or 4 to mode 2 |
| `TrafficMode3/` (ClosestBranchConsignee) | 3 resolvers: from mode 1, 2, or 4 to mode 3 |
| `TrafficMode4/` (Direct) | 3 resolvers: from mode 1, 2, or 3 to mode 4 |
| `FlatFieldsResolvers/` | Field-level updates (weight, addresses, dates, etc.) |
| `LotGenerationFieldsResolver/` | Fields that affect lot grouping |

**Domain impact:** May remove old legs, create new legs with different traffic flow, move legs between lots, recalculate lot aggregates, clean up empty lots and orphaned lot assignments.

### DELETE - Shipment Removed

**Trigger:** A local leg's parent shipment no longer exists in TMS. Only **unplanned** legs need to be checked — dispatched/planned shipments are never deleted in TMS (confirmed by Joachim Schreiner and Patrick Uschmann [PO], 2026-05-21).

**How delete detection works (separate from HWM query):**
1. Collect all **unplanned** local leg shipment IDs for the branch
2. Query TMS for which of these shipment IDs still exist
3. Any shipment ID that no longer exists in TMS → trigger delete resolver

This is a set comparison scoped to unplanned legs only, not a full-state reconciliation. The volume is dramatically smaller: hundreds or thousands of shipments vs. hundreds of thousands if all legs were checked.

**Alternative approach (from Yosif's PoC writeup):** Two queries per branch — an ID-only query (all unplanned shipment IDs, no time filter, cheap) for delete detection, plus a time-filtered change query for inserts/updates. This does not leverage the dispatched-shipments-never-deleted invariant but avoids the dependency on constraint #6. Could serve as a fallback if the constraint proves unreliable.

**What happens (via `DeletedShipmentResolver`):**
1. Load all legs for the shipment ID + branch key
2. Collect all lots associated with these legs
3. Remove leg-lot relationships
4. Remove legs from DB
5. Remove associated `LotAssignmentLegLink` entries
6. Remove lots that became empty (no remaining legs)
7. Remove lot assignments that became empty (no remaining leg links)
8. `SaveChangesAsync()`

**Domain impact:** Removes legs, cleans up orphaned lots and lot assignments. This is the same cleanup logic used by the Flow 7 recovery endpoint concept (see [ticket-draft-recovery-endpoint.md](../2026-05-18_Transactional_Sync_Error_UX_Analysis/ticket-draft-recovery-endpoint.md)).

---

## Performance

| Operation | Duration | Shipment count | Notes |
|-----------|----------|----------------|-------|
| Incremental query (15s window) | ~0.5s | ~50-100 records | Yosif's verbal estimate from separate analysis — **not implemented in PoC** |
| `v_shipment_all` view (all shipments, 1 branch) | ~5-6s | ~3,000 | View overhead - joins/translations slow it down |
| Shipment IDs only from view | ~1.5s | ~3,000 | Fewer columns helps |
| Full branch sync (all shipments + resolution) | ~20-25s | ~3,000 | PoC measurement, single branch |
| Full sync across all branches | ~40-50s | ~3,000/branch | Yosif's estimate, not measured |

**Shipment count source:** Yosif's PoC writeup reports approximately 3,000 unplanned shipments per branch. Branch volumes will vary in production.

**Performance discrepancy:** Yosif's PoC writeup reports 40-50s for a full branch sync (~3,000 shipments), while the verbal estimate from the architect sync meeting was 20-25s. The difference may be due to different branch sizes, test environments, or measurement scope. Both numbers are acceptable for one-shot manual recovery.

**TMS database impact: unmeasured.** The PoC measured response times but not the load imposed on the TMS source database (CPU, memory, connection count). Yosif confirmed this cannot be investigated from the New Dispo side. TMS databases have hard RAM/CPU constraints — the impact of full-branch queries on source database availability must be evaluated with Nagel before production use.

**Important: Use direct `sendung` table queries, not the `v_shipment_all` view.** The view adds ~10x overhead due to joins and field translations. The raw `sendung` table is also what CDC receives, so staying close to it minimizes divergence risk.

---

## Deployment Phases

### Phase 1: Recovery Endpoint (Go-Live MVP)

**What:** Expose a recovery endpoint that backfills from a given timestamp for selected branches. Operations calls it manually after a detected CDC outage.

**Endpoint inputs (provided by operations):**
- **Branch selection:** Specific branches or all branches
- **Time range:** The outage start timestamp — operations knows when the outage occurred

**Behavior:** Two-step recovery:
1. **Inserts/Updates:** Query TMS for shipments with `u_time > provided timestamp`, apply through existing CDC resolvers
2. **Deletes:** Collect unplanned local leg shipment IDs for the selected branches, verify existence in TMS, run delete resolver for missing ones

**Watermark auto-derivation (future):** To be discussed in team refinement (see Open Process Questions #7). For Go-Live, operations provides the timestamp externally.

| Aspect | Detail |
|--------|--------|
| Concurrency | No concern - single manual invocation |
| Delete detection | Works - scoped to unplanned legs only (dispatched shipments never deleted) |
| Authorization | Operations/admin roles only |
| Scope | Specific branches or all branches (caller's choice) |
| TMS database load | Low - incremental query + small ID-based existence check |

### Phase 2: Continuous Fallback (Out of Scope)

**Not in scope for Go-Live.** Documented here for architectural context only.

Background hosted service that polls TMS at a configurable interval (~15s). Same two-step approach as Phase 1, running on a timer. Would require solving multi-instance concurrency and continuous TMS database load evaluation with Nagel.

---

## Issues Requiring Resolution

### 1. TMS Delete Constraint Dependency

**Dependency:** The scoped delete detection relies on the invariant that dispatched/planned shipments are never deleted in TMS. Joachim Schreiner and Patrick Uschmann (PO) confirmed this (2026-05-21); enforcement is being implemented by Joachim/Reinhard. Until this is enforced on the TMS side, there is a theoretical risk that a dispatched shipment could be deleted and the recovery would not detect it.

**Mitigation:** Confirm with Nagel that the delete constraint is enforced before Go-Live. If not yet enforced, fall back to checking all local leg shipment IDs (not just unplanned), accepting higher query volume.

### 2. Watermark Clock Domain Mismatch

**Problem:** If the watermark is derived from local CloudSQL `UpdatedAt`, it reflects when New Dispo wrote the record (local clock), not when TMS changed it (`u_time`, TMS clock). The CDC pipeline adds latency between these two clocks.

**Additional complication (refinement 2026-05-22, Yosif):** TMS timestamps (`u_time`) are not timezone-aware, while New Dispo timestamps are timezone-sensitive. For Go-Live (single branch, on-demand), the operator provides the timestamp in TMS clock domain manually — manageable. For multi-branch/automated future use, a timezone resolution strategy per branch is needed.

**Mitigation:** Apply a safety overlap margin (e.g., watermark - 10 minutes) when querying TMS. Re-processed records are handled gracefully by resolvers via `Supports(old, new)` — if nothing changed, no resolver fires. Alternative: persist the last successfully processed TMS `u_time` during CDC processing to stay in the TMS clock domain.

### 3. TMS Database Load Protection

**Problem:** TMS databases have hard RAM/CPU constraints. Recovery after a long outage (4+ hours) requesting many shipments could overwhelm the source.

**Mitigations to implement:**
- Time-window slicing: break large recoveries into chunks (e.g., 15-minute windows)
- Sequential branch processing instead of parallel (reduces peak load)
- Rate limiting between batch requests
- Configurable batch size

**Action required:** Coordinate with Nagel on acceptable query volume before production use.

### 4. Multi-Instance Concurrency (De-scoped for Go-Live)

**Problem:** If Backend runs multiple instances, multiple recovery processes could run simultaneously on the same data.

**Refinement outcome (2026-05-22):** De-scoped for Go-Live. Only relevant if mechanism becomes an automatic background process. For on-demand triggering, the load balancer routes to a single instance. Branches provide natural separation — no conflict even if multiple instances process different branches. Must be revisited if mechanism becomes automated.

**Options for future automated mode:**
- Database flag: persist "sync is running" flag (simple, slight race condition window)
- Leader election: only one instance runs the sync
- Accept idempotency: resolvers check field changes, so duplicate processing is safe but wasteful

### 5. Atomic Per-Shipment Transactions

**Problem:** The PoC wraps the entire `Execute()` call in a single implicit EF Core context lifetime. If one resolver throws (e.g., constraint violation, unsupported traffic mode transition), the entire sync aborts — all branches, all shipments.

**Resolution:** Each shipment should be processed in its own `BeginTransaction() / Commit() / Rollback()` block. A failure for one shipment rolls back only that shipment; all others continue. This also enables a structured per-shipment error report in the endpoint response (source: Yosif's PoC writeup).

### 6. View vs. Direct Table Access

**Problem:** The `v_shipment_all` view is ~10x slower than direct `sendung` table queries.

**Resolution:** Recovery should query the raw table via TMS Bridge. This also matches the CDC data source, reducing divergence risk.

---

## Open Process Questions

| # | Question | Impact |
|---|----------|--------|
| 1 | **How do we detect that CDC is down?** Timeout? Monitoring? Active heartbeat? | Determines if Phase 1 alone suffices or Phase 2 / alerting is needed |
| 2 | **What's the detection threshold?** When do we declare an outage? | Affects runbook and alerting design |
| 3 | **Who triggers recovery?** DevOps? Operations? Automated? | Affects endpoint authorization, documentation, training |
| 4 | ~~**All branches or per-branch?**~~ Resolved: support both — operations provides branch selection as endpoint input | - |
| 5 | **TMS database load tolerance?** Acceptable query volume per minute? | Must be answered by Nagel before production use. Collect concrete query examples during implementation. |
| 6 | ~~**Is recovery idempotent?** Running it twice should be safe~~ **Confirmed (refinement 2026-05-22, Yosif):** Idempotent by nature — mechanism always retrieves current latest state from TMS and compares against local state. Only breaks under concurrent execution, which does not apply to on-demand triggering. | Resolved |
| 7 | **How is the watermark derived?**<br>A: `MAX(UpdatedAt)` from local CloudSQL entities with safety margin to account for CDC pipeline latency (clock domain mismatch between TMS `u_time` and local write time)<br>B: Persist the last successfully processed TMS `u_time` value directly during CDC processing (stays in TMS clock domain, no conversion needed, but new state to maintain)<br>**Timezone complication (refinement 2026-05-22):** TMS timestamps are not timezone-aware; New Dispo timestamps are timezone-sensitive. For Go-Live (single branch, on-demand), operator provides timestamp in TMS clock domain manually. | Open — for Go-Live, external input; auto-derivation is post-June |

---

## Toward Backlog Items

Based on this concept, the following work items can be derived:

### Phase 1 (Go-Live)

| Item | Description | Depends on |
|------|-------------|------------|
| Refine PoC | Implement watermark-based query, scoped delete detection, per-shipment transaction isolation, clean up naming/error handling | - |
| Expose endpoint | Controller with proper authorization (operations/admin) | Refine PoC |
| API design | Support all-branches and single-branch invocation | Refine PoC |
| TMS load evaluation | Coordinate with Nagel on acceptable query patterns | - |
| Runbook | Document recovery procedure for operations team | Endpoint, process questions answered |
| Direct table access | Ensure TMS Bridge query uses `sendung` table, not view | - |

### Phase 2 (Future)

| Item | Description | Depends on |
|------|-------------|------------|
| Background service | Hosted service with configurable interval | Phase 1 complete |
| Concurrency handling | Single-instance execution guarantee | Background service |
| Delete detection strategy | Choose approach for incremental mode | Background service |
| CDC outage detection | Monitoring/alerting for automatic fallback | - |

---

## Source Code Reference

### PoC files (`feature/data-sync-poll-mechanism` branch)

| File | Purpose |
|------|---------|
| `Application/Features/DataSync/Services/DataSyncExecutor/DataSyncExecutor.cs` | Core sync algorithm - orchestrates the full recovery cycle |
| `Application/Features/DataSync/Services/DataSyncExecutor/IDataSyncExecutor.cs` | Interface (`Task Execute()`) |
| `Application/Features/DataSync/Services/DataSyncExecutor/Mappings/DataSyncExecutorMapper.cs` | `LegEntity` -> `GoogleBucketShipmentData` conversion for old-state derivation |

### Reused CDC infrastructure (existing, on `master`)

| Path | Purpose |
|------|---------|
| `Application/Features/CDC/EventHandlers/ShipmentUpdated/ShipmentUpdatedEventHandler.cs` | CDC update handler (PoC reuses its resolvers directly) |
| `Application/Features/CDC/EventHandlers/ShipmentUpdated/TrafficModeUpdateResolvers/` | 12 traffic mode transition resolvers + base class |
| `Application/Features/CDC/EventHandlers/ShipmentUpdated/FlatFieldsResolvers/` | Flat field update resolver |
| `Application/Features/CDC/EventHandlers/ShipmentUpdated/LotGenerationFieldsResolver/` | Lot generation field resolver |
| `Application/Features/CDC/EventHandlers/NewShipmentCreated/NewShipmentCreatedResolver.cs` | Insert: leg extraction, lot assignment, persistence |
| `Application/Features/CDC/EventHandlers/DeletedShipment/DeletedShipmentResolver.cs` | Delete: leg removal, lot/assignment cleanup |

### Shared infrastructure

| Path | Purpose |
|------|---------|
| `Application/_Shared/Services/ShipmentProvider/IPickupPlanningShipmentProvider.cs` | Interface for fetching shipments from TMS Bridge |
| `Application/_Shared/Services/ShipmentProvider/Dtos/PickupPlanningShipmentDto.cs` | Shipment DTO (44 fields including addresses, weights, dates, traffic mode) |

---

## Input Sources

| Source | Date | Content |
|--------|------|---------|
| [Replication Slot Outage Recovery](../2026-03-19_team-intro/replication-slot-outage-recovery.md) | 2026-03-19 | Original 4-strategy analysis |
| [CDC Error Flow - GoLive Workshop](../2026-03-24_GoLive_Workshop_Sofia_-_Resilience_and_TMS_Pulse_ORA_Analysis/cdc-error-flow.md) | 2026-03-24 | Batch Recovery Layer concept |
| Architect Sync with Yosif (transcript) | 2026-05-19 | PoC walkthrough, performance data, delete issue discovery |
| P3 Internal Bi-Weekly (transcript) | 2026-05-19 | Team-level summary, process questions identified |
| Dispo Blocker with Joachim Schreiner, Patrick Uschmann (PO) (transcript) | 2026-05-21 | Confirmed: dispatched shipments never deleted in TMS, delete constraint being enforced |
| `feature/data-sync-poll-mechanism` branch | 2026-05-19 | PoC implementation |
| Extra Refinement: CDC Recovery (transcript) | 2026-05-22 | Concept accepted, idempotency confirmed, multi-instance de-scoped, timezone complication identified, old-state derivation assumption documented |

**Note (2026-05-22):** Ivaylo Pashov collaboration on CDC topics abandoned — no responses, no-shows, no concepts despite repeated requests. Team owns the solutions and concepts independently.

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
