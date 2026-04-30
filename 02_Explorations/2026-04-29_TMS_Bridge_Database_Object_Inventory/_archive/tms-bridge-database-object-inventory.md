# TMS Bridge Database Object Inventory

**Date:** 2026-04-29
**Status:** Active
**TMS Database Branch:** `release/7.0.0.8+NEW-DISPO` (commit 6543ffd9)
**TMS Bridge:** `Code/Disposition-Abstraction-Layer`

---

## Summary

Complete inventory of all TMS database objects referenced by the TMS Bridge (Disposition Abstraction Layer). The Bridge uses Entity Framework for read queries (mapped to views/tables) and an `IRoutineExecutor` service for write operations (calling stored procedures/functions via `OracleProcedureBuilder` / `PostgreProcedureBuilder`).

**Totals: ~76 database objects**

| Category | Count |
|----------|-------|
| TMS Schema Tables | 11 |
| Bridge Local Tables | 6 |
| Views | 22 |
| Stored Procedures | ~26 |
| Functions | ~11 |

---

## Tables

### TMS Schema Tables (11)

| Table | Entity Configuration | Domain |
|-------|---------------------|--------|
| `bordero` | `BorderoEntityConfiguration.cs` | Bordero |
| `fahrer` | `DriverEntityConfiguration.cs` | Driver |
| `person` | `PersonEntityConfiguration.cs` | Person |
| `ort` | `LocationEntityConfiguration.cs` | Location |
| `pst_hst` | `PstHstEntityConfiguration.cs` | Postal history |
| `rollkart` | `RollkartEntityConfiguration.cs` | Roll cart |
| `sen_zuord` | `SenZuordEntityConfiguration.cs` | Shipment assignment |
| `sen_ls_pst` | `SenLsPstEntityConfiguration.cs` | Shipment list postal |
| `sen_ls_ref` | `SenLsRefEntityConfiguration.cs` | Shipment list reference |
| `sendung` | `SendungEntityConfiguration.cs` | Shipment (core) |
| `tourpoint` | `TourpointEntityConfiguration.cs` | Tourpoint |

### Bridge Local Tables (6) — `public` schema

| Table | Entity Configuration | Domain |
|-------|---------------------|--------|
| `shipment` | `DISShipmentEntityConfiguration.cs` | Shipment (Bridge) |
| `presettemp` | `PresetTempEntityConfiguration.cs` | Preset temperature |
| `freightexchange_tourpoint` | `FreightExchangeTourpointEntityConfiguration.cs` | Freight exchange |
| `transportorder` | `TransportOrderEntityConfiguration.cs` | Transport order |
| `transportordercut` | `TransortOrderCutEntitytConfiguration.cs` | Transport order cut |
| `transportorder_pickupplanning` | `TransportOrderPickupPlanningEntityConfiguration.cs` | Pickup planning |

---

## Views (22)

### DIS Views (Disposition)

| View | Entity Configuration | Domain |
|------|---------------------|--------|
| `v_dis_branch_address` | `BranchAddressEntityConfiguration.cs` | Branch addresses |
| `v_dis_contact_details` | `ContactDetailsEntityConfiguration.cs` | Contact details |
| `v_dis_freight_exchange_tourpoints` | `FreightExchangeTourpointEntityConfiguration.cs` | Freight exchange |
| `v_dis_leg` | `LegEntityConfiguration.cs` | Legs |
| `v_dis_shipment_all` | `DISShipmentEntityConfiguration.cs` | Shipments |
| `v_dis_to_tourpoint` | `TourpointEntityConfiguration.cs` | Tourpoints |
| `v_dis_tourpoint_client_communication` | `TourpointClientCommunicationEntityConfiguration.cs` | Client communication |
| `v_dis_to_tourpoint_target_dates` | `TourpointTargetDatesEntityConfiguration.cs` | Target dates |
| `v_dis_transportorder` | `BranchDbContext.cs` | Transport orders |
| `v_dis_transportorder_filter` | `BranchDbContext.cs` | Transport order filtering |
| `v_dis_transportorder_pickupplanning` | `BranchDbContext.cs` | Pickup planning |
| `v_dis_transportorder_presettemp` | `BranchDbContext.cs` | Preset temperatures |
| `v_dis_transportorder_features` | `VehicleEntityConfiguration.cs` | Vehicle features |

