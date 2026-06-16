# Custom Flow Tracker for E2E Tests

**Date:** 2026-06-16
**Status:** Exploration

---

## Original User Input

> Due to the new dispo UX that is heavily relying on drag and drop, we can't use these tools. The idea is to write a custom flow tracker, if you won't want to call it like that, that allows users or test engineers or product owners to record business flows in the UI which then can be turned into automated tests.

---

## Problem Statement

The New Dispo planning view relies heavily on drag & drop (assigning orders to tours, reordering stops, etc.). Neither of the two standard recording tools captures drag & drop:

| Tool | Drag & Drop | Selector Quality | i18n Safe |
|------|-------------|-----------------|-----------|
| Playwright Codegen | not captured | `getByText()` fallback — breaks with i18n | No |
| Chrome DevTools Recorder | not captured (clicks only) | `nth-of-type`, xpath — brittle | No |

Both tools produce a raw draft that requires heavy manual cleanup before it becomes a usable test. For a UX built around drag & drop, these tools cover less than half the interaction surface.

### Playwright Codegen — detailed limitations

```bash
npx playwright codegen --target playwright-test --test-id-attribute data-testid "URL"
```

| Capability | Supported | Notes |
|------------|-----------|-------|
| Click | Yes | |
| Text input / fill | Yes | |
| Navigation | Yes | |
| Select / dropdown | Yes | |
| Keyboard shortcuts | Yes | |
| `data-testid` selectors | Yes | requires `--test-id-attribute data-testid` flag |
| **Drag & drop** | **No** | not captured — write `locator.dragTo(target)` manually |
| **CSS selector output** | **No** | no flag to force CSS selectors; priority is hardcoded |
| **Hover-only interactions** | **No** | hover menus/tooltips without click are not recorded |
| **Screenshots** | **No** | add `await page.screenshot()` in test code |

Selector priority (not configurable): `data-testid` → ARIA role + name (`getByRole`) → text content (`getByText`) → CSS. This means recordings contain `getByText('German text')` for most elements — **unusable** in an i18n app.

### Chrome DevTools Recorder — detailed limitations

Built-in: **DevTools → ⋮ → More tools → Recorder** (no plugin needed).

| Capability | Supported | Notes |
|------------|-----------|-------|
| Click | Yes | |
| Text input / change | Yes | |
| Navigation | Yes | |
| Viewport / device emulation | Yes | |
| Export to Playwright | Yes | via export menu or `@playwright/chrome-recorder` |
| **Drag & drop** | **No** | captures clicks at start/end but misses the pointer move sequence |
| **Selector quality** | **Poor** | generates `nth-of-type`, xpath, `pierce/` — brittle and verbose |
| **i18n awareness** | **No** | captures `aria/Speichern`, `text/Erstellen` — breaks in other locales |

Exports a JSON with `steps[]` where each step has a `type` (`click`, `change`, `navigate`, `setViewport`) and multiple selector strategies. None map cleanly to `data-testid` selectors.

## Core Concept: Test-Anchored Elements

The developers building the UI **know** which elements are the main players — the order cards, tour slots, filter buttons, branch selector, drawers. These elements get a `data-testid` attribute. Once these anchors are in place, recording a business flow reduces to **capturing the interplay between test-anchored elements**.

```
Standard recorder sees:              With test anchors:

pointerdown at (342, 718)            drag data-testid="order-card-FA001"
pointermove (342→810, 718→290)    →    to data-testid="tour-slot-T103"
pointerup at (810, 290)

click at (120, 45)                   click data-testid="branch-selector"
click at (120, 112)                  click data-testid="branch-option-ABN1034"
```

The recorder doesn't need to understand the DOM tree, CSS classes, or Angular internals. It only needs to observe: **which `data-testid` element was interacted with, and how** (click, drag-to, fill, etc.).

This shifts the problem:
- **Without anchors:** the recorder must reverse-engineer meaning from raw DOM — fragile, locale-dependent, framework-coupled
- **With anchors:** the recorder watches a small, stable set of marked elements — any approach (pure JS, extension, Angular-integrated) becomes viable because the hard part (identifying *what* was interacted with) is already solved in the markup

