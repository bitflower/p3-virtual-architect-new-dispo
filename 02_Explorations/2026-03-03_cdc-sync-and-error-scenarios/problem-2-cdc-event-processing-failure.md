# Problem 2: CDC Event Processing Failure (Bottom-Up Sync)

**Date:** 2026-03-03
**Status:** Active - requires solution
**Meeting Reference:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`

---

## Summary

New Dispo successfully **consumes** CDC events from Google Pub/Sub, but if internal **processing** fails (e.g., DB unavailable, mapping error), the event is **lost forever**. The current implementation returns HTTP 200 OK even on processing failures, causing Pub/Sub to acknowledge the message prematurely without retry.

**Complexity:** Medium (Less complex than distributed transactions)
**Category:** Event Loss After Consumption

---

## Problem Statement

From Yosif's meeting notes (2025-10-10):

> We don't have a mechanism to guarantee that CDC events will be eventually processed if New Dispo fails the first time. The outcome is that New Dispo will not be able to retry processing the event and it will eventually get out of sync.

**Direction:** TMS → New Dispo (Bottom-Up via CDC)

**Trigger:** Any change in TMS database (from any source)

**Root Cause:** Premature message acknowledgment - HTTP 200 OK returned before successful processing

---

## CDC Pipeline Architecture

```
┌─────────────────────┐
│   TMS Database      │ (PostgreSQL / AlloyDB)
│  (Sendung table)    │
└──────────┬──────────┘
           │ CDC Stream (Google Datastream)
           ↓
┌─────────────────────┐
│  Google Cloud       │
│  Storage Bucket     │
└──────────┬──────────┘
           │ Pub/Sub Notification
           ↓
┌─────────────────────┐
│  Google Pub/Sub     │ (Cloud Messaging)
│  Push Subscription  │
└──────────┬──────────┘
           │ HTTP POST with CloudEvent
           ↓
┌─────────────────────┐
│  New Dispo Backend  │ CDC Controller Endpoint
│  ConsumeEvent       │ /api/CDC/consume-event
└─────────────────────┘
```

**Current Model:** Push subscription (Pub/Sub pushes events to New Dispo)

---

## CDC Event Types

Based on code analysis, New Dispo subscribes to these TMS database events:

| CDC Event | TMS Table | Change Type | Handler |
|-----------|-----------|-------------|---------|
| NewShipmentCreated | `sendung` | INSERT | `NewShipmentCreatedEventHandler` |
| ShipmentUpdated | `sendung` | UPDATE | `ShipmentUpdatedEventHandler` |
| DeletedShipment | `sendung` | DELETE | `DeletedShipmentEventHandler` |

---

## Event Processing Flow

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/Requests/ConsumeEvent/ConsumeEventCommandHandler.cs`

```
1. Google Pub/Sub delivers event via HTTP POST (Line 28)
   ↓
2. ConsumeEventCommandHandler.Handle() (Lines 28-60)
   ↓
3. Deserialize CDC event from Base64 (Line 33)
   ↓
4. Find appropriate event handler (Lines 41-42)
   ↓
5. Get Keycloak access token (Line 44)
   ↓
6. Execute handler.Handle() (Line 51)
   ⚠️ Handler may fail here
   ↓
7. Exception caught, logged, IsEventSuccess = false (Lines 53-57)
   ✓ Pub/Sub message ALREADY ACKNOWLEDGED
   ↓
8. Event lost forever - no retry mechanism
```

---

## Failure Pattern

### Current Behavior (Problematic)

**File:** `ConsumeEventCommandHandler.cs:28-60`

```csharp
public async Task<ConsumeEventResponseDto> Handle(ConsumeEventCommand request, CancellationToken cancellationToken)
{
    var result = new ConsumeEventResponseDto { IsEventSuccess = true };
    try
    {
        // Lines 33-42: Deserialize and find handler
        var json = Encoding.UTF8.GetString(Convert.FromBase64String(request.Message.Message.Data));
        GoogleRecordChangeDto? eventDataChanges = JsonConvert.DeserializeObject<GoogleRecordChangeDto>(json)
            ?? throw new InvalidOperationException("Could not deserialize message to GoogleRecordChangeDto");

        IEventHandler handler = _eventHandlers.FirstOrDefault(h => h.Supports(oldRecord, newRecord))
            ?? throw new InvalidOperationException($"No handler for message content: {json}");

        // Line 51: Execute handler - may fail
        await handler.Handle(oldCorrectRecord, newCorrectRecord);
    }
    catch (Exception ex)
    {
        result.IsEventSuccess = false;
        _logger.LogError(ex, "Error processing Pub/Sub push message");
        // ⚠️ Message already acknowledged - no retry will occur
    }

    return result; // Even if IsEventSuccess = false, message is gone
}
```

