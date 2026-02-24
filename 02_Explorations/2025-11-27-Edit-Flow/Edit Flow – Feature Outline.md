# Edit Flow – Feature Outline
===========================

## 1. Objective
------------

*   **Short description of the Edit Flow feature**
Edit Flow enables dispatchers to modify key elements of transport orders including contractor, carrier, vehicle properties, tour point times/data, and tour start time, using TMS as source of truth where specified.
*   **Business goals and expected impact**: Completes the minimal editing process for transport orders, enabling faster dispatcher adjustments.
*   **Solution approach**: Focus on quick deliverables with minimal dependencies on external systems beyond TMS Database read/write.

## 2. Context
----------
Current disposition process overview
------------------------------------

The disposition process schedules and allocates transport orders to available vehicles, typically managed by dispatchers through a graphical interface for drag-and-drop assignment. It involves planning routes and ongoing route monitoring, handling vehicle capacity, driver assignments, and managing delivery priorities. The current process relies on the information from the Transport Management System (TMS) and often requires manual adjustments to accommodate changes or exceptions.

Role of TMS as source of truth
------------------------------

The TMS Database acts as the authoritative system for transport order data and center of all logic. It holds key information such as contractor, carrier, vehicle specifications, and tour points. The New Dispo app reads this data from the TMS Database and performs write-back operations where allowed, ensuring data consistency.

Assumptions and constraints
---------------------------

*   The TMS Database provides stable, well-defined APIs for reading and updating contractor, carrier, vehicle, and tour point data.
*   All edits must respect data ownership – only fields designated as owned by the TMS can be modified in the New Dispo app.
*   Dispatcher edits should not disrupt backend route calculation or violate existing constraints.

## 3. Scope of This Increment
--------------------------
Overview of included edit capabilities
--------------------------------------

*   Change Contractor (TMS as source): Reassign the contractor on a transport order.
*   Change Carrier (TMS as source): Reassign the carrier on a transport order.
*   Change vehicle properties and body type: Update attributes such as body type.
*   Set fixed arrival and/or departure at tour point: Apply either fixed arrival-only or fixed arrival plus departure constraints.
*   Delete tour point time restriction: Remove an existing fixed arrival time or existing fixed arrival time and fixed departure time constraint at a tour point.
*   Edit tour point data (TMS as source): Modify address-related and operational fields on an existing tour point.
*   Provide starting time for tour calculation: Have a starting time applied for route calculation.

Non-goals
---------

*   Change the transport mode.
*   Edit Contractor/Carrier or Tour Point data on a transport order where CMD is the source.
*   Edit a comment on a transport order.
*   Add a trailer.
*   Remove a trailer.
*   Check/uncheck "received on a hired basis" transport order properties.
*   Edit driver data on a transport order.
*   Edit the reference of a tour point.
*   Select an LHM option.
*   Block edit functionality based on transport order status.

## 4. User Stories / Use Cases

### 4.1 Change Contractor (TMS as source)
------------------------------------
**WHO**: As a user, I want to edit the contractor field(s) so that selected or manually entered contractor information is validated and correctly reflected on the transport order level.
**Description**: User types in contractor name field for fuzzy search of existing contractors from TMS. Candidates show Name1, country, ZIP, city, street. On selection, related fields auto-populate and deactivate (except email/name). Manual input allowed if no match; required fields: name, country, ZIP, city, street. Save only if required fields complete and country/ZIP/city combination exists in TMS table `ort`.
**Actors**: Dispatcher
**Triggers**: Edit directly in contractor field(s) on transport order details page.
**Preconditions**: TMS owns contractor data.
**Postconditions**:
*   Selected contractor: fields auto-populated, Transport Order updated.
*   Manual: validated address combination saved to transport order `pers` records of contractor only (not master data, e.g. `person` or CMD).
*   Email: always editable with format validation.
*   No carrier data: carrier fields populated with contractor values.
*   Incomplete manual: no save, unsaved changes warned on page leave.

**Technical Solution:**

- Fuzzy search based on data available in table `person` for the selected branch
- Country/ZIP/City combination validation via pairs in table `ort`
- Storing of contact/address data in table `pers` schema `pPers`

**Constraints:**

- Data in `person` is only as up to date as the latest manual import (no auto-import available, ownership of manual imports lies with CAL)
- Data in `ort` is only as up to date as the latest manual import (no auto-import available, ownership of manual imports lies with CAL)
- No TMS business logic is used to write into the `pers` record of the transport order (like `pTa.addunt`). Instead a new wrapper function will write directly into `pers` and create the relationship to the transport order via `sen_tb` bypassing any effects on subsequent processes like invoicing.

