# Minimal Recorder — Demystified

**Date:** 2026-06-16
**Trigger:** The "manual flow description by PO" approach is unrealistic — the PO won't produce usable JSON, and it doesn't deliver the efficiency gain we're after. Time to brutally face what a minimal recorder actually requires.

---

## Assumptions to Challenge

| # | Assumption | Status |
|---|---|---|
| A1 | "Drag detection is hard" | **Challenge below** |
| A2 | "The recorder needs to understand Angular/CDK internals" | **Challenge below** |
| A3 | "Assertion capture requires complex state tracking" | **Challenge below** |
| A4 | "The recorder needs a polished UI" | **Challenge below** |
| A5 | "Dropdown/select capture needs special handling" | **Challenge below** |
| A6 | "The recorder needs a build step / dependencies" | **Challenge below** |
| A7 | "Timing requires sophisticated detection" | **Already resolved — it doesn't** |

---

## A1: "Drag detection is hard"

**Reality:** The New Dispo uses CDK's pointer-based drag. At the DOM level, this is:

1. `pointerdown` on element A (lot card or shipment card — has `data-testid`)
2. `pointermove` events (element moves across screen)
3. `pointerup` on element B (drop zone — has `data-testid`)

The recorder doesn't need to understand CDK. It needs:
- On `pointerdown`: remember the source element's `data-testid`
- On `pointerup`: if the pointer moved more than ~10px from the start point, it's a drag. Read the target element's `data-testid`.
- Emit: `{ action: "drag", source: "shipment-card-6764480", target: "drop-zone-create-transport-order" }`

**Complication:** During a CDK drag, the dragged element gets cloned as a preview and the original stays in place. The `pointerup` fires on whatever element is under the cursor at release. If the drop zone has a `data-testid`, the recorder catches it. If the `pointerup` fires on the CDK preview/placeholder instead, the recorder needs to look at the underlying element.

**Mitigation:** Walk up from the `pointerup` target to find the nearest `data-testid`. CDK drop zones are the outer `div` with `cdkDropList` — as long as these divs have `data-testid`, the recorder finds them.

**Size:** ~25 lines of JS.

**Verdict: Not hard.** The complexity was in my head, not in the DOM events.

---

## A2: "The recorder needs to understand Angular/CDK"

**Reality:** The recorder is a vanilla JS script injected into the page. It sees the DOM, not Angular. It doesn't need to:
- Import Angular modules
- Listen to CDK-specific events
- Access Angular services or stores
- Know about signals, observables, or change detection

It ONLY needs to:
- Listen to native DOM events (`click`, `pointerdown`, `pointerup`, `input`, `change`)
- Read `data-testid` attributes from elements
- Read text content from elements (for domain context like "Partie Nr: 6223")

**What Angular integration WOULD add (V2):**
- Richer domain context (lot ID, shipment model data)
- Knowledge of which actions triggered API calls
- Loading state awareness from Angular services

But none of this is needed for the minimal recorder.

**Verdict: No Angular knowledge required.** Pure DOM events + `data-testid` attributes.

---

## A3: "Assertion capture requires complex state tracking"

**Reality:** The PO's assertions are visual: "after I clicked X, I see Y." The minimal assertion capture is:

**Before each action:** Snapshot which `data-testid` elements are visible on screen.
**After each action:** Snapshot again. Diff the two lists.

- **Elements that appeared** → `expect-visible` assertions
- **Elements that disappeared** → `expect-hidden` assertions (optional)
- **Text that changed** → `expect-text` assertions (optional)

The "snapshot" is one line: `document.querySelectorAll('[data-testid]')` filtered by visibility.

**Complication: When to take the "after" snapshot?**

The PO clicks, waits for the UI to update, then does their next action. The time between two PO actions IS the wait time. So the "after" snapshot is taken at the moment of the NEXT action, not immediately after the current one.

```
PO clicks lot-card-6223             → snapshot BEFORE click
  ... system loads shipments (2s) ...
PO clicks shipment-card-6764480    → snapshot BEFORE this click = "after" snapshot of previous action
                                      diff = shipment cards appeared → expect-visible assertions
```

This is elegant: the recorder doesn't need to poll or detect loading completion. The PO's own waiting behavior is the timing mechanism. When the PO interacts next, the screen must have already updated — otherwise the PO wouldn't be clicking on the new element.

**Size:** ~20 lines of JS (snapshot + diff).

