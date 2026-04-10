# Transactional State Verification - AssignLotToTransportOrder

**Date:** 2026-04-09  
**Status:** Approved (Joachim, 2026-04-09)

---

## Summary

This exploration documents the analysis of **transactional state verification** for the `AssignLotToTransportOrderCommandHandler` flow. This operation:

1. Assigns all legs of a Lot to an **existing** Transport Order (no TO creation)
2. Uses `CallCreateAndAddLeg` for every leg (N mutations via GraphQL Batch API)
3. Optionally repositions tour points via `CallMoveTourPoint` per leg
4. Sends all mutations in a single GraphQL Batch request (sequential execution)

---

## Analysis

### The Call Flow

```
Frontend (PUT /transportorders/{toId}/lots/{lotId})
    -> Backend (AssignLotToTransportOrderCommandHandler)
        -> Path A: AssignLotToTransportOrderSubHandler
        |      -> GraphQL Batch: CallCreateAndAddLeg x N legs
        |             -> pDIS_TransportOrder.CreateAndAddLeg (per leg)
        |
        -> Path B: AssignLotAndMoveTourPointsSubHandler
               -> GraphQL Batch:
                    Operation 1: CallCreateAndAddLeg x N legs (@export pickupPointIds)
                    Operation 2..N+1: CallMoveTourPoint per leg (uses exported pickupPointId)
                        -> pDIS_TransportOrder.MoveTourpoint (per leg)
```

### Path Selection

```
IF destinationTourPointId IS NULL OR relationType IS NULL:
    -> Path A (no repositioning)
ELSE:
    -> Path B (with repositioning)
```

### Key Differences from Other Flows

| Aspect | Flow #2 (FromLot) | Flow #3 (AssignLeg) | Flow #4 (AssignLot) |
|--------|-------------------|---------------------|---------------------|
| Transport Order | **Created** by first mutation | Pre-existing | Pre-existing |
| Leg Count | N | 1 | N |
| Repositioning | Not supported | Optional | Optional |
| Max TMS Mutations | N | 2 | 2N |
| Partial Failure Risk | High | Low | **Highest** |

### State Changes Traced

```
AssignLotToTransportOrder(TransportOrderId, LotId, DestinationTourPointId?, RelationType?)
    |
    +-> Per Leg [N times]: pDIS_TransportOrder.CreateAndAddLeg
    |       |
    |       +-> pDIS_TransportOrder.AddLeg
    |               |
    |               +-> [LegType = 'HL'] pTA.AddSen()
    |               |       -> Writes: Sen_Zuord (via Sen.Link)      -> resolved via: V_TA_Sen7, V_DIS_Leg
    |               |       -> Updates: Sendung (Status_Dis)         -> resolved via: V_DIS_Leg (implicit)
    |               |       -> Creates/Reuses: Res_Hst               -> resolved via: V_DIS_TO_Tourpoint
    |               |       -> Creates: Res_Hst_Zus (sen link)       -> resolved via: V_DIS_TO_Tourpoint
    |               |       -> Creates: Pers (address copy)          -> (internal)
    |               |       -> Creates: Sen_Hst (event log)          -> (internal)
    |               |       -> Creates: TA_Sen_Lst_B (loading list)  -> (internal)
    |               |       -> LegId = ShipmentId (for HL legs)
    |               |
    |               +-> [LegType = 'VL'] pTA_VL.AddLeg()
    |                       -> Writes: Sen_Zuord (via Sen.Link)      -> resolved via: V_TA_Sen7, V_DIS_Leg
    |                       -> Updates: Sendung (Status_Dis)         -> resolved via: V_DIS_Leg (implicit)
    |                       -> Creates/Reuses: Res_Hst               -> resolved via: V_DIS_TO_Tourpoint
    |                       -> Creates: Res_Hst_Zus (sen link)       -> resolved via: V_DIS_TO_Tourpoint
    |                       -> Creates: Pers (address copy)          -> (internal)
    |                       -> Creates: Sen_Hst (event log)          -> (internal)
    |                       -> May create new Leg via pDIS_Shipment.CreateLeg()
    |
    +-> [Path B only] Per Leg [N times]: pDIS_TransportOrder.MoveTourpoint
            |
            +-> PTA.MOVEORT (same-TO variant)
                    -> Updates: Res_Hst.Lfd_N (reorder)             -> resolved via: V_DIS_TO_Tourpoint.SequenceNumber
                    -> Updates: TA_Sen_Lst_B.POS_N (loading order)  -> (internal)
```

