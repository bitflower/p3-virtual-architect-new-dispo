# Transactional State Verification - AssignLegToTransportOrder

**Date:** 2026-04-09  
**Status:** Draft

---

## Summary

This exploration documents the analysis of **transactional state verification** for the `AssignLegToTransportOrderCommandHandler` flow (Flow #3). This operation:

1. Assigns a **single leg** to an **existing** Transport Order (no TO creation)
2. Uses `CallCreateAndAddLeg` for the single leg
3. Optionally repositions the pickup tour point via `CallMoveTourPoint`
4. Path B sends both mutations in a single GraphQL Batch request with `@export`

The TMS kernel provides **built-in idempotency** through `HasSen` checks: if the leg is already assigned to the TO, `AddLeg` returns silently without error. However, the OUT parameters (`PickupPointId`, etc.) are **NOT populated** on the HasSen early-return path.

---

## Analysis

### The Call Flow

```
Frontend (PUT /transportorders/{toId}/legs)
    -> Backend (AssignLegToTransportOrderCommandHandler)
        -> Path A: AssignLegToTransportOrderSubHandler
        |      -> GraphQL: CallCreateAndAddLeg (single mutation)
        |             -> pDIS_TransportOrder.CreateAndAddLeg
        |                 -> pDIS_TransportOrder.AddLeg
        |
        -> Path B: AssignLegAndMoveTourPointsSubHandler
               -> GraphQL Batch:
                    Operation 1: CallCreateAndAddLeg (@export pickupPointId)
                    Operation 2: CallMoveTourPoint (uses exported pickupPointId)
                        -> pDIS_TransportOrder.MoveTourpoint
```

### Path Selection

```
IF destinationTourPointId IS NULL OR relationType IS NULL:
    -> Path A (no repositioning)
ELSE:
    -> Path B (with repositioning)
```

### Key Differences from Other Flows

| Aspect | Flow #1 (FromLeg) | Flow #3 (AssignLeg) | Flow #4 (AssignLot) |
|--------|-------------------|---------------------|---------------------|
| Transport Order | **Created** by first mutation | Pre-existing | Pre-existing |
| Leg Count | 1 | 1 | N |
| Repositioning | Not supported | Optional | Optional |
| Max TMS Mutations | 1 | 2 | 2N |
| Partial Failure Risk | None | Low (Path B only) | **Highest** |

### State Changes Traced

```
AssignLegToTransportOrder(TransportOrderId, ShipmentId, LegType, DestinationTourPointId?, RelationType?)
    |
    +-> pDIS_TransportOrder.CreateAndAddLeg
    |       |
    |       +-> pDIS_TransportOrder.AddLeg
    |               |
    |               +-> [LegType = 'HL'] pTA.AddSen()
    |               |       -> HasSen check: TA_SEN_LST_B    -> IF TRUE: RETURN (idempotent)
    |               |       -> Writes: Sen_Zuord (via Sen.Link)      -> resolved via: V_TA_Sen7, V_DIS_Leg
    |               |       -> Writes: TA_SEN_LST_B (via AddSenLstB) -> resolved via: V_TA_Sen7
    |               |       -> Updates: Sendung (Status_Dis='L')     -> resolved via: V_DIS_Leg (implicit)
    |               |       -> Creates/Reuses: Res_Hst               -> resolved via: V_DIS_TO_Tourpoint
    |               |       -> Creates: Res_Hst_Zus (sen link)       -> resolved via: V_DIS_TO_Tourpoint
    |               |       -> Creates: Pers (address copy)          -> (internal)
    |               |       -> Creates: Sen_Hst (event log #12)      -> (internal)
    |               |       -> Creates: LST_B, LST_K (loading list)  -> (internal)
    |               |       -> LegId = ShipmentId (for HL legs)
    |               |
    |               +-> [LegType = 'VL'] pTA_VL.AddLeg()
    |                       -> HasSen check: Sen_Zuord (via pTA_NV.HasSen) -> IF TRUE: RETURN (idempotent)
    |                       -> Writes: Sen_Zuord (via Sen.Link)      -> resolved via: V_TA_Sen7, V_DIS_Leg
    |                       -> Updates: Sendung (Status_Dis='L')     -> resolved via: V_DIS_Leg (implicit)
    |                       -> Creates/Reuses: Res_Hst               -> resolved via: V_DIS_TO_Tourpoint
    |                       -> Creates: Res_Hst_Zus (sen link)       -> resolved via: V_DIS_TO_Tourpoint
    |                       -> Creates: Pers (address copy)          -> (internal)
    |                       -> Creates: Sen_Hst (event log #12)      -> (internal)
    |                       -> May create new Leg via pDIS_Shipment.CreateLeg()
    |
    +-> [Path B only] pDIS_TransportOrder.MoveTourpoint
            |
            +-> PTA.MOVEORT (same-TO variant)
            |       -> Updates: Res_Hst.Lfd_N (reorder)             -> resolved via: V_DIS_TO_Tourpoint.SequenceNumber
            |       -> Updates: TA_Sen_Lst_B.POS_N (loading order)  -> (internal)
            |
            EXCEPTION WHEN OTHERS:
                -> ResHst.ResetModus()  -- cleanup
                -> RAISE NOTICE (log only, NO re-raise!)
                -> Failure is SILENTLY SWALLOWED
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

### GraphQL Structure

**Path A (no repositioning):**
```graphql
mutation CallCreateAndAddLeg($databaseIdentifier: String!, $input: CreateAndAddLegInput!) {
    callCreateAndAddLeg(databaseIdentifier: $databaseIdentifier, input: $input) {
        pickupPointId, isNewPickupPoint, deliveryPointId, isNewDeliveryPoint, legId
    }
}
```

**Path B (with repositioning):**
```graphql
# Operation 1: Add leg, export pickupPointId
mutation CallCreateAndAddLeg {
    callCreateAndAddLeg(input: { transportOrderId, shipmentId, legType }) {
        pickupPointId @export(as: "pickupPointId")
        isNewPickupPoint, deliveryPointId, isNewDeliveryPoint, legId
    }
}

# Operation 2: Move tour point (uses @export from operation 1)
mutation CallMoveTourPoint($pickupPointId: Long!) {
    callMoveTourpoint(input: {
        sourceTourpointId: $pickupPointId
        destinationTourpointId, relationType, sourceTransportOrderTix, mode: null
    }) { isTourpointMoved }
}
```

---

## HasSen Idempotency Detail

The TMS kernel has **two different `HasSen` implementations** depending on leg type:

| Leg Type | HasSen Function | Check Table | Condition |
|----------|-----------------|-------------|-----------|
| **HL** (Long-haul) | `pTA.HasSen(TO, shipmentId)` | `TA_SEN_LST_B` | `TA_TIX = TO AND SEN_TIX = shipmentId` |
| **VL** (Pre-carriage) | `pTA_VL.HasSen` -> `pTA_NV.HasSen` | `Sen_Zuord` | `REF_TIX = TO AND SEN_TIX = LegId AND TYP = 'S'` |

**Behavior when HasSen returns TRUE:**
- Both VL and HL paths **return immediately without error** (silent no-op)
- No exception raised, no duplicate state created
- The OUT parameters (`PickupPointId`, `DeliveryPointId`, `LegId`) are **NOT populated** on early return

**Additional safety:** `Sen.Link` (which inserts into `Sen_Zuord`) handles unique constraint violations (`WHEN SQLSTATE '23505' then null`), so even without HasSen, duplicate inserts would not fail.

---

## Table-to-View Mapping

| Table Written | Operation | Verification View | Key Columns |
|---------------|-----------|-------------------|-------------|
| `Sen_Zuord` | INSERT (Sen.Link) | `V_TA_Sen7`, `V_DIS_Leg` | TransportOrderId (via TA_Tix), LegId (via Sen_Tix) |
| `Sendung` | UPDATE (Status_Dis) | `V_DIS_Leg` | Status_Dis = 'L' |
| `TA_SEN_LST_B` | INSERT (HL only) | `V_TA_Sen7` | TA_TIX = TO, SEN_TIX = Leg |
| `Res_Hst` | INSERT or reuse | `V_DIS_TO_Tourpoint` | TourPointId, Type |
| `Res_Hst_Zus` | INSERT | `V_DIS_TO_Tourpoint` | ShipmentAmount (aggregated) |
| `Res_Hst.Lfd_N` | UPDATE (MoveTourpoint) | `V_DIS_TO_Tourpoint` | SequenceNumber |
| `TA_Sen_Lst_B.POS_N` | UPDATE (MoveTourpoint) | (loading list position) | POS_N |

---

## Verification Candidates

### Primary Candidate: V_DIS_Leg

Check if the leg is assigned to the target Transport Order:

```sql
SELECT l.LegId, l.TransportOrderId, l.PickupTourPointId, l.DeliveryTourPointId
FROM V_DIS_Leg l
WHERE l.ShipmentId = :ShipmentId
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

### Strategy 1: ID-Based Leg Assignment Check (Recommended)

```sql
SELECT l.LegId, l.TransportOrderId, l.PickupTourPointId, l.DeliveryTourPointId
FROM V_DIS_Leg l
WHERE l.ShipmentId = :ShipmentId
  AND l.LegType = :LegType
  AND l.TransportOrderId = :TransportOrderId
```

**Semantics:**
- Row returned -> Leg already assigned to THIS TO -> IDEMPOTENT
- No row returned -> Check if assigned elsewhere (see Strategy 2)

### Strategy 2: Conflict Detection

```sql
SELECT l.LegId, l.TransportOrderId
FROM V_DIS_Leg l
WHERE l.ShipmentId = :ShipmentId
  AND l.LegType = :LegType
  AND l.TransportOrderId IS NOT NULL
```

Then in application logic:
```
IF row.TransportOrderId = :TransportOrderId:
    -> IDEMPOTENT: Already assigned to target TO
ELSE IF row.TransportOrderId != :TransportOrderId:
    -> CONFLICT: Leg already assigned to a different TO
ELSE IF row.TransportOrderId IS NULL:
    -> PROCEED: Leg is unassigned, safe to execute
```

**Note:** Unlike Flows #1/#2, there is no TO parameter comparison needed (Company, Branch, LoadingDate) because this flow assigns to an existing TO identified by `TransportOrderId`.

---

## Transaction Boundaries

### Path A: Single Mutation (Atomic)

```
┌──────────────────────────────────────────────────┐
│ TMS Bridge: Single call (atomic PL/pgSQL)         │
│ ┌──────────────────────────────────────────────┐ │
│ │ pDIS_TransportOrder.CreateAndAddLeg          │ │
│ │   -> AddLeg -> AddSen/pTA_VL.AddLeg         │ │
│ │   -> All writes in ONE transaction           │ │
│ └──────────────────────────────────────────────┘ │
│                COMMIT / ROLLBACK                  │
└──────────────────────────────────────────────────┘
```

**No partial TMS state is possible** for Path A. Single PL/pgSQL transaction.

### Path B: Two Mutations (GraphQL Batch)

```
┌──────────────────────────────────────────────────┐
│ GraphQL Batch: 2 operations                       │
│                                                   │
│ Operation 1: CreateAndAddLeg  [Transaction T1]    │
│     COMMIT T1                                     │
│     Returns: PickupPointId (@export)              │
│                                                   │
│ Operation 2: MoveTourpoint    [Transaction T2]    │
│     COMMIT T2 (or silent failure!)                │
└──────────────────────────────────────────────────┘
```

Each mutation is its own database transaction. The batch is **not atomic**.

### Failure Windows

| Failure Point | TMS State | Detection |
|---------------|-----------|-----------|
| Before any call | No leg assignment | V_DIS_Leg returns no row for target TO |
| After CreateAndAddLeg (Path A) | Leg assigned, no repositioning | V_DIS_Leg returns row |
| After CreateAndAddLeg, before MoveTourpoint (Path B) | Leg assigned, pickup NOT repositioned | V_DIS_Leg returns row, tour point in default position |
| After MoveTourpoint silently fails (Path B) | Leg assigned, pickup NOT repositioned | V_DIS_Leg returns row, tour point in default position |
| After everything succeeds (Path B) | Leg assigned and repositioned | V_DIS_Leg returns row, tour point in correct position |

### MoveTourpoint Exception Handling

The `MoveTourpoint` procedure catches all exceptions and returns normally (does NOT re-raise):

```sql
EXCEPTION
    when OTHERS then
        call reshst.resetmodus();  -- cleanup
        RAISE NOTICE '%', v_message;
        -- NOTE: Does NOT re-raise! Returns normally.
```

**Implication:** Path B may complete with the leg assigned but the pickup tour point not repositioned. This is a "soft failure" -- the leg is on the TO, but the stop order may be wrong.

---

## Idempotency Check Logic

### Path A

```
Input: TransportOrderId, ShipmentId, LegType

Query V_DIS_Leg for ShipmentId + LegType:

CASE 1: row.TransportOrderId = :TransportOrderId
    -> IDEMPOTENT: Leg already assigned to this TO
    -> Return existing PickupTourPointId, DeliveryTourPointId, LegId from view
    -> (Cannot rely on TMS OUT params -- HasSen early-return leaves them NULL)

CASE 2: row.TransportOrderId IS NOT NULL AND != :TransportOrderId
    -> CONFLICT: Leg already assigned to different TO
    -> Fail with error

CASE 3: row.TransportOrderId IS NULL
    -> PROCEED: Execute CreateAndAddLeg

CASE 4: No row returned
    -> ERROR: Leg does not exist for this ShipmentId/LegType
```

### Path B

```
Input: TransportOrderId, ShipmentId, LegType, DestinationTourPointId, RelationType

Query V_DIS_Leg for ShipmentId + LegType:

IF row.TransportOrderId = :TransportOrderId:
    -> Leg already assigned (mutation 1 complete)
    
    IF repositioning was requested:
        Check V_DIS_TO_Tourpoint for current pickup sequence
        IF pickup already in desired position:
            -> FULLY IDEMPOTENT: Skip both mutations
        ELSE:
            -> PARTIAL: Leg assigned but pickup not repositioned
            -> Can re-execute MoveTourpoint alone
            -> (Note: MoveTourpoint swallows errors silently)
    ELSE:
        -> IDEMPOTENT: Return existing data

ELSE IF row.TransportOrderId IS NULL:
    -> PROCEED: Execute full batch (both mutations)
```

### TMS-Level Idempotency for AddLeg

Both paths in `AddLeg` have built-in early-return checks:
- **HL path:** `pTA.HasSen(nTATix, nSenTix)` checks `TA_SEN_LST_B` -- returns silently if already assigned
- **VL path:** `pTA_VL.HasSen(nTATix, nLegTix)` via `pTA_NV.HasSen` checks `Sen_Zuord` -- returns silently if already assigned

This means **re-executing CreateAndAddLeg is safe at the TMS level**. However, the OUT parameters will be NULL on the HasSen early-return, so the application-level check via `V_DIS_Leg` is needed to **recover the IDs**.

---

## Open Questions

### Q1: OUT Parameter Loss on HasSen Early-Return
**Question:** When the TMS `HasSen` guard triggers, the OUT parameters (`PickupPointId`, `IsNewPickupPoint`, `DeliveryPointId`, `IsNewDeliveryPoint`) remain NULL because the function returns before populating them. Should the application-level verification query (`V_DIS_Leg`) always be used to recover these IDs on retry?

**Recommendation:** Yes. The verification query provides the necessary IDs regardless of whether the TMS call was skipped or executed.

### Q2: MoveTourpoint Silent Failure
**Question:** The `EXCEPTION WHEN OTHERS` block in `MoveTourpoint` catches ALL exceptions and does not re-raise. The caller receives no indication of failure. Should the TMS team fix this to propagate errors?

**Note:** This affects both retry detection and user feedback. The current Backend does not check `isTourpointMoved` per leg.

### Q3: VL Leg Creation Side Effect
**Question:** For VL legs, `AddLeg` may **create** a new leg via `pDIS_Shipment.CreateLeg` if no unassigned VL leg exists. A retry could find the previously-created (but unassigned, if the assign step failed) leg. The HasSen check would pass correctly, but `LegId` for VL is **not** the same as `ShipmentId`. Does this affect the verification query?

### Q4: Tour Point Position Verification for Path B
**Question:** Should verification for Path B also check that the pickup tour point is in the expected position (via `V_DIS_TO_Tourpoint.SequenceNumber`), or is leg assignment confirmation sufficient?

---

## Related Files

| File | Purpose |
|------|---------|
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` (line 1127) | DIS wrapper: `CreateAndAddLeg` |
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` (line 1049) | DIS wrapper: `AddLeg` |
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` (line 649) | DIS wrapper: `MoveTourpoint` |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (line 8668) | `pTA.HasSen` (HL idempotency check) |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (line 2169) | `pTA.AddSen` (HL leg assignment) |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (line 9389) | `PTA.MoveOrt` (tour point repositioning) |
| `Code/tms-alloydb-schema/src/sql/package/PTA_VL.sql` (line 102) | `pTA_VL.AddLeg` (VL leg assignment) |
| `Code/tms-alloydb-schema/src/sql/package/PTA_VL.sql` (line 61) | `pTA_VL.HasSen` -> `pTA_NV.HasSen` (VL idempotency) |
| `Code/tms-alloydb-schema/src/sql/package/SEN.sql` (line 13622) | `Sen.Link` (writes Sen_Zuord, handles unique violations) |
| `Code/tms-alloydb-schema/src/sql/package/RESHST.sql` | Tour point management: AddOrt, AddSen, Move |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_LEG.sql` | Primary verification view |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_TO_TOURPOINT.sql` | Tour point verification view |
| `Code/tms-alloydb-schema/src/sql/view/v_ta_sen7.sql` | Leg-to-TO assignment view |

---

## Comparison with All Flows

| Aspect | #1 FromLeg | #2 FromLot | #3 AssignLeg | #4 AssignLot | #5 UnassignLots | #6 UnassignLegs | #7 Delete |
|--------|-----------|-----------|-------------|-------------|----------------|----------------|----------|
| TO Created? | Yes | Yes | No | No | No | No | No |
| Leg Count | 1 | N | 1 | N | N | N | all |
| Max TMS Mutations | 1 | N | 2 | 2N | N | N | 1 |
| TMS Atomicity | Single | Non-atomic | Single/Batch | Non-atomic | Non-atomic | Non-atomic | **Single** |
| Partial Failure | None | High | **Low (Path B)** | Highest | High | High | None |
| TMS Idempotency | HasSen | HasSen | **HasSen** | HasSen | No | No | No |
| Verification | Row exists | Count | **Row exists** | Count + order | Row absent | Row absent | Row absent |