**Verdict: Simpler than expected.** The PO's natural interaction pace handles the timing problem, and the diff between snapshots gives us assertions for free.

---

## A4: "The recorder needs a polished UI"

**Reality:** For the minimal version, the PO needs exactly three controls:

1. **Start recording** — click a button or activate a bookmarklet
2. **Stop recording** — click the button again
3. **Get the output** — copy JSON from clipboard or download a file

That's a floating button in the corner of the screen. No panel, no timeline, no replay, no editing.

```
┌──────────────────────────────────────────────┐
│  App UI (planning page)                      │
│                                              │
│                                              │
│                                    [● REC]   │  ← floating button, top-right
│                                              │
└──────────────────────────────────────────────┘
```

- Red dot = recording. Click to stop.
- Square = stopped. Click to start.
- On stop: JSON is copied to clipboard + downloaded as `.flow.json`.

**Size:** ~30 lines of HTML/JS for the button + clipboard/download.

**Verdict: Trivial UI.** A floating button, not an application.

---

## A5: "Dropdown/select capture needs special handling"

**Reality:** Angular Material `mat-select` opens an overlay (CDK overlay) when clicked. The options (`mat-option`) render inside this overlay, which is appended to `<body>`, NOT inside the original `mat-select` element.

When the PO clicks an option:
1. `click` fires on the `mat-option` element (inside overlay)
2. The `mat-option` does NOT have the parent's `data-testid`
3. The overlay closes
4. The `mat-select` value updates

**The recorder needs to handle this.** Two approaches:

**Approach 1: Track overlay origin.** When an overlay opens (detected by `MutationObserver` on `<body>` for `.cdk-overlay-container`), remember which `data-testid` element triggered it. When a click happens inside the overlay, attribute it to the trigger element.

**Approach 2: Listen to `change` events.** Instead of tracking the click on `mat-option`, listen to the `change`/`selectionChange` event on the `mat-select` and capture the new value.

**Approach 3: Simplest.** The `lib-lookup-field` component has a `key` attribute (e.g., `key="branch"`). After the overlay closes, find the element whose `data-testid` corresponds to the dropdown and read its current value. The sequence becomes:

```json
{ "action": "select", "target": "branch-selector", "value": "ABN1034" }
```

Not "click on mat-option with text Kaufungen."

**Size:** ~20 lines for overlay tracking via MutationObserver. Or ~10 lines if we just capture the result (selected value) rather than the click path.

**Verdict: Needs handling but not complex.** The overlay pattern is the same for all Material dropdowns — solve it once.

---

## A6: "The recorder needs a build step / dependencies"

**Reality:** The recorder is a single vanilla JS file. No TypeScript, no npm, no bundler. It runs in the browser via:

- **Bookmarklet:** `javascript:(function(){...})()` — PO clicks a bookmark
- **Browser console paste:** Copy-paste the script into DevTools console
- **Chrome extension:** More polished but more effort to distribute
- **Script tag injection:** Dev adds `<script src="recorder.js">` behind a feature flag

For the minimal version: **bookmarklet or console paste.** Zero infrastructure.

**Size:** The entire recorder fits in one file. No build step.

**Verdict: Zero infrastructure required.**

---

## Resolved: What the Minimal Recorder Actually Is

After challenging all assumptions, the minimal recorder is:

| Component | Lines of JS (estimate) | What it does |
|---|---|---|
| Event listeners | ~25 | Click, pointerdown/up (drag), input/change (fills) |
| `data-testid` resolver | ~15 | Walk up DOM from event target to find nearest `data-testid` |
| Drag detection | ~15 | Pointer distance threshold, source/target `data-testid` extraction |
| Overlay tracking | ~20 | MutationObserver for Material overlays, attribute clicks to trigger element |
| Snapshot + diff | ~20 | Capture visible `data-testid` elements, diff between actions for assertions |
| Timing capture | ~5 | `Date.now()` on each event, compute gaps |
| Floating UI button | ~30 | Start/stop toggle, download/clipboard export |
| Flow JSON assembly | ~20 | Build the JSON structure, add metadata |
| **Total** | **~150** | **One file, no dependencies, no build step** |

### What this captures out of the box

