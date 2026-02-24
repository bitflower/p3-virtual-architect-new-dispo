# #120244 Edit Flow – 4. Change Comment of a Transport Order

> Date: 2025-12-11, Participants: Max Kehder, Matthias Max

Table: `TEXT_SENDUNG`
Field: `S_TEXT`

## Read

LATERAL JOIN from `sendung` on `TEXT_SENDUNG` joined via `sendung_tix` and filtered for the `TYP` = `'TA1'` and `laufende_nummer` = smallest

Can be added to `v_dis_transportorder` because it involves no functions.

Accepted limitation: Only the first comment will be displayed.

## Write

`INSERT` or `UPDATE` `text_sendung.s_text` for the `sendung_tix` = Transport Order ID and `TYP` = `'TA1'` and `laufende_nummer` = `1`

A new procedure in `pDis_TransportOrder` called `SetReference`.

## Constraints

Restricted to 255 characters because `s_text` is limited.
