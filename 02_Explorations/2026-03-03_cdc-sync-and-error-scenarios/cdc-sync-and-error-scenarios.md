# CDC Sync and Error Scenarios - Top-Down Synchronization Analysis

**Date:** 2026-03-03
**Status:** Exploration
**Meeting Reference:** 00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md

---

## Original User Input

Investigation into synchronization challenges between New Dispo Backend and TMS Database, focusing on:

1. **Top-Down Sync (New Dispo → TMS)**: How New Dispo writes data to TMS via TMS Bridge
2. **Bottom-Up Sync (TMS → New Dispo)**: How changes in TMS propagate to New Dispo via CDC
3. **The Problem**: When someone modifies data directly in TMS (e.g., via old Uniface fat client), New Dispo doesn't detect these changes

This exploration documents the current implementation based on actual code analysis.

---

## Summary

Two synchronization scenarios identified:

### 1. Top-Down Synchronization (New Dispo → TMS)

**Pattern Observed:**
- Operations execute sequentially: TMS database is modified first, then New Dispo database is modified
- No distributed transaction mechanism exists across the two databases
- Operations use separate database contexts: BranchDbContext (TMS) via TMS Bridge, AppDbContext (New Dispo)

**Affected Flows:**
- Leg/lot assignment to transport order
- Leg/lot unassignment from transport order
- Create transport order from leg/lot
- Delete transport order
- Mark leg as stays loaded

**Observed Failure Behavior:**
- If TMS operation succeeds but New Dispo SaveChanges fails:
  - TMS database contains the modification
  - New Dispo database does not contain the modification
  - No rollback mechanism executes
  - No retry mechanism exists
  - Systems remain in inconsistent state

### 2. Bottom-Up Synchronization (TMS → New Dispo via CDC)

**Pattern Observed:**
- TMS database changes trigger CDC events via Google Datastream
- Events stored in Google Cloud Storage, notifications sent via Pub/Sub
- New Dispo consumes events via HTTP POST to `/api/CDC/consume-event` endpoint

**Current CDC Error Handling:**
- Exception caught in `ConsumeEventCommandHandler.Handle()` (Lines 53-57)
- Error logged via ILogger
- `IsEventSuccess = false` returned in response
- HTTP 200 OK returned to Pub/Sub (message acknowledged)
- Pub/Sub does not redeliver acknowledged messages

**Observed Failure Behavior:**
- If event processing fails (DB unavailable, mapping error, business logic exception):
  - Pub/Sub message already acknowledged
  - Event will NOT be redelivered
  - Change exists in TMS but not reflected in New Dispo
  - No retry mechanism executes
  - Systems remain in inconsistent state

---

## Overall Synchronization Architecture

```
                        ┌─────────────────────────────────┐
                        │      New Dispo Backend          │
                        │  - Business Logic               │
                        │  - AppDbContext (New Dispo DB)  │
                        └─────────┬───────────────────┬───┘
                                  │                   │
                     TOP-DOWN     │                   │    BOTTOM-UP
                    (Write to TMS)│                   │   (Read from TMS)
                                  │                   │
                                  ↓                   ↑
                    GraphQL Mutation       HTTP POST (CloudEvent)
                    (CreateTransportOrder,      (CDC Events)
                     AssignLeg, etc.)
                                  │                   │
                                  ↓                   ↑
                        ┌─────────────────┐   ┌─────────────────┐
                        │   TMS Bridge    │   │  Google Pub/Sub │
                        │   (GraphQL API) │   │   Push Endpoint │
                        └────────┬────────┘   └────────┬────────┘
                                 │                     │
                    Stored Proc/Function         Pub/Sub Topic
                         Call                         │
                                 │                     │
                                 ↓                     ↑
                        ┌────────────────────────────────┐
                        │       TMS Database             │
                        │    (PostgreSQL/AlloyDB)        │
                        │  - pDIS_TransportOrder pkg     │
                        │  - pDIS_Leg pkg                │
                        │  - Sendung table (with CDC)    │
                        └────────┬───────────────────────┘
                                 │
                                 ↑ CDC Stream
                                 │ (Google Datastream)
                                 │
                        ┌────────────────────┐
                        │   Google Cloud     │
                        │   Storage Bucket   │
                        └────────────────────┘

Legend:
  ↓ TOP-DOWN: New Dispo writes to TMS (Vulnerable to partial failure)
  ↑ BOTTOM-UP: TMS changes propagated to New Dispo (Vulnerable to lost events)
```

