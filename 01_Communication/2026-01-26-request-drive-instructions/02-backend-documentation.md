# Fahranweisung — Backend Endpoints, Data Contracts & Authentication

## Authentication

- **Keycloak JWT Bearer Token** authentication on all endpoints
- Every request also requires a **`Database-Identifier`** header

### Required Headers on Every Request

| Header | Description |
|--------|-------------|
| `Authorization` | `Bearer {JWT token}` from Keycloak |
| `Database-Identifier` | Identifies the target database (e.g. `main`) |

---

## Drive Instructions Endpoint

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/api/pickup-planning/transportorders/{transportOrderId}/drive-instructions` | Retrieve drive instructions for a transport order |

**Response structure (nested hierarchy):**

```
DriveInstructionsTourPointCardDto
├── tourpointId, type (1=pickup, 3=delivery), sequenceNumber
├── name, street, country, postalCode, city
├── plannedArrivalTime, plannedDepartureTime
├── weight, floorPalletSpaces, volumePalletSpaces
├── uniqueClientsCount, uniqueTrafficFlowsCount
├── productGroups: List<string>
└── lotAssignmentCards[]
    ├── lotAssignmentId, number, legsCount, pickupTourPointOrder
    └── legCards[]
        ├── legId, shipmentNumber, order
        ├── name, street, country, city, zipCode
        ├── weight, volumePalletSpaces, floorPalletSpaces
        ├── deliveryDateFrom/To, pickupDateFrom/To, fixedDeliveryDate
        ├── staysLoaded: bool
        └── trafficIcon (ArrowDown=loading, ArrowUp=unloading)
```

---

## Tourpoint Operations (Move Tourpoints)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `PUT` | `/api/pickup-planning/tourpoints/reorder` | Move/reorder tourpoints in sequence |
| `POST` | `/api/pickup-planning/transportorders/tourpoint` | Add a tourpoint |
| `DELETE` | `/api/pickup-planning/transportorders/tourpoint` | Delete a tourpoint |
| `PUT` | `/api/transportorders/tourpoints/{tourPointId}` | Edit tourpoint data (address, person, etc.) |

**Reorder request:**

```json
{
  "SourceTransportOrderTix": 123,
  "SourceTourpointId": 456,
  "DestinationTourpointId": 789,
  "RelationType": 1,
  "Mode": null
}
```

**Edit tourpoint request:**

```json
{
  "PersonNumber": 123,
  "PersonTix": 456,
  "Name1": "string",
  "TourNumber": "string",
  "ReferenceTourpointId": 789,
  "Country": "DE",
  "Reference": "string",
  "PostalCode": "12345",
  "City": "Berlin",
  "StreetAndHouseNumber": "Musterstr. 1",
  "HouseNumberAddition": "a",
  "District": "string",
  "TourpointPosition": "string"
}
```

---

## Loading Sequence — Lot Assignments (Partien)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `PUT` | `/api/pickup-planning/lotassignments/reorder` | Change loading sequence of lot assignments |

**Request:**

```json
{
  "LotAssignmentId": "guid",
  "NewPickupTourPointOrder": 2,
  "TransportOrderId": 123
}
```

---

## Loading Sequence — Legs/Shipments (Sendungen innerhalb Partien)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `PUT` | `/api/pickup-planning/legs/reorder` | Change sequence of shipments within a lot assignment |
| `PATCH` | `/api/pickup-planning/legs/{legId}/stays-loaded` | Mark shipment as "stays loaded" |

**Reorder Leg request:**

```json
{
  "LotAssignmentId": "guid",
  "LegId": "guid",
  "NewOrder": 3
}
```

**Stays Loaded:** Query parameter `staysLoadedValue: bool`

---

## Transport Order Details

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/api/transportorders/{orderNumber}` | Full transport order details (tourpoints, vehicles, etc.) |
| `POST` | `/api/transportorders/paged` | Paginated transport order list |
| `PUT` | `/api/transportorders/tourpoints/{tourPointId}/loading-interval` | Set loading time window |
| `PUT` | `/api/transportorders/tourpoints/{tourPointId}/loading-reference` | Set loading reference |
| `DELETE` | `/api/transportorders/tourpoints/{tourPointId}/loading-interval` | Remove loading time window |
| `PATCH` | `/api/transportorders/tourpoint/{tourPointId}/tournumber` | Set customer tour number |

**Loading Interval request:**

```json
{
  "StartTime": "2026-01-26T08:00:00Z",
  "EndTime": "2026-01-26T09:00:00Z"
}
```

**Loading Reference request:**

```json
{
  "LoadingReference": "Gate 5"
}
```

---

## OpenAPI / Swagger

