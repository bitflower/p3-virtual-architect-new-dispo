# User Story 103821: Sendung.Quell_K and Sen_Ref.Typ=OMS_ID

**Date:** 2026-02-25
**Status:** Exploration
**Related User Story:** 103821

---

## Original User Input

> Von Joachim: User Story 103821: Sendung.Quell_K=s und Sen_Ref.Typ=OMS_ID
> Sorry, das war nicht ganz korrekt. Quell_K für OMS-Sendungen kann jeder Kleinbuchstabe oder O sein.

**Translation:**
> Sorry, that wasn't quite correct. Quell_K for OMS shipments can be any lowercase letter or O.

---

## Summary

This exploration investigates how to retrieve the **OMS_ID** for OMS shipments and display it in the New Dispo Frontend, specifically in the Drive Instructions drawer next to the shipment number.

## Entity Relationships

**TMS Database Entities (AlloyDB):**
- **SENDUNG** (Shipment) - has `SENDUNG_TIX` (ID), `SENDUNG_N` (Number), `QUELL_K` (Source Key)
- **SEN_REF** - stores references for shipments, including `TYP='OMS_ID'` → `REF` (the OMS ID value)
- **Transport Order** - corresponds to `SENDUNG` with `SENDUNGSART='S'`

**Backend Entities (Backend Database):**
- **Lot** (Partie) - has `LotNumber` - groups multiple Legs for dispatch planning (Backend-only entity, NOT in TMS)
- **LotAssignment** - has `Number` - when a Lot is assigned to a Transport Order
- **Leg** - represents a Sendung from TMS:
  - `ShipmentId` (long) - references TMS `SENDUNG.SENDUNG_TIX`
  - `ShipmentNumber` (long?) - the `SENDUNG.SENDUNG_N` from TMS
  - **Required:** Add `OmsId` (long?) field

**Screenshot Analysis:**
- **Partie Nr. 12345604** = Lot Number (Backend: `LotEntity.LotNumber`)
- **Sdg.-Nr. 604905** = Shipment Number (TMS: `SENDUNG.SENDUNG_N`, Backend: `LegEntity.ShipmentNumber`)
- **D10 badge** = Destination Branch (Backend: `LegEntity.ConsigneeServiceArea`)

## Objective

**Make OMS_ID available in the Frontend** by implementing changes across all layers:
1. **TMS Database:** Expose OMS_ID in views queried by TMS Bridge
2. **TMS Bridge:** Add OMS_ID to GraphQL schema
3. **Backend:** Add OMS_ID to DTOs and entities
4. **Frontend:** Display OMS_ID in Drive Instructions drawer

**Performance Constraint:** The OMS_ID lookup must not degrade query performance, especially the `sen_ref` table join.

## Verified End-to-End Data Flow

### Flow for Displaying OMS_ID in Drive Instructions Drawer

