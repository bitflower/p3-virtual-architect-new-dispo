# AddVehicle Modernization Strategy
## From Monolithic Database Logic to Microservices Architecture

## Current State: The Problem

### Current Architecture (Monolithic Database Logic)
```
API Layer                    Database Layer
┌─────────────┐             ┌──────────────────────────────────────┐
│             │             │                                      │
│  AddVehicle │────────────▶│  pDIS_TransportOrder.AddVehicle     │
│   Request   │             │            │                         │
│             │             │            ▼                         │
└─────────────┘             │       pTA.AddLkw                    │
                            │            │                         │
                            │            ├──▶ Extract Contractor  │
                            │            ├──▶ AddUnt (Carrier)    │
                            │            │      ├─▶ RemLkw       │
                            │            │      └─▶ RemAnh       │
                            │            ├──▶ Get Default Trailer│
                            │            ├──▶ AddAnh (Trailer)   │
                            │            ├──▶ ActualDispatch     │
                            │            └──▶ SetStatus          │
                            │                                      │
                            └──────────────────────────────────────┘
```

### Problems with Current Architecture

1. **Hidden Side Effects** - Adding a vehicle removes previous assignments
2. **Tight Coupling** - Vehicle → Contractor → Carrier → Trailer all in one call
3. **No Granular Control** - Cannot add vehicle without triggering contractor assignment
4. **Transaction Complexity** - All-or-nothing, no partial updates possible
5. **Testing Difficulty** - Cannot test individual operations in isolation
6. **API Evolution** - Cannot version individual operations independently
7. **Implicit Business Rules** - Logic hidden in database, not visible to API consumers
8. **No Event Stream** - Changes happen atomically, no audit trail of steps

## Target State: Microservices Architecture

### Architectural Principles

1. **Single Responsibility** - Each database function does ONE thing
2. **Explicit Orchestration** - API layer controls the flow
3. **No Hidden Side Effects** - All changes are explicit API calls
4. **Idempotent Operations** - Safe to retry
5. **Event-Driven** - Publish domain events for each change
6. **Eventual Consistency** - Where appropriate

### Decomposed Architecture

```
API/Service Layer                                    Database Layer
┌───────────────────────────────────────┐           ┌──────────────────────────┐
│                                       │           │                          │
│  Transport Order Orchestration API    │           │  Atomic DB Operations    │
│  ┌─────────────────────────────────┐ │           │                          │
│  │ POST /transport-orders/{id}/    │ │           │  Simple, focused         │
│  │      vehicle                    │ │           │  procedures with no      │
│  │                                 │ │           │  side effects            │
│  └────────────┬────────────────────┘ │           │                          │
│               │                       │           │                          │
│               ├──1──▶ Set Vehicle    ─┼──────────▶│  SetVehicle()           │
│               │                       │           │                          │
│               ├──2──▶ Get Contractor ─┼──────────▶│  GetVehicleContractor() │
│               │       from Vehicle    │           │                          │
│               │                       │           │                          │
│               ├──3──▶ Set Contractor ─┼──────────▶│  SetContractor()        │
│               │                       │           │                          │
│               ├──4──▶ Check if       ─┼──────────▶│  RequiresTrailer()      │
│               │       trailer needed  │           │                          │
│               │                       │           │                          │
│               ├──5──▶ Get Default    ─┼──────────▶│  GetDefaultTrailer()    │
│               │       Trailer         │           │                          │
│               │                       │           │                          │
│               ├──6──▶ Set Trailer    ─┼──────────▶│  SetTrailer()           │
│               │                       │           │                          │
│               └──7──▶ Publish Events  │           │                          │
│                                       │           │                          │
└───────────────────────────────────────┘           └──────────────────────────┘
         │
         ▼
┌───────────────────────────────────────┐
│  Event Bus / Message Queue            │
│  ─ VehicleAssigned                    │
│  ─ ContractorAssigned                 │
│  ─ TrailerAssigned                    │
└───────────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────┐
│  Downstream Services (Listeners)      │
│  ─ Status Calculation Service         │
│  ─ Dispatch Update Service            │
│  ─ Audit/History Service              │
└───────────────────────────────────────┘
```