### EBV Views

| View | Entity Configuration | Domain |
|------|---------------------|--------|
| `v_ebv_delivery_note` | `EBVDeliveryNoteEntityConfiguration.cs` | Delivery notes |
| `v_ebv_leg` | `EBVLegEntityConfiguration.cs` | Legs |
| `v_ebv_participant` | `EBVParticipantEntityConfiguration.cs` | Participants |
| `v_ebv_service` | `EBVServiceEntityConfiguration.cs` | Services |
| `v_ebv_shipment` | `EBVShipmentEntityConfiguration.cs` | Shipments |

### Other Views

| View | Entity Configuration | Domain |
|------|---------------------|--------|
| `v_pers_tb` | `DispoParticipantEntityConfiguration.cs` | Dispo participants |
| `v_sen_ls` | `SenLsEntityConfiguration.cs` | Sendung lists |
| `sen_ref` | `SenRefEntityConfiguration.cs` | Sendung references |

---

## Stored Procedures & Functions

### `pdis_transportorder` Schema (~26 routines)

#### Procedures

| Routine | Mutation File | Purpose |
|---------|--------------|---------|
| `addtourpoint` | `AddTourpointMutation.cs` | Add tourpoint to TO |
| `removeleg` | `RemoveLegMutation.cs` | Remove leg from TO |
| `edittourpoint` | `EditTourpointMutation.cs` | Edit tourpoint |
| `deletetourpoint` | `DeleteTourpointMutation.cs` | Delete tourpoint |
| `addvehicle` | `AssignVehicleMutation.cs` | Assign vehicle |
| `removevehicle` | `RemoveVehicleMutation.cs` | Remove vehicle |
| `addtrailer` | `AddTrailerMutation.cs` | Add trailer |
| `removetrailer` | `RemoveTrailerMutation.cs` | Remove trailer |
| `addshipment` | (Mutations) | Add shipment to TO |
| `removeshipment` | `RemoveShipmentFromTransportOrderMutation.cs` | Remove shipment |
| `setdriver` | `SetDriverMutation.cs` | Set driver |
| `setparticipant` | `SetParticipantMutation.cs` | Set participant |
| `removeparticipant` | `RemoveParticipantMutation.cs` | Remove participant |
| `setequipmenthired` | `SetEquipmentHiredMutation.cs` | Set equipment hired flag |
| `setpresettemp` | `SetPresetTempMutation.cs` | Set preset temperature |
| `settransportmode` | `SetTransportModeMutation.cs` | Set transport mode |
| `setcomment` | `SetCommentMutation.cs` | Set comment |
| `setloadingaidsoptions` | `SetLoadingAidsOptionMutation.cs` | Set loading aids options |
| `createandaddleg` | `CreateAndAddLegMutation.cs` | Create and add leg |
| `movetourpoint` | `MoveTourpointMutation.cs` | Move tourpoint |
| `delete` | `DeleteTransportOderMutation.cs` | Delete transport order |

#### Functions

| Routine | Source | Purpose |
|---------|--------|---------|
| `createtransportorderfromshipment` | `CreateTransportOrderFromLotMutation.cs` | Create TO from shipment |
| `createtransportorderfromleg` | `CreateTransportOrderFromLegMutation.cs` | Create TO from leg |
| `getdriver` | `GetDriverMutation.cs` | Get driver info |
| `getxserverdto` | `SetXServerDtoMutation.cs` | Get XServer DTO |
| `setvehicleattributes` | `SetVehicleAttributesMutation.cs` | Set vehicle attributes |
| `geterrormessage` | `RoutineExecutor.cs` | Get error message |

### `pdis_tourpoint` Schema (6 functions)

| Routine | Mutation File | Purpose |
|---------|--------------|---------|
| `removeloadingintervals` | `RemoveLoadingIntervalsMutation.cs` | Remove loading intervals |
| `setloadinginterval` | `SetLoadingIntervalMutation.cs` | Set loading interval |
| `setloadingreference` | `SetLoadingReferenceMutation.cs` | Set loading reference |
| `settargetloadingstarttime` | `SetTargetLoadingStartTimeMutation.cs` | Set target loading start |
| `settargetloadingendtime` | `SetTargetLoadingEndTimeMutation.cs` | Set target loading end |
| `setcustomertournumber` | `SetCustomerTourNumberMutation.cs` | Set customer tour number |