- Available at `/swagger` and `/swagger/v1/swagger.json`
- **Only enabled** in `Local` and `Development` environments (not in production/test)
- Swagger UI includes Bearer token authentication for testing
- Includes operation filters for `Database-Identifier` and `FreightProvider` headers

---

## Key Source Code Locations

| Area | Path |
|------|------|
| **Controllers** | `Features/PickupPlanning/PickupPlanningController.cs`, `Features/TransportOrders/TransportOrdersController.cs` |
| **Drive Instructions** | `Features/PickupPlanning/Requests/GetDriveInstructions/` |
| **Tourpoint Reorder** | `Features/PickupPlanning/Requests/ReorderTourpoint/` |
| **Tourpoint Edit** | `Features/TransportOrders/Requests/EditTourpoint/` |
| **Leg Reorder** | `Features/PickupPlanning/Requests/ReorderLeg/` |
| **Lot Assignment Reorder** | `Features/PickupPlanning/Requests/ReorderLotAssignment/` |
| **Stays Loaded** | `Features/PickupPlanning/Requests/MarkLegStaysLoaded/` |
| **Loading Reference** | `Features/TransportOrders/Requests/SetTourpointLoadingReference/` |
| **Loading Interval** | `Features/TransportOrders/Requests/SetTourpointLoadingInterval/` |
| **Auth Config** | `Infrastructure/ServiceSetupExtensions/KeyCloack/` |
| **Swagger Config** | `Infrastructure/ServiceSetupExtensions/Swagger/` |
| **Domain Entities** | `Domain/Entities/LotAssignment/`, `Domain/Entities/Leg/`, `Domain/Entities/LotAssignmentLegLink/` |

---

## TMS Bridge — GraphQL Mutations

Several backend endpoints delegate write operations to the TMS Bridge via GraphQL. The Bridge base URL is configured per environment (e.g. `http://localhost:5158/bridge/`). The backend forwards the caller's Bearer token to the Bridge.

### callMoveTourpoint — Reorder/Move Tourpoint

**Triggered by:** `PUT /api/pickup-planning/tourpoints/reorder`

```graphql
mutation callMoveTourpoint($databaseIdentifier: String!, $input: MoveTourpointInput!) {
    callMoveTourpoint(databaseIdentifier: $databaseIdentifier, input: $input) {
        isTourpointMoved
    }
}
```

**Input:**

| Field | Type | Required |
|-------|------|----------|
| sourceTransportOrderTix | long | yes |
| sourceTourpointId | long | yes |
| destinationTourpointId | long | yes |
| relationType | int | yes |
| mode | int | no |

---

### callAddTourpoint — Add Tourpoint

**Triggered by:** `POST /api/pickup-planning/transportorders/tourpoint`

```graphql
mutation callAddTourpoint($databaseIdentifier: String!, $input: AddTourpointInput!) {
    callAddTourpoint(databaseIdentifier: $databaseIdentifier, input: $input) {
        isTourpointAdded,
        tourpointId
    }
}
```

**Input:**

| Field | Type | Required |
|-------|------|----------|
| transportOrderId | long | yes |
| tourpointType | long | yes |
| productType | string | no |
| deliveryDateFrom | DateOnly | no |
| deliveryTimeFrom | string | no |
| deliveryDateTo | DateOnly | no |
| deliveryTimeTo | string | no |
| personNumber | long | no |
| personTix | long | no |
| name1 | string | no |
| tourNumber | string | no |
| referenceTourpointId | long | no |
| country | string | no |
| reference | string | no |
| postalCode | string | no |
| city | string | no |
| streetAndHouseNumber | string | no |
| houseNumberAddition | string | no |
| district | string | no |
| tourpointPosition | long | no |

---

### callDeleteTourpoint — Delete Tourpoint

**Triggered by:** `DELETE /api/pickup-planning/transportorders/tourpoint`

```graphql
mutation callDeleteTourpoint($databaseIdentifier: String!, $input: DeleteTourpointInput!) {
    callDeleteTourpoint(databaseIdentifier: $databaseIdentifier, input: $input) {
        isTourpointDeleted
    }
}
```

**Input:**

| Field | Type | Required |
|-------|------|----------|
| transportOrderId | long | yes |
| tourpointId | long | yes |
| mode | int | no |

---

### callEditTourpoint — Edit Tourpoint Details

**Triggered by:** `PUT /api/transportorders/tourpoints/{tourPointId}`

```graphql
mutation callEditTourpoint($databaseIdentifier: String!, $input: EditTourpointInput!) {
    callEditTourpoint(databaseIdentifier: $databaseIdentifier, input: $input) {
        isTourpointEdited
    }
}
```

**Input:**

