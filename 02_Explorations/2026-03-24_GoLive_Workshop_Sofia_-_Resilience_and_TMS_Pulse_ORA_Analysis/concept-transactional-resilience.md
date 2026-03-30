<h1 style="display: inline; margin: 0; vertical-align: middle;">&#8203;</h1>
<img src="https://dev.azure.com/p3ds/4912016f-16d3-40db-a383-c6ac3d76971c/_apis/git/repositories/1d9090ed-6839-4b9e-86a3-a75f9430a619/Items?path=/.attachments/P3_logo-aff7f4e5-b2c8-4c2c-9cc2-99f2b18bdcd4.svg&download=false&resolveLfs=true&%24format=octetStream&api-version=5.0-preview.1&sanitize=true&versionDescriptor.version=wikiMaster" width="50" style="display: inline-block; margin: 0; vertical-align: bottom; float: right;">


# Transport Order Transactional Resilience – Concept Outline

The requirements need to be aligned with business and IT and show the requirements by the state of **We 25.03.2026**.
The business requirements must be aligned with **Patrick (Client Stakeholder)**.
The technical solution design must be aligned with **Joachim (TMS Team)** and **Christian Lang / Pascal Leicht**.

---

## 1. Objective

Implement a minimal outbox pattern to prevent data inconsistency between New Dispo Database and TMS Database during transport order creation from unplanned lots or legs.

**Business Approval:** Patrick (Client Stakeholder) has approved the manual user-based retry approach as feasible for June 2026 go-live (Workshop: 2026-03-19). This constrains the solution to user-initiated recovery rather than automatic background processing.

* **Business goals and expected impact**
  * Eliminate data synchronization failures (Scenario 2: TMS succeeds, local DB fails)
  * Enable user-initiated recovery for transient failures
  * Maintain data integrity across distributed transactions
  * Provide audit trail for support team intervention

* **Solution approach**
  * Transactional Outbox Pattern (simplified for June go-live)
  * Local-first principle: commit user intent before calling external systems
  * User-initiated retry with idempotency guarantees
  * Support-assisted resolution for complex cases

---

## 2. Context

### Current transport order creation process overview

Transport order creation via drag-and-drop is currently implemented as a synchronous flow:
1. User drags lot/leg from unplanned area
2. Backend calls TMS Bridge to create transport order (returns transportOrderId, legIds, tourPointIds)
3. Backend creates LotAssignment entity in New Dispo DB with TMS-generated IDs
4. Backend commits local transaction

**Current vulnerability:** If step 3 fails after step 2 succeeds, TMS has the transport order but New Dispo DB does not have the corresponding LotAssignment, resulting in data out of sync.

---

### Role of TMS Database as source of truth

The TMS Database acts as the authoritative system for:

* Transport orders
* Legs
* Tour points
* Route optimization data

New Dispo Database maintains local representations (LotAssignmentEntity, LotAssignmentLegLinkEntity) linked via TMS-generated IDs.

---

### TMS Function Contract

**Input Parameters:** `pdis_transportorder.createtransportorderfromleg()`

| Parameter         | Type           | Purpose                                  |
| ----------------- | -------------- | ---------------------------------------- |
| `company`         | INT            | Company ID                               |
| `branch`          | INT            | Branch ID                                |
| `performanceDate` | DATE           | User-selected performance date           |
| `transportMode`   | INT (nullable) | Transport type (60=pickup, NULL=regular) |
| `shipmentId`      | BIGINT         | TMS shipment ID from leg                 |
| `legType`         | VARCHAR        | Leg type ("VL" or "HL")                  |

**Return Values:**

| Field              | Type   | Used In                                 |
| ------------------ | ------ | --------------------------------------- |
| `TransportOrderId` | BIGINT | LotAssignmentEntity.TransportOrderId    |
| `PickupPointId`    | BIGINT | LotAssignmentEntity.PickupTourPointId   |
| `DeliveryPointId`  | BIGINT | LotAssignmentEntity.DeliveryTourPointId |
| `LegId`            | BIGINT | LotAssignmentLegLinkEntity.TmsLegId     |

**Critical Dependency:** These TMS-generated IDs must be stored in New Dispo DB to maintain referential integrity. Loss of these IDs prevents completion of the operation.

---

### Assumptions and constraints

* TMS Bridge API is the only interface to TMS Database
* No distributed transaction (2PC) available across TMS Bridge boundary
* Full Saga Pattern with compensating transactions rejected (complexity, timeline)
* Full automated Outbox Pattern descoped for June (3-4 months implementation)
* Support team (L2/L3 from P3) available for manual intervention

---

## 3. Scope of This Increment

### Overview of included capabilities

* Transactional Outbox table (`TmsSyncOutbox`) in New Dispo Database
* Minimal Outbox Solution: commit user intent before calling TMS
* User-initiated retry mechanism via frontend
* Idempotent retry logic (application-level state checking)
* Support dashboard for failed operations

---

### Non-goals

* Automatic background retry worker (deferred to Q3 2026)
* Exponential backoff with infinite retries
* Circuit breaker pattern for TMS Bridge failures
* Real-time WebSocket status updates

