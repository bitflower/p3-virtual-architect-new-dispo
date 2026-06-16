# Implementation Plan — PRD-006: Custom Flow Tracker for E2E Tests

**Status:** Implementation complete — acceptance verification in progress
**Branch:** `feature/playwright-e2e-tests` (continue on existing branch, 2 commits ahead of `master`)
**Worktrees:** No — file sets are fully disjoint across streams

---

## Decisions locked in

| # | Question | Answer |
|---|---|---|
| 1 | Branch base | Continue on `feature/playwright-e2e-tests` (existing Playwright infrastructure: config, page objects, auth test) |
| 2 | CSP testing | Earliest possible check. Pivot to localhost if CSP blocks bookmarklet — PO wants to start before next test release |
| 3 | Snapshot diff scope V1 | `expect-visible` assertions + spinner detection (S3). Element count assertions (S2) deferred to V2 |
| 4 | Dynamic testid on cards | Dedicated `data-testid` attributes: `lot-card-{id}`, `shipment-card-{id}`. Don't reuse existing `data-lot-id` — avoids coupling to a non-standard attribute |
| 5 | Generator format | Claude Code skill (like `/e2e-record`) |
| 6 | `cal-orders-list` testid | On `<lib-table>` element inside the component template |
| 7 | Drag-drop detection | Angular bridge: custom `flow-tracker:drop` DOM events emitted from existing CDK drop handlers. Eliminates CDK drag preview unknown |

---

## Architectural notes that bind the implementation

### PRD corrections

| PRD claim | Actual repo state |
|---|---|
| "8 Angular template files" for testid seeding | **7 HTML + 2 TS files.** PRD lists `single-date-time-picker.component.html` and `date-time-picker.component.html` (shared lib components). Correct approach: add testids at usage sites (`planning-page-header.component.html` and `create-transport-order-dialog.component.html`), not inside shared libs. PRD also omits the 2 TypeScript files needed for the Angular bridge custom events |
| "~150 lines of vanilla JS, no app changes needed" | Recorder is still ~150 lines vanilla JS, but the Angular bridge approach adds ~3 lines per drop handler in the app code. This is a conscious tradeoff: reliable drag capture vs pure-DOM purity |
| "9 data-testid attributes total" in frontend | 12 existing `data-testid` attributes on `feature/playwright-e2e-tests` branch (settings-drawer family, header buttons, transport-page-title, filter-close, paginator-touch-target) |
| Leg filter mapped as single element | The `mat-button-toggle-group` has 3 toggles (VL, HL, NL). Each needs a `data-testid` for the recorder to capture specific filter clicks |
| Date picker → `single-date-time-picker.component.html` | This shared lib component is reused across the app. Testid goes on `<single-date-time-picker>` usage in `planning-page-header.component.html:2`, not inside the lib |

### Verified integration points

| Integration point | Location | Notes |
|---|---|---|
| CDK drag sources | `planning-page.component.html:95-109` (lots), `:137-150` (shipments) | Both use `<cal-draggable-card>` with `cdkDrag`. Dynamic `data-testid` goes on the `<cal-draggable-card>` host element |
| CDK drop targets | `planning-list.component.html:17-26` (create-TO), `planning-page.component.html:32-41` (create-lot), `:94` (lot zones) | Static `data-testid` on the `<div cdkDropList>` wrappers |
| Drop handlers (Angular bridge) | `planning-list.component.ts:203` (`dropOnCreateTransportOrder`), `planning-page.component.ts:393` (`dropOnCreateLot`), `:401` (`dropOnLot`) | Each emits `flow-tracker:drop` CustomEvent with `{source, target}` testids |
| Material overlay for branch/language selectors | Both use `<lib-lookup-field>` (shared component, renders a `mat-select` or similar). Overlay opens in `.cdk-overlay-container` | Recorder's MutationObserver watches `.cdk-overlay-container` for option selections |
| Dialog overlay stack | `dropOnCreateTransportOrder` → opens `CreateTransportOrderDialogComponent` (overlay 1) → date-time-picker popup (overlay 2) → Apply → back to dialog → Erstellen | Three overlay levels. Recorder tracks overlay depth via MutationObserver counting children of `.cdk-overlay-container` |
| Existing page objects | `e2e/page-objects/app.page.ts` (CSS fallbacks with `// Target:` comments), `e2e/page-objects/login.page.ts` | New `planning.page.ts` follows the same pattern. `app.page.ts` can be updated to use `getByTestId()` once testids are deployed |
| Playwright config | `playwright.config.ts` — base URL `test.dispo.gcp.nagel-group.com`, Chromium only, 60s timeout | Recorder works on any URL (bookmarklet). Generator emits tests that use the configured base URL |
| `mat-spinner` elements | `planning-page.component.html:60` (lots loading), `:129` (shipments loading), `planning-list.component.html:32` (TO creating) | Recorder's spinner detection (S3) watches for `.mat-mdc-progress-spinner` via MutationObserver |

