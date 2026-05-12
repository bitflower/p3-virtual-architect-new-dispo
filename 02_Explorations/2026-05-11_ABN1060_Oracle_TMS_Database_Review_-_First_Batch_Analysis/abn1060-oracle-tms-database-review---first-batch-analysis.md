# ABN1060 Oracle TMS Database Review
**Date:** 2026-05-11
**Environment:** ABN (Oracle) - Schema TMS1060

<internal>

**Status:** Exploration

</internal>

---

<internal>

## Original User Input

Reviews for the ABN1060 Oracle database. Three sources:
1. **P3 developer testing (first batch)** - connected Backend + TMS Bridge against Oracle DB, identified runtime errors
2. **Automated TMS Bridge DB Verifier** (from `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier`) - systematic check of all 77 database objects the TMS Bridge depends on
3. **P3 developer testing (second batch)** - confirmed CAL_QUEUE_Q error affects RemoveLeg, SetParticipant, RemoveParticipant; likely all write procedures

</internal>

---

## Summary

| Area | Status | Details |
|------|--------|---------|
| Tables (11) | All pass | Exist with correct permissions |
| Views (20) | All pass | Exist with correct permissions |
| Functions (11) | **3 missing** | `CreateTransportOrderFromLeg`, `CreateTransportOrderFromShipment` (obsolete), `AddShipment` (obsolete) |
| Procedures (35) | **1 missing** | `RemoveShipment` |
| Column definitions | **1 issue + 1 investigation** | `Comment` casing in `V_DIS_TRANSPORTORDER`. `U_TIME` confirmed missing in ALL environments (Oracle, PGS, and repo) — not ABN1060-specific, requires TMS Bridge-side investigation. |
| Queue infrastructure | **Permission granted** | `TMSBR1060.CAL_QUEUE_Q` permission granted to TMSBR1060 user (2026-05-12). Retry pending to confirm fix. Previously caused runtime failures in all write procedures. |

| Metric | Value |
|--------|-------|
| Objects verified | 77 |
| Existence (Level 1.0) | 73/77 found, 1 skipped, 4 not found |
| Signature (Level 1.5) | 42/42 match |
| Permissions (Level 2.0) | 73/77 granted, 1 skipped, 4 denied (non-existent) |
| Active blockers | 2 missing objects + 1 column issue + 1 runtime error under investigation |
| Obsolete gaps | 2 missing objects (low priority) |

---

## Consolidated Findings

### Category 1: Missing Database Objects

These objects are listed in the [TMS Bridge Database Object Inventory](../2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md) (v1.1) as required by the TMS Bridge, but do not exist in the ABN1060 database. Detected by the automated TMS Bridge DB Verifier.

| # | Object | Type | Package | Inventory Status | Called By | Impact |
|---|--------|------|---------|-----------------|-----------|--------|
| 1 | `CREATETRANSPORTORDERFROMLEG` | Function | PDIS_TRANSPORTORDER | **Active** | `CreateTransportOrderFromLegMutation` | Cannot create TO from leg |
| 2 | `CREATETRANSPORTORDERFROMSHIPMENT` | Function | PDIS_TRANSPORTORDER | **Obsolete** | `CreateTransportOrderFromLotMutation` (obsolete) | Low - obsolete mutation |
| 3 | `ADDSHIPMENT` | Function | PDIS_TRANSPORTORDER | **Obsolete** | `CreateTransportOrderFromLotMutation` (obsolete) | Low - obsolete mutation |
| 4 | `REMOVESHIPMENT` | Procedure | PDIS_TRANSPORTORDER | **Active** | `RemoveShipmentFromTransportOrderMutation` | Cannot remove shipment from TO |

All 4 missing objects belong to the `PDIS_TRANSPORTORDER` package. P3 developer testing confirmed #1 (`CreateTransportOrderFromLeg`). Objects #2-#4 were only caught by the automated verifier.

Objects #2 and #3 are marked obsolete in the inventory — they back the deprecated `CreateTransportOrderFromLotMutation`. Their absence will not affect current workflows but will cause verifier failures. Objects #1 and #4 are active and block real dispatcher operations.

**Action required:** Routines #1 and #4 need to be created in the PDIS_TRANSPORTORDER package on ABN1060 (high priority). For #2 and #3, clarify with the TMS team whether to deploy them for completeness or remove them from the TMS Bridge inventory.

### Category 2: Queue Infrastructure (Permission Granted — Retry Pending)

P3 developer testing revealed that write procedures fail at runtime due to a missing Oracle Advanced Queuing (AQ) queue. Initial testing identified `CreateAndAddLeg` and `Delete`; follow-up testing confirmed the issue is systemic.

**Root cause:** `TMSBR1060.CAL_QUEUE_Q` was not accessible.