```
USER: Opens Drive Instructions for Transport Order #12345
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. FRONTEND (Disposition-Frontend)                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ drive-instructions-drawer.service.ts                     │  │
│  │ • executeGetTourPoints(transportOrderId)                 │  │
│  │ • GET /api/pickup-drive-instructions?transportOrderId=X  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                         │ HTTP GET
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. BACKEND API (Disposition-Backend)                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ PickupDriveInstructionsController                        │  │
│  │ • GET /api/pickup-drive-instructions                     │  │
│  │ • Returns DriveInstructionsTourPointCardDto[]            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │                                       │
│                         ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ GetDriveInstructionsQueryHandler                         │  │
│  │ • Queries Backend DB: _appDbContext.LotAssignments       │  │
│  │   - Gets LotAssignmentEntity with LegLinks               │  │
│  │   - Reads LegEntity (has ShipmentNumber ✅)              │  │
│  │   - Builds DriveInstructionsLegCardDto ❌ NO OMS_ID     │  │
│  │ • Also calls TMS Bridge for tour points                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │                                       │
│                         │ (LegEntity was populated earlier via) │
│                         │                                       │
│                         ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ PickupPlanningShipmentProvider (initial data load)       │  │
│  │ • GetAllUnplanned(branchKey)                             │  │
│  │ • GraphQL query to TMS Bridge: "shipments"               │  │
│  │ • Populates LegEntity in Backend DB                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                         │ GraphQL Query
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. TMS BRIDGE (Disposition-Abstraction-Layer)                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ GraphQL API                                              │  │
│  │ query {                                                  │  │
│  │   shipments(databaseIdentifier: "branch_key") {          │  │
│  │     shipmentId                                           │  │
│  │     shipmentNumber  ✅                                   │  │
│  │     omsId           ❌ MISSING                           │  │
│  │     ... other fields                                     │  │
│  │   }                                                      │  │
│  │ }                                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                         │ SQL Query
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. TMS DATABASE (AlloyDB)                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Tables:                                                  │  │
│  │  SENDUNG (SENDUNG_TIX, SENDUNG_N, QUELL_K)              │  │
│  │  SEN_REF (SEN_TIX, TYP='OMS_ID', REF=<OMS_ID_value>)    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │                                       │
│                         ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ View queried by TMS Bridge (needs identification)        │  │
│  │ • Must include LEFT JOIN to sen_ref                      │  │
│  │ • Must SELECT oms_id field                               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Critical Insight

**The shipment data (including ShipmentNumber) displayed in the Drive Instructions drawer comes from the Backend Database (`LegEntity`), NOT directly from TMS.**

**Data Flow Timeline:**
1. **Initial Load** (when shipments become unplanned):
   - `PickupPlanningShipmentProvider` queries TMS Bridge GraphQL `shipments` query
   - This populates `LegEntity` in Backend database
   - **This is where OMS_ID must be captured**

2. **Display in UI** (when user opens Drive Instructions):
   - Frontend calls Backend `/api/pickup-drive-instructions`
   - Backend reads from its own `LegEntity` table
   - Returns `DriveInstructionsLegCardDto` with `ShipmentNumber` (and soon `OmsId`)

**Therefore:**
- The TMS Bridge GraphQL `shipments` query MUST include `omsId` field
- The TMS database view queried by this GraphQL schema MUST include OMS_ID
- The Backend `LegEntity` must store `OmsId` when populated from TMS
- The Backend `DriveInstructionsLegCardDto` must include `OmsId` when returned to Frontend

## OMS Shipment Identification

**Quell_K (Source Key) Criteria:**
- Any lowercase letter (a-z), OR
- Uppercase 'O'

**Sendungsart (Shipment Type):**
- 'A' (Avis/Notification)
- 'N' (Normal shipment)
- 'T' (Grobavis/Rough notification)
- 'S' (Sammelgut/Groupage - for New Dispo views)

## TMS Bridge (GraphQL Layer)

**Component:** Disposition-Abstraction-Layer (TMS Bridge)
**Purpose:** Provides GraphQL API over TMS database views

### Verified GraphQL Query Used

The Backend retrieves shipment data via the **`shipments` GraphQL query**:

**Caller:** `PickupPlanningShipmentProvider.GetAllUnplanned()`
**File:** `Code/Disposition-Backend/.../ShipmentProvider/PickupPlanningShipmentProvider.cs`

```csharp
var query = $@"query {{
    shipments(
        databaseIdentifier: ""{branchKey}"",
        where: {{ dispatchStatus: {{ eq: ""F"" }} }}  // F = Freigegeben (Released/Unplanned)
    )
    {{
       shipmentId
       shipmentNumber
       omsId            // ❌ MISSING - needs to be added
       company
       branch
       // ... ~40 other fields (weight, dates, addresses, etc.)
    }}
}}";
```

**When This Query Runs:**
- Triggered when shipments become unplanned (dispatchStatus = 'F')
- Populates Backend `LegEntity` table with shipment data
- This is the **ONLY** time shipment data flows from TMS to Backend

**Required Changes in TMS Bridge:**
1. **Identify which TMS database view** the `shipments` GraphQL type queries
2. Add `omsId` field to GraphQL `Shipment` type definition
3. Add LEFT JOIN to `sen_ref` in the underlying TMS database view
4. Map `oms_id` column from database view to GraphQL `omsId` field

## TMS Database Views

### Critical: Identify View Used by TMS Bridge

**Action Required:** Find which TMS database view backs the GraphQL `shipments` query in the TMS Bridge.

**Steps:**
1. Search TMS Bridge codebase (`Code/Disposition-Abstraction-Layer/`) for:
   - GraphQL schema definition of `Shipment` type
   - Resolver or data source configuration
   - SQL view name or query

2. Once identified, verify the view structure:
   - Does it already include `quell_k`? ✓ (probably yes, as Backend has origin data)
   - Does it include joins needed for shipment details? ✓ (yes, it returns ~40 fields)
   - Does it join to `sen_ref`? ❌ (probably no)

### Example: V_DIS_TRANSPORTORDER (for reference)

**File:** `Code/tms-alloydb-schema/src/sql/view/V_DIS_TRANSPORTORDER.sql`

**Note:** This view is for Transport Orders, NOT individual shipments. The TMS Bridge likely uses a different view for the `shipments` GraphQL query.

**However, this shows the pattern to follow:**

```sql
-- Current (line 84-100):
from sendung s1
  left join relation rel on ...
  left join region reg on ...
  left join sen_frk_unt u on ...

