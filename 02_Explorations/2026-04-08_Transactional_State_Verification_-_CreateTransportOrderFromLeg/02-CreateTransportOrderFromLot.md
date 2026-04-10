# Transactional State Verification - CreateTransportOrderFromLot

**Date:** 2026-04-08  
**Status:** Approved (Joachim, 2026-04-09)

---

## Summary

This exploration documents the analysis of **transactional state verification** for the `CreateTransportOrderFromLot` flow. Unlike Flow #1 (CreateTransportOrderFromLeg), this operation:

1. Creates a Transport Order from an **entire Lot** (multiple legs)
2. Uses `CallCreateTransportOrderFromLeg` for the first leg, then `CallCreateAndAddLeg` for remaining legs
3. Multiple TMS mutations (higher partial failure risk than Flow #1)

---

## Analysis

### The Call Flow

```
Frontend 
    -> Backend (CreateTransportOrderFromLotCommandHandler)
        -> CreateTransportOrderFromLotSubHandler
            -> CallCreateTransportOrderFromLeg (first leg)
                -> pDIS_TransportOrder.CreateTransportOrderFromLeg
            -> CallCreateAndAddLeg (for each remaining leg)
                -> pDIS_TransportOrder.CreateAndAddLeg
```

### Key Difference from Flow #1

| Aspect | Flow #1 (FromLeg) | Flow #2 (FromLot) |
|--------|-------------------|-------------------|
| Input | Single Leg | Entire Lot (n legs) |
| TMS Mutations | 1 (CreateTransportOrderFromLeg) | 1 + (n-1) = n mutations |
| TMS Atomicity | Single call | Multiple calls (not atomic) |
| Partial Failure Risk | Lower | Higher (partial execution possible) |

### State Changes Traced

```
CreateTransportOrderFromLot(LotId, DatabaseIdentifier, ...)
    |
    +-> First Leg: CallCreateTransportOrderFromLeg
    |       -> Creates: Sendung record (TransportOrderId)
    |       -> Creates: Sen_Frk_Unt record
    |       -> Creates: Sen_Zuord (leg assignment)
    |       -> Creates/Reuses: Res_Hst (tour points) - IsNewPickupPoint/IsNewDeliveryPoint indicates
    |
    +-> Remaining Legs: CallCreateAndAddLeg (loop)
            -> Creates: Sen_Zuord per leg
            -> Creates/Reuses: Res_Hst (tour points may be shared if same location)
```

**Note:** Tour points (Res_Hst) are not necessarily created per leg. The `IsNewPickupPoint` and `IsNewDeliveryPoint` return values indicate whether new tour points were created or existing ones were reused.

### Function Signatures

**Backend Handler:**
```csharp
// CreateTransportOrderFromLotCommandHandler.cs
public async Task<CreateTransportOrderFromLotResponse> Handle(
    CreateTransportOrderFromLotCommand command, 
    CancellationToken cancellationToken)
```

**SubHandler:**
```csharp
// CreateTransportOrderFromLotSubHandler.cs
public async Task<CreateTransportOrderFromLotSubHandlerResponse> Handle(
    CreateTransportOrderFromLotSubHandlerRequest request)
```

**TMS Bridge Mutations:**
- `CallCreateTransportOrderFromLeg` (see Flow #1)
- `CallCreateAndAddLeg`:
  ```graphql
  mutation CallCreateAndAddLeg($input: CreateAndAddLegInput!) {
    callCreateAndAddLeg(input: $input) {
      legId
      pickupPointId
      isNewPickupPoint
      deliveryPointId
      isNewDeliveryPoint
    }
  }
  ```

---

## Table-to-View Mapping

| Table Written | Verification View | Key Columns |
|---------------|-------------------|-------------|
| `Sendung` | `V_DIS_TransportOrder` | TransportOrderId, LoadingDate, Company, Branch |
| `Sen_Frk_Unt` | `V_DIS_TransportOrder` | ContractorId, TruckId, TrailerId |
| `Sen_Zuord` | `V_TA_Sen7`, `V_DIS_Leg` | TransportOrderId (via TA_Tix), per leg |
| `Res_Hst` | `V_DIS_TO_Tourpoint` | TourPointId, Type (Pickup/Delivery) - may reuse existing |

---

## Verification Candidates

### Primary Candidate: V_DIS_Leg

Check if legs from the Lot are already assigned to a Transport Order:

```sql
-- For each leg in the original lot
SELECT l.ShipmentId, l.LegId, l.LegType, l.TransportOrderId
FROM V_DIS_Leg l
WHERE l.ShipmentId IN (:ShipmentIds)  -- all shipments from original lot
  AND l.LegType = :LegType
  AND l.TransportOrderId IS NOT NULL
```

**Semantics:**
- Rows exist with TransportOrderId -> Legs already assigned to a TO in TMS
- Returns the existing TransportOrderId
- Can count how many legs are already assigned vs expected

### Secondary Candidate: V_DIS_TransportOrder

For full parameter verification, cross-check Transport Order details:

```sql
SELECT t.TransportOrderId, t.LoadingDate, t.Company, t.Branch, t.TransportMode,
       COUNT(l.LegId) as assigned_leg_count
FROM V_DIS_TransportOrder t
JOIN V_DIS_Leg l ON l.TransportOrderId = t.TransportOrderId
WHERE l.ShipmentId IN (:ShipmentIds)
GROUP BY t.TransportOrderId, t.LoadingDate, t.Company, t.Branch, t.TransportMode
```

---

## Verification Strategies

### Strategy 1: TMS Leg Assignment Check (Recommended)

```sql
-- Check: Are any legs from this Lot already assigned to a TO?
SELECT l.TransportOrderId, 
       COUNT(*) as assigned_leg_count,
       array_agg(l.LegId) as assigned_legs
FROM V_DIS_Leg l
WHERE l.ShipmentId IN (:ShipmentIds)  -- all shipments from the Lot
  AND l.LegType IN ('VL', 'HL')       -- PreCarriage or LongHaul
  AND l.TransportOrderId IS NOT NULL
GROUP BY l.TransportOrderId
```

**Semantics:**
- No rows -> Safe to execute (no legs assigned yet)
- Rows exist -> Check if ALL legs are assigned to SAME TO
  - All legs to same TO with expected count -> IDEMPOTENT (return existing TO)
  - Partial assignment -> PARTIAL FAILURE (needs recovery)
  - Different TOs -> CONFLICT (data integrity issue)

**Pros:**
- Queries source of truth directly
- Detects partial failures
- Single query for all legs

### Strategy 2: Full Parameter Match Check

```sql
-- Step 1: Get existing assignment state from TMS
SELECT l.TransportOrderId, l.ShipmentId, l.LegId, l.LegType
FROM V_DIS_Leg l
WHERE l.ShipmentId IN (:ShipmentIds)
  AND l.TransportOrderId IS NOT NULL;

-- Step 2: If TO exists, verify parameters match request
SELECT t.TransportOrderId, t.LoadingDate, t.Company, t.Branch
FROM V_DIS_TransportOrder t
WHERE t.TransportOrderId = :ExistingTransportOrderId
```

Then in application logic:
```
IF t.LoadingDate = :PerformanceDate 
   AND t.Company = :Company 
   AND t.Branch = :Branch
   AND assigned_leg_count = expected_leg_count
   -> IDEMPOTENT: Return existing TO
   
ELSE IF assigned_leg_count < expected_leg_count
   -> PARTIAL FAILURE: Some legs missing, needs completion
   
ELSE
   -> CONFLICT: Parameters mismatch or unexpected state
```

**Use case:** Distinguishing "retry of same request" from "different request for same data"

---

## Transaction Boundaries

### Risk Analysis

```
┌─────────────────────────────────────────────────────────────────┐
│ TMS Bridge Calls (NOT atomic - multiple GraphQL mutations)      │
│ ┌─────────────────────┐  ┌─────────────────────┐               │
│ │ CreateTO FromLeg    │  │ CreateAndAddLeg x N │               │
│ │ (Leg 1)             │  │ (Legs 2..N)         │               │
│ └─────────────────────┘  └─────────────────────┘               │
│            ↓                      ↓                             │
│         SUCCESS?              SUCCESS?                          │
└─────────────────────────────────────────────────────────────────┘
```

### Failure Windows

| Failure Point | State | Verification Query Result |
|---------------|-------|---------------------------|
| Before any call | No state | No rows in V_DIS_Leg |
| After 1st call, before 2nd | TO + 1 leg | 1 leg with TransportOrderId |
| After some AddLeg calls | TO + partial legs | Partial legs with same TransportOrderId |
| After all calls | TO + all legs | All legs with same TransportOrderId |

### Idempotency Check Logic

```
Query V_DIS_Leg for all ShipmentIds from Lot:

IF no legs have TransportOrderId:
    -> Safe to execute
    
ELSE IF all legs assigned to SAME TransportOrderId:
    IF leg_count = expected_count:
        -> IDEMPOTENT: Return existing TransportOrderId
    ELSE:
        -> PARTIAL: Some legs missing, consider completion
    
ELSE IF legs assigned to DIFFERENT TransportOrderIds:
    -> CONFLICT: Data integrity issue
```

---

## Open Questions (for Business)

### Q1: Partial Failure Handling
**Question:** If TMS has partial legs assigned (e.g., 2 of 5 legs), should we:
- A) Complete the remaining legs to the same TO
- B) Fail and require manual intervention
- C) Consider it a conflict

