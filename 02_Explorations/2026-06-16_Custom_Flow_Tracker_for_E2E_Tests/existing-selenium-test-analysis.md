# Existing Selenium UI Test Suite — Analysis

**Repo:** [Disposition-UI-Automation](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-UI-Automation)
**Date:** 2026-06-16

---

## Repo Status

| Metric | Value |
|--------|-------|
| First commit | 2024-06-13 |
| Last commit | 2025-12-17 (6 months ago) |
| Activity in 2026 | None |
| Total commits | ~145 |
| Top contributors | Ivaylo Petrov (49), Iliyan Hadzhiev (43), Iva Georgieva (18) |
| Stale remote branches | 3 unmerged (`drive-instructions-test-and-filtering-lots`, `features/roles-page`, `vehicle_type_dropdown_automated_test`) |
| Last PR merged | PR 31648 — "Refactoring tests after release v2.2" |

Activity peaked June–November 2024 (10–21 commits/month), tapered to sporadic single-digit months from December 2024, and stopped entirely after December 2025.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | .NET 8 / C# |
| Test framework | NUnit |
| Browser automation | Selenium WebDriver (ChromeDriver) |
| Reporting | ExtentReports |
| Page Object lib | SeleniumExtras.PageObjects (`[FindsBy]`) |
| Config | JSON files (urls, globals, color themes) |

---

## Solution Structure

```
CALConsult.Automation.UI.sln
├── Config                          — Shared infra
│   ├── Helpers.cs                  — JSON config reader, branch/env helpers
│   ├── ExtentManager.cs            — ExtentReports setup
│   ├── Navigation/
│   │   ├── UrlBuilder.cs           — URL assembly from urls.json
│   │   └── UrlConfig.cs            — URL config model
│   └── JsonConfigs/
│       ├── NewDispoGlobals.json    — Dispo page URLs
│       ├── InvoiceVerificationGlobals.json
│       ├── ColorThemes.json        — Expected CSS color values
│       └── urls.json               — Base URL + endpoints
│
├── Pages                           — Page Object Model
│   ├── Pages/
│   │   ├── BasePage.cs             — WebDriver, Actions, WebDriverWait, scroll helpers
│   │   ├── LoginPage.cs
│   │   ├── TransportPage.cs
│   │   ├── PlanningPage.cs
│   │   ├── OrderDetailsPage.cs
│   │   └── ClientCommunicationPage.cs
│   └── PageComponents/             — Reusable UI fragments
│       ├── SidebarPanelComponent/
│       ├── PlanningPageComponents/     (CalendarPicker, LegSection, LotsSection, TransportOrderCard)
│       ├── PlanningFilteringLots/      (AddressField, WeightField, VolumePalletSpace, etc.)
│       ├── PlaningSorting/             (LegsSortingPanel, LotsSortingPanel)
│       ├── TransportFilterPanel/       (FilterPanel, FilterCheckbox, FilterDateField, etc.)
│       ├── CommonDetailsForm/          (CommonDetails, Contracter, FreightCarrier, Truck, Trailer)
│       ├── ContractDetailsForm/        (Expences)
│       ├── DriveInstructionsForm/      (LoadingPoint, UnloadingPoint)
│       ├── DriveInstructions/          (DriveInstructions overlay)
│       ├── FreightExchange/            (FreightExchangeForm, FreightExchangeOfferCard)
│       ├── TransportFeaturesForm/      (Properties, AdditionalInformation, VehicleBodyType)
│       └── ClientCommunicationPageComponents/ (CustomerList, CustomerDetails)
│
├── Disposition.Tests               — Dispo test cases
│   ├── Config/
│   │   ├── BaseTest.cs             — SetUp/TearDown lifecycle, branch switching
│   │   └── PagesProvider.cs        — Lazy page initialization
│   └── Features/
│       ├── SidebarNavigationPanelTests.cs
│       ├── TransportOrderList.cs
│       ├── TransportPageFilterPanel.cs
│       ├── TransportOrderCardTests.cs
│       ├── TransportOrderForms.cs
│       ├── LotsFilteringTests.cs
│       ├── ColorThemes.cs
│       └── ClientCommunicationTests.cs
│
└── InvoiceVerification.Tests       — Separate app (not Dispo)
    └── Tests.cs
```

The primary clustering is a **two-level Page Object Model**: top-level Page classes (one per route) compose granular PageComponent classes (one per UI section/widget). Tests are organized by **feature**, not by page.

---

## Test Lifecycle (BaseTest)

Every test follows this lifecycle:

1. **SetUp**: Launch ChromeDriver → navigate to `localhost:4200` → `LoginPage.Login()` → switch to configured test ABN branch
2. **Test execution**: Navigate via sidebar, interact through page objects
3. **TearDown**: Capture screenshot on failure → write ExtentReports entry → dispose driver