| Field | Type | Required |
|-------|------|----------|
| tourpointId | long | yes (from URL) |
| personNumber | long | no |
| personTix | long | no |
| name1 | string | no |
| tourNumber | string | no |
| referenceTourpointId | long | no |
| country | string | no |
| reference | string | no |
| postalCode | string | no |
| city | string | no |
| streetAndHouseNumber | string | no |
| houseNumberAddition | string | no |
| district | string | no |
| tourpointPosition | long | no |

---

### callSetLoadingReference — Set Loading Reference

**Triggered by:** `PUT /api/transportorders/tourpoints/{tourPointId}/loading-reference`

```graphql
mutation callSetLoadingReference($databaseIdentifier: String!, $input: SetLoadingReferenceInput!) {
    callSetLoadingReference(databaseIdentifier: $databaseIdentifier, input: $input) {
        isLoadingReferenceSet
    }
}
```

**Input:**

| Field | Type | Required |
|-------|------|----------|
| tourpointId | long | yes (from URL) |
| loadingReference | string | no |

---

### callSetTargetLoadingStartTime / callSetTargetLoadingEndTime — Set Loading Interval

**Triggered by:** `PUT /api/transportorders/tourpoints/{tourPointId}/loading-interval`

```graphql
mutation callSetTargetLoadingStartTime($databaseIdentifier: String!, $input: SetTargetLoadingStartTimeInput!) {
    callSetTargetLoadingStartTime(databaseIdentifier: $databaseIdentifier, input: $input) {
        isStartTimeSet
    }
}

mutation callSetTargetLoadingEndTime($databaseIdentifier: String!, $input: SetTargetLoadingEndTimeInput!) {
    callSetTargetLoadingEndTime(databaseIdentifier: $databaseIdentifier, input: $input) {
        isEndTimeSet
    }
}
```

**Input (start):** `tourpointId: long`, `startTime: DateTime?`
**Input (end):** `tourpointId: long`, `endTime: DateTime?`

---

### callRemoveLoadingIntervals — Remove Loading Intervals

**Triggered by:** `DELETE /api/transportorders/tourpoints/{tourPointId}/loading-interval`

```graphql
mutation CallRemoveLoadingIntervals($databaseIdentifier: String!, $input: RemoveLoadingIntervalsInput!) {
    callRemoveLoadingIntervals(databaseIdentifier: $databaseIdentifier, input: $input) {
        isDeleted
    }
}
```

**Input:** `tourpointId: long`

---

### callStaysLoaded — Mark Leg as Stays Loaded

**Triggered by:** `PATCH /api/pickup-planning/legs/{legId}/stays-loaded`

```graphql
mutation callStaysLoaded {
    callStaysLoaded(databaseIdentifier: "{databaseIdentifier}"
      input: { tmsLegId: {tmsLegId}, staysLoadedFlag: {shouldStayLoaded} }
    ) {
        isStaysLoadedSet
        tmsLegId
    }
}
```

**Input:** `tmsLegId: long`, `staysLoadedFlag: bool`

> Note: this mutation uses string interpolation rather than GraphQL variables.

---

### TMS Bridge Summary

| GraphQL Mutation | Backend Endpoint | Response Field |
|------------------|------------------|----------------|
| `callMoveTourpoint` | `PUT /api/pickup-planning/tourpoints/reorder` | `isTourpointMoved` |
| `callAddTourpoint` | `POST /api/pickup-planning/transportorders/tourpoint` | `isTourpointAdded`, `tourpointId` |
| `callDeleteTourpoint` | `DELETE /api/pickup-planning/transportorders/tourpoint` | `isTourpointDeleted` |
| `callEditTourpoint` | `PUT /api/transportorders/tourpoints/{id}` | `isTourpointEdited` |
| `callSetLoadingReference` | `PUT /api/transportorders/tourpoints/{id}/loading-reference` | `isLoadingReferenceSet` |
| `callSetTargetLoadingStartTime` | `PUT /api/transportorders/tourpoints/{id}/loading-interval` | `isStartTimeSet` |
| `callSetTargetLoadingEndTime` | `PUT /api/transportorders/tourpoints/{id}/loading-interval` | `isEndTimeSet` |
| `callRemoveLoadingIntervals` | `DELETE /api/transportorders/tourpoints/{id}/loading-interval` | `isDeleted` |
| `callStaysLoaded` | `PATCH /api/pickup-planning/legs/{id}/stays-loaded` | `isStaysLoadedSet`, `tmsLegId` |

---

## Architecture Notes

- **CQRS pattern** — all operations split into Query handlers (reads) and Command handlers (writes)
- **GraphQL integration** — write operations (reorder tourpoints, edit, add, delete, stays-loaded) are forwarded to the TMS Bridge via GraphQL mutations
- **Local DB operations** — leg reorder and lot assignment reorder write directly to PostgreSQL via Entity Framework
- **Validation** — dedicated `ICommandValidator` / `IQueryValidator` per operation