## Decomposition Strategy

### Step 1: Identify Atomic Operations

Break `AddVehicle` into independent, side-effect-free operations:

| Current (Implicit)           | New (Explicit)                      | Database Function              |
|------------------------------|-------------------------------------|--------------------------------|
| Add vehicle                  | Set vehicle                         | `SetVehicle()`                 |
| Extract contractor           | Get vehicle contractor              | `GetVehicleContractor()`       |
| Assign carrier (AddUnt)      | Set contractor                      | `SetContractor()`              |
| Remove previous vehicle      | Clear vehicle                       | `ClearVehicle()`               |
| Remove previous trailer      | Clear trailer                       | `ClearTrailer()`               |
| Check trailer needed         | Check vehicle requires trailer      | `RequiresTrailer()`            |
| Get default trailer          | Get default trailer                 | `GetDefaultTrailer()`          |
| Assign trailer (AddAnh)      | Set trailer                         | `SetTrailer()`                 |
| Update dispatch (conditional)| Trigger dispatch update             | `TriggerDispatchUpdate()`      |
| Update status                | Calculate transport order status    | `CalculateStatus()`            |

### Step 2: Create Atomic Database Functions

#### 2.1 Vehicle Operations

```sql
-- Simple setter with NO side effects
create or replace procedure pDIS_TransportOrder.SetVehicle(
    TransportOrderId numeric,
    VehicleId varchar,
    LicensePlate varchar
) language plpgsql as $$
begin
    update SEN_FRK_UNT
    set LKW_TIX = VehicleId,
        LKW_K = VehicleId,
        LKW_AMTL_K = LicensePlate,
        U_Time = current_timestamp,
        U_User = current_user
    where Sen_Tix = TransportOrderId
      and Lfd_N = 1;
end; $$;

-- Get contractor from vehicle master data (read-only)
create or replace function pDIS_TransportOrder.GetVehicleContractor(
    VehicleId varchar
) returns numeric language plpgsql as $$
declare
    ContractorId numeric;
begin
    select coalesce(PERSONENNR_BESITZ, EIGENT_N, EIGENT_I)
    into ContractorId
    from LADERAUM_LKW
    where Lkw_K = VehicleId;

    return ContractorId;
end; $$;

-- Check if vehicle requires trailer (read-only)
create or replace function pDIS_TransportOrder.RequiresTrailer(
    VehicleId varchar
) returns boolean language plpgsql as $$
declare
    VehicleType varchar;
begin
    select Fzg_Typ into VehicleType
    from LADERAUM_LKW
    where Lkw_K = VehicleId;

    return VehicleType = 'SZM'; -- Tractor unit
end; $$;

-- Clear vehicle assignment
create or replace procedure pDIS_TransportOrder.ClearVehicle(
    TransportOrderId numeric
) language plpgsql as $$
begin
    update SEN_FRK_UNT
    set LKW_TIX = null,
        LKW_K = null,
        LKW_AMTL_K = null,
        U_Time = current_timestamp
    where Sen_Tix = TransportOrderId
      and Lfd_N = 1;
end; $$;
```

#### 2.2 Contractor Operations

```sql
-- Simple setter for contractor
create or replace procedure pDIS_TransportOrder.SetContractor(
    TransportOrderId numeric,
    ContractorId numeric
) language plpgsql as $$
begin
    update SEN_FRK_UNT
    set UNT_TIX = ContractorId,
        U_Time = current_timestamp,
        U_User = current_user
    where Sen_Tix = TransportOrderId
      and Lfd_N = 1;

    -- Also update SEN_TB relationship table
    update SEN_TB
    set Personennr = ContractorId
    where Sendung_Tix = TransportOrderId
      and TB_PBIT = 'UNF'; -- Entrepreneur/Carrier
end; $$;

-- Get current contractor (read-only)
create or replace function pDIS_TransportOrder.GetContractor(
    TransportOrderId numeric
) returns numeric language plpgsql as $$
declare
    ContractorId numeric;
begin
    select UNT_TIX into ContractorId
    from SEN_FRK_UNT
    where Sen_Tix = TransportOrderId
      and Lfd_N = 1;

    return ContractorId;
end; $$;
```

