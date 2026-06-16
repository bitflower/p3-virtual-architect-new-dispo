# Timing & Async Flows — Who Owns the Wait?

**Date:** 2026-06-16
**Trigger:** PRD scoping question — in a distributed system, many actions have multi-second runtime. Who handles this: the PO, the recorder, the generator, the framework, or the developer?

---

## The Problem

The New Dispo is a distributed system:

```
Angular Frontend → .NET Backend → TMS Bridge → AlloyDB/Oracle
                                      ↑
                        CDC Pipeline, Cloud Functions, TOP Service
```

When the PO drags a shipment to create a transport order, this happens:

1. Frontend sends HTTP request to Backend (~instant)
2. Backend calls TMS Bridge via GraphQL (~200ms)
3. TMS Bridge writes to TMS Database (~100-500ms)
4. Response propagates back (~200ms)
5. Frontend receives response and updates UI (~100ms)
6. **Total: 500ms–2s typical, 5s+ under load**

Other flows are slower:
- Tour calculation via TOP Service: **5–30 seconds** (TOP is ~80% of tour calc time per frontend tracing analysis)
- CDC synchronization pipelines: **seconds to minutes**
- Data refresh after branch switch: **1–3 seconds** (API call to load lots + shipments)

The PO clicks, waits, sees the result, clicks again. Their mental model is sequential: "I did X, then Y appeared, then I did Z." The distributed system's latency is invisible to them — they just wait until the screen updates.

**The question: where in the three-layer architecture does timing get handled?**

---

## Analysis by Layer

### Layer 1: Recording (PO interaction)

**The PO should NOT think about timing.** They interact naturally — click, wait for result, click again. The recorder observes the time gaps.

