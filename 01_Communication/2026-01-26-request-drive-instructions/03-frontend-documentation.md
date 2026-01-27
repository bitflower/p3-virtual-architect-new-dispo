# Fahranweisung (Drive Instructions) - Backend Dokumentation

Antwort auf die Anfrage zur Struktur der Fahranweisung in der New Dispo App.
Fokus: Backend-Endpoints, Datenverträge (Data Contracts) und Authentifizierung.

Alle referenzierten Pfade sind relativ zum Frontend-Repository Root.

---

## 1. Authentifizierung

**Mechanismus:** Keycloak OpenID Connect (OAuth 2.0 / Bearer Token)

- Beim App-Start wird `KeycloakService.init()` über `APP_INITIALIZER` aufgerufen. Nutzer müssen sich einloggen bevor die App lädt (`onLoad: 'login-required'`).
- Der `RequestService` fügt automatisch folgende Header zu jedem API-Call hinzu:

```
Authorization: Bearer <keycloak-token>
Content-Type: application/json
Database-Identifier: <branch-value-aus-localStorage>
```

- Die Session wird aktiv überwacht. Token-Erneuerung erfolgt 50 Sekunden vor Ablauf. Bei fehlgeschlagener Erneuerung wird der Nutzer ausgeloggt.

### Relevante Dateien

| Datei | Zweck |
|-------|-------|
| `libs/nagel-services/src/lib/keycloakService/keycloak.service.ts` | Token-Verwaltung, Init, Renewal, Logout |
| `libs/nagel-services/src/lib/requestService/request.service.ts` | Fügt Bearer Token + Database-Identifier zu allen Requests hinzu |
| `apps/nagel-cal-disposition/src/app/app.config.ts` | APP_INITIALIZER mit Keycloak, HTTP-Interceptor-Setup |
| `apps/nagel-cal-disposition/src/app/app.component.ts` (Zeilen 106-145) | Session-Activity-Monitoring & Token-Refresh |

---

## 2. Backend API Endpoints

Alle Endpoint-Konstanten sind definiert in:
`apps/nagel-cal-disposition/src/app/configuration/consts/endpoints.ts`

Die Base-URL kommt aus der Environment-Config (z.B. `http://localhost:5101` für Dev).

### 2.1 Fahranweisung / Tourpunkte

| Methode | Endpoint | Beschreibung |
|---------|----------|-------------|
| `GET` | `/api/pickup-planning/transportorders/{id}/drive-instructions` | Alle Tourpunkte (Fahranweisung) eines Transportauftrags abrufen |
| `POST` | `/api/pickup-planning/transportorders/tourpoint` | Neuen Tourpunkt anlegen |
| `PUT` | `/api/transportorders/tourpoints/{tourPointId}` | Bestehenden Tourpunkt bearbeiten |
| `DELETE` | `/api/pickup-planning/transportorders/tourpoint` | Tourpunkt löschen |
| `PUT` | `/api/pickup-planning/tourpoints/reorder` | Tourpunkte umsortieren (Drag & Drop) |
| `PATCH` | `/api/transportorders/tourpoint/{tourPointId}/tournumber` | Kunden-Tournummer setzen |
| `POST` | `/api/pickup-planning/transportorders/graph-tour-points` | Graph-Tourpunkte für Visualisierung abrufen |

### 2.2 Ladeintervalle (Loading Intervals)

| Methode | Endpoint | Beschreibung |
|---------|----------|-------------|
| `PUT` | `/api/transportorders/tourpoints/{tourPointId}/loading-interval` | Ladeintervall (Zeitfenster) setzen |
| `DELETE` | `/api/transportorders/tourpoints/{tourPointId}/loading-interval` | Ladeintervall entfernen |

### 2.3 Zuweisungen & Ladereihenfolge (Assignments / Loading Sequence)

| Methode | Endpoint | Beschreibung |
|---------|----------|-------------|
| `POST` | `/api/pickup-planning/lotassignments/from-leg` | Sendung (Leg) einem Transportauftrag zuweisen |
| `POST` | `/api/pickup-planning/lotassignments/from-lot` | Partie (Lot) einem Transportauftrag zuweisen |
| `PUT` | `/api/pickup-planning/lotassignments/reorder` | **Partien umsortieren** (Ladereihenfolge der Lots) |
| `PUT` | `/api/pickup-planning/legs/reorder` | **Sendungen innerhalb einer Partie umsortieren** (Legs innerhalb eines Lots) |
| `PUT` | `/api/pickup-planning/unassign` | Legs/Lots von einem Transportauftrag lösen |

---

## 3. Datenverträge (Data Contracts)

### 3.1 Tourpunkt-Typen

Definiert in `apps/nagel-cal-disposition/src/app/utils/tourPointsUtils.ts`:

| Wert | Typ |
|------|-----|
| 1 | Pickup (Ladestelle) |
| 3 | Delivery (Entladestelle) |
| 5 | Exchange of Carrier (Unternehmerwechsel) |
| 8 | Border Crossing (Grenzübergang) |
| 9 | Customs (Zoll) |
| 11 | Start |
| 12 | Finish |