### Function Signatures

**DIS Wrapper: CreateAndAddLeg**
```sql
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.CreateAndAddLeg(
    IN  TransportOrderId  numeric,
    IN  ShipmentId        numeric,
    IN  LegType           character varying,
    IN  Mode              numeric,
    OUT PickupPointId     numeric,
    OUT IsNewPickupPoint  boolean,
    OUT DeliveryPointId   numeric,
    OUT IsNewDeliveryPoint boolean,
    OUT LegId             numeric)
```

**DIS Wrapper: MoveTourpoint**
```sql
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.MoveTourpoint(
    TransportOrderTix       numeric,
    SourceTourpointId       numeric,
    DestinationTourpointId  numeric,
    RelationType            numeric,
    Mode                    numeric)
```

### GraphQL Batch Structure

**Path A (no repositioning):**
```graphql
mutation CallCreateAndAddLeg {
    leg{shipmentId1}: callCreateAndAddLeg(input: { transportOrderId, shipmentId1, legType }) {
        pickupPointId, isNewPickupPoint, deliveryPointId, isNewDeliveryPoint, legId
    }
    leg{shipmentId2}: callCreateAndAddLeg(input: { transportOrderId, shipmentId2, legType }) { ... }
    # ... N legs
}
```

**Path B (with repositioning):**
```graphql
# Operation 1: Add all legs, export pickupPointIds
mutation CallCreateAndAddLeg {
    leg{shipmentId1}: callCreateAndAddLeg(input: { ... }) {
        pickupPointId @export(as: "pickupPointId{shipmentId1}")
        ...
    }
    leg{shipmentId2}: callCreateAndAddLeg(input: { ... }) {
        pickupPointId @export(as: "pickupPointId{shipmentId2}")
        ...
    }
}

# Operation 2..N+1: Move tour points (uses @export from operation 1)
mutation CallMoveTourPoint{shipmentId1}($pickupPointId{shipmentId1}: Long!) {
    moveTourPoint{shipmentId1}: callMoveTourpoint(input: {
        sourceTourpointId: $pickupPointId{shipmentId1}
        destinationTourpointId, relationType, sourceTransportOrderTix, mode: null
    }) { isTourpointMoved }
}
```

---

## Table-to-View Mapping

| Table Written | Operation | Verification View | Key Columns |
|---------------|-----------|-------------------|-------------|
| `Sen_Zuord` | INSERT (per leg) | `V_TA_Sen7`, `V_DIS_Leg` | TransportOrderId (via TA_Tix), LegId (via Sen_Tix) |
| `Sendung` | UPDATE (per leg) | `V_DIS_Leg` | Status_Dis |
| `Res_Hst` | INSERT or reuse (per leg) | `V_DIS_TO_Tourpoint` | TourPointId, Type, SequenceNumber |
| `Res_Hst_Zus` | INSERT (per tour point) | `V_DIS_TO_Tourpoint` | ShipmentAmount (aggregated) |
| `Res_Hst.Lfd_N` | UPDATE (MoveTourpoint) | `V_DIS_TO_Tourpoint` | SequenceNumber |
| `TA_Sen_Lst_B` | INSERT/UPDATE | (loading list views) | POS_N |

---

## Verification Candidates

### Primary Candidate: V_DIS_Leg

Check how many legs from the Lot are assigned to the target Transport Order:

```sql
SELECT l.ShipmentId, l.LegId, l.LegType, l.TransportOrderId
FROM V_DIS_Leg l
WHERE l.ShipmentId IN (:ShipmentIds)   -- all shipments from the Lot
  AND l.LegType = :LegType
  AND l.TransportOrderId = :TransportOrderId
```

### Secondary Candidate: V_DIS_TO_Tourpoint

For verifying tour point state (especially Path B):

```sql
SELECT tp.TransportOrderId, tp.TourPointId, tp.SequenceNumber, tp.Type
FROM V_DIS_TO_Tourpoint tp
WHERE tp.TransportOrderId = :TransportOrderId
ORDER BY tp.SequenceNumber
```

