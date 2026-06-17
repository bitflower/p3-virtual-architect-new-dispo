# 007: Intent-Annotated E2E Test Generation

**Date:** 2026-06-17
**Status:** Concept (pre-PRD)
**Depends on:** 006_Custom_Flow_Tracker_E2E_Tests
**Source:** E2E Testing Alignment meeting 2026-06-17 + follow-up discussion

---

## Origin: The Alignment Meeting

On 2026-06-17, Matthias presented the 006 flow recorder POC to the team (Boyan, Vesela, Ivaylo, Valentin, Max Kehder). The discussion surfaced a critical gap that 006 alone does not close.

### Boyan's Challenge

Boyan (backed by Vesela) identified the #1 problem with current E2E automation: **test data idempotency**. The recorder captures clicks on UI elements, but real business tests work with specific entities (lot IDs, shipment IDs, transport order IDs) that change or get consumed between runs.

His concrete example flow:

1. Assign a **Leg** to a transport order
2. Check everything is populated correctly
3. Open the driving instruction
4. Validate the data is correctly filled according to what was assigned

His point: the recorder is fine for capturing button clicks, but "what are those business flows which do not involve entities with IDs?" He called the value-assertion gap "enormous, not little" and stated that fixing generated tests for complex flows would be "more effort than starting from scratch."

### Ivaylo's Counter

Ivaylo disagreed with Boyan and Vesela. He said he explicitly designed the existing Selenium framework to be **data-independent** — tests don't rely on specific entity IDs. The framework can "interact with the data itself" and verify "what happens after the button is clicked." He backed the feasibility of a data-independent approach conceptually.

### Vesela's Concern

Vesela agreed with Boyan: the main issue is test data. "They are not actually automation tests if you have to change something every time before you can start them."

### Outcome

- Valentin and Ivaylo need preparation time before committing an opinion
- Follow-up meeting planned with enough prep time for all
- Boyan flagged zero dev capacity until go-live; Max Kehder will work on it when available

---

## The Idempotency Problem (General)

E2E tests operate on shared, mutable state. Each test run creates/modifies/consumes data, leaving the system in a different state. Three failure patterns:

| Pattern | Example | Why it breaks |
|---|---|---|
| **Hardcoded entity IDs** | `click lot-card-6764480` | That lot was consumed by the previous run |
| **Consumed preconditions** | "Drag unassigned shipment to create TO" | All shipments already assigned from last run |
| **Environment divergence** | Test recorded on ABN, run on UAT | Different branches, different data shapes |

Industry workarounds:

1. **Seed/teardown** — reset DB state before each suite (slow, needs DB access)
2. **Self-provisioning** — each test creates its own data via API (doubles complexity)
3. **Data-independent selection** — tests find "any lot matching criteria" instead of "lot 6764480" (needs smart selectors)
4. **Isolated environments** — fresh DB per run (infrastructure-heavy)

In the New Dispo context, data comes from Oracle CDC through the TMS Bridge, so you cannot just INSERT test data — it must flow through the real pipeline or match its shape.

---

## Why 006 Alone Doesn't Solve This

006 delivers the **capture infrastructure**: `data-testid` seeding, the bookmarklet recorder, the Flow JSON format, and the Playwright generator. It captures actions mechanically and auto-generates visibility/count assertions from snapshot diffs.

What 006 cannot do:

| Gap | Example |
|---|---|
| **Selection strategy** | Did the PO want the *first* lot, a *specific* lot, or *any lot with HL legs*? |
| **Value assertions** | "The driving instruction shows 1300 kg" — the recorder sees the number but doesn't know it's the expected weight |
| **Cross-entity invariants** | "The number of legs on the TO must match the number of legs on the source lot" |
| **Data-independent generation** | The generator defaults to full testid strings (fragile) without knowing which parts are entity-specific |

---

## The Three-Layer Solution

The core concept: three complementary input channels, each capturing what it's best at.

### Layer 1: Mechanical Recording (from 006)

**What it captures:** Actions — clicks, drags, navigations, form fills, page transitions.
**Reliability:** Deterministic. The recorder sees exactly what happened.
**How:** PO uses the app normally with the bookmarklet active. Same recorder from 006.

The recording covers **cross-view flows** naturally. The PO doesn't stop recording when switching pages — they navigate to the driving instructions view, click elements there, and the recorder keeps tracking. Page navigations are captured as `navigate` actions in the Flow JSON.

### Layer 2: Inline Assertion UI (new in 007)

**What it captures:** Value expectations on specific `data-testid` elements.
**Reliability:** Deterministic. The PO clicks an element and enters/confirms the expected value.
**How:** The bookmarklet adds a minimal click UI on all `data-testid` domain nodes.

When recording, the PO can switch to "Assert" mode. Clicking a `data-testid` element opens a tiny popover showing the current value with:
- A **confirm** button — "yes, this value (e.g. '3 legs', '1300 kg', '42%') is what I expect"
- An **input field** — to override or specify the expected value explicitly