**Update 2026-05-12 (Matt Wilkinson):** The permission grant for `CAL_QUEUE_Q` has been provided to the `TMSBR1060` user. The TMS team has raised the question of **why this permission is needed** — this should be clarified. A retry is needed to confirm the fix resolves all write procedure failures.

**Confirmed affected procedures (before fix):**
- `CreateAndAddLeg` (initial batch)
- `Delete` (initial batch)
- `RemoveLeg` (second batch — confirmed by P3)
- `SetParticipant` (second batch — confirmed by P3)
- `RemoveParticipant` (second batch — confirmed by P3)

P3 assessment: likely **all write procedures** were affected, since the queue is referenced from triggers that fire on data modification.

**Error chain for CreateAndAddLeg:**
```
ORA-24010: QUEUE TMSBR1060.CAL_QUEUE_Q does not exist
  -> SYS.DBMS_AQ
  -> TMS1060.CAL_QUEUE
  -> TMS1060.PTA_DASHBOARD_MP4
  -> trigger TMS1060.TRAIUD_SENDUNG_TABRD_MP4
  -> TMS1060.PTA
  -> TMS1060.PDIS_TRANSPORTORDER
```

**Error chain for Delete (ORA-21000 — under investigation):**
```
ORA-21000: error number argument to raise_application_error of -24010 is out of range
  -> TMS1060.PTA (line 5060)
  -> TMS1060.PDIS_TRANSPORTORDER (line 72)
```

The Delete error is the same root cause: the PTA package catches the ORA-24010 queue error and attempts to re-raise it via `raise_application_error`, but -24010 is outside the valid range (-20000 to -20999), causing a secondary ORA-21000 error. **Matt Wilkinson confirmed (2026-05-12) this is actively being worked on with the team.**

