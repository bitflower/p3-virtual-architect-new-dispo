# EDI shipmentNumber CR — PBI 126097 verification

**Date:** 2026-07-01
**Status:** Documented (verification complete; backend implementation pending)

---

## Original User Input

> Verify PBI 126097 ("CR: Adding the shipment number to the EDI message") for completeness — including Acceptance Criteria. Check property naming (lowerCamelCase), identify the exact field mapping from the UI ("Sdg.-Nr"), and use Patrick's UI image. Sonja's DB PR #545 was provided for cross-check. Later: check abn1034 for null-ness of the value, and confirm the JSON type. Roel confirmed the JSON type should be a **number** (to match the DB type). Store as an exploration — document only, no further research.

Source meeting note: `00_Meetings/2026-07-01_EDI-Requirement/meeting.md` (request from Patrick Uschmann; PBI prepared by Maximilian Kehder).

---

## Summary

CALsuite WM began receiving records over the New Dispo → CALsuite EDI interface
(`SendPickupPlanToCALsuiteWM`), but the message does not carry the **shipment number
(Sendungsnummer)**, so WM cannot link the received data to their own records. This CR
adds a new property **`shipmentNumber`** to every `shipmentInformations[]` entry.

The PBI was verified and completed (Description + Acceptance Criteria filled, both images
attached). The critical clarification: the value must be the **business Sendungsnummer**
(the UI "Sdg.-Nr", `sendung_n`), **not** the internal `shipmentId` (`Sendung_Tix`) that the
message already carries. Type is a **JSON number** (confirmed by Roel), matching the DB
`numeric(7,0)`. Null-ness was checked on ABN1034: the value is effectively always present.

The DB half (view column) is delivered by child PBI 126098 / PR #545 (Ready to merge). The
API/EDI half (backend mapping) is still To Do.

## Analysis

### Verification result of PBI 126097 (before grooming)
- **Acceptance Criteria: missing.** The parent EDI story had no AC; only the child DB PBI
  126098 had AC ("shipmentnumber is present in v_dis_tp_client_comm").
- **Naming (lowerCamelCase):** the PBI text said "shipmentnumber". The EDI DTO
  (`JsonShipmentInformationDto`) uses strict lowerCamelCase via `[JsonPropertyName]`
  (`recordType`, `tourPosition`, …), so the JSON key must be **`shipmentNumber`**.
