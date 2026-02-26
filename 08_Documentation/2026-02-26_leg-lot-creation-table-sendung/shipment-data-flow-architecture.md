# Shipment Data Flow Architecture

**Date:** 2026-02-26
**Focus:** Complete data flow from TMS Database to Backend for shipment processing

---

## Overview

This document maps the complete architecture for shipment data flows in the New Dispo system, with focus on how shipment data from the `sendung` table flows through the system.

There are **two independent data pipelines** that both read from the `sendung` table:

1. **CDC Pipeline (Real-time)** - Captures changes and publishes events
2. **Batch Pickup Planning Pipeline** - Queries unplanned shipments via GraphQL

---

## Complete Architecture Diagram

```mermaid
graph TB
    subgraph "TMS Database (AlloyDB)"
        SENDUNG[("sendung table<br/>(source table)")]
        VIEW["v_dis_shipment_all view<br/>(WHERE sendungsart = 'A')"]
        SENDUNG --> VIEW
    end

    subgraph "CDC Pipeline (Real-time Changes)"
        REPLICATION_SLOT["PostgreSQL Logical<br/>Replication Slot<br/>(pgoutput)"]
        PUBLICATION["Publication<br/>(per-table config)"]
        CDC_CAPTURE["Google Datastream<br/>(CDC Capture)"]
        BUCKET["Google Cloud Storage<br/>Bucket<br/>(JSON change events)"]
        SENDUNG -.->|"INSERT/UPDATE/DELETE<br/>on published tables"| REPLICATION_SLOT
        REPLICATION_SLOT --> PUBLICATION
        PUBLICATION -->|"Only published<br/>tables captured"| CDC_CAPTURE
        CDC_CAPTURE -->|"Writes change events"| BUCKET
    end

    subgraph "New Dispo Cloud Functions"
        CF_TRIGGER["FilterShipmentsTrigger<br/>(Bucket/HTTPS)"]
        CF_FILTER["Filter Logic<br/>(shipmentType == 'A')"]
        PUBSUB["Google Pub/Sub<br/>Topic"]

        BUCKET -->|"Storage event"| CF_TRIGGER
        CF_TRIGGER --> CF_FILTER
        CF_FILTER -->|"Publish filtered events"| PUBSUB
    end

    subgraph "New Dispo Backend (CDC Path)"
        CDC_CONTROLLER["CDCController<br/>/pubsub/consume"]
        CDC_HANDLER["ConsumeEventCommandHandler"]
        EVENT_HANDLERS["Event Handlers<br/>- NewShipmentCreatedEventHandler<br/>- ShipmentUpdatedEventHandler<br/>- DeletedShipmentEventHandler"]
        BACKEND_DB[("Backend Database<br/>(Legs & Lots)")]

        PUBSUB -->|"Push subscription"| CDC_CONTROLLER
        CDC_CONTROLLER --> CDC_HANDLER
        CDC_HANDLER --> EVENT_HANDLERS
        EVENT_HANDLERS -->|"Create/Update<br/>Legs & Lots"| BACKEND_DB
    end

    subgraph "TMS Bridge (GraphQL API)"
        GQL_ENDPOINT["ShipmentQuery<br/>GetShipments(databaseIdentifier)"]
        DB_CONTEXT["BranchDbContext<br/>.DISShipments"]

        GQL_ENDPOINT --> DB_CONTEXT
        DB_CONTEXT -->|"SELECT * FROM"| VIEW
    end

    subgraph "New Dispo Backend (Batch Pickup Planning Path)"
        PP_CONTROLLER["PickupPlanningViewController<br/>/Initialize"]
        PP_INITIALIZER["PickupPlanningAllBranches<br/>DataInitializer"]
        PP_SHIPMENT_PROVIDER["PickupPlanningShipment<br/>Provider"]
        PP_QUERY["GraphQL Query Builder<br/>shipments(databaseIdentifier: '...',<br/>where: {dispatchStatus: {eq: 'F'}})"]

        PP_CONTROLLER -->|"POST /Initialize"| PP_INITIALIZER
        PP_INITIALIZER --> PP_SHIPMENT_PROVIDER
        PP_SHIPMENT_PROVIDER --> PP_QUERY
        PP_QUERY -->|"GraphQL HTTP Request"| GQL_ENDPOINT
        GQL_ENDPOINT -.->|"Response: shipment data"| PP_SHIPMENT_PROVIDER
        PP_SHIPMENT_PROVIDER -.->|"Extract legs,<br/>generate lots"| PP_INITIALIZER
        PP_INITIALIZER -.->|"Persist"| BACKEND_DB
    end

    style VIEW fill:#e1f5ff,stroke:#0066cc,stroke-width:3px
    style SENDUNG fill:#fff4e6,stroke:#ff9800,stroke-width:2px
    style CDC_CONTROLLER fill:#c3e6cb,stroke:#28a745,stroke-width:3px
    style GQL_ENDPOINT fill:#b3d7ff,stroke:#007bff,stroke-width:3px
    style BACKEND_DB fill:#fff9c4,stroke:#fbc02d,stroke-width:2px

    classDef cdcPath fill:#d4edda,stroke:#28a745,stroke-width:2px
    classDef batchPath fill:#cce5ff,stroke:#007bff,stroke-width:2px

    class BUCKET,CF_TRIGGER,CF_FILTER,PUBSUB,CDC_CONTROLLER,CDC_HANDLER,EVENT_HANDLERS cdcPath
    class PP_CONTROLLER,PP_INITIALIZER,PP_SHIPMENT_PROVIDER,PP_QUERY,GQL_ENDPOINT,DB_CONTEXT batchPath
```

