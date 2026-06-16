# Flow Format Deep Dive — Can a JSON Flow Replace a Test?

**Date:** 2026-06-16
**Trigger:** PRD Phase 2 blocker — can't scope MVP without understanding whether actions-only is enough or assertions are required for the concept to be validatable end-to-end.

---

## The Core Question

The PO records a business flow by clicking through the UI. The recording becomes a JSON file. A generator turns that JSON into a Playwright/Selenium test.

**For this to be a test (not a demo replay), the flow must capture three things:**
1. **Actions** — what the PO did (click, drag, fill, select, navigate)
2. **Expectations** — what the PO saw after each action (a card appeared, a count changed, a value matched)
3. **Data flow** — how values from one step feed into the next (selected lot → its shipments appear)

Actions alone produce a script that runs the same clicks. It will catch crashes and navigation errors. It will NOT catch: wrong data displayed, missing cards, incorrect counts, broken filters, regression in business logic.

---

## Scenario: "Create a Transport Order from an HL Shipment"

This is the PO's core planning flow. Let's walk it step by step and identify what each step needs in the flow format.

### Step 1: Navigate to Planning

```json
{
  "action": "navigate",
  "url": "/de/planning"
}
```

**Expectation needed?** Yes — the page must load. But Playwright/Selenium handle this implicitly (navigation waits for load). No explicit assertion required in the flow.

**Value passing?** None.

**Verdict:** Action-only is sufficient.

---

### Step 2: Select Branch

```json
{
  "action": "select",
  "target": "branch-selector",
  "value": "ABN1034"
}
```

**Expectation needed?** Yes — after selecting the branch, lot cards should appear in the lots column. The PO expects to see lots for this branch. Without an assertion, the test passes even if the lots column stays empty (e.g. API returns no data for this branch).

**What the PO would say:** "After I select Kaufungen, I see lots appearing on the left."

**Minimal assertion:**
```json
{
  "action": "expect",
  "target": "lot-card",
  "condition": "count",
  "operator": "greaterThan",
  "value": 0
}
```

**Value passing?** The selected branch determines which lots appear. This is implicit (the app handles it), but the test should verify the consequence.

**Verdict:** Assertion required — otherwise branch selection bugs go undetected.

---

### Step 3: Filter by Leg Type HL

```json
{
  "action": "click",
  "target": "leg-filter-HL"
}
```

**Expectation needed?** Yes — lots should now be filtered. Some lot cards should disappear (those without HL legs). The PO expects a reduced set.

**What the PO would say:** "After I click HL, the lots with only VL legs disappear."

**Minimal assertion:**
```json
{
  "action": "expect",
  "target": "lot-card",
  "condition": "count",
  "operator": "lessThan",
  "referenceStep": 2,
  "referenceField": "lot-card.count"
}
```

This introduces **cross-step references** — "the count should be less than what it was after step 2." This is significantly more complex than a simple assertion.

**Alternative (simpler):** Just assert the filter button shows as active:
```json
{
  "action": "expect",
  "target": "leg-filter-HL",
  "condition": "hasClass",
  "value": "selected-type-lot-filters-button"
}
```

But this only verifies the button state, not the filtering effect.

**Verdict:** The PO's mental model is "I clicked HL and the list changed." The assertion format needs to express data-level expectations, not just UI state.

---

### Step 4: Select a Lot Card

```json
{
  "action": "click",
  "target": "lot-card-6223"
}
```

**Expectation needed?** Yes — selecting a lot card causes its shipments to appear in the shipments column (column 2). This is the most important data-flow moment in the planning flow.

**What the PO would say:** "After I click lot 6223, I see its shipments on the right — shipment 6764480, 6764481, 6764478."

**Assertion needed:**
```json
{
  "action": "expect",
  "target": "shipment-card",
  "condition": "count",
  "operator": "greaterThan",
  "value": 0
},
{
  "action": "expect",
  "target": "shipment-card-6764480",
  "condition": "visible"
}
```

**Value passing?** The lot's `identificationNumber` is the key. The shipments that appear are the lot's children. The flow needs to know that clicking `lot-card-6223` should cause `shipment-card-6764480` to become visible. This is domain knowledge that the recorder can capture at record time (the PO clicked the lot, then saw specific shipments appear).

