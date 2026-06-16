---
name: e2e-record
description: Launch Playwright codegen to record a UI flow, then transform the recording into a clean e2e test with page objects and data-testid attributes. Use when the user wants to record a new e2e test flow or has a raw codegen script to refine.
allowed-tools: Bash,Read,Write,Edit,Glob,Grep
---

# E2E Record Skill

**IMPORTANT: Read `Code/Disposition-Frontend/e2e/DOM-TESTING-GUIDE.md` before writing any test code.** It contains critical knowledge about Angular CDK drag-and-drop, Material datepicker overlays, multiple spinners, locale-prefixed routes, and other DOM quirks that cause test failures.

Launches Playwright codegen for the user to record a flow by clicking through the UI, then transforms the raw recording into a production-quality e2e test following the project's conventions.

## When to Use

- User wants to record a new e2e test flow
- User ran `npx playwright codegen` and has a recorded script to refine
- User pastes raw Playwright test code that needs to be structured into page objects

## Workflow

### Phase 1: Launch Codegen & Obtain the Recording

**Parse arguments**: The user's input after `/e2e-record` is the test case title. Examples:
- `/e2e-record Filter transport orders by status` → title: "Filter transport orders by status"
- `/e2e-record Change branch selection` → title: "Change branch selection"

Store the title — it will be used in Phase 5 for:
- `test.describe()` group name (derive a feature name from the title)
- `test()` name (the title itself)
- File name (kebab-case of the title, e.g. `filter-transport-orders-by-status.spec.ts`)

If no title is provided, ask the user for one before proceeding.

**Step 1a**: If the user provided a raw codegen script already (pasted code), skip to Phase 2.

**Step 1b**: Otherwise, launch the browser for them. Determine the start URL:
- Default: `https://test.dispo.gcp.nagel-group.com/de/transport`
- If user explicitly provided a different URL, use that instead

Launch with `playwright codegen` so the browser opens **with the Inspector**:

```bash
cd "Code/Disposition-Frontend" && npx playwright codegen --target playwright-test --test-id-attribute data-testid "START_URL" &
```

Then tell the user:

```
Browser and Inspector are open (recording is active by default).

1. PAUSE recording — click the Record button (red circle) in the Inspector
2. Navigate to the starting point of your flow (e.g. log in, pick a branch)
3. RESUME recording — click the Record button again
4. Click through the flow you want to test
5. STOP recording — click Record once more
6. Copy ALL the code from the Inspector window
7. Paste it here
```

Wait for the user to paste the recorded script before proceeding.

### Phase 2: Analyze the Recording

Once you have the raw codegen script:

1. **Parse the actions**: Extract every `page.goto()`, `page.click()`, `page.fill()`, `page.locator()`, `expect()` call
2. **Identify pages/screens**: Group actions by the page/view they occur on (login, transport, planning, etc.)
3. **Read existing page objects** to check what's already covered:

```bash
cat Code/Disposition-Frontend/e2e/page-objects/*.ts
cat Code/Disposition-Frontend/e2e/page-objects/index.ts
```

4. **Catalog the selectors**: List every selector from the recording and classify:
   - Already covered by existing page object → reuse
   - New selector on existing page → extend the page object
   - New page entirely → create new page object

### Phase 3: Find Angular Templates

For each NEW selector that isn't already in a page object:

1. **Find the source template**: Search for the element in Angular component templates:

```bash
# Search by text content, CSS class, or element structure
grep -rn "SELECTOR_TEXT_OR_CLASS" "Code/Disposition-Frontend/apps" "Code/Disposition-Frontend/libs" --include="*.html" | grep -v node_modules
```

2. **Determine the best data-testid name** using the convention: `[feature]-[element]-[qualifier]` in kebab-case. Examples:
   - `transport-filter-button`
   - `planning-tour-card`
   - `header-branch-selector`
   - `order-details-save-button`

3. **Add data-testid to the template**: Edit the Angular HTML to add `data-testid="..."` to the element.

### Phase 4: Build Page Objects

For each page/screen identified:

1. **If page object exists**: Add new locators and methods to the existing file
2. **If page object is new**: Create it following this pattern:

```typescript
import { type Page, type Locator, expect } from '@playwright/test';

export class ExamplePage {
  readonly page: Page;
  readonly someElement: Locator;

  constructor(page: Page) {
    this.page = page;
    // CSS fallback until data-testid is deployed
    // Target: page.getByTestId('feature-element-name')
    this.someElement = page.locator('css-fallback-selector');
  }

  async someAction() {
    await this.someElement.click();
  }

  async expectSomeState() {
    await expect(this.someElement).toBeVisible();
  }
}
```

**Locator rules:**
- Primary: `page.getByTestId('...')` — but only after template changes are deployed
- Interim: CSS class or structural selector with a `// Target: page.getByTestId('...')` comment
- For Keycloak / 3rd-party pages: use `#id` or stable attribute selectors (we don't control those templates)
- NEVER use translated text in selectors (the app uses Angular i18n — text changes with locale)
- NEVER use `getByRole({ name: '...' })` with translated names
- Scope locators to parent containers to avoid ambiguity (e.g. `this.settingsDrawer.locator(...)`)

3. **Update the barrel export** in `e2e/page-objects/index.ts`

### Phase 5: Write the Test

Create the test file in `e2e/tests/` following this pattern:

```typescript
import { test, expect } from '@playwright/test';
import { LoginPage, AppPage, NewPage } from '../page-objects';

const TEST_USER = process.env['TEST_USER'] ?? 'basicuser';
const TEST_PASSWORD = process.env['TEST_PASSWORD'] ?? 'bUsr2025!Test';

test.describe('Feature Name', () => {
  test('descriptive test name', async ({ page }) => {
    const loginPage = new LoginPage(page);
    const appPage = new AppPage(page);

    // Login (most tests need this)
    await loginPage.goto();
    await loginPage.login(TEST_USER, TEST_PASSWORD);
    await appPage.expectLoggedIn();

    // ... test-specific actions
  });
});
```

**Test conventions:**
- File name: `[feature].spec.ts` (e.g. `transport-filter.spec.ts`)
- Every test that needs auth should use LoginPage + AppPage for login
- Use `test.describe` to group related tests
- Comments only for non-obvious flow steps
- No hardcoded waits — use `expect(...).toBeVisible()` or `waitFor()`

### Phase 6: Validate

1. **Run the test headless** to verify it passes:

```bash
cd "Code/Disposition-Frontend" && npx playwright test e2e/tests/NEW_TEST.spec.ts --reporter=list
```

2. If it fails, diagnose using the screenshot in `test-results/` and fix selectors
3. **Run headed** for the user to see:

```bash
cd "Code/Disposition-Frontend" && npx playwright test e2e/tests/NEW_TEST.spec.ts --headed --reporter=list
```

### Phase 7: Summary

Present to the user:
- **Test file**: path and what it covers
- **Page objects**: which were created/modified
- **Template changes**: which Angular templates got `data-testid` additions (list the attribute names)
- **Migration note**: remind that after deployment, CSS fallback selectors should be swapped to `getByTestId()`

## File Locations

| What | Where |
|------|-------|
| Playwright config | `Code/Disposition-Frontend/playwright.config.ts` |
| Tests | `Code/Disposition-Frontend/e2e/tests/*.spec.ts` |
| Page objects | `Code/Disposition-Frontend/e2e/page-objects/*.page.ts` |
| Barrel export | `Code/Disposition-Frontend/e2e/page-objects/index.ts` |
| Angular app templates | `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/` |
| Angular lib templates | `Code/Disposition-Frontend/libs/*/src/` |

## Common Pitfalls

1. **i18n**: All visible text is translated. Never match on German text like "Fahraufträge", "Einstellungen", "Abmelden". Use CSS classes or `data-testid`.
2. **Multiple drawers**: The app has several drawers (settings, filter, view-customize, drive-instructions) — all share `.drawer-title`. Always scope to the parent container.
3. **Angular Material selectors**: `mat-drawer`, `mat-toolbar`, `mat-select` are custom elements — they work as CSS selectors.
4. **Keycloak is external**: The login page is served by Keycloak at `/keycloak/realms/master/...`. We cannot add `data-testid` there. Use `#username`, `#password`, `#kc-login`.
5. **Branch selector**: The app requires a branch selection. Most tests should verify `appPage.expectLoggedIn()` which confirms the transport page loaded (meaning branch is set).