---

## Data Flow Paths

### Path 1: CDC Flow (Real-time) 🟢

**Purpose:** Capture and propagate shipment changes in real-time

**Flow:**
1. `sendung` table changes (INSERT/UPDATE/DELETE)
2. CDC mechanism captures **full row data** from the change
3. Changes written to Google Cloud Storage Bucket (JSON format with complete shipment data)
4. Cloud Functions (`FilterShipmentsTrigger`) triggered by bucket events
5. Filter shipments where `shipmentType == 'A'`
6. Publish filtered events to Google Pub/Sub (includes **full shipment data in payload**)
7. Pub/Sub pushes message to Backend CDC endpoint (`/pubsub/consume`)
8. `ConsumeEventCommandHandler` deserializes the Pub/Sub message:
   ```csharp
   // Extract JSON from Pub/Sub message
   var json = Encoding.UTF8.GetString(Convert.FromBase64String(request.Message.Message.Data));

   // Deserialize to GoogleRecordChangeDto
   GoogleRecordChangeDto eventDataChanges = JsonConvert.DeserializeObject<GoogleRecordChangeDto>(json);

   // Contains OldRecord and NewRecord with full shipment data in Payload
   GoogleBucketFileContentDto oldRecord = eventDataChanges.OldRecord;
   GoogleBucketFileContentDto newRecord = eventDataChanges.NewRecord;
   ```
9. Event handlers extract shipment data from the event payload:
   ```csharp
   // From BaseEventHandler.GetDbRecordFromBucketAsDto()
   var shipmentAsJson = JsonConvert.SerializeObject(record.Payload);
   GoogleBucketShipmentData shipment = JsonConvert.DeserializeObject<GoogleBucketShipmentData>(shipmentAsJson);
   ```
10. Event handlers process the embedded shipment data:
    - `NewShipmentCreatedEventHandler` - Creates new Legs & Lots
    - `ShipmentUpdatedEventHandler` - Updates existing Legs & Lots
    - `DeletedShipmentEventHandler` - Removes Legs & Lots
11. Changes persisted to Backend Database

**Key Characteristics:**
- ❌ **Does NOT use `v_dis_shipment_all` view**
- ❌ **Does NOT query the database** - shipment data is embedded in the event
- ✅ Reads raw data from CDC bucket
- ✅ Full shipment row data included in each event
- ✅ Real-time propagation
- ✅ Event-driven architecture
- ✅ Handles incremental changes

**Critical Detail: Shipment Data Source**

The event handlers **DO NOT query the database**. Instead, they consume the complete shipment data from the Pub/Sub message payload.

**Data Structure:**
```
Pub/Sub Message
└── Data (base64 encoded JSON)
    └── GoogleRecordChangeDto
        ├── OldRecord: GoogleBucketFileContentDto
        │   ├── Payload: GoogleBucketShipmentData (complete sendung row)
        │   │   ├── ShipmentId
        │   │   ├── ShipmentNumber
        │   │   ├── ShipmentType
        │   │   ├── ConsignorName
        │   │   └── ... (44 mapped sendung columns)
        │   └── SourceMetadata (table, changeType, isDeleted)
        └── NewRecord: GoogleBucketFileContentDto
            └── (same structure as OldRecord)
```