What the recorder CAN capture:
- Timestamps on each action (the PO clicked at T1, the next action was at T1+3s)
- Loading indicators appearing/disappearing (`mat-spinner` in the DOM)
- Element visibility transitions (shipment cards weren't there, then they appeared)

What the recorder CANNOT know:
- Why the wait happened (network? backend processing? CDC?)
- Whether the wait was the PO thinking vs. the system loading
- What the appropriate timeout should be in CI vs. production

**Recorder's responsibility:** Capture the raw timing. Don't interpret it.

```json
{
  "action": "click", "target": "lot-card-6223", "timestamp": "2026-06-16T10:30:05.200Z"
},
{
  "action": "expect-visible", "target": "shipment-card-6764480", "timestamp": "2026-06-16T10:30:07.800Z",
  "meta": { "waitedMs": 2600, "loadingIndicatorSeen": true }
}
```

The `meta.waitedMs` and `meta.loadingIndicatorSeen` are hints for the generator, not instructions for the PO.

### Layer 2: Flow Format (the contract)

The flow format is timing-**aware** but timing-**agnostic**. It records what happened and how long it took, but doesn't prescribe wait strategies.

**Key design rule:** Expectations are *eventually-true* statements, not *immediately-true* ones.

```json
{ "action": "expect-visible", "target": "shipment-card-6764480" }
```

This means: "at some point after the previous action, this element should become visible." It does NOT mean: "this element is visible right now" or "wait exactly 2.6 seconds."

The flow format MAY include timing hints for the generator:

```json
{ 
  "action": "expect-visible", 
  "target": "shipment-card-6764480",
  "hint": { "observedWaitMs": 2600, "category": "api-response" }
}
```

But these are advisory, not prescriptive.

### Layer 3: Generators (framework-specific)

**This is where timing gets resolved.** Each generator translates "eventually-true" expectations into framework-appropriate waiting.

#### Playwright Generator

Playwright has **built-in auto-waiting**. Most timing is handled for free:

```typescript
// "expect-visible" → auto-retries until timeout (default 5s, configurable)
await expect(page.getByTestId('shipment-card-6764480')).toBeVisible();

// "expect-count gt 0" → auto-retries
await expect(page.getByTestId('lot-card').first()).toBeVisible();

// "click" → auto-waits for element to be actionable
await page.getByTestId('lot-card-6223').click();

// "drag" → waits for both source and target
await page.getByTestId('shipment-card-6764480')
  .dragTo(page.getByTestId('drop-zone-create-transport-order'));
```

For slow operations (tour calculation, CDC), the generator increases the timeout:

```typescript
// hint.observedWaitMs > 5000 → generator bumps timeout
await expect(page.getByTestId('tour-result-card')).toBeVisible({ timeout: 30_000 });
```

**Playwright's auto-wait means:** the PO's timing is almost entirely handled by the framework. The generator's job is mainly to set appropriate timeouts for slow operations.

#### Selenium Generator

Selenium has **no auto-waiting**. The generator must emit explicit waits:

```csharp
// "expect-visible" → WebDriverWait
var wait = new WebDriverWait(_driver, TimeSpan.FromSeconds(10));
wait.Until(d => d.FindElement(By.CssSelector("[data-testid='shipment-card-6764480']")).Displayed);

// "click" → wait for clickable first
wait.Until(ExpectedConditions.ElementToBeClickable(
    By.CssSelector("[data-testid='lot-card-6223']")
)).Click();
```

The existing Selenium suite uses `Thread.Sleep()` (fragile). The generator should emit proper `WebDriverWait` + `ExpectedConditions` instead.

For slow operations:
```csharp
// hint.observedWaitMs > 5000 → generator uses longer timeout
var longWait = new WebDriverWait(_driver, TimeSpan.FromSeconds(30));
longWait.Until(d => d.FindElement(By.CssSelector("[data-testid='tour-result-card']")).Displayed);
```

---

## Timing Categories

Not all waits are equal. The generator benefits from knowing WHAT caused the wait:

| Category | Typical Duration | Example | Generator Strategy |
|---|---|---|---|
| **Instant** | <100ms | Click a toggle, open a dropdown | No explicit wait needed |
| **UI transition** | 100–500ms | Animation, drawer opening, accordion expanding | Playwright: auto-wait. Selenium: short implicit wait |
| **API response** | 500ms–3s | Branch switch loads lots, lot selection loads shipments | Playwright: default timeout. Selenium: `WebDriverWait(5s)` |
| **Backend processing** | 2–10s | Create transport order, save drive instructions | Playwright: `timeout: 10_000`. Selenium: `WebDriverWait(10s)` |
| **Distributed operation** | 5–60s | Tour calculation (TOP), CDC sync, batch operations | Playwright: `timeout: 60_000`. Selenium: `WebDriverWait(60s)` |

### Who classifies the category?

| Actor | When | How |
|---|---|---|
| **Recorder** (automated) | At record time | Measures `waitedMs` between action and next interaction. Detects `mat-spinner` presence. Flags waits > 3s as "slow." |
| **Generator** (automated) | At generation time | Uses `waitedMs` hint to pick timeout tier. Default: 5s. If hint > 5s: use 2× the hint. If hint > 15s: flag for review. |
| **Developer / Test engineer** (human) | At review time | Reviews generated tests. Adjusts timeouts for environment differences (CI is slower than local). Adds environment-specific config. |
| **Claude Code skill** (automated) | At generation time | Could apply known patterns: "drag to create-transport-order always needs 10s timeout" based on learned project knowledge. |

### The PO never sees timing

The PO's experience:
1. Click through the flow naturally
2. The recorder captures everything including timing
3. The generated test handles waiting automatically
4. IF a test fails due to timeout in CI → a developer adjusts the timeout

The PO doesn't know or care that "select branch" triggers an API call that takes 2 seconds.

---

## Edge Cases

### 1. Loading Spinners

The app shows `mat-spinner` during async operations. The recorder can detect this:

```json
{
  "action": "click", "target": "lot-card-6223",
  "meta": { "triggeredLoading": true, "loadingSelector": "mat-spinner", "loadingDurationMs": 1800 }
}
```

The generator can use this to emit "wait for spinner to disappear" before asserting:

```typescript
// Playwright
await expect(page.locator('mat-spinner')).toBeHidden({ timeout: 10_000 });
await expect(page.getByTestId('shipment-card-6764480')).toBeVisible();
```

```csharp
// Selenium
wait.Until(ExpectedConditions.InvisibilityOfElementLocated(By.CssSelector("mat-spinner")));
var shipment = wait.Until(ExpectedConditions.ElementIsVisible(
    By.CssSelector("[data-testid='shipment-card-6764480']")));
```

### 2. Polling / Eventually Consistent Data

Some operations don't have a loading spinner. The frontend might poll an API or receive a push notification. The PO just sees the data appear after a delay.

The recorder captures: "PO waited 8 seconds before the next action." The generator flags this for developer review:

```json
{
  "action": "expect-visible", "target": "cdc-synced-record-123",
  "hint": { "observedWaitMs": 8000, "category": "unknown", "reviewFlag": "Long wait without loading indicator — may need polling or retry logic in the test" }
}
```

### 3. Flaky Timing (passes locally, fails in CI)

The most common real-world problem. Local dev: 500ms response. CI environment: 3s response. UAT: 5s response.

**Solution:** The generator uses the recorded timing as a FLOOR, not a ceiling, and applies a multiplier:

```
Generated timeout = max(defaultTimeout, observedWaitMs × 2)
```

Plus a project-level config:

```json
{
  "timeoutMultiplier": {
    "local": 1,
    "ci": 3,
    "uat": 5
  }
}
```

This is the **developer/test engineer's** responsibility — not the PO's.

---

## Summary: Ownership Matrix

| Concern | PO | Recorder | Generator | Dev/Test Engineer |
|---|---|---|---|---|
| **Interacts naturally, doesn't think about timing** | ✅ owns | — | — | — |
| **Captures raw timestamps + loading indicators** | — | ✅ owns | — | — |
| **Classifies wait category from hints** | — | — | ✅ owns | — |
| **Emits framework-appropriate wait code** | — | — | ✅ owns | — |
| **Tunes timeouts for environment differences** | — | — | — | ✅ owns |
| **Reviews tests flagged with "long wait" warnings** | — | — | — | ✅ owns |
| **Adds polling/retry for eventually-consistent flows** | — | — | — | ✅ owns |
| **Maintains timeout config per environment** | — | — | — | ✅ owns |

**The PO's experience is timing-free.** They click, they see, they click again. Everyone else in the chain handles the distributed system's latency.

---

## Impact on PRD Scoping

Timing handling is **not a separate feature** — it's baked into the generator layer:

- **Sprint 1 (manual flows):** Developer writes the test, handles timing manually. No change.
- **Sprint 2 (recorder):** Recorder captures `waitedMs` hints. Generator uses them for timeout tiers. Works out of the box for 90% of flows.
- **Environment tuning:** Developer adds timeout config file. One-time setup.

The only PRD requirement is: **"The flow format MUST include optional timing metadata. The generator MUST use this metadata to select appropriate wait strategies per framework."**

This is a "Should Have" for the recorder (Sprint 2), not a "Must Have" for Sprint 1 where flows are written manually.
