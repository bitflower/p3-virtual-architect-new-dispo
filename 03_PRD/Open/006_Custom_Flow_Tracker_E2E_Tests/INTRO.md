# PRD-006 Introduction: Custom Flow Tracker for E2E Tests

## The Problem in One Sentence

The New Dispo planning view is built around drag & drop, which neither Playwright Codegen nor Chrome DevTools Recorder can capture — so every e2e test must be hand-written by a developer who understands Angular internals, and the Product Owner (who knows the business flows best) has no way to contribute.

## The Core Idea: UI Domain Mapping

Instead of fighting the recording tools, PRD-006 introduces a **UI domain mapping** — a PO-curated catalog of every UI element that participates in a business flow. Each element gets a stable `data-testid` attribute that links the visual UI element to its domain concept.

The mapping started with 15 elements for the core planning flow and has since grown to **~96 elements** across the entire application surface. This growth was always the plan — the PO continuously extends the catalog as new flows are identified. The current state lives in `e2e/_ui-domain-model/` with a screenshot per element.

### Catalog structure (13 sections, ~96 elements)

| Section | Elements | Examples |
|---|---|---|
| **Planning core** | 13 | Branch selector, lot/shipment cards, drop zones, create-TO dialog, date pickers, refresh buttons, toast |
| **Navigation bar** | 4 | Module links (customer communication, TO list, pickup planning), expanded state |
| **Lot sorting & filtering** | 10 | Sort module, filter by address/weight/VSP/BSP/delivery date/pickup date/temperature classes, reset |
| **Leg card details** | 9 | Card overview, related branch chip, consignee address, traffic mode, weight, VSP/BSP, temperature class, leg type, context menu |
| **Lot card details** | 9 | Card overview, consignor address, traffic mode, weight, VSP, BSP, temperature class, leg types, unique recipient counter |
| **Transport orders (planning)** | 8 | Filtered TOs, interval selection, contractor/license plate, context menu, delete button + confirmation, expanded card, TO banner |
| **Drive instruction slider** | 6 | Slider, tourpoints, expanded tourpoint, lots/legs on tourpoint, remove button + confirmation |
| **Transport order filtering** | 11 | Filter module, departure date, address, BSP, TO number, license plate, carrier, weight, status, transport mode, VSP |
| **Customer communication** | 8 | Module overview, client list, client details, communication status, start buttons, traffic light, planned shipments, refresh |
| **Transport order details** | 13 | Page overview, internal navigation, freight exchange form, common details, transport features, drive instructions, tourpoints, fixed time, calculate tour, tour info, duration/length, add tourpoint, start/finish dropdown |
| **Dialogs & confirmations** | 3 | Unsaved progress, merge leg to lot, delete TO confirmation |
| **System** | 2 | Settings sidebar, version display |

### Example `data-testid` values

| What the PO sees | `data-testid` | Type |
|---|---|---|
| A lot card showing "Partie Nr: 6223" | `lot-card-6223` | Dynamic (per entity) |
| A shipment card showing "Sdg.-Nr: 6764480" | `shipment-card-6764480` | Dynamic (per entity) |
| The branch selector dropdown | `branch-selector` | Static |
| The "create transport order" drop zone | `drop-zone-create-transport-order` | Static |
| The dialog confirm button "Erstellen" | `create-to-confirm` | Static |
| Lot filter by weight | `lot-filter-weight` | Static |
| Client communication status | `client-communication-status` | Static |
| Calculate tour button | `calculate-tour-button` | Static |

The catalog is designed to grow. As the PO identifies new flows worth testing (customer communication, transport order details, freight exchange), they add screenshots to `e2e/_ui-domain-model/` and the development team seeds the corresponding `data-testid` attributes. No recorder changes, no generator changes — the contract scales naturally.

### What this mapping achieves

The `data-testid` attributes become a **shared contract** between three layers:

```
Angular templates  ←──  data-testid  ──→  Recorder (bookmarklet)
                            │
                            ▼
                      Flow JSON format
                            │
                     ┌──────┴──────┐
                     ▼             ▼
               Playwright    Selenium (V2)
               generator     generator
```

