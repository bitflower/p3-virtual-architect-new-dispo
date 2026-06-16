# Selenium vs. Playwright — Selector Strategy Comparison & Framework-Agnostic Flow Recording

**Date:** 2026-06-16
**Input:** `existing-selenium-test-analysis.md`, `ui-angular-template-mapping.md`, codebase analysis of `Disposition-UI-Automation`

---

## Question 1: How Does Selenium Resolve Domain → UI Mapping?

### Selector Strategy Breakdown

| Strategy | Count | % | Example |
|---|---|---|---|
| HTML `id` attribute | 141 | 52% | `[FindsBy(How = How.Id, Using = "lot-drop-zone")]` |
| XPath | 127 | 47% | `//div[@id='lot-drop-zone' and contains(., '6223')]` |
| CSS selector | 9 | 3% | Minimal usage |
| `data-testid` | 4 | 1.5% | Only 2 elements: paginator + filter-close button |

**The Selenium suite has no systematic domain-to-UI abstraction.** Domain values (lot numbers, zip codes, transport order numbers) are embedded directly into XPath expressions via string interpolation:

```csharp
// "Find the lot card that contains text '6223'"
var xPath = $"//div[@id='lot-drop-zone' and contains(., '6223')]";

// "Find the transport order row with this number"
var xPath = $"//td/app-table-cell/span[text()='{cellValue}']";

// "Find lots by temperature icon"
var xPath = $"//mat-icon[@data-mat-icon-name='{iconName}']";
```

### Fragility Assessment

| Fragility Source | Impact | Selenium Examples |
|---|---|---|
| **Text content matching** | Breaks on i18n, wording changes | `contains(text(), 'Kaufungen')` |
| **Aria-label strings** | Breaks on label edits (has typos: `'toggle expnasion button'`) | Button location by aria-label |
| **Material Design internals** | Breaks on Angular/Material upgrades | `mat-select-value-47`, `mat-column-{name}` |
| **Positional XPath** | Breaks on DOM restructuring | `(//button[@aria-label='...'])[1]` — first button only |
| **Generated IDs** | Breaks on component reordering | `mat-tab-label-0-1` |

### What Selenium Gets Right (Page Object Model structure)

The **two-level POM** is well-designed and transferable:

```
Pages/          — one class per route (PlanningPage, TransportPage, LoginPage)
PageComponents/ — one class per UI section (LotsSection, LegSection, TransportOrderCard)
```

This maps cleanly to the PO's element list: each PO element corresponds to either a Page or a PageComponent. The *structure* is reusable across frameworks — only the *selectors inside* need to change.

---

## Question 2: How Can the PO Record Flows Usable by Both Selenium AND Playwright?

### The Core Insight

The PO records a **business flow**, not a test. The flow is framework-agnostic — it describes WHAT happened (domain actions), not HOW to automate it (selectors, waits, assertions). The framework-specific test is *generated* from the flow, not recorded.

```
PO records:                          Generated output:
                                     ┌─────────────────────────┐
"select branch ABN1034"         ──►  │ Playwright .spec.ts     │
"filter legs by HL"             ──►  │ Selenium NUnit .cs      │
"drag shipment 6764480          ──►  │ (or any future framework)│
   to create-transport-order"   ──►  └─────────────────────────┘
```

