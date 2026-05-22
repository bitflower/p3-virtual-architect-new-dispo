# [ADR010] CDC Recovery Strategy: Sendung Data Sync

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** Matthias Max, Christian Lang, Pascal Leicht

## Context

The CDC (Change Data Capture) pipeline syncs shipment data from the TMS `sendung` table to New Dispo. When this pipeline fails or has an extended outage, New Dispo data becomes stale with no recovery mechanism. Data loss can occur at multiple points along the CDC pipeline -- e.g., WAL replication slot timeout (1-hour retention on some branches), network outages, GCP Datastream failures, Striim failures, or Pub/Sub/Cloud Function/Backend processing disruptions. This affects all branches simultaneously and leaves dispatchers working with outdated data without knowing it.

In March 2026, four recovery strategies were identified and evaluated. In May 2026, a PoC was built on branch `feature/data-sync-poll-mechanism` (Disposition-Backend) to validate feasibility.

Key constraints:

1. **Schema ownership**: TMS database is owned by Nagel and cannot be modified
2. **Resource limits**: TMS databases have hard RAM/CPU constraints
3. **No shipment storage in New Dispo**: Local state lives as legs in CloudSQL, not as shipments
4. **Hard-deletes**: TMS performs hard-deletes on shipments (no soft-delete flag)
5. **Logic consistency**: Recovery records must run through the same business logic that CDC records run through, to avoid divergence
6. **Dispatched shipments are never deleted** (confirmed by Joachim Schreiner and Patrick Uschmann [PO], 2026-05-21; enforcement being implemented on TMS side by Joachim/Reinhard)

#### Options Considered

**Option 1: High-Water Mark (HWM) Recovery** -- query TMS for shipments updated since a known-good timestamp, apply inserts/updates.

* Yosif's separate analysis estimated ~0.5s for ~50 records in a 15-second `u_time` window — **not implemented in PoC**
* Existing CDC resolvers fully reusable
* **Cannot detect hard-deletes via timestamp** -- deleted records have no `u_time` to query. Requires a complementary delete check (see Decision)

**Option 2: Transactional Outbox on TMS Database** -- write CDC-relevant changes to a dedicated outbox table on the TMS side, making change events explicit and recoverable at the source.

* Would eliminate the "silent data loss" problem -- changes are persisted in a queryable table before CDC picks them up
* Recovery becomes trivial: replay unprocessed outbox entries
* Requires schema changes on the TMS database

**Option 3: Storage-Based Reconciliation ("Anti-Entropy")** -- periodically compare full state between TMS and New Dispo, fix discrepancies.

* PoC validated: full-sync mode loads all shipments, compares with local legs, applies all change types
* Full branch sync: ~20-25s (single branch, shipment count not recorded), all branches: ~40s estimated
* **Only approach that reliably catches deletes**
* TMS database load impact unmeasured -- must be evaluated with Nagel before production use
* Unsuitable for continuous polling due to full-state query volume; acceptable for one-shot recovery

**Option 4: Checkpoint & Manifest** -- write metadata after each sync batch, detect gaps on restart.

* Detection-only mechanism -- answers "when did we lose data?" but doesn't fix the gap
* Valuable for observability but not a recovery mechanism

## Decision

**Option 1 (HWM) with scoped delete detection**, implemented as a Backend-internal data sync that reuses existing CDC resolver logic.

Recovery is a two-step process:

| Step | Mechanism | Scope |
|------|-----------|-------|
| 1. Inserts/Updates | Query TMS for shipments with `u_time > watermark` | All shipments changed since last known-good timestamp |
| 2. Deletes | Check unplanned local leg shipment IDs against TMS | Only unplanned legs -- dispatched shipments are never deleted (constraint #6) |

The watermark is derived from the last successful sync timestamp. Delete detection is scoped to unplanned legs only, reducing query volume from hundreds of thousands to hundreds or thousands of shipment IDs per branch.

Phase 1 (recovery endpoint) is approved for Go-Live. Phase 2 (continuous background polling) is documented as a future option, not in scope for Go-Live.

## Rationale

* **Option 1 chosen** because HWM backfill is the lightest-weight approach: incremental, low TMS database load, and directly reusable with existing CDC resolvers. The delete detection gap is closed by a complementary scoped check (see below), not by switching to a heavier approach.

* **Delete detection solved via constraint #6:** Since dispatched/planned shipments are never deleted in TMS, delete detection only needs to verify unplanned local leg shipment IDs against TMS. This is a small ID-based existence check, not a full-state reconciliation. Volume: hundreds or thousands vs. hundreds of thousands.

* **Option 2 rejected** because it requires schema changes on the TMS database. Nagel owns the TMS database and does not have the capacity or budget for modifications. This is the most robust option technically, but violates the schema ownership constraint.

* **Option 3 not needed** because the scoped delete check (unplanned legs only) achieves delete detection without full-state comparison. Full reconciliation would impose unnecessary load on TMS databases whose impact on CPU, memory, and availability has not been measured. Option 3 remains available as a fallback if the dispatched-shipments-never-deleted constraint proves unreliable.

* **Option 4 deferred:** Detection-only. Valuable as a future complement for automated outage detection, but doesn't solve the recovery problem. Can be added independently without affecting this decision.

### Comparison

| Aspect | Option 1 (HWM) | Option 2 (Outbox) | Option 3 (Reconciliation) | Option 4 (Manifest) |
|--------|----------------|-------------------|--------------------------|---------------------|
| Handles inserts | Yes | Yes | Yes | No (detection only) |
| Handles updates | Yes | Yes | Yes | No (detection only) |
| Handles deletes | Yes (scoped to unplanned) | Yes | Yes | No (detection only) |
| Requires TMS schema change | No | **Yes** | No | No |
| TMS database load | Low (incremental) | Low (event-driven) | High (full scan) | None |
| Complexity | Low | Medium | Medium | Low |
| PoC validated | Yes | N/A (rejected) | Yes | N/A |

## Consequences

* **Positive**:
  * Recovery mechanism reuses 100% of existing CDC business logic -- no divergence risk
  * Backend-only change -- no coordination needed with TMS Bridge or Frontend teams
  * PoC proves feasibility and acceptable performance
  * Low TMS database load -- incremental HWM query + small ID-based delete check
  * Handles all change types (inserts, updates, deletes) in both Phase 1 and Phase 2
  * Architectural path toward continuous fallback is clear

* **Negative**:
  * Manual trigger required for Phase 1 -- no automated outage detection
  * Delete detection relies on constraint #6 (dispatched shipments never deleted) -- enforcement pending on TMS side
  * Watermark derivation requires handling clock domain mismatch between TMS `u_time` and local `UpdatedAt`
  * No real-time recovery -- data remains stale until someone detects the outage and triggers recovery

## Related ADRs

* [ADR-006: Oracle CDC Solution Selection](../ADR-006-oracle-cdc-solution-selection/ADR-006-oracle-cdc-solution-selection.md) -- related CDC infrastructure decision

## References

**Exploration:**
* [CDC Recovery - Sendung Data Sync (Solution Concept)](../../02_Explorations/2026-05-21_CDC_Recovery_-_Sendung_Data_Sync/cdc-recovery-sendung-data-sync.md) -- detailed architecture, algorithm, resolver reuse, performance data, and backlog derivation
* [Replication Slot Outage Recovery (Original Analysis)](../../02_Explorations/2026-03-19_team-intro/replication-slot-outage-recovery.md) -- the four recovery strategies initially identified
* [CDC Error Flow - GoLive Workshop](../../02_Explorations/2026-03-24_GoLive_Workshop_Sofia_-_Resilience_and_TMS_Pulse_ORA_Analysis/cdc-error-flow.md) -- Batch Recovery Layer concept

**Key Source Files (PoC branch `feature/data-sync-poll-mechanism`):**

| File | Role |
|------|------|
| `DataSyncExecutor.cs` | Core sync algorithm -- orchestrates full recovery cycle |
| `DataSyncExecutorMapper.cs` | LegEntity -> GoogleBucketShipmentData conversion for old-state derivation |
| `CDC/EventHandlers/ShipmentUpdated/TrafficModeUpdateResolvers/` | Reused update resolvers (12 traffic mode transitions) |
| `CDC/EventHandlers/NewShipmentCreated/NewShipmentCreatedResolver.cs` | Reused insert resolver |
| `CDC/EventHandlers/DeletedShipment/DeletedShipmentResolver.cs` | Reused delete resolver |

## Document History

| Date       | Author       | Change      |
|------------|--------------|-------------|
| 2026-05-21 | Matthias Max | ADR created |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