The Angular implementation is **decoupled from the test tooling**. The frontend team adds `data-testid` attributes to Angular templates and never needs to think about test frameworks. The recorder, flow format, and generators are built independently — they only care about `data-testid`, not Angular components, CSS classes, or Material Design internals. As the catalog grows from ~15 to ~96 elements (and beyond), only the templates change — the three-layer architecture stays the same.

This is the opposite of the existing Selenium suite, where 47% of selectors use XPath with string-interpolated values like `//div[@id='lot-drop-zone' and contains(., '6223')]` — selectors that break on every template change.

## The Assertion Model

A key insight from the exploration: **actions without assertions produce demo replays, not tests**. A script that clicks through the UI catches crashes but misses every data/logic bug.

PRD-006 defines four action categories in the Flow JSON format:

| Category | Purpose | Examples |
|---|---|---|
| **Navigation** | Where to go | `navigate` to `/de/planning` |
| **Interaction** | What the PO does | `click`, `select`, `fill`, `drag` |
| **Expectation** | What the PO sees after | `expect-visible`, `expect-count`, `expect-text` |
| **Context** | Structural markers | `dialog-opened`, `dialog-closed` |

The expectation actions are what make this a test framework rather than a replay tool. Consider the core planning flow:

```
PO selects branch Kaufungen
  → expects: lot cards appear (expect-count lot-card > 0)

PO clicks lot card 6223
  → expects: shipment cards appear (expect-visible shipment-card-6764480)

PO drags shipment to create-transport-order zone
  → expects: dialog opens (expect-visible create-to-dialog)

PO fills date, clicks confirm
  → expects: new transport order appears (expect-count transport-order-card increased)
```

The recorder captures these expectations **automatically** by taking snapshots of visible `data-testid` elements before and after each PO action. When new elements appear (shipment cards after lot selection, dialog after drag), the recorder generates `expect-visible` assertions. The PO doesn't have to think about assertions — they just use the app naturally, and the recorder infers "what changed" from the DOM diff.

