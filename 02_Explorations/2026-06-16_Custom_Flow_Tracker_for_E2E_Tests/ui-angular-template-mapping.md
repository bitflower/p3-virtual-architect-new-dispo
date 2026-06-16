# UI → Angular Template Mapping

**Date:** 2026-06-16
**Source:** PO element list (`ui-domain-lements.md`) cross-referenced against Angular frontend codebase

---

## Summary

All 11 UI elements identified by the PO were located in the Angular codebase. **Zero** have `data-testid` attributes today. The elements are concentrated in just **3 template files** plus **2 shared library components**.

## Mapping Table

| # | PO Element | Component Chain | Template File | Line | `data-testid` | Drag/Drop Role |
|---|---|---|---|---|---|---|
| 1 | Transport order list | `app-cal-orders-list` → `lib-table` | `components/cal-orders-list/cal-orders-list.component.html` | 8 | No | — |
| 2 | Branch selection | `cal-branch-lookup-field` → `lib-lookup-field` → `mat-select` | `components/branch-lookup-field/branch-lookup-field.component.html` | 1 | No | — |
| 3 | Language selection | `lib-header` → `lib-lookup-field` → `mat-select` | `libs/nagel-components/src/lib/header/header.component.html` | 6 | No | — |
| 4 | Lot cards | `cal-draggable-card` (inside `@for` loop) | `pages/planning-page/planning-page.component.html` | 95 | No¹ | `cdkDrag` source |
| 5 | Shipment/Leg cards | `cal-draggable-card` (inside `@for` loop) | `pages/planning-page/planning-page.component.html` | 137 | No | `cdkDrag` source |
| 6 | Leg type filter | `mat-button-toggle-group` (VL / HL / NL) | `pages/planning-page/planning-page.component.html` | 44 | No | — |
| 7 | Lot refresh button | `button mat-icon-button` + `lib-app-icon arrows_rotate_icon` | `pages/planning-page/planning-page.component.html` | 16 | No | — |
| 8 | Transport order refresh button | `button mat-icon-button` + `lib-app-icon arrows_rotate_icon` | `components/planning-list/planning-list.component.html` | 4 | No | — |
| 9 | Create transport order drop area | `div.drop-zone` + `cdkDropList` | `components/planning-list/planning-list.component.html` | 17 | No | `cdkDropList` target |
| 10 | Create new lot drop area | `div.drop-target-wrapper` + `cdkDropList` | `pages/planning-page/planning-page.component.html` | 32 | No | `cdkDropList` target |
| 11 | Date range filtering | `single-date-time-picker` → `mat-date-range-input` | `libs/nagel-components/src/lib/single-date-time-picker/single-date-time-picker.component.html` | 1 | No | — |

| 12 | Create TO dialog (container) | `create-transport-order-dialog` (Material dialog) | `components/create-transport-order-dialog/create-transport-order-dialog.component.html` | 1 | No | — |
| 13 | Create TO dialog: date input | `date-time-picker` → `mat-datepicker` + `input` | `libs/nagel-components/src/lib/date-time-picker/date-time-picker.component.html` | 2 | No | — |
| 14 | Create TO dialog: cancel button | `button#cancel_button` | `create-transport-order-dialog.component.html` | 8 | No (has `id`) | — |
| 15 | Create TO dialog: confirm button | `button#confirm_button` (disabled until date selected) | `create-transport-order-dialog.component.html` | 9 | No (has `id`) | — |

¹ Lot cards have `[attr.data-lot-id]="cardConfig.identificationNumber"` — a domain attribute but not a `data-testid`.

All paths relative to `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/` unless prefixed with `libs/`.

---

## Drag-Drop Topology

The drag-drop flow is **one-directional** — shipments are dragged INTO targets:

```
Shipment cards (cdkDrag, container id="shipments")
    ├── → "Create transport order" drop zone (cdkDropList, connectedTo=['shipments'])
    ├── → "Create new lot" drop zone (cdkDropList, connectedTo=['shipments'])
    └── → Existing lot card drop zone (cdkDropList per lot, id=lotDropZone)
```

