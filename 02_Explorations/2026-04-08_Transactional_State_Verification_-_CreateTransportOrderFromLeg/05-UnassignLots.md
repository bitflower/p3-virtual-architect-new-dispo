# Transactional State Verification - UnassignLots

**Date:** 2026-04-09
**Status:** Draft

---

## Summary

This exploration documents the analysis of **transactional state verification** for the `UnassignLotsSubHandler` flow (Flow #5). Unlike Flows 1-4 which CREATE state, this operation REMOVES state:

1. Removes N legs from a Transport Order via `CallRemoveLeg` (GraphQL Batch API)
2. Each leg removal deletes assignment records, loading list entries, and conditionally removes tour points
3. Verification logic is **inverted**: absence of state = operation completed

---

## Analysis

### The Call Flow

```
Frontend
    -> Backend (UnassignLegsAndLotsCommandHandler)
        -> UnassignLotsSubHandler (per lot)
            -> RemoveTmsLotsSubHandler
                -> GraphQL Batch: CallRemoveLeg x N (one per leg in the lot)
                    -> pDIS_TransportOrder.RemoveLeg(TransportOrderId, LegId, Mode)
                        -> pTA.RemSen(nTATix, nSenTix, nMode)
```

### Function Signatures

**DIS Wrapper:**
```sql
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.RemoveLeg(
    TransportOrderId numeric,
    LegId            numeric,
    Mode             numeric
)
-- Delegates directly to: pTA.RemSen(TransportOrderId, LegId, Mode)
```

**GraphQL Entry Point:**
```csharp
public async Task<RemoveLegResponse> CallRemoveLeg(
    [Service] IRoutineExecutor executor,
    [Service] IDbContextProvider<BranchDbContext> dbContextProvider,
    [GraphQLNonNullType] string databaseIdentifier,
    [GraphQLNonNullType] RemoveLegInput input)
// Input:  { TransportOrderId: long, LegId: long, Mode: long? }
// Output: { IsLegRemoved: bool }
```

**Backend Batch Construction (RemoveTmsLotsSubHandler):**
```graphql
mutation CallRemoveLeg {
    removeLeg_<LegId1>: callRemoveLeg(
        databaseIdentifier: "<db>"
        input: { transportOrderId: <TO>, legId: <LegId1>, mode: null }
    ) { isLegRemoved }

    removeLeg_<LegId2>: callRemoveLeg(
        databaseIdentifier: "<db>"
        input: { transportOrderId: <TO>, legId: <LegId2>, mode: null }
    ) { isLegRemoved }
    ...
}
```

The lot is considered removed only if ALL legs report `isLegRemoved = true`.

### State Changes Traced

```
pDIS_TransportOrder.RemoveLeg(TransportOrderId, LegId, Mode)
    |
    +-> pTA.RemSen(nTATix, nSenTix, nMode)
            |
            +-> [1] PTA.EXEC / SEN.EXEC  (action validation)
            |       -> Validates: can this leg be removed in current state?
            |
            +-> [2] Z-Sendung path (consolidated shipment handling)
            |       -> Deletes: SEN_ZUORD              -> resolved via: V_TA_Sen7
            |       -> Updates: SENDUNG (product group) -> (internal recalc)
            |       -> Calls: PTA.REMSENFROMLL
            |           -> Updates: SENDUNG (STATUS_DIS, LADELIST_TIX=null)
            |           -> Deletes: SEN_ZUORD (type 'Z')
            |
            +-> [3] Weight/Space zeroing
            |       -> Calls: PTA.SETSENGEW (weight -> 0)
            |       -> Calls: PTA.SETSENSTPL_C (pallet spaces -> 0)
            |           -> Updates: TA_SEN_LST_B, SEN_BER, RES_HST_ZUS
            |
            +-> [4] Tour point cleanup
            |       -> Calls: RESHST.REMSEN(nTATix, nSenTix)
            |           -> Deletes: RES_HST_ZUS          -> resolved via: V_DIS_TO_Tourpoint
            |           -> IF no shipments remain on tour point:
            |               -> Deletes: PERS (if orphaned)
            |               -> Calls: RESHST.UNLINKPOINTS
            |               -> Deletes: RES_HST           -> resolved via: V_DIS_TO_Tourpoint
            |
            +-> [5] Audit event
            |       -> Writes: SEN_HST (event 13 "Sendung vom TA entfernt") -> audit only
            |
            +-> [6] Sendung status (if leg not on any other TO)
            |       -> Updates: SENDUNG.STATUS_DIS -> 'F' (free) or 'O' (open)
            |
            +-> [7] Loading list cleanup (for sub-route TOs via V_TA_ABH)
            |       -> Deletes: LST_B                    -> (loading list detail)
            |       -> Deletes: LST_K (if empty)         -> (loading list header)
            |       -> Deletes: SEN_BER                  -> (area assignment)
            |       -> Deletes: TA_SEN_LST_B             -> (TO-shipment-loading-list link)
            |       -> Deletes: SEN_ZUORD                -> resolved via: V_TA_Sen7, V_DIS_Leg
            |
            +-> [8] Orphan tour point cleanup
            |       -> IF no delivery points remain on TO:
            |           -> Deletes: RES_HST (all ART=RES1) -> resolved via: V_DIS_TO_Tourpoint
            |
            +-> [9] TO status recalculation
                    -> Calls: PTA.SETSTATUS(nTATix)
                        -> Updates: SENDUNG (TO status)  -> resolved via: V_DIS_TransportOrder
```

---

## Table-to-View Mapping

| Table Modified (DELETE/UPDATE) | Operation | Verification View | Key Columns |
|-------------------------------|-----------|-------------------|-------------|
| `Sen_Zuord` | DELETE | `V_TA_Sen7`, `V_DIS_Leg` | REF_TIX (=TransportOrderId), SEN_TIX (=LegId) |
| `TA_Sen_Lst_B` | DELETE | (loading list views) | TA_TIX, SEN_TIX, LFD_N |
| `Res_Hst_Zus` | DELETE | `V_DIS_TO_Tourpoint` | RES_HST_TIX (shipment link removed) |
| `Res_Hst` | DELETE (conditional) | `V_DIS_TO_Tourpoint` | Tour point removed if no shipments remain |
| `LST_B` | DELETE | (loading list views) | Loading list detail |
| `LST_K` | DELETE (conditional) | (loading list views) | Loading list header if empty |
| `SEN_BER` | DELETE | (loading list views) | Area assignment |
| `Sendung` | UPDATE | `V_DIS_Leg`, `V_DIS_TransportOrder` | STATUS_DIS on the leg; TO status recalc |
| `Sen_Hst` | INSERT | (audit only) | Event log -- not for verification |

---

## Verification Candidates

### Primary Candidate: V_DIS_Leg

The `V_DIS_Leg` view derives `TransportOrderId` from `V_TA_Sen7`, which is based on `Sen_Zuord`. Since `pTA.RemSen` deletes the `Sen_Zuord` record, a successful removal causes `TransportOrderId` to become `NULL`.

```sql
-- V_DIS_Leg derivation of TransportOrderId:
(select TA_Tix from V_TA_Sen7 where Sen_Tix = s2.Sendung_Tix limit 1) TransportOrderId
```

After removal, this subquery returns no rows for the removed leg, yielding `TransportOrderId = NULL`.

### Secondary Candidate: V_DIS_TO_Tourpoint

Tour points may or may not be removed depending on whether other shipments share the same stop. This is a side effect, not the primary verification signal.

---

## Verification Strategies

### Strategy 1: Absence Check (ID-based, Recommended)

For a REMOVAL operation, success means the state is ABSENT.

```sql
-- Check: Are any of these legs still assigned to this Transport Order?
SELECT l.LegId, l.TransportOrderId
FROM V_DIS_Leg l
WHERE l.LegId IN (:LegId1, :LegId2, ..., :LegIdN)
  AND l.TransportOrderId = :TransportOrderId
```

**Semantics:**
- **No rows returned** -> All legs removed from this TO -> OPERATION COMPLETE
- **Some rows returned** -> Partial removal -> PARTIAL FAILURE
- **All rows returned** -> No legs removed -> OPERATION NOT STARTED

### Strategy 2: Per-Leg Granular Check

```sql
SELECT l.LegId,
       l.TransportOrderId,
       CASE WHEN l.TransportOrderId = :TransportOrderId THEN 'STILL_ASSIGNED'
            WHEN l.TransportOrderId IS NULL              THEN 'REMOVED'
            ELSE                                              'REASSIGNED_TO_OTHER_TO'
       END as removal_status
FROM V_DIS_Leg l
WHERE l.LegId IN (:LegId1, :LegId2, ..., :LegIdN)
```

**Semantics:**
- `REMOVED` -> Leg has no TO assignment -> Already removed (or never assigned)
- `STILL_ASSIGNED` -> Leg still on the target TO -> Not yet removed
- `REASSIGNED_TO_OTHER_TO` -> Leg now on a different TO -> Unexpected state

---

## Transaction Boundaries

### Risk Analysis

```
┌──────────────────────────────────────────────────────────────────┐
│ GraphQL Batch (single HTTP request, N mutations)                 │
│ ┌────────────┐ ┌────────────┐     ┌────────────┐               │
│ │ RemoveLeg  │ │ RemoveLeg  │ ... │ RemoveLeg  │               │
│ │ (Leg 1)    │ │ (Leg 2)    │     │ (Leg N)    │               │
│ └────────────┘ └────────────┘     └────────────┘               │
│      ↓               ↓                   ↓                      │
│   SUCCESS?        SUCCESS?            SUCCESS?                  │
└──────────────────────────────────────────────────────────────────┘
                         |
                         v
              IsLotRemoved = ALL(isLegRemoved)
```

Each `RemoveLeg` within the batch is an independent TMS procedure call. The batch is **not atomic** -- individual legs can succeed or fail independently.

### Failure Windows

| Failure Point | TMS State | Verification Query Result |
|---------------|-----------|---------------------------|
| Before batch call | All N legs assigned to TO | N rows with TransportOrderId = :TO |
| After K of N legs removed | K legs removed, N-K still assigned | N-K rows with TransportOrderId = :TO |
| After all N legs removed | No legs assigned to TO | 0 rows |

### Partial Failure Detection

```sql
-- Count how many legs from the lot are still assigned to this TO
SELECT COUNT(*) as remaining_leg_count
FROM V_DIS_Leg l
WHERE l.LegId IN (:LegId1, :LegId2, ..., :LegIdN)
  AND l.TransportOrderId = :TransportOrderId
```

| remaining_leg_count | Interpretation |
|---------------------|----------------|
| 0 | All legs removed (complete) |
| < N | Partial removal (some succeeded) |
| N | No legs removed (not started or all failed) |

---

## Idempotency Check Logic

```
Query V_DIS_Leg for all LegIds from the Lot against TransportOrderId:

IF no legs are assigned to TransportOrderId:
    -> IDEMPOTENT: All legs already removed. Return success.

ELSE IF some legs still assigned (count < original):
    -> PARTIAL FAILURE: Some legs removed, others not.
       Retry only the remaining legs (re-build batch with reduced set).

ELSE IF all legs still assigned (count = original):
    -> NOT STARTED: Safe to execute full batch.
```

### Key Difference from Flows 1-4

| Aspect | Flows 1-4 (Create) | Flow 5 (Remove) |
|--------|---------------------|------------------|
| Success indicator | Row EXISTS in V_DIS_Leg | Row ABSENT from V_DIS_Leg |
| Verification query | `TransportOrderId IS NOT NULL` | `TransportOrderId = :TO` returns no rows |
| Partial state | Legs assigned < expected count | Legs remaining > 0 |
| Idempotency | Return existing TO | Return success (already removed) |

---

## RemoveLeg Idempotency Behavior

`pTA.RemSen` is **NOT idempotent**. If called for a leg that is not assigned to the TO, it will:
- Fail to find tour point entries via `RESHST.GETSENBELAD2` / `RESHST.GETSENENTL2`
- Raise `NO_DATA_FOUND` exceptions at various points

The TMS Bridge wraps the call in a try/catch and returns `IsLegRemoved = false` on exception. Therefore, calling RemoveLeg for an already-removed leg will not corrupt state, but it will report failure. **Pre-checking is recommended** to avoid unnecessary error responses and to distinguish "already done" from "genuine failure."

---

## Open Questions

### Q1: Batch Atomicity
**Question:** The GraphQL batch sends all RemoveLeg calls in a single HTTP request. Does the TMS Bridge execute them independently (each with its own DB transaction) or as a single batch transaction?

**Current assumption:** Independent execution per mutation alias. Each `removeLeg_<id>` is a separate procedure call with independent commit/rollback.

### Q2: Empty TO After Removal
**Question:** After removing all legs from a TO, the Transport Order record itself persists (PTA.SETSTATUS recalculates status but does not delete). Does this require a separate `DeleteTransportOrder` call (Flow #7)?

### Q3: Tour Point Sharing
**Question:** If two legs share a tour point (same pickup/delivery location) and only one leg is removed, the tour point persists because `RESHST.REMSEN` only deletes the `RES_HST` record when no shipments remain (`nSenC = 0`). Does this affect verification?

**Current position:** No. `V_DIS_Leg.TransportOrderId` is the sufficient verification signal. Tour point persistence is internal TMS optimization, irrelevant for leg removal verification.

---

## Related Files

| File | Purpose |
|------|---------|
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` (line 1111) | DIS wrapper: `RemoveLeg` |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (line 11391) | Core logic: `pTA.RemSen(nTATix, nSenTix, nMode)` |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (line 11620) | `pTA.RemSenFromLL` (loading list removal) |
| `Code/tms-alloydb-schema/src/sql/package/RESHST.sql` (line 3664) | Tour point cleanup: `RESHST.RemSen` |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_LEG.sql` | Primary verification view |
| `Code/tms-alloydb-schema/src/sql/view/v_ta_sen7.sql` | Underlying assignment view (Sen_Zuord-based) |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_TO_TOURPOINT.sql` | Tour point verification view |
| `Code/Disposition-Abstraction-Layer/.../RemoveLeg/RemoveLegMutation.cs` | TMS Bridge GraphQL mutation |

---

## Comparison with Previous Flows

| Aspect | Flow #1 (CreateTOFromLeg) | Flow #2 (CreateTOFromLot) | Flow #5 (UnassignLots) |
|--------|---------------------------|---------------------------|------------------------|
| Direction | Creates state | Creates state | Removes state |
| TMS Mutations | 1 | N | N (batch) |
| Atomicity | Single call | Multiple calls | Batch (non-atomic) |
| Verification | Row EXISTS | All rows EXIST | Row ABSENT |
| Partial Failure | N/A | K of N legs added | K of N legs removed |
| Idempotency | NOT idempotent (creates new TO) | NOT idempotent | NOT idempotent (errors on missing) |
| Pre-check needed | Yes (prevent duplicate TO) | Yes (prevent duplicate TO) | Yes (prevent error on already-removed) |
