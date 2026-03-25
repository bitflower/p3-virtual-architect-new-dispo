# Shipment Data Flow Architecture

**Date:** 2026-02-26
**Version:** 1.0
**Status:** Verified
**Source:** [08_Documentation/2026-02-26_leg-lot-creation-table-sendung/shipment-data-flow-architecture.md](../../08_Documentation/2026-02-26_leg-lot-creation-table-sendung/shipment-data-flow-architecture.md)

---

## Overview

Complete architecture for shipment data flows in the New Dispo system, showing how shipment data from the `sendung` table flows through two independent pipelines:

1. **CDC Pipeline (Real-time)** - Captures changes and publishes events
2. **Batch Pickup Planning Pipeline** - Queries unplanned shipments via GraphQL

---

## Diagram

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

## Key Characteristics

### CDC Pipeline (Real-time) 🟢
- ❌ Does NOT use `v_dis_shipment_all` view
- ❌ Does NOT query the database
- ✅ Reads raw data from CDC bucket
- ✅ Full shipment row data included in each event
- ✅ Real-time propagation
- ✅ Event-driven architecture

### Pickup Planning Pipeline (Batch) 🔵
- ✅ Uses `v_dis_shipment_all` view
- ✅ Batch processing
- ✅ Filters for unplanned shipments (`dispatchStatus = 'F'`)
- ✅ One-time or periodic execution
- ✅ Generates complete Lot structure

---

## Related Documentation

- **Detailed Documentation:** [08_Documentation/2026-02-26_leg-lot-creation-table-sendung/](../../08_Documentation/2026-02-26_leg-lot-creation-table-sendung/)
- **Other Diagrams:** [07_Diagrams/](../)