---

## Top-Down Synchronization Architecture

### Component Overview

```
┌─────────────────────┐
│  New Dispo Backend  │ (C# / .NET 8 / Entity Framework)
│  (AppDbContext)     │
└──────────┬──────────┘
           │ GraphQL Mutation Call
           │ (HTTP/HTTPS)
           ↓
┌─────────────────────┐
│    TMS Bridge       │ (C# / .NET 8 / GraphQL / HotChocolate)
│ (BranchDbContext)   │
└──────────┬──────────┘
           │ Stored Procedure / Function Call
           │ (Direct DB Connection)
           ↓
┌─────────────────────┐
│   TMS Database      │ (PostgreSQL / AlloyDB)
│  (Schema: pDIS_*)   │
└─────────────────────┘
```

### TMS Bridge GraphQL Mutations (Top-Down Interface)

Key mutations exposed by TMS Bridge:

| Mutation | TMS Routine | Type | Purpose |
|----------|-------------|------|---------|
| `CallCreateTransportOrderFromLeg` | `pdis_transportorder.createtransportorderfromleg` | Function | Creates transport order and adds leg |
| `CallCreateAndAddLeg` | `pdis_transportorder.createandaddleg` | Procedure | Adds leg to existing transport order |
| `CallAssignLotToTransportOrder` | `pdis_transportorder.addshipment` | Procedure | **OBSOLETE** - Assigns lot to transport order |
| `CallStaysLoaded` | `pdis_leg.staysloaded` | Procedure | Marks leg as stays loaded |
| `CallDeleteTransportOrder` | `pdis_transportorder.delete` | Procedure | Deletes transport order |

---

## Vulnerability Pattern Analysis

### Example: Assign Leg to Transport Order

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/TransportOrderPlanning/Requests/AssignLegToTransportOrder/AssignLegToTransportOrderCommandHandler.cs`

#### Execution Flow

```
1. New Dispo Backend Handler (Line 28-136)
   ↓
2. Call TMS Bridge GraphQL Mutation (Line 47-49)
   → assignLegToTransportOrderSubHandler.AssignLeg(...)
   → Calls: pdis_transportorder.createandaddleg (TMS stored procedure)
   ✓ TMS Database Modified
   ↓
3. Recalculate Route on TMS (Line 51)
   → recalculateRouteService.Recalculate(...)
   ✓ TMS Database Modified Again
   ↓
4. Update New Dispo Database (Lines 55-127)
   → Create/Update LotAssignment
   → Create LotAssignmentLegLink
   → Update Lot aggregates
   → Remove leg from lot
   ↓
5. Save New Dispo Changes (Line 130)
   → await _appDbContext.SaveChangesAsync(cancellationToken);
   ⚠️ POTENTIAL FAILURE POINT
```

#### Vulnerability

**Critical Issue**: Steps 2-3 modify TMS database. If Step 5 fails (DB connection lost, constraint violation, etc.), there's **NO rollback mechanism** for TMS changes.

**Result**:
- TMS Database: Leg is assigned to transport order ✓
- New Dispo Database: Leg is NOT in LotAssignment ✗
- **Systems are now permanently out of sync**

#### Code Evidence

**AssignLegToTransportOrderCommandHandler.cs:47-51**
```csharp
// This modifies TMS database via GraphQL
CreateAndAddLegTourPointsGraphQLResponse response = destinationTourPoint is null || relationType is null
    ? await assignLegToTransportOrderSubHandler.AssignLeg(transportOrderId, shipmentId, legType, databaseIdentifier)
    : await assignLegAndMoveTourPointsSubHandler.AssignLegAndMoveTourPoint(transportOrderId, shipmentId, legType, databaseIdentifier, destinationTourPoint, relationType, cancellationToken);