**Critical Issue:** Google Pub/Sub considers the message successfully delivered when the HTTP endpoint returns **200 OK**. The `IsEventSuccess` flag in the response body has **no effect** on Pub/Sub message acknowledgment - the message is already acknowledged and will not be redelivered.

---

## Example: NewShipmentCreatedEventHandler

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/NewShipmentCreated/NewShipmentCreatedEventHandler.cs`

### What it does (Lines 50-89)

1. Maps CDC shipment data to domain entities
2. Extracts legs from shipment based on traffic mode
3. Finds/creates suitable lots for each leg
4. Adds legs and lots to New Dispo database
5. **Saves changes** (Line 88): `await _appDbContext.SaveChangesAsync();`

### Failure Scenarios

- Database connection lost during SaveChanges
- Constraint violation (duplicate key, foreign key)
- Mapping failure (invalid data from TMS)
- Business logic failure in leg extractor
- Out of memory / timeout during processing

### Result of Failure

- Exception caught by ConsumeEventCommandHandler
- Error logged
- `IsEventSuccess = false` returned
- **CDC event lost forever - TMS shipment never created in New Dispo**

---

## Why This is Problematic

1. **No Retry Mechanism**: If event processing fails, there's no automatic retry
2. **No Dead Letter Queue**: Failed events are not persisted for later review/replay
3. **Silent Failure**: System continues operating, but New Dispo is out of sync with TMS
4. **No Alerting**: Operators may not know events are failing
5. **No Manual Recovery**: No tool to replay CDC events from a specific point in time

---

## Impact Assessment

### What Happens When CDC Event Processing Fails

1. **TMS Database**: Contains the change (new shipment, updated shipment, deleted shipment)
2. **CDC Pipeline**: Event successfully delivered to Pub/Sub and consumed by New Dispo
3. **New Dispo Processing**: Fails during handler execution (Line 51 in ConsumeEventCommandHandler.cs)
4. **Exception Handling**: Exception caught, logged, `IsEventSuccess = false` returned (Lines 53-57)
5. **Pub/Sub Acknowledgment**: Message already acknowledged - will NOT be redelivered
6. **New Dispo Database**: Missing the shipment's legs and lots
7. **Result**: TMS shipment exists but is invisible to New Dispo users
8. **No Automatic Recovery**: Event is lost, no retry mechanism exists

---

## Solution Options

See detailed analysis in: `problem-2-solutions.md`

### Recommended: Pub/Sub Retry + Dead Letter Topic

**Quick Fix (Low Effort, High Impact):**

1. **Return HTTP 500/503** instead of HTTP 200 when event processing fails
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

---

## Questions/Open Items

1. **Current Incident Rate**: How often do CDC event processing failures actually occur in production?
2. **Monitoring**: Are there alerts for detecting CDC processing failures?
3. **Pub/Sub Configuration**: What is the current Pub/Sub subscription configuration? (retry policy, dead letter topic, acknowledgment deadline)
4. **Error Logging**: Where are CDC processing errors currently logged? Is there a centralized error tracking system?
5. **Manual Recovery**: Is there a documented procedure to replay CDC events manually?

---

## Related Files

### New Dispo Backend - CDC Processing

- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/Requests/ConsumeEvent/ConsumeEventCommandHandler.cs` - Main entry point
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/NewShipmentCreated/NewShipmentCreatedEventHandler.cs` - INSERT handler
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/ShipmentUpdated/ShipmentUpdatedEventHandler.cs` - UPDATE handler
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/DeletedShipment/DeletedShipmentEventHandler.cs` - DELETE handler
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/BaseEventHandler.cs` - Base class
- `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/ServiceSetupExtensions/GooglePubSUb/GooglePubSubServiceSetupExtensions.cs` - Pub/Sub configuration

---

## Cross-References

- **Solutions:** `problem-2-solutions.md`
- **Original Meeting:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`
- **Related Problem:** `problem-1-distributed-transaction-failure.md` (Top-down sync)
