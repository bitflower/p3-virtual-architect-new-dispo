# Transport Order Creation via Drag and Drop Flow

**Date:** 2026-03-16
**Version:** 1.1
**Status:** Verified (Deep code check: 2026-03-25)
**Source:** [02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/01-overview-and-flow.md](../../02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/01-overview-and-flow.md)

---

## Overview

Complete drag-and-drop flow showing how dispatchers create transport orders from unplanned lots or legs. This orchestrates the full stack:

**Frontend → Backend → TMS Bridge → TMS Database → Tour Calculation → Response**

Key characteristics:
- ✅ User-initiated via drag & drop (Angular CDK)
- ✅ Date picker dialog for performance date selection
- ✅ Batch GraphQL mutation to TMS
- ✅ Automatic tour calculation trigger (xServer)
- ✅ Transformation from LotEntity to LotAssignmentEntity
- ✅ Transactional integrity across the stack

---

## Diagram

```mermaid
sequenceDiagram
    participant User as Dispatcher
    participant Frontend as Angular Frontend
    participant Dialog as Create TO Dialog
    participant APIService as CRUD Service
    participant Controller as Backend Controller
    participant Handler as Command Handler
    participant SubHandler as TMS GraphQL SubHandler
    participant Bridge as TMS Bridge
    participant TMS as TMS Database
    participant RouteCalc as RecalculateRouteService
    participant TOP as TOP Service (xServer)

    User->>Frontend: Drag Lot/Leg from unplanned area
    User->>Frontend: Drop on "Create Transport Order" zone
    activate Frontend
    Frontend->>Dialog: Open date picker dialog
    activate Dialog
    Dialog-->>User: Show performance date selector
    User->>Dialog: Select date & click "Create"
    Dialog-->>Frontend: Return selected date
    deactivate Dialog

    Frontend->>APIService: createTransportOrder(lot/leg, date)
    activate APIService
    APIService->>Controller: POST /api/transport-order-planning/transportorders/from-lot
    activate Controller

    Controller->>Handler: Send CreateTransportOrderFromLotCommand
    activate Handler
    Handler->>Handler: Fetch lot with all legs from DB
    Handler->>Handler: Determine transport mode (60 if pickup)
    Handler->>Handler: Map legs to input DTOs

    Handler->>SubHandler: Create(legs, performanceDate, transportMode)
    activate SubHandler
    SubHandler->>SubHandler: Build batch GraphQL mutation
    SubHandler->>Bridge: Execute batch mutation (createTransportOrderFromLeg + addLeg)
    activate Bridge

    Bridge->>TMS: Call pdis_transportorder.createtransportorderfromleg()
    activate TMS
    TMS->>TMS: Create transport order
    TMS->>TMS: Add first leg
    TMS-->>Bridge: Return transportOrderId, legId, tourPointIds
    deactivate TMS

    loop For each additional leg
        Bridge->>TMS: Call pdis_transportorder.createandaddleg()
        activate TMS
        TMS->>TMS: Add leg to transport order
        TMS-->>Bridge: Return pickupPointId, isNewPickupPoint, deliveryPointId, isNewDeliveryPoint, legId
        deactivate TMS
    end

    Bridge-->>SubHandler: Return response with all IDs
    deactivate Bridge
    SubHandler-->>Handler: Return CreateTransportOrderFromLotBatchGraphQLResponseDto
    deactivate SubHandler

    Note over Handler,RouteCalc: CRITICAL: Tour calculation triggered immediately

    Handler->>RouteCalc: Recalculate(databaseIdentifier, transportOrderId)
    activate RouteCalc
    RouteCalc->>Bridge: GetPoolDto (transport order data)
    Bridge-->>RouteCalc: PoolDto with route info
    RouteCalc->>TOP: CalculateRoutes(poolDto)
    activate TOP
    TOP->>TOP: Run tour optimization algorithm
    TOP-->>RouteCalc: Enriched PoolDto with optimized routes
    deactivate TOP
    RouteCalc->>Bridge: SetPoolDto (persist optimized routes)
    Bridge->>TMS: Update tour points with optimized sequence
    deactivate RouteCalc

    Handler->>Handler: Create LotAssignmentEntity
    Handler->>Handler: Create LotAssignmentLegLinkEntity for each leg
    Handler->>Handler: Remove original lot from DB
    Handler->>Handler: SaveChangesAsync()
    Handler-->>Controller: Return CreateTransportOrderFromLotResponseDto
    deactivate Handler

    Controller-->>APIService: Return 201 Created with transportOrderId
    deactivate Controller
    APIService-->>Frontend: Success response
    deactivate APIService
    Frontend->>Frontend: Refresh transport order list
    Frontend-->>User: Show success message
    deactivate Frontend
```

---

## Key Takeaways

### 1. Complete Stack Integration ✅
- Frontend (Angular CDK drag & drop)
- Backend (CQRS pattern with MediatR)
- TMS Bridge (GraphQL mutations)
- TMS Database (stored functions)
- External Services (xServer tour optimization)

### 2. Automatic Tour Calculation ⚡
- Triggered immediately after transport order creation
- Non-blocking (errors logged but don't fail creation)
- Can be manually retriggered from frontend
- Uses xServer for route optimization

### 3. Data Transformation Pattern 🔄
- `LotEntity` (unplanned) → `LotAssignmentEntity` (planned)
- Original lot deleted, legs preserved
- Links maintained via `LotAssignmentLegLinkEntity`
- Full traceability with `PreviousLotId`

### 4. Batch Processing Strategy 📦
- Single GraphQL mutation with multiple operations
- First leg: `createtransportorderfromleg()`
- Additional legs: `createandaddleg()` (internally calls `addleg()`)
- Transactional integrity across all leg additions
- Efficient network usage
- Variable export/import between operations

### 5. Flexible Assignment Model 🔗
- Legs can be reassigned to different transport orders
- Lots can be split across multiple transport orders
- Individual legs can be added to existing transport orders
- Original shipment data always preserved

---

## Related Documentation

- **Detailed Documentation:** [02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/](../../02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/)
- **Pre-existing PlantUML Diagram:** [07_Diagrams/pickup-planning-create-transport-order-from-lot.wsd](../pickup-planning-create-transport-order-from-lot.wsd)
- **Other Diagrams:** [07_Diagrams/](../)