### Proposed Architecture: Three Layers

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: RECORDING (PO interaction)                    │
│  Browser overlay / bookmarklet / extension              │
│  Watches data-testid elements + pointer events          │
│  Output: Flow JSON (framework-agnostic)                 │
├─────────────────────────────────────────────────────────┤
│  Layer 2: FLOW FORMAT (the contract)                    │
│  JSON array of domain-level actions                     │
│  No selectors, no waits, no assertions                  │
│  Portable between any test framework                    │
├─────────────────────────────────────────────────────────┤
│  Layer 3: GENERATORS (one per target framework)         │
│  Flow JSON → Playwright .spec.ts (page objects)         │
│  Flow JSON → Selenium NUnit .cs (page objects)          │
│  Flow JSON → future framework                           │
└─────────────────────────────────────────────────────────┘
```

### Layer 2: Flow Format (the key design decision)

The flow format must capture domain meaning, not DOM coordinates. Each action references elements by their `data-testid` name, and the recorder enriches drag-drop actions with CDK event context when available.

```json
{
  "name": "Create transport order from HL shipment",
  "recordedAt": "2026-06-16T10:30:00Z",
  "steps": [
    {
      "action": "navigate",
      "url": "/de/planning"
    },
    {
      "action": "select",
      "target": "branch-selector",
      "value": "ABN1034",
      "domain": { "type": "branch", "id": "ABN1034", "label": "10 - 34 - Kaufungen" }
    },
    {
      "action": "click",
      "target": "leg-filter-HL"
    },
    {
      "action": "click",
      "target": "lot-card-6223",
      "domain": { "type": "lot", "id": "6223" }
    },
    {
      "action": "drag",
      "source": "shipment-card-6764480",
      "target": "drop-zone-create-transport-order",
      "domain": {
        "sourceType": "shipment",
        "sourceId": "6764480",
        "targetAction": "createTransportOrder"
      }
    },
    {
      "action": "fill",
      "target": "planning-date-range-picker",
      "value": { "start": "2026-06-28T00:00", "end": "2026-06-30T23:59" }
    }
  ]
}
```

**Key properties of this format:**
- `target` always references a `data-testid` value — never XPath, CSS, or text
- `domain` is optional enrichment — human-readable context extracted from the DOM at record time
- `action` is a small fixed vocabulary: `navigate`, `click`, `select`, `fill`, `drag`, `assert`
- No framework syntax leaks into the format (no `await`, no `FindElement`, no `page.locator`)

### Layer 3: Generators (Playwright vs. Selenium)

Each generator reads the same Flow JSON and emits framework-specific test code using the existing page object patterns:

**Playwright generator output:**
```typescript
test('Create transport order from HL shipment', async ({ page }) => {
  const loginPage = new LoginPage(page);
  const planningPage = new PlanningPage(page);
  
  await loginPage.goto();
  await loginPage.login(TEST_USER, TEST_PASSWORD);
  
  await page.goto('/de/planning');
  await page.getByTestId('branch-selector').click();
  // select ABN1034 from dropdown...
  await page.getByTestId('leg-filter-HL').click();
  await page.getByTestId('lot-card-6223').click();
  await page.getByTestId('shipment-card-6764480')
    .dragTo(page.getByTestId('drop-zone-create-transport-order'));
});
```

**Selenium generator output:**
```csharp
[Test]
public void CreateTransportOrderFromHLShipment()
{
    _planningPage.Navigate();
    _planningPage.SelectBranch("ABN1034");
    _planningPage.LotsSection.FilterByLegType("HL");
    _planningPage.LotsSection.SelectLot("6223");
    _planningPage.LegsSection.DragShipmentToCreateTransportOrder("6764480");
}
```

The Selenium generator maps `data-testid` references to existing PageComponent methods where they exist, or generates `FindElement(By.CssSelector("[data-testid='...']"))` for new elements.

---

## Comparison: What Changes, What Stays

### Selectors — complete overhaul needed for Selenium

| Selenium today | After `data-testid` seeding |
|---|---|
| `By.XPath("//div[@id='lot-drop-zone' and contains(., '6223')]")` | `By.CssSelector("[data-testid='lot-card-6223']")` |
| `By.XPath("(//button[@aria-label='toggle expnasion button'])[1]")` | `By.CssSelector("[data-testid='transport-order-card-{id}']")` |
| `By.XPath("//mat-icon[@data-mat-icon-name='{iconName}']")` | `By.CssSelector("[data-testid='leg-filter-{type}']")` |
| `By.Id("mat-select-value-47")` | `By.CssSelector("[data-testid='branch-selector']")` |

### Page Object structure — transferable as-is

| Selenium POM | Playwright POM | Same concept? |
|---|---|---|
| `PlanningPage.cs` | `planning.page.ts` | Yes — one class per route |
| `LotsSection.cs` | (extend `planning.page.ts` or split) | Yes — one section per UI area |
| `TransportOrderCard.cs` | (component in page object) | Yes |
| `LoginPage.cs` | `login.page.ts` (already exists) | Yes |
| `BasePage.cs` (driver, waits, scroll) | Playwright built-in (`page`, auto-wait) | Playwright doesn't need this |

### Test lifecycle — similar but different mechanics

| Concern | Selenium (NUnit) | Playwright |
|---|---|---|
| Setup | `[SetUp]` → ChromeDriver → login → branch | `test.beforeEach` → `page.goto` → login |
| Waits | Manual `Thread.Sleep` / `WebDriverWait` | Auto-wait built into `getByTestId()` |
| Assertions | NUnit `Assert.That()` | Playwright `expect()` with auto-retry |
| Teardown | `[TearDown]` → screenshot + dispose | Auto-screenshot on failure |
| Parallel | Single-threaded (`workers: 1`) | Single-threaded today, can scale |

---

## What `data-testid` Seeding Enables

Adding `data-testid` to the 11 PO elements (see `ui-angular-template-mapping.md`) creates a **shared contract** between all three layers:

```
Angular templates (source of truth for data-testid)
    │
    ├── Flow Recorder reads data-testid from live DOM
    │
    ├── Playwright page objects use page.getByTestId('...')
    │
    └── Selenium page objects use By.CssSelector("[data-testid='...']")
```

The `data-testid` attribute is the convergence point. It means:
1. **One set of element anchors** maintained in Angular templates
2. **Both test frameworks** can consume the same anchors
3. **The PO's recorded flows** reference the same anchors
4. **Refactoring CSS classes, DOM structure, or i18n** doesn't break tests

### What `data-testid` Does NOT Solve

- **Drag-drop recording** — `data-testid` identifies the source and target, but the recorder still needs to detect drag gestures from pointer events or CDK events
- **Dynamic data** — `data-testid="lot-card-6223"` contains a runtime value. The recorder captures the specific ID; the generator may need to parameterize it
- **Assertions** — the flow format captures actions, not expectations. Assertions must be added manually or inferred ("after drag to create-transport-order, expect a new card")
- **Timing/loading states** — the flow doesn't capture wait conditions. Generators must add framework-appropriate waits

---

## Recommendation: Build Sequence

Given time pressure (PO needs flows ASAP):

### Sprint 1: Foundation (enables manual PO flow description)
1. Add `data-testid` to all 11 PO elements (6 template files, ~20 lines changed)
2. Define the Flow JSON format (the Layer 2 contract)
3. Build a Playwright generator that reads Flow JSON → `.spec.ts` with page objects
4. PO describes flows in JSON manually (or verbally, transcribed by dev)

### Sprint 2: Recorder (enables PO self-service)
5. Build the browser overlay/bookmarklet (Layer 1) — reads `data-testid`, captures clicks + drags
6. PO records flows by clicking through the UI
7. Recorded JSON feeds into the Playwright generator from Sprint 1

### Sprint 3: Selenium bridge (enables dual-framework output)
8. Build a Selenium generator that reads the same Flow JSON → NUnit `.cs`
9. Migrate existing fragile Selenium selectors to `data-testid` where tests still run
10. Both frameworks consume the same recorded flows

This sequence delivers value at each sprint: Sprint 1 unblocks the PO immediately (with dev assistance), Sprint 2 makes it self-service, Sprint 3 bridges the Selenium investment.
