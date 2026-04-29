# TMSBridge — SQL Database Objects Reference

All objects accessed by `CALConsult.TMSBridge.API` via Entity Framework Core or direct DB routine calls.
Schema abbreviations: **public** = `public`, **tms** = runtime-resolved TMS schema (e.g. `tms1034`).

---

## Tables

Directly accessed as tables (no view override in `BranchDbContext`). All are **READ only** via EF Core — no `SaveChanges` calls exist in the application layer.

| Table | Schema | Operations |
|---|---|---|
| `bordero` | tms | READ |
| `fahrer` | tms | READ |
| `ort` | tms | READ |
| `person` | tms | READ |
| `pst_hst` | tms | READ |
| `rollkart` | tms | READ |
| `sendung` | tms | READ |
| `sen_ls_pst` | tms | READ |
| `sen_ls_ref` | tms | READ |
| `sen_zuord` | tms | READ |

> **Note:** Several entity configurations declare `ToTable(...)` (e.g. `transportorder`, `shipment`, `tourpoint`, `presettemp`, `freightexchange_tourpoint`, `transportorder_pickupplanning`, `transportordercut`) but `BranchDbContext.OnModelCreating` overrides all of them with `ToView(...)`. Those entities are therefore accessed via views — see the Views section below.

---

## Views

All views are **READ only** (EF Core maps them as keyless or keyed view entities; no insert/update/delete).

### Dispatcher / Transport Order Views (public schema)

| View | Schema | DbSet | Operations |
|---|---|---|---|
| `v_dis_transportorder` | public | `TransportOrders` | READ |
| `v_dis_transportorder_filter` | public | `TransportOrdersCut` | READ |
| `v_dis_transportorder_pickupplanning` | public | `PickupPlanningTransportOrders` | READ |
| `v_dis_shipment_all` | public | `DISShipments` | READ |
| `v_dis_to_tourpoint` | public | `Tourpoints` | READ |
| `v_dis_freight_exchange_tourpoints` | public | `FreightExchangeTourpoints` | READ |
| `v_dis_transportorder_presettemp` | public | `PresetsTemp` | READ |
| `v_dis_branch_address` | public | `BranchAddresses` | READ |
| `v_dis_leg` | public | `Legs` | READ |
| `v_dis_transportorder_features` | tms | `Vehicle` | READ |
| `v_dis_contact_details` | tms | `ContactsDetails` | READ |
| `v_dis_to_tourpoint_target_dates` | tms | `TourpointTargetDates` | READ |
| `v_dis_tourpoint_client_communication` | tms | `TourpointClientCommunications` | READ |
| `v_pers_tb` | tms | `DispoParticipants` | READ |

### EBV (Electronic Delivery Note) Views

| View | Schema | DbSet | Operations |
|---|---|---|---|
| `v_ebv_shipment` | tms | `EBVShipments` | READ |
| `v_ebv_delivery_note` | tms | *(navigation only)* | READ |
| `v_ebv_leg` | tms | *(navigation only)* | READ |
| `v_ebv_participant` | tms | *(navigation only)* | READ |
| `v_ebv_service` | tms | *(navigation only)* | READ |

### Sendung (Consignment) Views / Tables

| Object | Type | Schema | DbSet | Operations |
|---|---|---|---|---|
| `v_sen_ls` | View | tms | `SenLs` | READ |
| `sen_ref` | View | tms | `SenRef` | READ |

---

## DB Functions

Called via `IRoutineExecutor` with `OperationType.Function`. All return data — treat as **READ** unless noted.

| Function (schema.name) | Operation | GraphQL Entry Point |
|---|---|---|
| `pdis_transportorderdto.get` | READ | `TransportOrderDetailsQuery` |
| `pdis_transportorder.getxserverdto` | READ | `GetXserverDtoQuery` |
| `pdis_transportorder.getdriver` | READ | `GetDriverMutation` |
| `pdis_transportorder.geterrormessage` | READ | Internal (`RoutineExecutor` error handler) |
| `pdis_transportorder.setxserverdto` | WRITE | `SetXServerDtoMutation` |
| `pdis_transportorder.createtransportorderfromleg` | WRITE | `CreateTransportOrderFromLegMutation` |
| `pdis_transportorder.createtransportorderfromshipment` | WRITE | `CreateTransportOrderFromLotMutation` *(obsolete)* |
| `pdis_transportorder.addshipment` | WRITE | `CreateTransportOrderFromLotMutation` *(obsolete)* |
| `pdis_leg.getstaysloadedstatus` | READ | `GetStaysLoadedQuery` |
| `cal_uniface.item` | READ | `ItemMutation`, `PstHstEntityMetaDataResolver` |

---

## Table Functions (Oracle only)

Called via `IRoutineExecutor` with `OperationType.Table`. Generates `SELECT * FROM TABLE(schema.function_name(...))`. Only an Oracle builder exists (`OracleTableBuilder`) — no Postgres equivalent. All are **READ**.

| Function (schema.name) | Operation | GraphQL Entry Point |
|---|---|---|
| `cal_uniface.list2dbtt` | READ | `List2DbttMutation`, `PstHstEntityMetaDataResolver` |

