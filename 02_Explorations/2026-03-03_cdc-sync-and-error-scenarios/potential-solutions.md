# Potential Solutions & Architectural Patterns

**Date:** 2026-03-03
**Status:** Proposals / Recommendations
**Related Problems:**
- `problem-1-distributed-transaction-failure.md`
- `problem-2-cdc-event-processing-failure.md`
- `problem-3-external-tms-modifications.md`

---

**Note:** This document contains potential solutions and recommendations. For fact-based analysis, see the problem-specific documents listed above.

---

## 1. Top-Down Sync Solutions (New Dispo → TMS)

### Option A: Saga Pattern (Orchestration)

Implement a saga orchestrator that manages the distributed transaction:

**Pros:**
- Explicit compensation logic for rollback
- Centralized coordination
- Clear audit trail of operations

**Cons:**
- Complex implementation
- Need to write compensation logic for each TMS operation
- Requires saga state persistence

**Implementation Approach:**
```
1. Save intent in New Dispo (e.g., PendingLegAssignment record)
2. Call TMS Bridge mutation
3. If TMS succeeds:
   - Update New Dispo with TMS response data
   - Mark intent as completed
4. If TMS fails:
   - Mark intent as failed
   - Retry with exponential backoff
5. If New Dispo update fails after TMS success:
   - Execute compensation: Call TMS Bridge to undo operation
   - Mark intent as compensated
```

### Option B: Event Sourcing

Store all operations as events, enabling replay and recovery:

**Pros:**
- Complete audit trail
- Can replay events to rebuild state
- Natural fit for distributed systems

**Cons:**
- Significant architectural change
- Complex event schema management
- Need event store infrastructure

### Option C: Outbox Pattern

Write intended TMS operations to a local outbox table, then process asynchronously:

**Pros:**
- Leverages local database transactions
- Reliable message delivery
- Can retry failed operations

**Cons:**
- Eventual consistency (not immediate)
- Need background worker to process outbox
- Adds latency to operations

**Implementation Approach:**
```
1. Begin New Dispo DB transaction
2. Insert records to domain tables (Legs, LotAssignments, etc.)
3. Insert TMS operation intent to Outbox table
4. Commit transaction (atomic)
5. Background worker:
   - Reads outbox entries
   - Calls TMS Bridge
   - Marks outbox entry as processed
   - Retries on failure with exponential backoff
```

### Option D: Two-Phase Commit (2PC)

Use distributed transaction coordinator:

**Pros:**
- True ACID transactions across databases
- Familiar pattern

**Cons:**
- Blocking protocol (impacts performance)
- Not natively supported by PostgreSQL in this architecture
- TMS Bridge would need transaction coordinator support
- Complexity and operational overhead

**Verdict**: Not recommended for this architecture

---

## 2. Bottom-Up Sync Solutions (TMS → New Dispo via CDC)

### Option A: Pub/Sub Dead Letter Topic + Retry Logic

Configure Google Pub/Sub to retry failed messages and use dead letter topic:

**Implementation:**
1. **Return HTTP 500** instead of HTTP 200 when event processing fails
2. Configure Pub/Sub subscription with:
   - Retry policy with exponential backoff
   - Maximum retry attempts (e.g., 5)
   - Dead letter topic for messages that exceed retry limit
3. Create separate consumer for dead letter topic with manual processing

**Code Change Required:**
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

**Pros:**
- Minimal code changes
- Uses Google Cloud native features
- Automatic retry with backoff
- Dead letter queue for manual review

**Cons:**
- Retries may fail repeatedly if root cause persists
- Need manual intervention for dead letter queue

### Option B: Event Store for CDC Events

Persist all CDC events before processing:

**Implementation:**
1. Store raw CDC event in `CdcEventLog` table
2. Mark as `Pending`
3. Process event
4. Mark as `Processed` or `Failed`
5. Background job retries `Failed` events

**Pros:**
- Complete CDC event history
- Can replay events
- Manual recovery possible

**Cons:**
- Additional database writes
- Storage overhead
- Need background retry job

### Option C: Idempotent Event Handlers + Event Deduplication

Make handlers idempotent and store processed event IDs:

**Implementation:**
1. Extract unique event ID from CDC metadata
2. Check if event ID exists in `ProcessedEvents` table
3. If exists, skip processing (idempotent)
4. Process event
5. Insert event ID to `ProcessedEvents` table in same transaction

**Pros:**
- Allows safe retries
- Prevents duplicate processing
- Simple implementation

**Cons:**
- All handlers must be idempotent
- Need to generate/extract unique event IDs

---

## 3. Monitoring & Alerting Solutions

Regardless of chosen pattern, implement:

### Sync Health Checks
- Periodic reconciliation jobs to detect out-of-sync records
- Compare TMS and New Dispo data counts/checksums
- Alert on discrepancies

### Metrics & Dashboards
- Track CDC event processing success/failure rates
- Track TMS Bridge call success/failure rates
- Track average sync latency
- Alert on error rate thresholds

### Structured Logging
- Correlation IDs across TMS Bridge calls and New Dispo operations
- Log all sync operations with status
- Enable troubleshooting and forensic analysis

---

## Recommended Approach

### For Top-Down Sync
- **Short-term**: Implement comprehensive monitoring and alerting
- **Medium-term**: Implement Outbox Pattern for new operations
- **Long-term**: Consider migrating to Event Sourcing for full audit trail

### For Bottom-Up Sync
- **Immediate**: Fix Pub/Sub error handling (return HTTP 500 on failure)
- **Short-term**: Configure dead letter topic and retry policy
- **Medium-term**: Implement event store for CDC events
- **Long-term**: Make all handlers idempotent with deduplication

---

## Implementation Tasks

### Architectural Decision
- Implement distributed transaction pattern (Saga, 2PC, or Event Sourcing)

### Monitoring & Alerting
- Add sync health checks and alerting
- Set up dashboards for sync metrics

### CDC Error Handling
- Implement retry queue and dead letter queue for CDC events
- Add event store for CDC event history

### Documentation
- Document manual recovery procedures for sync failures
- Create runbooks for operators

### Testing
- Add integration tests that simulate failure scenarios
- Test compensation logic
- Test retry mechanisms
