# PRD-006: Custom Flow Tracker for E2E Tests

**Feature ID:** 006_Custom_Flow_Tracker_E2E_Tests
**Date:** 2026-06-16
**Status:** Draft

---

## 1. Problem

The New Dispo planning view is built around drag & drop — assigning shipments to transport orders, creating lots, reordering stops. Neither Playwright Codegen nor Chrome DevTools Recorder captures drag & drop interactions. Both produce output dominated by `getByText('German text')` selectors that break under i18n. The result: every e2e test must be hand-written by a developer who understands Angular internals.

Meanwhile, the Product Owner — the person who knows the business flows best — has no way to contribute to test creation. They can describe flows verbally, but the translation from "I drag shipment 6764480 to the create-transport-order area" into a working Playwright or Selenium test is a manual, error-prone process that requires developer time.

The existing Selenium test suite (`Disposition-UI-Automation`, 34 active tests) uses fragile selectors: 47% XPath with string-interpolated values, Material Design generated IDs like `mat-select-value-47`, and aria-labels with typos. It has zero `data-testid` usage on domain elements and has been stale since December 2025. The frontend has 9 `data-testid` attributes total — none on planning view elements.

**Evidence:**

| Source | Finding |
|---|---|
| `02_Explorations/.../custom-flow-tracker.md` | Playwright Codegen and Chrome Recorder both fail to capture drag & drop |
| `02_Explorations/.../existing-selenium-test-analysis.md` | 34 active tests, 11 disabled, stale since Dec 2025, zero planning drag-drop coverage |
| `02_Explorations/.../ui-angular-template-mapping.md` | 0 of 15 PO-identified elements have `data-testid` |
| `02_Explorations/.../selenium-vs-playwright-comparison.md` | Selenium selectors are 47% XPath, highly fragile |
| `02_Explorations/.../minimal-recorder-demystified.md` | A minimal recorder is ~150 lines of vanilla JS — not the large tool imagined |

**Failure modes to avoid:**
- The Selenium suite's fragility (XPath + generated IDs) — don't repeat this pattern
- Building a polished tool when a bookmarklet suffices — scope discipline
- Capturing actions without assertions — produces demo replays, not tests (see `flow-format-deep-dive.md`)

## 2. Direction Alignment

No direction/strategy documents are configured. This PRD is driven by:
- PO's explicit request for a way to record business flows (PO element mapping provided as `ui-domain-lements.md`)
- Time pressure: PO needs to contribute test flows ASAP
- Architectural goal: `data-testid` as a shared contract between Angular templates, the recorder, and both test frameworks (Playwright + Selenium)

**Conscious scope reductions:**
- Selenium generator deferred to V2 (suite stale, needs selector migration first)
- Rich domain model enrichment via Angular bridge deferred to V2
- Cross-step relative assertions (snapshot comparison) deferred to V2
- Polished recorder UI deferred to V2

## 3. Requirements (MoSCoW)

### Must Have

- **M1: `data-testid` seeding on all 15 PO-identified elements.** Add `data-testid` attributes to the Angular templates per the mapping in `ui-angular-template-mapping.md`. Dynamic IDs for cards: `lot-card-{identificationNumber}`, `shipment-card-{identificationNumber}`. Static IDs for controls: `branch-selector`, `leg-filter-HL`, `lot-refresh-button`, `transport-order-refresh-button`, `drop-zone-create-transport-order`, `drop-zone-create-lot`, `planning-date-range-picker`, `transport-order-list`, `language-selector`. Dialog elements: `create-to-dialog`, `create-to-date-input`, `create-to-cancel`, `create-to-confirm`. Changes across 8 Angular template files.

- **M2: Flow JSON format specification.** Define the format with four action categories: navigation (`navigate`), interaction (`click`, `select`, `fill`, `drag`), expectation (`expect-visible`, `expect-count`, `expect-text`), and context markers (`dialog-opened`, `dialog-closed`). Each action references elements by `data-testid`. Format includes optional timing metadata (`timestamp`, `meta.waitedMs`). Expectations are *eventually-true* statements — the generator maps them to framework-appropriate waits.