Relation-Typen für Positionierung: `0`=first, `1`=last, `2`=after, `3`=before

### 3.2 Request/Response Bodies

#### Tourpunkt anlegen (`POST /api/pickup-planning/transportorders/tourpoint`)

Request:
```json
{
  "transportOrderId": 123,
  "tourPointType": 11,
  "name1": "string",
  "productType": null,
  "tourNumber": "string | null",
  "country": "string | null",
  "postalCode": "string | null",
  "city": "string | null",
  "streetAndHouseNumber": "string | null",
  "district": "string",
  "deliveryDateFrom": "ISO date | null",
  "deliveryDateTo": "ISO date | null",
  "deliveryTimeFrom": "ISO date | null",
  "deliveryTimeTo": "ISO date | null"
}
```

Response:
```json
{
  "IsTourpointAdded": true,
  "TourpointId": 456
}
```

#### Tourpunkt bearbeiten (`PUT /api/transportorders/tourpoints/{tourPointId}`)

Request:
```json
{
  "name1": "string",
  "tourNumber": "string",
  "country": "string",
  "postalCode": "string",
  "city": "string",
  "streetAndHouseNumber": "string",
  "district": "string"
}
```

Response:
```json
{
  "IsTourpointEdited": true
}
```

#### Tourpunkt löschen (`DELETE /api/pickup-planning/transportorders/tourpoint`)

Request:
```json
{
  "TourPointId": 456,
  "TransportOrderId": 123,
  "Mode": 11
}
```

Response:
```json
{
  "IsTourpointDeleted": true
}
```

#### Tourpunkte umsortieren (`PUT /api/pickup-planning/tourpoints/reorder`)

Request:
```json
{
  "SourceTransportOrderTix": 123,
  "SourceTourpointId": 456,
  "DestinationTourpointId": 789,
  "RelationType": 2,
  "Mode": null
}
```

#### Kunden-Tournummer setzen (`PATCH /api/transportorders/tourpoint/{tourPointId}/tournumber`)

Request:
```json
{
  "tourPointId": 456,
  "tourNumber": "string | null",
  "personNumber": 0
}
```

#### Ladeintervall setzen (`PUT /api/transportorders/tourpoints/{tourPointId}/loading-interval`)

Request:
```json
{
  "StartTime": "ISO datetime | null",
  "EndTime": "ISO datetime | null"
}
```

Response:
```json
{
  "isStartTimeSet": true,
  "isEndTimeSet": true
}
```

#### Ladeintervall entfernen (`DELETE /api/transportorders/tourpoints/{tourPointId}/loading-interval`)

Response:
```json
{
  "isDeleted": true
}
```

#### Partien umsortieren (`PUT /api/pickup-planning/lotassignments/reorder`)

Request:
```json
{
  "LotAssignmentId": "guid",
  "NewPickupTourPointOrder": 1,
  "TransportOrderId": 123
}
```

#### Sendungen innerhalb Partie umsortieren (`PUT /api/pickup-planning/legs/reorder`)

Request:
```json
{
  "LotAssignmentId": "guid",
  "LegId": "guid",
  "NewOrder": 1
}
```

#### Sendung zuweisen (`POST /api/pickup-planning/lotassignments/from-leg`)

Request:
```json
{
  "transportOrderId": 123,
  "legId": "guid",
  "lotAssignmentId": "guid",
  "destinationTourPointId": 456,
  "relationType": 2
}
```

#### Partie zuweisen (`POST /api/pickup-planning/lotassignments/from-lot`)

Request:
```json
{
  "transportOrderId": 123,
  "lotId": "guid",
  "destinationTourPointId": 456,
  "relationType": 2
}
```

#### Legs/Lots lösen (`PUT /api/pickup-planning/unassign`)

Request:
```json
{
  "LotAssignmentIds": ["guid1", "guid2"],
  "LegIds": ["guid3"],
  "TransportOrderId": 123
}
```

Response:
```json
{
  "Result": true,
  "Value": {
    "LotsResponse": [{ "Success": true, "Id": "guid1", "Error": null }],
    "LegsResponse": [{ "Success": true, "Id": "guid3", "Error": null }]
  }
}
```

#### Graph-Tourpunkte abrufen (`POST /api/pickup-planning/transportorders/graph-tour-points`)

Request:
```json
{
  "TransportOrderIds": [123, 456]
}
```

---

## 4. TypeScript-Interfaces (zentrale Datenmodelle)

### 4.1 TourPointDetails

Definiert in `apps/nagel-cal-disposition/src/models/orderDetails.ts` (Zeilen 197-243):

