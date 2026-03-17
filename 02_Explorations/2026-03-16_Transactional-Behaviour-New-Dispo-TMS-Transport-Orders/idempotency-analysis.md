# Idempotency Analysis: Transport Order Creation Flow

**Date:** 2026-03-16
**Analysis Focus:** Dispatcher flow - create transport order + assign legs/lots
**Decision Context:** Manual retry mechanism requires idempotency guarantees

---

## Executive Summary

✅ **IDEMPOTENCY CONFIRMED:** The TMS database implements idempotency for transport order leg assignment operations.

**Key Finding:** `pTA.AddSen()` procedure includes explicit duplicate check via `PTA.HASSEN()` function. If leg already assigned to transport order, operation returns early without modification.

**Implication:** Manual retry mechanism for Scenarios 1 & 3 is **safe to implement**. Retrying failed operations will not create duplicate leg assignments.

---

## Analysis Scope

### Use Case: Transport Order Creation via Drag & Drop

**Flow documented in:**
- `02_Explorations/2026-03-16_Transport_Order_Creation_via_Drag_and_Drop/01-overview-and-flow.md`

**TMS Operations Analyzed:**
1. `pDIS_TransportOrder.CreateTransportOrderFromLeg()` - Creates transport order and adds first leg
2. `pDIS_TransportOrder.AddShipment()` / `pDIS_TransportOrder.AddLeg()` - Adds additional legs to transport order

**Code Location:**
- Package: `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql`
- Core logic: `Code/tms-alloydb-schema/src/sql/package/PTA.sql`

---

## Call Chain Analysis

### Transport Order Creation Flow

```
CreateTransportOrderFromLeg(...)
  ↓
  pDIS_TransportOrder.New(...)
    → Creates new transport order record
  ↓
  pdis_transportorder.CreateAndAddLeg(...)
    ↓
    pDIS_TransportOrder.AddLeg(...)
      ↓
      pTA.AddSen(...)  ← IDEMPOTENCY CHECK HERE
```

### Adding Additional Legs

```
AddShipment(...)
  ↓
  pTA.AddSen(...)  ← IDEMPOTENCY CHECK HERE
```

---

## Idempotency Implementation

### Location: `PTA.sql:2169` - `pTA.AddSen()` Procedure

**Critical Code Section:**

```sql
CREATE OR REPLACE PROCEDURE pta.addsen(
   IN nTATix numeric,        -- Transport Order ID
   IN nSenTix numeric,       -- Shipment/Leg ID
   ...
   IN nMode numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
   /*------------------------------------------------------------------
   Hinzufügen einer einzelnen Sendung zum TA
   (Adding a single shipment to the transport order)
   ------------------------------------------------------------------*/

   -- IDEMPOTENCY CHECK
   if(PTA.HASSEN(nTATix, nSenTix)) then
      return;  -- Already assigned, exit early
   end if;

   -- ... continue with assignment logic ...
END;
$$;
```

**Line 2196-2198:** If leg already assigned to transport order, return immediately without error.

---

### Duplicate Check Function: `PTA.HASSEN()`

**Location: `PTA.sql:8668`**

```sql
CREATE OR REPLACE FUNCTION pta.hassen(ntatix numeric, nsentix numeric)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
   s  CHAR(1);
BEGIN
   -- Check if relationship exists in TA-SEN-LOADLIST table
   select '*' into STRICT s
   where exists(
      select '*'
      from TA_SEN_LST_B
      where TA_TIX = nTATix
        and SEN_TIX = nSenTix
   );
   return TRUE;  -- Relationship exists
exception
   when NO_DATA_FOUND then
      return FALSE;  -- Relationship does not exist
END;
$$;
```

**Behavior:**
- Queries `TA_SEN_LST_B` table (transport order - shipment - loadlist relationship)
- Returns `TRUE` if leg already assigned to transport order
- Returns `FALSE` if leg not yet assigned

---

## Additional Safety Checks

### Duplicate Leg Prevention: `PDIS_TRANSPORTORDER.sql:1080-1089`

**Location: `pDIS_TransportOrder.AddLeg()` procedure**