### Q2: Leg Count Verification
**Question:** Should verification ensure ALL legs from the original lot are assigned, or is "at least one" sufficient for idempotency?

---

## Related Files

| File | Purpose |
|------|---------|
| `Code/Disposition-Backend/.../CreateTransportOrderFromLot/CreateTransportOrderFromLotCommandHandler.cs` | Backend entry point |
| `Code/Disposition-Backend/.../CreateTransportOrderFromLot/SubHandlers/CreateTransportOrderFromLotSubHandler.cs` | TMS Bridge orchestration |
| `Code/Disposition-Abstraction-Layer/.../CreateTransportOrderFromLegMutation.cs` | GraphQL: first leg |
| `Code/Disposition-Abstraction-Layer/.../CreateAndAddLegMutation.cs` | GraphQL: additional legs |
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` | TMS stored procedures |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_LEG.sql` | Verification view |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER.sql` | TO verification view |

---

## Comparison with Flow #1

| Aspect | Flow #1 | Flow #2 |
|--------|---------|---------|
| Scope | Single leg | Entire lot (n legs) |
| TMS Atomicity | Single mutation | Multiple mutations (not atomic) |
| Verification View | V_DIS_Leg (1 row) | V_DIS_Leg (n rows, same TO) |
| Partial Failure Risk | Low | High |
| Verification Complexity | Simple (row exists?) | Count-based (all legs assigned?) |

---

## Next Steps

1. [ ] Clarify partial failure handling strategy (Q1)
2. [ ] Define leg count verification requirements (Q2)
3. [ ] Implement idempotency check using V_DIS_Leg verification query