**Code Reference:**
```csharp
// File: BaseEventHandler.cs:16-26
protected T GetDbRecordFromBucketAsDto<T>(GoogleBucketFileContentDto record) where T : class
{
    // Extracts the Payload object from the CDC event
    var shipmentAsJson = JsonConvert.SerializeObject(record.Payload);

    // Deserializes to GoogleBucketShipmentData with sendung columns
    T shipmentFromGoogleBucket = JsonConvert.DeserializeObject<T>(shipmentAsJson);

    return shipmentFromGoogleBucket;
}
```

**Visual: CDC Event Data Extraction**

```
┌─────────────────────────────────────────────────────────────────┐
│ Pub/Sub Message (Base64 JSON)                                  │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ GoogleRecordChangeDto                                       │ │
│ │ ┌──────────────────────┐  ┌──────────────────────┐         │ │
│ │ │ OldRecord            │  │ NewRecord            │         │ │
│ │ │ ┌──────────────────┐ │  │ ┌──────────────────┐ │         │ │
│ │ │ │ SourceMetadata   │ │  │ │ SourceMetadata   │ │         │ │
│ │ │ │ - table          │ │  │ │ - table          │ │         │ │
│ │ │ │ - changeType     │ │  │ │ - changeType     │ │         │ │
│ │ │ │ - isDeleted      │ │  │ │ - isDeleted      │ │         │ │
│ │ │ └──────────────────┘ │  │ └──────────────────┘ │         │ │
│ │ │ ┌──────────────────┐ │  │ ┌──────────────────┐ │         │ │
│ │ │ │ Payload          │ │  │ │ Payload          │ │         │ │
│ │ │ │ ┌──────────────┐ │ │  │ │ ┌──────────────┐ │ │         │ │
│ │ │ │ │ Shipment     │ │ │  │ │ │ Shipment     │ │ │         │ │
│ │ │ │ │ Data:        │ │ │  │ │ │ Data:        │ │ │         │ │
│ │ │ │ │ - ShipmentId │ │ │  │ │ │ - ShipmentId │ │ │         │ │
│ │ │ │ │ - Company    │ │ │  │ │ │ - Company    │ │ │         │ │
│ │ │ │ │ - Branch     │ │ │  │ │ │ - Branch     │ │ │         │ │
│ │ │ │ │ - Type       │ │ │  │ │ │ - Type       │ │ │         │ │
│ │ │ │ │ - Status     │ │ │  │ │ │ - Status     │ │ │         │ │
│ │ │ │ │ - Weight     │ │ │  │ │ │ - Weight     │ │ │         │ │
│ │ │ │ │ - ...44 flds │ │ │  │ │ │ - ...44 flds │ │ │         │ │
│ │ │ │ └──────────────┘ │ │  │ │ └──────────────┘ │ │         │ │
│ │ │ └──────────────────┘ │  │ └──────────────────┘ │         │ │
│ │ └──────────────────────┘  └──────────────────────┘         │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
            ConsumeEventCommandHandler extracts
                              │
                              ▼
              Event Handlers process embedded data
                              │
                              ▼
                    Backend DB (Legs & Lots)
```

**Code Locations:**
- Cloud Functions: `Code/Nagel-GCP/CALConsult.Disposition.Functions/CALConsult.Disposition.Functions.FilterShipments.Bucket/Trigger/FilterShipmentsTrigger.cs`
- CDC Controller: `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/CDCController.cs`
- Event Handlers: `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/`
- Data Extraction: `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/BaseEventHandler.cs:16`

---

### Path 2: Pickup Planning Initialization (Batch) 🔵

**Purpose:** Bulk load unplanned shipments for pickup planning

**Flow:**
1. User/System triggers initialization via POST `/Initialize` endpoint
2. Backend calls `PickupPlanningAllBranchesDataInitializer`
3. For each branch, `PickupPlanningShipmentProvider` builds GraphQL query:
   ```graphql
   query {
     shipments(
       databaseIdentifier: "BRANCH_KEY",
       where: { dispatchStatus: { eq: "F" } }
     ) {
       shipmentId
       shipmentNumber
       consignorName
       # ... more fields
     }
   }
   ```
4. GraphQL request sent to TMS Bridge API
5. TMS Bridge `ShipmentQuery.GetShipments()` processes query
6. `BranchDbContext.DISShipments` queries **`v_dis_shipment_all` view**
7. View returns filtered shipments (`WHERE sendungsart = 'A'`)
8. GraphQL applies additional filters (`dispatchStatus = 'F'`)
9. Response returned to Backend
10. Backend extracts Legs from shipments
11. Backend generates Lots based on routing rules
12. Legs & Lots persisted to Backend Database

**Key Characteristics:**
- ✅ **Uses `v_dis_shipment_all` view**
- ✅ Batch processing
- ✅ Filters for unplanned shipments (`dispatchStatus = 'F'`)
- ✅ One-time or periodic execution
- ✅ Generates complete Lot structure

