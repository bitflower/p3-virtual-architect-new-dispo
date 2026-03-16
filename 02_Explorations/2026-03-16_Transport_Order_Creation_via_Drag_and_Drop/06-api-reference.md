# Transport Order Creation - API Reference

**Date:** 2026-03-16
**Focus:** HTTP endpoints, request/response formats, and cURL examples
**Document Series:** Part 6 of 6

---

## Overview

This document provides a complete reference for all HTTP endpoints related to transport order creation via drag and drop.

**Base URL:** `{environment.apiUrl}/api/transport-order-planning`

---

## Endpoints

### 1. Create Transport Order from Lot

Creates a transport order from an entire lot (multiple legs).

---

#### Endpoint Details

**URL:** `/api/transport-order-planning/transportorders/from-lot`
**Method:** `POST`
**Authentication:** Required (via database identifier header)
**Content-Type:** `application/json`

---

#### Request Body

```json
{
  "lotId": "123e4567-e89b-12d3-a456-426614174000",
  "performanceDate": "2026-03-16T10:00:00.000Z"
}
```

**Fields:**
- `lotId` (Guid, required) - The ID of the lot to convert into a transport order
- `performanceDate` (DateTime, required) - The scheduled start date/time for the transport order (ISO 8601 format)

---

#### Response Body (Success - 201 Created)

```json
{
  "transportOrderId": 123456789
}
```

**Fields:**
- `transportOrderId` (long) - The TMS ID of the newly created transport order

---

#### Response Body (Error - 404 Not Found)

```json
{
  "message": "Lot with id: 123e4567-e89b-12d3-a456-426614174000 was not found!"
}
```

---

#### cURL Example

```bash
curl -X POST "https://api.example.com/api/transport-order-planning/transportorders/from-lot" \
  -H "Content-Type: application/json" \
  -H "Database-Identifier: BRANCH_KEY_001" \
  -d '{
    "lotId": "123e4567-e89b-12d3-a456-426614174000",
    "performanceDate": "2026-03-16T10:00:00.000Z"
  }'
```

---

#### TypeScript Example

```typescript
const response = await this.requestService.postRequest<
  CreateTransportOrderRequest,
  CreateTransportOrderResponse
>(
  `${environment.apiUrl}/api/transport-order-planning/transportorders/from-lot`,
  {
    lotId: "123e4567-e89b-12d3-a456-426614174000",
    performanceDate: "2026-03-16T10:00:00.000Z"
  }
);

console.log(`Created transport order: ${response.transportOrderId}`);
```

---

#### HTTP Status Codes

| Code | Description |
|------|-------------|
| **201** | Transport order successfully created |
| **400** | Bad request (invalid lotId format or performanceDate) |
| **404** | Lot not found |
| **500** | Internal server error (TMS communication failure, database error) |

---

### 2. Create Transport Order from Single Leg

Creates a transport order from a single leg.

---

#### Endpoint Details

**URL:** `/api/transport-order-planning/transportorders/from-leg`
**Method:** `POST`
**Authentication:** Required (via database identifier header)
**Content-Type:** `application/json`

---

#### Request Body

```json
{
  "legId": "987e6543-e21b-45d3-a789-123456789abc",
  "performanceDate": "2026-03-16T10:00:00.000Z"
}
```

**Fields:**
- `legId` (Guid, required) - The ID of the leg to convert into a transport order
- `performanceDate` (DateTime, required) - The scheduled start date/time for the transport order (ISO 8601 format)

---

#### Response Body (Success - 201 Created)

```json
{
  "transportOrderId": 123456790
}
```

**Fields:**
- `transportOrderId` (long) - The TMS ID of the newly created transport order

---

#### Response Body (Error - 404 Not Found)

```json
{
  "message": "Leg with id: 987e6543-e21b-45d3-a789-123456789abc was not found!"
}
```

---

#### cURL Example

```bash
curl -X POST "https://api.example.com/api/transport-order-planning/transportorders/from-leg" \
  -H "Content-Type: application/json" \
  -H "Database-Identifier: BRANCH_KEY_001" \
  -d '{
    "legId": "987e6543-e21b-45d3-a789-123456789abc",
    "performanceDate": "2026-03-16T10:00:00.000Z"
  }'
```

