# Comparison: VA Inventory vs. Yosif's List

**Date:** 2026-04-29
**VA Source:** This exploration's `tms-bridge-database-object-inventory.md`
**Yosif Source:** `00_Meetings/2026-04-28_From_Yosif_TMSBridge-SQL-Objects 1 1.md`

---

## Total Object Count

| Category | VA Inventory | Yosif | Delta | Notes |
|----------|-------------|-------|-------|-------|
| Tables | 17 (11+6) | 10 | +7 | VA counts 6 bridge-local entities + `tourpoint` as tables; Yosif correctly notes BranchDbContext overrides them all to views |
| Views | 22 (header) / 21 (listed) | 21 | 0-1 | VA header says 22 but only 21 listed — counting error. Actual view names match exactly |
| Functions | ~11 | 11 (10 + 1 table func) | 0 | Yosif separates `cal_uniface.list2dbtt` as "Table Function (Oracle only)" |
| Procedures | ~26 | 35 | -9 | VA significantly undercounted; some misclassified as functions |
| Custom Types | 0 | 1 | -1 | VA missing `legtype` PostgreSQL ENUM |
| **Total** | **~76** | **78** | | |

---

## View Names: Exact Match (21/21)

All 21 view names are identical across both lists. Both use pre-rename names.

| # | View Name | VA | Yosif |
|---|-----------|:--:|:-----:|
| 1 | `v_dis_branch_address` | Y | Y |
| 2 | `v_dis_contact_details` | Y | Y |
| 3 | `v_dis_freight_exchange_tourpoints` | Y | Y |
| 4 | `v_dis_leg` | Y | Y |
| 5 | `v_dis_shipment_all` | Y | Y |
| 6 | `v_dis_to_tourpoint` | Y | Y |
| 7 | `v_dis_tourpoint_client_communication` | Y | Y |
| 8 | `v_dis_to_tourpoint_target_dates` | Y | Y |
| 9 | `v_dis_transportorder` | Y | Y |
| 10 | `v_dis_transportorder_filter` | Y | Y |
| 11 | `v_dis_transportorder_pickupplanning` | Y | Y |
| 12 | `v_dis_transportorder_presettemp` | Y | Y |
| 13 | `v_dis_transportorder_features` | Y | Y |
| 14 | `v_ebv_delivery_note` | Y | Y |
| 15 | `v_ebv_leg` | Y | Y |
| 16 | `v_ebv_participant` | Y | Y |
| 17 | `v_ebv_service` | Y | Y |
| 18 | `v_ebv_shipment` | Y | Y |
| 19 | `v_pers_tb` | Y | Y |
| 20 | `v_sen_ls` | Y | Y |
| 21 | `sen_ref` | Y | Y |

---

## Classification Disagreements (Procedure vs. Function)

| Routine | VA Classification | Yosif Classification |
|---------|-------------------|---------------------|
| `pdis_transportorder.setvehicleattributes` | Function | Procedure (WRITE) |
| `pdis_transportorder.addshipment` | Procedure | Function (WRITE) |

---

## Objects in Yosif but Missing from VA

| Object | Type | Notes |
|--------|------|-------|
| `pdis_transportorder.setxserverdto` | Function (WRITE) | VA only lists `getxserverdto` |
| `pdis_transportorder.removedriver` | Procedure | VA has it in Bridge mutation list but omitted from DB objects section |
| `legtype` | PostgreSQL ENUM | Custom type in `pdis_transportorder` schema (values: VL, HL, NL) |

## Objects in VA but NOT in Yosif

| Object | Type | Notes |
|--------|------|-------|
| `tourpoint` (as table) | Table | Yosif correctly identifies this is overridden to view `v_dis_to_tourpoint` |
| 6 bridge-local "tables" | Tables | `shipment`, `presettemp`, `freightexchange_tourpoint`, `transportorder`, `transportordercut`, `transportorder_pickupplanning` — Yosif correctly notes these are all overridden to views |

---

## Yosif's List: Additional Metadata Not in VA

- **READ/WRITE classification** for every object
- **Schema assignment** (public vs tms) for views and tables
- **DbSet names** mapping views to C# properties
- **Navigation-only entities** flagged (EBV sub-entities without own DbSet)
- **Obsolete markers** (e.g., `CreateTransportOrderFromLotMutation`)
- **Implicit call chains** (`PstHstMetaDataResolver` chains `cal_uniface.item` -> `cal_uniface.list2dbtt`)

---

## View Rename Coverage

Both lists use the **old (pre-rename)** view names. Neither covers the 7 renames from TMS Database commit `6543ffd9`.

| Renamed View | VA | Yosif | Rename State |
|-------------|:--:|:-----:|-------------|
| `v_dis_freight_exchange_tourpoints` -> `v_dis_freight_exchange_tp` | old | old | NOT COVERED |
| `v_dis_transportorder_features` -> `v_dis_to_features` | old | old | NOT COVERED |
| `v_dis_transportorder_pickupplanning` -> `v_dis_to_pickupplanning` | old | old | NOT COVERED |
| `v_dis_tourpoint_client_communication` -> `v_dis_tp_client_comm` | old | old | NOT COVERED |
| `v_dis_to_tourpoint_target_dates` -> `v_dis_to_tp_target_dates` | old | old | NOT COVERED |
| `v_dis_transportorder_filter` -> `v_dis_to_filter` | old | old | NOT COVERED |
| `v_dis_transportorder_presettemp` -> `v_dis_to_presettemp` | old | old | NOT COVERED |

---

## Assessment

**Yosif's list is more precise on:**
- Table vs. view distinction (respects BranchDbContext overrides)
- Procedure vs. function classification
- Completeness of routines (35 procs vs VA's ~26)
- Metadata (READ/WRITE, schema, DbSet)

**VA inventory adds:**
- Bridge internal structure (GraphQL queries/mutations, services, multi-tenancy)
- View rename tracking from TMS Database commit `6543ffd9`
- Upcoming branch impact analysis

**Recommended action:** Merge Yosif's precise DB object classifications into the VA inventory as the authoritative baseline, keep the VA's Bridge-side structure and rename tracking as complementary sections.