---

## Verification Strategies

### Strategy 1: Count-Based Leg Assignment Check (Recommended)

```sql
SELECT l.TransportOrderId,
       COUNT(*) AS assigned_leg_count,
       array_agg(l.LegId ORDER BY l.LegId) AS assigned_leg_ids
FROM V_DIS_Leg l
WHERE l.ShipmentId IN (:ShipmentIds)
  AND l.LegType IN ('VL', 'HL')
  AND l.TransportOrderId = :TransportOrderId
GROUP BY l.TransportOrderId
```

**Semantics:**
- No rows -> No legs assigned yet -> PROCEED
- `assigned_leg_count = :ExpectedLegCount` -> All legs assigned -> IDEMPOTENT
- `0 < assigned_leg_count < :ExpectedLegCount` -> PARTIAL FAILURE (K of N legs assigned)

### Strategy 2: Conflict Detection

```sql
SELECT l.ShipmentId, l.LegId, l.LegType, l.TransportOrderId
FROM V_DIS_Leg l
WHERE l.ShipmentId IN (:ShipmentIds)
  AND l.LegType IN ('VL', 'HL')
  AND l.TransportOrderId IS NOT NULL
```

Then in application logic:
```
assigned_to_target = legs WHERE TransportOrderId = :TransportOrderId
assigned_to_other  = legs WHERE TransportOrderId != :TransportOrderId

IF assigned_to_target.count = expected_count:
    -> IDEMPOTENT
ELSE IF assigned_to_other.count > 0:
    -> CONFLICT: Some legs already assigned to a different TO
ELSE IF assigned_to_target.count > 0 AND assigned_to_target.count < expected_count:
    -> PARTIAL FAILURE: Complete remaining legs
ELSE:
    -> PROCEED
```

**Note:** Unlike Flows #1/#2, there is no TO parameter comparison needed (Company, Branch, LoadingDate) because this flow assigns to an existing TO identified by `TransportOrderId`.

---

## Transaction Boundaries

### Risk Analysis

**Path A (no repositioning):**
```
┌────────────────────────────────────────────────────────────────────────────┐
│ GraphQL Batch: 1 operation, N aliased mutations                           │
│ ┌──────────────┐ ┌──────────────┐     ┌──────────────┐                    │
│ │ AddLeg       │ │ AddLeg       │ ... │ AddLeg       │                    │
│ │ (Leg 1)      │ │ (Leg 2)      │     │ (Leg N)      │                    │
│ └──────────────┘ └──────────────┘     └──────────────┘                    │
└────────────────────────────────────────────────────────────────────────────┘
```

**Path B (with repositioning):**
```
┌────────────────────────────────────────────────────────────────────────────┐
│ GraphQL Batch: 1 + N operations                                           │
│                                                                            │
│ Operation 1: CallCreateAndAddLeg (all N legs, @export pickupPointIds)      │
│ Operations 2..N+1: CallMoveTourPoint (per leg, sequential)                 │
└────────────────────────────────────────────────────────────────────────────┘
```

Each mutation executes as its own database transaction. The batch is **not atomic**.

### Failure Windows

| Failure Point | TMS State | Detection |
|---------------|-----------|-----------|
| Before any call | No leg assignments | assigned_count = 0 |
| After K of N AddLeg | K legs assigned to TO | 0 < assigned_count < N |
| After all N AddLeg | All legs assigned | assigned_count = N |
| After all AddLeg + K of N Moves | All legs assigned, K repositioned | assigned_count = N, check tour point order |
| After everything | All legs assigned and repositioned | assigned_count = N, correct order |

### MoveTourpoint Exception Handling

The `MoveTourpoint` procedure catches all exceptions and returns normally (does NOT re-raise):

```sql
EXCEPTION
    when OTHERS then
        call reshst.resetmodus();  -- cleanup
        RAISE NOTICE '%', v_message;
        -- NOTE: Does NOT re-raise! Returns normally.
```

**Implication:** Path B may complete with all legs assigned but some tour points not repositioned. This is a "soft failure" — the legs are on the TO, but the stop order may be wrong.