---

#### HTTP Status Codes

| Code | Description |
|------|-------------|
| **201** | Transport order successfully created |
| **400** | Bad request (invalid legId format or performanceDate) |
| **404** | Leg not found |
| **500** | Internal server error (TMS communication failure, database error) |

---

### 3. Assign Leg to Existing Transport Order

Adds a single leg to an existing transport order.

---

#### Endpoint Details

**URL:** `/api/transport-order-planning/transportorders/{transportOrderId}/legs/{legId}`
**Method:** `PUT`
**Authentication:** Required (via database identifier header)
**Content-Type:** `application/json`

---

#### URL Parameters

- `transportOrderId` (long) - The TMS ID of the transport order
- `legId` (Guid) - The ID of the leg to add

---

#### Request Body

```json
{
  "performanceDate": "2026-03-16T10:00:00.000Z"
}
```

**Fields:**
- `performanceDate` (DateTime, optional) - Updates the performance date if provided

---

#### Response Body (Success - 200 OK)

```json
{
  "success": true,
  "message": "Leg successfully added to transport order"
}
```

---

#### cURL Example

```bash
curl -X PUT "https://api.example.com/api/transport-order-planning/transportorders/123456789/legs/987e6543-e21b-45d3-a789-123456789abc" \
  -H "Content-Type: application/json" \
  -H "Database-Identifier: BRANCH_KEY_001" \
  -d '{
    "performanceDate": "2026-03-16T10:00:00.000Z"
  }'
```

---

#### HTTP Status Codes

| Code | Description |
|------|-------------|
| **200** | Leg successfully added to transport order |
| **400** | Bad request (invalid ID format) |
| **404** | Transport order or leg not found |
| **500** | Internal server error |

---

### 4. Assign Lot to Existing Transport Order

Adds all legs from a lot to an existing transport order.

---

#### Endpoint Details

**URL:** `/api/transport-order-planning/transportorders/{transportOrderId}/lots/{lotId}`
**Method:** `PUT`
**Authentication:** Required (via database identifier header)
**Content-Type:** `application/json`

---

#### URL Parameters

- `transportOrderId` (long) - The TMS ID of the transport order
- `lotId` (Guid) - The ID of the lot to add

---

#### Request Body

```json
{
  "performanceDate": "2026-03-16T10:00:00.000Z"
}
```

**Fields:**
- `performanceDate` (DateTime, optional) - Updates the performance date if provided

---

#### Response Body (Success - 200 OK)

```json
{
  "success": true,
  "message": "Lot successfully added to transport order",
  "legsAdded": 3
}
```

---

#### cURL Example

```bash
curl -X PUT "https://api.example.com/api/transport-order-planning/transportorders/123456789/lots/123e4567-e89b-12d3-a456-426614174000" \
  -H "Content-Type: application/json" \
  -H "Database-Identifier: BRANCH_KEY_001" \
  -d '{
    "performanceDate": "2026-03-16T10:00:00.000Z"
  }'
```

---

#### HTTP Status Codes

| Code | Description |
|------|-------------|
| **200** | Lot successfully added to transport order |
| **400** | Bad request (invalid ID format) |
| **404** | Transport order or lot not found |
| **500** | Internal server error |

---

### 5. Trigger Manual Route Calculation

Manually triggers route optimization for a transport order.

---

#### Endpoint Details

**URL:** `/api/transportorders/{transportOrderId}/calculate-routes`
**Method:** `POST`
**Authentication:** Required (via database identifier header)
**Content-Type:** `application/json`

---

#### URL Parameters

- `transportOrderId` (long) - The TMS ID of the transport order

---

#### Request Body

```json
{
  "silent": false
}
```

**Fields:**
- `silent` (boolean, optional) - If true, suppresses UI notifications. Default: false

---

#### Response Body (Success - 200 OK)

```json
{
  "success": true,
  "message": "Route calculation completed successfully",
  "optimizedTourPoints": 5
}
```

---

#### cURL Example

