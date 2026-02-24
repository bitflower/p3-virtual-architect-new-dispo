**PBI**: #120990
**WHO**: As a dispatcher, I want to unassign a trailer, vehicle, contractor, or carrier from a Transport Order so that I can undo previous assignments when necessary.

**Description**: Allows dispatchers to **unassign key resources** (Contractor, Carrier, Vehicle, Trailer) from a Transport Order. Removing a Contractor also removes the associated Carrier; all other removals affect only the targeted entity. Once unassigned, the Transport Order detail view is updated immediately to reflect the changes, without requiring a page refresh.

**Actors**: Dispatcher.

**Triggers**:
*   User initiates the unassignment action for a Contractor, Carrier, Vehicle, or Trailer from the Transport Order.

**Preconditions**:
*   A valid Transport Order exists with one or more assigned entities (Contractor, Carrier, Vehicle, Trailer).
*   The user has permission to modify the order.

**Postconditions**:
*   The following cascading logic applies:
    *   Removing **Contractor** removes Contractor and Carrier.
    *   Removing **Carrier** removes only the Carrier.
    *   Removing **Vehicle** removes only the Vehicle.
    *   Removing **Trailer** removes only the Trailer.
*   The UI reflects all changes immediately without manual refresh.

**Technical Solution:**

> **Note:** `RemoveParticipant` is only available in the NEW-DISPO branch (`release/7.0.0.8+NEW-DISPO`).

#### TMS Core Changes (Joachim)

Joachim will modify the core functions so that cascading deletions of Vehicle and Trailer no longer occur:

- `pta.remunt` will **no longer** call `pta.remlkw` / `pta.remanh` — Vehicle and Trailer are preserved when removing a Contractor or Carrier. This is controlled via an internal flag that is not externally settable for now.
- `pta.remlkw` will **no longer** call `pta.remanh` — Trailer is preserved when removing a Vehicle.
- `pta.remunt` does **not** remove the Carrier (`FRF`) — this must be handled by P3 explicitly. No transactional boundary is required on the database side, so the two calls can be orchestrated either in a database wrapper or sequentially from the backend.

#### P3 Procedures

Procedures in `pDIS_TransportOrder`, wrapping core `pTA.*` functions:

```sql
-- Remove Participant (Contractor or Carrier) from Transport Order
-- ALREADY EXISTS in release/7.0.0.8+NEW-DISPO (PR #439)
create or replace procedure pDIS_TransportOrder.RemoveParticipant(
    TransportOrderId  numeric,
    ParticipantType   varchar,  -- 'UNF', 'UNN', or 'FRF'
    Mode              numeric
)
-- Calls: pTA.RemUnt(TransportOrderId, ParticipantType, Mode)

-- Remove Trailer from Transport Order
-- ALREADY EXISTS in release/7.0.0.8+NEW-DISPO
create or replace procedure pDIS_TransportOrder.RemoveTrailer(
    TransportOrderId  numeric,
    Mode              numeric
)
-- Calls: pTA.remanh(nTATix => TransportOrderId, nMode => Mode)

-- Remove Vehicle (Truck) from Transport Order
-- ALREADY EXISTS in release/7.0.0.8+NEW-DISPO
create or replace procedure pDIS_TransportOrder.RemoveVehicle(
    TransportOrderId  numeric,
    Mode              numeric
)
-- Calls: pTA.remlkw(nTATix => TransportOrderId, nMode => Mode)
```

#### Call Sequences per User Action

| User Action       | Calls from TMS Bridge                                                                                                           |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Remove Contractor | 1. `RemoveParticipant(id, 'UNF'/'UNN', mode)` — removes Contractor<br>2. `RemoveParticipant(id, 'FRF', mode)` — removes Carrier |
| Remove Carrier    | 1. `RemoveParticipant(id, 'FRF', mode)` — removes Carrier                                                                       |
| Remove Vehicle    | 1. `RemoveVehicle(id, mode)` — removes Vehicle                                                                                  |
| Remove Trailer    | 1. `RemoveTrailer(id, mode)` — removes Trailer                                                                                  |

> **Transaction Safety:** Separate calls do not cause inconsistent states (confirmed by Joachim). No transactional wrapper is required.

#### Participant Types

| Type  | Description          | German                  |
| ----- | -------------------- | ----------------------- |
| `UNF` | Long-haul Contractor | Unternehmer Fernverkehr |
| `UNN` | Local Contractor     | Unternehmer Nahverkehr  |
| `FRF` | Carrier              | Frachtführer            |

#### Cascading Behavior (after Joachim's changes)

| Action                           | Removes         |
| -------------------------------- | --------------- |
| `RemoveParticipant('UNF'/'UNN')` | Contractor only |
| `RemoveParticipant('FRF')`       | Carrier only    |
| `RemoveVehicle`                  | Vehicle only    |
| `RemoveTrailer`                  | Trailer only    |

#### Core Functions (verified by DB team)

| Action             | Core Function | Parameters                 |
| ------------------ | ------------- | -------------------------- |
| Remove Participant | `pta.remunt`  | `(ntatix, sperstb, nmode)` |
| Remove Vehicle     | `pta.remlkw`  | `(ntatix, nmode)`          |
| Remove Trailer     | `pta.remanh`  | `(ntatix, nmode)`          |

#### Responsibilities

All code of this story is developed by the following roles/parties:

| Who     | Responsibility                                                                                 |
| ------- | ---------------------------------------------------------------------------------------------- |
| Joachim | Modify `pta.remunt` and `pta.remlkw` to stop cascading to Vehicle/Trailer                      |
| P3      | Implement "Remove Contractor" as two sequential calls (remove Contractor, then remove Carrier) |
| P3      | All frontend, backend (TMS Bridge), and database wrapper code                                  |

The business requirements have been aligned with **Maximilian Beisheim**.
The technical solution design has been aligned with **Joachim Schreiner**.
