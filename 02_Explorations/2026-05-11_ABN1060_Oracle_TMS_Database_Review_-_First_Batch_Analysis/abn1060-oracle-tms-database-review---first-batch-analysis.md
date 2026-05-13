# ABN1060 Oracle TMS Database Review
**Date:** 2026-05-13
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
| Functions (11) | **2 missing + 1 type mismatch** | `CreateTransportOrderFromLeg` deployed as **Procedure** (TMS Bridge expects Function; parameter `Mode` → `nMode`). `CreateTransportOrderFromShipment` (obsolete), `AddShipment` (obsolete) still missing. |
| Procedures (35) | **1 missing** | `RemoveShipment` |
| Column definitions | **1 open** | `Comment` casing in `V_DIS_TRANSPORTORDER`. ~~`U_TIME` deployment gap~~ resolved (2026-05-13). |
| Queue infrastructure | **Partial fix** | `TMSBR1060.CAL_QUEUE_Q` permission granted (2026-05-12). Retry shows `SetParticipant` now works, but `CreateAndAddLeg` still fails with ORA-24010. Investigating whether different CAL_QUEUE overloads are involved. |

| Metric | Value |
|--------|-------|
| Objects verified | 77 |
| Existence (Level 1.0) | 73/77 found, 1 skipped, 4 not found |
| Signature (Level 1.5) | 42/42 match |
| Permissions (Level 2.0) | 73/77 granted, 1 skipped, 4 denied (non-existent) |
| Active blockers | 1 missing object + 1 type mismatch requiring TMS Bridge adaptation + 1 column issue + 1 partial queue fix + 1 runtime error under investigation |
| Obsolete gaps | 2 missing objects (low priority) |

---

## Consolidated Findings

### Category 1: Missing Database Objects

These objects are listed in the [TMS Bridge Database Object Inventory](../2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md) (v1.1) as required by the TMS Bridge, but do not exist in the ABN1060 database. Detected by the automated TMS Bridge DB Verifier.

| # | Object | Type | Package | Inventory Status | Called By | Impact |
|---|--------|------|---------|-----------------|-----------|--------|
| 1 | `CREATETRANSPORTORDERFROMLEG` | ~~Function~~ **Procedure** | PDIS_TRANSPORTORDER | **Active** | `CreateTransportOrderFromLegMutation` | ~~Missing~~ **Deployed — type mismatch** (see below) |
| 2 | `CREATETRANSPORTORDERFROMSHIPMENT` | Function | PDIS_TRANSPORTORDER | **Obsolete** | `CreateTransportOrderFromLotMutation` (obsolete) | Low - obsolete mutation |
| 3 | `ADDSHIPMENT` | Function | PDIS_TRANSPORTORDER | **Obsolete** | `CreateTransportOrderFromLotMutation` (obsolete) | Low - obsolete mutation |
| 4 | `REMOVESHIPMENT` | Procedure | PDIS_TRANSPORTORDER | **Active** | `RemoveShipmentFromTransportOrderMutation` | Cannot remove shipment from TO |

All 4 missing objects belong to the `PDIS_TRANSPORTORDER` package. P3 developer testing confirmed #1 (`CreateTransportOrderFromLeg`). Objects #2-#4 were only caught by the automated verifier.

Objects #2 and #3 are marked obsolete in the inventory — they back the deprecated `CreateTransportOrderFromLotMutation`. Their absence will not affect current workflows but will cause verifier failures. Objects #1 and #4 are active and block real dispatcher operations.

**Update 2026-05-13 (TMS Team — deployment confirmation):**
Object #1 (`CREATETRANSPORTORDERFROMLEG`) has been deployed to ABN1060 in the latest Oracle deployment. Two important changes:

1. **Type changed: Function → Procedure.** The routine is now a Procedure, not a Function. The TMS Bridge calls it as `OperationType.Function` (`CreateTransportOrderFromLegMutation.cs:43`) and expects a return value via `result.Rows[0].Field<object[]>("Result")` (line 45). This call will fail against the Procedure. The TMS Bridge code, DB Verifier registry (`db-objects.json:44`), and DB Object Inventory all need to be updated from Function to Procedure.

2. **Parameter renamed: `Mode` → `nMode`.** The parameter `Mode numeric` was renamed to `nMode numeric` because `MODE` is an Oracle reserved word. The TMS Bridge passes this parameter as `"mode"` (`CreateTransportOrderFromLegMutation.cs:33`). The parameter name must be updated to `"nMode"` in the TMS Bridge code.

Object #4 (`REMOVESHIPMENT`) was **not mentioned** in the deployment and remains missing.