### 4.2 Change Carrier (TMS as source)
----------------------------------
**Analogous to User Story 4.1, except no auto-populate when contractor data is missing.**

**WHO**: As a user, I want to edit the carrier field(s) so that selected or manually entered carrier information is validated and correctly reflected on the transport order level.
**Description**: User types in carrier name field for fuzzy search of existing carriers from TMS. Candidates show Name1, country, ZIP, city, street. On selection, related fields auto-populate and deactivate (except email/name). Manual input allowed if no match; required fields: name, country, ZIP, city, street. Save only if required fields complete and country/ZIP/city combination exists in TMS table `ort`.
**Actors**: Dispatcher
**Triggers**: Edit directly in carrier field(s) on transport order details page.
**Preconditions**: TMS owns carrier data.
**Postconditions**:
*   Selected carrier: fields auto-populated, Transport Order updated.
*   Manual: validated address combination saved to transport order `pers` records of contractor only (not master data, e.g. `person` or CMD).
*   Email: always editable with format validation.
*   Incomplete manual: no save, unsaved changes warned on page leave.

**Technical Solution:**

- Fuzzy search based on data available in table `person` for the selected branch
- Country/ZIP/City combination validation via pairs in table `ort`
- Storing of contact/address data in table `pers` via schema `pPers`

**Constraints:**

- Data in `person` is only as up to date as the latest manual import (no auto-import available, ownership of manual imports lies with CAL)
- Data in `ort` is only as up to date as latest manual import (no auto-import available, ownership of manual imports lies with CAL)
- No TMS business logic is used to write into the `pers` record of the transport order (like `pTa.addunt`). Instead a new wrapper function will write directly into `pers` and create the relationship to the transport order via `sen_tb` bypassing any effects on subsequent processes like invoicing.

### 4.3 Change Vehicle Properties and Body Type
-------------------------------------------
**WHO**: As a user, I want to check and uncheck vehicle body types and properties so that I can correctly reflect the vehicle's technical setup and equipment in the transport order.
**Description**: Two areas on transport order details:
*   **Body Type**: Toggle checkboxes for ATP-Kühlung FRC – 20 °C (default selected), ATP-Kühlung FRB – 10 °C, ATP-Koffer, Wechselbrücke, Plane, Tank/Silo. Multiple selection allowed; checked items highlighted.
*   **Vehicle Properties**: Temperaturschreiber erforderlich, Vorkühlung (non-toggleable), Trennwand, Doppelstock. Changes saved on the fly.
**Actors**: Dispatcher
**Triggers**: Edit directly in body type/properties section on transport order details page.
**Preconditions**: transport order in editable state.
**Postconditions**: Selected attributes updated on transport order; visual highlights applied

**Technical Solution:**

- Vehicle properties are stored in the "hidden tourpoint" (`RES_HST` with `typ = TYP_STOP`) of each Transport Order. All values are stored as key-value pairs in `RES_HST_ZUS.T` field.
- Vehicle properties are read via the `V_DIS_TRANSPORTORDER_VEHICLEPROPS` view (to be developed by P3), which internally queries `RES_HST_ZUS` via the hidden tourpoint. The view internally:
  - Gets the hidden tourpoint via `RES_HST` (typ = TYP_STOP)
  - Reads body type via `ResHst.GetOpt(nTix, 'LKWTYP')`
  - Reads equipment features via `ResHst.GetOpt(nTix, 'AUSSTATT')` and parses into boolean flags
  - Reads temperature settings via `ResHst.GetZus(nTix, ZUSTYP_TEMP)` and extracts chamber values
- Vehicle properties are set via a new function `pDis_TransportOrder.SetVehicleProperties` containing the following logic:
  1. Receive Transport Order TIX and property data from UI
  2. Get the hidden tourpoint TIX via `pTA2.getStartOrt(nTaTix)`
  3. For body types: Call `ResHst.SetOpt(nResHstTix, 'LKWTYP', sValue)`
  4. For equipment: Call `ResHst.SetOpt(nResHstTix, 'AUSSTATT', sValue)`
  5. For temperature: Call `ResHst.SetZus(nResHstTix, ZUSTYP_TEMP, sValue)`

  > **Note:** `ResHst.SetOpt` and `ResHst.SetZus` handle both INSERT and UPDATE automatically (UPSERT pattern). Passing `null` for the value will DELETE the entry.

