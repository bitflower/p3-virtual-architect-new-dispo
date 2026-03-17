# Transport Order Creation Flow

**Date:** 2026-03-16
**Status:** Documentation Complete
**Context:** New Dispo dispatcher planning workflow

---

## What This Documents

This exploration documents the complete flow for creating transport orders in the New Dispo system. When a dispatcher drags a lot or leg from the unplanned area and drops it on the "Create Transport Order" zone, the following occurs:

1. ✅ Transport order is created in TMS
2. ✅ Legs are assigned to the transport order
3. ✅ Tour calculation is automatically triggered (xServer optimization)
4. ✅ UI is refreshed with the new transport order
5. ✅ Error handling and retry mechanisms for TMS synchronization failures
6. ✅ Idempotency guarantees for safe retry operations

---

## Document Structure

This exploration is split into **8 focused documents** for easy navigation and maintenance:

### 📖 [01. Overview & Flow](./01-overview-and-flow.md)
**Audience:** Product owners, architects, new team members

High-level overview of the complete flow:
- Executive summary
- Complete sequence diagram
- Step-by-step flow description (no code)
- User journey from dispatcher perspective
- Key concepts and terminology

**Start here** if you want to understand what happens when a dispatcher creates a transport order.

---

### 💻 [02. Frontend Implementation](./02-frontend-implementation.md)
**Audience:** Frontend developers (Angular/TypeScript)

Deep dive into the Angular frontend:
- Drag & drop UI (Angular CDK)
- Component structure (`planning-list`, `create-transport-order-dialog`)
- Service layer and API integration
- State management and refresh logic
- TypeScript code with explanations

**Read this** if you need to modify or debug the frontend drag-and-drop behavior.

---

### ⚙️ [03. Backend Implementation](./03-backend-implementation.md)
**Audience:** Backend developers (C#/.NET)

Detailed backend implementation:
- Controller endpoints
- CQRS command handlers with full code
- Business logic (transport mode determination, leg mapping)
- Tour calculation service (RecalculateRouteService)
- Error handling patterns
- Code snippets with line numbers

**Read this** if you need to modify backend logic or add new features.

---

### 🔗 [04. TMS Integration](./04-tms-integration.md)
**Audience:** Integration specialists, TMS experts

TMS Bridge and database integration:
- GraphQL mutation structure
- Batch mutation pattern (`@export` variables)
- TMS stored functions (`pdis_transportorder.*`)
- Request/response mapping
- Transaction handling

**Read this** if you work on TMS Bridge or need to understand TMS communication.

---

### 🗄️ [05. Data Model & Transformations](./05-data-model-transformations.md)
**Audience:** Database designers, architects

Entity structure and transformations:
- Entity relationship diagrams
- LotEntity → LotAssignmentEntity transformation
- LotAssignmentLegLinkEntity structure
- Before/after database state
- Why original lots are deleted

**Read this** if you need to understand data persistence or database schema.

---

### 📋 [06. API Reference](./06-api-reference.md)
**Audience:** API consumers, testers, integrators

Quick reference for all endpoints:
- Endpoint URLs and HTTP methods
- Request/Response DTOs with examples
- HTTP status codes
- Error responses
- cURL examples for testing

**Read this** if you need to integrate with the API or write tests.

---

### ⚠️ [07. TMS Sync Error Handling Decision](./tms-sync-error-handling-decision.md)
**Audience:** Solution architects, technical leads, product owners

Decision paper for error handling strategy:
- Three failure scenarios (local DB failure, early Bridge failure, network interruption)
- Three architectural approaches (manual recovery, outbox pattern, event-driven)
- Comparison matrix and trade-offs
- Implementation recommendations for June 2026 release
- Post-release migration path

**Read this** if you need to understand error handling strategy or implement retry mechanisms.

---

### 🔒 [08. Idempotency Analysis](./idempotency-analysis.md)
**Audience:** Backend developers, integration specialists

Detailed idempotency verification:
- TMS database operation analysis
- `PTA.HASSEN()` duplicate check mechanism
- Transport order creation idempotency constraints
- Safe retry implementation patterns
- State-checking logic for reconciliation

**Read this** if you need to implement retry logic or verify TMS operation safety.

---

## Quick Navigation by Role

### 👨‍💼 **Product Owner / Business Analyst**
Start with: [01. Overview & Flow](./01-overview-and-flow.md)

### 🎨 **Frontend Developer**
Go to: [02. Frontend Implementation](./02-frontend-implementation.md)
Then check: [06. API Reference](./06-api-reference.md)

### ⚙️ **Backend Developer**
Go to: [03. Backend Implementation](./03-backend-implementation.md)
Then check: [04. TMS Integration](./04-tms-integration.md)
For error handling: [07. TMS Sync Error Handling](./tms-sync-error-handling-decision.md)
For retry logic: [08. Idempotency Analysis](./idempotency-analysis.md)

### 🗄️ **Database / Integration Specialist**
Go to: [04. TMS Integration](./04-tms-integration.md)
Then check: [05. Data Model & Transformations](./05-data-model-transformations.md)
Then read: [08. Idempotency Analysis](./idempotency-analysis.md)

### 🧪 **Tester / QA**
Go to: [06. API Reference](./06-api-reference.md)
Then read: [01. Overview & Flow](./01-overview-and-flow.md)
For error scenarios: [07. TMS Sync Error Handling](./tms-sync-error-handling-decision.md)

### 🏗️ **Solution Architect**
Read in order: 01 → 03 → 04 → 05 → 07 → 08

---

## Related Documentation

### Pre-Existing Diagrams
- **`07_Diagrams/pickup-planning-create-transport-order-from-lot.wsd`** - Original PlantUML sequence diagram (this exploration expands on it)

### Related Explorations
- **Leg/Lot Creation Flow** - How shipments become legs and get grouped into lots (prerequisite to this flow)
  `02_Explorations/2026-03-16_Document_and_visualize_the_flow_of_Creating_and_adding_legslots_end_to_end/`

- **Shipment Data Flow** - Complete CDC and batch pipeline architecture
  `08_Documentation/2026-02-26_leg-lot-creation-table-sendung/shipment-data-flow-architecture.md`

---

## Original Full Document

The complete, unsplit documentation is preserved in:
- **`00-ORIGINAL-FULL-DOCUMENT.md`** (for reference or searching)

---

## Key Technologies

| Layer | Technologies |
|-------|-------------|
| **Frontend** | Angular 19, TypeScript, Angular CDK Drag & Drop, Material Design |
| **Backend** | .NET 8, C#, MediatR (CQRS), Entity Framework Core, AutoMapper |
| **Integration** | GraphQL (Hot Chocolate), REST API |
| **Database** | PostgreSQL (Backend), AlloyDB (TMS) |
| **Tour Optimization** | xServer (PTV), TOP Service |

---

## Document Maintenance

- **Created:** 2026-03-16
- **Last Updated:** 2026-03-17
- **Maintained By:** Virtual Architect Team
- **Update Policy:** Update individual documents when code changes occur in their respective layers
- **Recent Changes:** Added TMS sync error handling and idempotency analysis documents

---

## Quick Links

- [Overview & Flow](./01-overview-and-flow.md)
- [Frontend Implementation](./02-frontend-implementation.md)
- [Backend Implementation](./03-backend-implementation.md)
- [TMS Integration](./04-tms-integration.md)
- [Data Model & Transformations](./05-data-model-transformations.md)
- [API Reference](./06-api-reference.md)
- [TMS Sync Error Handling Decision](./tms-sync-error-handling-decision.md)
- [Idempotency Analysis](./idempotency-analysis.md)
