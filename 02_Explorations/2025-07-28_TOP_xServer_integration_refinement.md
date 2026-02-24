# 2025-07-28 Team Refinement

## xServer Integration

### Summary

The xServer integration into New Dispo is a pure "glue together" solution in iteration 1 (November deadline). Meaning we don't actually introduce any new business logic. We just "plug together" existing components with new components.

> The main goal of this iteration 1 integration is not lean architecture but rather feature delivery within the time scope.

### xServer

Services Overview:
http://10.32.3.102:30000/dashboard/Content/Administration/Services.htm

> Requires open Nagel VPN connection

OpenAPI:

`swagger.json` taken from: `http://10.32.3.102:30000/services/openapi/2.26/swagger.json`

Request Runner:
There is a playground to run API calls: http://10.32.3.102:30000/dashboard/Content/Administration/RawRequestRunner.htm

### "TOP" Project

TOP = **To**ur **Op**timization

A .Net 4.5 project by CAL that integrates the TMS with the xServer via a central `PoolDTO`.

The `PoolDTO` is an (generic) entity defined by CAL to cover all kinds of Transport Order tour calculation and optimisation use cases.

The `PoolDTO` is delivered by the TMS Database via `pTop_LoadingList.get()`.
The `PoolDTO` is accepted by the TMS Database via `pTop_LoadingList.get()`.

> All mapping and business logic resides in the TMS Database and the TOP project and will be re-used !