The investment is in the `data-testid` attributes. The recorder itself becomes simple.

## Idea: Custom Flow Tracker

Build a recording tool that captures the interplay between test-anchored elements, including drag & drop. **No approach has been chosen yet** — this section explores the solution space.

### Target Users

| Who | Goal |
|-----|------|
| **Product Owners** | Record acceptance criteria as flows, hand off to dev |
| **Test Engineers** | Record regression tests without reading Angular code |
| **Developers** | Rapid test scaffolding from real UI sessions |

### Core Question

Where does the recording logic live, and at what level does it capture interactions?

There is a spectrum from low-level (DOM events, like Playwright does) to high-level (semantic business actions via framework integration):

```
DOM events                                              Semantic actions
  ├── pointerdown/move/up                ... → "dragOrderToTour(FA-001, T-103)"
  ├── click at (342, 718)                ... → "selectBranch(ABN1034)"
  ├── input value changed                ... → "setFilter(status=open)"
  └── navigation to /de/planning         ... → "navigate(/de/planning)"

  Pure JS / browser-level                     Angular-integrated
```

Low-level is framework-agnostic but produces brittle output (same problem as Playwright Codegen). High-level is robust but coupled to Angular internals. The right answer likely sits somewhere in between.

### Approach A: Pure JavaScript / DOM-level recorder

A standalone script (injected via bookmarklet, browser extension, or `<script>` tag) that listens to native DOM events — no Angular dependency.

**How it captures drag & drop:**
- Listen to `pointerdown` → `pointermove` → `pointerup` sequences
- Identify source/target elements via `data-testid` or other stable attributes
- Emit a drag action when the pointer travels beyond a threshold before release

**Pros:**
- Framework-agnostic — works on any web app
- Zero impact on app code
- Could be reused across projects
- Closest to what Playwright "should" do but doesn't

**Cons:**
- No access to business model (only knows DOM elements, not "order FA-001")
- Needs `data-testid` or stable attributes everywhere to produce usable output
- Must reverse-engineer what Angular CDK considers a valid drop zone

**Effort estimate:** Medium — drag detection logic needs tuning, but no app changes required.

### Approach B: Chrome Extension

A browser extension with a DevTools panel or popup UI that records interactions.

**How it captures drag & drop:**
- Content script injects event listeners (same as Approach A) OR
- App emits `CustomEvent`s that the extension listens to (hybrid with Approach C)

**Pros:**
- Separate from the app — no bundle impact, independent release cycle
- Nice activation UX (extension icon, DevTools panel)
- Can persist recordings in extension storage
- Can work across environments (test, UAT, local) without app changes