**Action required:** (a) Object #4 (`REMOVESHIPMENT`) still needs to be created in PDIS_TRANSPORTORDER on ABN1060. (b) TMS Bridge code must be adapted for Object #1: change `OperationType.Function` → `OperationType.Procedure` and parameter `"mode"` → `"nMode"`. (c) DB Verifier registry and DB Object Inventory must be updated to reflect the type change. (d) For #2 and #3, clarify with the TMS team whether to deploy them for completeness or remove them from the TMS Bridge inventory.

### Category 2: Queue Infrastructure (Partial Fix — Investigation Ongoing)

P3 developer testing revealed that write procedures fail at runtime due to a missing Oracle Advanced Queuing (AQ) queue. Initial testing identified `CreateAndAddLeg` and `Delete`; follow-up testing confirmed the issue is systemic.

**Root cause:** `TMSBR1060.CAL_QUEUE_Q` was not accessible.

**Update 2026-05-12 (TMS Team):** The permission grant for `CAL_QUEUE_Q` has been provided to the `TMSBR1060` user. The TMS team has raised the question of **why this permission is needed** — this should be clarified.

**Update 2026-05-13 (P3 retry results):** The permission grant **partially** resolved the issue:
- **`SetParticipant` now works** — no CAL_QUEUE_Q error.
- **`CreateAndAddLeg` still fails** — same ORA-24010 error persists.

This raises the question whether `SetParticipant` and `CreateAndAddLeg` use **different overloads** (i.e., different call signatures/variants) of `CAL_QUEUE_Q` within `TMS1060.CAL_QUEUE`, and whether the permission grant only covers one of them. P3 flagged this as the next line of investigation.

**Confirmed affected procedures (before fix):**
- `CreateAndAddLeg` (initial batch) — **still failing after fix**
- `Delete` (initial batch) — retry pending
- `RemoveLeg` (second batch — confirmed by P3) — retry pending
- `SetParticipant` (second batch — confirmed by P3) — **resolved by fix**
- `RemoveParticipant` (second batch — confirmed by P3) — retry pending

P3 assessment: likely **all write procedures** were affected, since the queue is referenced from triggers that fire on data modification. The partial fix suggests different code paths may exist.

**Error chain for CreateAndAddLeg (2026-05-13, still failing):**
```
ORA-24010: QUEUE TMSBR1060.CAL_QUEUE_Q does not exist
  -> SYS.DBMS_AQ (line 180)
  -> TMS1060.CAL_QUEUE (line 132)
  -> TMS1060.CAL_QUEUE (line 152)
  -> TMS1060.CAL_QUEUE (line 168)
  -> TMS1060.PTA_DASHBOARD_MP4 (line 113)
  -> trigger TMS1060.TRAIUD_SENDUNG_TABRD_MP4 (line 9)
  -> TMS1060.PTA (line 4976)
  -> TMS1060.PTA (line 1719)
  -> TMS1060.PTA (line 5262)
  -> TMS1060.PDIS_TRANSPORTORDER (line 316)
  -> TMS1060.PDIS_TRANSPORTORDER (line 298)
```

**Error chain for Delete (ORA-21000 — under investigation):**
```
ORA-21000: error number argument to raise_application_error of -24010 is out of range
  -> TMS1060.PTA (line 5060)
  -> TMS1060.PDIS_TRANSPORTORDER (line 72)
```

The Delete error is the same root cause: the PTA package catches the ORA-24010 queue error and attempts to re-raise it via `raise_application_error`, but -24010 is outside the valid range (-20000 to -20999), causing a secondary ORA-21000 error. **TMS Team confirmed (2026-05-12) this is actively being worked on with the team.**