Lot cards are also `cdkDrag` sources, but their drop targets are per-lot zones wrapping each lot card (line 94 in `planning-page.component.html`). This supports reordering or merging lots.

### Drop event handlers

| Drop Target | Handler | What happens |
|---|---|---|
| Create transport order zone | `dropOnCreateTransportOrder($event)` | Opens date/time dialog, then calls `pickupPlanningTransportOrdersActionsService.createTransportOrder()` |
| Create new lot zone | `dropOnCreateLot($event)` | Calls `dragDropService.dropLegToCreateNewLot(draggedLeg, onSuccess)` |
| Existing lot card | `dropOnLot($event, cardConfig)` | Assigns shipment to existing lot |

---

## Shared Component: `cal-draggable-card`

Both lot and shipment cards render through the same component:

- **Template:** `components/draggable-card/draggable-card.component.html`
- **Selector:** `<cal-draggable-card>`
- **Key inputs:** `[cardConfig]`, `[selected]`, `[numberLabel]`

The card displays:
- **Header chips** — leg type badges (VL/HL/NL) via `@for(chip of cardConfig.headerChips)`
- **Identification number** — "Partie Nr: 6223" or "Sdg.-Nr: 6764480"
- **Context menu** — three-dot menu, shown only for shipment cards (`@if(cardConfig.shipmentId)`)
- **Sender/Recipient** — customer name + address via `<cal-participant>`
- **Info chips** — metric badges (VK, BSP, VSP) via `@for(chip of cardConfig.infoChips)`

### Data model

```
DraggableCardConfig (base)
├── id: string
├── shipmentId?: number          ← only shipment cards
├── identificationNumber: string ← the displayed "Nr."
├── headerChips: HeaderLotChip[] ← VL/HL/NL badges
├── infoChips: InfoLotChip[]     ← VK, BSP, VSP metrics
├── sender?: Participant         ← { name, street, address }
├── recipient?: Participant
├── consigneeName?: string
└── consigneeServiceArea?: number

LotCardConfig extends DraggableCardConfig
└── shipments: DraggableCardConfig[]  ← child shipments
```

---

## Shared Library Components

Two library components wrap multiple PO elements:

### `lib-lookup-field` (used by #2 Branch, #3 Language)

- **Path:** `libs/nagel-form/src/lib/fields/lookup-field/lookup-field.component.ts`
- **Selector:** `<lib-lookup-field>`
- **Structure:** `mat-form-field` → `mat-select` → `mat-option`
- **Inputs:** `key`, `label`, `icon`, `className`, `value`, `options`, `changeHandler`
- The `key` field is useful for `data-testid` naming: `key="branch"` for branch, `key="languageSwitch"` for language

### `single-date-time-picker` (used by #11 Date range)

- **Path:** `libs/nagel-components/src/lib/single-date-time-picker/`
- **Selector:** `<single-date-time-picker>`
- **Structure:** `mat-form-field` → `mat-datepicker-toggle` + `mat-date-range-input` (start/end) + `mat-date-range-picker`
- **Inputs:** `storageKey`, `handleOnSubmit`

---

## Proposed `data-testid` Attributes