**Verdict:** Assertion required — this is the critical data-flow step. Without it, the test doesn't verify that lot selection works.

---

### Step 5: Drag Shipment to Create Transport Order

```json
{
  "action": "drag",
  "source": "shipment-card-6764480",
  "target": "drop-zone-create-transport-order"
}
```

**Expectation needed?** This is the most complex step. After the drag:
1. A dialog opens (date/time picker for departure)
2. The PO fills in the date
3. The PO confirms
4. A new transport order card appears in the transport orders column (column 3)
5. The shipment card may change state (assigned indicator)

**What the PO would say:** "I drag the shipment to the transport order area. A dialog opens. I pick a date. I confirm. A new transport order appears."

This is actually **multiple sub-steps**, not one action:

```json
{
  "action": "drag",
  "source": "shipment-card-6764480",
  "target": "drop-zone-create-transport-order"
},
{
  "action": "expect",
  "target": "create-transport-order-dialog",
  "condition": "visible"
},
{
  "action": "fill",
  "target": "departure-date-picker",
  "value": { "date": "2026-06-28", "time": "06:00" }
},
{
  "action": "click",
  "target": "confirm-create-transport-order"
},
{
  "action": "expect",
  "target": "transport-order-card",
  "condition": "count",
  "operator": "greaterThan",
  "referenceStep": "before-drag",
  "referenceField": "transport-order-card.count"
}
```

**Verdict:** The drag action triggers a multi-step sub-flow. The format needs to handle dialogs, fills within dialogs, and assertions on the outcome. Actions-only completely fails here — the test would drag, but never fill the dialog or verify the result.

---

### Step 6: Verify Date Range

```json
{
  "action": "expect",
  "target": "planning-date-range-picker",
  "condition": "value",
  "value": { "start": "2026-06-28T00:00", "end": "2026-06-30T23:59" }
}
```

**Verdict:** Pure assertion, no action. The PO checks that the date range shows correct values.

---

## What the Scenario Reveals

### Finding 1: Actions-only is NOT viable for end-to-end validation

Every meaningful step requires an assertion to verify the business outcome. Without assertions, the flow is a clickthrough script that catches crashes but misses every data/logic bug.

| Step | Action-only catches | Assertion catches additionally |
|---|---|---|
| Select branch | Page doesn't crash | Lots actually appear for this branch |
| Filter by HL | Button is clickable | Lot list actually filters |
| Select lot | Card is clickable | Shipments appear for this lot |
| Drag to create TO | Drag doesn't crash | Dialog opens, TO is created, card appears |
| Date range | Picker is present | Correct values displayed |

### Finding 2: Cross-step data flow is unavoidable

The flow isn't a flat list of independent actions. It's a chain:
- Branch → determines lots
- Lot selection → determines shipments
- Shipment drag → triggers dialog → dialog values → determines transport order

The format must express "after step 4, I expect to see X" where X depends on what happened in step 4.

### Finding 3: Dialogs and sub-flows need handling

The drag-to-create flow opens a dialog that requires its own actions (fill date, click confirm). This is a nested sub-flow within the main flow. The format needs to handle modal/dialog context.

### Finding 4: Two types of assertions needed

1. **State assertions** — "this element is visible / has value X / has count > N"
2. **Relative assertions** — "the count is different from what it was at step N"

Relative assertions are powerful but complex. They require the recorder to snapshot state at key moments.

---

## Revised Flow Format Proposal

Based on the scenario walkthrough, the flow format needs four action categories:

### 1. Navigation actions
```json
{ "action": "navigate", "url": "/de/planning" }
```

### 2. Interaction actions (what the PO does)
```json
{ "action": "click", "target": "lot-card-6223" }
{ "action": "select", "target": "branch-selector", "value": "ABN1034" }
{ "action": "fill", "target": "departure-date-picker", "value": "2026-06-28T06:00" }
{ "action": "drag", "source": "shipment-card-6764480", "target": "drop-zone-create-transport-order" }
```

