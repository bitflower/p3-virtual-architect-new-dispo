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

## Option D: Switch from Push to Pull Subscription

Switch from push-based (Pub/Sub → Backend) to pull-based (Backend → Pub/Sub) subscription model.

### Current Model (Push)

```
Pub/Sub → HTTP POST → New Dispo Backend → Returns 200 OK (premature ack!)
```

**Problem:** Backend returns HTTP 200 before processing completes → message acknowledged prematurely

### Proposed Model (Pull)

```
New Dispo Backend → Pulls messages from Pub/Sub → Processes → Explicitly calls ack()
```

**Benefit:** Backend controls acknowledgment timing → only ack after successful processing

### Implementation

**1. Change Pub/Sub subscription from Push to Pull:**
```bash
gcloud pubsub subscriptions update backend-topic-sub \
  --push-endpoint="" \
  --ack-deadline=60
```

**2. Implement background pull worker service:**
```csharp
public class CdcPullWorkerService : BackgroundService
{
    private readonly SubscriberClient _subscriber;
    private readonly IEventHandler[] _eventHandlers;
    private readonly ILogger<CdcPullWorkerService> _logger;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var subscriptionName = new SubscriptionName(projectId, subscriptionId);

        await _subscriber.StartAsync((message, cancellationToken) =>
        {
            try
            {
                // Deserialize CDC event
                var json = Encoding.UTF8.GetString(message.Data.ToByteArray());
                var cdcEvent = JsonConvert.DeserializeObject<GoogleRecordChangeDto>(json);

                // Find and execute handler
                var handler = _eventHandlers.FirstOrDefault(h => h.Supports(cdcEvent));
                await handler.Handle(cdcEvent);

                _logger.LogInformation("CDC event processed successfully: {MessageId}", message.MessageId);

                // ✅ Explicitly acknowledge only on success
                return Task.FromResult(SubscriberClient.Reply.Ack);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "CDC event processing failed: {MessageId}", message.MessageId);

                // ❌ Don't acknowledge - Pub/Sub will redeliver automatically
                return Task.FromResult(SubscriberClient.Reply.Nack);
            }
        });

        // Keep worker running
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }
}
```

**3. Deploy as long-running worker:**
- **Option A:** Cloud Run Job with `minInstances: 1`
- **Option B:** GKE Deployment
- **Option C:** Compute Engine VM
- **Option D:** Cloud Functions 2nd Gen (abstracts pull internally)

### Pros

- **Explicit acknowledgment control** - Only ack after successful processing (solves core problem)
- **Automatic retry** - Unacknowledged messages automatically redelivered by Pub/Sub
- **Backpressure handling** - Backend controls consumption rate based on capacity
- **No HTTP endpoint exposure** - No need for public webhook endpoint
- **Simpler error handling** - Don't need to worry about HTTP status codes
- **Flow control** - Can pause/resume pulling based on system health (e.g., DB down)

### Cons

- **Requires persistent worker** - Can't leverage Cloud Run's request-driven scaling as effectively
- **Deployment complexity** - Need long-running service or scheduled job
- **Polling overhead** - Adds latency (mitigated by streaming pull)
- **Infrastructure management** - Need to manage pull workers (health checks, restarts)
- **Not using existing Cloud Run HTTP pattern** - Different from current architecture

### Effort

**High** - Significant architectural change:
- Implement new background service
- Change deployment model (Cloud Run Job or GKE)
- Update Pub/Sub subscription configuration
- Remove existing HTTP endpoint
- Test pull worker behavior

Estimated: 2-3 sprints

### Risk

**Medium**
- New deployment pattern (persistent workers vs. request-driven)
- Need to manage worker lifecycle
- Different scaling characteristics than current Cloud Run setup

---

## Comparison: Push vs Pull

