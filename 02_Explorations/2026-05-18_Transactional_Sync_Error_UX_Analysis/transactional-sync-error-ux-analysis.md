# Transactional Sync Error UX Analysis

**Date:** 2026-05-18
**Status:** Exploration
**Related User Stories:** #123326 (parent), #124105, #123950
**Branches Analyzed:**
- `feature/assign-leg-create-transport-order-from-leg-indempotent` (PR #32792) — #123303 (flows 1, 3)
- `feature/assing-lot-create-transport-order-from-lot-indempotent` (not yet merged, merge conflicts) — #123303 (flows 2, 4)
- `feature/unassing_transactions_implementation` (no PR linked yet) — #124362 / #124363 (flows 5, 6)
- `implement-final-changes-for-delete-transport-order` (no PR linked yet) — #124364 (flow 7)
- `feature/add-initial-retry-behavior` (PR #32732, merged) — #124103 (retry mechanism)
**Note:** All feature branches share merge-base `781a2800` (2026-05-07) with `origin/master`. Diffs are identical regardless of base branch.

<!-- internal -->
**Meeting Input:**
- `00_Meetings/2026-05-21_Weekly Refinement - NewDispo-Transactional-FLows-UX+Logging.vtt` — Team refinement with Matthias, Max Kehder, Boyan, Yosif, Bojidar, Ivaylo, Sonja (~75 min)
<!-- /internal -->

<!-- internal -->
**Concept Sources (local → wiki via wiki-connector):**
- `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/` → `Transactional-Behaviour.md`
- `02_Explorations/2026-04-08_Transactional_State_Verification_-_CreateTransportOrderFromLeg/` → `Transactional-Behaviour/Flows/`
- Wiki: `WIKI/Nagel-CAL-Disposition.wiki/Projects/Active/Transactional-Behaviour/`
  - `TMS-Synchronization-Failure-Scenarios.md` — 3 failure scenarios (Early Failure, Local DB Failure, Network Interruption)
  - `TMS-Sync-Error-Handling-Decision.md` — Decision paper: Option 1 (Manual Recovery) selected for June 2026
  - `Flows.md` — Progress tracker for all 7 flow analyses
  - `Flows/01..07-*.md` — Individual flow analysis with verification queries
  - `Challange-Transactional-Aprroaches.md` — Discussion on approaches
<!-- /internal -->

---

## Goal

Two questions:
1. **UX (#123950):** What should the user see when a sync conflict occurs — toast severity, wording, incident ID visibility, partial success handling?
2. **Logging (#124105):** What structured logging and unified error response does the Backend need to support the UX concept and enable operations to investigate failures?

---

## How Sync Detection Works

The transactional flows implement a **pre-action sync check**: before executing any TMS operation, the handler queries the current TMS state and compares it to the New Dispo local state.

### Single-Leg Assign Flows (#123303): CreateTransportOrderFromLeg, AssignLegToTransportOrder

```
1. Load leg from New Dispo DB
2. Query TMS Bridge for current TMS leg state → TmsLegRecord
3. ShouldSync(tmsLeg) → checks if tmsLeg.TransportOrderId is not null
4. If out-of-sync:
   a. Repair: sync New Dispo local state to match TMS (create/update lot assignment)
   b. Throw ConflictException with message
5. If in-sync: proceed with TMS operation normally
```

**Key file:** `AssignLegToTransportOrderCommandHandler.cs` on branch `feature/assign-leg-create-transport-order-from-leg-indempotent`

### Lot-Based Assign Flows (#123303): CreateTransportOrderFromLot, AssignLotToTransportOrder

```
1. Load lot and legs from New Dispo DB
2. Query TMS Bridge for ALL legs in lot → List<TmsLegRecord>
3. ShouldSync(tmsLegs, legs) → true if ANY leg has matching TmsLegRecord with TransportOrderId
4. If out-of-sync:
   a. Per-leg: repair conflicting legs (create LotAssignment), report non-conflicting legs
   b. Recalculate or remove lot
   c. Return HTTP 200 with per-leg ConflictDto list (NOT ConflictException)
5. If in-sync: proceed with TMS operation normally
```

**Key files:** `CreateTransportOrderFromLotSyncSubHandler.cs`, `AssignLotToTransportOrderSyncSubHandler.cs` on branch `feature/assing-lot-create-transport-order-from-lot-indempotent`

**Important:** Lot-based flows use HTTP 200 + `Conflicts` array, NOT HTTP 409 + `ConflictException`. This is a different error contract from the single-leg flows. Lot is a New Dispo Backend concept only — TMS Bridge and TMS Database have no knowledge of lots. The Backend maps lot → legs before calling TMS Bridge.

### Unassign Flows (#124362 / #124363): UnassignLegs, UnassignLots

```
1. Load legs/lots from New Dispo DB
2. Query TMS Bridge for unsynched legs → GetUnsynchedLegs()
3. Filter: separate synced legs from unsynched legs
4. For synced legs: execute TMS remove operation, then update New Dispo DB
5. For unsynched legs: repair New Dispo state, return per-item error response
```

**Key files:** `UnassignLegsSubHandler.cs`, `UnassignLotsSubHandler.cs`, `InternalLegOperationsSubHandler.cs` on branch `feature/unassing_transactions_implementation`

### Delete Transport Order (#124364)

**In Progress.** Sync detection designed: check if deletion was already performed in TMS → if yes, sync local state by unassigning legs/lots on New Dispo side and return HTTP 200 (operation effectively succeeded). Does not check whether legs are assigned to a different TO — only cares about cleaning up local state.

### Atomicity Guarantees

| Scope | Atomic? | Explanation |
|-------|---------|-------------|
| TMS operations within one flow | **Yes** | All TMS calls for a single operation (e.g., unassign all legs in a lot) commit or fail together |
| New Dispo DB operations within one flow | **Yes** | Single `SaveChangesAsync` call commits all local changes at once |
| Cross-system (TMS + New Dispo together) | **No** | TMS can succeed while New Dispo fails — this is the out-of-sync case |

It will **never** happen that 3 of 5 legs in a lot are unassigned in New Dispo while 2 are not. The out-of-sync state is always all-or-nothing per system. The "partial success" concept applies only across *separate operations* (individual legs from the slider), not within a single lot/TO operation.

**"Non-recoverable" means per-request:** non-recoverable within this request including internal Polly retries. If the user tries again later and succeeds, that's a new iteration. This is the "manual minimal version."

### Known Limitation: Backend Crash

If the Backend process itself crashes (not just a TMS or DB failure), there will be no incident ID in the response and no structured log entry. Manual cloud log investigation is the fallback. Scoped out for now.

---

## Concept vs. Implementation: What Was Designed vs. What Was Built

The concept documentation (approved April 2026) specified verification queries and conflict handling for each flow. Here's how the implementations compare:

### Architecture Decision (from TMS-Sync-Error-Handling-Decision.md)

**Selected:** Option 1 — Manual User-Driven Recovery (for June 2026)
- On sync failure: display error, provide manual retry
- State-checking logic required before any retry
- Idempotency verified for leg assignment (HasSen guard), NOT for TO creation
- Post-June roadmap: migrate to Outbox Pattern

**What was actually built:** A hybrid approach — the implementations go beyond "manual recovery" by automatically repairing New Dispo state. The user doesn't need to manually trigger a retry; instead, the pre-action sync check repairs state and forces a page refresh. This is stricter than Option 1 but simpler than Outbox.

### Per-Flow: Concept vs. Implementation

**Legend:** Option 1 specified: state-checking query → display error → user manually retries.

| Flow | Concept (Option 1) | Implementation | vs. Option 1 |
|------|---------------------|----------------|--------------|
| **01 CreateTOFromLeg** | Query TMS for leg assignment, show error if assigned, user retries | Queries TMS, **auto-repairs** New Dispo state, throws ConflictException (409) | **Overdelivered** — auto-repair instead of manual retry. User still must re-evaluate, but local state is already fixed. |
| **02 CreateTOFromLot** | Check all lot legs assigned to same TO, show error, user retries | Queries TMS per leg, **auto-repairs** per conflicting leg, returns HTTP 200 with per-leg `ConflictDto` list. Branch: `feature/assing-lot-create-transport-order-from-lot-indempotent` (not yet merged — merge conflicts) | **Overdelivered** — auto-repair per leg + per-leg conflict details. Different error contract: HTTP 200 + Conflicts array (not 409). |
| **03 AssignLegToTO** | Query TMS, distinguish same-TO (no-op) vs. different-TO (error), user retries | Queries TMS, **auto-repairs**, throws ConflictException. Distinguishes same-TO vs. different-TO in error message. | **Overdelivered** — auto-repair + same/different-TO distinction in error message |
| **04 AssignLotToTO** | Check all lot legs, per-leg count, user retries | Queries TMS batch, **auto-repairs** per conflicting leg, returns HTTP 200 with per-leg `ConflictDto` (same-TO/different-TO distinction). Same branch as Flow 02 (not yet merged — merge conflicts) | **Overdelivered** — auto-repair per leg + same/different-TO error messages. Different error contract: HTTP 200 + Conflicts array (not 409). |
| **05 UnassignLots** | Query TMS for removal status, show error, user retries | Queries TMS, **auto-repairs** unsynched legs, proceeds with synched legs, returns per-item success/failure | **Overdelivered** — auto-repair + partial success (synched legs proceed, unsynched repaired) |
| **06 UnassignLegs** | Query TMS per-leg, show error, user retries | Same auto-repair pattern, per-leg granularity, proceeds with synched legs | **Overdelivered** — auto-repair + partial success |
| **07 DeleteTO** | Query TMS for TO existence, show error, user retries | In Progress: check if already deleted in TMS → sync local state, return 200 | **Catching up** — sync detection designed, implementation in progress |

**Summary:**
- 6 of 7 flows **overdeliver** vs. Option 1 (auto-repair instead of manual retry)
- Of these, 2 (lot-based assign flows) are implemented on branch but not yet merged (merge conflicts)
- 1 of 7 flows **catching up** (DeleteTO sync detection in progress — #124364)

### Cross-cutting: Option 1 Requirements Not Yet Addressed

| Option 1 Requirement | Status | Notes |
|----------------------|--------|-------|
| State-checking query before action | **Done** for 6 flows (4 merged, 2 on branch) | Via TmsLegProvider, equivalent to concept verification queries |
| Display error to user | **Partially done** | ConflictException → HTTP 409, but error messages are bare strings, no incident ID |
| User manually retries | **Replaced** by auto-repair + forced refresh | Better UX, but concept drift from Option 1 |
| Error messaging UX (decision paper open item #2) | **Not done** | No structured error payload for frontend UX |
| Incident ID / log reference for support | **Not done** | No incident tracking at all |
| Support team runbooks (decision paper open item #6) | **Not done** | No documentation for support |
| Monitoring for failure frequency (decision paper open item #5) | **Not done** | No metrics or dashboards |

### Three Failure Scenarios (from TMS-Synchronization-Failure-Scenarios.md)

| Scenario | Description | vs. Option 1 | How Current Implementation Handles It |
|----------|-------------|--------------|--------------------------------------|
| **1. Early Failure** | TMS Bridge returns 4xx/5xx before commit | **As specified** | Handled by exception handlers + Polly retry (3x). Clean failure, no inconsistency. Nothing more needed. |
| **2. Local DB Failure Post-TMS** | TMS commits, New Dispo DB fails | **Overdelivered** (detection) / **Underdelivered** (communication) | Pre-action sync check detects and **auto-repairs** on *next* user action. But: no proactive detection between actions, no incident ID, no structured error info for user or support. |
| **3. Network Interruption** | TMS commits, response lost | **Overdelivered** (detection) / **Underdelivered** (communication) | Same as Scenario 2. Polly retry may catch transient network issues (3x), but if all retries fail, inconsistency persists until next user action triggers sync check. No incident trail. |

**Key insight:** The implementation **overdelivers on detection and repair** (auto-fix instead of manual retry) but **underdelivers on communication** (no incident ID, no structured error info, no support tooling). This is the gap that #124105 and #123950 need to close.

**Additional finding:** Two different error contracts exist — single-leg flows use HTTP 409 + `ConflictException`, lot-based flows use HTTP 200 + `Conflicts` array. This complicates frontend error handling.

### Individual Flow Analysis

Detailed per-flow analysis with sequence diagrams, concept vs. implementation comparison, Option 1 checklist, and UX scenarios:

| Flow | File | Status |
|------|------|--------|
| 01 CreateTOFromLeg | [flow-01-create-transport-order-from-leg.md](./flow-01-create-transport-order-from-leg.md) | Overdelivered |
| 02 CreateTOFromLot | [flow-02-create-transport-order-from-lot.md](./flow-02-create-transport-order-from-lot.md) | Overdelivered (on branch, merge conflicts) |
| 03 AssignLegToTO | [flow-03-assign-leg-to-transport-order.md](./flow-03-assign-leg-to-transport-order.md) | Overdelivered |
| 04 AssignLotToTO | [flow-04-assign-lot-to-transport-order.md](./flow-04-assign-lot-to-transport-order.md) | Overdelivered (on branch, merge conflicts) |
| 05 UnassignLots | [flow-05-unassign-lots.md](./flow-05-unassign-lots.md) | Overdelivered |
| 06 UnassignLegs | [flow-06-unassign-legs.md](./flow-06-unassign-legs.md) | Overdelivered |
| 07 DeleteTO | [flow-07-delete-transport-order.md](./flow-07-delete-transport-order.md) | In Progress (#124364) |

---

## Retry vs. Sync-Check: Two Separate Mechanisms

### Retry (PR #32732, merged)

- Wraps **every** TMS Bridge GraphQL call via `GraphQLQueryService.SendQuery()`
- Uses Polly with exponential backoff: 3 attempts, 200ms base delay, jitter
- Only handles **transient infrastructure errors**:
  - `HttpRequestException` (connection error, DNS, premature response end)
  - `TaskCanceledException` (timeout)
  - `TimeoutException`
  - `GraphQLHttpRequestException` (502, 503, 504)
  - `TmsBridgeTransientErrorException` (TMS DB down behind TMS Bridge)
- Does **not** handle `ConflictException` or business errors

### Sync-Check (flow PRs)

- Runs **before** the TMS operation, not as a retry
- Detects state divergence between New Dispo and TMS
- **Always repairs** New Dispo local state to match TMS
- **Always throws/returns error** even after successful repair
- Purpose: force user to refresh and consciously re-evaluate the action

**The ConflictException fires even when repair succeeds.** This is by design per the user story: "repair sync → inform user → user repeats action if still desired." The 3x Polly retry never kicks in for sync conflicts because `ConflictException` is not in the retry predicate.

---

## What Error Information Reaches the Frontend Today

### Assign Flows → HTTP 409 Conflict (ProblemDetails)

```json
{
  "status": 409,
  "title": "Conflict with the current state of the target resource.",
  "detail": "Leg has already been assigned to transportorder with ID 1234.",
  "type": "https://datatracker.ietf.org/doc/html/rfc7231#section-6.5.8",
  "errors": []
}
```

Variants:
- `"Leg has already been assigned to this transportorder."` (same TO)
- `"Leg has already been assigned to a different transportorder with id {x}."` (different TO)
- `"Leg has already been assigned to transportorder with ID {syncResult.TransportOrderId}."` (create TO flow)

### Lot-Based Assign Flows → Per-leg ConflictDto in 200 OK (on branch, not yet merged)

```json
{
  "transportOrderId": 0,
  "transportOrderNumber": 0,
  "conflicts": [
    { "legId": "aaa-bbb", "error": "Leg is already part of a transport order", "isAssigned": true },
    { "legId": "ccc-ddd", "error": "Leg has already been assigned to a different transportorder.", "isAssigned": true },
    { "legId": "eee-fff", "error": null, "isAssigned": false }
  ]
}
```

Note: Different error contract from single-leg flows. HTTP 200 with `Conflicts` array instead of HTTP 409 `ConflictException`.

### Unassign Flows → Per-item UpsertOperationResponseDto in 200 OK

```json
[
  { "id": "<legId>", "success": false, "error": "Conflict occured" },
  { "id": "<legId>", "success": false, "error": "Tms Leg removal failed." },
  { "id": "<lotAssignmentId>", "success": false, "error": "Remove lot failed" }
]
```

### Common to all flows (via BaseExceptionHandler)

- `_logger.LogError(ex, ex.Message)` — generic Serilog logging
- No incident ID generated
- No structured sync conflict payload
- No correlation ID returned

---

## Assessment: Is #124105 Still Needed?

**Yes, but with redefined scope.**

What the flows already cover:
- Sync detection (comparing New Dispo state vs. TMS state)
- Automatic repair of New Dispo local state
- Basic error messages indicating what went wrong

What is still missing (#124105 scope):
1. **Incident ID** — no unique trackable ID per sync conflict event → [Implementation options analyzed](./incident-id-options.md)
2. **Structured logging** — sync conflicts are logged as generic exceptions, not as structured events with sync-specific payload
3. **Enriched error response** — the error messages are plain strings with minimal context; no machine-readable conflict type, no affected entity details
4. **Log persistence** — logs go to rolling text files only; no dedicated queryable storage for sync incidents (note: #124104 for GCP storage was descoped/removed)

### Current #124105 Scope (as refined)

**State:** To Refine | **Effort:** 1.5 (predates scope expansion — worth re-estimating)

| AC | Scope |
|----|-------|
| AC 1 | Incident ID in all sync conflict responses — `HttpContext.TraceIdentifier` recommended (~1 line in `BaseExceptionHandler`) |
| AC 2 | Structured sync conflict logging — incidentId, conflictType, affectedEntityType/Id, transportOrderId, actionTaken, flowName |
| AC 3 | Unified error response shape — replacing 3 inconsistent contracts (409 ProblemDetails / 200 ConflictDto[] / 200 UpsertOperationResponseDto[]). Must be agreed with FE team. |
| AC 4 | Log pairing for Flow 7 — "deletion initiated" / "deletion finished" events with matching identifiers |

---

## Data Available for Frontend UX (#123950)

### Data Available per Flow (from concept verification queries)

The flow concept documents specify what data is queryable from TMS at sync-check time. This is data the backend *already fetches* or *could fetch* and forward to the frontend:

| Flow | Data Available at Sync Check | Useful for UX? |
|------|------------------------------|----------------|
| **CreateTOFromLeg** | TransportOrderId, PerformanceDate, Company, Branch, TransportMode (via V_DIS_TransportOrder join) | Yes — can tell user "leg is already on TO #X, created on date Y" |
| **CreateTOFromLot** | Per-leg assignment status, existing TransportOrderId, expected vs. actual leg count. Implemented: `ConflictDto` per leg with `IsAssigned` flag | Yes — can show partial assignment status. Implementation returns per-leg conflict details in HTTP 200 |
| **AssignLegToTO** | TransportOrderId, PickupTourPointId, DeliveryTourPointId, TMS LegId; HasSen idempotency means TMS silently no-ops | Yes — can distinguish "already on this TO" (benign) from "on different TO" (conflict) |
| **AssignLotToTO** | Per-leg assignment count, tour point sequence. Implemented: per-leg `ConflictDto` with same-TO/different-TO distinction | Yes — can show which legs are assigned where. Implementation returns per-leg conflict details with same/different TO error messages |
| **UnassignLots** | Per-leg removal status (still assigned vs. removed), expected leg count | Yes — can show "3 of 5 legs removed, 2 were already unassigned" |
| **UnassignLegs** | Per-leg status (removed/still-assigned/reassigned-elsewhere) | Yes — granular per-leg feedback |
| **DeleteTO** | TO existence (binary check) | Minimal — "TO was already deleted" or "TO still exists" |

### Currently available in the Backend (from TmsLegRecord, queried during sync check)

| Field | UX Relevance |
|-------|-------------|
| `TransportOrderId` | Which TO the leg is actually assigned to in TMS |
| `ShipmentId` | Which shipment is affected |
| `LegType` (V/H/N) | Pickup (VL) vs. delivery (HL) vs. transit (NL) |
| `PickUpName1`, `PickUpCity`, `PickUpStreet` | Origin address |
| `DeliveryName1`, `DeliveryCity`, `DeliveryStreet` | Destination address |
| `DeliveryDateFrom` / `DeliveryDateTo` | Delivery time window |
| `ProductGroup` | Product group code |
| `LegId` / `PreviousLegId` | Internal leg references |

### Proposed Error Response Structure for Frontend

```json
{
  "status": 409,
  "title": "Sync conflict detected and resolved",
  "detail": "Leg VL for shipment 12345 was already assigned to Transport Order 6789 in TMS. Local state has been repaired.",
  "incidentId": "a1b2c3d4-...",
  "conflictType": "AlreadyAssigned | AlreadyUnassigned | TmsOperationFailed | StateMismatch",
  "affectedEntity": {
    "type": "Leg | Lot | TransportOrder",
    "id": "...",
    "shipmentId": 12345
  },
  "actionTaken": "LocalStateRepaired | NoRepairPossible",
  "wasAutoRepaired": true,
  "tmsState": {
    "transportOrderId": 6789,
    "legType": "V",
    "origin": "Nagel Langenhagen, Münchner Str. 42",
    "destination": "Nagel Hamburg, Hauptstr. 10",
    "deliveryWindow": "2026-05-20 08:00 - 2026-05-20 16:00"
  }
}
```

### Per-Flow UX Scenarios

| Scenario | User Action | What Happened | What User Sees | User Must Do |
|----------|------------|---------------|----------------|-------------|
| Assign leg (already on same TO) | Assign leg to TO X | Leg already on TO X in TMS, local synced | Snackbar: "Already assigned. Page refreshed." | Nothing — done |
| Assign leg (on different TO) | Assign leg to TO X | Leg on TO Y in TMS, local synced | Snackbar: "Leg is on TO Y. Page refreshed. Re-evaluate." | Decide if reassignment needed |
| Create TO from leg (already assigned) | Create new TO | Leg already on TO Z, local synced | Snackbar: "Leg already on TO Z. Page refreshed." | Navigate to existing TO or pick different leg |
| Unassign leg (not assigned in TMS) | Remove leg from TO | Leg wasn't on this TO in TMS, local cleaned | Per-item error in response | Refresh — already unassigned |
| Unassign lot (partial sync) | Remove lot from TO | Some legs in lot were out of sync | Mixed success/failure per item | Refresh — partial repair, retry remainder |
| Delete TO | Delete TO | (no sync check yet in #124364) | TBD | TBD |

### UX Design Considerations — PO Decisions (2026-05-20)

| # | Topic | Decision | Source |
|---|-------|----------|--------|
| 1 | **Incident ID visibility** | Only shown for non-resolvable issues (Flow 7 / TMS failures). Resolvable conflicts: logged server-side only. Cryptic UUID/hex acceptable — copy-paste button handles UX. One fresh ID per request, no correlation across retries. | PO decision + team confirmation |
| 2 | **Refresh behavior** | Manual refresh — user refreshes the page themselves. No auto-refresh. | PO decision, overrides original AC2 |
| 3 | **Auto-retry of user action** | No auto-retry. User must consciously repeat the action after refresh. | Confirmed, per AC4 |
| 4 | **Severity levels** | Two levels for resolvable: info (auto-dismiss, green) for benign + warning (stays until dismissed, yellow/orange) for real conflicts. Error (red, persistent + Log ID) for non-resolvable. | PO decision + team confirmation |
| 5 | **Same-TO vs. Different-TO** | Distinguish: "already on this TO" = info level, "on a different TO" = warning level. | PO decision, backend already supports this |
| 6 | **Partial success display** | Summary toast for individual-leg-from-slider scenario only (e.g., "3 of 5 legs assigned. 2 had conflicts."). Lot operations are atomic — one operation = one toast, no per-leg partial state. No per-leg detail panel. | PO decision, refined by team |
| 7 | **Flow 7 toast wording** | Transparent: "Transport Order deleted. Some local data could not be cleaned up. Our team has been notified. Log ID: X" | PO decision |
| 8 | **Flow-specific vs. generic messages** | Generic template with `[action name]` slot. Not flow-specific wording. | PO decision |
| 9 | **Log infrastructure** | Use existing GCP Cloud Run log. No dedicated sink or table. Filter by incident ID. Yosif proposed structured log template: prefix + incident ID + entity IDs for filterability. | Team decision |

### Current #123950 Scope (as refined)

**State:** To Refine | **Depends on:** #124105

| AC | Scope |
|----|-------|
| AC 1 | Info toast — benign conflicts (green, auto-dismiss). Template: *"The [action name] you performed affected an out-of-sync item. The issue has been resolved automatically. Please refresh the page."* |
| AC 2 | Warning toast — real conflicts (orange, stays until dismissed). Same template, different severity. |
| AC 3 | Batch summary toast (Flows 2, 4, 5, 6) — single summary, severity follows worst-case item. |
| AC 4 | Error toast — non-resolvable (red, stays, Log ID + copy button). Flow 7 template: *"Transport Order deleted. Some local data could not be cleaned up. Our team has been notified. Log ID: [Log ID]."* |
| AC 5 | Same-TO vs. Different-TO distinction (Flows 3, 4) — same TO = info, different TO = warning. |
| AC 6 | General behavior — manual refresh, no auto-retry, generic template with `[action name]` slot. |

---

## Open Questions

### Resolved

| # | Question | Resolution | Date |
|---|----------|------------|------|
| 3 | **Incident ID implementation** — which approach? | `HttpContext.TraceIdentifier` (Option 1) recommended. Cryptic UUID/hex acceptable — copy-paste button handles UX. GCP log entry ID (Option 3) dismissed as non-trivial. Now defined as #124105 AC 1. | 2026-05-21 |
| 4 | **Frontend error contract** — unified or split? | Unified. #124105 AC 3 mandates a single response shape replacing all three current contracts. Must be agreed with FE team before implementation. | 2026-05-23 |
| 5 | **Snackbar per AC1 vs. per-item errors** — one snackbar with summary or one per item? | Summary toast only (PO decision #6). Applies only to individual-leg-from-slider scenario; lot operations are atomic (one toast per lot). | 2026-05-20 |
| 8 | **Partial failure in batch operations** — UX for mixed success/failure results? | Summary toast, no per-leg detail. Lot operations are atomic — partial success only across separate requests (individual legs from slider). | 2026-05-20 |
| 9 | **Incident ID human-readability** — does the ID need to be user-friendly? | No. Cryptic UUID/hex is acceptable. Copy-paste button handles the UX. Confirmed by Max Kehder. | 2026-05-21 |
| 10 | **Dedicated log infrastructure** — separate log sink for conflict events? | No. Use existing GCP Cloud Run log. Filter by incident ID. No additional infra. | 2026-05-21 |
| 11 | **Incident ID correlation across retries** — should the same entity get the same ID on repeated failures? | No. Each request gets a fresh ID. Separate requests = separate incidents. | 2026-05-21 |
| 12 | **Meaning of "non-recoverable"** — permanently broken or just this request? | Per-request scope: non-recoverable within this request including internal Polly retries. User can retry manually later. | 2026-05-21 |
| 13 | **Proactive vs. reactive detection** — background check or only on user action? | Reactive only (on next user action). Accepted for June as "manual minimal version." | 2026-05-21 |
| 14 | **Concept drift** — auto-repair went beyond Option 1, update docs? | Yes. Auto-repair is now the documented pattern, confirmed by team. Concept updated to reflect what was built. | 2026-05-21 |
| 15 | **Toast auto-dismiss duration** — 3 seconds too short? | Addressed by severity model: info auto-dismisses, warning/error stay until dismissed. Validate during FE implementation. | 2026-05-21 |

### Still Open

1. **#124364 (DeleteTransportOrder)**: In Progress. Sync detection designed but not yet complete. Must adopt unified error contract from #124105 AC 3 and include incident ID (AC 1) + structured logging (AC 2).
2. **Lot-based assign flows** (#123304 In Progress, branch `feature/assing-lot-create-transport-order-from-lot-indempotent`): Has merge conflicts (not yet merged). Ticket specifies "return 409 conflict" which may align with unified contract from #124105 AC 3. Must adopt unified contract at merge time.