**Code Locations:**
- Backend Controller: `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/PickupPlanningView/PickupPlanningViewController.cs:59`
- Shipment Provider: `Code/Disposition-Backend/CALConsult.Disposition.API/Application/_Shared/Services/ShipmentProvider/PickupPlanningShipmentProvider.cs:39-47`
- TMS Bridge Query: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Queries/ShipmentQuery/ShipmentQuery.cs:15`
- DB Context: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContext.cs:137-139`

---

## CDC Replication Configuration Details

**Location:** `Code/tms-alloydb-schema/src/sql/scripts/misc/datastream_setup.sql`

**Technology Stack:**
- PostgreSQL Logical Replication (native feature)
- Plugin: `pgoutput` (standard PostgreSQL logical decoding plugin)
- Google Datastream (captures from replication slot)

**How It Works:**

```sql
-- 1. Create replication slot
PG_CREATE_LOGICAL_REPLICATION_SLOT('slot_name', 'pgoutput');

-- 2. Create publication for specific table
CREATE PUBLICATION publication_name FOR TABLE tablename;
```

**Key Characteristics:**
- ✅ Replication slot captures logical changes (INSERT/UPDATE/DELETE)
- ✅ Publications define **which tables** are replicated
- ✅ Per-table configuration (not database-wide)
- ✅ Configuration is external to application code
- ⚠️ Script is parameterized - actual table names configured at runtime

**What Gets Captured:**
- Only tables explicitly added to a publication
- Full row data for INSERT operations (all columns)
- Old and new row data for UPDATE operations
- Old row data for DELETE operations
- Metadata: table name, change type, timestamp

**What Does NOT Get Captured:**
- Tables not in any publication
- Related table data (requires separate publication)
- JOIN results or computed values
- Data from views

**Current Configuration:**
Based on code analysis:
- ✅ `sendung` table is published (event handlers process only this table)
- ❌ Other tables like `sen_ref` are not captured (no corresponding event handlers exist)
- 📝 Only 44 of 100+ `sendung` columns are mapped in `GoogleBucketShipmentData` DTO

---

## `v_dis_shipment_all` View Details

**Location:** `Code/tms-alloydb-schema/src/sql/view/V_DIS_SHIPMENT_ALL.sql`

**Definition:**
```sql
CREATE OR REPLACE VIEW v_dis_shipment_all AS
SELECT
    sendung_tix as shipmentid,
    firma as company,
    niederlassung as branch,
    sendungsart as shipmenttype,
    status_dis as dispatchstatus,
    sendung_n as shipmentnumber,
    -- ... many more fields ...
FROM sendung s
WHERE sendungsart = 'A';  -- Only type 'A' shipments
```

**Purpose:**
- Exposes shipment data specifically for disposition/pickup planning
- Filters only type 'A' shipments (Abholsendung/Pickup shipments)
- Provides standardized column naming for GraphQL API

**Mapped to Entity:**
- Entity: `DISShipmentEntity`
- Mapping: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContext.cs:137-139`
  ```csharp
  modelBuilder.Entity<DISShipmentEntity>()
      .ToView("v_dis_shipment_all")
      .HasKey(to => to.ShipmentId);
  ```

**Used By:**
- TMS Bridge GraphQL API (`GetShipments` query)
- Called by Backend Pickup Planning initialization

**NOT Used By:**
- CDC pipeline (uses raw bucket data instead)
- Real-time event handlers

---

## Components Using `shipments(databaseIdentifier:...)` GraphQL Query

### TMS Bridge (Defines the Query)
- **File:** `ShipmentQuery.cs:15`
- **Method:** `GetShipments(string databaseIdentifier, ...)`
- **Returns:** `IQueryable<DISShipmentEntity>`
- **Data Source:** `v_dis_shipment_all` view

### New Dispo Backend (Consumes the Query)

#### 1. PickupPlanningShipmentProvider
- **File:** `PickupPlanningShipmentProvider.cs`
- **Methods:**
  - `GetAllUnplanned(string branchKey)` - Line 39-47
  - `GetSingleShipment(string branchKey, long shipmentId)` - Line 75-83
- **Purpose:** Builds and executes GraphQL queries for shipments

#### 2. PickupPlanningAllBranchesShipmentProvider
- **File:** `PickupPlanningAllBranchesShipmentProvider.cs:55`
- **Purpose:** Retrieves shipments for multiple branches in parallel
- **Calls:** `_shipmentProvider.GetAllUnplanned(key)`

#### 3. PickupPlanningAllBranchesDataInitializer
- **File:** `PickupPlanningAllBranchesDataInitializer.cs:203`
- **Purpose:** Orchestrates batch initialization of pickup planning data
- **Calls:** `_allBranchesShipmentProvider.Get(branchKeys)`

#### 4. InitializePickupPlanningDataCommandHandler
- **File:** `InitializePickupPlanningDataCommandHandler.cs:16`
- **Purpose:** Command handler for initialization request
- **Calls:** `_dataInitializer.Initialize()`

#### 5. PickupPlanningViewController
- **File:** `PickupPlanningViewController.cs:59`
- **Endpoint:** `POST /Initialize`
- **Purpose:** HTTP endpoint to trigger initialization
- **Calls:** `_mediator.Send(new InitializePickupPlanningDataCommand())`

---

## Related Files

### Database Schema & CDC Configuration
- **CDC Setup**: `Code/tms-alloydb-schema/src/sql/scripts/misc/datastream_setup.sql` (replication slot & publication config)
- **Views**: `Code/tms-alloydb-schema/src/sql/view/V_DIS_SHIPMENT_ALL.sql`
- **Tables**:
  - `Code/tms-alloydb-schema/src/sql/table/SENDUNG.sql`
  - `Code/tms-alloydb-schema/src/sql/table/SEN_REF.sql`

### TMS Bridge
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Queries/ShipmentQuery/ShipmentQuery.cs`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContext.cs`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/Shipment/DISShipmentEntity.cs`