**Cons:**
- If pure DOM: same limitations as Approach A
- If relying on `CustomEvent`s from the app: needs app-side changes anyway
- Two codebases to maintain
- Chrome-only (Edge works, Firefox/Safari don't)

**Effort estimate:** Medium-High — extension scaffolding + the recorder logic itself.

### Approach C: Angular-integrated recorder

A service/module inside the Angular app that hooks into Angular CDK events, router, services, and stores.

**How it captures drag & drop:**
- Listens to `CdkDragDrop` events which already carry `previousContainer`, `container`, `previousIndex`, `currentIndex`, and the data model
- Gets semantic meaning for free: "order FA-2026-001 dropped onto tour T-103"

**Pros:**
- Highest fidelity — records business actions, not coordinates
- Output survives template refactors, CSS changes, i18n switches
- Leverages existing Angular CDK infrastructure
- Can tap into any service/store for rich context

**Cons:**
- Coupled to Angular — not reusable on other apps
- Ships with the app code (needs feature flag or build-time exclusion)
- Requires buy-in from the frontend team

**Effort estimate:** Medium — Angular DI makes wiring easy, but scope must be controlled.

### Approach D: Hybrid — thin DOM layer + optional Angular bridge

A standalone recorder (JS or extension) that works at DOM level by default, but can receive richer events from an optional Angular bridge when available.

**How it captures drag & drop:**
- Base layer: DOM pointer events → detects drag gestures → reads `data-testid` from source/target
- Angular bridge (opt-in): emits `CustomEvent`s with business model data on `CdkDragDrop`
- Recorder merges both signals: DOM for basic interactions, bridge for semantic enrichment

**Pros:**
- Works without Angular changes (degraded but functional)
- Gets semantic richness when the bridge is present
- App-side bridge is tiny (a few event emitters)
- Recorder is reusable; bridge is project-specific

**Cons:**
- Two moving parts
- Must define a contract between bridge and recorder

**Effort estimate:** Medium-High — but most flexible long-term.

### Recording Output

Regardless of approach, the recorder produces a JSON flow file. The level of detail depends on the approach:

**DOM-level output** (Approaches A/B without bridge):
```json
[
  { "action": "navigate", "url": "/de/planning" },
  { "action": "click", "testId": "branch-selector" },
  { "action": "click", "testId": "branch-option-ABN1034" },
  { "action": "drag", "sourceTestId": "order-card-12345", "targetTestId": "tour-slot-T103" }
]
```

**Semantic output** (Approach C or D with bridge):
```json
[
  { "action": "navigate", "to": "/de/planning" },
  { "action": "selectBranch", "branch": "ABN1034" },
  { "action": "dragOrderToTour", "orderId": "FA-2026-001", "tourId": "T-103" },
  { "action": "reorderStop", "stopId": "S-42", "fromIndex": 2, "toIndex": 0 }
]
```

Both formats can be transformed into Playwright specs — semantic output produces more readable, more stable tests.

### Comparison Matrix

| | A: Pure JS | B: Extension | C: Angular | D: Hybrid |
|---|---|---|---|---|
| Captures drag & drop | Yes (DOM) | Yes (DOM) | Yes (CDK) | Yes (both) |
| Semantic business actions | No | No / Partial | Yes | Yes (with bridge) |
| App code changes needed | No | No / Minimal | Yes | Minimal (bridge) |
| Framework-agnostic | Yes | Yes | No | Mostly |
| Activation UX | Bookmarklet / script tag | Extension icon | Feature flag / URL param | Extension or bookmarklet |
| Works on production | Yes | Yes | If feature-flagged | Yes |
| Reusable across projects | Yes | Yes | No | Recorder yes, bridge no |

### Open Questions

- [ ] Which approach to pursue? Or prototype multiple?
- [ ] Should the tracker record **assertions** too (e.g. "I see 5 stops on this tour") or only actions?
- [ ] How to handle **timing** — record waits/loading states or let the test framework handle that?
- [ ] Should it integrate with the existing Playwright page object structure or generate a new abstraction?
- [ ] Does it need to work on production or only dev/test environments?
- [ ] MVP scope: which actions are enough for a first useful version?
- [ ] Who builds it — frontend team, architecture, external?

### Possible MVP Scope (approach-independent)

Minimum to be useful for the planning view:

1. **Record:** navigate, branch select, drag-order-to-tour, drag-reorder-stop
2. **Export:** JSON file download
3. **Generate:** Claude Code skill or CLI that reads the JSON and produces a Playwright spec
4. **Activation:** depends on chosen approach

## Related Files

- [`Code/Disposition-Frontend/e2e/GETTING-STARTED.md`](../../Code/Disposition-Frontend/e2e/GETTING-STARTED.md) — E2E getting started guide
- [`Code/Disposition-Frontend/playwright.config.ts`](../../Code/Disposition-Frontend/playwright.config.ts) — Playwright config
- [`Code/Disposition-Frontend/e2e/page-objects/`](../../Code/Disposition-Frontend/e2e/page-objects/) — Existing page objects
- [`.claude/skills/e2e-record/SKILL.md`](../../.claude/skills/e2e-record/SKILL.md) — E2E record skill
