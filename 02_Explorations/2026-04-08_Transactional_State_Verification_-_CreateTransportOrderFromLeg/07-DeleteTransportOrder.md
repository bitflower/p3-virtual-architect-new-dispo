# Transactional State Verification - DeleteTransportOrder

**Date:** 2026-04-09  
**Status:** Approved (Joachim, 2026-04-09)

---

## Summary

This exploration documents the analysis of **transactional state verification** for the `pDIS_TransportOrder.Delete` function. Unlike Flows #1-#4 (which create state), this is a **destructive** operation:

1. Removes the Transport Order and all its associated state from TMS
2. Single TMS mutation (atomic within PL/pgSQL)
3. Verification is an **absence check**: the TO should NOT exist after execution

---

## Analysis

### The Call Flow

```
Frontend
    -> Backend (DeleteTransportOrderCommandHandler)
        -> DeleteTransportOrderSubHandler
            -> TMS Bridge (GraphQL Mutation: callDeleteTransportOrder)
                -> pDIS_TransportOrder.Delete (PL/pgSQL)
                    -> pTA.Del (TMS kernel)
```

### State Changes Traced

```
pDIS_TransportOrder.Delete(TransportOrderId, Mode=NULL)
    |
    +-> pTA.Del(nTATix, nMode)
            |
            +-> pTA.Exec(ACTION_TADEL)
            |       -> pTA.lockRec()           -> UPDATE Sendung (version lock)
            |       -> pTA.canExecute()        -> Business rule guards (see below)
            |
            +-> for each shipment in V_TA_SEN7:
            |       pTA.RemSen(nTATix, SenTix)
            |           -> Deletes: Sen_Zuord             (leg-to-TO assignment)
            |           -> Deletes: TA_Sen_Lst_B          (loading list items)
            |           -> Deletes: Lst_B, Lst_K, Sen_Ber (cost/performance entries)
            |           -> Deletes: Res_Hst_Zus           (tour point shipment links)
            |           -> Deletes: Res_Hst               (tour points with no remaining shipments)
            |           -> Updates: Sendung (shipment)     (resets STATUS_DIS to 'F' = free)
            |           -> Writes:  Sen_Hst               (event 13 "Sendung vom TA entfernt")
            |
            +-> ResHst.DelRef(nTATix)
            |       -> for each remaining Res_Hst:
            |           -> Deletes: Pers (tour point person)
            |           -> Deletes: Res_Hst_Zus (cascaded)
            |           -> Deletes: Res_Hst
            |
            +-> DELETE FROM Pers WHERE TIX IN (SELECT Pers_Tix FROM Sen_TB WHERE Sen_Tix = nTATix)
            +-> DELETE FROM Pers WHERE TIX IN (SELECT Unt_Tix FROM Sen_Frk_Unt WHERE Sen_Tix = nTATix)
            |
            +-> DELETE FROM Sendung WHERE Sendung_Tix = nTATix
                    -> CASCADE deletes:
                        Sen_TB, Sen_Frk_Unt, Sen_Zuord (both sides),
                        TA_Sen_Lst_B, Lst_K, Sen_Ber, Sen_Hst,
                        Text_Sendung, Sen_Ref, Sen_Zus, Papier_Sendung,
                        Sendgort, Sen_Rrv, Sen_Land, Frk_Sen, Send_Ls,
                        Sen_Pst, Sen_Abh, Sen_Bahn, Frb_Protokoll,
                        Sen_Zustand, Sen_Sammelauft, Be_Entlad_Stelle,
                        Pers_Sen, Lager_Buch2aa, Sen_Zoll, Sendungspos_Land
```

**Important:** The shipments (legs) themselves are NOT deleted. `pTA.RemSen` unlinks them from the TO and resets their `STATUS_DIS` to `'F'` (free), making them available for reassignment.

### Function Signatures

**DIS Wrapper:**
```sql
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.Delete(
    TransportOrderId numeric,
    Mode             numeric   -- passed as NULL from TMS Bridge
)
```

**TMS Kernel:**
```sql
CREATE OR REPLACE PROCEDURE pTA.Del(
    IN nTATix numeric,
    IN nMode  numeric
)
```

**GraphQL:**
```graphql
mutation callDeleteTransportOrder($databaseIdentifier: String!, $input: DeleteTransportOrderInput!) {
    callDeleteTransportOrder(databaseIdentifier: $databaseIdentifier, input: $input) {
        isDeleted
        transportOrderId
    }
}
```

**Note:** The TMS Bridge always returns `IsDeleted = true` after the procedure completes without exception. The flag is not computed from actual TMS state -- it is hardcoded.