> **Note:** `PstHstEntityMetaDataResolver` chains `cal_uniface.item` and `cal_uniface.list2dbtt` automatically when a `pst_hst` query includes the `decodedMetaData` field — these function calls are triggered server-side without a separate explicit mutation.

---

## Stored Procedures

Called via `IRoutineExecutor` with `OperationType.Procedure`. All are **WRITE** operations (they mutate DB state).

### `disp_mde_ah` Schema (Dispatcher MDE — Arrival Hub)

| Procedure | Operation | GraphQL Entry Point |
|---|---|---|
| `disp_mde_ah.scanbarcode` | WRITE | `DispMdeAhScanBarcodeMutation` |
| `disp_mde_ah.startentladung` | WRITE | `DispMdeAhStartEntlandungMutation` |
| `disp_mde_ah.endeentladung` | WRITE | `DispMdeAhEndeEntladungMutation` |
| `disp_mde_ah.abschlnve` | WRITE | `DispMdeAhAbschlNVEMutation` |

### `disp_mde_eb` Schema (Dispatcher MDE — Departure Hub)

| Procedure | Operation | GraphQL Entry Point |
|---|---|---|
| `disp_mde_eb.endeentladung` | WRITE | `DispMdeEbEndeEntladungMutation` |
| `disp_mde_eb.abschlnve` | WRITE | `DispMdeEbAbschlNVEMutation` |

### `pdis_transportorder` Schema (Transport Order Management)

| Procedure | Operation | GraphQL Entry Point |
|---|---|---|
| `pdis_transportorder.delete` | WRITE | `DeleteTransportOderMutation` |
| `pdis_transportorder.addtourpoint` | WRITE | `AddTourpointMutation` |
| `pdis_transportorder.edittourpoint` | WRITE | `EditTourpointMutation` |
| `pdis_transportorder.deletetourpoint` | WRITE | `DeleteTourpointMutation` |
| `pdis_transportorder.movetourpoint` | WRITE | `MoveTourpointMutation` |
| `pdis_transportorder.removeleg` | WRITE | `RemoveLegMutation` |
| `pdis_transportorder.createandaddleg` | WRITE | `CreateAndAddLegMutation` |
| `pdis_transportorder.removeshipment` | WRITE | `RemoveShipmentFromTransportOrderMutation` |
| `pdis_transportorder.addvehicle` | WRITE | `AssignVehicleMutation` |
| `pdis_transportorder.removevehicle` | WRITE | `RemoveVehicleMutation` |
| `pdis_transportorder.addtrailer` | WRITE | `AddTrailerMutation` |
| `pdis_transportorder.removetrailer` | WRITE | `RemoveTrailerMutation` |
| `pdis_transportorder.setparticipant` | WRITE | `SetParticipantMutation` |
| `pdis_transportorder.removeparticipant` | WRITE | `RemoveParticipantMutation` |
| `pdis_transportorder.setpresettemp` | WRITE | `SetPresetTempMutation` |
| `pdis_transportorder.settransportmode` | WRITE | `SetTransportModeMutation` |
| `pdis_transportorder.setvehicleattributes` | WRITE | `SetVehicleAttributesMutation` |
| `pdis_transportorder.setequipmenthired` | WRITE | `SetEquipmentHiredMutation` |
| `pdis_transportorder.setloadingaidsoptions` | WRITE | `SetLoadingAidsOptionMutation` |
| `pdis_transportorder.setcomment` | WRITE | `SetCommentMutation` |
| `pdis_transportorder.setdriver` | WRITE | `SetDriverMutation` |
| `pdis_transportorder.removedriver` | WRITE | `RemoveDriverMutation` |

### `pdis_tourpoint` Schema (Tour Point Management)

| Procedure | Operation | GraphQL Entry Point |
|---|---|---|
| `pdis_tourpoint.setcustomertournumber` | WRITE | `SetCustomerTourNumberMutation` |
| `pdis_tourpoint.setloadinginterval` | WRITE | `SetLoadingIntervalMutation` |
| `pdis_tourpoint.settargetloadingstarttime` | WRITE | `SetTargetLoadingStartTimeMutation` |
| `pdis_tourpoint.settargetloadingendtime` | WRITE | `SetTargetLoadingEndTimeMutation` |
| `pdis_tourpoint.removeloadingintervals` | WRITE | `RemoveLoadingIntervalsMutation` |
| `pdis_tourpoint.setloadingreference` | WRITE | `SetLoadingReferenceMutation` |

### `pdis_leg` Schema (Leg Management)

| Procedure | Operation | GraphQL Entry Point |
|---|---|---|
| `pdis_leg.staysloaded` | WRITE | `StaysLoadedMutation` |

---

## Custom Types / Enums

| Object | Type | Schema | Notes |
|---|---|---|---|
| `legtype` | PostgreSQL ENUM | `pdis_transportorder` | Values: `VL`, `HL`, `NL`. Registered via `HasPostgresEnum` (PostgreSQL only). |