#### 2.3 Trailer Operations

```sql
-- Simple setter for trailer
create or replace procedure pDIS_TransportOrder.SetTrailer(
    TransportOrderId numeric,
    TrailerId varchar,
    LicensePlate varchar
) language plpgsql as $$
begin
    update SEN_FRK_UNT
    set ANH_TIX = TrailerId,
        ANH_K = TrailerId,
        ANH_AMTL_K = LicensePlate,
        U_Time = current_timestamp,
        U_User = current_user
    where Sen_Tix = TransportOrderId
      and Lfd_N = 1;
end; $$;

-- Get default trailer for branch (read-only)
create or replace function pDIS_TransportOrder.GetDefaultTrailer(
    Company numeric,
    Branch numeric
) returns varchar language plpgsql as $$
declare
    TrailerId varchar;
begin
    select PEQM.GETDEFAULTTRAILER('FV', Company, Branch)
    into TrailerId;

    return TrailerId;
end; $$;

-- Clear trailer assignment
create or replace procedure pDIS_TransportOrder.ClearTrailer(
    TransportOrderId numeric
) language plpgsql as $$
begin
    update SEN_FRK_UNT
    set ANH_TIX = null,
        ANH_K = null,
        ANH_AMTL_K = null,
        U_Time = current_timestamp
    where Sen_Tix = TransportOrderId
      and Lfd_N = 1;
end; $$;
```

#### 2.4 Status Operations

```sql
-- Calculate and update status (no side effects beyond status)
create or replace procedure pDIS_TransportOrder.CalculateAndUpdateStatus(
    TransportOrderId numeric
) language plpgsql as $$
begin
    -- Only updates status, nothing else
    call pTA.SetStatus(TransportOrderId);
end; $$;
```

### Step 3: API Layer Orchestration

#### 3.1 RESTful API Design

```typescript
// API Endpoint: POST /api/v1/transport-orders/{id}/vehicle
interface AssignVehicleRequest {
  vehicleId: string;
  licensePlate: string;
  options?: {
    assignContractor?: boolean;      // Default: true
    assignDefaultTrailer?: boolean;  // Default: true
    clearPrevious?: boolean;         // Default: false
  };
}

interface AssignVehicleResponse {
  transportOrderId: number;
  vehicle: {
    id: string;
    licensePlate: string;
    assignedAt: string;
  };
  contractor?: {
    id: number;
    assigned: boolean;
    source: 'vehicle-master-data' | 'manual';
  };
  trailer?: {
    id: string;
    assigned: boolean;
    source: 'default' | 'manual';
  };
  events: string[];  // List of events published
}
```

#### 3.2 Service Implementation (TypeScript/Node.js Example)

