# Transport Order Creation - TMS Integration

**Date:** 2026-03-16
**Focus:** GraphQL mutations, batch operations, and TMS stored functions
**Document Series:** Part 4 of 6

---

## Overview

The TMS Bridge layer provides GraphQL mutations that call stored functions in the TMS database. The key innovation is the **batch GraphQL mutation pattern** that:

1. Creates a transport order with the first leg
2. Adds remaining legs using the exported transport order ID
3. Maintains transactional integrity
4. Minimizes network overhead

---

## 1. Backend - TMS Bridge GraphQL Builder

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/TransportOrderPlanning/Requests/CreateTransportOrderFromLot/SubHandlers/CreateTransportOrderFromLotSubHandler.cs`

**Purpose:** Builds a batch GraphQL mutation with multiple operations

---

## 2. Batch GraphQL Mutation Pattern

### Why Use Batch Mutations?

1. **Single HTTP Request**
   - Reduces network overhead
   - Faster overall execution

2. **Transactional Integrity**
   - All operations succeed or all fail
   - No partial transport orders

3. **Variable Export**
   - First mutation exports `transportOrderId` with `@export(as: "transportOrderId")`
   - Subsequent mutations use `$transportOrderId` variable
   - No need to make multiple round-trips

4. **Efficient TMS Communication**
   - Batch processing on TMS side
   - Maintains database transaction consistency

---

### Operation 1 - Create Transport Order with First Leg

**GraphQL Mutation:**

```graphql
mutation CallCreateTransportOrderFromLeg {
  createTransportOrderFromLeg{shipmentId}: callCreateTransportOrderFromLeg(
    databaseIdentifier: "BRANCH_KEY"
    input: {
      company: 1
      branch: 101
      performanceDate: "2026-03-16T10:00:00"
      transportMode: 60
      shipmentId: 123456
      legType: "VL"
    }
  ) {
    transportOrderId @export(as: "transportOrderId")
    legId
    pickupPointId
    deliveryPointId
  }
}
```

**Key Feature:** `@export(as: "transportOrderId")` makes the ID available to subsequent mutations

---

### Operation 2+ - Add Remaining Legs (Loop)

**GraphQL Mutation:**

```graphql
mutation CallCreateAndAddLeg{shipmentId}($transportOrderId: Long!) {
  callCreateAndAddLeg{shipmentId}: callCreateAndAddLeg(
    databaseIdentifier: "BRANCH_KEY"
    input: {
      transportOrderId: $transportOrderId
      shipmentId: 789012
      legType: "VL"
    }
  ) {
    legId
    pickupPointId
    deliveryPointId
  }
}
```

**Benefits:**
- Reuses `$transportOrderId` from first mutation
- No need for additional queries
- Ensures all legs belong to the same transport order

---

### Complete Batch Example

```graphql
# First operation creates and exports ID
mutation Op1 {
  createTransportOrderFromLeg: callCreateTransportOrderFromLeg(...) {
    transportOrderId @export(as: "transportOrderId")  # Export for reuse
    legId
    pickupPointId
    deliveryPointId
  }
}

# Second operation uses the exported ID
mutation Op2($transportOrderId: Long!) {
  callCreateAndAddLeg(input: { transportOrderId: $transportOrderId, ... }) {
    legId
    pickupPointId
    deliveryPointId
  }
}

# Third operation also uses the exported ID
mutation Op3($transportOrderId: Long!) {
  callCreateAndAddLeg(input: { transportOrderId: $transportOrderId, ... }) {
    legId
    pickupPointId
    deliveryPointId
  }
}
```

---

## 3. TMS Bridge - GraphQL Mutations

**Location:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/`

---

### CreateTransportOrderFromLegMutation

**File:** `CreateTransportOrderFromLeg/CreateTransportOrderFromLegMutation.cs`