await recalculateRouteService.Recalculate(databaseIdentifier, transportOrderId, cancellationToken);
```

**AssignLegToTransportOrderCommandHandler.cs:60-93**
```csharp
// This creates New Dispo records using data from TMS response
_appDbContext.LotAssignments.Add(new LotAssignmentEntity
{
    // ... entity setup ...
    PickupTourPointId = response.PickupPointId,    // From TMS
    DeliveryTourPointId = response.DeliveryPointId, // From TMS
    LegLinks = new List<LotAssignmentLegLinkEntity>
    {
        new ()
        {
            TmsLegId = response.LegId,  // From TMS - stores TMS FK
            // ...
        }
    }
});
```

**AssignLegToTransportOrderCommandHandler.cs:130**
```csharp
// If this fails, TMS changes are NOT rolled back
await _appDbContext.SaveChangesAsync(cancellationToken);
```

### Observed Constraints for TMS Rollback

System characteristics that affect rollback capability:

1. **Network Dependency**: Rollback would require additional HTTP call to TMS Bridge, which can fail independently
2. **Stateless TMS Bridge**: TMS Bridge has no transaction context across HTTP calls
3. **Stored Procedure Design**: TMS stored procedures do not expose inverse/undo operations
4. **Temporal Gap**: Time window between TMS write and potential rollback attempt allows other operations to occur

---

## TMS Database Interface (Stored Procedures)

**File:** `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql`

### CreateTransportOrderFromLeg (Lines 197-243)

```sql
CREATE OR REPLACE FUNCTION pdis_transportorder.CreateTransportOrderFromLeg(
    Company numeric,
    Branch numeric,
    PerformanceDate timestamp without time zone,
    TransportMode numeric,
    RegionId character varying,
    ShipmentId numeric,
    LegType character varying,
    mode numeric,
    OUT TransportOrderId numeric,
    OUT PickupPointId numeric,
    OUT IsNewPickupPoint boolean,
    OUT DeliveryPointId numeric,
    OUT IsNewDeliveryPoint boolean,
    OUT LegId numeric)
```

**What it does:**
1. Creates new transport order: `pDIS_TransportOrder.New(...)`
2. Adds leg to transport order: `pdis_transportorder.CreateAndAddLeg(...)`
3. Returns IDs and flags that New Dispo uses to create its entities

### AddLeg Procedure (Lines 77-84)

```sql
create or replace procedure pDIS_TransportOrder.AddLeg(
    in  nTransportOrderId    numeric,
    in  nShipmentId          numeric,
    in  sLegType             varchar,
    out nPickupPointId       numeric,
    out bIsNewPickupPoint    boolean,
    out nDeliveryPointId     numeric,
    out bIsNewDeliveryPoint  boolean,
    in  nMode                numeric)
```

**What it does:**
- Adds a leg (shipment) to an existing transport order
- Creates/reuses pickup and delivery tour points
- Returns tour point IDs for New Dispo to reference

---

## Source Code Evidence

### TMS Bridge Layer

**TMS Bridge GraphQL Mutation**
- File: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/CreateTransportOrderFromLeg/CreateTransportOrderFromLegMutation.cs`
- Lines: 15-58
- Pattern: Calls `executor.ExecuteRoutineAsync(dbContext, OperationType.Function, routine)`