```typescript
class TransportOrderService {

  async assignVehicle(
    transportOrderId: number,
    request: AssignVehicleRequest
  ): Promise<AssignVehicleResponse> {

    const events: string[] = [];
    const response: AssignVehicleResponse = {
      transportOrderId,
      vehicle: {
        id: request.vehicleId,
        licensePlate: request.licensePlate,
        assignedAt: new Date().toISOString()
      },
      events
    };

    try {
      // Start database transaction (for consistency within this operation)
      await this.db.transaction(async (trx) => {

        // 1. Optional: Clear previous assignments
        if (request.options?.clearPrevious) {
          await trx.query(
            'CALL pDIS_TransportOrder.ClearVehicle($1)',
            [transportOrderId]
          );
          await trx.query(
            'CALL pDIS_TransportOrder.ClearTrailer($1)',
            [transportOrderId]
          );
          events.push('PreviousAssignmentsCleared');
        }

        // 2. Set vehicle (atomic operation)
        await trx.query(
          'CALL pDIS_TransportOrder.SetVehicle($1, $2, $3)',
          [transportOrderId, request.vehicleId, request.licensePlate]
        );
        events.push('VehicleAssigned');

        // 3. Optional: Assign contractor from vehicle
        if (request.options?.assignContractor !== false) {
          const contractorResult = await trx.query(
            'SELECT pDIS_TransportOrder.GetVehicleContractor($1) as id',
            [request.vehicleId]
          );

          const contractorId = contractorResult.rows[0]?.id;

          if (contractorId) {
            await trx.query(
              'CALL pDIS_TransportOrder.SetContractor($1, $2)',
              [transportOrderId, contractorId]
            );

            response.contractor = {
              id: contractorId,
              assigned: true,
              source: 'vehicle-master-data'
            };
            events.push('ContractorAssigned');
          }
        }

        // 4. Optional: Assign default trailer if needed
        if (request.options?.assignDefaultTrailer !== false) {
          const requiresTrailerResult = await trx.query(
            'SELECT pDIS_TransportOrder.RequiresTrailer($1) as required',
            [request.vehicleId]
          );

          if (requiresTrailerResult.rows[0]?.required) {
            // Get transport order details for company/branch
            const orderResult = await trx.query(
              'SELECT Firma, NL FROM Sendung WHERE Sendung_Tix = $1',
              [transportOrderId]
            );

            const { firma: company, nl: branch } = orderResult.rows[0];

            const trailerResult = await trx.query(
              'SELECT pDIS_TransportOrder.GetDefaultTrailer($1, $2) as id',
              [company, branch]
            );

            const trailerId = trailerResult.rows[0]?.id;

            if (trailerId) {
              // Get trailer license plate
              const trailerDetailsResult = await trx.query(
                'SELECT Amtl_K FROM LADERAUM_LKW WHERE Lkw_K = $1',
                [trailerId]
              );

              const trailerPlate = trailerDetailsResult.rows[0]?.amtl_k;

              await trx.query(
                'CALL pDIS_TransportOrder.SetTrailer($1, $2, $3)',
                [transportOrderId, trailerId, trailerPlate]
              );

              response.trailer = {
                id: trailerId,
                assigned: true,
                source: 'default'
              };
              events.push('TrailerAssigned');
            }
          }
        }

        // 5. Update status (last step)
        await trx.query(
          'CALL pDIS_TransportOrder.CalculateAndUpdateStatus($1)',
          [transportOrderId]
        );
        events.push('StatusUpdated');

      }); // End transaction

      // 6. Publish domain events (AFTER transaction commits)
      await this.publishEvents(transportOrderId, events, response);

      return response;

    } catch (error) {
      // All changes rolled back automatically
      throw new Error(`Failed to assign vehicle: ${error.message}`);
    }
  }

  private async publishEvents(
    transportOrderId: number,
    eventTypes: string[],
    data: any
  ): Promise<void> {
    // Publish to event bus (Kafka, RabbitMQ, etc.)
    for (const eventType of eventTypes) {
      await this.eventBus.publish({
        eventType: `TransportOrder.${eventType}`,
        aggregateId: transportOrderId,
        timestamp: new Date().toISOString(),
        data
      });
    }
  }
}
```

#### 3.3 Alternative: Command Pattern