### `pdis_leg` Schema (2 functions)

| Routine | Source | Purpose |
|---------|--------|---------|
| `getstaysloadedstatus` | `GetStaysLoadedQuery.cs` | Get stays-loaded status |
| `staysloaded` | `StaysLoadedMutation.cs` | Set stays-loaded flag |

### `disp_mde_ah` Schema (4 procedures - Unloading/Picking)

| Routine | Mutation File | Purpose |
|---------|--------------|---------|
| `startentladung` | `DispMdeAhStartEntlandungMutation.cs` | Start unloading |
| `endeentladung` | `DispMdeAhEndeEntladungMutation.cs` | End unloading |
| `abschlnve` | `DispMdeAhAbschlNVEMutation.cs` | Complete NVE |
| `scanbarcode` | `DispMdeAhScanBarcodeMutation.cs` | Scan barcode |

### `disp_mde_eb` Schema (2 procedures - Loading)

| Routine | Mutation File | Purpose |
|---------|--------------|---------|
| `endeentladung` | `DispMdeEbEndeEntladungMutation.cs` | End unloading |
| `abschlnve` | `DispMdeEbAbschlNVEMutation.cs` | Complete NVE |

### `cal_uniface` Schema (2 functions)

| Routine | Mutation File | Purpose |
|---------|--------------|---------|
| `item` | `ItemMutation.cs` | Item lookup |
| `list2dbtt` | `List2DbttMutation.cs` | List to DBTT conversion |

### `pdis_transportorderdto` Schema (1 function)

| Routine | Source | Purpose |
|---------|--------|---------|
| `get` | `BranchDbContext.cs` (DbFunction) | Get transport order DTO |

---

## Breaking Changes: View Renames (2026-04-29)

As of TMS Database `release/7.0.0.8+NEW-DISPO` commit `6543ffd9`, the following views were renamed. The Bridge still references the **old names** and will break at runtime without matching updates.

| Old Name (Bridge references) | New Name (DB) | Bridge File to Update |
|------------------------------|---------------|-----------------------|
| `v_dis_freight_exchange_tourpoints` | `v_dis_freight_exchange_tp` | `FreightExchangeTourpointEntityConfiguration.cs` |
| `v_dis_transportorder_features` | `v_dis_to_features` | `VehicleEntityConfiguration.cs` |
| `v_dis_transportorder_pickupplanning` | `v_dis_to_pickupplanning` | `TransportOrderPickupPlanningEntityConfiguration.cs` |
| `v_dis_tourpoint_client_communication` | `v_dis_tp_client_comm` | `TourpointClientCommunicationEntityConfiguration.cs` |
| `v_dis_to_tourpoint_target_dates` | `v_dis_to_tp_target_dates` | `TourpointTargetDatesEntityConfiguration.cs` |
| `v_dis_transportorder_filter` | `v_dis_to_filter` | `BranchDbContext.cs` |
| `v_dis_transportorder_presettemp` | `v_dis_to_presettemp` | `BranchDbContext.cs` |

**Not used by Bridge (safe):** `V_DIS_TRANSPORTORDER_COUNT` renamed to `V_DIS_TO_COUNT`

**Content change:** `V_DIS_TO_PresetTemp.sql` has structural changes beyond the rename — review column additions/removals.

### Upcoming Branches to Watch

| Branch | Impact |
|--------|--------|
| `173129/sonjapetkovic-Adding_missing_property_into_CreateTransportOrderFromLeg` | Affects `pdis_transportorder.createtransportorderfromleg` |
| `173275/sonjapetkovic-Add_new_fields_into_V_DIS_LEG` | Affects `v_dis_leg` view |

---

## TMS Bridge Internal Structure

### GraphQL Queries (26)