This produces structured, unambiguous assertion entries in the Flow JSON:

```json
{
  "type": "assert-value",
  "target": "transport-order-leg-count-TO-2847",
  "observed": "3",
  "expected": "3",
  "mode": "confirmed"
}
```

This eliminates the need for the intent narrative to carry individual value expectations. The PO captures "I expect 1300 kg here" by clicking the weight element and confirming — no prose required.

### Layer 3: Intent Narrative (new in 007)

**What it captures:** Selection strategy and cross-entity relationships.
**Reliability:** AI-interpreted — but with a small, focused interpretation surface.
**How:** PO writes a short paragraph describing the flow intent.

Example:
> "I pick the FIRST lot available and drag it onto the transport order creation area. After that I expect a new transport order to be present in the drive instructions slider with THE NUMBER OF LEGS ASSIGNED THAT MATCH THE NUMBER OF LEGS OF THE LOT."

The intent narrative only needs to express what neither mechanical layer can:
- **Selection strategy** — "FIRST available", "any lot with unassigned legs", "the third shipment"
- **Cross-entity invariants** — "leg count must match the source lot"
- **Correlation direction** — "the TO I just created" (linking actions across steps)

### How the Layers Complement Each Other

| Concern | Which layer resolves it | Why |
|---|---|---|
| What actions were performed | Mechanical recording | Deterministic, precise |
| What values are expected | Inline assertion UI | PO clicks + confirms, no ambiguity |
| Which element to select | Intent narrative | "FIRST", "any with HL legs", "nth" |
| Cross-entity relationships | Intent narrative | "legs must match source lot" |
| Timing / wait behavior | Mechanical recording (timestamps) | Generator derives waits from observed timing |
| Cross-view assertions | Mechanical recording + inline assertions | PO navigates to new page and asserts there |

### Generator Input

The AI-powered generator skill receives all three inputs:

```
Mechanical Flow JSON ────────┐
                             │
Inline Assertion Entries ────┤→ AI Generator Skill → Playwright .spec.ts
                             │
Intent Narrative ────────────┘
```

The AI interpretation surface is small and focused:
- Parse selection strategy hints ("FIRST", "any", "nth") → emit `.first()`, `.nth(n)`, or filter patterns
- Parse cross-entity invariants → emit variable capture + comparison assertions
- Everything else (actions, values, timing) comes from the deterministic layers

---

## Proof Target: Boyan's Flow

The acceptance proof for 007 is Boyan's exact flow from the meeting:

1. Select a branch
2. Filter for HL legs
3. Pick the **first available lot** (intent: selection strategy)
4. Drag a leg onto the create-transport-order drop zone
5. Fill the dialog (date, confirm)
6. Navigate to the driving instructions view
7. Find the newly created transport order
8. Assert: the TO has **the same number of legs as the source lot** (intent: cross-entity invariant)
9. Assert: specific values are correctly populated (inline assertions: weight, addresses, etc.)

If 007 can generate a test for this flow that:
- Runs successfully on test environment
- Works with different data (not hardcoded to the recorded lot/leg IDs)
- Fails when a business expectation is violated

...then the approach is proven for complex business flows.

---

## Relationship to 006

| | 006 | 007 |
|---|---|---|
| **Scope** | Recording infrastructure | Intelligence layer |
| **Generator input** | Flow JSON only | Flow JSON + Inline Assertions + Intent Narrative |
| **Generator type** | Template-based (mechanical mapping) | AI-powered (resolves strategy + invariants) |
| **Selection approach** | Full testid strings | Pattern-based, strategy-driven |
| **Assertions** | Auto-generated visibility/count | Confirmed values + cross-entity invariants |
| **Proof target** | Core planning flow (button clicks, drag, dialog) | Boyan's complex flow (assign leg → verify driving instruction data) |
| **Depends on** | `data-testid` seeding | 006 infrastructure (recorder, format, testids) |

007 extends the 006 bookmarklet (adds assert mode + inline UI) and replaces the 006 template-based generator with an AI-powered generator skill. The `data-testid` contract and Flow JSON format from 006 remain the foundation.

---

## Open Questions for PRD Phase

1. **Inline assertion UI scope** — Should the assert-mode overlay appear on ALL `data-testid` elements or only on a curated "assertable" subset?
2. **Intent narrative format** — Free-form paragraph? Structured template with prompts? Voice input option?
3. **Generator skill architecture** — Claude Code skill (like `/e2e-record`) or standalone CLI? How much context does it need (page objects, component structure)?
4. **Cross-entity invariant complexity** — How far do we go? Simple "count matches" is tractable. "Weight of TO equals sum of leg weights minus deductions" may be too complex for V1.
5. **Recorder extension vs. new bookmarklet** — Extend 006's bookmarklet with assert mode, or keep them separate?
6. **Proof environment** — Which environment and dataset for the Boyan flow proof? Test environment with stable-enough data?

---

*This document captures the concept discussion from 2026-06-17. It serves as input for PRD validation.*