- **M3: Minimal browser recorder (bookmarklet).** ~150 lines of vanilla JavaScript, no dependencies, no build step. Capabilities:
  - Capture clicks on `data-testid` elements (walk up DOM from event target to find nearest `data-testid`)
  - Detect drag gestures between `data-testid` elements via pointer events (pointerdown → distance threshold → pointerup)
  - Track Material overlay/dropdown selections back to trigger element via MutationObserver on `.cdk-overlay-container`
  - Handle two-level dialog flows (datepicker popup Apply, then dialog Erstellen)
  - Generate `expect-visible` assertions automatically via snapshot diff of visible `data-testid` elements between PO actions
  - Record timestamps on each action for timing metadata
  - Activation: bookmarklet (`javascript:(function(){...})()`). Controls: floating start/stop toggle button, JSON export to clipboard + file download

- **M4: Playwright test generator.** Reads Flow JSON, emits `.spec.ts` files using existing page object conventions (`e2e/page-objects/`, `e2e/tests/`). Mappings:
  - `data-testid` references → `page.getByTestId()`
  - `expect-visible` → `expect(locator).toBeVisible()`
  - `expect-count` → element count assertions
  - `expect-text` → `expect(locator).toContainText()`
  - `drag` → `locator.dragTo(target)`
  - Timing metadata → auto-wait timeout selection (default 5s; >5s observed → 2× multiplier)
  - Can be a Claude Code skill or standalone CLI script

- **M5: End-to-end validation with PO.** PO records the core planning flow (select branch → filter HL → select lot → drag shipment to create transport order → fill date in dialog → confirm → verify transport order created). Generated test runs successfully against the test environment. Generated test fails when a business expectation is violated — proving assertions work.

### Should Have

- **S1: `data-testid` naming convention document.** Formalize the `[feature]-[element]-[qualifier]` pattern with dynamic ID rules for card elements. Publish in the frontend e2e getting started guide (`GETTING-STARTED.md`).

- **S2: Snapshot diff captures element counts.** The recorder captures how many elements matching a `data-testid` prefix are visible (e.g., `lot-card.*: 12`), enabling `expect-count` assertions in addition to `expect-visible`.

- **S3: Loading spinner detection.** Recorder uses MutationObserver to detect `mat-spinner` presence between actions, includes `meta.loadingIndicatorSeen` in timing metadata. Generator uses this to emit "wait for spinner to disappear" before assertions.

### Could Have

- **C1: Chrome extension wrapper.** Package the bookmarklet as a Chrome extension for easier activation (extension icon instead of bookmark). Same recorder logic, better UX.

- **C2: Flow replay visualization.** A read-only viewer that highlights the `data-testid` elements referenced in a Flow JSON file on the live page, so the PO can verify a recorded flow visually.

- **C3: Selenium NUnit generator.** Reads the same Flow JSON, emits NUnit `.cs` test files using the existing Selenium Page Object structure. Maps `data-testid` to `By.CssSelector("[data-testid='...']")`. Emits `WebDriverWait` with appropriate timeouts.

### Won't Have (explicit)

- **W1: Angular-integrated recorder (Approach C from exploration).** The minimal bookmarklet (Approach A) delivers the core value without coupling to Angular internals. Angular bridge for richer domain data is a V2 enhancement.

- **W2: Cross-step relative assertions.** "Fewer lots than before the filter" requires snapshot comparison logic. V1 uses absolute assertions only (`expect-count gt 0`). Developer adds relative checks manually when needed.

- **W3: Assertion editing in the recorder.** The recorder auto-generates assertions from snapshot diffs. Editing them requires modifying the Flow JSON or the generated test code. No in-recorder assertion editor.

- **W4: Multi-browser support.** Chrome/Edge only (Chromium-based). No Firefox or Safari.

- **W5: CI/CD integration.** Generated tests run locally or via existing Playwright config. No pipeline gates, no automatic recording triggers, no cloud test execution.

- **W6: Migration of existing Selenium selectors to `data-testid`.** The Selenium suite has 34 active tests with fragile selectors. Migrating them to `data-testid` is separate work not covered by this PRD.

## 4. Out of Scope

- Recording non-`data-testid` elements (raw DOM clicks, CSS class selectors)
- Tour calculation flows (TOP Service integration, 30s+ async operations)
- Map view interactions
- Mobile/responsive testing
- Multi-user or role-based test scenarios
- Production environment recording (test/UAT/local only)

## 5. Implementation Approach (unverified hint)

### Component layout