### Angular bridge custom event contract

```typescript
// Emitted by drop handlers, consumed by recorder
document.dispatchEvent(new CustomEvent('flow-tracker:drop', {
  bubbles: true,
  detail: {
    source: string,  // data-testid of dragged element, e.g. "shipment-card-6764480"
    target: string   // data-testid of drop zone, e.g. "drop-zone-create-transport-order"
  }
}));
```

Three emission sites:
1. `dropOnCreateTransportOrder` → source: `shipment-card-{event.item.data.identificationNumber}`, target: `drop-zone-create-transport-order`
2. `dropOnCreateLot` → source: `shipment-card-{event.item.data.identificationNumber}`, target: `drop-zone-create-lot`
3. `dropOnLot` → source: `shipment-card-{event.item.data.identificationNumber}`, target: `lot-card-{card.identificationNumber}`

---

## Schema — Flow JSON format

```json
{
  "version": "1.0",
  "recordedAt": "2026-06-16T14:30:00Z",
  "baseUrl": "http://localhost:4200",
  "steps": [
    {
      "action": "navigate",
      "url": "/de/planning",
      "timestamp": 1750000000000
    },
    {
      "action": "click",
      "testId": "branch-selector",
      "timestamp": 1750000001000
    },
    {
      "action": "select",
      "testId": "branch-selector",
      "value": "Kaufungen",
      "timestamp": 1750000002000
    },
    {
      "action": "click",
      "testId": "leg-filter-HL",
      "timestamp": 1750000003000
    },
    {
      "action": "click",
      "testId": "lot-card-12345",
      "timestamp": 1750000004000
    },
    {
      "action": "drag",
      "source": "shipment-card-6764480",
      "target": "drop-zone-create-transport-order",
      "timestamp": 1750000005000
    },
    {
      "action": "dialog-opened",
      "testId": "create-to-dialog",
      "timestamp": 1750000005500
    },
    {
      "action": "click",
      "testId": "create-to-date-input",
      "timestamp": 1750000006000
    },
    {
      "action": "click",
      "testId": "datepicker-apply",
      "meta": { "overlay": true },
      "timestamp": 1750000007000
    },
    {
      "action": "dialog-closed",
      "testId": "create-to-dialog",
      "timestamp": 1750000007500
    },
    {
      "action": "click",
      "testId": "create-to-confirm",
      "timestamp": 1750000008000
    },
    {
      "action": "expect-visible",
      "testId": "lot-card-12345",
      "meta": { "autoGenerated": true, "waitedMs": 2000, "loadingIndicatorSeen": true },
      "timestamp": 1750000010000
    }
  ]
}
```

Action categories:
- **Navigation:** `navigate` (url)
- **Interaction:** `click` (testId), `select` (testId, value), `fill` (testId, value), `drag` (source, target)
- **Expectation:** `expect-visible` (testId), `expect-text` (testId, text)
- **Context:** `dialog-opened` (testId), `dialog-closed` (testId)

Timing metadata: `timestamp` (ms epoch), `meta.waitedMs` (observed wait before next action), `meta.loadingIndicatorSeen` (boolean, spinner detected between actions).

---

## File-level work breakdown

### Stream 0 — Foundation (main session)

| File | Action | Content |
|---|---|---|
| `e2e/recorder/flow-schema.json` | **Create** | JSON Schema for Flow JSON format (validates recorded files) |
| `e2e/GETTING-STARTED.md` | **Modify** | Add `data-testid` naming convention section (S1): `[feature]-[element]-[qualifier]` for static, `[feature]-[element]-{dynamicId}` for cards. Document all 15+ testid values |
| CSP check | **Manual** | Open `test.dispo.gcp.nagel-group.com` in Chrome, run `javascript:alert(1)` in address bar. If blocked, confirm localhost as primary target |

**Constraints:** No Angular source code changes. No page objects. Foundation only.

### Stream A — `data-testid` seeding + Angular bridge (agent)

Owns these files exclusively:

| File | Changes |
|---|---|
| `apps/.../pages/planning-page/planning-page.component.html` | Add `[attr.data-testid]="'lot-card-' + cardConfig.identificationNumber"` on `<cal-draggable-card>` at line 95. Add `[attr.data-testid]="'shipment-card-' + shipment.identificationNumber"` on `<cal-draggable-card>` at line 137. Add `data-testid="lot-refresh-button"` on `<button>` at line 16. Add `data-testid="drop-zone-create-lot"` on `<div cdkDropList>` at line 32. Add `data-testid="leg-filter-VL"`, `data-testid="leg-filter-HL"`, `data-testid="leg-filter-NL"` on respective `<mat-button-toggle>` at lines 53-55 |
| `apps/.../pages/planning-page/planning-page.component.ts` | Add `flow-tracker:drop` CustomEvent dispatch in `dropOnCreateLot()` (line 393) and `dropOnLot()` (line 401) |
| `apps/.../components/planning-list/planning-list.component.html` | Add `data-testid="transport-order-refresh-button"` on `<button>` at line 4. Add `data-testid="drop-zone-create-transport-order"` on `<div cdkDropList>` at line 17 |
| `apps/.../components/planning-list/planning-list.component.ts` | Add `flow-tracker:drop` CustomEvent dispatch in `dropOnCreateTransportOrder()` (line 203) |
| `apps/.../components/branch-lookup-field/branch-lookup-field.component.html` | Add `data-testid="branch-selector"` on `<lib-lookup-field>` at line 3 |
| `libs/nagel-components/src/lib/header/header.component.html` | Add `data-testid="language-selector"` on `<lib-lookup-field>` at line 6 |
| `apps/.../pages/planning-page/planning-page-header/planning-page-header.component.html` | Add `data-testid="planning-date-range-picker"` on `<single-date-time-picker>` at line 2 |
| `apps/.../components/cal-orders-list/cal-orders-list.component.html` | Add `data-testid="transport-order-list"` on `<lib-table>` at line 8 |
| `apps/.../components/create-transport-order-dialog/create-transport-order-dialog.component.html` | Add `data-testid="create-to-dialog"` on root `<div>` at line 1. Add `data-testid="create-to-date-input"` on `<date-time-picker>` at line 5. Add `data-testid="create-to-cancel"` on cancel `<button>` at line 8. Add `data-testid="create-to-confirm"` on confirm `<button>` at line 9 |

**Constraints:**
- Must NOT touch any file under `e2e/`
- Must NOT modify shared lib component internals (`single-date-time-picker.component.html`, `date-time-picker.component.html`)
- Testids on shared components go at usage sites only
- Follow naming convention: `[feature]-[element]-[qualifier]` kebab-case
- CustomEvent must use `bubbles: true` so it propagates to `document`
- Keep `id="cancel_button"` and `id="confirm_button"` on dialog buttons (existing code may depend on them); add `data-testid` alongside

**Total: 7 HTML files + 2 TS files, ~30 lines changed**

### Stream B — Recorder bookmarklet (agent)

Owns this file exclusively:

| File | Action |
|---|---|
| `e2e/recorder/flow-tracker.js` | **Create** — ~150-170 lines vanilla JS |

Recorder capabilities:
1. **Click capture:** Listen for `click` on elements with `data-testid` (walk up DOM from `event.target` to find nearest ancestor with `[data-testid]`)
2. **Drag capture:** Listen for `flow-tracker:drop` CustomEvent on `document` (Angular bridge)
3. **Material overlay tracking:** MutationObserver on `.cdk-overlay-container` — detect `select` actions by correlating overlay option clicks back to the trigger element's testid
4. **Dialog tracking:** Count children of `.cdk-overlay-container` to track overlay depth, emit `dialog-opened`/`dialog-closed` context markers
5. **Spinner detection (S3):** MutationObserver for `.mat-mdc-progress-spinner` presence between user actions — sets `meta.loadingIndicatorSeen: true`
6. **Snapshot diff for assertions:** Before each user action, snapshot visible `[data-testid]` elements. After next action settles (MutationObserver idle + no spinner), diff snapshots. New testids → emit `expect-visible` assertions automatically
7. **UI:** Floating toggle button (Start/Stop). On stop: copy Flow JSON to clipboard + trigger file download
8. **Activation:** Bookmarklet wrapper (`javascript:(function(){...})()`) — self-contained, no external fetch