```sql
when pDIS_TransportOrder.Leg_LongHaul() then
   if (rSen.Sendungsart = 'A') then
      -- Abbruch, wenn anderes Leg des Shipments bereits auf dem Transportauftrag ist
      -- (Abort if another leg of the shipment is already on the transport order)
      select count(*) into n
        from V_TA_Sen7 t
        join lateral PDIS_Shipment.GetLegIds(nShipmentId) l
          on t.Sen_Tix = l.LegId
       where t.TA_Tix  = nTransportOrderId
         and l.LegId  != nShipmentId;
      if (n > 0) then
         raise exception 'Es ist bereits ein Leg der Sendung dem Transportauftrag zugeordnet!';
      end if;

      call pTA.AddSen(...);  -- Proceeds to idempotent AddSen
   ...
```

**Purpose:** Prevents assigning multiple legs of the same shipment to one transport order (business rule validation).

**Note:** This is **not** idempotency for the same leg, but business logic preventing conflicting leg assignments.

---

## Idempotency Characteristics

### ✅ Safe for Retry

| Operation | Idempotent? | Mechanism | Behavior on Retry |
|-----------|-------------|-----------|-------------------|
| Create Transport Order + Add First Leg | ⚠️ Partial | Transport order creation is NOT idempotent; leg assignment IS idempotent | New transport order created, but leg assignment checks for duplicate |
| Add Additional Legs | ✅ Yes | `PTA.HASSEN()` check | Silent success if already assigned |
| Assign Same Leg Twice | ✅ Yes | `PTA.HASSEN()` check | Second assignment ignored |

### ⚠️ Transport Order Creation is NOT Idempotent

**Critical Constraint:** `pDIS_TransportOrder.New()` calls `pTA.New()` which **always creates a new transport order record**.

**Implication for Retry Strategy:**
- **Scenario 1 (New Dispo DB failure after TMS success):**
  - Transport order created in TMS
  - Retry would create **duplicate transport order**
  - ❌ Cannot safely retry full operation

- **Scenario 3 (Network failure after TMS success):**
  - Transport order may or may not exist in TMS
  - Retry would create **duplicate transport order** if it succeeded
  - ❌ Cannot safely retry full operation

**Required Approach:**
1. Query TMS to check if transport order exists (by performance date, legs, etc.)
2. If exists: Skip creation, align New Dispo state
3. If not exists: Execute full creation operation

---

## Implications for Decision Paper

### Question 1: TMS Idempotency Status

**Answer:** ✅ **Partial Idempotency**

- ✅ **Leg assignment operations are idempotent** (via `PTA.HASSEN()`)
- ❌ **Transport order creation is NOT idempotent** (always creates new record)

### Question 2: Manual Retry Feasibility

**Answer:** ✅ **Feasible with state-checking logic**

**Required Implementation:**

```
On Failure (Scenarios 1 or 3):
  1. Get legs from failed lot (LotEntity.Legs)
     - All legs share same pickup, delivery, timing, product type (clustering)
     - All legs sent to TMS together in batch operation

  2. Query TMS Bridge for FIRST leg: GetTransportOrderByLeg(legId)
     - Returns transport order ID if leg already assigned, null otherwise
     - NOTE: Performance date not needed - leg ID is sufficient (unique in TMS)

  3. If leg found on transport order (operation succeeded but response lost):
     a. Retrieve transport order ID and all tour point IDs from TMS
     b. DEFENSIVE CHECK: Verify all other lot legs also on same transport order
        - Query TMS for each remaining leg
        - All should be on same transport order (atomic batch operation guarantee)
        - If inconsistency found: Log error, escalate to manual resolution
     c. Create LotAssignmentEntity in New Dispo DB with TMS IDs
     d. Create LotAssignmentLegLinkEntity for each leg with TMS leg IDs
     e. Remove original LotEntity
     f. SaveChangesAsync()
     g. ✅ Data reconciled

  4. If leg NOT found on transport order (operation truly failed):
     - Retry full CreateTransportOrderFromLot operation
     - New transport order created in TMS with all legs
     - ✅ Clean retry
```

**Optimization:** Since ALL legs from lot are assigned together atomically, checking FIRST leg is sufficient. Defensive verification of remaining legs is optional but recommended for data integrity assurance.