**StaysLoaded Mutation Example**
- File: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisLeg/StaysLoadedMutation/StaysLoadedMutation.cs`
- Lines: 14-53
- Pattern: Wraps call in try-catch, but only logs errors - no compensation

### New Dispo Backend Layer

**GraphQL Request Executor**
- File: `Code/Disposition-Backend/CALConsult.Disposition.API/Shared/GraphQL/RequestExecutors/Mutations/CallCreateTransportOrderFromLegGraphQLRequestExecutor.cs`
- Lines: 14-46
- Pattern: Constructs GraphQL request, calls TMS Bridge via HTTP

**Command Handler (Business Logic)**
- File: `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/TransportOrderPlanning/Requests/AssignLegToTransportOrder/AssignLegToTransportOrderCommandHandler.cs`
- Lines: 28-136
- Pattern: Call TMS → Update New Dispo DB → SaveChanges (vulnerable pattern)

### TMS Database Layer

**Stored Procedures Package**
- File: `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql`
- Key Functions/Procedures:
  - `CreateTransportOrderFromLeg` (Line 197)
  - `AddShipment` (Line 149)
  - `AddLeg` (Line 77)
  - `Delete` (Line 65)

---

## Findings

### Current State

1. **No Distributed Transaction Support**: New Dispo and TMS operate on separate databases (AppDbContext vs BranchDbContext) without XA transactions or saga patterns

2. **Sequential Write Pattern**: All top-down flows follow the pattern:
   - Write to TMS (via TMS Bridge GraphQL mutation)
   - Write to New Dispo (via Entity Framework SaveChanges)
   - **No compensation if second write fails**

3. **Stateless TMS Bridge**: TMS Bridge is a stateless API - each GraphQL call is independent, no transaction context maintained

4. **Foreign Key Dependencies**: New Dispo stores TMS IDs (e.g., `TmsLegId`, `PickupTourPointId`) creating tight coupling without referential integrity across databases

5. **Error Handling Gaps**:
   - TMS Bridge mutations may catch exceptions but don't provide compensation operations
   - New Dispo handlers don't attempt rollback of TMS changes on failure

### Bottom-Up Sync (CDC) - Separate Issue

From meeting notes:
- CDC events are consumed successfully (cloud messaging guarantees delivery)
- But if New Dispo processing fails (DB unavailable, internal error), the event is lost
- **No retry queue or dead letter queue for failed processing**

---

## Bottom-Up Synchronization (CDC Event Processing)

### Architecture

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

### CDC Event Types

Based on code analysis, New Dispo subscribes to these TMS database events:

| CDC Event | TMS Table | Change Type | Handler |
|-----------|-----------|-------------|---------|
| NewShipmentCreated | `sendung` | INSERT | `NewShipmentCreatedEventHandler` |
| ShipmentUpdated | `sendung` | UPDATE | `ShipmentUpdatedEventHandler` |
| DeletedShipment | `sendung` | DELETE | `DeletedShipmentEventHandler` |

### Event Processing Flow

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

### CDC Vulnerability Pattern

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

**Observed Behavior**: Google Pub/Sub considers the message successfully delivered when the HTTP endpoint returns 200 OK. The `IsEventSuccess` flag in the response has no effect on Pub/Sub message acknowledgment - the message is already acknowledged and will not be redelivered.

### Example: NewShipmentCreatedEventHandler

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/NewShipmentCreated/NewShipmentCreatedEventHandler.cs`

**What it does (Lines 50-89)**:
1. Maps CDC shipment data to domain entities
2. Extracts legs from shipment based on traffic mode
3. Finds/creates suitable lots for each leg
4. Adds legs and lots to New Dispo database
5. **Saves changes** (Line 88): `await _appDbContext.SaveChangesAsync();`

**Failure Scenarios**:
- Database connection lost during SaveChanges
- Constraint violation (duplicate key, foreign key)
- Mapping failure (invalid data from TMS)
- Business logic failure in leg extractor
- Out of memory / timeout during processing

**Result of Failure**:
- Exception caught by ConsumeEventCommandHandler
- Error logged
- `IsEventSuccess = false` returned
- **CDC event lost forever - TMS shipment never created in New Dispo**

### Why This is Problematic

1. **No Retry Mechanism**: If event processing fails, there's no automatic retry
2. **No Dead Letter Queue**: Failed events are not persisted for later review/replay
3. **Silent Failure**: System continues operating, but New Dispo is out of sync with TMS
4. **No Alerting**: Operators may not know events are failing
5. **No Manual Recovery**: No tool to replay CDC events from a specific point in time