```csharp
public async Task<CreateTransportOrderFromLegResponse> CallCreateTransportOrderFromLeg(
    IRoutineExecutor executor,
    IDbContextProvider<BranchDbContext> dbContextProvider,
    string databaseIdentifier,
    CreateTransportOrderFromLegInput input)
{
  // Get database context for the branch
  BranchDbContext dbContext = await dbContextProvider.GetDbContext(databaseIdentifier);

  // Build routine call to TMS stored function
  var routine = new Routine
  {
    Schema = "pdis_transportorder",
    Name = "createtransportorderfromleg",
    Parameters = new Dictionary<string, object>
    {
      { "p_firma", input.Company },
      { "p_niederlassung", input.Branch },
      { "p_datum", input.PerformanceDate },
      { "p_modus", input.TransportMode },
      { "p_sendung_tix", input.ShipmentId },
      { "p_legtype", input.LegType },
      { "p_mode", "NEW_DISPO" }
    }
  };

  // Execute TMS stored function
  var result = await executor.ExecuteRoutineAsync(
    dbContext,
    OperationType.Function,
    routine
  );

  // Map result to response
  return new CreateTransportOrderFromLegResponse
  {
    TransportOrderId = result.GetValue<long>("transportOrderId"),
    LegId = result.GetValue<long>("legId"),
    PickupPointId = result.GetValue<long>("pickupPointId"),
    DeliveryPointId = result.GetValue<long>("deliveryPointId")
  };
}
```

---

### TMS Stored Function: createtransportorderfromleg

**Schema:** `pdis_transportorder`
**Function:** `createtransportorderfromleg`

**Parameters:**
- `p_firma` - Company ID (integer)
- `p_niederlassung` - Branch ID (integer)
- `p_datum` - Performance date (timestamp)
- `p_modus` - Transport mode (integer, 60 = pickup)
- `p_sendung_tix` - Shipment TIX ID (long)
- `p_legtype` - Leg type (string: VL, HL, NL)
- `p_mode` - Source system identifier (string: "NEW_DISPO")

**Returns:**
- `transportOrderId` - Transport Order ID (TMS primary key)
- `legId` - Leg ID (TMS leg primary key)
- `pickupPointId` - Pickup Tour Point ID
- `deliveryPointId` - Delivery Tour Point ID

**What it does:**
1. Creates a new transport order record in TMS
2. Adds the first leg/shipment to the transport order
3. Creates pickup and delivery tour points
4. Returns all generated IDs

---

### CreateAndAddLegMutation

**File:** `CreateAndAddLeg/CreateAndAddLegMutation.cs`

```csharp
public async Task<CreateAndAddLegTourPointsGraphQLResponse> CallCreateAndAddLeg(
    IRoutineExecutor executor,
    IDbContextProvider<BranchDbContext> dbContextProvider,
    string databaseIdentifier,
    CreateAndAddLegInput input)
{
  // Get database context for the branch
  BranchDbContext dbContext = await dbContextProvider.GetDbContext(databaseIdentifier);

  // Calls TMS stored function: pdis_transportorder.addshipment
  // Adds additional leg to existing transport order

  var routine = new Routine
  {
    Schema = "pdis_transportorder",
    Name = "addshipment",
    Parameters = new Dictionary<string, object>
    {
      { "p_ta_tix", input.TransportOrderId },
      { "p_sendung_tix", input.ShipmentId },
      { "p_legtype", input.LegType }
    }
  };

  var result = await executor.ExecuteRoutineAsync(dbContext, OperationType.Function, routine);

  return new CreateAndAddLegTourPointsGraphQLResponse
  {
    LegId = result.GetValue<long>("legId"),
    PickupPointId = result.GetValue<long>("pickupPointId"),
    DeliveryPointId = result.GetValue<long>("deliveryPointId")
  };
}
```

---

### TMS Stored Function: addshipment

**Schema:** `pdis_transportorder`
**Function:** `addshipment`

**Parameters:**
- `p_ta_tix` - Transport Order ID (long)
- `p_sendung_tix` - Shipment TIX ID (long)
- `p_legtype` - Leg type (string: VL, HL, NL)

**Returns:**
- `legId` - Leg ID (TMS leg primary key)
- `pickupPointId` - Pickup Tour Point ID
- `deliveryPointId` - Delivery Tour Point ID