**Action required:** Investigate why the permission grant resolved `SetParticipant` but not `CreateAndAddLeg`. Compare the CAL_QUEUE overloads used by each code path (line numbers in `TMS1060.CAL_QUEUE`: 132, 152, 168). Retry remaining write procedures to determine which are fixed and which still fail. Clarify to the TMS team why the TMS Bridge user needs access to CAL_QUEUE_Q (it is referenced by triggers on tables modified by PDIS_TRANSPORTORDER procedures — the TMS Bridge user needs enqueue permission because the stored procedures execute under the caller's context).

### Category 3: Column-Level Issues

These are data-level problems not caught by the automated verifier (which checks object existence, not column definitions).

| # | View | Issue | Status | Impact |
|---|------|-------|--------|--------|
| 1 | `V_DIS_TRANSPORTORDER` | Column `Comment` uses mixed case instead of UPPERCASE | **Open** | TMS Bridge expects all-uppercase column names; queries fail |
| 2 | `V_DIS_TO_PICKUPPLANNING` | Column `U_TIME` was missing | **Resolved** (2026-05-13) | Deployed |

**Issue #1 — Comment casing:** Fix the `Comment` column name to `COMMENT` (or quoted uppercase) in `V_DIS_TRANSPORTORDER`. This remains an ABN1060-specific action.

**Issue #2 — U_TIME (Reclassified: Not ABN1060-Specific):**
Andrej (TMS team) stated (2026-05-12) that the field `U_TIME` does **not exist** in either of the views `V_DIS_TRANSPORTORDER` or `V_DIS_TO_PICKUPPLANNING` — neither in PostgreSQL, nor in Oracle, nor in the repository source code.

**Update 2026-05-13 — Git history contradicts this:** `U_TIME` **is present** in the repository. Commit `98b257fa` by Sonja Petkovic (2026-04-07, PBI 172967) explicitly added `s1.u_time` from the `sendung` table to `V_DIS_TRANSPORTORDER_PICKUPPLANNING` (later renamed to `V_DIS_TO_PICKUPPLANNING`). The column is present on `release/7.0.0.8+NEW-DISPO` and 6 other branches.

This means the view definition in the repo is correct and includes `U_TIME`. The issue is that this view definition was **not deployed** to the Oracle (ABN1060) and PostgreSQL databases. This is a deployment gap, not a missing feature.

**Update 2026-05-13 (TMS Team — deployment confirmation):** `V_DIS_TO_PickupPlanning.ora.sql` now contains `U_TIME` in the view. This resolves the deployment gap. **Remaining step:** Verify the same view definition is also applied in the PostgreSQL environment.

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
| Missing CREATETRANSPORTORDERFROMLEG | Found | Found | **Deployed** (2026-05-13) as Procedure — type mismatch with TMS Bridge (expects Function). Parameter `Mode` → `nMode`. |
| Missing CREATETRANSPORTORDERFROMSHIPMENT | Not tested | Found | Only caught by verifier. **Obsolete** per inventory |
| Missing ADDSHIPMENT | Not tested | Found | Only caught by verifier. **Obsolete** per inventory |
| Missing REMOVESHIPMENT | Not tested | Found | Only caught by verifier. Active — blocks dispatcher operations |
| Queue infrastructure missing | Found (runtime, 5 procedures confirmed). Retry: SetParticipant fixed, CreateAndAddLeg still fails | Not checked | Verifier checks existence/perms, not runtime deps. Partial fix suggests different code paths |
| Column naming (Comment) | Found | Not checked | Verifier doesn't check column definitions |
| Missing column (U_TIME) | Found | Not checked | **Resolved** (2026-05-13) — deployed to Oracle. Verify PostgreSQL. |
| Delete runtime error | Found | Not detected | Procedure exists and has correct signature |

This cross-reference demonstrates the complementary value of both approaches: the automated verifier catches missing objects systematically across all 77 dependencies, while manual testing catches runtime errors, column-level issues, and infrastructure gaps.

---

## Action Items

| # | Action | Owner | Priority | Status | Category |
|---|--------|-------|----------|--------|----------|
| 1a | ~~Create `CREATETRANSPORTORDERFROMLEG` in PDIS_TRANSPORTORDER~~ | TMS Team | High | **Done** (2026-05-13) — but deployed as **Procedure**, not Function | Missing Objects |
| 1b | Create `REMOVESHIPMENT` in PDIS_TRANSPORTORDER | TMS Team | High | Open | Missing Objects (active) |
| 1c | Decide on `CREATETRANSPORTORDERFROMSHIPMENT` and `ADDSHIPMENT`: deploy for completeness or remove from inventory | TMS Team / P3 | Low | Open | Missing Objects (obsolete) |
| 1d | **TMS Bridge adaptation:** Update `CreateTransportOrderFromLegMutation.cs` — change `OperationType.Function` → `OperationType.Procedure` (line 43) and parameter `"mode"` → `"nMode"` (line 33). Verify result handling is compatible with Procedure output. | P3 | **Critical** | Open | Type Mismatch |
| 1e | Update DB Verifier registry (`db-objects.json:44`) and DB Object Inventory: reclassify `CreateTransportOrderFromLeg` from Function to Procedure | P3 / CAL | Medium | Open | Registry Update |
| 2a | ~~Create Oracle AQ queue `CAL_QUEUE_Q` in TMSBR1060 schema~~ | TMS Team / DBA | High | **Done** (2026-05-12) | Infrastructure |
| 2b | ~~Retry write operations to confirm CAL_QUEUE_Q fix~~ | P3 | High | **Partial** (2026-05-13) | Verification |
| 2c | Investigate CAL_QUEUE overload difference between `SetParticipant` (works) and `CreateAndAddLeg` (still fails). Compare call paths at `TMS1060.CAL_QUEUE` lines 132, 152, 168 | P3 / TMS Team | High | Open | Investigation |
| 2d | Retry remaining write procedures (`Delete`, `RemoveLeg`, `RemoveParticipant`) to determine fix coverage | P3 | High | Open | Verification |
| 2e | Clarify to TMS team why TMSBR1060 needs CAL_QUEUE_Q access (trigger execution context) | P3 / CAL | Medium | Open | Documentation |
| 3 | Fix `Comment` column casing in V_DIS_TRANSPORTORDER | TMS Team / DBA | High | Open | Column Fix |
| 4 | ~~Deploy `V_DIS_TO_PICKUPPLANNING` view definition (includes `U_TIME`) to ABN1060 Oracle~~ and verify PostgreSQL | TMS Team / DBA | High | **Partially done** (2026-05-13) — Oracle deployed, PostgreSQL pending | Deployment Gap |
| 5 | Resolve ORA-21000 error in Delete (PTA line 5060 error re-raise) | TMS Team | High | **In progress** (2026-05-12) | Runtime Error |
| 6 | Re-run verifier after fixes to confirm resolution | P3 | Medium | Blocked on #1b, #1d, #3 | Verification |
| 7 | Retry remaining write procedures (`Delete`, `RemoveLeg`, `RemoveParticipant`) to classify fix coverage | P3 | High | Open | Verification |
| 8 | **P3 to confirm** TMS Team's deployments: verify `CreateTransportOrderFromLeg` (as Procedure) is callable and `U_TIME` is present in `V_DIS_TO_PICKUPPLANNING` on ABN1060 | P3 | High | Open | Verification |

---

<internal>

## Related Files

- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/Ivailo-analysis.md` - P3 developer testing notes (first batch)
- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/ivailo-2.md` - P3 developer testing notes (second batch — CAL_QUEUE_Q blast radius)
- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/TMS-Verfitier-results.md` - Automated verifier output
- `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/` - Verifier tool source
- `02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md` - Object registry source (v1.1)
- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/2026-05-12_feedback Matt.md` - TMS Team feedback on CAL_QUEUE_Q grant, U_TIME non-existence, ORA-21000 status
- `00_Meetings/2026-05-13_oracle-abn1060-batch-v3/2026-05-13_oracle-abn1060-batch-v3.md` - P3 retry results: SetParticipant works, CreateAndAddLeg still fails (with error screenshot)
- `00_Meetings/2026-05-13_abn1060-matt-feedback.md` - TMS Team deployment confirmation: CreateTransportOrderFromLeg (as Procedure) + U_TIME deployed

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
| 1.2 | 2026-05-12 | Matthias Max | Updated with TMS Team feedback: (1) CAL_QUEUE_Q permission granted to TMSBR1060 — retry pending; (2) U_TIME reclassified — column doesn't exist in any environment (Oracle, PGS, repo), now a TMS Bridge-side investigation; (3) ORA-21000 Delete error actively being worked on by TMS team. |
| 1.3 | 2026-05-13 | Matthias Max | U_TIME finding corrected: column IS in the repo (commit `98b257fa`, Sonja Petkovic, 2026-04-07, PBI 172967). The view definition was not deployed to Oracle/PGS — deployment gap, not a missing feature. Action item #4 updated accordingly. |
| 1.4 | 2026-05-13 | Matthias Max | CAL_QUEUE_Q permission grant partial fix: `SetParticipant` now works, `CreateAndAddLeg` still fails with ORA-24010. New investigation: possible different CAL_QUEUE overloads per code path. Updated error chain with line numbers from P3 retry screenshot. Action items 2b-2e restructured. Source: P3 developer retry, overload question raised by P3. |
| 1.5 | 2026-05-13 | Matthias Max | TMS Team deployment confirmation: (1) `CreateTransportOrderFromLeg` deployed as **Procedure** (not Function) with parameter `Mode` renamed to `nMode` (Oracle reserved word). TMS Bridge code (`CreateTransportOrderFromLegMutation.cs`) calls `OperationType.Function` and uses `"mode"` — both must be adapted. New critical action item #1d. (2) `U_TIME` now deployed in `V_DIS_TO_PICKUPPLANNING` on Oracle — action item #4 partially resolved (PostgreSQL verification pending). (3) `RemoveShipment` not mentioned, remains missing. Action items restructured (#1a-#1e, #8 added). |

---

<div align="center">Created and maintained by <strong>Virtual Architect</strong></div>