---

## 4. Key Architectural Decisions

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **Table-based outbox** | Workshop decision: "need to store this information anyway somewhere" (transcript line 2398). Provides audit trail, query capability, support dashboard. | More complex than log files, but enables retry and reconciliation. |
| **User-initiated retry** | Patrick approval (Workshop 2026-03-19): "manual step for the user... could be feasible" (transcript lines 1141-1177). | Simpler implementation, fits June timeline. Users must manually trigger recovery. |
| **TmsResponse storage** | Enables idempotency when TMS succeeds but local DB fails. Critical for Scenario 2. | Requires JSONB field, adds storage overhead. |
| **Application-level idempotency** | TMS Bridge doesn't support idempotency keys yet. Use TMS query as fallback using shipmentId/date/legType. | Requires TMS query endpoint, more complex retry logic. |
| **Status state machine** | Clear visibility for support team, enables monitoring and alerting. | Requires state transitions to be carefully managed. |
| **Synchronous processing (v1)** | Inline processing during user request. User waits for initial attempt, can retry on failure. | Users see immediate success/failure. No background worker complexity for June timeline. |

---

## 5. User Stories

**Primary User Story:** Transport Order Creation with Resilience

As a dispatcher, I want to create transport orders from unplanned lots reliably even when temporary database issues occur, with ability to retry failed operations.

**Detailed user stories and acceptance criteria:** See `user-stories.md`

**Failure Scenarios Covered:**
* Scenario 1: TMS call fails (early failure)
* Scenario 2: Local DB failure after TMS success
* Scenario 3: Response lost (network interruption)

**Technical Implementation:** See `implementation-proposal.md` for detailed architecture, database schema, and code examples.

**Visual Flows:** See `solution-flow-diagrams.md` for sequence diagrams and state machines.

---

## 6. API Endpoints

### Transport Order Planning Controller

| Endpoint                                                 | Method | Purpose                                                         |
| -------------------------------------------------------- | ------ | --------------------------------------------------------------- |
| `/api/transport-order-planning/transportorders/from-lot` | POST   | Create transport order (creates outbox entry, processes inline) |
| `/api/transport-order-planning/transportorders/retry`    | POST   | Retry failed outbox entry (user-initiated)                      |
| `/api/transport-order-planning/outbox/{outboxId}/status` | GET    | Query outbox entry status (for frontend polling)                |

### Admin / Support Controller

| Endpoint                                       | Method | Purpose                                                      |
| ---------------------------------------------- | ------ | ------------------------------------------------------------ |
| `/api/admin/outbox/failed`                     | GET    | Query all failed outbox entries (paginated)                  |
| `/api/admin/outbox/{outboxId}/manual-complete` | POST   | Manually mark outbox entry as completed (support resolution) |

---

### Authentication

All endpoints require JWT authentication with dispatcher or admin role.

---

## 7. Open Business Questions

1. **TMS Idempotency Support:**
   - Confirm idempotency status of all TMS endpoints (createtransportorderfromleg, createandaddleg)
   - Which TMS procedures are inherently idempotent vs. require state checking before retry?
   - Can TMS operations be safely retried without creating duplicates?

2. **Retry Policy:**
   - How many user-initiated retries before escalating to "Contact Support"?
   - Recommendation: 1 immediate retry, then manual intervention

3. **Multi-User Visibility:**
   - Should transport orders in "Pending" status be visible to other dispatchers?
   - Recommendation: Hide pending, show only completed (avoid confusion)

4. **Support Process:**
   - Who is designated L2/L3 support contact for June go-live?
   - What database access permissions does support team require?
   - Timeline for support team training?

---

## 8. Non-Functional Requirements

### 1. Performance / Scalability

* (NFR-01-01) (Assumption) The outbox table should accommodate 10,000 entries per month with 30-day retention policy.
* (NFR-01-02) The outbox query endpoint should return status in <500ms for single outbox entry lookup.
* (NFR-01-03) The retry operation should complete in <10 seconds including idempotency checks.

---

### 2. Reliability

* (NFR-02-01) The system should persist user intent to outbox table with 99.99% success ratio (only fails if New Dispo DB is unavailable).
* (NFR-02-02) The system should prevent duplicate transport orders with 99.999% success ratio when user retries failed operations.
* (NFR-02-03) The system should preserve TMS response (transportOrderId, legIds) in outbox table with 99.9% success ratio when TMS succeeds but local DB save fails.
* (NFR-02-04) The system should support idempotent retry operations ensuring no duplicate transport orders are created in TMS.
* (NFR-02-05) The system should handle TMS Bridge timeout (>30 seconds) by marking outbox entry as "Failed" for user retry.
* (NFR-02-06) (Assumption) The system should gracefully handle concurrent retry attempts on same outbox entry by locking entry during processing (Status='Processing').

---

### 3. Data Integrity

