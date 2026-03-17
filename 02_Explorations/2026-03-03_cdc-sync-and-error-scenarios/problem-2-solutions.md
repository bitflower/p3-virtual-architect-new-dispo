# Problem 2 Solutions: CDC Event Processing Failure (Bottom-Up Sync)

**Date:** 2026-03-03
**Status:** Active - solution selection required
**Related Problem:** `problem-2-cdc-event-processing-failure.md`

---

## Summary

Solutions for CDC event processing failures where events are consumed but lost if internal processing fails.

**Goal:** Ensure CDC events are eventually processed even if New Dispo fails the first time.

---

## Option A: Pub/Sub Dead Letter Topic + Retry Logic ⭐ **RECOMMENDED**

Configure Google Pub/Sub to retry failed messages and use dead letter topic.

### Implementation

1. **Return HTTP 500/503** instead of HTTP 200 when event processing fails
2. Configure Pub/Sub subscription with:
   - Retry policy with exponential backoff
   - Maximum retry attempts (e.g., 5)
   - Dead letter topic for messages that exceed retry limit
3. Create separate consumer for dead letter topic with manual processing

### Code Change Required

```csharp
// In ConsumeEventCommandHandler.cs
public async Task<ConsumeEventResponseDto> Handle(...)
{
    try
    {
        await handler.Handle(oldCorrectRecord, newCorrectRecord);
        return new ConsumeEventResponseDto { IsEventSuccess = true };
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error processing Pub/Sub push message");
        // Return failure to trigger Pub/Sub retry
        throw; // Let the controller return 500
    }
}
```

### Pros

- **Minimal code changes** - Only need to throw exception instead of catching it
- **Uses Google Cloud native features** - No custom infrastructure required
- **Automatic retry with backoff** - Built into Pub/Sub
- **Dead letter queue for manual review** - Failed events not lost

### Cons

- Retries may fail repeatedly if root cause persists (e.g., bad data)
- Need manual intervention for dead letter queue
- No guarantee of eventual success for permanent failures

### Effort

**Low** - Can be implemented in 1 sprint

### Risk

**Low** - Well-understood GCP feature, minimal code changes

---

## Option B: Event Store for CDC Events

Persist all CDC events before processing.

### Implementation

1. Store raw CDC event in `CdcEventLog` table
2. Mark as `Pending`
3. Process event
4. Mark as `Processed` or `Failed`
5. Background job retries `Failed` events

### Pros

- **Complete CDC event history** - Full audit trail
- **Can replay events** - Manual recovery possible
- **Manual recovery possible** - Operators can re-trigger processing

### Cons

- Additional database writes (2x per event)
- Storage overhead
- Need background retry job
- More complex error handling

### Effort

**Medium** - Requires DB schema changes, background job implementation

### Risk

**Low** - Straightforward pattern, well understood

---

## Option C: Idempotent Event Handlers + Event Deduplication

Make handlers idempotent and store processed event IDs.

### Implementation

1. Extract unique event ID from CDC metadata
2. Check if event ID exists in `ProcessedEvents` table
3. If exists, skip processing (idempotent)
4. Process event
5. Insert event ID to `ProcessedEvents` table in same transaction

### Pros

- **Allows safe retries** - Can retry without side effects
- **Prevents duplicate processing** - Essential for at-least-once delivery
- **Simple implementation** - Single table, straightforward logic

### Cons

- **All handlers must be idempotent** - Requires careful design
- Need to generate/extract unique event IDs from CDC metadata
- Doesn't solve retry mechanism on its own (complements Option A or B)

### Effort

**Medium** - All event handlers need review and potential refactoring

### Risk

**Medium** - Requires careful verification of idempotency

---

## Monitoring & Alerting (Cross-Cutting)

Regardless of chosen solution, implement:

### Sync Health Checks

- Periodic reconciliation jobs to detect out-of-sync records
- Compare TMS and New Dispo data counts/checksums
- Alert on discrepancies

### Metrics & Dashboards

- Track CDC event processing success/failure rates
- Track average event processing latency
- Alert on error rate thresholds
- Monitor dead letter queue depth

### Structured Logging

- Correlation IDs for CDC events
- Log all processing attempts with status
- Enable troubleshooting and forensic analysis

---

## Recommended Approach

### Immediate (Sprint 1)

✅ **Implement Option A: Pub/Sub Retry + Dead Letter Topic**
- Fix HTTP status code handling (throw exception on failure)
- Configure Pub/Sub subscription retry policy
- Set up dead letter topic
- Create simple dead letter consumer for monitoring

**Rationale:**
- Minimal code changes, low risk
- Solves 90% of transient failures automatically
- Quick win with high impact

### Short-term (Sprint 2-3)

✅ **Add Monitoring & Alerting**
- Set up dashboards for CDC event processing
- Alert on high error rates
- Monitor dead letter queue

### Medium-term (Sprint 4-6)

🔄 **Implement Option B: Event Store**
- Persist all CDC events for audit trail
- Enable manual replay capability
- Background job for retry failed events

### Long-term (Sprint 7+)

🔄 **Implement Option C: Idempotent Handlers**
- Make all event handlers idempotent
- Add deduplication logic
- Enable safe retries without side effects

---

## Implementation Tasks

### Phase 1: Quick Fix (Option A)

- [ ] Modify `ConsumeEventCommandHandler.cs` to throw on failure
- [ ] Update CDC controller to return 500 on exceptions
- [ ] Configure Pub/Sub subscription retry policy (max 5 attempts, exponential backoff)
- [ ] Create dead letter topic
- [ ] Implement dead letter queue consumer (log + alert)
- [ ] Test retry behavior with intentional failures

### Phase 2: Monitoring

- [ ] Add CDC event processing metrics (success/failure/latency)
- [ ] Create dashboard for CDC health
- [ ] Set up alerts for high error rates
- [ ] Monitor dead letter queue depth

### Phase 3: Event Store (Option B)

- [ ] Design `CdcEventLog` schema
- [ ] Implement event persistence before processing
- [ ] Create background job for retry
- [ ] Build manual replay tool

### Phase 4: Idempotency (Option C)

- [ ] Audit all event handlers for idempotency
- [ ] Design `ProcessedEvents` schema
- [ ] Implement deduplication logic
- [ ] Add unique event ID extraction from CDC metadata
- [ ] Test retry scenarios

---

## Testing Strategy

- Integration tests simulating processing failures
- Test retry mechanism with various failure types:
  - DB connection failures (transient)
  - Mapping errors (permanent)
  - Constraint violations (permanent)
- Verify dead letter queue handling
- Test event replay from event store
- Validate idempotency (same event processed twice = same result)

---

## Cross-References

- **Problem Analysis:** `problem-2-cdc-event-processing-failure.md`
- **Original Meeting:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`
- **Related Solutions:** `problem-1-solutions.md` (Top-down sync)