Relevant `.cs` project:
![image.png](https://dev.azure.com/p3ds/4912016f-16d3-40db-a383-c6ac3d76971c/_apis/wiki/wikis/1d9090ed-6839-4b9e-86a3-a75f9430a619/pages/13493/comments/attachments/4c409ea8-9eca-485d-a4d4-77dae9961a47)

Dependencies:
@<Matthias Max (PARTNER)> Add Dep Visual

Code (Nagel account needed):
https://dev.azure.com/caldevops/Agile/_git/CALtms?path=/3GL/CALConsult.TOP

Further resources:
[Code Analysis by Matthias (with AI)](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/13731/xServer-Integration-with-TMS)

### PoolDTO

#### Preparation (Get `FRK_TIX`)

We first need to retrieve the `FRK_TIX`.

```sql
SELECT
	FRK_TIX,
	LFD_N, -- IST IMMER 1 (MITTLERWEILE = BORDERO HAT NUR EINEN UNTERNEHMER NEUERDINGS)
	TA_TIX -- VERBINDUNG ZUM TO, NULLS in TA_TIX sind Borderos , für die es noch keinen TO gibt (sollte in unseren Fälle nicht vorkommen)
FROM
	TMS1034.FRK_UNT
WHERE TA_TIX = ...
AND LFD_N = 1 -- hard-coded condition
LIMIT 10
```

Result:
![image.png](/.attachments/image-22f5a342-d827-4e83-9b16-76740968a7c7.png)

#### Discussion

- Idea: Wrap the SELECT for retrieving the FRK_TIX and calling the `pTop_LoadingList.get()` in one DB function - TBD @<Matthias Max (PARTNER)> 

#### Get Call

Now we can call the function.

Parameters:

- `sid`: `FRK_TIX`
- `dplanningdate`: 

Example:

```sql
--abn1034, NV, 24.07.2025, LL445803:
select ptop_loadinglistdto.get('10340429359153', trunc(localtimestamp));
```

Result (pgAdmin):
![image.png](/.attachments/image-99347530-b854-4d0f-aba8-5de8815a3702.png)

Result (JSON):

```json
{
    "Id": 10340429359153,
    "Info": 445803,
    "PlanningDate": "2025-03-26T00:00:00+01:00",
    "PlanningInterval": {
        "End": "2025-03-26T23:00:00",
        "Start": "2025-03-25T23:00:00"
    },
    "Configurations": [
        {
            "Id": "0",
            "Info": "Configuration 0",
            "Version": "2",
            "Url": "http://xserver2.nagel-group.local:30000",
            "CountryType": "LICENSEPLATE",
            "VehiclePalletSpaceOverloading": 1,
            "VehicleWeightOverloading": 1,
            "VehicleOvertimeFactor": 1,
            "VehicleLoadingFactor": 1,
            "MaximumOrderWeightForSmallVehicleDelivery": "200",
            "MaximumPalletSpacesForFreePlannedPickups": "2",
            "Countries": [
                "DE"
            ],
            "MatchLocationMinimumScore": 50,
            "RouteCalculationResultFields": [
                ""
            ],
            "CalculationMode": 4,
            "CustomCalculationModeConfigFile": "//CAL4010/cal/tms/tms.1034/CALConsult.TourOptimization.CustomCalcMode.cfg",
            "UseHighPerformanceRouting": true,
            "DistanceTimeWeighting": 50,
            "FeatureLayerThemes": [
                "PTV_TruckAttributes"
            ],
            "AddStartLocationToPlannedTour": true,
            "AddEndLocationToPlannedTour": true,
            "FerryPenalty": 2500,
            "RailPenalty": 2500,
            "CostPerKilometer": 1.2,
            "WorkingCostPerHour": 20.5,
            "Currency": "EUR",
            "BreakDuration": null,
            "BreakIntervalStartTime": 16200,
            "BreakIntervalEndTime": 24300,
            "UseDrivingTimeRegulation": false,
            "UseWorkungTimeDirective": false
        }
    ],
    "Locations": [
        {
            "Id": "10340430073544",
            "Type": 0,
            "PersonNumber": 99034,
            "PersonIndex": 0,
            "Name1": "NAGEL-GROUP LOGISTICS SE",
            "Street": "SCHWARZE BREITE 16",
            "Country": "DE",
            "PostalCode": "34260",
            "City": "KAUFUNGEN",
            "Longitude": 9.5735000000000000,
            "Latitude": 51.2846500000000000,
            "RequiredVehicleEquipment": [
                "10"
            ],
            "OpeningIntervals": null,
            "OpeningIntervalMatch": 3,
            "ServiceDuration": 600
        },
        {
            "Id": "10340430073545",
            "Type": 1,
            "PersonNumber": 560300606,
            "PersonIndex": 0,
            "Name1": "EDEKA NEUKAUF KORSCHAN KG",
            "Street": "BRUECKENHOFSTR. 94",
            "Country": "DE",
            "PostalCode": "34132",
            "City": "KASSEL",
            "Longitude": 9.4417200000000000,
            "Latitude": 51.2834700000000000,
            "RequiredVehicleEquipment": null,
            "OpeningIntervals": [
                {
                    "Start": "2025-03-26T06:59:00+01:00",
                    "End": "2025-03-26T16:01:00+01:00"
                }
            ],
            "OpeningIntervalMatch": 3,
            "ServiceDuration": 600
        },
        {
            "Id": "10340430073855",
            "Type": 1,
            "PersonNumber": 0,
            "PersonIndex": 0,
            "Name1": "FDU ( LAGER KVN ) KAUFUNGEN",
            "Street": "SCHWARZE BREITE 16",
            "Country": "DE",
            "PostalCode": "34260",
            "City": "KAUFUNGEN",
            "Longitude": 9.5735000000000000,
            "Latitude": 51.2846500000000000,
            "RequiredVehicleEquipment": [
                "11"
            ],
            "OpeningIntervals": [
                {
                    "Start": "2025-03-26T06:59:00+01:00",
                    "End": "2025-03-26T16:01:00+01:00"
                }
            ],
            "OpeningIntervalMatch": 3,
            "ServiceDuration": 600
        },
        {
            "Id": "10340430073859",
            "Type": 1,
            "PersonNumber": 0,
            "PersonIndex": 0,
            "Name1": "TANTE OLGA",
            "Street": "LANGE WIESE 21",
            "Country": "DE",
            "PostalCode": "34117",
            "City": "KASSEL",
            "Longitude": 9.4434000000000000,
            "Latitude": 51.3151700000000000,
            "RequiredVehicleEquipment": [
                "11"
            ],
            "OpeningIntervals": [
                {
                    "Start": "2025-03-26T06:59:00+01:00",
                    "End": "2025-03-26T16:01:00+01:00"
                }
            ],
            "OpeningIntervalMatch": 3,
            "ServiceDuration": 600
        },
        {
            "Id": "10340430079228",
            "Type": 1,
            "PersonNumber": 560300290,
            "PersonIndex": 0,
            "Name1": "EDEKA NEUKAUF PRANDZIOCH",
            "Street": "HARLESHAEUSER STRASSE 64",
            "Country": "DE",
            "PostalCode": "34130",
            "City": "KASSEL",
            "Longitude": 9.4441300000000000,
            "Latitude": 51.3264900000000000,
            "RequiredVehicleEquipment": null,
            "OpeningIntervals": [
                {
                    "Start": "2025-03-26T06:59:00+01:00",
                    "End": "2025-03-26T16:01:00+01:00"
                }
            ],
            "OpeningIntervalMatch": 3,
            "ServiceDuration": 600
        }
    ],
    "Orders": [
        {
            "Id": "0",
            "Type": 1,
            "StartLocationId": "10340430073544",
            "EndLocationId": "10340430073859",
            "StartServiceDuration": 270,
            "EndServiceDuration": 270,
            "ProductGroupsQuantities": [
                {
                    "Id": "Fresh",
                    "Weight": 500.000,
                    "PalletSpaces": 2.000,
                    "VolumePalletSpaces": 0,
                    "FloorPalletSpaces": 0
                },
                {
                    "Id": "All",
                    "Weight": 500.000,
                    "PalletSpaces": 2.000,
                    "VolumePalletSpaces": 0.000,
                    "FloorPalletSpaces": 0.000
                }
            ],
            "Priority": 4
        },
        {
            "Id": "1",
            "Type": 1,
            "StartLocationId": "10340430073544",
            "EndLocationId": "10340430073545",
            "StartServiceDuration": 637,
            "EndServiceDuration": 637,
            "ProductGroupsQuantities": [
                {
                    "Id": "Fresh",
                    "Weight": 120.000,
                    "PalletSpaces": 5.25,
                    "VolumePalletSpaces": 5.25,
                    "FloorPalletSpaces": 1.00
                },
                {
                    "Id": "All",
                    "Weight": 120.000,
                    "PalletSpaces": 5.250,
                    "VolumePalletSpaces": 5.250,
                    "FloorPalletSpaces": 1.000
                }
            ],
            "Priority": 4
        },
        {
            "Id": "2",
            "Type": 1,
            "StartLocationId": "10340430073544",
            "EndLocationId": "10340430079228",
            "StartServiceDuration": 22,
            "EndServiceDuration": 22,
            "ProductGroupsQuantities": [
                {
                    "Id": "Fresh",
                    "Weight": 0.000,
                    "PalletSpaces": 0.021,
                    "VolumePalletSpaces": 0,
                    "FloorPalletSpaces": 0
                },
                {
                    "Id": "All",
                    "Weight": 0.000,
                    "PalletSpaces": 0.021,
                    "VolumePalletSpaces": 0.000,
                    "FloorPalletSpaces": 0.000
                }
            ],
            "Priority": 4
        },
        {
            "Id": "3",
            "Type": 1,
            "StartLocationId": "10340430073544",
            "EndLocationId": "10340430073855",
            "StartServiceDuration": 641,
            "EndServiceDuration": 641,
            "ProductGroupsQuantities": [
                {
                    "Id": "Fresh",
                    "Weight": 365.035,
                    "PalletSpaces": 4.00,
                    "VolumePalletSpaces": 4.00,
                    "FloorPalletSpaces": 0
                },
                {
                    "Id": "All",
                    "Weight": 365.035,
                    "PalletSpaces": 4.000,
                    "VolumePalletSpaces": 4.000,
                    "FloorPalletSpaces": 0.000
                }
            ],
            "Priority": 4
        }
    ],
    "Vehicles": [
        {
            "Id": "0",
            "Info": "1301/GT-NG 5834",
            "VehicleProfile": "6-nagel-top-euro6-11.99t",
            "ProductGroupQuantityScenarios": [
                [
                    {
                        "Id": "Frozen",
                        "Weight": 6680.000,
                        "PalletSpaces": 15.00,
                        "VolumePalletSpaces": 15.00,
                        "FloorPalletSpaces": 15.00
                    },
                    {
                        "Id": "Fresh",
                        "Weight": 6680.000,
                        "PalletSpaces": 15.00,
                        "VolumePalletSpaces": 15.00,
                        "FloorPalletSpaces": 15.00
                    },
                    {
                        "Id": "All",
                        "Weight": 6680.000,
                        "PalletSpaces": 15.00,
                        "VolumePalletSpaces": 15.00,
                        "FloorPalletSpaces": 15.00
                    }
                ]
            ],
            "VehicleEquipment": [
                "6",
                "7",
                "10",
                "11",
                "51"
            ],
            "StartLocationId": "",
            "EndLocationId": "",
            "LoadingDuration": 2700,
            "UnloadingDuration": 2700,
            "StartTime": "1900-01-01T05:30:00+01:00",
            "MaximumStartDelay": 900,
            "EndTime": null,
            "MaximumTourDuration": 36000,
            "Preloaded": false,
            "PlannableForPickup": true,
            "LoadingTimeFactor": 1
        }
    ],
    "Plans": [
        {
            "Id": "0",
            "ConfigurationId": "0",
            "Tours": [
                {
                    "Id": "10340429359153",
                    "Info": "445803",
                    "LoadingListInfo": "445803",
                    "VehicleId": "0",
                    "TourElements": [
                        {
                            "Id": "10340430073544",
                            "Type": 0,
                            "ExtendedType": 0,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "LocationId": "10340430073544"
                        },
                        {
                            "Id": "10340430073544.10340430073545",
                            "Type": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "Distance": 0,
                            "Duration": 0,
                            "DrivingDuration": "0",
                            "BreakDuration": 0,
                            "StartTourPointId": 10340430073544,
                            "EndTourPointId": 10340430073545
                        },
                        {
                            "Id": "10340430073545",
                            "Type": 0,
                            "ExtendedType": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "LocationId": "10340430073545"
                        },
                        {
                            "Id": "10340430073545.10340430073855",
                            "Type": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "Distance": 0,
                            "Duration": 0,
                            "DrivingDuration": "0",
                            "BreakDuration": 0,
                            "StartTourPointId": 10340430073545,
                            "EndTourPointId": 10340430073855
                        },
                        {
                            "Id": "10340430073855",
                            "Type": 0,
                            "ExtendedType": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "LocationId": "10340430073855"
                        },
                        {
                            "Id": "10340430073855.10340430073859",
                            "Type": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "Distance": 0,
                            "Duration": 0,
                            "DrivingDuration": "0",
                            "BreakDuration": 0,
                            "StartTourPointId": 10340430073855,
                            "EndTourPointId": 10340430073859
                        },
                        {
                            "Id": "10340430073859",
                            "Type": 0,
                            "ExtendedType": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "LocationId": "10340430073859"
                        },
                        {
                            "Id": "10340430073859.10340430079228",
                            "Type": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "Distance": 0,
                            "Duration": 0,
                            "DrivingDuration": "0",
                            "BreakDuration": 0,
                            "StartTourPointId": 10340430073859,
                            "EndTourPointId": 10340430079228
                        },
                        {
                            "Id": "10340430079228",
                            "Type": 0,
                            "ExtendedType": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "LocationId": "10340430079228"
                        },
                        {
                            "Id": "10340430079228.10340430092476",
                            "Type": 1,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "Distance": 0,
                            "Duration": 0,
                            "DrivingDuration": "0",
                            "BreakDuration": 0,
                            "StartTourPointId": 10340430079228,
                            "EndTourPointId": 10340430092476
                        },
                        {
                            "Id": "10340430092476",
                            "Type": 0,
                            "ExtendedType": 2,
                            "StartTime": "1900-01-01T00:00:00+01:00",
                            "EndTime": "1900-01-01T00:00:00+01:00",
                            "LocationId": "10340430073544"
                        }
                    ]
                }
            ]
        }
    ]
}
```

[pTop.get.json](/.attachments/pTop.get-8a470765-898c-43ae-a3ab-94029cc3a6e8.json)

### Flow

![image.png](/.attachments/image-d858bf81-847d-4cc4-ade4-138fb514cea7.png)

### Responsibility of P3

![image.png](/.attachments/image-3af54ad7-e949-4e5b-b59e-7f24abaa0023.png)

### How to use the TOP DLL

### Test Cases show how to integrate (Actual Code)

![image.png](https://dev.azure.com/p3ds/4912016f-16d3-40db-a383-c6ac3d76971c/_apis/wiki/wikis/1d9090ed-6839-4b9e-86a3-a75f9430a619/pages/13493/comments/attachments/dbcb475e-e8db-41f8-a85d-c465b7dde036)
Pfad: 3GL/CALConsult.TOP/Test/CALConsult.TOP.Test.XServer.JS/Program.cs

### Relevant changes to last refinement

- We know the exact usage of the existing DLL (aka .Net project)
- We know the exact function in the DLL to use
- We have an exact example code that does what we need to do. It's part of an automated test case.

### Options for integrating the TOP DLL

**Main pending technical decision:** How to integrate the DLL functionality

> Overall Goal: Enable P3 as much as possible and don't be dependent on CAL

#### Option 1: New cloud component to integrate TOP DLL

- It is written in .Net 4.5 based on Windows (?) (aka not compatible with our .Net Core tech stack?)
- Do we want this shared resource (shared with CAL) ?
  - Input from Joachim: yes, this is the way to go in iteration 1
  - How does the release process look like etc. and debugging
- **.Net expertise requried!**
  - Exploration required

#### Option 2: Integrate TOP DLL into New Dispo Backend

Same as Option 1. Just not as a separate new component.

#### Option 3: (Re-)Use existing REST web service from CAL

Host the existing REST () web service `CALConsult.TOP.Service` and add/fix/test the `CalculateRoute` functionality.

Todos:

- [ ] Check if the required `CalculateRoute` method of `xServer` project is exposed
- [ ] Discuss hosting options

Code:
https://dev.azure.com/caldevops/Agile/_git/CALtms?path=/3GL/CALConsult.TOP/CALConsult.TOP.Service

#### Discussion

- Option 1
  - Pros
    - Clean separation of concerns and domains, most future proof
  - Cons
    - Highest effort in total across all options
- Option 2
  - Pros
    - Lowest integration effort of all options
  - Cons
    - "Pollutes" New Dispo backend more and is not supporting a clean domain-split
    - Risk: use non-.Net core DLL in .Net core project => Will this work in deployment?
  - Details
    - Prepare it in a "modular monolith" kinda way to be able to extract it to a separate microservice easily later
- Option 3
  - Pros
    - Existing code, less effort to create new solution (compared to Option 1)
  - Cons
    - Legacy .Net had tendency to be error-prone

Questions affecting the decision:
  - Do other services / systems use this TOP interface now or later? @<Matthias Max (PARTNER)> 
    - Is now the right time to consider this looking at the timeline of November?

## DevOps Perspective

WIP ⚠️

- Prepare networking setup
- Prepare potential new cloud components
- Align on GCP workload preparation (without Qodea)

### Refinement Preparation Todos

- [x] Sequence Diagram @<Matthias Max (PARTNER)> 
- [ ] Test flow end 2 end with example to see result in `v_dis_to_tourpoint` @<Matthias Max (PARTNER)> or someone from the team (Sonja)
- [ ] Introduce team upfront to the refinement with the new learnings about the DLL entry point @<Matthias Max (PARTNER)> 

## Next Steps

- Exploration for the .Net exploration of all three options
  - #117518

## New Dispo Test Data generation (Transport Orders)

We are able to create Shipments with this endpoint:
`bla`

in this Swagger UI (VPN required):
`https://development-biztalk-to-oms-and-tms-branch.cal-consult.int/swagger/index.html`

![image.png](/.attachments/image-9cdd6148-9a57-47fd-8eac-b4735df193a8.png)

### DTO to create Shipments

```json
{
  "QueueTransmissionData": {
    "SourceEntityName": "V_ESB_CONSIGNMENT",
    "TargetEntityName": "KND_SEN",
    "Entity_Id": "89950",
    "EntityIdColumn": "CONSIGNMENT_ID",
    "DateQueued": "2025-07-29T14:38:00"
  },
  "KndSen": {
    "Firma": "10",
    "Nl": "34",
    "Sen_N": "443",
    "C_Time": "2025-07-11T11:37:16",
    "C_User": "",
    "U_Time": "2025-07-28T17:38:03",
    "U_User": "",
    "Abs_Ref_K": "443",
    "Vk_Strom": "3",
    "Lst_D": "2025-07-11T00:00:00",
    "Emp_Rel": "60",
    "Fix_Bis_D": "2025-07-12T00:00:00",
    "Frank": "6",
    "Status_K": "3",
    "Prod_Grp": "01",
    "Consignment_Id": "89950",
    "Consignment_Statuscode": "42",
    "Quell_K": "s",
    "Fix_Key": "34",
    "Tran_Art": "01",
    "Sen_Art": "A",
    "Tran_K": "1",
    "U_Version": "!",
    "SelbstAbh_K": "0",
    "SelbstAnl_B": "0",
    "Dir_Angelad_B": "0",
    "Sort_K": "OMS-0000000000000000033823"
  },
  "KndSenLsRecords": {
    "KndSenLs": [
      {
        "Ls_N": "OMS0001",
        "U_Version": "!",
        "Ls_D": "2025-07-11T11:37:18",
        "Colli_C": "0",
        "Tats_Gew": "78",
        "Inh": "FEINKOST"
      },
      {
        "Ls_N": "OMS0002",
        "U_Version": "!",
        "Ls_D": "2025-07-11T07:37:18",
        "Colli_C": "0",
        "Tats_Gew": "78",
        "Inh": "FEINKOST"
      }
    ]
  },
  "KndSenPosRecords": {
    "KndSenPos": [
      {
        "Pos_N": "1",
        "Ve_C": "1",
        "Ve_Tk": "EUR",
        "Lhm_C": "20",
        "Lhm_Tk": "BOX",
        "Stellplatz_C": "6.5",
        "Gueterart": "00001",
        "Tats_Gew": "2578",
        "Frpf_Gew": "78",
        "Stueck_C": "40",
        "Zeichen_N": "4477888",
        "Inh": "SPEZIELLES",
        "U_Version": "!",
        "Bodenstpl_C": "1"
      },
      {
        "Pos_N": "2",
        "Lhm_C": "5",
        "Lhm_Tk": "EUR",
        "Stellplatz_C": "0",
        "Gueterart": "00002",
        "Tats_Gew": "1511",
        "Frpf_Gew": "22",
        "Stueck_C": "7",
        "Zeichen_N": "2244111",
        "Inh": "LECKERFOOD",
        "U_Version": "!"
      },
      {
        "Pos_N": "3",
        "Lhm_C": "40",
        "Lhm_Tk": "BOX",
        "Stellplatz_C": "0",
        "Gueterart": "00007",
        "Tats_Gew": "1531",
        "Frpf_Gew": "32",
        "Stueck_C": "100",
        "Zeichen_N": "3355566",
        "Inh": "DRINKS",
        "U_Version": "!"
      }
    ]
  },
  "KndSenPstRecords": {
    "KndSenPst": [
      {
        "Pst_N": "357200389300707189",
        "Pst_Ebene": "E",
        "U_Version": "!"
      },
      {
        "Pst_N": "357200389300707196",
        "Pst_Ebene": "E",
        "U_Version": "!"
      },
      {
        "Pst_N": "357200389300707202",
        "Pst_Ebene": "E",
        "U_Version": "!"
      }
    ]
  },
  "KndSenRefRecords": {
    "KndSenRef": [
      {
        "Typ": "OMS_ID",
        "Ref": "89950",
        "Art": "I",
        "U_Version": "!"
      },
      {
        "Typ": "IFTMIN-BGM",
        "Ref": "1502361",
        "Art": "I",
        "U_Version": "!"
      },
      {
        "Typ": "LIEFNR",
        "Ref": "1502361",
        "Art": "I",
        "U_Version": "!"
      }
    ]
  },
  "KndSenTbRecords": {
    "KndSenTb": [
      {
        "Pers_N": "787878",
        "Pers_I": "0",
        "Pers_Tb": "ABS",
        "Name1": "TEST D34",
        "Str": "HASELWEG 5",
        "Sitz_Land": "D",
        "Sitz_Plz": "34233",
        "Sitz_Ort": "FULDATAL",
        "Sitz_Bez": "ROTHWESTEN",
        "Ber_Land": "D",
        "Ber_Plz": "34233",
        "Ber_Ort": "FULDATAL",
        "Ber_Bez": "ROTHWESTEN",
        "U_Version": "!"
      },
      {
        "Pers_N": "0",
        "Pers_I": "0",
        "Pers_Tb": "EMP",
        "Name1": "THORSTENS SHOPPING MALL",
        "Str": "BERLINER STRASSE 45",
        "Sitz_Land": "D",
        "Sitz_Plz": "61118",
        "Sitz_Ort": "BAD VILBEL",
        "Ber_Land": "D",
        "Ber_Plz": "61118",
        "Ber_Ort": "BAD VILBEL",
        "U_Version": "!"
      }
    ]
  },
  "KndSenLsRefRecords": {
    "KndSenLsRef": [
      {
        "Ls_N": "OMS0002",
        "Typ": "AUF",
        "Ref": "TEST2AUFT066LS",
        "Art": "E",
        "U_Version": "!"
      },
      {
        "Ls_N": "OMS0002",
        "Typ": "BES",
        "Ref": "TEST2BESTEL654",
        "Art": "E",
        "U_Version": "!"
      }
    ]
  },
  "KndSenTRecords": {
    "KndSenT": [
      {
        "Lfd_N": "1",
        "U_Version": "!",
        "Typ": "M",
        "T": "SYSTEMTEST OMS"
      }
    ]
  },
  "KndSenPosTRecords": null,
  "KndSenLsPstRecords": null,
  "KndSenFRecords": null,
  "KndSenZusRecords": {
    "KndSenZus": [
      {
        "U_Version": "!",
        "Id": "ABL_SCAN_ANW_K",
        "Wert": "1"
      },
      {
        "U_Version": "!",
        "Id": "SA_ANGELADEN"
      }
    ]
  },
  "KndSoFuRecords": null
}
```

#### Notes
This triggers the creation of the shipment from OMS on `ent1034`. You must enter 1034 as branch, otherwise it will end up in Oracle.

`Entity_Id` corresponds to the `Consignment_Id` of OMS.

If the same `Entity_Id` is transferred again, then `DateQueued` must be newer than the last time it was transferred.

### Test Run Results

Body:
```json
{ "id": "89950", "changeType": null, "sourceType": "Consignment", "status": 0, "errorMessage": null }
```

Response Headers:
```
content-length: 90
content-type: application/json; charset=utf-8 
date: Tue,29 Jul 2025 12:20:06 GMT
server: Microsoft-IIS/10.0 x-powered-by: ASP.NET
```