```typescript
// Commands represent intentions
interface AssignVehicleCommand {
  type: 'AssignVehicle';
  transportOrderId: number;
  vehicleId: string;
  licensePlate: string;
}

interface AssignContractorCommand {
  type: 'AssignContractor';
  transportOrderId: number;
  contractorId: number;
}

interface AssignTrailerCommand {
  type: 'AssignTrailer';
  transportOrderId: number;
  trailerId: string;
  licensePlate: string;
}

// Command handlers are simple and focused
class AssignVehicleCommandHandler {
  async handle(command: AssignVehicleCommand): Promise<void> {
    await this.db.query(
      'CALL pDIS_TransportOrder.SetVehicle($1, $2, $3)',
      [command.transportOrderId, command.vehicleId, command.licensePlate]
    );

    await this.eventBus.publish({
      type: 'VehicleAssigned',
      transportOrderId: command.transportOrderId,
      vehicleId: command.vehicleId
    });
  }
}

// Saga orchestrates multiple commands
class AssignVehicleWithContractorSaga {
  async execute(transportOrderId: number, vehicleId: string): Promise<void> {
    // Step 1: Assign vehicle
    await this.commandBus.send({
      type: 'AssignVehicle',
      transportOrderId,
      vehicleId
    });

    // Step 2: Get contractor from vehicle
    const contractorId = await this.db.query(
      'SELECT pDIS_TransportOrder.GetVehicleContractor($1)',
      [vehicleId]
    );

    // Step 3: Assign contractor
    if (contractorId) {
      await this.commandBus.send({
        type: 'AssignContractor',
        transportOrderId,
        contractorId
      });
    }

    // Step 4: Check and assign trailer if needed
    const requiresTrailer = await this.db.query(
      'SELECT pDIS_TransportOrder.RequiresTrailer($1)',
      [vehicleId]
    );

    if (requiresTrailer) {
      const trailerId = await this.getDefaultTrailer(transportOrderId);
      await this.commandBus.send({
        type: 'AssignTrailer',
        transportOrderId,
        trailerId
      });
    }
  }
}
```

### Step 4: Event-Driven Architecture

#### 4.1 Domain Events

```typescript
// Domain events represent what happened
interface VehicleAssignedEvent {
  eventType: 'TransportOrder.VehicleAssigned';
  aggregateId: number;  // transportOrderId
  timestamp: string;
  data: {
    vehicleId: string;
    licensePlate: string;
    assignedBy: string;
  };
}

interface ContractorAssignedEvent {
  eventType: 'TransportOrder.ContractorAssigned';
  aggregateId: number;
  timestamp: string;
  data: {
    contractorId: number;
    source: 'vehicle-master-data' | 'manual';
  };
}
```

#### 4.2 Event Listeners (Async Side Effects)

```typescript
// Status calculation service listens to events
class StatusCalculationService {

  @EventListener('TransportOrder.VehicleAssigned')
  @EventListener('TransportOrder.ContractorAssigned')
  @EventListener('TransportOrder.TrailerAssigned')
  async onTransportOrderChanged(event: DomainEvent): Promise<void> {
    // Recalculate status asynchronously
    await this.db.query(
      'CALL pDIS_TransportOrder.CalculateAndUpdateStatus($1)',
      [event.aggregateId]
    );

    // Publish result
    await this.eventBus.publish({
      eventType: 'TransportOrder.StatusUpdated',
      aggregateId: event.aggregateId,
      timestamp: new Date().toISOString()
    });
  }
}

// Dispatch service listens to vehicle assignment
class DispatchUpdateService {

  @EventListener('TransportOrder.VehicleAssigned')
  async onVehicleAssigned(event: VehicleAssignedEvent): Promise<void> {
    // Update related delivery orders asynchronously
    await this.db.query(
      'CALL pTA.ActualDispatch($1, $2)',
      [event.aggregateId, PTA_LIB.MODE_TAMODFRK()]
    );
  }
}
```

## Migration Strategy

### Phase 1: Add Atomic Functions (Non-Breaking)

1. **Create new atomic database functions** alongside existing procedures
2. **Keep existing `AddVehicle`** for backward compatibility
3. **Add feature flags** to control which path is used

```sql
-- New atomic function
create or replace procedure pDIS_TransportOrder.SetVehicle_V2(...);

-- Existing monolithic function (unchanged)
create or replace procedure pDIS_TransportOrder.AddVehicle(...);
```

### Phase 2: API Layer Orchestration

1. **Create new API endpoints** that use atomic functions
2. **Version the API** (`/v2/transport-orders/{id}/vehicle`)
3. **Implement orchestration** in service layer
4. **Add comprehensive logging** to track flow