-- Required addition:
  left join sen_ref sr on (sr.sen_tix = s1.sendung_tix and sr.typ = 'OMS_ID')

-- Add to SELECT:
sr.ref::numeric(22) as oms_id
```

**Performance Considerations:**
1. **Index Check:** Verify `sen_ref` has index on `(sen_tix, typ)` for efficient lookup
2. **LEFT JOIN Impact:** Since not all shipments have OMS_ID, LEFT JOIN is necessary
3. **Proven Pattern:** `V_ESB_SENDUNG` already uses this exact pattern successfully

## Database Schema

### SENDUNG Table
```sql
CREATE TABLE sendung (
    sendung_tix numeric(22,0) NOT NULL,
    ...
    quell_k character(1),  -- Line 160: Source key (single character)
    ...
);
```

### SEN_REF Table
```sql
CREATE TABLE sen_ref (
    sen_tix numeric(22,0) NOT NULL,
    typ character varying(16) NOT NULL,  -- Reference type (e.g., 'OMS_ID')
    ref character varying(144) NOT NULL, -- Reference value
    u_version character(1),
    c_time timestamp without time zone,
    c_user character(8),
    u_time timestamp without time zone,
    u_user character(8),
    art character(1)
);
```

## How OMS_ID is Retrieved - Reference Implementation

### V_ESB_SENDUNG View Pattern

**File:** `Code/tms-alloydb-schema/src/sql/view/V_ESB_SENDUNG.sql`

This view demonstrates the **established pattern** for retrieving OMS_ID:

```sql
create or replace view V_ESB_SENDUNG
as
  select s.SENDUNG_TIX     SEN_TIX,
         r.REF :: numeric(22) OMS_ID,  -- ⚠️ Key retrieval pattern
         s.VERKEHRSSTROM   VK_STROM
    from SENDUNG s
    left join SEN_REF r on (r.SEN_TIX = s.SENDUNG_TIX and r.TYP = 'OMS_ID')  -- ⚠️ Simple LEFT JOIN
   where s.SENDUNGSART in ('A','N','T')
     and (s.QUELL_K between 'a' and 'z' or s.QUELL_K = 'O');