---

## Idempotency Check Logic

```
Input: TransportOrderId, ShipmentIds[] (from Lot), ExpectedLegCount

Query V_DIS_Leg for all ShipmentIds against the target TransportOrderId:

CASE 1: assigned_count = 0
    -> PROCEED: Execute the full operation

CASE 2: assigned_count = ExpectedLegCount
    -> IDEMPOTENT: All legs already assigned to this TO
    -> Return success without re-executing

CASE 3: 0 < assigned_count < ExpectedLegCount
    -> PARTIAL FAILURE: K of N legs assigned
    -> Identify missing legs (ShipmentIds NOT in assigned set)
    -> Decision: Complete remaining legs OR fail

CASE 4: Any leg assigned to DIFFERENT TransportOrderId
    -> CONFLICT: Leg already on another TO
    -> Fail with error
```

### TMS-Level Idempotency for AddLeg

Both paths in `AddLeg` have built-in early-return checks:
- **HL path:** `pTA.HasSen(nTATix, nSenTix)` checks `TA_Sen_Lst_B` — returns silently if already assigned
- **VL path:** `pTA_VL.HasSen(nTATix, nLegTix)` checks `Sen_Zuord` — returns silently if already assigned

This means **re-executing a complete retry is safe at the TMS level**. Already-assigned legs will be silently skipped.

---

## Open Questions

### Q1: Partial Failure Completion Strategy
**Question:** If K of N legs are assigned after a partial failure, should the retry:
- A) Add only the missing (N-K) legs to the same TO
- B) Re-send all N legs (relying on TMS-level idempotency of `HasSen`)
- C) Fail and require manual intervention

**Recommendation:** Option B is safest given that `HasSen` makes re-adding already-assigned legs a no-op.

### Q2: MoveTourpoint Failure Handling
**Question:** If all legs are assigned but some `MoveTourpoint` calls returned `isTourpointMoved = false`, should this be treated as a failure?

**Note:** The current Backend does not check `isTourpointMoved` per leg. A failed move is silently ignored.

### Q3: Tour Point Order Verification
**Question:** Should verification for Path B also check that tour points are in the expected order (via `V_DIS_TO_Tourpoint.SequenceNumber`), or is leg assignment count sufficient?

---

## Related Files

| File | Purpose |
|------|---------|
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` | DIS wrappers: CreateAndAddLeg, AddLeg, MoveTourpoint |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` | Core: AddSen, MoveOrt, HasSen |
| `Code/tms-alloydb-schema/src/sql/package/PTA_VL.sql` | VL leg handling: AddLeg, HasSen |
| `Code/tms-alloydb-schema/src/sql/package/RESHST.sql` | Tour point management: Add, Move, AddSen |
| `Code/tms-alloydb-schema/src/sql/package/SEN.sql` | Sen.Link (writes Sen_Zuord) |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_LEG.sql` | Primary verification view |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_TO_TOURPOINT.sql` | Tour point verification view |
| `Code/tms-alloydb-schema/src/sql/view/v_ta_sen7.sql` | Leg-to-TO assignment view |
| `Code/Disposition-Abstraction-Layer/.../CreateAndAddLeg/CreateAndAddLegMutation.cs` | TMS Bridge: AddLeg |
| `Code/Disposition-Abstraction-Layer/.../MoveTourpoint/MoveTourpointMutation.cs` | TMS Bridge: MoveTourpoint |

---

## Comparison with All Flows

| Aspect | #1 FromLeg | #2 FromLot | #3 AssignLeg | #4 AssignLot | #5 UnassignLots | #7 Delete |
|--------|-----------|-----------|-------------|-------------|----------------|----------|
| TO Created? | Yes | Yes | No | No | No | No |
| Leg Count | 1 | N | 1 | N | N | all |
| Max TMS Mutations | 1 | N | 2 | **2N** | N | 1 |
| TMS Atomicity | Single | Non-atomic | Single/Batch | **Non-atomic** | Non-atomic | Single |
| Partial Failure | None | High | Low | **Highest** | High | None |
| TMS Idempotency | No | No | HasSen | **HasSen** | No | No |
| Verification | Row exists | Count | Row exists | **Count + order** | Row absent | Row absent |