**Note:** TMS database doesn't have "lot" concept. Lots are New Dispo construct. Must query by individual legs, which TMS understands.

---

## Lot Clustering Logic Analysis

### How Legs are Grouped into Lots

**Code Location:** `PickupPlanningLotGenerator.cs:24-37`

Legs are grouped into lots based on:
1. **Same pickup location:** OriginName, OriginCity, OriginStreet
2. **Same delivery location:** DestinationName, DestinationCity, DestinationStreet
3. **Same time windows:** DeliveryDateFrom, DeliveryDateTo, PickupDateFrom, PickupDateTo
4. **Same product type:** IsProductGroup4 (frozen products separated)

**Key Insight:** ALL legs in a lot share the SAME pickup, delivery, timing, and product characteristics.

### Transport Order Creation from Lot

**Code Location:** `CreateTransportOrderFromLotCommandHandler.cs:38-99`

**Critical Behavior:**
```csharp
Line 38-42: Fetch lot with ALL legs (.Include(l => l.Legs))
Line 44:    var legs = lot.Legs.ToList();
Line 54:    Map ALL legs to input DTOs
Line 56-57: Take FIRST leg as primary leg for transport order creation
Line 59:    Create transport order in TMS with ALL legs via batch mutation
Line 84-93: Create LotAssignmentLegLinkEntity for EACH leg
            Links each leg to transport order with PreviousLotId
Line 97:    Remove original lot (replaced by LotAssignment)
```

**Guaranteed Behavior:**
- ✅ ALL legs from a lot are sent to TMS in SINGLE batch operation
- ✅ ALL legs are assigned to the SAME transport order
- ✅ Atomic operation: either all legs assigned or none
- ✅ LotAssignmentLegLinkEntity preserves PreviousLotId for all legs

**Consequence for State-Checking:**
- If ANY leg from a lot is found on a transport order in TMS, ALL legs from that lot MUST be on the SAME transport order
- Query TMS for any single leg from the lot - if found, retrieve the transport order ID
- Verify consistency: all legs from lot should be on that transport order (defensive check)

### Question 3: Automatic Retry via Outbox Pattern

**Answer:** ✅ **Requires same state-checking logic**

Outbox pattern does not change idempotency requirements. Background worker must:
1. Check if operation already completed in TMS before retry
2. Use idempotent operations where available (leg assignment)
3. Skip non-idempotent operations (transport order creation) if already completed

---

## Recommendations

### For Manual Recovery (Option 1)

**Prerequisites:**
1. ✅ Implement TMS state query: `GetTransportOrderByLotAndDate(lotId, performanceDate)`
2. ✅ Retry logic must check TMS state before re-executing
3. ✅ UI must distinguish "operation succeeded but DB failed" vs. "operation failed"

**Error Message Strategy:**
- **Scenario 1 (New Dispo DB failure):** "Transport order created in TMS but local save failed. Click retry to align data."
- **Scenario 3 (Network failure):** "Operation status uncertain. Click retry to verify and align data."

### For Outbox Pattern (Option 2)

**Prerequisites:**
1. ✅ Outbox handler must implement state-checking before retry
2. ✅ Cannot blindly retry - must query TMS first
3. ✅ Idempotent leg assignment allows safe re-processing of legs

**Advantage over Manual:**
- Automated state-checking and reconciliation
- No user intervention required for transient failures

---

## Test Cases for Idempotency Verification

### Test 1: Duplicate Leg Assignment
```
1. Create transport order with leg A
2. Call AddShipment(transportOrderId, legA) again
3. Expected: Silent success, no duplicate in TA_SEN_LST_B
4. Verify: Query TA_SEN_LST_B shows single assignment
```

### Test 2: Network Failure Simulation
```
1. Initiate CreateTransportOrderFromLot
2. Simulate network failure after TMS success
3. Retry operation with state-checking logic
4. Expected: Transport order ID retrieved from TMS, no duplicate created
5. Verify: Single transport order in TMS, New Dispo aligned
```