### Backend - Pickup Planning
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/PickupPlanningView/PickupPlanningViewController.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/_Shared/Services/ShipmentProvider/PickupPlanningShipmentProvider.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Shared/GraphQL/Dtos/Queries/shipment/PickupPlanningShipmentDto.cs`

### Backend - CDC
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/CDCController.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/NewShipmentCreated/NewShipmentCreatedEventHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/GooglePubSub/Dtos/GoogleBucketShipmentData.cs`

### Cloud Functions
- `Code/Nagel-GCP/CALConsult.Disposition.Functions/CALConsult.Disposition.Functions.FilterShipments.Bucket/Trigger/FilterShipmentsTrigger.cs`
- `Code/Nagel-GCP/CALConsult.Disposition.Functions/CALConsult.Disposition.Functions.FilterShipments.Bucket/Dtos/GoogleBucketShipmentData.cs`

---

## Summary: Two Independent Data Pipelines

The New Dispo system has **two completely independent pipelines** for shipment data:

### Comparison Table

| Aspect | CDC Pipeline (Real-time) | Pickup Planning Pipeline (Batch) |
|--------|--------------------------|-----------------------------------|
| **Trigger** | Database change events | Manual POST /Initialize |
| **Data Source** | CDC event payload (embedded data) | GraphQL query to TMS Bridge |
| **Uses `v_dis_shipment_all`?** | ❌ No | ✅ Yes |
| **Queries Database?** | ❌ No - data in event | ✅ Yes - via GraphQL |
| **Data Freshness** | Real-time (seconds) | On-demand batch |
| **Processing Model** | Event-driven, incremental | Query-based, bulk loading |
| **Complete Row Data?** | ✅ Yes - in Payload | ✅ Yes - from query |
| **Target** | Creates/Updates Legs & Lots | Creates initial Legs & Lots |
| **Column Coverage** | 44 mapped sendung columns | View-defined column selection |

### Critical Insight: Where Does Shipment Data Come From?

**CDC Pipeline:**
```
sendung table change
  → CDC captures FULL ROW
    → Bucket stores complete data
      → Cloud Functions passes through
        → Pub/Sub includes FULL DATA in message
          → Backend extracts from Payload
            ⚠️ NO DATABASE QUERY
```

**Pickup Planning Pipeline:**
```
POST /Initialize
  → Backend builds GraphQL query
    → TMS Bridge receives query
      → Queries v_dis_shipment_all view
        → View queries sendung table
          → Returns filtered data
            ⚠️ QUERIES DATABASE
```

### Key Architectural Characteristics

**Separation of Concerns:**
- CDC handles real-time incremental updates
- Pickup Planning handles bulk initialization
- Both ultimately persist to Backend Database (Legs & Lots)

**Data Consistency:**
- Both paths read from the same source (`sendung` table)
- Different data access patterns for different use cases
- Backend reconciles data from both pipelines

**Scalability Considerations:**
- CDC scales with database write volume
- Pickup Planning scales with query complexity and data volume
- Both can operate independently without blocking each other