**What it does:**
1. Adds the leg/shipment to an existing transport order
2. Creates or updates tour points
3. Returns generated IDs

---

## 4. Data Flow Through Layers

```
Backend Handler
    ├─ Maps LegEntity to CraeteTransportOrderLegDataInputDto
    └─ Calls CreateTransportOrderFromLotSubHandler
        ↓
SubHandler
    ├─ Builds batch GraphQL mutation string
    └─ Executes mutation via TMS Bridge
        ↓
TMS Bridge GraphQL Mutation
    ├─ callCreateTransportOrderFromLeg (mutation 1)
    │   └─ Calls pdis_transportorder.createtransportorderfromleg
    └─ callCreateAndAddLeg (mutations 2+, loop)
        └─ Calls pdis_transportorder.addshipment
        ↓
TMS Database
    ├─ Creates transport order record
    ├─ Adds all legs to transport order
    ├─ Creates/updates tour points
    └─ Returns all IDs
        ↓
Response Flows Back
    ├─ TMS → TMS Bridge
    ├─ TMS Bridge → SubHandler
    ├─ SubHandler → Handler
    └─ Handler uses IDs to create LotAssignmentEntity
```

---

## 5. Input/Output DTOs

### CreateTransportOrderFromLegInput

```csharp
public class CreateTransportOrderFromLegInput
{
  public int Company { get; set; }
  public int Branch { get; set; }
  public DateTime PerformanceDate { get; set; }
  public int? TransportMode { get; set; }  // 60 for pickup
  public long ShipmentId { get; set; }
  public string LegType { get; set; }  // "VL", "HL", "NL"
}
```

---

### CreateTransportOrderFromLegResponse

```csharp
public class CreateTransportOrderFromLegResponse
{
  public long TransportOrderId { get; set; }
  public long LegId { get; set; }
  public long PickupPointId { get; set; }
  public long DeliveryPointId { get; set; }
}
```

---

### CreateAndAddLegInput

```csharp
public class CreateAndAddLegInput
{
  public long TransportOrderId { get; set; }
  public long ShipmentId { get; set; }
  public string LegType { get; set; }  // "VL", "HL", "NL"
}
```

---

### CreateAndAddLegTourPointsGraphQLResponse

```csharp
public class CreateAndAddLegTourPointsGraphQLResponse
{
  public long LegId { get; set; }
  public long PickupPointId { get; set; }
  public long DeliveryPointId { get; set; }
}
```

---

### CreateTransportOrderFromLotBatchGraphQLResponseDto

```csharp
public class CreateTransportOrderFromLotBatchGraphQLResponseDto
{
  public List<CreatedTransportOrderGraphQLResponseDto> CreatedTransportOrderGraphQLResponse { get; set; }
  public List<CreateAndAddLegTourPointsGraphQLResponse>? CreateAndAddLegTourPoints { get; set; }
}
```

---

## 6. Leg Types

The system supports three leg types:

| Leg Type | Description | German Term |
|----------|-------------|-------------|
| **VL** | Pickup leg (Vorlauf) | Vorlaufsendung |
| **HL** | Main/Trunk leg (Hauptlauf) | Hauptlaufsendung |
| **NL** | Delivery leg (Nachlauf) | Nachlaufsendung |

These are passed to TMS stored functions to determine routing and sequencing logic.

---

## File Reference

### TMS Bridge

| Component | File Path | Purpose |
|-----------|-----------|---------|
| **Create TO Mutation** | `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/CreateTransportOrderFromLeg/CreateTransportOrderFromLegMutation.cs` | TMS function: createtransportorderfromleg |
| **Add Leg Mutation** | `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/CreateAndAddLeg/CreateAndAddLegMutation.cs` | TMS function: addshipment |

---

## See Also

- **[Overview and Flow](./01-overview-and-flow.md)** - High-level sequence diagram
- **[Backend Implementation](./03-backend-implementation.md)** - Command handlers and business logic
- **[Data Model Transformations](./05-data-model-transformations.md)** - Entity relationships
- **[API Reference](./06-api-reference.md)** - Complete HTTP endpoint documentation
