# Release Script Verification Report

**Generated:** 2025-11-17
**Authors Checked:** Sonja Petkovic, Mohamad Al Haj Omar
**Date Range:** 2025-01-01 to 2025-11-17

## Executive Summary

Analysis of files added by Sonja and Mohamad reveals **1 missing file** that needs to be added to the release scripts.

---

## Missing Files

### ❌ TO_QPAYLOAD.sql

- **Location:** `src/sql/type/TO_QPAYLOAD.sql`
- **Should be in:** `src/sql/scripts/type/all_create_types.sql`
- **Status:** File exists but is NOT referenced in the release script
- **Action Required:** Add `\i ../type/TO_QPAYLOAD.sql` to all_create_types.sql

---

## Files That Were Deleted/Renamed

### V_DIS_TO_TOURPOINT_OPTIMIZED.sql

- **Status:** Created and added to all_create_views.sql, but later deleted (commit 17690aa5)
- **Note:** This file was intentionally removed from the codebase

### V_DIS_TRANSPORTORDER_PICKUPPLANING.sql

- **Status:** Created with typo (single N), then corrected to V_DIS_TRANSPORTORDER_PICKUPPLANNING.sql (double N)
- **Current Status:** ✓ The corrected version IS properly included in all_create_views.sql (line 510)

---

## Verified Files - All Correctly Included

### Functions ✓

**File:** `src/sql/scripts/function/all_create_functions.sql`

| File | Line | Status |
|------|------|--------|
| TRAI_EQM_ITEMS_TRFUNC_REUSE_EQM_K_PLPROXY.sql | 68 | ✓ |
| TRAI_EQM_ITEMS_TRFUNC_REUSE_EQM_K_PLPROXY_WRAPPER.sql | 69 | ✓ |

### Packages ✓

**File:** `src/sql/scripts/package/all_create_packages.sql`

| File | Line | Status |
|------|------|--------|
| CAL_JSON.sql | 100 | ✓ |
| PDIS_LEG.sql | 715 | ✓ |
| PDIS_SHIPMENT.sql | 714 | ✓ |
| PDIS_SYS.sql | 716 | ✓ |
| PDIS_TOURPOINT.sql | 555 | ✓ |
| PDIS_TRANSPORTORDER.sql | 713 | ✓ |
| PTA.sql | 414 | ✓ |
| PTA_SESSION.sql | 264 | ✓ |
| PTMS_HST.sql | 485 | ✓ |
| PTOURORT_LIB.sql | 155 | ✓ |

### Tables ✓

**File:** `src/sql/scripts/table/all_create_tms_tables.sql`

| File | Status |
|------|--------|
| fak_lst_g.sql | ✓ |
| lst_g.sql | ✓ |

### Triggers ✓

**File:** `src/sql/scripts/trigger/all_create_trigger_functions.sql`

| File | Line | Status |
|------|------|--------|
| TRBIU_LADERAUM_LKW_PROFIL.sql | 38 | ✓ |
| all_trigger_functions.sql | 19 | ✓ |

### Types

**File:** `src/sql/scripts/type/all_create_types.sql`

| File | Line | Status |
|------|------|--------|
| DBTO_CONDITION.sql | 65 | ✓ |
| dbto_csmsenhst.sql | 24 | ✓ |
| TO_QPAYLOAD.sql | - | ❌ **MISSING** |

### Views ✓

**File:** `src/sql/scripts/view/all_create_views.sql`

All 17 view files currently in the repository are properly included:

| File | Line | Status |
|------|------|--------|
| V_COM_PST_ZDB.sql | 129 | ✓ |
| V_CSM_SEN_HST2.sql | 41 | ✓ |
| V_DIS_BRANCH_ADDRESS.sql | 512 | ✓ |
| V_DIS_FREIGHT_EXCHANGE_TOURPOINTS.sql | 511 | ✓ |
| V_DIS_LEG.sql | 517 | ✓ |
| V_DIS_SHIPMENT.sql | 515 | ✓ |
| V_DIS_SHIPMENT_ALL.sql | 516 | ✓ |
| V_DIS_TO_TOURPOINT.sql | 508 | ✓ |
| V_DIS_TRANSPORTORDER.sql | 505 | ✓ |
| V_DIS_TRANSPORTORDER_PICKUPPLANNING.sql | 510 | ✓ |
| V_DIS_TRANSPORTORDER_PRESETTEMP.sql | 507 | ✓ |
| V_ESB_SENDUNG.sql | 796 | ✓ |
| V_TA3.sql | 721 | ✓ |
| v_csm_sen_hst.sql | 33 | ✓ |
| v_dis_transportorder_filter.sql | 603 | ✓ |

---

## Recommendations

### Immediate Action Required

1. **Add TO_QPAYLOAD.sql to all_create_types.sql**
   - Insert `\i ../type/TO_QPAYLOAD.sql` at the appropriate location in `src/sql/scripts/type/all_create_types.sql`
   - Recommended position: After line 101 (after DBTO_TMS_HST_VT.sql) since it follows alphabetical ordering

### Verification Steps

1. Add the missing file to the release script
2. Run the release script in a test environment to ensure proper execution order
3. Verify no dependency errors occur

---

## Files Analyzed

- **Mohamad's files:** `git-files-mohamadaomar-2025-01-01_2025-11-17.md` (4 files)
- **Sonja's files:** `git-files-sonjapetkovicP3-2025-01-01_2025-11-17.md` (39 files)
- **Total files reviewed:** 43 files across 6 SQL object types
