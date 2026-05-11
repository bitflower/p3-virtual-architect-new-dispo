# ABN1060 Oracle TMS Database Review
**Date:** 2026-05-11
**Environment:** ABN (Oracle) - Schema TMS1060

<internal>

**Status:** Exploration

</internal>

---

<internal>

## Original User Input

First batch of reviews for the ABN1060 Oracle database. Two sources:
1. **P3 developer testing** - connected Backend + TMS Bridge against Oracle DB, identified runtime errors
2. **Automated TMS Bridge DB Verifier** (from `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier`) - systematic check of all 77 database objects the TMS Bridge depends on

</internal>

---

## Summary

| Area | Status | Details |
|------|--------|---------|
| Tables (11) | All pass | Exist with correct permissions |
| Views (20) | All pass | Exist with correct permissions |
| Functions (11) | **3 missing** | `CreateTransportOrderFromLeg`, `CreateTransportOrderFromShipment` (obsolete), `AddShipment` (obsolete) |
| Procedures (35) | **1 missing** | `RemoveShipment` |
| Column definitions | **2 issues** | `Comment` casing in `V_DIS_TRANSPORTORDER`, missing `U_TIME` in `V_DIS_TO_PICKUPPLANNING` |
| Queue infrastructure | **Missing** | `TMSBR1060.CAL_QUEUE_Q` not provisioned — causes runtime failures in `CreateAndAddLeg` and `Delete` |

| Metric | Value |
|--------|-------|
| Objects verified | 77 |
| Existence (Level 1.0) | 73/77 found, 1 skipped, 4 not found |
| Signature (Level 1.5) | 42/42 match |
| Permissions (Level 2.0) | 73/77 granted, 1 skipped, 4 denied (non-existent) |
| Active blockers | 2 missing objects + 1 missing queue + 2 column issues |
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

### Category 2: Missing Queue Infrastructure (Blocker)

P3 developer testing of `CreateAndAddLeg` and `Delete` procedures revealed that both fail at runtime due to a missing Oracle Advanced Queuing (AQ) queue.

**Root cause:** `TMSBR1060.CAL_QUEUE_Q` does not exist.

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

**Error chain for Delete:**
```
ORA-21000: error number argument to raise_application_error of -24010 is out of range
  -> TMS1060.PTA (line 5060)
  -> TMS1060.PDIS_TRANSPORTORDER (line 72)
```

The Delete error is the same root cause: the PTA package catches the ORA-24010 queue error and attempts to re-raise it via `raise_application_error`, but -24010 is outside the valid range (-20000 to -20999), causing a secondary ORA-21000 error.

**Action required:** The Oracle AQ queue `CAL_QUEUE_Q` needs to be created in the `TMSBR1060` schema. This is a provisioning/setup step for the TMS Bridge infrastructure.

### Category 3: Column-Level Issues (Blockers)

These are data-level problems not caught by the automated verifier (which checks object existence, not column definitions).

| # | View | Issue | Impact |
|---|------|-------|--------|
| 1 | `V_DIS_TRANSPORTORDER` | Column `Comment` uses mixed case instead of UPPERCASE | TMS Bridge expects all-uppercase column names; queries fail |
| 2 | `V_DIS_TO_PICKUPPLANNING` | Column `U_TIME` is missing | Pickup planning page fails |

**Action required:** Fix the `Comment` column name to `COMMENT` (or quoted uppercase) in `V_DIS_TRANSPORTORDER`. Add `U_TIME` column to `V_DIS_TO_PICKUPPLANNING`.

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
| Queue infrastructure missing | Found (runtime) | Not checked | Verifier checks existence/perms, not runtime deps |
| Column naming (Comment) | Found | Not checked | Verifier doesn't check column definitions |
| Missing column (U_TIME) | Found | Not checked | Verifier doesn't check column definitions |
| Delete runtime error | Found | Not detected | Procedure exists and has correct signature |

This cross-reference demonstrates the complementary value of both approaches: the automated verifier catches missing objects systematically across all 77 dependencies, while manual testing catches runtime errors, column-level issues, and infrastructure gaps.

---

## Action Items

| # | Action | Owner | Priority | Category |
|---|--------|-------|----------|----------|
| 1a | Create `CREATETRANSPORTORDERFROMLEG` and `REMOVESHIPMENT` in PDIS_TRANSPORTORDER | TMS Team | High | Missing Objects (active) |
| 1b | Decide on `CREATETRANSPORTORDERFROMSHIPMENT` and `ADDSHIPMENT`: deploy for completeness or remove from inventory | TMS Team / P3 | Low | Missing Objects (obsolete) |
| 2 | Create Oracle AQ queue `CAL_QUEUE_Q` in TMSBR1060 schema | TMS Team / DBA | High | Infrastructure |
| 3 | Fix `Comment` column casing in V_DIS_TRANSPORTORDER | TMS Team / DBA | High | Column Fix |
| 4 | Add `U_TIME` column to V_DIS_TO_PICKUPPLANNING | TMS Team / DBA | High | Column Fix |
| 5 | Re-run verifier after fixes to confirm resolution | P3 | Medium | Verification |

---

## Related Files

- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/Ivailo-analysis.md` - P3 developer testing notes
- `00_Meetings/2026-05-11_Oracle_TMS_Check_ABN1060/TMS-Verfitier-results.md` - Automated verifier output
- `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/` - Verifier tool source
- `02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md` - Object registry source (v1.1)

---

<internal>

## Tools Used

| Tool | Purpose |
|------|---------|
| TMS Bridge DB Verifier (`Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier`) | Automated verification of 77 DB objects across 3 levels (existence, signature, permissions) |

</internal>

---

<div align="center">Created and maintained by <strong>Virtual Architect</strong></div>