```typescript
export interface TourPointDetails {
    addressId: number;
    addressType: string;
    adviceAmount: number;
    branch: number;
    city: string;
    company: number;
    country: string;
    district: string;
    driveInstruction: string;
    floorPalletSpaces: number;
    frozenAmount: number;
    kind: number;
    latitude: number;
    longitude: number;
    match: string;
    name1: string | null;
    name2: string | null;
    name3: string | null;
    packageAmount: number;
    personId: string;
    personIndex: number;
    personNumber: number | null;
    personText: string | null;
    personType: string;
    plannedArrivalTime: string | null;
    plannedDepartureTime: string | null;
    targetEndTime: string | null;
    targetStartTime: string | null;
    postalCode: string;
    sequenceNumber: number;
    serviceArea: string;
    shipmentAmount: number;
    street: string;
    tourpointId: number;
    transportOrderId: number;
    type: number;
    volumePalletSpaces: number;
    weight: number;
    lotAssignmentIds: string[];
    tourNumber: string | null;
    formKey: number;
    isNew?: boolean;
    isEditableTourPoint?: boolean;
    distance: number | null;
    totalDuration: number | null;
}
```

### 4.2 TourPointConfig (Planning-View)

Definiert in `apps/nagel-cal-disposition/src/models/planningPageTypes.ts` (Zeilen 396-420):

```typescript
export interface TourPointConfig {
    tourpointId: number;
    type: number;
    sequenceNumber: number;
    trafficIcon: TrafficIconType;
    commaSeparatedLotAssignmentNumbers: string;
    name: string;
    street: string;
    country: string;
    postalCode: string;
    city: string;
    locationIdentifier: string;
    plannedArrivalTime: null;
    plannedDepartureTime: string | null;
    weight: number | null;
    floorPalletSpaces: number;
    floorPalletSpacesIdentifier: string;
    volumePalletSpaces: number;
    volumePalletSpacesIdentifier: string;
    uniqueClientsCount: number;
    uniqueTrafficFlowsCount: string;
    productGroups: object[];
    lotAssignmentCards: LotTourPointConfig[];
    infoChips?: InfoLotChip[];
}
```

### 4.3 LotTourPointConfig (Partien am Tourpunkt)

```typescript
export interface LotTourPointConfig {
    lotAssignmentId: string;
    number: number;
    legsCount: number;
    trafficIcon: string;
    pickupTourPointOrder: number;
    legCards: LegTourPointConfig[];
    checked?: boolean;
}
```

### 4.4 LegTourPointConfig (Sendungen innerhalb einer Partie)

```typescript
export interface LegTourPointConfig {
    legId: string;
    shipmentNumber: number;
    order: number;
    name: string | null;
    country: string | null;
    city: string | null;
    street: string | null;
    zipCode: string | null;
    locationIdentifier: string | null;
    weight: number | null;
    volumePalletSpaces: number | null;
    volumePalletSpacesIdentifier: string | null;
    floorPalletSpaces: number | null;
    floorPalletSpacesIdentifier: string | null;
    destinationCountry: string | null;
    consigneeServiceArea: string | null;
    serviceAreaIdentifier: string | null;
    fixedDeliveryDate: string | null;
    deliveryDateFrom: string | null;
    deliveryDateTo: string | null;
    pickupDateFrom: string | null;
    pickupDateTo: string | null;
    trafficIcon: string;
    infoChips: InfoLotChip[];
    checked?: boolean;
    staysLoaded?: boolean;
}
```

---

## 5. Service-Dateien (Referenz)

| Service | Datei |
|---------|-------|
| Manage Tour Points | `apps/nagel-cal-disposition/src/app/services/manage-tour-points.service.ts` |
| Drive Instructions Drawer | `apps/nagel-cal-disposition/src/app/services/drive-instructions-drawer.service.ts` |
| Reorder Drag & Drop | `apps/nagel-cal-disposition/src/app/services/reorder-drag-and-drop.service.ts` |
| Assignment Requests | `apps/nagel-cal-disposition/src/app/services/assignment-requests.service.ts` |
| Graph Tour Points | `apps/nagel-cal-disposition/src/app/services/graph-tour-points.service.ts` |
| Planning Drag & Drop | `apps/nagel-cal-disposition/src/app/services/planning-drag-and-drop.service.ts` |

---

## 6. Datenmodell-Dateien (Referenz)

| Modell | Datei |
|--------|-------|
| TourPointDetails, Loading Interval DTOs | `apps/nagel-cal-disposition/src/models/orderDetails.ts` |
| Create/Edit/Delete Tour Point Types | `apps/nagel-cal-disposition/src/models/tourPointTypes.ts` |
| TourPointConfig, LotTourPointConfig, LegTourPointConfig, TransportOrder | `apps/nagel-cal-disposition/src/models/planningPageTypes.ts` |
| Assignment Request/Response Types | `apps/nagel-cal-disposition/src/models/assignmentsTypes.ts` |
| Tour Point Type Constants & Utilities | `apps/nagel-cal-disposition/src/app/utils/tourPointsUtils.ts` |
| Endpoint-Konstanten | `apps/nagel-cal-disposition/src/app/configuration/consts/endpoints.ts` |