### Phase 3: Event Infrastructure

1. **Add event publishing** to new API endpoints
2. **Create event listeners** for async processing
3. **Migrate side effects** (status, dispatch) to event handlers
4. **Monitor event processing** lag and failures

### Phase 4: Migrate Clients

1. **Update clients** to use new API endpoints one by one
2. **Monitor metrics** (latency, errors, data consistency)
3. **Run both systems in parallel** during migration
4. **Gradually increase traffic** to new endpoints

### Phase 5: Deprecate Old Functions

1. **Mark old procedures as deprecated**
2. **Log warnings** when old functions are called
3. **Set sunset date** for old API
4. **Remove old procedures** after all clients migrated

## Comparison: Before vs After

### Transaction Scope

**Before (Monolithic):**
```
┌─────────────────────────────────────────────┐
│  Single Database Transaction                │
│  ┌───────────────────────────────────────┐ │
│  │ AddVehicle                            │ │
│  │  ├─ Set Vehicle                       │ │
│  │  ├─ Extract Contractor                │ │
│  │  ├─ Assign Contractor (AddUnt)        │ │
│  │  │   ├─ Remove Previous Vehicle       │ │
│  │  │   └─ Remove Previous Trailer       │ │
│  │  ├─ Get Default Trailer               │ │
│  │  ├─ Assign Trailer (AddAnh)           │ │
│  │  ├─ Update Dispatch                   │ │
│  │  └─ Update Status                     │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**After (Microservices):**
```
┌────────────────────────────────────┐
│  API Transaction (Consistency)     │
│  ┌──────────────────────────────┐ │
│  │ Set Vehicle                  │ │
│  │ Set Contractor               │ │
│  │ Set Trailer                  │ │
│  └──────────────────────────────┘ │
└────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────┐
│  Async Events (Eventual)           │
│  ┌──────────────────────────────┐ │
│  │ Calculate Status             │ │
│  │ Update Dispatch              │ │
│  │ Send Notifications           │ │
│  └──────────────────────────────┘ │
└────────────────────────────────────┘
```

### Control Flow

| Aspect                  | Before (Monolithic)           | After (Microservices)              |
|-------------------------|-------------------------------|------------------------------------|
| **Orchestration**       | Database procedures           | API service layer                  |
| **Side effects**        | Implicit, hidden              | Explicit, visible                  |
| **Transaction scope**   | All-or-nothing                | Core operations atomic, rest async |
| **Error handling**      | Rollback entire operation     | Partial success possible           |
| **Flexibility**         | Fixed flow, mode flags        | Configurable flow per request      |
| **Testing**             | Integration tests only        | Unit tests for each operation      |
| **Observability**       | Database logs only            | Distributed tracing, events        |
| **Performance**         | Single round-trip, but slow   | Multiple calls, but parallelizable |

## Advantages of Microservices Approach

### 1. **Flexibility**
```typescript
// Scenario 1: Full automation (like current AddVehicle)
await service.assignVehicle(orderId, {
  vehicleId: 'V123',
  options: {
    assignContractor: true,
    assignDefaultTrailer: true
  }
});

// Scenario 2: Manual control (not possible before)
await service.assignVehicle(orderId, {
  vehicleId: 'V123',
  options: {
    assignContractor: false,  // User will set manually
    assignDefaultTrailer: false
  }
});

// Scenario 3: Custom workflow
await service.assignVehicle(orderId, { vehicleId: 'V123' });
await service.assignContractor(orderId, customContractorId);
await service.assignTrailer(orderId, customTrailerId);
```

### 2. **Testability**
```typescript
// Unit test individual operations
describe('SetVehicle', () => {
  it('should only update vehicle fields', async () => {
    await service.setVehicle(orderId, vehicleId);

    // Assert only vehicle changed, nothing else
    expect(contractor).toBeUnchanged();
    expect(trailer).toBeUnchanged();
  });
});