**Constraints:**
- Must NOT touch any Angular source file
- Must NOT import or require any dependency
- Must NOT use framework-specific APIs (no Angular, no Zone.js)
- Must NOT use `getByText`, translated strings, or CSS class selectors
- `data-testid` is the ONLY element identification mechanism
- Must work on both localhost:4200 and test.dispo.gcp.nagel-group.com (if CSP allows)

### Stream C — Generator skill + page objects (agent)

Owns these files exclusively:

| File | Action |
|---|---|
| `.claude/skills/flow-to-test/SKILL.md` | **Create** — Claude Code skill definition |
| `e2e/page-objects/planning.page.ts` | **Create** — Planning view page object using `page.getByTestId()` for all 15+ elements |
| `e2e/page-objects/index.ts` | **Modify** — Add `export { PlanningPage } from './planning.page'` |

Generator skill behavior:
1. Accept a Flow JSON file path as input
2. Validate structure against the flow schema
3. Map each action to Playwright code:
   - `click` → `await page.getByTestId('...').click()`
   - `select` → Material select interaction pattern
   - `drag` → `await page.getByTestId('source').dragTo(page.getByTestId('target'))`
   - `expect-visible` → `await expect(page.getByTestId('...')).toBeVisible()`
   - `expect-text` → `await expect(page.getByTestId('...')).toContainText('...')`
   - `dialog-opened/closed` → comments/structure markers
4. Use `PlanningPage` page object for locator access
5. Generate timeout from timing metadata: `max(5000, meta.waitedMs × 2)` for observed slow actions
6. If `meta.loadingIndicatorSeen`, emit `await expect(page.locator('.mat-mdc-progress-spinner')).toBeHidden()` before next assertion
7. Output: `e2e/tests/<slug>.spec.ts` following existing test file conventions

Page object pattern (matches existing `app.page.ts`):
```typescript
export class PlanningPage {
  readonly branchSelector: Locator;
  readonly lotRefreshButton: Locator;
  // ... all static elements
  
  constructor(page: Page) {
    this.branchSelector = page.getByTestId('branch-selector');
    // ...
  }
  
  lotCard(id: string): Locator {
    return this.page.getByTestId(`lot-card-${id}`);
  }
  
  shipmentCard(id: string): Locator {
    return this.page.getByTestId(`shipment-card-${id}`);
  }
}
```

**Constraints:**
- Must NOT touch any Angular source file
- Must NOT modify `e2e/recorder/` files
- Must follow existing page object conventions from `app.page.ts`
- Test files go in `e2e/tests/`, page objects in `e2e/page-objects/`
- Use `page.getByTestId()` exclusively — no CSS selectors, no XPath, no translated text

---

## Code review gates

| Gate | After | Lenses | Focus |
|---|---|---|---|
| G1 | Stream 0 | Architectural + Clean-code | Schema correctness, naming convention completeness |
| G2 | Stream A | Architectural + Clean-code | Testid placement correctness (shared vs local), Angular bridge event contract, no unintended side effects on drop handlers, attribute binding syntax |
| G3 | Stream B | Clean-code + Architectural mini-pass | Recorder correctness (event handling, MutationObserver cleanup, memory leaks on long sessions), function size, no accidental data capture |
| G4 | Stream C | Clean-code | Page object completeness, generator mapping correctness, skill definition clarity, consistency with existing `app.page.ts` patterns |
| G5 | Integration | Architectural | Does the full chain work: record → export JSON → generate test → test passes? Cross-cutting: timing, assertions, dialog flow |

Gates G2, G3, G4 run in parallel (disjoint file sets).

---

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| CSP blocks bookmarklet on test environment | Medium | High — recorder doesn't work on deployed app | Test CSP in Stream 0. Pivot to localhost for V1. Chrome extension (C1) as V2 upgrade if needed |
| Material overlay clicks don't trace back to trigger reliably | Medium | Medium — dropdown selections misattributed | Recorder falls back to `mat-select` `selectionChange` event listening if MutationObserver correlation fails |
| Snapshot diff produces spurious assertions (lazy load, accordion animations) | High | Medium — noisy generated tests | V1 filters: only diff testids that are visible in viewport (IntersectionObserver check). Ignore elements during active CSS transitions. Developer deletes false assertions from generated test |
| `Playwright dragTo()` doesn't trigger CDK drop handlers | Medium | High — generated drag tests don't work | CDK drag-drop may require specific pointer event sequences, not just HTML5 drag. If `dragTo()` fails, generator emits manual pointer event sequence (`page.dispatchEvent`) |
| PO records on localhost but generated tests run on test env with different data | Medium | Medium — tests fail due to data mismatch | Flow JSON captures testid patterns, not specific text/data. Dynamic IDs (lot numbers, shipment numbers) are parameterized in the generated test as variables the developer fills in |
| Three-level overlay tracking (page → dialog → datepicker) produces incorrect dialog-opened/closed markers | Medium | Low — test still works, just missing structure markers | Recorder counts `.cdk-overlay-container` children. dialog-opened when count increases, dialog-closed when it decreases. The nesting is implicit from count changes |