All URLs are hardcoded to `http://localhost:4200` — tests run against a local Frontend instance only.

---

## Coverage by Page/Feature

### 1. Sidebar Navigation — 3 tests ✅ all active

| Test | What it checks |
|------|---------------|
| `PageNavigation` | Click each sidebar item, verify URL matches config |
| `ExpandCollapseSidebar` | Toggle sidebar collapsed state |
| `CheckAllSidebarComponents` | Sidebar title = "DISPOSITION", menu items = Planning, Transport orders, Customer communication, Test |

**Depth: Shallow.** Presence and navigation only, no interaction with page content after navigation.

---

### 2. Transport Orders List (`/transport`) — 8 tests ✅ all active

| Test | What it checks |
|------|---------------|
| `AllColumnsAreDisplayed` | Exactly 10 columns rendered |
| `ValidateRowsCount` | Row count ≤ selected items-per-page for each dropdown option |
| `ColumnsCanBeSwitched` | Toggle Vehicle/Stops column visibility via customize view |
| `SortByColumn` | Sort by transport order number ascending + descending, verify order |
| `DisplayOrderDetails` | Click row → URL contains `order-details/{id}` |
| `SwitchListPages` | Next/previous pagination, data changes, page number updates |
| `DragAndDropColumns` | Drag column to first/last position, verify reorder |
| `ValidateBranchSwitching` | Switch to "10 - 34 - Kaufungen", verify data changes |

**Depth: Moderate.** Good structural coverage of the list component (columns, pagination, sorting, column reorder). Uses `Thread.Sleep` in several places (sorting, drag-drop, pagination) — fragile under load.

---

### 3. Transport Page Filter Panel (`/transport`) — 2 active, 7 disabled ⚠️

| Test | Status | What it checks |
|------|--------|---------------|
| `ValidateOpenFilterPanel` | ✅ Active | Filter panel opens |
| `ValidateCloseFilterPanel` | ✅ Active | Filter panel closes |
| `ValidateFilterButtonsToggle` | ❌ Commented out | Temperature filter button toggle |
| `ValidateCheckboxButtonToggle` | ❌ Commented out | Checkbox filter toggle |
| `ValidateTextFieldPopulation` | ❌ Commented out | Text field input |
| `ValidateSelectionDropdownSelection` | ❌ Commented out | VKS dropdown selection |
| `ValidateSaveButton` | ❌ Commented out | Apply filter persists state |
| `ValidateResetButton` | ❌ Commented out | Reset clears all filters |
| `ValidateDateFiltersByDateInput` / `ByDatePicker` | ❌ Commented out | Date filter population |

**Depth: Effectively minimal.** The filter panel tests were written but disabled (`//[Test]` attribute commented out). Only open/close works. No actual filtering verification is active.

---

### 4. Planning: Lots Filtering (`/planning`) — 6 tests ✅ all active

| Test | What it checks |
|------|---------------|
| `CheckAllFieldsAreDisplayed` | 7 dropdown options present (Address, Weight, Volume/Ground pallet space, Delivery/Pickup date, Temperature) |
| `CheckLotsAreFilteredByAddress` | Filter by zip code → lot count matches, reset restores original count |
| `CheckLotsAreFilteredByWeight` | Filter by weight range → lot count matches, reset restores |
| `CheckLotsAreFilteredByVolumePalletSpace` | Select checkbox → apply (no assertion on result count) |
| `CheckLotsAreFilteredByGroundPalletSpace` | Select checkbox → apply (no assertion on result count) |
| `CheckLotsAreFilteredByTemperatureClasses` | Filter by temperature → lot count matches by icon, reset restores |

**Depth: Moderate.** Address, weight, and temperature filtering have proper verify+reset cycles. Volume and ground pallet space tests apply the filter but **have no assertions** on the result — they only verify the filter can be applied without error.

---

### 5. Planning: Transport Order Card (`/planning`) — 4 tests, 1 known broken ⚠️

| Test | Status | What it checks |
|------|--------|---------------|
| `ForwardButtonWorkingAsExpected` | ✅ Active | Forward button opens order details in new tab |
| `MagicWandButtonWorkigAsExpected` | ✅ Active | Magic wand opens drive instructions overlay with close button |
| `CloseButtonWorkingAsExpected` | ⚠️ Marked failing | Close drive instructions (TODO: "failing because of a bug on the FE") |
| `DetailsButtonWorkingAsExpected` | ✅ Active | Details button in drive instructions navigates to order details |

**Depth: Shallow.** Tests the card's action buttons (forward, magic wand, close, details) but only on the first card. No variation in transport order data.

---

### 6. Order Details: Forms & Freight Exchange (`/order-details`) — 7 active, 1 disabled