```
Code/Disposition-Frontend/
├── e2e/
│   ├── recorder/
│   │   ├── flow-tracker.js          ← the ~150-line bookmarklet source
│   │   └── flow-schema.json         ← JSON schema for the flow format
│   ├── generator/
│   │   └── generate-from-flow.ts    ← CLI/skill: Flow JSON → .spec.ts
│   ├── flows/                       ← recorded Flow JSON files
│   ├── page-objects/                ← existing (extend with planning view)
│   └── tests/                       ← existing + generated tests
```

### Three work streams

| Stream | Deliverable | Dependency |
|---|---|---|
| **A: `data-testid` seeding** | Angular template changes (8 files, ~25 lines) | None — can start immediately |
| **B: Recorder** | `flow-tracker.js` bookmarklet (~150 lines) | Depends on A (needs `data-testid` on live elements) |
| **C: Generator** | `generate-from-flow.ts` + planning page objects | Depends on M2 (flow format spec) |

Streams A and C can start in parallel. Stream B starts after A is deployed to test environment.

### Three-layer architecture

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: RECORDING (PO interaction)                    │
│  Bookmarklet watches data-testid + pointer events       │
│  Snapshot diffs generate assertions automatically       │
│  Output: Flow JSON (framework-agnostic)                 │
├─────────────────────────────────────────────────────────┤
│  Layer 2: FLOW FORMAT (the contract)                    │
│  JSON: actions + expectations + timing metadata         │
│  No framework syntax, no selectors, no waits            │
│  data-testid is the only element reference mechanism    │
├─────────────────────────────────────────────────────────┤
│  Layer 3: GENERATORS (one per target framework)         │
│  V1: Flow JSON → Playwright .spec.ts (page objects)     │
│  V2: Flow JSON → Selenium NUnit .cs (page objects)      │
│  Each generator owns wait strategy for its framework    │
└─────────────────────────────────────────────────────────┘
```

### Timing ownership

| Actor | Responsibility |
|---|---|
| **PO** | Clicks naturally — doesn't think about timing |
| **Recorder** | Captures timestamps + detects `mat-spinner` between actions |
| **Generator** | Emits framework-appropriate waits (Playwright auto-wait, Selenium WebDriverWait) |
| **Developer** | Tunes timeouts for CI/UAT environments when defaults don't hold |

## 6. Files Likely to Change

### Angular template changes (data-testid seeding)

| File | Elements | New/Modified |
|---|---|---|
| `apps/.../planning-page/planning-page.component.html` | Lot cards (#4), shipment cards (#5), leg filter (#6), lot refresh (#7), create-lot drop (#10) | Modified |
| `apps/.../planning-list/planning-list.component.html` | TO refresh (#8), create-TO drop (#9) | Modified |
| `apps/.../branch-lookup-field/branch-lookup-field.component.html` | Branch selector (#2) | Modified |
| `libs/.../header/header.component.html` | Language selector (#3) | Modified |
| `libs/.../single-date-time-picker/single-date-time-picker.component.html` | Date range picker (#11) | Modified |
| `apps/.../cal-orders-list/cal-orders-list.component.html` | Transport order list (#1) | Modified |
| `apps/.../create-transport-order-dialog/create-transport-order-dialog.component.html` | Dialog container (#12), cancel (#14), confirm (#15) | Modified |
| `libs/.../date-time-picker/date-time-picker.component.html` | Dialog date input (#13) | Modified |

### New files (recorder + generator)

| File | Purpose | New/Modified |
|---|---|---|
| `e2e/recorder/flow-tracker.js` | Minimal recorder bookmarklet | New |
| `e2e/recorder/flow-schema.json` | Flow format JSON schema | New |
| `e2e/generator/generate-from-flow.ts` | Playwright test generator | New |
| `e2e/page-objects/planning.page.ts` | Planning view page object | New |
| `e2e/page-objects/index.ts` | Export new page object | Modified |
| `e2e/GETTING-STARTED.md` | Add recorder usage instructions | Modified |

## 7. Verification

### Acceptance — functional

- [ ] All 15 PO elements have `data-testid` attributes visible in browser DevTools
- [ ] PO activates bookmarklet on test environment, records the core planning flow:
  1. Select branch Kaufungen
  2. Click HL leg filter
  3. Select lot card
  4. Drag shipment card to create-transport-order drop zone
  5. Dialog opens — pick date/time via datepicker → Apply
  6. Click "Erstellen" (confirm) in dialog
  7. New transport order card appears
- [ ] Recorder exports valid Flow JSON containing actions + auto-generated `expect-visible` assertions
- [ ] Generator produces a runnable `.spec.ts` file from the Flow JSON
- [ ] Generated test passes when run via `npx playwright test` against the test environment
- [ ] Generated test fails when a business expectation is violated (e.g., lot selection doesn't load shipments) — proving assertions work

### Acceptance — recorder edge cases

- [ ] Material dropdown selection (branch selector) captured as `select` action with correct value
- [ ] Drag from shipment card to create-TO drop zone captured as `drag` action with correct source/target `data-testid`
- [ ] CDK drag preview does not intercept `pointerup` (or recorder handles it via `document.elementsFromPoint()`)
- [ ] Two-level dialog flow captured correctly: datepicker Apply + dialog Erstellen as separate actions
- [ ] Recording on test environment (`test.dispo.gcp.nagel-group.com`) works without CORS or CSP issues

### Acceptance — assertions

- [ ] Snapshot diff correctly identifies shipment cards appearing after lot selection → generates `expect-visible`
- [ ] Snapshot diff correctly identifies dialog appearing after drag → generates `expect-visible` for dialog
- [ ] Snapshot diff does NOT produce spurious assertions from scrolling or unrelated DOM changes

### Acceptance — timing

- [ ] Generated test handles the 1-3s API response after branch selection (Playwright auto-wait)
- [ ] Generated test handles the loading spinner during shipment load
- [ ] Generated test does NOT contain hardcoded `waitForTimeout` calls

## 8. Related

### Prior art (with file paths)

| Document | Relevance |
|---|---|
| `02_Explorations/2026-06-16_Custom_Flow_Tracker_for_E2E_Tests/custom-flow-tracker.md` | Original exploration, 4 approaches analyzed |
| `02_Explorations/2026-06-16_Custom_Flow_Tracker_for_E2E_Tests/ui-domain-lements.md` | PO's UI-to-domain element mapping (15 elements incl. dialog) |
| `02_Explorations/2026-06-16_Custom_Flow_Tracker_for_E2E_Tests/ui-angular-template-mapping.md` | Exact file:line mapping for all 15 PO elements to Angular templates |
| `02_Explorations/2026-06-16_Custom_Flow_Tracker_for_E2E_Tests/existing-selenium-test-analysis.md` | Selenium suite state, coverage gaps, code quality |
| `02_Explorations/2026-06-16_Custom_Flow_Tracker_for_E2E_Tests/selenium-vs-playwright-comparison.md` | Framework comparison, three-layer architecture, `data-testid` as shared contract |
| `02_Explorations/2026-06-16_Custom_Flow_Tracker_for_E2E_Tests/flow-format-deep-dive.md` | Why actions-only fails, assertion model, complete scenario walkthrough |
| `02_Explorations/2026-06-16_Custom_Flow_Tracker_for_E2E_Tests/timing-and-async-flows.md` | Timing ownership matrix, distributed system wait handling |
| `02_Explorations/2026-06-16_Custom_Flow_Tracker_for_E2E_Tests/minimal-recorder-demystified.md` | Assumption challenge, ~150 lines estimate, genuine unknowns |
| `.claude/skills/e2e-record/SKILL.md` | Existing Playwright codegen skill (doesn't capture drag-drop) |

### Downstream / prerequisites

| Item | Relationship |
|---|---|
| `data-testid` seeding PR | **Prerequisite** — recorder doesn't work without it |
| Existing Playwright infrastructure (`e2e/`) | **Extend** — add planning page objects, flow-based tests |
| Existing Selenium suite (`Disposition-UI-Automation`) | **Future consumer** (V2) — Selenium generator reads same Flow JSON |
| `/e2e-record` Claude Code skill | **Complement** — handles non-drag flows via Playwright Codegen; this PRD handles drag-drop flows |

### Genuine unknowns (resolve by building, not analyzing)

| Unknown | Risk | Mitigation |
|---|---|---|
| Does CDK drag preview intercept `pointerup`? | Recorder misses drop target | Use `document.elementsFromPoint()` to look through the preview |
| Do Material overlay clicks trace back reliably? | Dropdown selections misattributed | Fall back to `mat-select` change event instead of click tracking |
| Does snapshot diff produce spurious assertions? | Noisy generated tests | Filter by visibility viewport intersection; tune in practice |
| CSP on test environment blocks bookmarklet? | Recorder can't inject | Host recorder script on same domain or use browser extension (C1) |