```

**Key Points:**
- Simple LEFT JOIN to `sen_ref` table
- Filter on `typ = 'OMS_ID'`
- Cast `ref` to `numeric(22)` for type safety
- LEFT JOIN ensures non-OMS shipments return NULL

**Performance:**
- ✅ Direct table join (no function calls)
- ✅ Can leverage indexes on `sen_ref(sen_tix, typ)`
- ✅ Already used in production ESB integration

### Performance Analysis

**Index Requirements:**
```sql
-- Check if this index exists on sen_ref:
CREATE INDEX idx_sen_ref_sen_tix_typ ON sen_ref(sen_tix, typ);
```

**Impact Assessment:**
1. **Best Case:** Index exists → sub-millisecond lookup per row
2. **Worst Case:** No index → table scan, significant performance degradation
3. **Cardinality:** Not all shipments have OMS_ID → LEFT JOIN mandatory

**Recommendation:** Use the V_ESB_SENDUNG pattern (direct LEFT JOIN) rather than creating a function wrapper, as it:
- Allows query optimizer to use indexes effectively
- Avoids function call overhead
- Makes dependencies explicit in the query plan

## Frontend Components (Where OMS_ID Should Appear)

### Screenshot Analysis
The OMS_ID needs to be displayed in the **Drive Instructions Slider** next to the shipment number (Sdg.-Nr.).

**File:** `02_Explorations/2026-02-25_User-Story-103821_OMS-Sendung-Quell-K/image.png`

Shows:
- **Partie Nr.** 12345604 (Transport Order Number) - displayed at top
- **Sdg.-Nr.** 604905 with **D10** badge (Shipment Number + Destination Branch)
- Company details, weight, VSP, BSP, date

### Component Hierarchy

```
transport-order-drive-instructions-dialog.component
└─ group-tour-point-list.component
   ├─ pickup-planning-transport-order-card (shows Transport Order info)
   └─ group-tour-point (shows tour points with Lot Assignment Numbers)
      └─ leg-tour-point.component (shows individual shipment details)
         ├─ shipmentNumber (line 9) ✅ Currently displayed
         ├─ D04 badge (line 12) ⚠️ Hardcoded, should be dynamic
         └─ OMS_ID ❌ MISSING - needs to be added here
```

### Key Frontend Files

**1. Leg Tour Point Component** (displays shipment details)
- **HTML:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/tour-point/leg-tour-point/leg-tour-point.component.html`
- **TypeScript:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/tour-point/leg-tour-point/leg-tour-point.component.ts`
- **Current:** Shows `shipmentNumber` (line 9)
- **Required:** Add `omsId` field display

**2. Data Model - LegTourPointConfig**
- **File:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/models/planningPageTypes.ts:432`
- **Current fields:**
  - `legId: string`
  - `shipmentNumber: number` (line 434)
  - `order, name, country, city, street, zipCode`
  - `weight, volumePalletSpaces, floorPalletSpaces`
  - `destinationCountry, consigneeServiceArea, serviceAreaIdentifier`
  - `infoChips: InfoLotChip[]`
- **Required:** Add `omsId?: number | null` field

