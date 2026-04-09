# Transactional State Verification - Project Status

**Start Date:** 2026-04-08  
**Last Updated:** 2026-04-09

---

## Overview

Systematic analysis of all Dispo-TMS touchpoints to identify state changes and generate idempotency verification queries for each flow.

---

## Progress Tracker

> **Source:** Technical PBI 123794: [Backend] Create holistic list of all New Dispo <> TMS touchpoints

| # | Command Handler / Flow | Status | Analysis Document | Date Completed |
|---|------------------------|--------|-------------------|----------------|
| 1 | CreateTransportOrderFromLegCommandHandler | :hourglass: Pending Approval | [01-CreateTransportOrderFromLeg.md](./01-CreateTransportOrderFromLeg.md) | 2026-04-08 |
| 2 | CreateTransportOrderFromLotCommandHandler | :hourglass: Pending Approval | [02-CreateTransportOrderFromLot.md](./02-CreateTransportOrderFromLot.md) | 2026-04-08 |
| 3 | AssignLegToTransportOrderCommandHandler | :hourglass: Pending Approval | [03-AssignLegToTransportOrder.md](./03-AssignLegToTransportOrder.md) | 2026-04-09 |
| 4 | AssignLotToTransportOrderCommandHandler | :hourglass: Pending Approval | [04-AssignLotToTransportOrder.md](./04-AssignLotToTransportOrder.md) | 2026-04-09 |
| 5 | UnassignLotsSubHandler | :hourglass: Pending Approval | [05-UnassignLots.md](./05-UnassignLots.md) | 2026-04-09 |
| 6 | UnassignLegsSubHandler | :hourglass: Pending Approval | [06-UnassignLegs.md](./06-UnassignLegs.md) | 2026-04-09 |
| 7 | DeleteTransportOrderCommandHandler | :hourglass: Pending Approval | [07-DeleteTransportOrder.md](./07-DeleteTransportOrder.md) | 2026-04-09 |

**Progress:** 7 / 7 flows analyzed (100%) - all pending approval

---

## Touchpoints Detail

### Command Handlers

| # | Handler | Sub-Handlers | TMS Bridge GraphQL Calls | Dispo DB Changes |
|---|---------|--------------|--------------------------|------------------|
| 1 | `CreateTransportOrderFromLegCommandHandler` | CreateTransportOrderFromLegSubHandler | `CallCreateTransportOrderFromLeg` | Creates `LotAssignmentEntity`, `LotAssignmentLegLinkEntity` |
| 2 | `CreateTransportOrderFromLotCommandHandler` | CreateTransportOrderFromLotSubHandler | `CallCreateTransportOrderFromLeg` (first leg), `CallCreateAndAddLeg` (remaining legs) | Creates `LotAssignmentEntity`, `LotAssignmentLegLinkEntity` |
| 3 | `AssignLegToTransportOrderCommandHandler` | AssignLegToTransportOrderSubHandler, AssignLegAndMoveTourPointsSubHandler | `CallCreateAndAddLeg`, `CallMoveTourPoint` (via Batch API) | Creates/Updates `LotAssignmentEntity`, `LotAssignmentLegLinkEntity` |
| 4 | `AssignLotToTransportOrderCommandHandler` | AssignLotToTransportOrderSubHandler, AssignLotAndMoveTourPointsSubHandler | `CallCreateAndAddLeg` (n legs), `CallMoveTourPoint` (n legs via Batch API) | Creates `LotAssignmentEntity`, `LotAssignmentLegLinkEntity` |
| 5 | `UnassignLotsSubHandler` | RemoveTmsLotsSubHandler | `CallRemoveLeg` (n legs via Batch API) | Removes `LotAssignmentEntity` |
| 6 | `UnassignLegsSubHandler` | RemoveTmsLegsSubHandler | `CallRemoveLeg` (n legs) | Removes `LotAssignmentLegLinkEntity` |
| 7 | `DeleteTransportOrderCommandHandler` | DeleteTransportOrderSubHandler | `CallDeleteTransportOrder` | Moves leg to suitable lot, Removes `LotAssignmentEntity`, `LotAssignmentLegLinkEntity` |

---

### TMS Bridge GraphQL Mutations

| Mutation | Input Parameters | Output Parameters |
|----------|------------------|-------------------|
| `CallCreateTransportOrderFromLeg` | company, branch, performanceDate, transportMode, regionId, shipmentId, legType | TransportOrderId, LegId, PickupPointId, IsNewPickupPoint, DeliveryPointId, IsNewDeliveryPoint |
| `CallCreateAndAddLeg` | transportOrderId, shipmentId, legType | PickupPointId, IsNewPickupPoint, DeliveryPointId, IsNewDeliveryPoint, LegId |
| `CallMoveTourPoint` | mode, relationType, destinationTourpointId, sourceTourpointId, sourceTransportOrderTix | isTourpointMoved |
| `CallRemoveLeg` | transportOrderId, legId, mode | isLegRemoved |
| `CallDeleteTransportOrder` | transportOrderId | isDeleted, transportOrderId |

---

<!-- internal -->
## Analysis Approach

For each flow, the `transactional-state-verifier` agent will:

1. **Trace State Changes** - Identify what tables/entities are modified in TMS Database
2. **Map to Views** - Find verification views (V_DIS_*) that expose the state
3. **Generate Queries** - Create idempotency verification queries
4. **Document** - Produce analysis document with diagrams
<!-- /internal -->

---

<!-- internal -->
## Notes

- All handlers interact with TMS through the **TMS Bridge GraphQL API**
- State is written to **TMS Database** (AlloyDB) via PL/pgSQL packages (pDIS_*, pTA_*)
- Verification is done through **V_DIS_*** views that expose the state
- Dispo Database (Backend) maintains **LotAssignmentEntity** and **LotAssignmentLegLinkEntity** as local state mirrors
<!-- /internal -->
