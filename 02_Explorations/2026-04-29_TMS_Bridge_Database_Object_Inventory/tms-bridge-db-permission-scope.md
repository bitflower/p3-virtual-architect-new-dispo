# TMS Bridge: Database Objects

**Date:** 2026-04-29
**TMS Database Version:** `release/7.0.0.8+NEW-DISPO` (commit 6543ffd9)

<internal>
**Purpose:** Binding overview of all database objects accessed by `CALConsult.TMSBridge.API`. Defines the required permission scope for the TMS Bridge database user in production.
</internal>


---

## Schema Convention

- **tms** = runtime-resolved TMS tenant schema (e.g., `tms01001` on PostgreSQL, `TMS01001` on Oracle)
- **public** = PostgreSQL default schema (Bridge-local objects)
- **pdis_transportorder**, **pdis_tourpoint**, **pdis_leg**, **disp_mde_ah**, **disp_mde_eb**, **cal_uniface**, **pdis_transportorderdto** = fixed routine schemas

---

## 1. Tables (11)

All accessed READ-only via Entity Framework Core. No `SaveChanges` calls exist in the application layer.

> **Classification principle:** Objects are classified by their **actual database type** (TABLE or VIEW), not by the EF Core mapping directive. `ToView()` in EF Core means "treat as read-only entity" — it does not imply the database object is a view. `ToTable()` means "treat as writable entity". When `ToView()` targets a database TABLE, the object is classified here as a TABLE with read-only access.

| # | Object Name | Type | Schema | EF Mapping | Access | Required Permission |
|---|-------------|------|--------|------------|--------|---------------------|
| 1 | `bordero` | TABLE | tms | `ToTable` | READ | SELECT |
| 2 | `fahrer` | TABLE | tms | `ToTable` | READ | SELECT |
| 3 | `ort` | TABLE | tms | `ToTable` | READ | SELECT |
| 4 | `person` | TABLE | tms | `ToTable` | READ | SELECT |
| 5 | `pst_hst` | TABLE | tms | `ToTable` | READ | SELECT |
| 6 | `rollkart` | TABLE | tms | `ToTable` | READ | SELECT |
| 7 | `sendung` | TABLE | tms | `ToTable` | READ | SELECT |
| 8 | `sen_ls_pst` | TABLE | tms | `ToTable` | READ | SELECT |
| 9 | `sen_ls_ref` | TABLE | tms | `ToTable` | READ | SELECT |
| 10 | `sen_zuord` | TABLE | tms | `ToTable` | READ | SELECT |
| 11 | `sen_ref` | TABLE | tms | `ToView` | READ (read-only) | SELECT |

> **Note on #11:** `sen_ref` is a TABLE in the TMS database, mapped via `ToView("sen_ref")` in `SenRefEntityConfiguration.cs`. The `ToView()` directive enforces read-only access at the EF level — it does not change the underlying database object type. A `v_sen_ref` VIEW exists in the database (unions `sen_ref` + `sen_ls_ref`) but is **not used** by the TMS Bridge.

> **Note:** Entity configurations for `transportorder`, `shipment`, `tourpoint`, `presettemp`, `freightexchange_tourpoint`, `transportorder_pickupplanning`, and `transportordercut` declare `ToTable(...)` but `BranchDbContext.OnModelCreating` overrides all of them with `ToView(...)`. These are listed in section 2 (Views).

---

## 2. Views (20)

All accessed READ-only via Entity Framework Core.

### 2a. Disposition Views

| # | Object Name | Type | Schema | Access | Required Permission | Notes |
|---|-------------|------|--------|--------|---------------------|-------|
| 1 | `v_dis_transportorder` | VIEW | public | READ | SELECT | |
| 2 | `v_dis_to_filter` | VIEW | public | READ | SELECT | Renamed from `v_dis_transportorder_filter` |
| 3 | `v_dis_to_pickupplanning` | VIEW | public | READ | SELECT | Renamed from `v_dis_transportorder_pickupplanning` |
| 4 | `v_dis_shipment_all` | VIEW | public | READ | SELECT | |
| 5 | `v_dis_to_tourpoint` | VIEW | public | READ | SELECT | |
| 6 | `v_dis_freight_exchange_tp` | VIEW | public | READ | SELECT | Renamed from `v_dis_freight_exchange_tourpoints` |
| 7 | `v_dis_to_presettemp` | VIEW | public | READ | SELECT | Renamed from `v_dis_transportorder_presettemp` |
| 8 | `v_dis_branch_address` | VIEW | public | READ | SELECT | |
| 9 | `v_dis_leg` | VIEW | public | READ | SELECT | |
| 10 | `v_dis_to_features` | VIEW | tms | READ | SELECT | Renamed from `v_dis_transportorder_features` |
| 11 | `v_dis_contact_details` | VIEW | tms | READ | SELECT | |
| 12 | `v_dis_to_tp_target_dates` | VIEW | tms | READ | SELECT | Renamed from `v_dis_to_tourpoint_target_dates` |
| 13 | `v_dis_tp_client_comm` | VIEW | tms | READ | SELECT | Renamed from `v_dis_tourpoint_client_communication` |
| 14 | `v_pers_tb` | VIEW | tms | READ | SELECT | |

