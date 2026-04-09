# Transactional State Verification - UnassignLegs

**Date:** 2026-04-09  
**Status:** Draft

---

## Summary

This exploration documents the analysis of **transactional state verification** for the `UnassignLegsSubHandler` flow (Flow #6). This operation:

1. Removes individual legs from a Transport Order via parallel HTTP calls
2. Uses `pDIS_TransportOrder.RemoveLeg` per leg (same DIS-wrapper as Flow #5)
3. Calls are dispatched via `Parallel.ForEachAsync` with max 4 concurrency (NOT batch API)
4. Verification uses **inverted logic**: absence of assignment = operation completed

---

## Analysis

### The Call Flow

```
Frontend
    -> Backend (UnassignLegsAndLotsCommandHandler)
        -> UnassignLegsSubHandler.Unassign(transportOrderId, legIds, databaseIdentifier)
            -> RemoveTmsLegsSubHandler.Remove(legsData, databaseIdentifier)
                -> Parallel.ForEachAsync (max 4 concurrent)
                    -> CallRemoveLeg (per leg, individual HTTP request)
                        -> TMS Bridge (GraphQL Mutation: callRemoveLeg)
                            -> pDIS_TransportOrder.RemoveLeg(TransportOrderId, LegId, Mode)
                                -> pTA.RemSen(nTATix, nSenTix, nMode)
```

### Key Difference from Flow #5 (UnassignLots)

| Aspect | Flow #5 (UnassignLots) | Flow #6 (UnassignLegs) |
|--------|------------------------|------------------------|
| Backend Handler | `RemoveTmsLotsSubHandler` | `RemoveTmsLegsSubHandler` |
| HTTP Transport | GraphQL Batch API (single request, N aliased mutations) | `Parallel.ForEachAsync` (N separate HTTP requests, max 4 concurrent) |
| TMS Function | `pDIS_TransportOrder.RemoveLeg` | `pDIS_TransportOrder.RemoveLeg` (identical) |
| Atomicity at HTTP level | Single request (server-side sequential) | Multiple requests (client-side parallel) |
| Partial failure visibility | Aggregate `IsLotRemoved` (all-or-nothing) | Per-leg `IsLegRemoved` |

**Implication:** Flow #6 has more granular failure tracking (per-leg success/failure) but higher partial failure risk because each HTTP request is independent.

### State Changes Traced (per leg removal)

```
pDIS_TransportOrder.RemoveLeg(TransportOrderId, LegId, Mode)
    |
    +-> pTA.RemSen(nTATix, nSenTix, nMode)
            |
            +-> [Branch A: Z-Sendung path (loading list leg)]
            |       -> Deletes: SEN_ZUORD (type 'Z', link between Z-Sendung and SG-Sendung)
            |       -> Updates: SENDUNG (product code via RemSenActualizeZusaProd)
            |       -> Calls: pTA.RemSenFromLL (removes from loading list)
            |           -> Updates: SENDUNG (STATUS_DIS, clears LADELIST_TIX)
            |           -> Deletes: SEN_ZUORD (type 'Z')
            |       -> Writes: SEN_HST (event 13: "Sendung vom TA entfernt")
            |       -> return (early exit)
            |
            +-> [Branch B: Direct leg path (normal case for New Dispo)]
                    |
                    +-> Weight/space cleanup
                    |       -> Calls: pTA.SetSenGew (zeroes weight on tour points)
                    |       -> Calls: pTA.SetSenStpl_C (zeroes pallet spaces)
                    |
                    +-> Tour point cleanup
                    |       -> Calls: RESHST.RemSen(nTATix, nSenTix)
                    |           -> Deletes: RES_HST_ZUS (leg-to-tourpoint link)
                    |           -> IF no more legs on tourpoint:
                    |               -> Deletes: PERS (contact person)
                    |               -> Releases: Resource (via pRes.Exec)
                    |               -> Calls: RESHST.UnlinkPoints
                    |               -> Deletes: RES_HST (the tour point itself)
                    |
                    +-> Event logging
                    |       -> Writes: SEN_HST (event 13)
                    |
                    +-> Sendung status update (if leg not on other TOs)
                    |       -> Updates: SENDUNG.STATUS_DIS -> 'F' (free) or 'O'
                    |
                    +-> Sub-route leg cleanup (V_TA_ABH loop)
                    |       -> Deletes: LST_B (loading list items)
                    |       -> Deletes: LST_K (loading list headers, if empty)
                    |       -> Deletes: SEN_BER (area references)
                    |       -> Deletes: TA_SEN_LST_B (TO-leg loading list link)
                    |       -> Deletes: SEN_ZUORD (leg-to-TO assignment)    <- primary state
                    |       -> Writes: SEN_HST (event 13 per sub-route)
                    |
                    +-> Orphan tour point cleanup
                    |       -> IF no delivery points remain on TO:
                    |           -> Deletes: all RES_HST with ART = RES1
                    |
                    +-> pTA.SetStatus(nTATix)  -- recalculate TO status
                    +-> pTA.Clear()            -- clear session
```

### Function Signatures

**DIS-wrapper (TMS Database):**
```sql
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.RemoveLeg(
    TransportOrderId numeric,
    LegId            numeric,
    Mode             numeric
)
-- No OUT parameters. Raises exception on failure.
```

**TMS Bridge (GraphQL):**
```graphql
mutation callRemoveLeg($databaseIdentifier: String!, $input: RemoveLegInput!) {
    callRemoveLeg(databaseIdentifier: $databaseIdentifier, input: $input) {
        isLegRemoved
    }
}
```

The TMS Bridge wraps exceptions into `isLegRemoved = false` (catch-all in `RemoveLegMutation.cs`).

---

## Table-to-View Mapping

| Table Written/Deleted | Operation | Verification View | Key Columns |
|----------------------|-----------|-------------------|-------------|
| `SEN_ZUORD` | DELETE | `V_TA_Sen7`, `V_DIS_Leg` | TransportOrderId (via TA_Tix), LegId (via SEN_TIX) |
| `TA_SEN_LST_B` | DELETE | (loading list views) | TA_TIX, SEN_TIX |
| `LST_B` | DELETE | (internal) | Loading list items |
| `LST_K` | DELETE | (internal) | Loading list headers |
| `SEN_BER` | DELETE | (internal) | Area references |
| `RES_HST_ZUS` | DELETE | `V_DIS_TO_Tourpoint` | Leg-to-tourpoint links |
| `RES_HST` | DELETE (conditional) | `V_DIS_TO_Tourpoint` | Tour points (only if no other legs reference them) |
| `SENDUNG` | UPDATE | `V_DIS_Leg` | STATUS_DIS changes (to 'F' or 'O') |
| `SEN_HST` | INSERT | (event log, not used for verification) | Event 13 records |

---

## Verification Candidates

### Primary Candidate: V_DIS_Leg

The `V_DIS_Leg` view derives `TransportOrderId` from `V_TA_Sen7`:
```sql
(select TA_Tix from V_TA_Sen7 where Sen_Tix = s2.Sendung_Tix limit 1) TransportOrderId
```

After `RemoveLeg`, the `SEN_ZUORD` row linking the leg to the TO is deleted, so `V_TA_Sen7` returns no row for that leg, and `TransportOrderId` becomes `NULL` in `V_DIS_Leg`.

**Verification uses inverted logic:** The absence of a `TransportOrderId` value for a given LegId means the leg has been successfully removed.

### Secondary Candidate: V_DIS_TO_Tourpoint

Tour points may or may not be deleted depending on whether other legs still reference them. This is NOT suitable as a primary verification view because tour point presence/absence depends on shared state across legs.

---

## Verification Strategies

### Strategy 1: Absence Check (ID-based, Recommended)

```sql
-- For each leg that should have been removed:
SELECT l.LegId, l.TransportOrderId
FROM V_DIS_Leg l
WHERE l.LegId IN (:LegId1, :LegId2, ..., :LegIdN)
  AND l.TransportOrderId = :TransportOrderId
```

**Semantics:**
- No rows returned -> ALL legs successfully removed from this TO (DONE)
- Some rows returned -> PARTIAL removal (only returned legs are still assigned)
- All rows returned -> NONE removed (operation did not execute)

### Strategy 2: Count-Based Partial Detection

```sql
SELECT COUNT(*) as still_assigned_count
FROM V_DIS_Leg l
WHERE l.LegId IN (:LegId1, :LegId2, ..., :LegIdN)
  AND l.TransportOrderId = :TransportOrderId
```

**Semantics:**
- `still_assigned_count = 0` -> COMPLETE: All legs removed
- `still_assigned_count = N` (total expected) -> NOT STARTED: No legs removed
- `0 < still_assigned_count < N` -> PARTIAL: Some legs removed, some remain

### Strategy 3: Full State Snapshot (for recovery)

```sql
SELECT l.LegId, 
       l.TransportOrderId,
       CASE WHEN l.TransportOrderId = :TransportOrderId THEN 'STILL_ASSIGNED'
            WHEN l.TransportOrderId IS NULL THEN 'REMOVED'
            ELSE 'REASSIGNED_TO_OTHER_TO'
       END as leg_state
FROM V_DIS_Leg l
WHERE l.LegId IN (:LegId1, :LegId2, ..., :LegIdN)
```

**Semantics:** Provides per-leg status for recovery decision making. Detects the edge case where a leg was removed and then re-assigned to a different TO between retries.

---

## Idempotency Check Logic

```
Input: transportOrderId, [legId1, legId2, ..., legIdN]

Query V_DIS_Leg for all target LegIds:

IF no legs have TransportOrderId = :transportOrderId:
    -> IDEMPOTENT: All legs already removed. Return success for all.
    
ELSE IF all legs still have TransportOrderId = :transportOrderId:
    -> PROCEED: No legs removed yet. Execute full operation.
    
ELSE (some legs assigned, some not):
    -> PARTIAL FAILURE: 
       - Identify which legs are still assigned (TransportOrderId = :transportOrderId)
       - Retry RemoveLeg only for those still-assigned legs
       - Report already-removed legs as success
```

### Idempotency of RemoveLeg Itself

`pDIS_TransportOrder.RemoveLeg` is **NOT idempotent** at the TMS level. Calling it for a leg that is already removed will raise an exception (the `SEN_ZUORD` row no longer exists, the action state check in `pTA.Exec`/`SEN.Exec` fails, or `RESHST.GetSenBelad2` hits `NO_DATA_FOUND`).

The TMS Bridge catches this exception and returns `isLegRemoved = false`, which is **indistinguishable from a legitimate failure** (e.g., business rule violation preventing removal).

This makes pre-verification essential: before retrying, check which legs are still assigned and only retry those.

---

## Transaction Boundaries

```
+------------------------------------------------------------------------------+
| UnassignLegsSubHandler                                                       |
|                                                                              |
|  +---------------------------------------------+                            |
|  | RemoveTmsLegsSubHandler (TMS mutations)      |                            |
|  |                                              |                            |
|  |  Parallel.ForEachAsync (max 4 concurrent)    |                            |
|  |  +----------+ +----------+ +----------+      |                            |
|  |  | RemoveLeg| | RemoveLeg| | RemoveLeg|      |  <-- N independent HTTP    |
|  |  | (Leg 1)  | | (Leg 2)  | | (Leg N)  |      |      requests              |
|  |  +----------+ +----------+ +----------+      |                            |
|  +---------------------------------------------+                            |
+------------------------------------------------------------------------------+
```

Each `pDIS_TransportOrder.RemoveLeg` call at the TMS level is atomic (single PL/pgSQL transaction). The non-atomicity is at the **orchestration level**: N separate TMS transactions with no distributed transaction coordinator.

---

## Partial Failure Analysis

### Failure Windows (Flow #6 specific)

Because each leg removal is a separate HTTP request, there are N independent failure windows:

```
Parallel.ForEachAsync (max 4 concurrent)
    |
    +-> HTTP Request 1: RemoveLeg(TO, Leg1) -> SUCCESS
    +-> HTTP Request 2: RemoveLeg(TO, Leg2) -> SUCCESS
    +-> HTTP Request 3: RemoveLeg(TO, Leg3) -> NETWORK TIMEOUT (unknown state)
    +-> HTTP Request 4: RemoveLeg(TO, Leg4) -> NOT YET STARTED (cancelled)
    +-> HTTP Request 5: RemoveLeg(TO, Leg5) -> NOT YET STARTED
```

| Failure Scenario | Legs 1-2 | Leg 3 | Legs 4-5 | Verification Query Result |
|-----------------|----------|-------|----------|---------------------------|
| All succeed | Removed | Removed | Removed | 0 rows (COMPLETE) |
| Network failure mid-stream | Removed | Unknown | Still assigned | 2-3 rows (PARTIAL) |
| TMS Bridge crash | Removed | Removed | Still assigned | 2 rows (PARTIAL) |
| Backend crash before any call | Still assigned | Still assigned | Still assigned | 5 rows (NOT STARTED) |

### Comparison: Batch API (Flow #5) vs Parallel HTTP (Flow #6)

| Aspect | Flow #5 (Batch) | Flow #6 (Parallel HTTP) |
|--------|-----------------|------------------------|
| Request granularity | 1 HTTP request | N HTTP requests |
| Failure mode | All-or-nothing at HTTP level | Per-leg independent failure |
| Partial state detection | Harder (batch may partially execute server-side) | Easier (each response is independent) |
| Retry granularity | Must check all legs | Can check per-leg |
| Concurrency control | Server-controlled (sequential within batch) | Client-controlled (max 4 parallel) |
| Network failure impact | All N legs affected | Only concurrent batch affected |

---

## Open Questions

### Q1: Retry Semantics for Already-Removed Legs
**Question:** When retrying after partial failure, should we call `RemoveLeg` for legs that are already removed (and tolerate the exception), or should we pre-check via `V_DIS_Leg` and skip already-removed legs?

**Recommendation:** Pre-check via `V_DIS_Leg`. The TMS exception for "already removed" is indistinguishable from business rule failures, making blind retry unreliable.

### Q2: Race Condition on Re-Assignment
**Question:** Between a partial failure and a retry, could a removed leg be re-assigned to a different TO (by another user or process)? If so, the verification query (Strategy 3) would show `REASSIGNED_TO_OTHER_TO`, and the retry logic needs to decide whether to skip or fail.

### Q3: Error Reporting Granularity
**Question:** The TMS Bridge returns `isLegRemoved = false` for both "already removed" and "business rule violation." Should the verification pre-check be added to distinguish these cases before calling RemoveLeg?

---

## Related Files

| File | Purpose |
|------|---------|
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` (line 1111) | DIS wrapper: `RemoveLeg` |
| `Code/tms-alloydb-schema/src/sql/package/PTA.sql` (line 11391) | Core logic: `pTA.RemSen` |
| `Code/tms-alloydb-schema/src/sql/package/RESHST.sql` (line 3664) | Tour point cleanup: `RESHST.RemSen` |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_LEG.sql` | Primary verification view |
| `Code/tms-alloydb-schema/src/sql/view/v_ta_sen7.sql` | Underlying assignment view |
| `Code/tms-alloydb-schema/src/sql/view/V_DIS_TO_TOURPOINT.sql` | Tour point verification view |
| `Code/Disposition-Abstraction-Layer/.../RemoveLeg/RemoveLegMutation.cs` | TMS Bridge GraphQL mutation |