**3. Data Model - LegResponseStructure**
- **File:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/models/planningPageTypes.ts:104`
- **Current fields:**
  - `shipmentId: number` (line 106)
  - `shipmentNumber: number` (line 132)
  - Traffic flow, product group, dates, destinations, weight, etc.
- **Required:** Add `omsId?: number | null` field

**4. Group Tour Point List Component**
- **File:** `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/components/transport-order-drive-instructions-dialog/tour-points-list/group-tour-point-list.component.html`
- **Purpose:** Displays the drive instructions drawer with tour points
- **Action:** Ensure OMS_ID data flows through to leg-tour-point component

### Frontend Implementation Tasks

1. **Add field to TypeScript models:**
   ```typescript
   // In LegTourPointConfig interface (line 432)
   export interface LegTourPointConfig {
     legId: string,
     shipmentNumber: number,
     omsId?: number | null,  // ✅ ADD THIS
     // ... rest of fields
   }

   // In LegResponseStructure interface (line 104)
   export interface LegResponseStructure {
     shipmentNumber: number;
     omsId?: number | null;  // ✅ ADD THIS
     // ... rest of fields
   }
   ```

2. **Update leg-tour-point.component.html:**
   ```html
   <div class="flex items-center gap-[2px] justify-between align-middle">
       <div class="flex justify-start items-center">
           <span class="legNumberLabel grey-label" i18n>Shipment number: </span>
           <span class="value ml-1">{{legTourPoint.shipmentNumber}}</span>

           <!-- ADD OMS_ID DISPLAY HERE -->
           @if(legTourPoint.omsId) {
               <span class="label grey-label ml-2" i18n>OMS ID: </span>
               <span class="value ml-1">{{legTourPoint.omsId}}</span>
           }

           <app-chip
               class="ml-2"
               [content]="legTourPoint.serviceAreaIdentifier || 'D04'"
               className="relative text-center mt-1 mb-1 mr-1 rounded-2xl overflow-hidden !flex text-xs final-branch"/>
       </div>
   ```

3. **Backend API must expose omsId:**
   - Ensure the Backend API endpoint returns `omsId` for each leg/shipment
   - Backend should query the enhanced `v_dis_transportorder` view (or related views) that includes the OMS_ID

## Implementation Checklist

### Layer 1: TMS Database (Code/tms-alloydb-schema)
- [ ] **CRITICAL FIRST STEP:** Identify which TMS database view backs the GraphQL `shipments` query
  - Search TMS Bridge codebase for GraphQL schema and resolver
  - Document the view name and current structure

- [ ] **Verify index:** Check if index exists on `sen_ref(sen_tix, typ)`
  ```sql
  SELECT * FROM pg_indexes WHERE tablename = 'sen_ref' AND indexdef LIKE '%sen_tix%typ%';
  ```

- [ ] **Update identified view:** Add OMS_ID
  ```sql
  -- Add this LEFT JOIN:
  left join sen_ref sr on (sr.sen_tix = s.sendung_tix and sr.typ = 'OMS_ID')

  -- Add this to SELECT clause:
  sr.ref::numeric(22) as oms_id
  ```

- [ ] **Test performance:** Run EXPLAIN ANALYZE on updated view
  ```sql
  EXPLAIN ANALYZE SELECT * FROM <identified_view> WHERE <typical_conditions>;
  ```

- [ ] **Deploy:** Apply database view changes (likely requires migration)

### Layer 2: TMS Bridge (Code/Disposition-Abstraction-Layer)
- [ ] **Identify GraphQL schema location** for `shipments` query
- [ ] **Add field to GraphQL type:**
  ```graphql
  type Shipment {
    shipmentId: Long!
    shipmentNumber: Long!
    omsId: Long  # ✅ ADD THIS
    # ... other fields
  }
  ```
- [ ] **Update resolvers** to map `oms_id` from database views
- [ ] **Test GraphQL query:**
  ```graphql
  query {
    shipments(databaseIdentifier: "branch_key") {
      shipmentId
      shipmentNumber
      omsId
    }
  }
  ```
- [ ] **Deploy:** TMS Bridge API

### Layer 3: Backend (Code/Disposition-Backend)
- [ ] **Update PickupPlanningShipmentDto:**
  ```csharp
  [JsonProperty("omsId")]
  public long? OmsId { get; set; }  // ✅ ADD THIS
  ```
  File: `CALConsult.Disposition.API/Application/_Shared/Services/ShipmentProvider/Dtos/PickupPlanningShipmentDto.cs`

- [ ] **Update LegEntity:**
  ```csharp
  public long? OmsId { get; set; }  // ✅ ADD THIS
  ```
  File: `CALConsult.Disposition.API/Domain/Entities/Leg/LegEntity.cs`

- [ ] **Update LegEntityConfiguration** to map database column
  File: `CALConsult.Disposition.API/Domain/Entities/Leg/LegEntityConfiguration.cs`

- [ ] **Create database migration** for `OmsId` column in `leg` table

- [ ] **Update LegResponseDto** and related DTOs to include `OmsId`

- [ ] **Update DriveInstructionsLegCardDto:**
  ```csharp
  public long? OmsId { get; set; }  // ✅ ADD THIS
  ```

- [ ] **Test Backend API:** Verify `/api/drive-instructions` returns `omsId`

- [ ] **Deploy:** Run migrations and deploy Backend API

### Layer 4: Frontend (Code/Disposition-Frontend)
- [ ] **Update LegResponseStructure:**
  ```typescript
  export interface LegResponseStructure {
    shipmentNumber: number;
    omsId?: number | null;  // ✅ ADD THIS
    // ... other fields
  }
  ```
  File: `apps/nagel-cal-disposition/src/models/planningPageTypes.ts:104`

- [ ] **Update LegTourPointConfig:**
  ```typescript
  export interface LegTourPointConfig {
    legId: string,
    shipmentNumber: number,
    omsId?: number | null,  // ✅ ADD THIS
    // ... other fields
  }
  ```
  File: `apps/nagel-cal-disposition/src/models/planningPageTypes.ts:432`

- [ ] **Update leg-tour-point.component.html:**
  ```html
  <div class="flex items-center gap-[2px] justify-between align-middle">
      <div class="flex justify-start items-center">
          <span class="legNumberLabel grey-label" i18n>Shipment number: </span>
          <span class="value ml-1">{{legTourPoint.shipmentNumber}}</span>

          @if(legTourPoint.omsId) {
              <span class="label grey-label ml-3" i18n>OMS ID: </span>
              <span class="value ml-1">{{legTourPoint.omsId}}</span>
          }

          <app-chip ... />
      </div>
  ```
  File: `apps/nagel-cal-disposition/src/app/components/tour-point/leg-tour-point/leg-tour-point.component.html`

- [ ] **Test Frontend:**
  - Open Drive Instructions drawer
  - Verify OMS_ID displays for OMS shipments
  - Verify non-OMS shipments don't show OMS_ID (null handling)

- [ ] **Deploy:** Frontend application

### Testing & Validation
- [ ] **End-to-end test:** Create/assign Lot with OMS shipments, verify OMS_ID appears in UI
- [ ] **Performance test:** Monitor query performance with OMS_ID joins
- [ ] **Cross-reference test:** Verify OMS_ID values match between TMS and OMS systems

## Related Files by Layer

### Layer 1: TMS Database (Code/tms-alloydb-schema)
**Tables:**
- `src/sql/table/sendung.sql` - Main shipment table (has `quell_k`)
- `src/sql/table/sen_ref.sql` - Shipment references table (stores OMS_ID)

**Views (need to identify which views TMS Bridge queries):**
- `src/sql/view/V_DIS_TRANSPORTORDER.sql` - Main New Dispo view (Transport Orders)
- `src/sql/view/v_dis_transportorder_filter.sql`
- Other shipment views queried by TMS Bridge (need to identify)

**Reference Implementation:**
- `src/sql/view/V_ESB_SENDUNG.sql` - Shows OMS_ID retrieval pattern with LEFT JOIN

### Layer 2: TMS Bridge (Code/Disposition-Abstraction-Layer)
**GraphQL Schema:**
- GraphQL type definitions for `Shipment` (need to locate)
- GraphQL resolvers for `shipments` query (need to locate)

### Layer 3: Backend (Code/Disposition-Backend)
**DTOs:**
- `CALConsult.Disposition.API/Application/_Shared/Services/ShipmentProvider/Dtos/PickupPlanningShipmentDto.cs`
- `CALConsult.Disposition.API/Application/Features/PickupPlanningView/Requests/GetLotsAndLegs/Dtos/LegResponseDto.cs`
- `CALConsult.Disposition.API/Application/Features/PickupDriveInstructions/Requests/GetDriveInstructions/Dtos/DriveInstructionsLegCardDto.cs`

**Entities:**
- `CALConsult.Disposition.API/Domain/Entities/Leg/LegEntity.cs`
- `CALConsult.Disposition.API/Domain/Entities/Leg/LegEntityConfiguration.cs`

**Services:**
- `CALConsult.Disposition.API/Application/_Shared/Services/ShipmentProvider/PickupPlanningShipmentProvider.cs`

### Layer 4: Frontend (Code/Disposition-Frontend)
**Type Definitions:**
- `apps/nagel-cal-disposition/src/models/planningPageTypes.ts`
  - `LegResponseStructure` interface (line 104)
  - `LegTourPointConfig` interface (line 432)

**Components:**
- `apps/nagel-cal-disposition/src/app/components/tour-point/leg-tour-point/leg-tour-point.component.html`
- `apps/nagel-cal-disposition/src/app/components/tour-point/leg-tour-point/leg-tour-point.component.ts`
- `apps/nagel-cal-disposition/src/app/components/transport-order-drive-instructions-dialog/tour-points-list/group-tour-point-list.component.html`

## Next Steps

### Phase 1: Discovery (TMS Bridge Architecture)
1. **CRITICAL:** Identify which TMS database view the TMS Bridge `shipments` GraphQL query uses
   - Search TMS Bridge codebase for GraphQL schema definition of `Shipment` type
   - Find the SQL view or query that backs this GraphQL type
   - Document the current view structure and fields

2. **Verify Index:** Check if `sen_ref` table has index on `(sen_tix, typ)` for performance

### Phase 2: Database Layer
3. **Add OMS_ID to identified TMS view:**
   ```sql
   left join sen_ref sr on (sr.sen_tix = s.sendung_tix and sr.typ = 'OMS_ID')
   -- Add to SELECT: sr.ref::numeric(22) as oms_id
   ```
4. **Test Performance:** Use EXPLAIN ANALYZE to verify no performance degradation

### Phase 3: Implementation
5. **TMS Bridge:** Add `omsId` field to GraphQL schema
6. **Backend:** Add `OmsId` to DTOs, entities, and database migrations
7. **Frontend:** Add `omsId` to interfaces and display in UI
8. **End-to-End Test:** Verify OMS_ID appears in Drive Instructions drawer

---

## Verified Architecture Summary

### ✅ Confirmed Data Flow

**Frontend Call:**
```typescript
// File: drive-instructions-drawer.service.ts:70
GET /api/pickup-drive-instructions?transportOrderId=12345
Returns: TourPointConfig[] with nested LegTourPointConfig[]
```

**Backend Endpoint:**
```csharp
// File: PickupDriveInstructionsController.cs:43
[HttpGet]
public async Task<JsonResult> GetDriveInstructions([FromQuery] long transportOrderId)
// Returns: DriveInstructionsTourPointCardDto[] with nested DriveInstructionsLegCardDto
```

**Backend Data Source:**
```csharp
// File: GetDriveInstructionsQueryHandler.cs:35-39
// Reads from Backend database: _appDbContext.LotAssignments
// Which includes LegEntity (populated earlier from TMS via GraphQL)
```

**Initial Data Load:**
```csharp
// File: PickupPlanningShipmentProvider.cs:39-47
// GraphQL query to TMS Bridge:
query {
  shipments(
    databaseIdentifier: "branch_key",
    where: { dispatchStatus: { eq: "F" } }  // Unplanned shipments
  ) {
    shipmentId
    shipmentNumber  ✅ Currently included
    omsId           ❌ MISSING
    // ~40 other fields
  }
}
```

### ❓ Critical Unknown

**Which TMS database view backs the GraphQL `shipments` query?**

This must be identified in the TMS Bridge (`Code/Disposition-Abstraction-Layer/`) before implementation can proceed.

---

## Background Context

### OMS Integration via ESB

OMS shipments are integrated with TMS and changes are synchronized back to OMS via ESB (Enterprise Service Bus).

**Trigger: TRAIU_SENDUNG_ESB**

**File:** `Code/tms-alloydb-schema/src/sql/trigger/TRAIU_SENDUNG_ESB.sql`

When traffic flow (`verkehrsstrom`) changes for OMS shipments (Quell_K between 'a'-'z' or 'O', Sendungsart 'A'/'N'/'T'), the trigger queues a message to notify OMS:

```sql
elsif new.SENDUNGSART in ('A','N','T')
  and new.VERKEHRSSTROM <> coalesce(old.VERKEHRSSTROM,new.VERKEHRSSTROM)
  and (new.QUELL_K between 'a' and 'z' or new.QUELL_K = 'O')