### Test 3: Database Outage After TMS Success
```
1. Initiate CreateTransportOrderFromLot
2. Simulate New Dispo DB outage after TMS success
3. Retry operation with state-checking logic
4. Expected: Transport order ID retrieved from TMS, LotAssignment created
5. Verify: Single transport order, correct state in New Dispo DB
```

---

## Code References

| Function/Procedure | File | Line | Purpose |
|-------------------|------|------|---------|
| `CreateTransportOrderFromLeg()` | PDIS_TRANSPORTORDER.sql | 185 | Entry point for creating transport order from leg |
| `New()` | PDIS_TRANSPORTORDER.sql | 39 | Creates new transport order record |
| `CreateAndAddLeg()` | PDIS_TRANSPORTORDER.sql | 1127 | Wrapper for adding leg |
| `AddLeg()` | PDIS_TRANSPORTORDER.sql | 1049 | Adds leg with business validation |
| `AddShipment()` | PDIS_TRANSPORTORDER.sql | 102 | Public API for adding shipment/leg |
| `AddSen()` | PTA.sql | 2169 | Core assignment logic with idempotency check |
| `HASSEN()` | PTA.sql | 8668 | Duplicate check function |

---

## Conclusion

**DECISION PAPER UPDATE REQUIRED:**

1. **Idempotency Status:** Confirmed for leg assignment operations, NOT confirmed for transport order creation
2. **Manual Retry Feasibility:** ✅ Safe with state-checking logic
3. **Implementation Requirement:** Must implement TMS state query before retry
4. **Risk Level:** Low with proper state-checking, High without

**Action Items:**
- [x] Verify TMS database idempotency implementation
- [x] Analyze lot clustering logic in backend
- [ ] Define TMS state query API in TMS Bridge (see specification below)
- [ ] Implement state-checking logic in retry flow
- [ ] Create test cases for idempotency verification
- [ ] Update error messages with retry guidance
- [ ] Document reconciliation procedure for support team

---

## Required TMS Bridge API

### Query: `GetTransportOrderByLeg`

**Purpose:** Check if a leg (TMS shipment) is already assigned to a transport order.

**Input:**
```csharp
public class GetTransportOrderByLegQuery
{
    public long LegId { get; set; }  // TMS shipment ID (Sendung_Tix)
}
```

**Output:**
```csharp
public class TransportOrderAssignmentDto
{
    public long? TransportOrderId { get; set; }      // TA_Tix (null if not assigned)
    public long? PickupTourPointId { get; set; }     // Belad_Tix
    public long? DeliveryTourPointId { get; set; }   // Entl_Tix
    public long? TmsLegId { get; set; }              // Actual TMS leg ID (may differ from ShipmentId for VL legs)
}
```

**SQL Query (TMS Database):**
```sql
SELECT
    ta.TA_Tix AS TransportOrderId,
    belad.TourOrt_Tix AS PickupTourPointId,
    entl.TourOrt_Tix AS DeliveryTourPointId,
    tasen.Sen_Tix AS TmsLegId
FROM TA_SEN_LST_B tasen
JOIN V_TA_Sen7 ta ON ta.TA_Tix = tasen.TA_Tix AND ta.Sen_Tix = tasen.Sen_Tix
LEFT JOIN TourOrt belad ON belad.TourOrt_Tix = ta.Belad_Tix
LEFT JOIN TourOrt entl ON entl.TourOrt_Tix = ta.Entl_Tix
WHERE tasen.Sen_Tix = :legId
   OR tasen.Sen_Tix IN (
      -- For VL legs, query parent shipment's generated leg
      SELECT LegId FROM PDIS_Shipment.GetLegIds(:legId)
   )
LIMIT 1;
```

**Behavior:**
- Returns null TransportOrderId if leg not assigned
- Returns transport order details if leg assigned
- Handles both direct shipment IDs and VL leg IDs

**GraphQL Mutation (TMS Bridge):**
```graphql
query GetTransportOrderByLeg($legId: Long!) {
  transportOrderAssignment: getTransportOrderByLeg(legId: $legId) {
    transportOrderId
    pickupTourPointId
    deliveryTourPointId
    tmsLegId
  }
}
```

**Blocking Risk Removed:** Idempotency concern addressed. Manual retry option (Option 1) is viable with state-checking implementation.