| # | PO Element | Proposed `data-testid` | Where to add | Notes |
|---|---|---|---|---|
| 1 | Transport order list | `transport-order-list` | `cal-orders-list.component.html` on `lib-table` | Table container |
| 2 | Branch selection | `branch-selector` | `branch-lookup-field.component.html` on root `div` | Or on `lib-lookup-field` via attribute forwarding |
| 3 | Language selection | `language-selector` | `header.component.html` on `lib-lookup-field` wrapper div | |
| 4 | Lot cards | `lot-card-{identificationNumber}` | `planning-page.component.html` line 95 on `cal-draggable-card` | Dynamic: `[attr.data-testid]="'lot-card-' + cardConfig.identificationNumber"` |
| 5 | Shipment/Leg cards | `shipment-card-{identificationNumber}` | `planning-page.component.html` line 137 on `cal-draggable-card` | Dynamic: `[attr.data-testid]="'shipment-card-' + shipment.identificationNumber"` |
| 6 | Leg type filter | `leg-filter-group`, `leg-filter-VL`, `leg-filter-HL`, `leg-filter-NL` | `planning-page.component.html` lines 44-55 | One on group, one per toggle |
| 7 | Lot refresh button | `lot-refresh-button` | `planning-page.component.html` line 16 on `button` | |
| 8 | Transport order refresh button | `transport-order-refresh-button` | `planning-list.component.html` line 4 on `button` | |
| 9 | Create transport order drop area | `drop-zone-create-transport-order` | `planning-list.component.html` line 17 on `div.drop-zone` | Drop target |
| 10 | Create new lot drop area | `drop-zone-create-lot` | `planning-page.component.html` line 32 on `div.drop-target-wrapper` | Drop target |
| 11 | Date range filtering | `planning-date-range-picker` | `single-date-time-picker.component.html` line 1 on `mat-form-field` | Shared component — consider `[attr.data-testid]` via input |
| 12 | Create TO dialog | `create-to-dialog` | `create-transport-order-dialog.component.html` line 1 on `div.create-dialog` | Dialog container |
| 13 | Create TO: date input | `create-to-date-input` | `libs/.../date-time-picker/date-time-picker.component.html` line 2 on `input` | Shared component — consider input-driven testid |
| 14 | Create TO: cancel button | `create-to-cancel` | `create-transport-order-dialog.component.html` line 8 on `button#cancel_button` | Already has HTML `id` |
| 15 | Create TO: confirm button | `create-to-confirm` | `create-transport-order-dialog.component.html` line 9 on `button#confirm_button` | Disabled until date selected |

---

## Concentration Analysis

### By template file (app-level)

| Template | Elements | Lines touched |
|---|---|---|
| `planning-page.component.html` | #4, #5, #6, #7, #10 | 16, 32, 44-55, 95, 137 |
| `planning-list.component.html` | #8, #9 | 4, 17 |
| `cal-orders-list.component.html` | #1 | 8 |
| `branch-lookup-field.component.html` | #2 | 1 |

### By template file (library-level)

| Template | Elements | Notes |
|---|---|---|
| `header.component.html` | #3 | Language selector wrapper |
| `single-date-time-picker.component.html` | #11 | Shared — needs input-driven testid |

### Create Transport Order Dialog

| Template | Elements | Notes |
|---|---|---|
| `create-transport-order-dialog.component.html` | #12 (container), #14 (cancel), #15 (confirm) | Cancel/confirm already have HTML `id` attributes |
| `libs/.../date-time-picker/date-time-picker.component.html` | #13 (date input) | Shared component — also used in drive instructions form |

**Dialog structure:**
```
create-transport-order-dialog (mat-dialog)
├── h2 mat-dialog-title — "Fahrauftrag erstellen" (from data.title, i18n)
├── mat-dialog-content
│   ├── p — instruction text (from data.message, i18n)
│   └── date-time-picker
│       ├── mat-form-field
│       │   ├── input [matDatepicker] — placeholder "Start date and time" (i18n)
│       │   └── mat-datepicker-toggle (calendar icon)
│       └── mat-datepicker (popup when calendar icon clicked)
│           ├── lib-time-picker (hour/minute selection)
│           ├── Cancel button (matDatepickerCancel)
│           └── Apply button (matDatepickerApply)
├── mat-dialog-actions
│   ├── button#cancel_button — "Abbrechen"
│   └── button#confirm_button — "Erstellen" [disabled]="!selectedDate"
```

Note: The dialog has TWO levels of cancel/confirm:
1. **Datepicker popup level:** Cancel/Apply inside the calendar popup — these confirm the date selection
2. **Dialog level:** Abbrechen/Erstellen — these confirm or cancel the entire transport order creation

The PO flow is: click calendar icon → pick date → pick time → Apply (closes datepicker) → Erstellen (creates the transport order).

**Bottom line:** Adding `data-testid` to cover all 15 PO elements (11 original + 4 dialog) requires changes to **8 template files**, with the majority (5 of 15) in `planning-page.component.html`.
