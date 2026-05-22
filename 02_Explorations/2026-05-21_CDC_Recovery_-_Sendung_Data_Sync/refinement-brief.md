# CDC Recovery: Sendung Data Sync — Refinement Brief

**For:** Team Refinement Session
**Full concept:** [cdc-recovery-sendung-data-sync.md](./cdc-recovery-sendung-data-sync.md)
**ADR:** [ADR-010](../../09_ADRs/ADR-010-cdc-recovery-sendung-data-sync/ADR-010-cdc-recovery-sendung-data-sync.md)

---

## Problem

When the CDC pipeline fails (network outage, Datastream/Striim failure, WAL slot timeout, etc.), shipment data in New Dispo becomes stale. Dispatchers work with outdated data without knowing it. There is currently no recovery mechanism.

**Scope:** Recovery of the `sendung` table — the single CDC-synced entity between TMS and New Dispo.

---

## Approach: Watermark-Based Recovery

Recovery is a **two-step process**, triggered manually via an endpoint after a detected CDC outage.

**Why manual first?** The recovery mechanism is the building block. Without this building block, automation is not possible. Automation (outage detection, automatic triggering) can be layered on top at any time — but the recovery capability itself must exist first.

**Endpoint inputs (provided by operations):**
- **Branch selection:** Specific branches or all branches
- **Time range:** The outage window (start timestamp), because operations knows when the outage occurred

| Step | What | How |
|------|------|-----|
| 1. Inserts + Updates | Backfill shipments changed during outage window | Query TMS for `u_time > provided timestamp`, apply through existing CDC resolvers |
| 2. Deletes | Detect shipments deleted during outage | Check **unplanned** local leg shipment IDs against TMS, run delete resolver for missing ones |

### Why only unplanned legs for deletes?

**Dispatched/planned shipments are never deleted in TMS** (confirmed by Joachim Schreiner and Patrick Uschmann [PO], 2026-05-21; enforcement being implemented by Joachim/Reinhard).

This reduces delete detection scope from hundreds of thousands to hundreds or thousands of shipment IDs per branch.

**Fallback if constraint proves unreliable:** Yosif's PoC uses a two-query approach — an ID-only query (all unplanned IDs, cheap) for delete detection, plus a time-filtered query for inserts/updates. Does not depend on the constraint.

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

**Key point:** Recovery reuses 100% of existing CDC resolver logic — no new business logic, no divergence risk.

---

## What the PoC Proved

**Branch:** `feature/data-sync-poll-mechanism` (Disposition-Backend, Yosif Mihaylov) — [PoC writeup](../../WIKI/Nagel-CAL-Disposition.wiki/Sandbox-(Internal)/Explorations/2026%2D05%2D21-CDC-Recovery-mechanism%3A-In%2Dmemory-data-sync-service.md)

| What | Result |
|------|--------|
| Full branch sync (~3,000 shipments + resolution) | ~20-25s per branch |
| Resolver reuse | All existing CDC resolvers work unchanged |
| Old-state derivation | `LegEntity` → `GoogleBucketShipmentData` mapper works |
| HWM incremental query (~50 records, 15s window) | ~0.5s — Yosif's verbal estimate from separate analysis, **not implemented in PoC** |

**Not yet in PoC:** Watermark-based `u_time` filtering (PoC loads all unplanned shipments, no timestamp filter), scoped delete detection (PoC does full-state comparison), per-shipment transaction isolation (one resolver failure currently aborts entire sync).

**Good news:** The TMS Bridge GraphQL already supports `updateTime` filtering — no TMS Bridge changes needed for HWM queries.

---

## Open Questions for Refinement

| # | Question | Category |
|---|----------|----------|
| 1 | **Watermark: external input vs. auto-derived?** For Go-Live, operations provides the outage start timestamp as endpoint input. For the future, should the system also be able to auto-derive it?<br>A: `MAX(UpdatedAt)` from local CloudSQL entities with safety margin (clock domain mismatch between TMS `u_time` and local write time)<br>B: Persist the last successfully processed TMS `u_time` during CDC processing (stays in TMS clock domain, no conversion needed, but new state to maintain) | Development |
| 2 | **Who triggers recovery?** DevOps? Operations? Automated? | Operational |
| 3 | **How do we detect that CDC is down?** Timeout? Monitoring? Active heartbeat? | Operational |
| 4 | **Is recovery idempotent?** Running it twice should be safe — likely yes (resolvers check changes), needs explicit verification | Development |
| 5 | **Multi-instance concurrency:** If Backend runs multiple instances, how do we prevent parallel recovery runs? Options: DB flag, leader election, or accept idempotent duplicate processing | Development |
| 6 | **TMS database load tolerance:** Acceptable query volume? Must be answered by Nagel before production use | Operational |
| 7 | ~~**Is the TMS delete constraint enforced?**~~ **Confirmed** by Joachim Schreiner and Patrick Uschmann (PO), 2026-05-21. Enforcement being implemented by Joachim/Reinhard. Fallback remains available: check all local leg shipment IDs if needed | Resolved |

---

## Backlog Items (Go-Live)

| Item | Description |
|------|-------------|
| Refine PoC | Implement watermark-based query, scoped delete detection, per-shipment transaction isolation, clean up naming/error handling |
| Expose endpoint | Controller with proper authorization (operations/admin) |
| API design | Support all-branches and single-branch invocation |
| Direct table access | Ensure TMS Bridge query uses `sendung` table, not `v_shipment_all` view |
| TMS load evaluation | Coordinate with Nagel on acceptable query patterns |
| Runbook | Document recovery procedure for operations team |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