### 2b. EBV Views

| # | Object Name | Type | Schema | Access | Required Permission | Notes |
|---|-------------|------|--------|--------|---------------------|-------|
| 15 | `v_ebv_shipment` | VIEW | tms | READ | SELECT | |
| 16 | `v_ebv_delivery_note` | VIEW | tms | READ | SELECT | Navigation-only (no own DbSet) |
| 17 | `v_ebv_leg` | VIEW | tms | READ | SELECT | Navigation-only (no own DbSet) |
| 18 | `v_ebv_participant` | VIEW | tms | READ | SELECT | Navigation-only (no own DbSet) |
| 19 | `v_ebv_service` | VIEW | tms | READ | SELECT | Navigation-only (no own DbSet) |

### 2c. Sendung (Consignment) Views

| # | Object Name | Type | Schema | Access | Required Permission | Notes |
|---|-------------|------|--------|--------|---------------------|-------|
| 20 | `v_sen_ls` | VIEW | tms | READ | SELECT | |

---

## 3. Functions (11)

Called via `IRoutineExecutor`. Functions return data; some also mutate state (marked WRITE).

| # | Object Name | Type | Schema | Access | Required Permission | Called By |
|---|-------------|------|--------|--------|---------------------|----------|
| 1 | `pdis_transportorderdto.get` | FUNCTION | pdis_transportorderdto | READ | EXECUTE | `TransportOrderDetailsQuery` |
| 2 | `pdis_transportorder.getxserverdto` | FUNCTION | pdis_transportorder | READ | EXECUTE | `GetXserverDtoQuery` |
| 3 | `pdis_transportorder.getdriver` | FUNCTION | pdis_transportorder | READ | EXECUTE | `GetDriverMutation` |
| 4 | `pdis_transportorder.geterrormessage` | FUNCTION | pdis_transportorder | READ | EXECUTE | Internal error handler (`RoutineExecutor`) |
| 5 | `pdis_transportorder.setxserverdto` | FUNCTION | pdis_transportorder | WRITE | EXECUTE | `SetXServerDtoMutation` |
| 6 | `pdis_transportorder.createtransportorderfromleg` | FUNCTION | pdis_transportorder | WRITE | EXECUTE | `CreateTransportOrderFromLegMutation` |
| 7 | `pdis_transportorder.createtransportorderfromshipment` | FUNCTION | pdis_transportorder | WRITE | EXECUTE | `CreateTransportOrderFromLotMutation` (obsolete) |
| 8 | `pdis_transportorder.addshipment` | FUNCTION | pdis_transportorder | WRITE | EXECUTE | `CreateTransportOrderFromLotMutation` (obsolete) |
| 9 | `pdis_leg.getstaysloadedstatus` | FUNCTION | pdis_leg | READ | EXECUTE | `GetStaysLoadedQuery` |
| 10 | `cal_uniface.item` | FUNCTION | cal_uniface | READ | EXECUTE | `ItemMutation`, `PstHstMetaDataResolver` |
| 11 | `cal_uniface.list2dbtt` | TABLE FUNCTION | cal_uniface | READ | EXECUTE | `List2DbttMutation`, `PstHstMetaDataResolver` |

> **Note on #10 + #11:** `PstHstMetaDataResolver` chains `cal_uniface.item` followed by `cal_uniface.list2dbtt` automatically when a `pst_hst` GraphQL query includes the `decodedMetaData` field. These are triggered server-side without an explicit mutation call.

> **Note on #11:** `cal_uniface.list2dbtt` is a table function. Only an Oracle builder exists (`OracleTableBuilder`, generates `SELECT * FROM TABLE(...)`). No PostgreSQL equivalent is implemented.

---

## 4. Stored Procedures (35)

Called via `IRoutineExecutor`. All are WRITE operations (mutate database state).