```bash
curl -X POST "https://api.example.com/api/transportorders/123456789/calculate-routes" \
  -H "Content-Type: application/json" \
  -H "Database-Identifier: BRANCH_KEY_001" \
  -d '{
    "silent": false
  }'
```

---

#### HTTP Status Codes

| Code | Description |
|------|-------------|
| **200** | Route calculation completed |
| **202** | Route calculation initiated (async processing) |
| **404** | Transport order not found |
| **500** | Internal server error (xServer communication failure) |

---

## Data Transfer Objects (DTOs)

### CreateTransportOrderFromLotRequestDto

```csharp
public class CreateTransportOrderFromLotRequestDto
{
  public Guid LotId { get; set; }
  public DateTime PerformanceDate { get; set; }
}
```

---

### CreateTransportOrderFromLotResponseDto

```csharp
public class CreateTransportOrderFromLotResponseDto
{
  public long TransportOrderId { get; set; }
}
```

---

### CreateTransportOrderFromLegRequestDto

```csharp
public class CreateTransportOrderFromLegRequestDto
{
  public Guid LegId { get; set; }
  public DateTime PerformanceDate { get; set; }
}
```

---

### CreateTransportOrderFromLegResponseDto

```csharp
public class CreateTransportOrderFromLegResponseDto
{
  public long TransportOrderId { get; set; }
}
```

---

## Common Headers

All requests require the following headers:

| Header | Description | Example |
|--------|-------------|---------|
| **Content-Type** | Request content type | `application/json` |
| **Database-Identifier** | Branch/database identifier | `BRANCH_KEY_001` |
| **Authorization** | Bearer token (if applicable) | `Bearer eyJ0eXAiOiJKV1QiLCJhb...` |

---

## Error Response Format

All error responses follow a consistent format:

```json
{
  "message": "Error description",
  "errorCode": "ERROR_CODE",
  "details": {
    "field": "Additional context"
  }
}
```

---

## Rate Limiting

**Note:** The tour calculation endpoints may be subject to rate limiting to prevent excessive xServer API calls.

**Recommended Practice:**
- Use the frontend debounce mechanism (3-second delay)
- Avoid calling calculate-routes repeatedly
- Let automatic calculation handle most scenarios

---

## Best Practices

### 1. Performance Date Format

Always use ISO 8601 format with timezone:
```
2026-03-16T10:00:00.000Z
```

### 2. Error Handling

Always check for the following:
- 404 errors (lot/leg not found)
- 500 errors (TMS communication failure)
- Implement retry logic for transient failures

### 3. Tour Calculation

- Automatic tour calculation is triggered after creation
- Manual recalculation is debounced (3 seconds)
- Tour calculation failures don't block transport order creation

---

## Integration Examples

### Full Create Flow (TypeScript)

```typescript
// 1. Create transport order
const createResponse = await this.createTransportOrder(
  lotId,
  performanceDate
);

// 2. Wait for UI refresh
await this.refreshTransportOrderList();

// 3. (Optional) Trigger silent recalculation after 3 seconds
setTimeout(() => {
  this.calculateRoutes(createResponse.transportOrderId, true);
}, 3000);
```

---

### Full Create Flow (C#)

```csharp
// 1. Create command
var command = new CreateTransportOrderFromLotCommand(
  new CreateTransportOrderFromLotRequestDto
  {
    LotId = lotId,
    PerformanceDate = performanceDate
  },
  databaseIdentifier
);

// 2. Send to handler via MediatR
var response = await _mediator.Send(command);

// 3. Tour calculation is automatic (non-blocking)
// No additional steps needed

return response.TransportOrderId;
```

---

## See Also

- **[Overview and Flow](./01-overview-and-flow.md)** - High-level sequence diagram
- **[Frontend Implementation](./02-frontend-implementation.md)** - Angular drag & drop UI
- **[Backend Implementation](./03-backend-implementation.md)** - Command handlers and business logic
- **[TMS Integration](./04-tms-integration.md)** - GraphQL mutations and TMS functions
- **[Data Model Transformations](./05-data-model-transformations.md)** - Entity relationships and state transitions
