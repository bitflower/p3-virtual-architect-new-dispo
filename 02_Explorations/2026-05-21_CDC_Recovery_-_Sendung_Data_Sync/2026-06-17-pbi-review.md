# PBI Review: CDC Outage Recovery (#123589)

**Date:** 2026-06-17
**Reviewer:** Matthias Max
**Concept sources:**
- [ADR-010: CDC Recovery Strategy](../../09_ADRs/ADR-010-cdc-recovery-sendung-data-sync/ADR-010-cdc-recovery-sendung-data-sync.md)
- [Solution Concept: CDC Recovery - Sendung Data Sync](cdc-recovery-sendung-data-sync.md)

---

## PBI Inventory

| # | PBI | State | SP | Assignee |
|---|-----|-------|----|----------|
| 124824 | [BE] Implement on-demand data sync poll mechanism | Refined | 3 | Ivaylo Petrov |
| 124826 | [BE] Expose an endpoint for the data sync mechanism | Refined | 2 | Kristiyan Paunov |
| 124827 | [QA] Test the data sync mechanism | Refined | 2.5 | Vesela Todorova |
| 123931 | [QA/BE/DevOps] Automated tests for data loss scenarios | Blocked | - | Matthias Max |
| 123927 | [Arch] Technical Concept | Closed | - | Ivailo Pashov |
| 123929 | [BE] Implement recovery Mechanism | Removed | - | - |
| 123952 | [DevOps] Implement check scheduler / trigger | Removed | - | - |

---

## PBI #124824 — Implement mechanism (3 SP)