### 4a. `pdis_transportorder` Schema — Transport Order Management (22)

| # | Object Name | Type | Schema | Access | Required Permission | Called By |
|---|-------------|------|--------|--------|---------------------|----------|
| 1 | `pdis_transportorder.delete` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `DeleteTransportOderMutation` |
| 2 | `pdis_transportorder.addtourpoint` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `AddTourpointMutation` |
| 3 | `pdis_transportorder.edittourpoint` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `EditTourpointMutation` |
| 4 | `pdis_transportorder.deletetourpoint` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `DeleteTourpointMutation` |
| 5 | `pdis_transportorder.movetourpoint` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `MoveTourpointMutation` |
| 6 | `pdis_transportorder.removeleg` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `RemoveLegMutation` |
| 7 | `pdis_transportorder.createandaddleg` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `CreateAndAddLegMutation` |
| 8 | `pdis_transportorder.removeshipment` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `RemoveShipmentFromTransportOrderMutation` |
| 9 | `pdis_transportorder.addvehicle` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `AssignVehicleMutation` |
| 10 | `pdis_transportorder.removevehicle` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `RemoveVehicleMutation` |
| 11 | `pdis_transportorder.addtrailer` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `AddTrailerMutation` |
| 12 | `pdis_transportorder.removetrailer` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `RemoveTrailerMutation` |
| 13 | `pdis_transportorder.setparticipant` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `SetParticipantMutation` |
| 14 | `pdis_transportorder.removeparticipant` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `RemoveParticipantMutation` |
| 15 | `pdis_transportorder.setpresettemp` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `SetPresetTempMutation` |
| 16 | `pdis_transportorder.settransportmode` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `SetTransportModeMutation` |
| 17 | `pdis_transportorder.setvehicleattributes` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `SetVehicleAttributesMutation` |
| 18 | `pdis_transportorder.setequipmenthired` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `SetEquipmentHiredMutation` |
| 19 | `pdis_transportorder.setloadingaidsoptions` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `SetLoadingAidsOptionMutation` |
| 20 | `pdis_transportorder.setcomment` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `SetCommentMutation` |
| 21 | `pdis_transportorder.setdriver` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `SetDriverMutation` |
| 22 | `pdis_transportorder.removedriver` | PROCEDURE | pdis_transportorder | WRITE | EXECUTE | `RemoveDriverMutation` |

### 4b. `pdis_tourpoint` Schema — Tourpoint Management (6)

| # | Object Name | Type | Schema | Access | Required Permission | Called By |
|---|-------------|------|--------|--------|---------------------|----------|
| 23 | `pdis_tourpoint.setcustomertournumber` | PROCEDURE | pdis_tourpoint | WRITE | EXECUTE | `SetCustomerTourNumberMutation` |
| 24 | `pdis_tourpoint.setloadinginterval` | PROCEDURE | pdis_tourpoint | WRITE | EXECUTE | `SetLoadingIntervalMutation` |
| 25 | `pdis_tourpoint.settargetloadingstarttime` | PROCEDURE | pdis_tourpoint | WRITE | EXECUTE | `SetTargetLoadingStartTimeMutation` |
| 26 | `pdis_tourpoint.settargetloadingendtime` | PROCEDURE | pdis_tourpoint | WRITE | EXECUTE | `SetTargetLoadingEndTimeMutation` |
| 27 | `pdis_tourpoint.removeloadingintervals` | PROCEDURE | pdis_tourpoint | WRITE | EXECUTE | `RemoveLoadingIntervalsMutation` |
| 28 | `pdis_tourpoint.setloadingreference` | PROCEDURE | pdis_tourpoint | WRITE | EXECUTE | `SetLoadingReferenceMutation` |

### 4c. `pdis_leg` Schema — Leg Management (1)

| # | Object Name | Type | Schema | Access | Required Permission | Called By |
|---|-------------|------|--------|--------|---------------------|----------|
| 29 | `pdis_leg.staysloaded` | PROCEDURE | pdis_leg | WRITE | EXECUTE | `StaysLoadedMutation` |

### 4d. `disp_mde_ah` Schema — MDE Arrival Hub (4)