---

## Business Rule Guards (canExecute for ACTION_TADEL)

Before deletion, `pTA.canExecute` checks the TO status. Deletion is **blocked** if any of these conditions are true:

| Guard | Status | Error Code | Meaning |
|-------|--------|------------|---------|
| Already ended | `TASTATUS_END` (7) | `20335` | TO has been completed |
| Already dispatched | `TASTATUS_ABF` (5) | `20333` | TO has been dispatched (Abfertigung) |
| MDE started | `STATUS_MDESTARTED` | `20381` | Mobile device execution has started |
| Already disposed | `TASTATUS_DIS` (4) | `20331` | TO has been assigned for disposition |
| Has Bordero | `FRK_UNT.BO_TIX IS NOT NULL` | `20310` | TO is linked to a Bordero document |

A TO in planning status (NEU, UNVOLLST, AVIS) can be deleted. A TO that has progressed to DIS/ABF/END cannot.

---

## Table-to-View Mapping

| Table Written/Deleted | Verification View | Key Columns |
|------------------------|-------------------|-------------|
| `Sendung` (TO record) | `V_DIS_TransportOrder` | TransportOrderId |
| `Sen_Zuord` | `V_TA_Sen7`, `V_DIS_Leg` | TransportOrderId (via TA_Tix) |
| `Sen_Frk_Unt` | `V_DIS_TransportOrder` | ContractorId, TruckId |
| `Sen_TB` | `V_DIS_TransportOrder` | ContractorParticipantType |
| `Res_Hst` + `Res_Hst_Zus` | `V_DIS_TO_Tourpoint` | TransportOrderId, TourPointId |
| `TA_Sen_Lst_B` | (loading list views) | TA_Tix, Sen_Tix |
| `Pers` (contractor/driver) | (no direct DIS view) | Pers_Tix |
| `Lst_K`, `Lst_B`, `Sen_Ber` | (cost views) | Sendung_Tix |
| `Sen_Hst` | (event history) | Sen_Tix -- event 13 written before deletion |

---

## Verification Candidates

### Primary Candidate: V_DIS_TransportOrder

For a deletion, verification checks for **absence**:

```sql
SELECT TransportOrderId
FROM V_DIS_TransportOrder
WHERE TransportOrderId = :TransportOrderId
```

**Semantics:**
- No row returned -> TO has been successfully deleted (or never existed)
- Row returned -> TO still exists (deletion not yet executed, or failed)

### Secondary Candidate: V_DIS_Leg

Check that no legs reference this TO anymore:

```sql
SELECT LegId, ShipmentId, TransportOrderId
FROM V_DIS_Leg
WHERE TransportOrderId = :TransportOrderId
```

### Tertiary Candidate: V_DIS_TO_Tourpoint

```sql
SELECT TourPointId
FROM V_DIS_TO_Tourpoint
WHERE TransportOrderId = :TransportOrderId
```

---

## Verification Strategies

### Strategy 1: Absence Check (Recommended)

```sql
SELECT TransportOrderId
FROM V_DIS_TransportOrder
WHERE TransportOrderId = :TransportOrderId
```

**Semantics:**
- No row -> Deletion was successful (or TO never existed)
- Row exists -> TO still exists, deletion was not executed

**Pros:**
- Single query, single view
- Definitive: if the TO row in `Sendung` is gone, everything else is gone too (CASCADE + explicit cleanup)

### Strategy 2: Defensive Check (Absence + Leg Orphan Detection)

```sql
-- Step 1: TO should not exist
SELECT TransportOrderId
FROM V_DIS_TransportOrder
WHERE TransportOrderId = :TransportOrderId;

-- Step 2: No legs should reference this TO
SELECT COUNT(*) as orphaned_legs
FROM V_DIS_Leg
WHERE TransportOrderId = :TransportOrderId;
```

**Use case:** Paranoid verification. Since `Sen_Zuord` cascades from `Sendung`, this should always return 0 if Step 1 returns no row. Useful as a sanity check.

---

## Idempotency Analysis

### Is pDIS_TransportOrder.Delete Idempotent?

**No.** Calling `Delete` on an already-deleted Transport Order will **fail with an exception**.

The failure path:
1. `pTA.Del` calls `pTA.Exec(ACTION_TADEL)`
2. `pTA.Exec` calls `pTA.lockRec(nTATix)`
3. `lockRec` executes `UPDATE Sendung SET U_VERSION = ... WHERE Sendung_Tix = nTATix`
4. Since the row no longer exists, `ROW_COUNT = 0`
5. `lockRec` raises exception with `ERRCODE = CAL_EXCEPTIONS.ERR_REC_MOD_CODE()` (error `20016`)