The PBI correctly references the PoC branch, encourages improving over copying, identifies the transaction granularity issue (concept Issue #5), and mentions direct table access. The following gaps remain:

### Delete detection scope differs from concept

The PBI says "retrieve all ids from TMS" for deletion detection. The concept is explicit: delete checks are **scoped to unplanned legs only** because dispatched shipments are never deleted (constraint #6, confirmed by Joachim Schreiner and Patrick Uschmann, 2026-05-21). This scoping reduces the check from hundreds of thousands to hundreds/thousands of IDs per branch.

**Impact:** Implementing "retrieve all IDs" will impose unnecessary load on TMS and deviates from the decided approach.

**Fix:** PBI must state that deletion detection queries only shipment IDs of **unplanned** local legs against TMS, not all shipments.

### Watermark clock domain mismatch not addressed

The PBI says "make sure the logic there is filtering by updatedTime" as if it's a simple filter. The concept identifies this as Issue #2 with significant complexity:
- TMS `u_time` is not timezone-aware; New Dispo timestamps are timezone-sensitive
- For Go-Live, the operator provides the timestamp manually in TMS clock domain
- A safety overlap margin (e.g., watermark - 10 minutes) is needed because re-processed records are harmless (resolvers check `Supports(old, new)`)

**Impact:** Developers will implement a naive timestamp filter that may miss records due to clock drift or timezone mismatch.

**Fix:** PBI must specify that the watermark comes from the endpoint input (not auto-derived), is in TMS clock domain, and must include a configurable safety margin.

### TMS database load protection missing

The concept identifies this as Issue #3 with concrete mitigations:
- Time-window slicing for large recoveries (e.g., 15-minute chunks)
- Sequential branch processing instead of parallel (reduces peak load)
- Rate limiting between batch requests
- Configurable batch size

The PBI actually suggests the opposite — "investigate what makes sense to be parallelized" — without the counterweight that parallel branch processing conflicts with TMS load protection.

**Impact:** A parallel implementation will spike TMS database load. TMS databases have hard RAM/CPU constraints.

**Fix:** PBI must reference load protection mitigations from the concept. Parallelization investigation must weigh performance gains against TMS load impact.

### TMS Bridge queries use views with avoidable overhead

The PBI mentions "make the request against the sendung table directly not against the view" as a parenthetical remark. Code review of the TMS Bridge and TMS database schema confirms this concern is real:

| TMS Bridge query | View | Overhead source |
|---|---|---|
| `GetAllUnplanned()` | `v_dis_shipment` | Nested `NOT EXISTS` subquery on `sen_zuord` (checked twice) + `sen.isavis()` per row |
| `GetShipments()` | `v_dis_shipment_all` | `sen.isavis()` per row only |

Neither view JOINs other tables — both read from `sendung` directly. But `sen.isavis(sendung_tix)` internally re-fetches the full `sendung` row via `SEN.GET()` just to extract `STATUS_8`, a field already available in the row. This is an avoidable round-trip per shipment.

The CDC Recovery mechanism uses `GetAllUnplanned()` → `v_dis_shipment`. The concept's ~10x overhead measurement was against `v_dis_shipment_all`, which has *less* overhead than `v_dis_shipment`. The actual overhead of `v_dis_shipment` is unmeasured and likely higher due to the `sen_zuord` subquery.

**Fix:** This should be a conscious implementation decision, not an afterthought. The team should measure `v_dis_shipment` vs. raw `sendung` with equivalent filters early in the implementation to determine if a TMS Bridge change (new query endpoint or view optimization) is warranted.

### SaveChangesAsync refactoring framed as performance optimization, not correctness

The PBI says "call SaveChangesAsync only after we finished updating the shipment" — correct direction, but the concept frames this as **per-shipment transaction isolation** (`BeginTransaction` / `Commit` / `Rollback`). One shipment failing must not abort others. This is a correctness requirement that also enables the structured per-shipment error report in the endpoint response.

**Impact:** Without explicit transaction isolation, a single resolver exception can abort the entire sync across all branches.

**Fix:** PBI must specify per-shipment transaction boundaries with rollback-on-failure, not just SaveChangesAsync batching.

### Old-state derivation risk not mentioned

The concept documents a confirmed refinement caveat (2026-05-22): the `LegEntity -> GoogleBucketShipmentData` mapping assumes leg-inherited fields never diverge per-leg. Maximilian confirmed that future leg splitting (VL sub-legs) is planned but agreed this is a known future concern, not a Go-Live blocker.

**Impact:** Developers implementing the mapper without this context may not flag regressions when leg-splitting is introduced later.

**Fix:** Add a note that the old-state derivation strategy depends on shipment-level fields being identical across all legs of a shipment.

---

## PBI #124826 — Expose endpoint (2 SP)

The PBI correctly identifies the need for per-depot and all-depots flexibility and mentions returning success/failure information. The following gaps remain:

### Missing the primary input — timestamp

The concept explicitly says the endpoint receives a **time range** (outage start timestamp) from operations. This is the watermark — the entire HWM mechanism depends on it. The PBI says "Design the input and the response" but does not mention the timestamp parameter.

**Impact:** The endpoint design will be incomplete. Without a timestamp input, the mechanism cannot perform watermark-based recovery.

**Fix:** PBI must specify that the endpoint accepts a timestamp (in TMS clock domain) as a required input alongside branch selection.

### Authorization not specified

The concept says "Operations/admin roles only." This endpoint can delete and modify leg data across all branches. It needs explicit role-gating.

**Impact:** Endpoint may ship without authorization, allowing any authenticated user to trigger recovery.

**Fix:** Add authorization requirement to the PBI description.

### Two-step process not reflected

The concept is explicit that recovery is two steps:
1. **Inserts/Updates:** Query TMS for shipments with `u_time > watermark`
2. **Deletes:** Check unplanned local leg shipment IDs against TMS

The PBI treats it as a single black-box trigger.

**Impact:** The endpoint may not orchestrate both steps, or may miss the delete detection entirely.

**Fix:** PBI description should reflect the two-step nature so the endpoint design accounts for both.

### Response structure vague

"Return enough information" needs to be concrete:
- Per-branch status (success / partial failure / failure)
- Per-shipment insert/update/delete counts
- Per-shipment errors with shipment IDs
- Overall success/partial-failure/failure status

The concept already describes this as "structured per-shipment error report."

**Fix:** Specify expected response structure in the PBI or in an acceptance criterion.

---

## PBI #124827 — QA Testing (2.5 SP)

The PBI covers insert/update/delete scenarios, idempotency check, multi-branch failure isolation, partial-shipment failure isolation, and performance testing. The following gaps remain:

### Insert and update test cases not separated

The PBI says: "For shipment insertion make sure we cover the basic cases for the different type of updates: flat fields update, lot generation fields update, traffic mode field updates."

Those update types apply to the **UPDATE** path (existing legs in CloudSQL). INSERT always goes through `NewShipmentCreatedResolver` — it creates legs from scratch based on traffic mode. The correct test matrix:

| Change type | Test focus |
|---|---|
| **Insert** | New shipment in TMS, no local legs -> legs created, lot assigned. Cover different traffic modes (1-4) for leg extraction. |
| **Update** | Shipment exists in TMS and locally -> flat fields, lot generation fields, traffic mode transitions (12 resolvers for 4x3 mode changes) |
| **Delete** | Shipment absent from TMS, local unplanned legs exist -> legs + lots + assignments cleaned up |

**Fix:** Separate insert and update test cases clearly. Insert tests should cover traffic mode variations for leg extraction, not field update types.

### Delete detection scope not tested

The PBI does not mention testing that deletion detection is **scoped to unplanned legs**. A dispatched leg whose parent shipment is absent from TMS should **not** trigger delete resolution.

**Impact:** Without this test case, a regression could cause dispatched/planned legs to be incorrectly deleted during recovery.

**Fix:** Add test case: "Verify that dispatched/planned legs are excluded from delete detection."

### Timestamp / clock domain edge cases missing

No test cases for:
- Different watermark values and their effect on recovered record set
- Safety margin behavior (watermark - N minutes)
- Behavior when TMS `u_time` and local `UpdatedAt` diverge significantly

**Fix:** Add edge case tests for timestamp handling.

### TMS load observation missing

"Test performance" should include monitoring TMS database resource consumption during the test, not just response time. The concept explicitly flags TMS database load as unmeasured.

**Fix:** Performance test should include TMS-side resource monitoring (CPU, memory, connection count) or at minimum document that this was not observed.

---

## PBI #123931 — Automated data loss tests (Blocked)

**Stale — references removed PBI #123929.** Description says "Setup a testing environment that allows to test the acceptance criteria of #123929" — but #123929 has since been **Removed**.

This PBI needs an updated description before work can start. It should either be:
- **Removed** if the intent is covered by #124827
- **Rewritten** to reference current PBIs (#124824, #124826) if end-to-end data loss simulation is still desired as a separate work item beyond #124827's scope

---

## Previously Missing PBIs

The concept's Phase 1 backlog listed items that had no corresponding PBI. Two have now been created:

### TMS Load Evaluation → created as #125381

**Concept reference:** [Issue #3](cdc-recovery-sendung-data-sync.md#3-tms-database-load-protection), [Open Process Question #5](cdc-recovery-sendung-data-sync.md#open-process-questions), [Backlog item "TMS load evaluation"](cdc-recovery-sendung-data-sync.md#phase-1-go-live)

Coordinate with Nagel on acceptable query patterns before production use. Collect concrete query examples during implementation. TMS databases have hard RAM/CPU constraints.

**Why this matters:** This is a **pre-production blocker**. The concept explicitly states: "TMS database load impact unmeasured — must be evaluated with Nagel before production use."

### Operations Runbook → created as #125382

**Concept reference:** [Backlog item "Runbook"](cdc-recovery-sendung-data-sync.md#phase-1-go-live)

Phase 1 is manually triggered. Someone in operations needs to know:
- How to detect that CDC is down ([Open Process Question #1](cdc-recovery-sendung-data-sync.md#open-process-questions))
- When to declare an outage ([Open Process Question #2](cdc-recovery-sendung-data-sync.md#open-process-questions))
- How to determine the correct timestamp to provide
- How to call the endpoint
- What to check in the response
- What to do if recovery partially fails

### Direct Table Access (TMS Bridge) → no separate PBI needed

**Concept reference:** [Issue #6](cdc-recovery-sendung-data-sync.md#6-view-vs-direct-table-access), [Backlog item "Direct table access"](cdc-recovery-sendung-data-sync.md#phase-1-go-live)

The concept recommended querying the raw `sendung` table instead of the `v_shipment_all` view (~10x overhead). Code review of the TMS Bridge and TMS database schema clarifies the actual situation:

| TMS Bridge query | View used | Source table | Overhead |
|---|---|---|---|
| `GetAllUnplanned()` | `v_dis_shipment` | `sendung` (single table, no JOINs) | **Nested EXISTS subquery** on `sen_zuord` + `sen.isavis()` function call per row |
| `GetShipments()` | `v_dis_shipment_all` | `sendung` (single table, no JOINs) | `sen.isavis()` function call per row only |

Neither view JOINs other tables. The overhead comes from:
1. **`v_dis_shipment`**: a nested `NOT EXISTS` subquery checking `sen_zuord` twice (filters out shipments with certain assignment relationships) — this is the primary cost driver
2. **`sen.isavis(sendung_tix)`**: called per row in both views. The numeric overload internally re-fetches the full `sendung` row via `SEN.GET()` just to extract `STATUS_8` — a field already available in the row. This is an avoidable round-trip.

The CDC Recovery mechanism uses `GetAllUnplanned()` → `v_dis_shipment`. The concept's ~10x measurement was against `v_shipment_all` (likely `v_dis_shipment_all`), which has less overhead than `v_dis_shipment`. The actual overhead of `v_dis_shipment` is **unmeasured and likely higher** due to the `sen_zuord` subquery.

**Recommendation:** No separate PBI needed — this should be evaluated as part of #125381 (TMS load evaluation). Measure `v_dis_shipment` vs. raw `sendung` with equivalent filters to determine if a TMS Bridge change is warranted.

---

## Summary

The PBIs capture the shape of the work (implement mechanism, expose endpoint, test it) but miss several concept-critical details that will lead to rework if not addressed before implementation starts.

**Highest-priority gaps:**

| Gap | Affected PBI | Risk |
|-----|-------------|------|
| Delete detection must be scoped to unplanned legs only | #124824 | Unnecessary TMS load, architectural deviation |
| Timestamp is a required endpoint input | #124826 | Endpoint unusable without it |
| TMS load protection mitigations not specified | #124824 | TMS database stability risk in production |
| TMS load evaluation with Nagel | #125381 (created) | Pre-production blocker |
| #123931 references removed PBI | #123931 | Stale description, needs update before work can start |

---

## Document History

| Date       | Author       | Change      |
|------------|--------------|-------------|
| 2026-06-17 | Matthias Max | PBI review created |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
