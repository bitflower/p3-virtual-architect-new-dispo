# Driver Terminal TMS Integration

**Date:** 2026-04-29
**Status:** Exploration

---

## Original User Input

> **Mission:** Clarify the used endpoints of the TMS Proxy by the Driver Terminal Backend.
>
> **Entry point:** Swagger UI screenshot showing "CAL TMS Mock Transport order" controller with 6 endpoints:

![Swagger Mock Endpoints](swagger-mock-endpoints.png)

---

## Summary

The Driver Terminal Backend uses a **two-tier Feign client architecture** to call the TMS Proxy. Internal services (`svc-pp-core-service`, `svc-worker-service`) call into `svc-tms-service`, which then calls the **real CAL TMS Proxy** via the `CalClient` Feign interface. The `svc-tms-cal-mock` module provides a local mock implementation of the same 6 endpoints for development/testing.

## Architecture

```
svc-pp-core-service / svc-worker-service
    |
    | OutboundTmsApiServiceClient (Feign)
    v
svc-tms-service (OutboundTransportOrderController)
    |
    | OutboundTransportOrderService
    v
CalClient (Feign -> ${CAL_SERVICE_BASE_URL})
    |
    v
Real CAL TMS Proxy
```

## Mock Controller (Entry Point)

**File:** `Code/Driver-Terminal/Self-Service-Terminal-Backend/svc-tms-cal-mock/src/main/java/com/p3ds/sst/tms/cal/mock/service/controller/TransportOrderController.java`

Implements the same 6 endpoints with simulated delays for local development:

| Endpoint | Method | Line |
|---|---|---|
| `GET /GetTransportOrderById` | `getTransportOrderByCalId()` | 57 |
| `GET /GetTransportOrderDocuments` | `getTransportOrderDocuments()` | 113 |
| `GET /GetTransportOrderInfosFromInterval` | `getTransportOrders()` | 37 |
| `POST /SignTransportOrder` | `signTransportOrder()` | 97 |
| `POST /SubmitArchiveId` | `submitArchiveId()` | 135 |
| `POST /UpdateTransportOrder` | `updateTransportOrderByCalId()` | 79 |

## Real TMS Proxy Client (CalClient)

**File:** `Code/Driver-Terminal/Self-Service-Terminal-Backend/svc-tms-service/src/main/java/com/p3ds/sst/tms/service/client/CalClient.java`

Feign client targeting `${CAL_SERVICE_BASE_URL}` with `CalClientConfiguration` for auth/timeout handling.

| TMS Proxy Endpoint | CalClient Method | Line | Auth | Notes |
|---|---|---|---|---|
| `GET /GetTransportOrderById` | `getTransportOrderById()` | 18 | Authorization header | Query: ID, terminalId |
| `POST /UpdateTransportOrder` | `updateTransportOrder()` | 27 | Authorization header | Body: UpdateActionDto |
| `POST /SignTransportOrder` | `signTransportOrderDocument()` | 35 | Authorization header | Body: CalTmsSignActionDto |
| `GET /GetTransportOrderDocuments` | `getDocument()` | 43 | Authorization header | Query: ID, terminalId |
| `GET /GetTransportOrderInfosFromInterval` | `getTransportOrdersForDateInterval()` | 51 | Authorization header | Query: intervalStart, intervalEnd, terminalId |
| `POST /SubmitArchiveId` | `submitArchiveId()` | 61 | Authorization header | Body: SubmitArchiveIdActionDto |

All CalClient methods support custom timeout options via `CalTimeoutProperties`.

## Tier 1: Internal API (OutboundTmsApiServiceClient)

**File:** `Code/Driver-Terminal/Self-Service-Terminal-Backend/common-tms-service-api/src/main/java/com/p3ds/sst/tms/service/common/client/OutboundTmsApiServiceClient.java`

Feign client targeting `${TMS_API_SERVICE_BASE_URL}` — used by internal services to reach `svc-tms-service`.

| Internal Endpoint | Maps to CalClient Call | Line |
|---|---|---|
| `POST /outbound/transport-orders` | `updateTransportOrder()` | 18 |
| `POST /outbound/transport-orders/{id}/documents/sign` | `signTransportOrderDocument()` | 26 |
| `GET /outbound/transport-orders/{id}/documents` | `getDocument()` | 35 |
| `GET /outbound/transport-orders/{id}` | `getTransportOrderById()` | 45 |
| `GET /outbound/transport-orders` | `getTransportOrdersForDateInterval()` | 52 |
| `POST /outbound/transport-orders/qr-code` | `submitArchiveId()` | 58 |
| `GET /test/transport-orders` | (test endpoint) | 66 |

## Integration Service (svc-tms-service)

**Controller:** `Code/Driver-Terminal/Self-Service-Terminal-Backend/svc-tms-service/src/main/java/com/p3ds/sst/tms/service/controller/outbound/OutboundTransportOrderController.java`

**Service:** `Code/Driver-Terminal/Self-Service-Terminal-Backend/svc-tms-service/src/main/java/com/p3ds/sst/tms/service/service/outbound/OutboundTransportOrderService.java`

Bridges Tier 1 to CalClient with request/response mapping and authorization token injection via `CalAccessTokenService`.

## Consumers

### svc-pp-core-service
**File:** `Code/Driver-Terminal/Self-Service-Terminal-Backend/svc-pp-core-service/src/main/java/com/p3ds/sst/pp/core/service/service/outbound/OutboundTransportOrderService.java`

Calls: `updateTransportOrder`, `signTransportOrderDocument`, `getTransportOrderSignedDocument`, `getTransportOrderFromCal`, `fetchTransportOrders`, `sendQrCode`, `fetchTestTransportOrders`

### svc-worker-service
**File:** `Code/Driver-Terminal/Self-Service-Terminal-Backend/svc-worker-service/src/main/java/com/p3ds/sst/worker/service/services/DocumentWorkerService.java`

Calls: `getTransportOrderSignedDocument` (polling for signed documents)

## Configuration

| Service | Property | Env Variable |
|---|---|---|
| svc-tms-service | `cal.service.base.url` | `CAL_SERVICE_BASE_URL` |
| svc-pp-core-service | `tms.api.service.base.url` | `TMS_API_SERVICE_BASE_URL` |
| svc-worker-service | `tms.api.service.base.url` | `TMS_API_SERVICE_BASE_URL` |

## Questions/Open Items

- What is the actual value of `CAL_SERVICE_BASE_URL` in production? Does it point to the TMS Proxy or directly to the CAL TMS?
- The `POST /outbound/transport-orders/qr-code` endpoint internally maps to `CalClient.submitArchiveId()` — is this the intended semantic?
- Are there additional TMS Proxy endpoints not consumed by the Driver Terminal?