### 3. Expectation actions (what the PO sees)
```json
{ "action": "expect-visible", "target": "shipment-card-6764480" }
{ "action": "expect-count", "target": "lot-card", "operator": "gt", "value": 0 }
{ "action": "expect-value", "target": "planning-date-range-picker", "contains": "28/06/2026" }
{ "action": "expect-text", "target": "lot-card-6223", "contains": "RANA PASTIFICIO" }
```

### 4. Context markers (for generators)
```json
{ "action": "snapshot", "label": "before-filter", "capture": ["lot-card.count"] }
{ "action": "dialog-opened", "target": "create-transport-order-dialog" }
{ "action": "dialog-closed", "target": "create-transport-order-dialog" }
```

### Complete scenario in revised format

```json
{
  "name": "Create transport order from HL shipment",
  "recordedBy": "PO",
  "recordedAt": "2026-06-16T10:30:00Z",
  "steps": [
    { "action": "navigate", "url": "/de/planning" },
    
    { "action": "select", "target": "branch-selector", "value": "ABN1034" },
    { "action": "expect-count", "target": "lot-card", "operator": "gt", "value": 0 },
    
    { "action": "snapshot", "label": "before-filter", "capture": ["lot-card.count"] },
    { "action": "click", "target": "leg-filter-HL" },
    { "action": "expect-count", "target": "lot-card", "operator": "lt", "referenceSnapshot": "before-filter", "referenceField": "lot-card.count" },
    
    { "action": "click", "target": "lot-card-6223" },
    { "action": "expect-visible", "target": "shipment-card-6764480" },
    
    { "action": "snapshot", "label": "before-drag", "capture": ["transport-order-card.count"] },
    { "action": "drag", "source": "shipment-card-6764480", "target": "drop-zone-create-transport-order" },
    { "action": "dialog-opened", "target": "create-transport-order-dialog" },
    { "action": "fill", "target": "departure-date-input", "value": "2026-06-28T06:00" },
    { "action": "click", "target": "confirm-create-transport-order" },
    { "action": "dialog-closed", "target": "create-transport-order-dialog" },
    { "action": "expect-count", "target": "transport-order-card", "operator": "gt", "referenceSnapshot": "before-drag", "referenceField": "transport-order-card.count" }
  ]
}
```

---

## Impact on MVP Scoping

### If assertions are in MVP:
- The Flow JSON format is richer — needs `expect-*`, `snapshot`, `dialog-*` actions
- The recorder needs to capture not just what the PO clicked, but what appeared/changed after
- The generator needs to emit `expect()` / `Assert.That()` statements, not just action calls
- **But:** the concept is end-to-end validatable. A PO can record a flow, a test is generated, the test actually verifies business behavior.

### If assertions are deferred to V2:
- The Flow JSON is simpler — actions only
- The recorder is simpler — just capture clicks and drags
- **But:** generated tests are clickthrough scripts. They catch crashes, not bugs. The PO can't validate that the concept works for their use case. And the V2 assertion retrofit requires revisiting every recorded flow.

### Recommendation

**Assertions must be in MVP** — at minimum the simple forms:
- `expect-visible` (element appeared)
- `expect-count` with absolute values (more than 0 items)
- `expect-text` with `contains` (card shows expected text)

Defer to V2:
- `snapshot` + relative assertions (count changed compared to earlier)
- `dialog-opened` / `dialog-closed` markers (can be inferred from the action sequence)
- Cross-step references

This gives the PO enough to express "I did X and saw Y" without the complexity of state tracking across steps.

---

## Open Question for PRD

With simple assertions in MVP, does the PO still need a recorder (Sprint 2), or can they describe flows with expectations using a structured form/template?

A form like:

| Step | I do... | I expect to see... |
|---|---|---|
| 1 | Navigate to Planning | Planning page loads |
| 2 | Select branch Kaufungen | Lots appear |
| 3 | Click HL filter | Fewer lots shown |
| 4 | Click lot 6223 | Shipments appear, including 6764480 |
| 5 | Drag 6764480 to create-transport-order | Dialog opens |
| 6 | Fill date 2026-06-28 06:00 | — |
| 7 | Click confirm | New transport order card appears |

A dev or Claude Code skill then translates this table into Flow JSON. No recorder needed for Sprint 1. The recorder (Sprint 2) auto-generates this table by observing the PO's interactions.