| Query | Domain |
|-------|--------|
| `BranchAddressQuery` | Branch addresses |
| `CartageQuery` | Bordero, Rollkart |
| `ContactsDetailsQuery` | Contact details |
| `DispoParticipantQuery` | Dispo participants |
| `DriverQuery` | Drivers |
| `FreightExchangeTourpointQuery` | Freight exchange tourpoints |
| `GetStaysLoadedQuery` | Leg stays-loaded status |
| `GetXserverDtoQuery` | XServer DTO |
| `LegQuery` | Legs |
| `LocationQuery` | Locations (Ort) |
| `PersonQuery` | Persons |
| `PresetTempQuery` | Preset temperatures |
| `PstHstQuery` | PST/HST data |
| `SenQuery` | Sendung queries |
| `SenZuordQuery` | Sendung assignments |
| `SendungQuery` | Sendung detail |
| `ShipmentQuery` | Shipments (EBV + DIS) |
| `TourpointClientCommunicationQuery` | Client communication |
| `TourpointQuery` | Tourpoints |
| `TourpointTargetDatesQuery` | Target dates |
| `TransportOrderDetailsQuery` | TO details (via `pdis_transportorderdto.get`) |
| `TransportOrderFieldValuesQuery` | TO field values |
| `TransportOrderFilterQuery` | TO filter/cut view |
| `TransportOrderPickupPlanningQuery` | Pickup planning |
| `TransportOrderQuery` | TO list (paginated + unpaginated) |
| `TransportOrdersGroupedQuery` | Grouped TOs with pagination |
| `VehicleQuery` | Vehicle features |

### GraphQL Mutations (41)

#### `PdisTransportOrder` Mutations (25)

| Mutation | DB Routine |
|----------|-----------|
| `AddTourpointMutation` | `pdis_transportorder.addtourpoint` |
| `AddTrailerMutation` | `pdis_transportorder.addtrailer` |
| `AssignVehicleMutation` | `pdis_transportorder.addvehicle` |
| `CreateAndAddLegMutation` | `pdis_transportorder.createandaddleg` |
| `CreateTransportOrderFromLegMutation` | `pdis_transportorder.createtransportorderfromleg` |
| `DeleteTourpointMutation` | `pdis_transportorder.deletetourpoint` |
| `DeleteTransportOrderMutation` | `pdis_transportorder.delete` |
| `EditTourpointMutation` | `pdis_transportorder.edittourpoint` |
| `GetDriverMutation` | `pdis_transportorder.getdriver` |
| `MoveTourpointMutation` | `pdis_transportorder.movetourpoint` |
| `RemoveDriverMutation` | `pdis_transportorder.removedriver` |
| `RemoveLegMutation` | `pdis_transportorder.removeleg` |
| `RemoveParticipantMutation` | `pdis_transportorder.removeparticipant` |
| `RemoveShipmentFromTransportOrderMutation` | `pdis_transportorder.removeshipment` |
| `RemoveTrailerMutation` | `pdis_transportorder.removetrailer` |
| `RemoveVehicleMutation` | `pdis_transportorder.removevehicle` |
| `SetCommentMutation` | `pdis_transportorder.setcomment` |
| `SetDriverMutation` | `pdis_transportorder.setdriver` |
| `SetEquipmentHiredMutation` | `pdis_transportorder.setequipmenthired` |
| `SetLoadingAidsOptionMutation` | `pdis_transportorder.setloadingaidsoptions` |
| `SetParticipantMutation` | `pdis_transportorder.setparticipant` |
| `SetPresetTempMutation` | `pdis_transportorder.setpresettemp` |
| `SetTransportModeMutation` | `pdis_transportorder.settransportmode` |
| `SetVehicleAttributesMutation` | `pdis_transportorder.setvehicleattributes` |
| `SetXServerDtoMutation` | `pdis_transportorder.getxserverdto` |

#### `PdisTourPoint` Mutations (6)

| Mutation | DB Routine |
|----------|-----------|
| `RemoveLoadingIntervalsMutation` | `pdis_tourpoint.removeloadingintervals` |
| `SetCustomerTourNumberMutation` | `pdis_tourpoint.setcustomertournumber` |
| `SetLoadingIntervalMutation` | `pdis_tourpoint.setloadinginterval` |
| `SetLoadingReferenceMutation` | `pdis_tourpoint.setloadingreference` |
| `SetTargetLoadingEndTimeMutation` | `pdis_tourpoint.settargetloadingendtime` |
| `SetTargetLoadingStartTimeMutation` | `pdis_tourpoint.settargetloadingstarttime` |