then
  call TMS2ESB.PutToEntityChangedQueue(...);
end if;
```

This integration context explains why OMS_ID is needed: to identify the correct shipment in OMS when reporting changes.

### Other ESB Views Using OMS_ID

- `V_ESB_FAKLSTG.sql`
- `V_ESB_SEN_HST.sql`
- `V_ESB_SEN_ON_LL.sql`
- `V_ESB_SEN_ON_RK.sql`

### Open Questions

1. **Quell_K Semantics:** What's the difference between lowercase (a-z) and uppercase 'O'?
   - Different source systems within OMS?
   - Different data entry methods?

2. **Complete Quell_K Mapping:**
   - '0' = TMS internal
   - 'D' = New Dispo
   - a-z, O = OMS
   - Others?

3. **SEN_REF Reference Types:** What other reference types exist besides 'OMS_ID'?

### Related User Stories

- DEMPM-332: Avis-Handling: Übernahme aus OMS - Task 167434
- PBI-145369: DEMPM-332: Rückübertragung des Verkehrsstroms an OMS
- User Story 103821: Sendung.Quell_K and Sen_Ref.Typ=OMS_ID (current)

---

## Summary

### Key Findings

1. **Entity Clarification:**
   - **Partie Nr.** = Lot Number (Backend entity `LotEntity.LotNumber`, NOT in TMS)
   - **Sdg.-Nr.** = Shipment Number (TMS: `SENDUNG.SENDUNG_N`, Backend: `LegEntity.ShipmentNumber`)
   - Lot is a Backend concept for grouping Legs (shipments) for dispatch planning

2. **Verified API Endpoints:**
   - **Frontend → Backend:** `GET /api/pickup-drive-instructions?transportOrderId={id}`
   - **Backend → TMS Bridge:** GraphQL query `shipments(databaseIdentifier, where: {dispatchStatus: {eq: "F"}})`
   - **TMS Bridge → TMS Database:** SQL query to TMS view (needs identification)

3. **Data Flow Timeline:**
   - **Initial Load:** Shipments flow from TMS → TMS Bridge → Backend database (`LegEntity`)
   - **Display:** Frontend reads from Backend database (NOT directly from TMS)
   - **Critical:** OMS_ID must be captured during initial load, not at display time

4. **Performance:**
   - Use direct LEFT JOIN to `sen_ref` table (proven pattern from `V_ESB_SENDUNG`)
   - Verify index on `sen_ref(sen_tix, typ)` exists
   - Avoid function wrappers to allow query optimizer to work effectively

5. **Implementation Scope:**
   - 4 layers to update: TMS Database view → TMS Bridge → Backend → Frontend
   - **Most Critical First Step:** Identify which TMS database view backs the GraphQL `shipments` query in TMS Bridge
   - Each subsequent layer is straightforward once previous layer exposes OMS_ID