* (NFR-03-01) The system should guarantee atomicity of outbox entry creation and local transaction commit (both succeed or both fail).
* (NFR-03-02) The system should store complete TMS input parameters in Payload field for replay capability.
* (NFR-03-03) The system should store complete TMS response in TmsResponse field when TMS operation succeeds.
* (NFR-03-04) The system should maintain referential integrity between LotAssignmentEntity and TmsSyncOutbox entries via EntityId.
* (NFR-03-05) (Assumption) The system should prevent orphaned outbox entries by implementing cleanup job for entries >30 days old with Status='Completed'.

---

### 4. Modifiability / Extensibility

* (NFR-04-01) The system should enable adding new synchronized operation types (e.g., "AddLegToTransportOrder", "UpdateTourPoint") within 2 weeks.
* (NFR-04-02) The system should enable migration to background worker-based outbox processor within 1 month without changing outbox table schema.
* (NFR-04-03) (Assumption) The outbox table schema should support future enhancements (exponential backoff, dead letter queue) without breaking changes.

---

### 5. Manageability

* (NFR-05-01) The following events need to be logged:
  * Outbox entry created with the following properties: OutboxId, OperationType, EntityId, CreatedBy
  * TMS operation failed with the following properties: OutboxId, EntityId, ErrorType, ErrorMessage, AttemptCount
  * Local DB save failed after TMS success with the following properties: OutboxId, EntityId, TmsTransportOrderId, ErrorMessage
  * User retry initiated with the following properties: OutboxId, UserId, AttemptCount
  * Idempotency check detected existing transport order with the following properties: OutboxId, TmsTransportOrderId, Source (TmsResponse vs. TMS query)
  * Manual support intervention with the following properties: OutboxId, SupportUserId, Action

* (NFR-05-02) Alerts should be sent for:
  * Outbox entry in "Failed" status for >15 minutes
  * Outbox entry with AttemptCount >= 3
  * Outbox table growth exceeding 50,000 entries

* (NFR-05-03) The support dashboard should display:
  * All failed outbox entries (last 7 days)
  * Retry success rate (percentage)
  * Average outbox processing time
  * Entries requiring manual review (Status='ManualReview')

---

### 6. Auditability

* (NFR-06-01) The system should preserve outbox entries for 30 days after completion for audit purposes.
* (NFR-06-02) The system should provide full audit trail of retry attempts including timestamp, user, and outcome.
* (NFR-06-03) (Assumption) The system should enable support team to reconstruct full operation history from outbox Payload and TmsResponse fields.

---

### 7. Testability

* (NFR-07-01) The system should support component testing with mocked TMS Bridge responses.
* (NFR-07-02) The system should support integration testing with Test Containers for New Dispo DB.
* (NFR-07-03) The system should cover following failure scenarios in automated tests:
  * TMS call timeout
  * TMS call returns error response
  * Local DB save fails after TMS succeeds
  * User retry with existing TMS response
  * User retry with TMS query fallback
  * Concurrent retry attempts on same outbox entry

---

### 8. Constraints

* (NFR-08-01) The system must not create duplicate transport orders in TMS under any retry scenario.
* (NFR-08-02) The system must not rollback TMS operations (no compensating transactions / Saga pattern).
* (NFR-08-03) The system must remain compatible with existing frontend drag-and-drop UX (202 Accepted + polling acceptable).

---

## 9. Collaboration Guidelines

### Ownership

| Component               | Owner                               | Responsibility                                    |
| ----------------------- | ----------------------------------- | ------------------------------------------------- |
| TmsSyncOutbox Schema    | New Dispo Backend Team              | Database migration, EF Core entity                |
| Outbox Processor        | New Dispo Backend Team              | Processing logic, retry mechanism                 |
| TMS Idempotency Support | TMS Team (Joachim)                  | Evaluate feasibility, timeline for TMS-level keys |
| Frontend Retry UX       | New Dispo Frontend Team             | Error dialog, retry button, polling               |
| Support Dashboard       | New Dispo Backend Team              | Admin endpoints, failed entry queries             |
| Support Runbook         | New Dispo Backend Team + P3 Support | Manual resolution procedures                      |

---

### Interface Contracts

**Backend → TMS Bridge:**
- No changes required for Phase 1

**Frontend → Backend:**
- Existing: `POST /api/transport-order-planning/transportorders/from-lot`
  - Return 202 Accepted with `outboxId` on success
  - Return 500 with `outboxId` and `error` on failure
- New: `POST /api/transport-order-planning/transportorders/retry?outboxId={id}`
  - Return 200 OK with `transportOrderId` on success
- New: `GET /api/transport-order-planning/outbox/{outboxId}/status`
  - Return status JSON for polling

---

## 10. Success Criteria

### Acceptance Criteria for June Go-Live (TBD - Proposals)

- [ ] Zero data inconsistencies detected in reconciliation report (weekly TMS vs. New Dispo DB comparison)
- [ ] <5% of transport order creation operations require user retry (measured over 30 days)
- [ ] <1% of transport order creation operations require support intervention (measured over 30 days)
- [ ] Support team can resolve any failed outbox entry within 15 minutes using provided runbook
- [ ] No frontend UX confusion reported by Sofia team or client (user testing validation)
- [ ] All NFRs validated in staging environment with simulated failures