#### Reading

| Function                          | Description                                  |
| --------------------------------- | -------------------------------------------- |
| `pTA2.getStartOrt(nTaTix)`        | Get hidden tourpoint TIX for Transport Order |
| `ResHst.GetOpt(nTix, sKey)`       | Get option value from RES_HST_ZUS            |
| `ResHst.GetZus(nTix, nTyp)`       | Get additional value by type                 |
| `ResHst.GetZus(nTix, nTyp, sKey)` | Get additional value by type and key         |

#### Writing

| Procedure                           | Description                          |
| ----------------------------------- | ------------------------------------ |
| `ResHst.SetOpt(nTix, sKey, sValue)` | Set/update option (UPSERT)           |
| `ResHst.SetZus(nTix, nTyp, sValue)` | Set/update additional value (UPSERT) |
| `ResHst.SetZus(rResHstZus)`         | Set/update using record type         |

#### Constants (pTourOrt_Lib)

```sql
-- Property Types (res_hst_zus.typ)
ZUSTYP_TEMP() = 262 -- Temperature settings
ZUSTYP_OPT() = 999 -- Options (AUSSTATT, LKWTYP, etc.)

-- Property Keys (res_hst_zus.key)
ZUSKEY_AUSSTATT() = 'AUSSTATT' -- Equipment features list
ZUSKEY_LKWTYP_N() = 'LKWTYP' -- Body type

-- Temperature Property IDs
ZUSID_ANH_VORKUEHL_TEMP() = 'Anh_Vorkuehl_Temp'
ZUSID_ANH_KLAPPE_VORKUEHL_TEMP() = 'Klappe_Anh_Vorkuehl_Temp'
ZUSID_ANH_KLAPP3_VORKUEHL_TEMP() = 'Klappe3_Anh_Vorkuehl_Temp'
ZUSID_VORKUEHL_B() = 'Vorkuehl_B'

-- Tourpoint Types (res_hst.typ)
TYP_STOP() = 4 -- Hidden start point
```

#### Vehicle Properties (AUSSTATT)

Stored as option with `typ = 999` (ZUSTYP_OPT) and `key = 'AUSSTATT'`.

| Property                         | Description                   | Field in T          |
| -------------------------------- | ----------------------------- | ------------------- |
| Temperaturschreiber erforderlich | Temperature recorder required | `tempschreiber_b=T` |
| Vorkühlung                       | Pre-cooling required          | `vorkuehl_b=T`      |
| Trennwand                        | Partition wall                | `trennwand_b=T`     |
| Doppelstock                      | Double deck                   | `doppelstock_b=T`   |

Values are stored as key=value pairs, concatenated with delimiters.

#### Temperature Settings (TEMP)

Stored with `typ = 262` (ZUSTYP_TEMP). Values are stored as key=value pairs in the `T` field, concatenated with delimiters.

| Property                        | Description                          | Field in T                          |
| ------------------------------- | ------------------------------------ | ----------------------------------- |
| Trailer pre-cooling temperature | Trailer pre-cooling temperature      | `Anh_Vorkuehl_Temp=<value>`         |
| Front chamber pre-cooling       | Trailer front chamber pre-cooling    | `Klappe_Anh_Vorkuehl_Temp=<value>`  |
| Third chamber pre-cooling       | Trailer third chamber pre-cooling    | `Klappe3_Anh_Vorkuehl_Temp=<value>` |
| Trailer transport temperature   | Trailer transport temperature        | `Anh_Tran_Temp=<value>`             |
| Front chamber transport temp    | Trailer front chamber transport temp | `Klappe_Anh_Tran_Temp=<value>`      |
| Pre-cooling required            | Pre-cooling required flag            | `Vorkuehl_B=T`                      |

**Constraints:**

- The vehicle properties will be set as defined above and the process will not include any other business-logic relevant functions calls in TMS database
- Should the interfaces defined above contain errors or should the mapping of fields and functions be incorrect, the implementation of vehicle property management cannot proceed as described

### 4.4 Set Fixed Arrival and/or Departure Time for a Tour Point
-------------------------------------------
**WHO**: As a user, I want to set a fixed arrival time OR fixed arrival + departure time for a tour point so planning stays flexible under time restrictions.
**Description**: Button opens datepicker for arrival only or arrival+departure. Saved on tourpoint level as constraints for route calculation.
**Actors**: Dispatcher
**Triggers**: Button in transport order details/drive instructions → datepicker selection.
**Preconditions**: Tour point editable.
**Postconditions**: Time constraints applied; Button reactivates for tour calculation.

