# #119685 Edit Flow – 1. Change Transport Mode

> Date: 2025-12-11, Participants: Max Kehder, Matthias Max

Is directly related to the field `sendung` => `tran_art numeric(2,0)` with no business logic attached.

Options:
- Direct `UPDATE`
- `DIS`-wrapper that does the `UPDATE`

## Discussion Max Kehder / Consequences

- The change of the value would lead to the transport order to be filtered out in New Dispo
  - This needs to be covered as well