// Integration test full flow
describe('AssignVehicleWorkflow', () => {
  it('should assign vehicle with contractor', async () => {
    await service.assignVehicleWorkflow(orderId, vehicleId);

    expect(vehicle).toBeAssigned();
    expect(contractor).toBeAssigned();
  });
});
```

### 3. **Observability**
```typescript
// Distributed tracing
POST /transport-orders/123/vehicle
  ├─ span: db.setVehicle (5ms)
  ├─ span: db.getContractor (3ms)
  ├─ span: db.setContractor (4ms)
  ├─ span: db.requiresTrailer (2ms)
  ├─ span: db.setTrailer (4ms)
  └─ span: eventBus.publish (10ms)
Total: 28ms

// Event stream
VehicleAssigned → ContractorAssigned → TrailerAssigned → StatusUpdated
   ↓                  ↓                    ↓                 ↓
  10:15:01          10:15:01             10:15:02          10:15:03
```

### 4. **Scalability**
```
┌─────────────────┐     ┌──────────────────┐
│ Vehicle Service │────▶│ Vehicle DB Pool  │
└─────────────────┘     └──────────────────┘
        ║
┌═══════════════════════════════════════════┐
║         Event Bus (Kafka)                 ║
└═══════════════════════════════════════════┘
        ║
        ╠══════▶ ┌─────────────────────┐
        ║        │ Status Service (x3) │  ← Scale independently
        ║        └─────────────────────┘
        ║
        ╚══════▶ ┌─────────────────────┐
                 │ Dispatch Service    │
                 └─────────────────────┘
```

### 5. **Independent Evolution**
```
Version 1: Simple vehicle assignment
POST /v1/transport-orders/{id}/vehicle
  → SetVehicle()

Version 2: Add contractor automation
POST /v2/transport-orders/{id}/vehicle?assignContractor=true
  → SetVehicle() + SetContractor()

Version 3: Add trailer automation
POST /v3/transport-orders/{id}/vehicle
  → SetVehicle() + SetContractor() + SetTrailer()

All versions can coexist!
```

## Challenges and Solutions

### Challenge 1: Data Consistency

**Problem:** Multiple calls = multiple transactions = potential inconsistency

**Solutions:**

1. **Saga Pattern with Compensation**
```typescript
class AssignVehicleSaga {
  async execute(orderId: number, vehicleId: string) {
    const compensations: (() => Promise<void>)[] = [];

    try {
      // Step 1: Assign vehicle
      await this.setVehicle(orderId, vehicleId);
      compensations.push(() => this.clearVehicle(orderId));

      // Step 2: Assign contractor
      const contractorId = await this.getContractor(vehicleId);
      await this.setContractor(orderId, contractorId);
      compensations.push(() => this.clearContractor(orderId));

      // Success!
      return { success: true };

    } catch (error) {
      // Rollback in reverse order
      for (const compensate of compensations.reverse()) {
        await compensate();
      }
      throw error;
    }
  }
}
```

2. **Optimistic Locking**
```sql
-- Add version column
alter table SEN_FRK_UNT add column Version bigint default 0;

-- Update with version check
update SEN_FRK_UNT
set LKW_TIX = $1,
    Version = Version + 1
where Sen_Tix = $2
  and Version = $3;  -- Only update if version matches
```

3. **Event Sourcing** (Advanced)
```typescript
// Store events, not state
events = [
  { type: 'VehicleAssigned', vehicleId: 'V123', timestamp: '...' },
  { type: 'ContractorAssigned', contractorId: 42, timestamp: '...' },
  { type: 'TrailerAssigned', trailerId: 'T456', timestamp: '...' }
];

// Rebuild state from events
currentState = events.reduce(applyEvent, initialState);
```

### Challenge 2: Performance

**Problem:** Multiple round-trips vs single procedure call

**Solutions:**

1. **Batch Operations**
```sql
create or replace procedure pDIS_TransportOrder.BatchUpdate(
    TransportOrderId numeric,
    Updates jsonb  -- { vehicle: {...}, contractor: {...}, trailer: {...} }
) language plpgsql as $$
begin
    if (Updates->>'vehicle' is not null) then
        -- Set vehicle
    end if;

    if (Updates->>'contractor' is not null) then
        -- Set contractor
    end if;

    if (Updates->>'trailer' is not null) then
        -- Set trailer
    end if;
