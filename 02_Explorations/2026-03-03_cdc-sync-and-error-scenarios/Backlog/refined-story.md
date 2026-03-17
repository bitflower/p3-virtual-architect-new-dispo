# User Story: CDC Event Processing Failure - Implement Retry & Error Handling

**Status:** Draft - Pending team refinement for solution selection

---

## User Story

**As a** system operator / developer
**I want** CDC events to be retried automatically when processing fails
**So that** TMS changes are not lost and New Dispo remains synchronized with TMS database

---

## Problem Statement

### Current Behavior (Bug)

The CDC event processing endpoint returns **HTTP 200 OK even when event processing fails**. This causes Google Pub/Sub to acknowledge the message prematurely, preventing automatic retry. The event is lost forever and New Dispo falls out of sync with TMS.

**Code Location:** `ConsumeEventCommandHandler.cs:53-57`

```csharp
catch (Exception ex)
{
    result.IsEventSuccess = false;
    _logger.LogError(ex, "Error processing Pub/Sub push message");
    // ⚠️ HTTP 200 OK returned - Pub/Sub considers message delivered
}
return result; // Message acknowledged, won't be redelivered
```

### Architecture Context

```
TMS Database (sendung table)
  ↓ Google Datastream (CDC)
Cloud Storage Bucket
  ↓ Pub/Sub Notification
Google Pub/Sub (Push Subscription)
  ↓ HTTP POST /api/CDC/consume-event
New Dispo Backend (Cloud Run)
  ↓ ConsumeEventCommandHandler.Handle()
  ↓ Event Handler (NewShipmentCreated, ShipmentUpdated, etc.)
  ❌ Processing fails (DB unavailable, mapping error, constraint violation)
  ✓ HTTP 200 OK returned anyway
  ✗ Event lost forever
```

### Impact

- **Data Loss:** CDC events are consumed but not processed
- **Data Inconsistency:** TMS contains shipments that are invisible in New Dispo
- **No Retry:** Pub/Sub does not redeliver acknowledged messages
- **Silent Failure:** Operators unaware of lost events
- **Manual Recovery:** No tool to replay lost CDC events

### Root Cause

