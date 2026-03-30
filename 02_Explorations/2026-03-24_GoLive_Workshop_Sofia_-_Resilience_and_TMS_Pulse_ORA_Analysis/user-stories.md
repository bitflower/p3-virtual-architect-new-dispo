# Transactional Resilience: User Stories

**Date:** 2026-03-25
**Status:** Ready for Refinement
**Related:** `concept-transactional-resilience.md`, `implementation-proposal.md`

---

## User Story 1: Transport Order Creation with Resilience

**Related to:** Scenario 2 Workshop Discussion (2026-03-19)

### WHO
As a dispatcher, I want to create transport orders from unplanned lots so that shipments can be assigned to tours reliably even when temporary database issues occur.

### Description
The system must persist my intent to create a transport order before calling TMS, allowing retry if the operation fails after TMS succeeds but before local state is saved.

### Actors
- Dispatcher (frontend user)
- Backend system
- TMS Bridge
- New Dispo Database
- TMS Database

### Preconditions
* Lot exists in unplanned area with associated legs
* User has selected performance date
* New Dispo Database is available for outbox write

### Postconditions (Success)
* Transport order created in TMS
* LotAssignment created in New Dispo DB with TMS IDs
* Original lot removed from unplanned area
* Outbox entry marked as "Completed"

### Failure Scenarios & Recovery

#### Scenario 1: Early Failure (TMS Call Fails)
**What happens:**
- TMS call fails before or during execution
- Outbox entry status: "Failed"
- No TMS transport order created

**User Recovery:**
- User sees error dialog with [Retry] button
- User clicks retry
- System re-attempts TMS call with same parameters from outbox Payload

#### Scenario 2: Local DB Failure After TMS Success
**What happens:**
- TMS succeeds and returns transportOrderId
- Local DB save fails (timeout, unavailable)
- Outbox stores TMS response before failing

**User Recovery:**
- User sees error dialog with [Retry] button
- User clicks retry
- System uses stored TMS IDs from TmsResponse
- No duplicate transport order created (idempotent)

#### Scenario 3: Response Lost (Network Interruption)
**What happens:**
- TMS executes successfully
- Network failure before response reaches backend
- Outbox entry "Failed" with no TmsResponse

**User Recovery:**
- User sees error dialog with [Retry] button
- User clicks retry
- System queries TMS state using shipmentId/date/legType
- If TO exists in TMS: uses existing IDs
- If TO not in TMS: creates new
- Idempotent handling prevents duplicates

---

## User Story 2: Support Dashboard for Failed Operations

**Priority:** P1 (June Go-Live)

### WHO
As a support engineer, I need to see all failed transport order operations so that I can assist users who report issues and manually resolve persistent failures.

### Description
The system must provide a dashboard showing all outbox entries with status "Failed" or "ManualReview", with ability to view full operation details and manually mark as completed.

### Actors
- Support engineer (L2/L3 from P3)
- Backend system
- New Dispo Database

### Preconditions
* Support engineer authenticated with admin role
* Outbox entries exist with Failed or ManualReview status

### Postconditions
* Support can view failed operation details (Payload, TmsResponse, error messages)
* Support can manually mark entry as completed (with comment)
* Support can see retry history (AttemptCount, LastAttemptAt)

### Acceptance Criteria
- [ ] Dashboard shows entries from last 7 days by default
- [ ] Filterable by: status, operation type, date range, user
- [ ] Shows: OutboxId, OperationType, CreatedAt, AttemptCount, ErrorMessage
- [ ] Detail view shows: full Payload (JSON), full TmsResponse (JSON), timestamps
- [ ] Manual complete action requires confirmation and comment
- [ ] Audit trail preserved after manual resolution

---

## User Story 3: Automatic Cleanup of Completed Operations

**Priority:** P2 (Post Go-Live)

### WHO
As a system administrator, I need completed outbox entries to be automatically cleaned up so that the table doesn't grow indefinitely and impact performance.

### Description
The system must automatically delete outbox entries with status "Completed" that are older than 30 days, preserving audit requirements while maintaining performance.

### Actors
- Background cleanup job
- New Dispo Database

### Preconditions
* Outbox entries exist with status "Completed"
* Entries are older than 30 days

### Postconditions
* Old completed entries deleted
* Database table size controlled
* No impact on active retry operations

### Acceptance Criteria
- [ ] Cleanup runs daily at low-traffic time (e.g., 2 AM)
- [ ] Deletes only entries with Status='Completed' AND CompletedAt < (NOW() - 30 days)
- [ ] Batch processing (1000 entries per batch) to avoid locks
- [ ] Logs count of deleted entries
- [ ] Alert if cleanup fails or table exceeds 50,000 entries

---

## Technical PBI: Transactional Outbox Implementation

**Sprint:** TBD (June 2026 Go-Live)
**Story Points:** TBD

### Implementation Details

See detailed technical design in:
- `implementation-proposal.md` - Database schema, C# code, API endpoints
- `solution-flow-diagrams.md` - Sequence diagrams, state machine, decision trees
- `concept-transactional-resilience.md` - NFRs, architectural decisions

### Definition of Done

- [ ] Database migration created and tested (TmsSyncOutbox table)
- [ ] EF Core entity and configuration implemented
- [ ] Outbox creation in `CreateTransportOrderFromLotCommandHandler`
- [ ] Retry endpoint implemented with idempotency logic
- [ ] Status query endpoint for frontend polling
- [ ] Unit tests for all scenarios (A, B, C)
- [ ] Integration tests with Test Containers
- [ ] Frontend retry button and error dialog
- [ ] Support dashboard basic view
- [ ] Documentation updated (API docs, runbook)
- [ ] Code reviewed and approved
- [ ] Deployed to staging and validated

---

## Acceptance Criteria (All Stories)

**For June Go-Live:**

- [ ] Zero data inconsistencies detected in reconciliation report (weekly TMS vs. New Dispo DB comparison)
- [ ] <5% of transport order creation operations require user retry (measured over 30 days)
- [ ] <1% of transport order creation operations require support intervention (measured over 30 days)
- [ ] Support team can resolve any failed outbox entry within 15 minutes using provided runbook
- [ ] No frontend UX confusion reported by Sofia team or client (user testing validation)
- [ ] All NFRs validated in staging environment with simulated failures

---

## Related Documentation

- **Concept:** `concept-transactional-resilience.md`
- **Implementation:** `implementation-proposal.md`
- **Diagrams:** `solution-flow-diagrams.md`
- **Workshop Analysis:** `resilience-transactional-behaviour.md`
- **Failure Scenarios:** `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/tms-sync-failure-scenarios.md`