#### `PdisLeg` Mutations (1)

| Mutation | DB Routine |
|----------|-----------|
| `StaysLoadedMutation` | `pdis_leg.staysloaded` |

#### `DispMdeAh` Mutations (4)

| Mutation | DB Routine |
|----------|-----------|
| `DispMdeAhStartEntladungMutation` | `disp_mde_ah.startentladung` |
| `DispMdeAhEndeEntladungMutation` | `disp_mde_ah.endeentladung` |
| `DispMdeAhAbschlNVEMutation` | `disp_mde_ah.abschlnve` |
| `DispMdeAhScanBarcodeMutation` | `disp_mde_ah.scanbarcode` |

#### `DispMdeEb` Mutations (2)

| Mutation | DB Routine |
|----------|-----------|
| `DispMdeEbEndeEntladungMutation` | `disp_mde_eb.endeentladung` |
| `DispMdeEbAbschlNVEMutation` | `disp_mde_eb.abschlnve` |

#### `CalUniface` Mutations (2)

| Mutation | DB Routine |
|----------|-----------|
| `ItemMutation` | `cal_uniface.item` |
| `List2DbttMutation` | `cal_uniface.list2dbtt` |

#### Inactive Mutations (commented out in Startup.cs)

- `CreateTransportOrderFromLotMutation`
- `AssignLotToTransportOrderMutation`

### Core Services

| Service | Purpose |
|---------|---------|
| `IRoutineExecutor` / `RoutineExecutor` | Executes stored procedures, functions, table ops; handles savepoints + error retrieval |
| `IDbConnectionStringProvider` / `DbConnectionStringProvider` | Resolves connection strings per database identifier; detects Oracle vs PostgreSQL |
| `BranchDbContextFactory` | Creates branch-specific DbContext instances with multi-tenant schema isolation |
| `ScopedDbContextProvider<T>` | Request-scoped DbContext lifecycle management |
| `IDbCommandFactory` / `DbCommandFactory` | Creates DB commands via vendor-specific builders |
| `IDbDataSourceCache` / `DbDataSourceCache` | Singleton cache for DB data sources (connection pooling) |
| `DbTransactionAbortState` | Tracks transaction failure state to abort subsequent ops in a request |
| `PstHstMetaDataResolver` | Resolves metadata for PST/HST entities |

### Vendor-Specific Builders

| Builder | Vendor | Type |
|---------|--------|------|
| `PostgreFunctionBuilder` | PostgreSQL | Function calls |
| `PostgreSQLProcedureBuilder` | PostgreSQL | Procedure calls |
| `OracleFunctionBuilder` | Oracle | Function calls |
| `OracleProcedureBuilder` | Oracle | Procedure calls |
| `OracleTableBuilder` | Oracle | Table operations |

### Multi-Tenancy Model

- **Pattern:** Database-per-branch with schema isolation
- **Identifier format:** `DO-{company}-{branch}` (e.g., `DO-01-001`)
- **TMS schema naming:** `tms{company}{branch}` (PostgreSQL) / `TMS{company}{branch}` (Oracle)
- **Per-request:** Each GraphQL request passes `databaseIdentifier`, DbContext created on-demand
- **Caching:** `DbDataSourceCache` (singleton) reuses connections; Oracle pool max 300, timeout 120s
- **Auth:** All queries/mutations require `[Authorize]` via KeyCloak

### Database Schemas Accessed

| Schema | Purpose |
|--------|---------|
| `tms{company}{branch}` | TMS tenant schema (tables + views) |
| `pdis_transportorder` | Transport order routines |
| `pdis_tourpoint` | Tourpoint routines |
| `pdis_leg` | Leg routines |
| `disp_mde_ah` | Unloading/picking routines |
| `disp_mde_eb` | Loading routines |
| `cal_uniface` | Uniface integration |
| `pdis_transportorderdto` | TO DTO function |
| `public` | Bridge-local tables |

See also: [comparison-va-vs-yosif.md](comparison-va-vs-yosif.md) — detailed comparison with Yosif's list from 2026-04-28.