HTTP status code determines Pub/Sub acknowledgment behavior:
- **HTTP 2xx** → Message acknowledged (won't retry)
- **HTTP 5xx** → Message NOT acknowledged (will retry)

Current implementation returns HTTP 200 OK regardless of processing outcome. The `IsEventSuccess` flag in the response body is **ignored by Pub/Sub**.

**Reference:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md` (Yosif's original problem identification)

---

## Acceptance Criteria

### AC1: Automatic Retry on Transient Failures

**Given** a CDC event fails due to transient error (DB connection lost, timeout)
**When** event processing fails
**Then** the system returns HTTP 5xx status code
**And** Pub/Sub automatically retries the event with exponential backoff
**And** retry continues up to configured maximum attempts (e.g., 5)

**Verification:**
- Intentionally disconnect database during CDC event processing
- Verify HTTP 500/503 returned
- Verify Pub/Sub redelivers message
- Verify successful processing on retry after DB reconnects

---

### AC2: Dead Letter Queue for Permanent Failures

**Given** a CDC event fails permanently (bad data, constraint violation)
**When** maximum retry attempts exceeded
**Then** the event is moved to dead letter topic
**And** event remains in dead letter queue for manual review
**And** alert triggered for dead letter queue depth threshold

**Verification:**
- Send CDC event with invalid data that cannot be processed
- Verify retries occur
- Verify event moved to dead letter topic after max attempts
- Verify event retrievable from dead letter topic

---

### AC3: Comprehensive Error Logging

**Given** a CDC event processing failure
**When** error occurs at any stage
**Then** error logged with:
- Timestamp
- Pub/Sub message ID
- CDC event metadata (table name, operation type)
- TMS shipment ID (if available)
- Processing stage (deserialization, handler selection, event handling)
- Error message and stack trace
- Retry attempt number

**Verification:**
- Review logs for failed CDC events
- Verify all required fields present
- Verify correlation ID traces event through retries

---

### AC4: Event Processing Monitoring

**Given** CDC events being processed
**When** viewing monitoring dashboard
**Then** metrics visible:
- CDC event processing success rate
- CDC event processing failure rate
- Average event processing latency
- Dead letter queue depth
- Retry count distribution

**And** alerts configured for:
- Error rate exceeds threshold (e.g., >5%)
- Dead letter queue depth exceeds threshold (e.g., >10 messages)
- Processing latency exceeds threshold (e.g., >5 seconds)

**Verification:**
- Dashboard displays all required metrics
- Alerts trigger when thresholds exceeded
- Metrics updated in near real-time

---

### AC5: Manual Event Replay (Optional - Solution Dependent)

**Given** failed CDC events in dead letter queue
**When** root cause resolved (e.g., code fix deployed)
**Then** operator can manually trigger reprocessing
**And** events reprocessed successfully
**And** reprocessing outcome logged

**Note:** Implementation depends on selected solution (Event Store vs Dead Letter Queue)

**Verification:**
- Retrieve message from dead letter queue
- Manually trigger reprocessing
- Verify successful processing
- Verify New Dispo data updated correctly

---

## Solution Options (Pending Team Refinement)

**Four approaches documented in:** `problem-2-solutions.md`

### Option A: Fix Push Model + Dead Letter Topic ⭐ **RECOMMENDED**
- **Effort:** Low (1 sprint)
- **Change:** Throw exception on failure → HTTP 500 returned
- **Retry:** Automatic via Pub/Sub retry policy
- **Recovery:** Dead letter queue for manual review

### Option B: Event Store for CDC Events
- **Effort:** Medium (2-3 sprints)
- **Change:** Persist all CDC events before processing
- **Retry:** Background job retries failed events
- **Recovery:** Full audit trail, manual replay tool

### Option C: Idempotent Event Handlers + Deduplication
- **Effort:** Medium (2-3 sprints)
- **Change:** All handlers idempotent, store processed event IDs
- **Retry:** Safe retries without side effects
- **Recovery:** Complements Option A or B

### Option D: Switch to Pull Subscription
- **Effort:** High (2-3 sprints)
- **Change:** Backend pulls from Pub/Sub, explicit ack/nack
- **Retry:** Automatic via Pub/Sub (unacknowledged messages)
- **Recovery:** Full control over acknowledgment timing

**Decision Point:** Team refinement to select approach based on effort/benefit trade-off

---

## Definition of Ready (DoR)

- [ ] Solution option selected by team (A, B, C, or D)
- [ ] Technical design reviewed and approved
- [ ] Pub/Sub subscription configuration documented (retry policy, dead letter topic)
- [ ] Impact assessment on Cloud Run scaling/costs reviewed
- [ ] Monitoring dashboard design reviewed
- [ ] Alert threshold values defined
- [ ] Testing strategy defined (including failure injection)

---

## Definition of Done (DoD)

- [ ] Selected solution implemented and deployed
- [ ] HTTP status code behavior corrected (if Option A)
- [ ] Pub/Sub retry policy configured (if Option A)
- [ ] Dead letter topic created and consumer implemented (if Option A)
- [ ] Error logging includes all required fields (AC3)
- [ ] Monitoring dashboard deployed with all metrics (AC4)
- [ ] Alerts configured and tested (AC4)
- [ ] Integration tests cover failure scenarios:
  - [ ] Transient failures (DB connection lost)
  - [ ] Permanent failures (bad data)
  - [ ] Retry behavior validated
  - [ ] Dead letter queue handling validated
- [ ] Documentation updated:
  - [ ] Architecture diagram updated
  - [ ] Error handling flow documented
  - [ ] Operator runbook for dead letter queue
  - [ ] Alert response procedures
- [ ] Code reviewed and merged
- [ ] Deployed to test environment and validated
- [ ] Deployed to production
- [ ] Monitored for 1 week post-deployment

---

## Technical References

- **Problem Analysis:** `problem-2-cdc-event-processing-failure.md`
- **Solution Options:** `problem-2-solutions.md`
- **Original Issue:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`
- **Code Location:** `Code/Disposition-Backend/.../CDC/Requests/ConsumeEvent/ConsumeEventCommandHandler.cs`

---

## Related Files

- `ConsumeEventCommandHandler.cs` - Main entry point (bug location)
- `NewShipmentCreatedEventHandler.cs` - INSERT handler
- `ShipmentUpdatedEventHandler.cs` - UPDATE handler
- `DeletedShipmentEventHandler.cs` - DELETE handler
- `GooglePubSubServiceSetupExtensions.cs` - Pub/Sub configuration

---

## Risks & Dependencies

**Risks:**
- Solution selection impacts effort (1 sprint vs 3 sprints)
- Retries may cause duplicate processing if handlers not idempotent
- Dead letter queue requires manual monitoring and intervention
- Increased Pub/Sub costs due to retries

**Dependencies:**
- Google Pub/Sub subscription configuration access
- Monitoring infrastructure (dashboard, alerting)
- Code deployment to Cloud Run

**Mitigation:**
- Start with Option A (low effort, high impact)
- Add Option C (idempotency) in follow-up iteration if needed
- Set up monitoring before enabling retries
- Document dead letter queue handling procedures

---

## Estimates

**Pending team refinement and solution selection**

| Solution | Effort | Risk |
|----------|--------|------|
| Option A: Fix Push + DLQ | 1 sprint | Low |
| Option B: Event Store | 2-3 sprints | Low |
| Option C: Idempotent Handlers | 2-3 sprints | Medium |
| Option D: Pull Subscription | 2-3 sprints | Medium |

**Recommendation:** Start with Option A, then incrementally add B and/or C if needed.