**Technical Solution:**

- The existing TMS interfaces will be used to set both single arrival times and ranges (arrival & departure)

#### TMS Interfaces

| Function                                                                                                                       | Description                                        |
| ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| `pDIS_TourPoint.SetTargetLoadingStartTime(TourPointId numeric, dStart timestamp without time zone)`                            | Designed for a single target time                  |
| `pDIS_TourPoint.SetLoadingInterval(TourPointId numeric, dStart timestamp without time zone, dEnd timestamp without time zone)` | Designed for managing a collection of time windows |

Both write to the same table (`RES_HST_ZUS`) with the same type (`PTOURORT_LIB.GET_ZUSTYP_LADEZR()`).

**Constraints:**

- The TMS interfaces are new, which introduces a risk of:
  - them not being as stable as needed, and
  - them not fully meeting TMS internal business logic constraints.
- Joachim is still working on some of these interfaces as of Wednesday, 3rd of December 2025.

### 4.5 Delete Tour Point Time Restriction
-------------------------------------------
**WHO**: As a user, I want to delete an existing fixed arrival and/or fixed departure time restriction from a tour point within a transport order so that I can remove outdated or incorrect time constraints and keep the planning accurate and flexible.
**Description**: Trash bin icon displayed next to each fixed arrival and departure time restriction. Clicking deletes immediately without confirmation. Field clears; new fixtime can be added. UI updates immediately.
**Actors**: Dispatcher
**Triggers**: Click trash bin icon next to time restriction.
**Preconditions**: Existing time restriction.
**Postconditions**: Time restriction deleted; tour point updated; Button reactivates for tour calculation.

**Technical Solution:**

- The existing TMS interface will be used to remove tour point fixed arrival and/or departure times.

#### TMS Interface

| Function                                                     | Description                                                           |
| ------------------------------------------------------------ | --------------------------------------------------------------------- |
| `pDIS_TourPoint.RemoveLoadingIntervals(TourPointId numeric)` | Designed to remove all loading time data (intervals AND target times) |

Internal TMS logic: It removes all loading time data by their shared type (`ZUSTYP_LADEZR`).

**Constraints:**

- The TMS interface is new, which introduces a risk of:
  - it not being as stable as needed, and
  - it not fully meeting TMS internal business logic constraints.
- Joachim is still working on some of these interfaces as of Wednesday, 3rd of December 2025.

### 4.6 Edit Tour Point Data (TMS as source)
----------------------------------------

**WHO**: As a user, I want to edit the address data of an existing tour point (except Loading/Unloading), so that selected or manually entered tour point information is correctly reflected on transport order level.
**Description**: Fuzzy search on Name1 field shows TMS candidates (Name1, country, ZIP, city, street). Selection auto-populates/deactivates fields (except reference/name/tour number). Manual input requires validated country/ZIP/city/street combination from TMS (red border on mismatch). Validated through TMS table `ort`. Save only if complete/existing/all required fields. Street allows non-TMS entries. Manual data stored on tour point's related `pers` (snapshot) record only (not in master data `person` or CMD).
**Actors**: Dispatcher
**Triggers**: Edit directly in Name1 field on tourpoint details page.
**Preconditions**: Non-loading/unloading tour point; TMS owns data.
**Postconditions**: Updated tour point on transport order; Transport order updated; Button reactivates for tour calculation; fields wiped if new name without match.

**Technical Solution:**

- Fuzzy search based on data available in table `person` for the selected branch
- Country/ZIP/City combination validation via pairs in table `ort`
- Storing of contact/address data in table `pers` (directly via INSERT or optionally via schema `pPers`)

**Constraints:**

- Data in `person` is only as up to date as the latest manual import (no auto-import available, ownership of manual imports lies with CAL)
- Data in `ort` is only as up to date as the latest manual import (no auto-import available, ownership of manual imports lies with CAL)
- No TMS business logic is used to write into the `pers` record of the transport order. Instead a new wrapper function will write directly into `pers` and create the relationship to the tour point via `RES_HST_ZUS (typ=999, key='PERS_TIX')` bypassing any effects on subsequent processes like invoicing.

### 4.7 Provide a Starting Time for Tour Calculation (**No P3 development/implementation**)
------------------------------------------------