> **Note:** This implicit snapshot-based approach is the V1 baseline. The assertion model is designed to evolve toward targeted, PO-controlled assertions — right-clicking elements to pin specific text values, asserting exact counts, or marking elements that should be absent. See [Vision Beyond V1](#vision-beyond-v1) for the full assertion evolution roadmap.

### Why assertions must be in V1

Without assertions, the generated test for "select branch → see lots" would be:

```typescript
// Actions-only: passes even if the lots column stays empty
await page.getByTestId('branch-selector').click();
await page.getByTestId('branch-option-ABN1034').click();
```

With the assertion model:

```typescript
// Catches the bug: branch selection doesn't load lots
await page.getByTestId('branch-selector').click();
await page.getByTestId('branch-option-ABN1034').click();
await expect(page.getByTestId(/^lot-card-/)).toHaveCount({ minimum: 1 });
```

## How This Speeds Up E2E Test Creation

The traditional workflow:

```
PO describes flow verbally → Developer interprets → Developer writes test code
                                                    (reads Angular templates,
                                                     figures out selectors,
                                                     adds waits, assertions)
```

The PRD-006 workflow:

```
PO opens bookmarklet → PO clicks through the real UI → Flow JSON exported
                                                              │
                                                    Generator produces .spec.ts
                                                    (selectors, waits, assertions
                                                     are all derived automatically)
                                                              │
                                                    Developer / test engineer reviews,
                                                    adds domain-specific assertions,
                                                    tunes timeouts, commits
```

The PO records directly in the running application. Drag & drop, dropdown selections, dialog flows — everything is captured because the recorder watches `data-testid` elements and pointer events, not framework internals. The ~150-line vanilla JavaScript bookmarklet has no dependencies and no build step.

The generated `.spec.ts` files use the existing page object structure (`e2e/page-objects/`, `e2e/tests/`) and Playwright's `getByTestId()` API. A developer reviews and tunes — but starts from a working test, not a blank file.

## Vision Beyond V1

V1 delivers the core loop: implicit assertions via snapshot diff, a bookmarklet recorder, and a Playwright generator. The architecture is deliberately layered so that each dimension can evolve independently.

### Assertion evolution: from implicit to targeted

V1 assertions are **implicit** — the recorder infers "what changed" from the DOM diff between PO actions. The PO never thinks about assertions; their continuation is the confirmation. This catches structural regressions (elements missing, dialogs not opening) but cannot express domain-specific expectations.

The progression toward richer assertions:

| Level | What | How | Status |
|---|---|---|---|
| **Implicit presence** | "Shipment cards appeared after lot selection" | Snapshot diff generates `expect-visible` automatically | V1 (shipped) |
| **Element counts** | "There are exactly 3 lot cards after the filter" | Snapshot diff captures counts per `data-testid` prefix → `expect-count` | V2 |
| **Targeted text assertions** | "This lot card should say RANA PASTIFICIO" | PO right-clicks an element → "this should say X" → `expect-text` | V2 |
| **Targeted value assertions** | "The date picker shows 28/06/2026" | PO right-clicks a control → "this value should be X" → `expect-value` | V2 |
| **Absence assertions** | "The deleted transport order should NOT be visible" | PO marks an element → "this should NOT be here" → `expect-hidden` | V2 |
| **Cross-step relative assertions** | "Fewer lots than before the filter" | Recorder snapshots state at key moments, generator compares across steps | V2+ |

The key design principle: V2 explicit assertions are **PO-intentional** (the PO actively declares them via right-click or similar gesture), while V1 implicit assertions are **PO-behavioral** (inferred from the PO's natural flow). Both coexist — implicit assertions catch the baseline, explicit assertions pin domain-specific expectations.

### Domain model enrichment

V1 identifies elements by `data-testid` only — `shipment-card-6764480` is a string, not a business object. V2 introduces an optional **Angular bridge** that enriches the Flow JSON with domain context:

```json
{
  "action": "click",
  "testId": "lot-card-6223",
  "domain": { "type": "lot", "id": "6223", "label": "Partie Nr: 6223" }
}
```

This makes Flow JSON files human-readable as business documentation, not just test input. The bridge is opt-in — the recorder works without it, the generator ignores `domain` fields it doesn't need.

### Recorder and tooling evolution

| Step | What | Why |
|---|---|---|
| **V1: Bookmarklet** | ~150 lines vanilla JS, zero dependencies | Ships immediately, no infrastructure |
| **V2: Chrome extension** | Same recorder logic, better UX (extension icon, persistent state) | Avoids CSP issues, easier PO activation |
| **V2: Flow replay visualization** | Highlights `data-testid` elements referenced in a Flow JSON on the live page | PO verifies a recorded flow visually before handing it off |
| **V2+: Angular-integrated recorder** | Hooks into CDK events, router, services for richer semantic capture | "dragOrderToTour(FA-001, T-103)" instead of "drag shipment-card → drop-zone" |

### Generator evolution: dual-framework output

The Flow JSON format is framework-agnostic by design. V1 ships a Playwright generator. The same JSON feeds future generators:

| Generator | Output | Status |
|---|---|---|
| **Playwright** | `.spec.ts` with `page.getByTestId()` + auto-wait | V1 (shipped) |
| **Selenium NUnit** | `.cs` with `By.CssSelector("[data-testid='...']")` + `WebDriverWait` | V2 (existing suite stale, needs selector migration first) |
| **Future framework** | Same Flow JSON → any test framework | Architecture supports it, no recorder changes needed |

## Summary

| Concept | What it does |
|---|---|
| **UI domain mapping** | ~96 PO-curated `data-testid` anchors (and growing) across 13 sections of the application, decoupled from Angular implementation details |
| **Assertion model** | Automatic `expect-visible` / `expect-count` / `expect-text` generation via DOM snapshot diffs — turns recordings into real tests |
| **Three-layer architecture** | Recording → Flow JSON → Generator — each layer is independent, the JSON format is the contract |
| **PO enablement** | The person who knows the business flows can record them directly, without reading Angular code |