---

## Out of scope

- **S2: Element count assertions** — deferred to V2 (snapshot diff produces `expect-visible` only in V1)
- **C1: Chrome extension wrapper** — deferred unless CSP blocks bookmarklet on all target environments
- **C2: Flow replay visualization** — V2
- **C3: Selenium NUnit generator** — V2 (suite stale, needs selector migration first)
- **W1–W6 from PRD** — explicitly excluded
- **Updating `app.page.ts` CSS fallbacks to `getByTestId()`** — separate cleanup task after testids are deployed
- **Tour calculation flow recording** — TOP Service integration involves 30s+ async operations outside recorder's timing model
- **Migration of existing 34 Selenium tests to `data-testid`** — separate effort, not part of this PRD

---

## Acceptance checklist

Derived from PRD Section 7 (Verification):

### Functional
- [x] All 15 PO-identified elements have `data-testid` attributes visible in browser DevTools (plus 3 individual leg filter toggles = 18 total testid additions)
- [x] Three `flow-tracker:drop` CustomEvents fire correctly on each drop handler (verify in DevTools console: `document.addEventListener('flow-tracker:drop', e => console.log(e.detail))`)
- [x] PO activates bookmarklet on localhost, records the core planning flow (branch select → HL filter → lot select → drag shipment → dialog → date → confirm → verify TO)
- [x] Recorder exports valid Flow JSON matching the defined schema
- [x] `/flow-to-test` skill produces a runnable `.spec.ts` from the recorded Flow JSON
- [x] Generated test passes against localhost (with test data present)
- [x] Generated test fails when a business expectation is violated — mutation test: disabled `dropOnCreateTransportOrder` body, test failed on `expect(createToDialog).toBeVisible()` at line 59 as expected (2026-06-16)

### Recorder edge cases
- [ ] Material dropdown (branch selector) captured as `select` action with correct testid + value
- [x] Drag-to-create-TO captured as `drag` action via Angular bridge event (not pointer heuristics)
- [ ] Two-level dialog flow captured: datepicker Apply + dialog Erstellen as separate `click` actions with correct testids
- [x] Overlay depth tracking produces correct `dialog-opened`/`dialog-closed` markers — fixed: recorder now uses `lastDragTarget` as fallback when `lastClickedTestId` is null (2026-06-16)
- [x] Spinner detection (S3) sets `meta.loadingIndicatorSeen` when `mat-spinner` appears between actions

### Assertions
- [x] Snapshot diff identifies new testids appearing after lot selection → generates `expect-visible`
- [x] Snapshot diff identifies dialog appearing after drag → generates `expect-visible` for `create-to-dialog`
- [ ] Snapshot diff does NOT produce spurious assertions from scrolling, lazy load, or accordion toggling

### Timing
- [x] Generated test handles 1-3s API response after branch selection (Playwright auto-wait, no hardcoded `waitForTimeout`)
- [x] Generated test emits "wait for spinner to disappear" when `loadingIndicatorSeen` is true
- [x] No `waitForTimeout()` calls in generated output

---

## Execution order

1. **Rebase from master** — `git fetch origin && git rebase origin/master` on `feature/playwright-e2e-tests` to pick up latest frontend changes. Resolve any conflicts before proceeding
2. **Phase 2: Commit plan** — commit this file to `feature/playwright-e2e-tests`
3. **Stream 0: Foundation** — Flow JSON schema, GETTING-STARTED.md naming convention, CSP check
4. **Gate G1** — review Stream 0
5. **Streams A + B + C in parallel** — spawn 3 agents in single message
6. **Gates G2 + G3 + G4 in parallel** — review all 3 streams (disjoint file sets)
7. **Fix review findings** — Critical/High before integration, Medium if cheap
8. **Integration** — verify full chain on localhost: record → export → generate → run test
9. **Gate G5** — architectural review of integrated feature
10. **Report** — green/red status, review finding counts, plan deviations

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
