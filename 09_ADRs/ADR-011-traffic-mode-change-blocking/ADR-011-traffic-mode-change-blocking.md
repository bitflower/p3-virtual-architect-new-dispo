# [ADR011] Traffic Mode Change Blocking for Disposed Shipments

**Status:** Approved
**Decision Date:** 2026-06-11
**Date:** 2026-06-15
**Deciders:** Patrick Uschmann (decision owner), Matthias Max (P3 Architect), Maximilian Kehder, Joachim Schreiner | **Notified:** Christian Lang

## Context

When a shipment's traffic mode changes in UniFace (classic TMS) and the change crosses the pickup/main-haul boundary (e.g. from pre-carriage to main-haul), the shipment's pickup leg type changes. New Dispo reacts correctly -- it removes the old leg and creates a new leg of the correct type. However, the TMS database does not clean up the orphaned transport order assignment, leaving an inconsistent state: the driving instruction references a phantom leg that no longer exists in New Dispo.

This is a TMS-internal data integrity problem. The change originates in TMS, and the orphaned assignment is a TMS-internal artifact. For Go-Live, all known data integrity risks on PROD must be eliminated.

Key constraints:

1. **Go-Live deadline**: June 16, 2026 -- no capacity for architectural changes
2. **Top-Down only**: New Dispo operates as a remote control for TMS. Bottom-Up synchronization (New Dispo writing corrections back to TMS) is explicitly de-scoped for this release
3. **TMS team capacity**: No capacity for a TMS-internal fix (Option A) before Go-Live
4. **Existing precedent**: Main-haul transport orders already block traffic mode changes in long-distance operations (Fernverkehr)

#### Options Considered

**Option A: TMS owns its own data integrity** -- Extend TMS-internal database logic to clean up orphaned transport order assignments when a traffic mode change crosses the pre-carriage/main-haul boundary. Alternatively, TMS blocks the change when the shipment is assigned (precedent: main-haul TAs already block this).

* Architecturally correct: each system is responsible for its own data consistency
* Passes the isolation test -- without New Dispo, the same orphaned assignment would occur
* No distributed transaction problem; everything stays within the TMS transaction boundary
* **TMS team has no capacity to implement this before Go-Live**

**Option B: New Dispo corrects TMS data via CDC** -- New Dispo detects the traffic mode change via CDC, then calls the TMS Bridge to clean up the orphaned assignment in TMS.

* Joachim Schreiner proposed this approach: CDC detects the change, invokes TMS cleanup function before creating new legs
* Would solve the immediate problem without TMS-side changes
* **Makes TMS data integrity dependent on New Dispo availability** -- if New Dispo is down, TMS stays inconsistent
* **Introduces a distributed transaction problem** -- TMS Bridge call and New Dispo state change are not atomic; TMS operations are not idempotent, making automatic recovery unreliable
* **Sets architectural precedent** -- every future TMS integrity issue becomes a candidate for "New Dispo should fix it", shifting the contract from "New Dispo mirrors TMS state" to "New Dispo maintains TMS state"
* **Performance impact** -- every cross-boundary traffic mode change requires additional roundtrip requests from New Dispo Backend via TMS Bridge back to TMS database, increasing CDC event processing latency

**Option C: Block traffic mode changes when shipment has a disposed leg (Go-Live interim)** -- Extend the existing blocking mechanism in UniFace to prevent traffic mode changes that would alter the leg type when the shipment has a disposed leg in New Dispo.

## Decision

**Option C -- Block traffic mode changes when a disposed leg exists.** Decided unanimously on 2026-06-11 in the Dispo-Blocker meeting. Joachim Schreiner implements the blocking rules in the TMS database logic.

The blocking rules depend on which leg type is currently disposed:

| Disposed Leg | Allowed Changes | Blocked Changes | Reason |
|---|---|---|---|
| Main-haul leg disposed | None | All changes blocked | Main-haul is the primary dispatch unit |
| Only pre-carriage leg disposed | Mode 2 <-> 4 | Modes 2/4 to 1/3 and modes 1/3 to 2/4 | Switch between modes 2 and 4 does not affect pre-carriage. Switching to mode 1/3 would remove the pre-carriage leg |
| No leg disposed | All | None | No disposition, no risk |

Traffic mode mapping reference:

| TMS Traffic Mode | New Dispo Traffic Mode | Pickup Leg Type |
|---|---|---|
| 34 | 1 | Main-haul (HL) |
| 30 | 2 | Pre-carriage (VL) |
| 3 + no pre-carriage | 3 | Main-haul relay loading (HL) |
| 3 + with pre-carriage / 31 / 32 | 4 | Pre-carriage (VL) |

Dispatcher workaround when a traffic mode change is needed on a disposed shipment: (1) remove the leg from the transport order in New Dispo, (2) change the traffic mode in TMS/OMS, (3) re-plan the newly created leg.

## Rationale

This is an interim Go-Live solution. The architectural decision between Option A and Option B is deferred to post-Go-Live.

* **Option C chosen** because it is the only option deliverable before Go-Live (June 16, 2026). It eliminates the data integrity risk by preventing the problematic operation rather than handling its consequences. The blocking pattern already exists for main-haul transport orders in long-distance operations, so this extends a proven mechanism with minimal effort. The trade-off is dispatcher friction (three-step workaround) and a deferred root-cause fix.

* **Option A rejected for Go-Live** -- architecturally the correct long-term solution. Each system should own its own data consistency, and the isolation test confirms this: even without New Dispo, the orphaned assignment would exist. However, the TMS team has no capacity before Go-Live. Recommended path for post-Go-Live.

* **Option B rejected** -- it would be the first instance of New Dispo assuming responsibility for TMS-internal data integrity, which is not a bug fix but an architectural direction change with compounding consequences: (1) TMS data consistency becomes dependent on New Dispo availability, (2) distributed transaction problem with non-idempotent TMS operations, (3) precedent effect shifting the system contract from "New Dispo mirrors TMS state" to "New Dispo maintains TMS state", (4) CDC pipeline performance degradation from additional roundtrips, (5) all deployment branches gain a hard runtime dependency on New Dispo. Bottom-Up synchronization was explicitly de-scoped for this release.

## Consequences

* **Positive**:
  * Orphaned transport order assignment risk eliminated for Go-Live
  * No architectural precedent set -- Option A vs. B decision remains open for post-Go-Live

* **Negative**:
  * Dispatchers must follow a three-step workaround (unassign, change, re-plan) instead of changing traffic mode directly
  * Blocking rules add operational complexity that must be communicated to dispatchers
  * Post-Go-Live decision (Option A vs. Option B) still required to address the root cause

## Related ADRs

* [ADR-010: CDC Recovery Strategy: Sendung Data Sync](../ADR-010-cdc-recovery-sendung-data-sync/ADR-010-cdc-recovery-sendung-data-sync.md) -- covers the CDC pipeline that delivers traffic mode changes to New Dispo; recovery strategy for CDC outages
* [ADR-006: Oracle CDC Solution Selection](../ADR-006-oracle-cdc-solution-selection/ADR-006-oracle-cdc-solution-selection.md) -- the CDC infrastructure (Striim) that detects traffic mode changes from TMS


## Document History

| Date       | Author       | Change      |
|------------|--------------|-------------|
| 2026-06-15 | Matthias Max | ADR created |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