| # | Object Name | Type | Schema | Access | Required Permission | Called By |
|---|-------------|------|--------|--------|---------------------|----------|
| 30 | `disp_mde_ah.scanbarcode` | PROCEDURE | disp_mde_ah | WRITE | EXECUTE | `DispMdeAhScanBarcodeMutation` |
| 31 | `disp_mde_ah.startentladung` | PROCEDURE | disp_mde_ah | WRITE | EXECUTE | `DispMdeAhStartEntladungMutation` |
| 32 | `disp_mde_ah.endeentladung` | PROCEDURE | disp_mde_ah | WRITE | EXECUTE | `DispMdeAhEndeEntladungMutation` |
| 33 | `disp_mde_ah.abschlnve` | PROCEDURE | disp_mde_ah | WRITE | EXECUTE | `DispMdeAhAbschlNVEMutation` |

### 4e. `disp_mde_eb` Schema — MDE Departure Hub (2)

| # | Object Name | Type | Schema | Access | Required Permission | Called By |
|---|-------------|------|--------|--------|---------------------|----------|
| 34 | `disp_mde_eb.endeentladung` | PROCEDURE | disp_mde_eb | WRITE | EXECUTE | `DispMdeEbEndeEntladungMutation` |
| 35 | `disp_mde_eb.abschlnve` | PROCEDURE | disp_mde_eb | WRITE | EXECUTE | `DispMdeEbAbschlNVEMutation` |

---

## 5. Custom Types (1)

| # | Object Name | Type | Schema | Required Permission | Values | Notes |
|---|-------------|------|--------|---------------------|--------|-------|
| 1 | `legtype` | ENUM | pdis_transportorder | USAGE | VL, HL, NL | Registered via `HasPostgresEnum` (PostgreSQL only). Used as input parameter in `createtransportorderfromleg`, `createandaddleg`, `removeshipment`, and obsolete lot mutations. |

---

## Summary: Permission Scope

### By Access Pattern

| Access | Count | Required Permission |
|--------|-------|---------------------|
| READ (Tables) | 11 | SELECT |
| READ (Views) | 20 | SELECT |
| READ (Functions) | 5 | EXECUTE |
| WRITE (Functions) | 4 | EXECUTE |
| READ (Table Functions) | 1 | EXECUTE |
| WRITE (Procedures) | 35 | EXECUTE |
| USAGE (Custom Types) | 1 | USAGE |
| **Total** | **77** | |

### By Schema

| Schema | SELECT | EXECUTE | USAGE | Total |
|--------|--------|---------|-------|-------|
| tms (tenant) | 16 (11 tables + 5 views) | — | — | 16 |
| public | 9 (9 views) | — | — | 9 |
| pdis_transportorder | — | 31 (9 functions + 22 procedures) | 1 (legtype) | 32 |
| pdis_tourpoint | — | 6 procedures | — | 6 |
| pdis_leg | — | 2 (1 function + 1 procedure) | — | 2 |
| pdis_transportorderdto | — | 1 function | — | 1 |
| disp_mde_ah | — | 4 procedures | — | 4 |
| disp_mde_eb | — | 2 procedures | — | 2 |
| cal_uniface | — | 2 functions | — | 2 |
| **Total** | **25** | **48** | **1** | **77** |

---

## View Rename Reference

The following 7 views were renamed in TMS Database `release/7.0.0.8+NEW-DISPO` (commit `6543ffd9`). This document uses the **new names**. The TMS Bridge code must be updated to reference these new names before deployment.

| Old Name | New Name |
|----------|----------|
| `v_dis_transportorder_filter` | `v_dis_to_filter` |
| `v_dis_transportorder_pickupplanning` | `v_dis_to_pickupplanning` |
| `v_dis_freight_exchange_tourpoints` | `v_dis_freight_exchange_tp` |
| `v_dis_transportorder_presettemp` | `v_dis_to_presettemp` |
| `v_dis_transportorder_features` | `v_dis_to_features` |
| `v_dis_to_tourpoint_target_dates` | `v_dis_to_tp_target_dates` |
| `v_dis_tourpoint_client_communication` | `v_dis_tp_client_comm` |

Not renamed: `v_dis_transportorder_count` -> `v_dis_to_count` (not used by TMS Bridge).

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-29 | Matthias Max | Initial inventory: 10 tables, 21 views, 11 functions, 35 procedures, 1 custom type. View names updated to post-rename state (7 views renamed in TMS DB commit 6543ffd9). |
| 1.1 | 2026-04-29 | Matthias Max | Reclassified `sen_ref` from VIEW to TABLE (read-only via `ToView`). Added EF Mapping column to tables section. Added classification principle: objects classified by actual DB type, not EF mapping directive. Counts: 11 tables, 20 views. Triggered by Eric Meijers' review feedback. |

---

<div align="center">Created and maintained by <strong>Virtual Architect</strong></div>
