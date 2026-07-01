# PBI 126097 — Draft Acceptance Criteria (for review)

**Story:** CR: Adding the shipment number to the EDI message
**Parent:** Feature 125084 (Change Requests)
**Child (DB):** 126098 — PR #545 *"…added one new field shipmentNumber"* (Ready to merge)
**Requested by:** Patrick Uschmann — CALsuite WM received the first records but the
**Sendungsnummer** is missing; they need it to *link* the EDI data to their own records.

> Status: DRAFT — not yet written to ADO. Review, then I can push to the 126097 AC field.

## Scope
Add the shipment number (Sendungsnummer / UI "Sdg.-Nr") to every `shipmentInformations[]`
entry of the `SendPickupPlanToCALsuiteWM` EDI message. The message body is otherwise unchanged.

## Acceptance Criteria
1. Each `shipmentInformations[]` entry in the EDI JSON contains a new property
   **`shipmentNumber`**, on the same level as `recordType`, `tourPosition`, etc.
   (placement per the PBI attachment / Max's image).
2. The JSON key is exactly **`shipmentNumber`** — **lowerCamelCase** — consistent with the
   existing `JsonShipmentInformationDto` properties. (Not `shipmentnumber`, not `ShipmentNumber`.)
3. The value is the **business Sendungsnummer** — the same value shown in the New Dispo UI as
   **"Sdg.-Nr"** for that leg (Patrick's image, e.g. `6764516`). Source = the new
   `V_DIS_TP_CLIENT_COMM.shipmentnumber` column (= `sendung.sendung_n`), i.e. New Dispo
   `leg_shipment_number`.
4. The value is **not** the internal `shipmentId` (`Sendung_Tix`); the existing `shipmentId`
   field in the message remains unchanged.
5. Cardinality: exactly one `shipmentNumber` per `shipmentInformations[]` entry (per leg/tourpoint).
6. No other fields in the EDI body are added, removed, or changed.
7. **Verification:** for a sample tourpoint, `shipmentInformations[].shipmentNumber` in the
   generated EDI message equals the "Sdg.-Nr" shown in the Frontend for that leg and the
   `shipmentnumber` in `V_DIS_TP_CLIENT_COMM`. CALsuite WM confirms they can link records on it.

## Dependencies
- DB column must be merged & deployed first: child **126098 / PR #545**
  (`sen_ship.sendung_n as shipmentNumber` in `V_DIS_TP_CLIENT_COMM`).
- ⚠️ Confirm PR #545 deploy mechanics: the column is inserted **mid-list** with
  `CREATE OR REPLACE VIEW`. Postgres only allows *appending* columns on replace — verify the
  deploy drops/recreates the view (or move the column to the end), else the deploy errors on
  an env that already has the view.

## Open questions (need PO/dev decision — not asserted here)
- **Null handling:** if `shipmentnumber` is null for a leg, is the field emitted as `null` or
  omitted? (DTO props are nullable `long?`.)
- Any WM-side format/length expectation for the number? (7-digit sample observed.)

## References
- Patrick's request + UI value "Sdg.-Nr": `image.png` (this folder)
- Target JSON placement: PBI 126097 attachment (Max)
- DB PR #545: `pr-545-overview.png`, `pr-545-files-changed.png` (this folder)
- Verified mapping chain:
  `sendung.sendung_n` → `v_dis_leg.ShipmentNumber` → `V_DIS_TP_CLIENT_COMM.shipmentnumber`
  → `TourpointCommunicationInfoEdiDto.ShipmentNumber` (new)
  → `JsonShipmentInformationDto.shipmentNumber` (new) → EDI JSON
- Backend touchpoints: `TourpointCommunicationInfoEdiDto`, `JsonShipmentInformationDto`,
  `SendToEdiMapper.ToJsonShipmentInformationDto`

---

### Paste-ready AC (for the ADO Acceptance Criteria field)
- Each `shipmentInformations[]` entry contains a new property `shipmentNumber` on the same level as `recordType` / `tourPosition`.
- JSON key is exactly `shipmentNumber` (lowerCamelCase), matching the existing message convention.
- Value = the business Sendungsnummer shown in the UI as "Sdg.-Nr" (source: `V_DIS_TP_CLIENT_COMM.shipmentnumber` = `sendung_n` = `leg_shipment_number`) — NOT the internal `shipmentId`.
- One `shipmentNumber` per `shipmentInformations[]` entry; no other body fields change.
- Verified when the message value matches the Frontend "Sdg.-Nr" for the same leg and CALsuite WM can link on it.
- Depends on 126098 / PR #545 (DB view column) being deployed first.