| PO Action | Captured as | Assertion generated |
|---|---|---|
| Click a lot card | `{ action: "click", target: "lot-card-6223" }` | `expect-visible` for shipment cards that appeared |
| Click leg filter HL | `{ action: "click", target: "leg-filter-HL" }` | `expect-hidden` for lots that disappeared |
| Select branch from dropdown | `{ action: "select", target: "branch-selector", value: "ABN1034" }` | `expect-visible` for lot cards that appeared |
| Drag shipment to create TO | `{ action: "drag", source: "shipment-card-6764480", target: "drop-zone-create-transport-order" }` | `expect-visible` for dialog/new card |
| Fill date in picker | `{ action: "fill", target: "planning-date-range-picker", value: "28/06/2026" }` | none (value is the action, not the outcome) |

### What this does NOT capture (genuine V2 items)

| Gap | Why it's V2 | Workaround in V1 |
|---|---|---|
| Domain model enrichment ("order FA-2026-001" vs. "shipment-card-6764480") | Requires Angular bridge to read model data | `data-testid` with IDs is human-readable enough |
| Assertion on specific text/values inside cards | Snapshot only tracks `data-testid` presence, not inner text | Developer adds `expect-text` assertions to generated test manually |
| Cross-step relative assertions ("fewer lots than before") | Needs snapshot comparison logic in generator | Developer adds manually or V2 recorder captures counts |
| Nested dialog flows (drag → dialog → fill → confirm) | Dialog elements need `data-testid` too | Add `data-testid` to dialog elements (same effort as other elements) |

---

## The PO's Actual Experience

```
1. PO opens the planning page in their browser
2. PO clicks the "Record" bookmarklet → red dot appears in corner
3. PO clicks through their business flow naturally:
   - Select branch → lots appear
   - Click HL filter → lots filter
   - Click lot 6223 → shipments appear  
   - Drag shipment 6764480 to create-transport-order → dialog opens
   - Fill date → confirm → transport order created
4. PO clicks the red dot to stop → JSON downloaded to their machine
5. PO sends the .flow.json to the team (email, Slack, Teams, Git)
6. Developer/skill runs the generator → Playwright test + Selenium test
7. Developer reviews, adjusts timeouts, adds edge-case assertions, commits
```

**Total PO effort:** ~2 minutes of clicking through the flow they already know.
**Total developer effort:** Review generated test, tune timeouts, add business-specific assertions.
**No JSON writing, no technical knowledge required from the PO.**

---

## What the Minimal Recorder Depends On

| Dependency | Status | Effort to resolve |
|---|---|---|
| `data-testid` on 11 PO elements | Not done | ~20 lines across 6 Angular templates |
| `data-testid` on dialog elements (create TO dialog) | Not assessed | Need to identify and count dialog elements |
| `data-testid` naming convention agreed | Proposed in `ui-angular-template-mapping.md` | Decision, not engineering |
| Playwright generator | Not built | Separate concern, can be a Claude Code skill |
| Selenium generator | Not built | V2 |

---

## Revised Build Scope — Single Sprint

Given the actual size (~150 lines, no dependencies), the recorder is NOT a Sprint 2 item. It can ship with Sprint 1:

| Work Item | Effort | Who |
|---|---|---|
| Add `data-testid` to 11 PO elements + dialog elements | ~1 day | Frontend developer |
| Build minimal recorder (bookmarklet) | ~2-3 days | Developer (frontend or architecture) |
| Build Playwright generator (Claude Code skill or CLI) | ~2-3 days | Developer |
| PO validates end-to-end: record → generate → run test | ~1 day | PO + developer together |
| **Total** | **~5-7 days** | **One developer** |

The "Sprint 2 recorder" assumption was based on imagining a polished tool. The actual minimal recorder is a ~150-line bookmarklet that ships alongside the generator.

---

## Remaining Genuine Unknowns

These are real questions, not inflated assumptions:

1. **Does the CDK drag preview element intercept `pointerup`?** Need to test on the live app. If yes, the recorder needs to look through the preview to find the drop zone underneath. Solvable with `document.elementsFromPoint()`.

2. **Do Material overlay clicks reliably trace back to the trigger?** The `MutationObserver` approach needs validation. Alternative: the `mat-select` change event might be more reliable.

3. **What dialog elements need `data-testid`?** The "create transport order" dialog fields haven't been mapped yet. This is a gap in `ui-angular-template-mapping.md` that needs filling.

4. **Does the snapshot diff produce too many false assertions?** If 50 `data-testid` elements are on screen and 3 appear after an action, the diff produces 3 `expect-visible` assertions — correct. But if a card scrolls in/out of view during the action, it might produce spurious assertions. Needs testing.

These are best resolved by **building the minimal recorder and testing it**, not by further analysis.
