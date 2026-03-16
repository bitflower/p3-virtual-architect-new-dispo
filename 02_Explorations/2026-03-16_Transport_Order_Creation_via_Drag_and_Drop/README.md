# Transport Order Creation via Drag & Drop

**Date:** 2026-03-16
**Status:** Documentation Complete
**Context:** New Dispo dispatcher planning workflow

---

## What This Documents

This exploration documents the complete flow for creating transport orders in the New Dispo system through the dispatcher's drag-and-drop interface. When a dispatcher drags a lot or leg from the unplanned area and drops it on the "Create Transport Order" zone, the following occurs:

1. ✅ Transport order is created in TMS
2. ✅ Legs are assigned to the transport order
3. ✅ Tour calculation is automatically triggered (xServer optimization)
4. ✅ UI is refreshed with the new transport order

---

## Document Structure

This exploration is split into **6 focused documents** for easy navigation and maintenance:

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

## Quick Navigation by Role

### 👨‍💼 **Product Owner / Business Analyst**
Start with: [01. Overview & Flow](./01-overview-and-flow.md)

### 🎨 **Frontend Developer**
Go to: [02. Frontend Implementation](./02-frontend-implementation.md)
Then check: [06. API Reference](./06-api-reference.md)

### ⚙️ **Backend Developer**
Go to: [03. Backend Implementation](./03-backend-implementation.md)
Then check: [04. TMS Integration](./04-tms-integration.md)

### 🗄️ **Database / Integration Specialist**
Go to: [04. TMS Integration](./04-tms-integration.md)
Then check: [05. Data Model & Transformations](./05-data-model-transformations.md)

### 🧪 **Tester / QA**
Go to: [06. API Reference](./06-api-reference.md)
Then read: [01. Overview & Flow](./01-overview-and-flow.md)

### 🏗️ **Solution Architect**
Read in order: 01 → 03 → 04 → 05

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
- **Last Updated:** 2026-03-16
- **Maintained By:** Virtual Architect Team
- **Update Policy:** Update individual documents when code changes occur in their respective layers

---

## Quick Links

- [Overview & Flow](./01-overview-and-flow.md)
- [Frontend Implementation](./02-frontend-implementation.md)
- [Backend Implementation](./03-backend-implementation.md)
- [TMS Integration](./04-tms-integration.md)
- [Data Model & Transformations](./05-data-model-transformations.md)
- [API Reference](./06-api-reference.md)