end; $$;
```

2. **GraphQL for Efficient Queries**
```graphql
mutation AssignVehicle($input: AssignVehicleInput!) {
  assignVehicle(input: $input) {
    transportOrder {
      id
      vehicle { id licensePlate }
      contractor { id name }
      trailer { id licensePlate }
      status
    }
  }
}
```

3. **Caching Strategy**
```typescript
// Cache read-only operations
@Cacheable('vehicle-contractor', ttl: 3600)
async getVehicleContractor(vehicleId: string): Promise<number> {
  return this.db.query(
    'SELECT pDIS_TransportOrder.GetVehicleContractor($1)',
    [vehicleId]
  );
}
```

### Challenge 3: Monitoring & Debugging

**Problem:** Distributed operations harder to debug than single procedure

**Solutions:**

1. **Correlation IDs**
```typescript
const correlationId = uuid();

logger.info({ correlationId, step: 'start' }, 'Assigning vehicle');
await setVehicle(orderId, vehicleId, { correlationId });
logger.info({ correlationId, step: 'vehicle-set' }, 'Vehicle assigned');
await setContractor(orderId, contractorId, { correlationId });
logger.info({ correlationId, step: 'contractor-set' }, 'Contractor assigned');
```

2. **Distributed Tracing (OpenTelemetry)**
```typescript
const tracer = trace.getTracer('transport-order-service');

await tracer.startActiveSpan('assignVehicle', async (span) => {
  span.setAttribute('transportOrderId', orderId);
  span.setAttribute('vehicleId', vehicleId);

  await setVehicle(orderId, vehicleId);
  await setContractor(orderId, contractorId);

  span.end();
});
```

3. **Event Replay for Debugging**
```typescript
// Replay events to see what happened
const events = await eventStore.getEvents(transportOrderId);
console.log('Event history:', events);
// [
//   { type: 'VehicleAssigned', timestamp: '10:15:01' },
//   { type: 'ContractorAssigned', timestamp: '10:15:01' },
//   { type: 'TrailerAssignmentFailed', error: '...', timestamp: '10:15:02' }
// ]
```

## Recommendation

### Short Term (3-6 months)
1. **Start with atomic read functions** (GetVehicleContractor, RequiresTrailer)
2. **Create simple setter procedures** (SetVehicle, SetContractor, SetTrailer)
3. **Build new API endpoint** with orchestration logic
4. **Run A/B test** between old and new flows
5. **Collect metrics** (performance, errors, satisfaction)

### Medium Term (6-12 months)
1. **Migrate high-traffic operations** to new architecture
2. **Implement event publishing** for audit and async processing
3. **Build event listeners** for status calculation and dispatch updates
4. **Deprecate old monolithic procedures**
5. **Provide migration guide** for API consumers

### Long Term (12+ months)
1. **Full event-driven architecture**
2. **Extract services** (Vehicle Service, Contractor Service, Trailer Service)
3. **Implement CQRS** (Command Query Responsibility Segregation)
4. **Consider event sourcing** for critical aggregates
5. **Autonomous services** with separate databases

## Conclusion

The key to successful modernization is **gradual migration** with the ability to **run both systems in parallel**. Start with atomic database functions, move orchestration to the API layer, and eventually adopt event-driven architecture for loose coupling and scalability.

The trade-off is increased complexity in the API layer, but you gain:
- **Flexibility** in business logic
- **Testability** of individual operations
- **Observability** of system behavior
- **Scalability** of independent components
- **Evolvability** without breaking existing clients

Modern architecture recognizes that **complexity doesn't disappear** - it just moves from the database layer (where it's hidden and inflexible) to the application layer (where it's explicit and manageable).