---

## Questions/Open Items

1. **Current Incident Rate**: How often do these sync failures actually occur in production?

2. **Manual Recovery Process**: Is there a documented procedure for operators to detect and fix sync issues?

3. **Monitoring**: Are there alerts for detecting out-of-sync conditions?

4. **CDC Recovery**: For bottom-up sync, is there CDC event logging or replay capability?

5. **TMS Stored Procedure Behavior**: Are TMS stored procedures idempotent? What happens if they're called multiple times with the same parameters?

6. **Pub/Sub Configuration**: What is the current Pub/Sub subscription configuration? (retry policy, dead letter topic, acknowledgment deadline)

7. **Error Logging**: Where are sync errors currently logged? Is there a centralized error tracking system?

8. **HTTP Response Handling**: What HTTP status codes does the CDC endpoint currently return for success vs. failure cases?

---

## Related Files

### New Dispo Backend - Top-Down Sync
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/TransportOrderPlanning/Requests/AssignLegToTransportOrder/AssignLegToTransportOrderCommandHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Shared/GraphQL/RequestExecutors/Mutations/CallCreateTransportOrderFromLegGraphQLRequestExecutor.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Shared/GraphQL/RequestExecutors/Mutations/CallStaysLoadedRequestExecutor.cs`

### New Dispo Backend - Bottom-Up Sync (CDC)
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/Requests/ConsumeEvent/ConsumeEventCommandHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/NewShipmentCreated/NewShipmentCreatedEventHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/ShipmentUpdated/ShipmentUpdatedEventHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/DeletedShipment/DeletedShipmentEventHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/BaseEventHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/ServiceSetupExtensions/GooglePubSUb/GooglePubSubServiceSetupExtensions.cs`

### TMS Bridge
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/CreateTransportOrderFromLeg/CreateTransportOrderFromLegMutation.cs`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/AssignLotToTransportOrder/AssignLotToTransportOrderMutation.cs` (OBSOLETE)
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisLeg/StaysLoadedMutation/StaysLoadedMutation.cs`

### TMS Database Schema
- `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql`
- `Code/tms-alloydb-schema/src/sql/package/PDIS_LEG.sql` (likely contains StaysLoaded procedure)

### Meeting Notes
- `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`

---

## Impact Assessment

### What Happens When Top-Down Sync Fails

Based on code analysis, if a top-down operation fails:

1. **TMS Database**: Contains the change (transport order created, leg assigned, etc.)
2. **New Dispo Database**: Missing the corresponding entities (LotAssignment, LotAssignmentLegLink)
3. **Foreign Key References**: New Dispo stores TMS IDs (TmsLegId, PickupTourPointId, DeliveryTourPointId) that reference TMS records
4. **Data Inconsistency**: TMS shows the leg as assigned to a transport order, New Dispo shows it as unassigned in a lot
5. **No Automatic Detection**: System continues operating with inconsistent state
6. **No Automatic Recovery**: No background job or reconciliation process exists to detect/fix the inconsistency

### What Happens When Bottom-Up Sync Fails

Based on code analysis, if CDC event processing fails:

1. **TMS Database**: Contains the change (new shipment, updated shipment, deleted shipment)
2. **CDC Pipeline**: Event successfully delivered to Pub/Sub and consumed by New Dispo
3. **New Dispo Processing**: Fails during handler execution (Line 51 in ConsumeEventCommandHandler.cs)
4. **Exception Handling**: Exception caught, logged, `IsEventSuccess = false` returned (Lines 53-57)
5. **Pub/Sub Acknowledgment**: Message already acknowledged - will NOT be redelivered
6. **New Dispo Database**: Missing the shipment's legs and lots
7. **Result**: TMS shipment exists but is invisible to New Dispo users
8. **No Automatic Recovery**: Event is lost, no retry mechanism exists