**Action required:** Retry write operations to confirm the CAL_QUEUE_Q permission grant resolves the issue. Clarify to the TMS team why the TMS Bridge user needs access to CAL_QUEUE_Q (it is referenced by triggers on tables modified by PDIS_TRANSPORTORDER procedures — the TMS Bridge user needs enqueue permission because the stored procedures execute under the caller's context).

### Category 3: Column-Level Issues

These are data-level problems not caught by the automated verifier (which checks object existence, not column definitions).

| # | View | Issue | Status | Impact |
|---|------|-------|--------|--------|
| 1 | `V_DIS_TRANSPORTORDER` | Column `Comment` uses mixed case instead of UPPERCASE | **Open** | TMS Bridge expects all-uppercase column names; queries fail |
| 2 | `V_DIS_TO_PICKUPPLANNING` | Column `U_TIME` is missing | **Reclassified** | See below |

**Issue #1 — Comment casing:** Fix the `Comment` column name to `COMMENT` (or quoted uppercase) in `V_DIS_TRANSPORTORDER`. This remains an ABN1060-specific action.

**Issue #2 — U_TIME (Reclassified: Not ABN1060-Specific):**
Andrej (TMS team) confirmed (2026-05-12) that the field `U_TIME` does **not exist** in either of the views `V_DIS_TRANSPORTORDER` or `V_DIS_TO_PICKUPPLANNING` — neither in PostgreSQL, nor in Oracle, nor in the repository source code. This is **not** an ABN1060-specific gap but a systemic discrepancy: the TMS Bridge expects a column that has never been defined in any environment.

**Recommended next step:** Trace in git history which PR or commit added `U_TIME` to the view definition. Since Andrej confirms it is not present in the current repo, it was either removed at some point or never committed. Identifying the originating change will clarify whether this is a regression (column was removed inadvertently) or a planned addition that was never completed.

### Category 4: Resolved During Testing

| # | Issue | Resolution |
|---|-------|------------|
| 1 | P3 developer reported views `V_DIS_TO_FILTER` and `V_DIS_TO_PICKUPPLANNING` as missing (ORA-00942) | Verifier confirms both views exist with SELECT granted. Likely a user context/schema prefix issue during initial connection. |
| 2 | Procedures/Functions folders appeared empty in DB browser | Found under Packages folder for TMS1060 user context |

---

## Verifier Results Summary

```
Level 1.0 (Existence):  73/77 found, 1 skipped, 4 NOT FOUND
Level 1.5 (Signature):  42/42 match
Level 2.0 (Permission): 73/77 granted, 1 skipped, 4 DENIED (non-existent objects)
```

| Category | Total | Pass | Fail |
|----------|-------|------|------|
| Tables | 11 | 11 | 0 |
| Views | 20 | 20 | 0 |
| Functions | 11 | 8 | 3 |
| Procedures | 35 | 34 | 1 |
| Types | 1 | 0 (skipped, PG-only) | 0 |

---

## Cross-Reference: Manual vs Automated Findings

| Finding | P3 Developer (Manual) | Verifier (Automated) | Notes |
|---------|-----------------|----------------------|-------|
| Missing CREATETRANSPORTORDERFROMLEG | Found | Found | Confirmed by both. Active — blocks dispatcher operations |
| Missing CREATETRANSPORTORDERFROMSHIPMENT | Not tested | Found | Only caught by verifier. **Obsolete** per inventory |
| Missing ADDSHIPMENT | Not tested | Found | Only caught by verifier. **Obsolete** per inventory |
| Missing REMOVESHIPMENT | Not tested | Found | Only caught by verifier. Active — blocks dispatcher operations |
| Queue infrastructure missing | Found (runtime, 5 procedures confirmed) | Not checked | Verifier checks existence/perms, not runtime deps. Likely affects all write procedures |
| Column naming (Comment) | Found | Not checked | Verifier doesn't check column definitions |
| Missing column (U_TIME) | Found | Not checked | Verifier doesn't check column definitions |
| Delete runtime error | Found | Not detected | Procedure exists and has correct signature |

This cross-reference demonstrates the complementary value of both approaches: the automated verifier catches missing objects systematically across all 77 dependencies, while manual testing catches runtime errors, column-level issues, and infrastructure gaps.

---

## Action Items

| # | Action | Owner | Priority | Status | Category |
|---|--------|-------|----------|--------|----------|
| 1a | Create `CREATETRANSPORTORDERFROMLEG` and `REMOVESHIPMENT` in PDIS_TRANSPORTORDER | TMS Team | High | Open | Missing Objects (active) |
| 1b | Decide on `CREATETRANSPORTORDERFROMSHIPMENT` and `ADDSHIPMENT`: deploy for completeness or remove from inventory | TMS Team / P3 | Low | Open | Missing Objects (obsolete) |
| 2a | ~~Create Oracle AQ queue `CAL_QUEUE_Q` in TMSBR1060 schema~~ | TMS Team / DBA | High | **Done** (2026-05-12) | Infrastructure |
| 2b | Retry write operations to confirm CAL_QUEUE_Q fix | P3 | High | **Pending retry** | Verification |
| 2c | Clarify to TMS team why TMSBR1060 needs CAL_QUEUE_Q access (trigger execution context) | P3 / CAL | Medium | Open | Documentation |
| 3 | Fix `Comment` column casing in V_DIS_TRANSPORTORDER | TMS Team / DBA | High | Open | Column Fix |
| 4 | ~~Add `U_TIME` column to V_DIS_TO_PICKUPPLANNING~~ — **Reclassified:** Trace in git history which PR/commit added `U_TIME` to the view; column doesn't exist in any environment or repo | P3 | High | **Reclassified** | Git History Investigation |
| 5 | Resolve ORA-21000 error in Delete (PTA line 5060 error re-raise) | TMS Team / Matt W. | High | **In progress** (2026-05-12) | Runtime Error |
| 6 | Re-run verifier after fixes to confirm resolution | P3 | Medium | Blocked on #1a, #3 | Verification |

---

<internal>

## Related Files

- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/Ivailo-analysis.md` - P3 developer testing notes (first batch)
- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/ivailo-2.md` - P3 developer testing notes (second batch — CAL_QUEUE_Q blast radius)
- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/TMS-Verfitier-results.md` - Automated verifier output
- `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/` - Verifier tool source
- `02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md` - Object registry source (v1.1)
- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/2026-05-12_feedback Matt.md` - Matt Wilkinson feedback on CAL_QUEUE_Q grant, U_TIME non-existence, ORA-21000 status

</internal>

---

<internal>

## Tools Used

| Tool | Purpose |
|------|---------|
| TMS Bridge DB Verifier (`Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier`) | Automated verification of 77 DB objects across 3 levels (existence, signature, permissions) |

</internal>

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-11 | Matthias Max | Initial review: 4 missing objects, 1 missing queue, 2 column issues. Sources: P3 developer testing + automated TMS Bridge DB Verifier. |
| 1.1 | 2026-05-11 | Matthias Max | Expanded CAL_QUEUE_Q blast radius: confirmed RemoveLeg, SetParticipant, RemoveParticipant also affected. Likely all write procedures blocked. Source: P3 second batch testing. |
| 1.2 | 2026-05-12 | Matthias Max | Updated with Matt Wilkinson feedback: (1) CAL_QUEUE_Q permission granted to TMSBR1060 — retry pending; (2) U_TIME reclassified — column doesn't exist in any environment (Oracle, PGS, repo), now a TMS Bridge-side investigation; (3) ORA-21000 Delete error actively being worked on by TMS team. |

---

<div align="center">Created and maintained by <strong>Virtual Architect</strong></div>