| Aspect | Push (Current) | Push (Fixed - Option A) | Pull (Option D) |
|--------|---------------|------------------------|-----------------|
| **Ack Control** | ❌ Poor (HTTP 200 bug) | ✅ Good (throw on error) | ✅ **Excellent (explicit)** |
| **Cloud Run Fit** | ✅ Perfect | ✅ Perfect | ⚠️ Acceptable (needs always-on) |
| **Latency** | ✅ Low (immediate push) | ✅ Low (immediate push) | ⚠️ Higher (polling interval) |
| **Backpressure** | ⚠️ Limited | ⚠️ Limited | ✅ **Full control** |
| **Code Changes** | 🟡 Minimal (fix bug) | 🟡 Minimal (fix bug) | 🔴 **Significant (new worker)** |
| **Deployment** | ✅ Existing | ✅ Existing | 🔴 **New infrastructure** |
| **Effort** | 🟢 Low (1 sprint) | 🟢 Low (1 sprint) | 🔴 **High (2-3 sprints)** |
| **Solves Problem** | ❌ No | ✅ **Yes** | ✅ **Yes** |

---

## When to Choose Pull (Option D)

Consider pull model if:
- ✅ Team wants **explicit control** over acknowledgment patterns
- ✅ Backend needs **sophisticated backpressure control** (e.g., pause consumption when DB unhealthy)
- ✅ Moving to **GKE or always-on infrastructure** anyway
- ✅ Need **fine-grained control** over message consumption rate
- ✅ Want to **avoid HTTP endpoint** exposure concerns
- ✅ Team has experience with **long-running worker patterns**

**Recommendation:** Only choose pull if you have **strategic reasons beyond solving Problem 2**. The core acknowledgment bug is solved equally well by fixing push (Option A) with much less effort.

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

### Alternative: Pull Model (Option D)

🤔 **Consider if strategic reasons exist:**
- If moving to GKE or persistent worker infrastructure
- If explicit backpressure control becomes critical
- If team wants explicit acknowledgment patterns

**Note:** Only pursue if there are benefits beyond solving Problem 2, as Option A (fixed push) solves the core issue with much less effort.

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

### Alternative: Pull Model (Option D)

**Only pursue if strategic reasons exist beyond solving Problem 2**

- [ ] **Design Phase:**
  - [ ] Choose deployment model (Cloud Run Job / GKE / Compute Engine)
  - [ ] Design pull worker architecture
  - [ ] Plan scaling and health check strategy
- [ ] **Implementation:**
  - [ ] Implement `CdcPullWorkerService` background service
  - [ ] Implement message acknowledgment logic (Ack/Nack)
  - [ ] Add graceful shutdown handling
  - [ ] Configure worker health checks and restarts
- [ ] **Infrastructure:**
  - [ ] Convert Pub/Sub subscription from Push to Pull
  - [ ] Deploy pull worker service
  - [ ] Set up worker monitoring and alerting
  - [ ] Remove/deprecate existing HTTP endpoint
- [ ] **Testing:**
  - [ ] Test pull worker startup and shutdown
  - [ ] Test acknowledgment behavior (Ack on success, Nack on failure)
  - [ ] Test worker restart and message redelivery
  - [ ] Load test pull throughput and latency
  - [ ] Test backpressure scenarios (slow processing)

---

## Testing Strategy

### Common Tests (All Options)

- Integration tests simulating processing failures
- Test retry mechanism with various failure types:
  - DB connection failures (transient)
  - Mapping errors (permanent)
  - Constraint violations (permanent)
- Verify dead letter queue handling
- Test event replay from event store (Option B)
- Validate idempotency (same event processed twice = same result, Option C)

### Pull Model Specific Tests (Option D)

- **Worker Lifecycle:**
  - Test worker startup and initial subscription
  - Test graceful shutdown (acknowledge in-flight messages)
  - Test worker restart and message redelivery
- **Acknowledgment Behavior:**
  - Test Ack on successful processing
  - Test Nack on failed processing
  - Test automatic redelivery after Nack
  - Test message redelivery after worker crash (before ack)
- **Performance:**
  - Load test pull throughput vs push
  - Measure latency impact of polling
  - Test concurrent message processing
- **Backpressure:**
  - Test worker pause/resume on DB unavailability
  - Test controlled consumption rate during high load
  - Test message accumulation when worker stopped

---

## Cross-References

- **Problem Analysis:** `problem-2-cdc-event-processing-failure.md`
- **Original Meeting:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`
- **Related Solutions:** `problem-1-solutions.md` (Top-down sync)