**Behavior on second call:** Exception `20016` ("record modified / not found").

### Idempotency Check Logic

```
Query V_DIS_TransportOrder for TransportOrderId:

IF no row returned:
    -> ALREADY DELETED: Return success (skip TMS call)

ELSE IF row exists:
    -> PROCEED: Execute deletion
    -> Note: Business rule guards may still reject
             (e.g., TO status progressed to ABF/END since last check)
```

### Pre-Check Required

NewDispo **must** check state before calling `pDIS_TransportOrder.Delete` to handle retries gracefully. Without a pre-check, a retry after successful deletion will result in error `20016`.

---

## Transaction Boundaries

### Atomicity

Flow #7 is a **single TMS mutation** — fully atomic within PL/pgSQL:

```
┌───────────────────────────────────────────────────┐
│ TMS Bridge: Single call (atomic PL/pgSQL)          │
│ ┌───────────────────────────────────────────────┐ │
│ │ pDIS_TransportOrder.Delete(TransportOrderId)  │ │
│ │   -> pTA.Del()                                │ │
│ │      -> RemSen (loop) + ResHst.DelRef         │ │
│ │      -> DELETE FROM Sendung (CASCADE)          │ │
│ └───────────────────────────────────────────────┘ │
│                    COMMIT / ROLLBACK               │
└───────────────────────────────────────────────────┘
```

**No partial TMS state is possible.** The entire `pTA.Del` runs within a single PL/pgSQL procedure. If any step fails, the database transaction is rolled back and the TO remains intact.

### Failure Windows

| Failure Point | TMS State | Detection |
|---------------|-----------|-----------|
| Before TMS call | TO exists | V_DIS_TransportOrder returns row |
| TMS call fails (business rule) | TO exists (unchanged) | V_DIS_TransportOrder returns row |
| TMS call succeeds | TO deleted | V_DIS_TransportOrder returns no row |

---

## Open Questions

### Q1: Pre-Check vs. Exception Handling
**Question:** Should the retry logic pre-check via `V_DIS_TransportOrder` before calling Delete, or should it catch the `20016` error and treat it as success?

**Recommendation:** Pre-check is cleaner. The `20016` error from `lockRec` is a generic "record modified/not found" error that could also indicate a concurrent modification, not just a missing record.

### Q2: Status Guard Pre-Validation
**Question:** Should the pre-check also verify the TO's status to predict whether `canExecute(ACTION_TADEL)` will succeed? This would avoid making TMS calls that are guaranteed to fail for TOs in END/ABF/DIS status.

---

## Related Files

| File | Purpose |
|------|---------|
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` (lines 89-96) | DIS wrapper: `Delete` |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (lines 4745-4803) | TMS kernel: `pTA.Del` |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (lines 3627-3640) | Business rule guards for `ACTION_TADEL` |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (lines 11391-11525) | `pTA.RemSen` (remove shipment from TO) |
| `Code/tms-alloydb-schema/src/sql/package/RESHST.sql` (lines 1522-1554) | `ResHst.Del` (delete tour point) |
| `Code/tms-alloydb-schema/src/sql/package/RESHST.sql` (lines 1577-1586) | `ResHst.DelRef` (delete all tour points for ref) |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER.sql` | Primary verification view |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_LEG.sql` | Leg verification view |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_TO_TOURPOINT.sql` | Tour point verification view |
| `Code/Disposition-Abstraction-Layer/.../DeleteTransportOrder/DeleteTransportOderMutation.cs` | GraphQL entry point |

---

## Comparison with Flows #1, #2, and #5

| Aspect | Flow #1 (CreateFromLeg) | Flow #2 (CreateFromLot) | Flow #5 (UnassignLots) | Flow #7 (Delete) |
|--------|-------------------------|-------------------------|------------------------|-------------------|
| Direction | Creates state | Creates state | Removes legs | Removes TO entirely |
| TMS Mutations | 1 | N | N (batch) | 1 |
| TMS Atomicity | Single call | Multiple calls | Batch (non-atomic) | **Single call (atomic)** |
| Partial Failure Risk | Low | High | High | **None** |
| Verification Type | Presence check | Count-based check | Absence check | **Absence check** |
| Idempotent? | No (creates duplicate) | No (creates duplicate) | No (error on retry) | **No (error 20016)** |
| Verification View | V_DIS_Leg (row exists) | V_DIS_Leg (n rows) | V_DIS_Leg (rows absent) | **V_DIS_TransportOrder (row absent)** |