**WHO**: As a dispatcher, I want the tour calculation to use the correct start time for the entire tour so that the tour does not start at a random time.

**Description**:

**Logic**:

- If a fixed Arrival Time is available on the first Tour Point (excluding type 4), use it
- Else use the Performance Date of the Transport Order
  - If Performance Date lacks time, default to 00:00:00
- This does explicitly leave the first tour point's `fixedArrivalTime` available for being set by the Dispatcher
  - Result: the first tour point's `fixedArrivalTime` is not misused for the start of the tour property.

**Actors**: Dispatcher

**Triggers**: Tour calculation initiated.

**Preconditions**: Transport order exists with tour points. Transport orders without tour points cannot be calculated.

**Postconditions**: Tour start time set per logic; calculation runs with correct start.

**Technical Solution:**

CAL will implement the following behaviour:
- The TMS Database function `pDIS_TransportOrder.GetXServerDto` will set the start time of the tour by writing into the `PoolDTO`.
- The start time value will be determined by the following logic:
  - If a `fixedArrivalTime` on the first tour point is set, it is used as the start time.
    - The `performanceDate` value of the Transport Order is **not** used as the value for the start time.
  - Else the `performanceDate` of the Transport Order is used as the value for the start time.
- The target property in the `PoolDTO` which will contain the start time value is the property `Location.OpeningIntervals` of the first `Location`.
  - The first `Location` will be identified with the following path: `Plans[0].Tours[0].TourElements[0].LocationId`.

**Constraints:**

- The tour calculation component chain consisting of TMS's functions for getting the `PoolDTO` which is passed to CAL's TOP Service and then triggers a calculation on PTV's on-prem hosted xServer must
  - A) be capable of consuming fixed times and start time without performance regressions and
  - B) cover the business logic to support the Start Time for a Tour and the fixed Arrival and/or Departure times of tour points

# Non-Functional Requirements

## Ownership and Responsibility

**P3** holds responsibility for the non-functional requirements of the **New Dispo Architecture and Infrastructure**, specifically covering the following components within the defined feature scope:

- New Dispo Frontend
- New Dispo Backend
- TMS Bridge
- Google Secret Manager
- Keycloak

**CAL** holds responsibility for the non-functional requirements of the **TMS Architecture and Infrastructure**, specifically covering the following components within the defined feature scope:

- TMS branch database core schema (including core schema, tables, functions, procedures, and views)
- TOP .NET project including the TOP REST service
- Network configuration between on-premise environments and GCP workloads

## Performance Requirements

- **Fuzzy Search Request Handling:** A client-side input throttling mechanism must be applied to fuzzy search operations, introducing a minimum delay of **500 ms** before the backend search API is invoked.
- **Fuzzy Search Response Time – Contact Data:** Fuzzy search requests related to Contractor, Carrier, and Tour Point contact datasets must return results within a maximum of **1,000 ms** under normal operating conditions.
- **Fuzzy Search Response Time – Location Data:** Fuzzy search requests related to Country, ZIP, and City validation datasets must return results within a maximum of **1,000 ms** under normal operating conditions.
- **End-to-End Request Latency (New Dispo → TMS):** Any user interaction initiated in the New Dispo Frontend that triggers a TMS database query must reach the TMS database within **1,000 ms** (network transit and service invocation included).

For any other use case/feature, it is not possible to define holistic performance requirements due to the dependency on TMS Database performance.

## 6. Project Boundaries & Collaboration Guidelines

### Ownership & Concept Stability
Each party owns and is responsible for their components. Any conceptual changes beyond this document require separate agreement and estimation.

### Deliverable Scope
P3's offer is based on the current concept agreement. Deliverables are bound to the defined interfaces. Project success is measured by P3 delivering agreed functionality, independent of whether CAL fulfills all prerequisites.

### Rollout Responsibilities
P3 delivers source code to:
- P3 Azure DevOps repositories
- CAL's GitHub TMS repository (database objects as create-scripts embedded in build-scripts)

Database object deployment to ABN, UAT, or PROD environments is outside this project scope. P3 is happy to support deployment activities under a separate purchase order.

### Cloud & Network Configuration
P3 scope includes:
- GCP workload deployments for all New Dispo assets, including new provisionings (e.g. Redis cache)

Not in P3 scope:
- GCP network configuration (e.g. between workloads) → CAL/Nagel managed service partners
- On-premise connectivity → CAL/Nagel IT