| Test | Status | What it checks |
|------|--------|---------------|
| `NavigateBetweenForms` | ✅ Active | Click each form tab, verify it becomes selected |
| `ValidateVehicleTypeDropdown` | ❌ Commented out | Vehicle type dropdown selection |
| `ValidateFreightExchangeFormFieldsPresence` | ✅ Active | All 9 freight exchange form fields present |
| `ValidateFreightExchangeOfferCreation` | ✅ Active | Create offer → verify price + contact on card |
| `ValidateFreightExchangeOfferEdit` | ✅ Active | Create → edit price + contact → verify updated values |
| `ValidateFreightExchangeOfferDelete` | ✅ Active | Create → delete → verify card gone |
| `ValidateContactPersonSelection` | ✅ Active | Select contact → Timocom/Trans.eu checkboxes enable/disable correctly (3 parametrized contacts) |
| `ValidateTimocomToTransEuContactPersonChange` | ✅ Active | Switch from Timocom to Trans.eu contact → Timocom unchecked + disabled |
| `ValidateTransEuToTimocomContactPersonChange` | ✅ Active | Switch from Trans.eu to Timocom contact → Trans.eu unchecked + disabled |

**Depth: Deepest coverage in the suite.** Full CRUD on freight exchange offers with data verification. Contact person / freight platform checkbox logic tested with multiple parametrized scenarios covering Timocom-only, Trans.eu-only, and mixed contacts.

---

### 7. Color Themes — 3 tests ✅ all active

| Test | What it checks |
|------|---------------|
| `ColorThemeValidation` | Toggle light/dark on each page, verify background CSS value |
| `SidebarColorValidation` | Toggle theme, verify sidebar background changes |
| `SidebarComponentsColorValidation` | Toggle theme, verify sidebar menu item text colors |

**Depth: Shallow.** CSS value comparisons against `ColorThemes.json`. Functional but narrow — only background and text color, no component-level theming.

---

### 8. Client Communication (`/customer-communication`) — 2 active, 2 disabled ⚠️

| Test | Status | What it checks |
|------|--------|---------------|
| `ValidateClientCommunicationIsOpened` | ✅ Active | Page URL check |
| `EDIButtonWorkingAsExpected` | ✅ Active | Select customer → select checkbox → click EDI → snackbar "All records were sent to EDI successfully" |
| `EmailButtonWorkingAsExpected` | ❌ Commented out | E-Mail button (disabled in app) |
| `BothButtonWorkingAsExpected` | ❌ Commented out | Both button (disabled in app) |

**Depth: Minimal.** Only URL check and one happy-path EDI send. E-Mail and Both buttons disabled in the application itself.

---

## Summary

| Page/Feature | Active Tests | Disabled | Depth |
|-------------|:---:|:---:|-------|
| Sidebar Navigation | 3 | 0 | Shallow — presence/navigation |
| Transport Orders List | 8 | 0 | Moderate — list mechanics |
| Transport Filter Panel | 2 | 7 | Minimal — only open/close |
| Planning: Lots Filtering | 6 | 0 | Moderate — 3 of 5 filters verified |
| Planning: Transport Order Card | 3 | 1 (broken) | Shallow — button clicks only |
| Order Details: Freight Exchange | 7 | 1 | Deep — full CRUD + business logic |
| Color Themes | 3 | 0 | Shallow — CSS checks |
| Client Communication | 2 | 2 | Minimal — URL + one EDI send |
| **Total** | **34** | **11** | |

### What's NOT covered at all

- **Tour planning workflows** — no drag & drop of orders to tours, no stop reordering
- **Map interactions** — nothing on the map view
- **Tour calculation** — no trigger/verify of calculation results
- **Write operations on transport orders** — no editing of order fields (only freight exchange)
- **Planning: Legs section** — page objects exist (`LegSection`, `LegsSortingPanel`) but no tests
- **Planning: Sorting** — page objects exist (`LotsSortingPanel`, `LegsSortingPanel`) but no tests
- **Order Details: Common Details form** — page objects for Contracter, FreightCarrier, Truck, Trailer exist but no tests
- **Order Details: Transport Features** — page objects for Properties, AdditionalInformation, VehicleBodyType exist but no tests
- **Order Details: Contract Details / Expenses** — page object exists but no tests
- **Order Details: Drive Instructions form** — LoadingPoint/UnloadingPoint page objects exist but no tests
- **Multi-user / role-based scenarios** — single user only
- **Error states, validation messages, empty states**
- **Responsive / mobile behavior**

### Code Quality Notes

- Multiple `Thread.Sleep()` calls (6s, 5s, 500ms) instead of explicit waits — fragile timing
- Several `TimeSpan.FromSeconds(N)` calls that create a TimeSpan object but don't use it (no-op, likely intended as sleeps)
- Hardcoded test data (transport order numbers, customer names, zip codes) tied to specific ABN branch state
- All URLs hardcoded to `localhost:4200` — no CI/environment flexibility
- Page objects exist for many components that have zero test coverage, suggesting planned work that was never completed
