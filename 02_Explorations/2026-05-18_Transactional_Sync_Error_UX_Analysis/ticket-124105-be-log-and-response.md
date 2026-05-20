# #124105 — [BE] Log Dispo<->TMS transactional issues and return proper response

**State:** Refined | **Sprint:** 46 | **Parent:** #123326 | **Successor:** #123950
**BE Effort:** 1.5 (predates redefined scope — see note below)

---

## Description

> **Effort note:** The BE Effort of 1.5 was estimated before log pairing (AC 4) and error contract unification (AC 3) were added to scope. Worth re-estimating.

This ticket works with existing logging infrastructure (Serilog + Cloud Logging on Cloud Run). There is no dedicated log storage.

Six of seven transactional sync flows (1–6) already detect state divergence between New Dispo and TMS and auto-repair the local database before returning an error. However, what reaches the Frontend today is insufficient for the UX concept and unusable for operations:

- **No incident ID** — no way to correlate a user-facing error with its log entry
- **Bare string error messages** — not machine-readable (e.g., `"Leg has already been assigned to transportorder with ID 1234."`)
- **Three inconsistent error contracts** — HTTP 409 ProblemDetails (Flows 1, 3), HTTP 200 + `ConflictDto[]` (Flows 2, 4), HTTP 200 + `UpsertOperationResponseDto[]` (Flows 5, 6). These must be unified into a single response shape (see AC 3).
- **Generic logging** — sync conflicts logged via `LogError(ex, ex.Message)`, no structured fields
- **Flow 7 failures are invisible** — if TMS deletion succeeds but local cleanup fails, the Backend has all the context at the point of failure (transport order ID, request context, error details) but does not capture or communicate it

This ticket enriches Backend error responses and logging so that:
1. The successor ticket #123950 has structured data to implement the PO-approved severity-based toast UX
2. Operations can investigate failures using a trackable incident ID
3. Flow 7 failures are proactively detectable via log pairing

### What Already Exists (No Rework Needed)

- Sync detection + auto-repair in Flows 1–6
- `HttpContext.TraceIdentifier` in `BaseExceptionHandler` — usable as incident ID (~1 line)
- Same-TO / different-TO distinction in error messages (Flows 3, 4)
- Per-leg `ConflictDto` (Flows 2, 4) and per-item `UpsertOperationResponseDto` (Flows 5, 6)


### Flow 7: What the Backend Already Knows at Failure Time

When a Transport Order deletion succeeds in TMS but local cleanup fails (CloudSQL outage, timeout, crash), the Backend is at the exact point of failure and has:
- The transport order ID (from the request)
- The TMS Bridge confirmation that deletion succeeded (`isDeleted: true`)
- The exception/error from the failed local cleanup
- The request context (`HttpContext.TraceIdentifier`)

This ticket wraps that failure point: attach an incident ID, collect the transport order ID and error details into a structured log entry (AC 2), emit the log pair (AC 4), and return an enriched error response to the Frontend (AC 3) so it can show the Flow 7 error toast with Log ID.

### References

- [Sync Conflict UX Onepager (PO Decisions)](./ux-meeting-onepager.md)

---

## Acceptance Criteria

### AC 1: Incident ID in All Sync Conflict Responses

**Given** any sync conflict is detected (Flows 1–6) or a Flow 7 failure occurs,
**when** the Backend returns an error/conflict response,
**then** the response includes an `incidentId` field containing a unique, request-scoped identifier that matches the corresponding log entry.

*Recommended:* `HttpContext.TraceIdentifier` (~1 line in `BaseExceptionHandler`). On Cloud Run this correlates with Cloud Logging entries. See [incident-id-options.md](./incident-id-options.md).

### AC 2: Structured Sync Conflict Logging

**Given** a sync conflict is detected or a Flow 7 failure occurs,
**when** the Backend logs the event,
**then** the log entry includes structured fields:
- `incidentId` (same value as returned to Frontend)
- `conflictType` (e.g. `AlreadyAssigned`, `SameTransportOrder`, `DifferentTransportOrder`, `AlreadyUnassigned`, `OrphanedAssignment`)
- `affectedEntityType` (Leg / Lot / TransportOrder) and `affectedEntityId`
- `transportOrderId`
- `actionTaken` (`LocalStateRepaired` / `NoRepairPossible`)
- `flowName`

### AC 3: Unified, Enriched Error Response for Frontend

**Given** a sync conflict is detected in any of the 7 flows,
**when** the Backend returns the response,
**then** all flows use a **single, unified response shape** (replacing the current three inconsistent contracts) that includes machine-readable fields sufficient for #123950 to:
- Determine toast severity (info / warning / error) — the Backend provides structured data, the **Frontend classifies severity**
- Display a batch summary (e.g., "3 of 5 assigned, 2 had conflicts")
- Show the incident ID for error-level issues
- Distinguish same-TO vs. different-TO conflicts

The current inconsistency:

| Flows | Current Contract (to be replaced) |
|-------|----------------------------------|
| 1, 3 | HTTP 409 + `ProblemDetails` (via `ConflictException`) |
| 2, 4 | HTTP 200 + `ConflictDto[]` (on branch, not yet merged) |
| 5, 6 | HTTP 200 + `UpsertOperationResponseDto[]` |

The exact unified response shape must be agreed with the Frontend team before implementation. A proposed structure exists in the [exploration](./transactional-sync-error-ux-analysis.md) (section "Proposed Error Response Structure for Frontend").

### AC 4: Log Pairing for Flow 7 (Delete Transport Order)

**Given** a user initiates a Transport Order deletion,
**then** the Backend logs a structured **"deletion initiated"** event (transport order ID, incident ID, timestamp) at the start,
**and** upon successful completion of all cleanup steps, logs a **"deletion finished"** event with the same identifiers.

An unpaired "initiated" event (no matching "finished") indicates orphaned data requiring manual intervention.

---

## Implementation Notes

### Lot-Based Flows (2, 4): Merge Coordination

Flows 2 and 4 are implemented on branch `feature/assing-lot-create-transport-order-from-lot-indempotent` which has merge conflicts and is not yet merged. The unified response contract (AC 3) should be defined and implemented for the merged flows (1, 3, 5, 6, 7) first. Flows 2 and 4 adopt the unified contract when their branch is resolved and merged. Coordinate with the developer to ensure the incident ID and structured logging are included at merge time.

### Minor: Typo in Codebase

Flows 5 and 6 contain `"Conflict occured"` (should be `"Conflict occurred"`). Worth fixing when touching these handlers.

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