- **Placement:** well specified — same level as `recordType`, `tourPosition` (Max's image).

### Exact field mapping from the UI ("Sdg.-Nr")
Patrick's card shows `Sdg.-Nr: 6764516`. Traced end-to-end:

| Layer | Symbol | Notes |
|---|---|---|
| UI card ("Sdg.-Nr") | `legTourPoint().shipmentNumber` | `leg-tour-point.component.html` |
| Frontend REST DTO | `LegResponseDto.shipmentNumber` (`long?`) | `GetLotsAndLegs/Dtos` |
| Backend entity → DB | `LegEntity.ShipmentNumber` → `leg_shipment_number` | `LegEntityConfiguration` |
| AlloyDB source view | `v_dis_leg.ShipmentNumber` = `sendung.sendung_n` | business Sendungsnummer |

### The trap (source field)
The EDI message is built from `TourpointCommunicationInfoEdiDto`, whose source view
`V_DIS_TP_CLIENT_COMM` today only exposes `shipmentid` = `sendung.sendung_tix` — the
**internal** id (~14-digit, e.g. `10340431089100`), already serialized as `shipmentId`.
The new field must instead carry `sendung_n` (the ~7-digit business number = UI "Sdg.-Nr").

### Confirmed EDI mapping chain
`sendung.sendung_n` → `v_dis_leg.ShipmentNumber` → **(PR #545)** `V_DIS_TP_CLIENT_COMM.shipmentnumber`
→ `TourpointCommunicationInfoEdiDto.ShipmentNumber` (new) → `JsonShipmentInformationDto.shipmentNumber` (new)
→ EDI JSON.

### Type decision (JSON number vs string)
Other fields in the same `shipmentInformations` entry split by purpose:
- **JSON numbers:** `shipmentId` (`long?`), `tourPosition`, `consignorGlobalLocationNumber`,
  `loadingLocationGlobalLocationNumber`, `dataTransferNumber`, `stopNumber`.
- **JSON strings (reference/link keys):** `deliveryNoteNumber` (string despite the name),
  `itSystemReference`, `orderReference`, `sourceSystemReference`, `supplierReference`,
  `aggregationKey`, `deliveryRelation`.

Because `sendung_n` is `numeric(7,0)` (clean integer, no leading zeros, ≤7 digits, well within
JSON safe-integer range) and the sibling `shipmentId` is already numeric, **Roel confirmed
(2026-07-01) a JSON number is fine**, matching the DB type. → Map as `long?`, no string cast;
PR #545's numeric view column is correct as-is.

## Database Schema

Connection (from `DATABASES.md`): AlloyDB **abn1034** @ `10.100.47.236:5432`, user/schema `tms1034`.

- `sendung.sendung_n` — **`numeric(7,0)`** (integer, 0 decimals).
  - Null-ness on abn1034: **0 nulls / 38,248 shipments**. Range **2 – 9,982,783**, max **7 digits**,
    0 non-integer values. Sample values: 758624, 189327, 2091295.
- `V_DIS_TP_CLIENT_COMM` (schema `tms1034`) — currently **88 columns**, `shipmentid` is col #1,
  `pickuptourpointid` col #2. **No `shipmentnumber` column yet on abn1034** → PR #545 not deployed there.
- View join: `FROM v_dis_leg ship_lg JOIN sendung sen_ship ON sen_ship.sendung_tix = ship_lg.shipmentid`.
  Because it's an INNER join and `sendung_n` has no nulls, the new value is guaranteed present.

### PR #545 (Sonja) — `tms-alloydb-schema`
Adds one line to `V_DIS_TP_CLIENT_COMM.sql`:
```sql
SELECT ship_lg.shipmentid,
       sen_ship.sendung_n as shipmentNumber,   -- new (mid-list, col #2)
       ship_lg.pickuptourpointid,
       ...
```
Correct source (`sendung_n`, not `shipmentid`). Ready to merge into `release/7.0.0.8+NEW-DISPO`.

**Deploy caveat (posted as a comment on 126098):** the column is inserted **mid-list**, but
PostgreSQL `CREATE OR REPLACE VIEW` only allows **appending** columns at the end. Against an
environment that already has the view this errors (`cannot change name of view column
"pickuptourpointid"…`). Fix: drop+recreate the view, or move `shipmentNumber` to the end of the
SELECT list. The `select … limit 5` test on ENT1034 would not catch this if the view was created fresh.

## Source Code Evidence

**Backend (Code/Disposition-Backend):**
- `…/SendToEDI/Dtos/JsonDtos/ContentDtos/TourInformationDtos/ShipmentInformationDtos/JsonShipmentInformationDto.cs`
  — the `shipmentInformations[]` entry DTO (lowerCamelCase via `[JsonPropertyName]`).
- `…/SendToEDI/Dtos/TourpointDtos/TourpointCommunicationInfoEdiDto.cs` — mapping source; has
  `ShipmentId` (`long?`, `shipmentId`); no `ShipmentNumber` yet.
- `…/SendToEDI/Mappings/SendToEdiMapper.cs` — `ToJsonShipmentInformationDto(...)` direct
  property-to-property mapping (no conversions).
- `…/SendToEDI/…/EdiJsonBuilderSubHandler.cs` — serializes with Newtonsoft `JsonConvert.SerializeObject`
  (no custom number→string converter; `long?` ⇒ JSON number, `string?` ⇒ JSON string).
- `…/PickupPlanningView/Requests/GetLotsAndLegs/Dtos/LegResponseDto.cs` — `ShipmentNumber` (`long?`, `shipmentNumber`).
- `…/Domain/Entities/Leg/LegEntity.cs` (+ `LegEntityConfiguration.cs`) — `ShipmentNumber` (`long?`) → `leg_shipment_number`.

**Frontend (Code/Disposition-Frontend):**
- `…/components/tour-point/leg-tour-point/leg-tour-point.component.html` — renders "Shipment number"
  ("Sdg.-Nr") via `{{ legTourPoint().shipmentNumber }}`.

**TMS Bridge (Code/Disposition-Abstraction-Layer) — for reference:**
- `…/Data/Entities/Sendung/SendungEntity.cs` — `SendungN` = `decimal?` (GraphQL `Decimal`).
- `…/Data/Entities/Shipment/DISShipmentEntity.cs` — `ShipmentNumber` = `long` (GraphQL `Long`).
- `…/Data/Entities/Leg/LegEntity.cs` — `ShipmentNumber` = `decimal?`.
- TMS Bridge exposes numeric TMS keys as native `Long`/`Decimal` (no string-wrapping, no ID scalar).
  Note the cosmetic inconsistency: Backend types this value `long?` while TMS Bridge types it `decimal?`
  (same 7-digit integer either way).

**DB (Code/tms-alloydb-schema):**
- `src/sql/view/V_DIS_TP_CLIENT_COMM.sql`, `src/sql/view/V_DIS_LEG.sql` (`s.Sendung_N as ShipmentNumber`,
  `s.Sendung_Tix as ShipmentId`).

## Findings

1. `shipmentNumber` must be **lowerCamelCase** and carry the **business Sendungsnummer** (`sendung_n`
   = UI "Sdg.-Nr"), never the internal `shipmentId` (`Sendung_Tix`).
2. **Type = JSON number** (Roel-confirmed), matching DB `numeric(7,0)`; map `long?`, no cast.
3. **Null-ness is a non-issue:** 0 nulls across 38,248 shipments on ABN; INNER join guarantees presence.
4. **PR #545 source is correct** (`sen_ship.sendung_n`), but has a `CREATE OR REPLACE VIEW`
   mid-insert deploy risk and is **not yet deployed to abn1034**.
5. Reference/link-key fields in this message are otherwise strings; the number choice here is a
   deliberate, confirmed exception justified by the clean numeric DB type.

## Questions/Open Items

- **Resolved — Type:** JSON number (Roel, 2026-07-01).
- **Resolved — Null handling:** value always present (0/38,248 on ABN); JSON-safe.
- **Open — Backend implementation:** add `ShipmentNumber` (`long?`) to
  `TourpointCommunicationInfoEdiDto` + `JsonShipmentInformationDto` and map it in `SendToEdiMapper`.
- **Open — Deploy:** merge/deploy PR #545 (mind the view `CREATE OR REPLACE` caveat); it is not on ABN yet.

## Related Files

- `00_Meetings/2026-07-01_EDI-Requirement/` — `meeting.md`, `image.png` (Patrick's "Sdg.-Nr" card),
  `pr-545-overview.png`, `pr-545-files-changed.png`.
- Backend / Frontend / TMS Bridge / DB source paths listed under **Source Code Evidence**.
- Memory: `project_edi_shipmentnumber_cr.md` (see also `project_edi_flow_contextpartyid.md`).

## Related User Stories/Tasks

- **US 126097** — "CR: Adding the shipment number to the EDI message" (API/EDI side; To Do).
  Description + AC filled + both images attached this session.
- **Technical PBI 126098** — "[DB] Add shipmentnumber to V_DIS_TP_CLIENT_COMM" (Code review);
  deploy caveat comment posted.
- **Feature 125084** — "Change Requests" (parent).
- **PR #545** (`tms-alloydb-schema`, Sonja) — adds the view column; Ready to merge.

---

*Documented by the Virtual Architect — 2026-07-01*
