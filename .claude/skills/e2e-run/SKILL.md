---
name: e2e-run
description: Run Playwright e2e tests. Use when the user wants to run e2e tests, check test results, or verify test status. Supports running all tests, specific tests, headed mode, and debugging failures.
allowed-tools: Bash,Read
---

# E2E Run Skill

Runs Playwright e2e tests for the Disposition Frontend.

## When to Use

- User asks to "run e2e tests", "run playwright", "check tests"
- User wants to verify a specific test after changes
- User wants to see tests run in a visible browser

## Usage

Parse the user's request to determine:
- **Which tests**: all, or a specific spec file / test name
- **Mode**: headless (default), headed (visible browser), or debug

### Run All Tests

```bash
cd "Code/Disposition-Frontend" && npx playwright test --reporter=list
```

### Run Specific Test File

```bash
cd "Code/Disposition-Frontend" && npx playwright test e2e/tests/TESTNAME.spec.ts --reporter=list
```

### Run with Visible Browser

```bash
cd "Code/Disposition-Frontend" && npx playwright test e2e/tests/TESTNAME.spec.ts --headed --reporter=list
```

### Run Matching Test Name

```bash
cd "Code/Disposition-Frontend" && npx playwright test --grep "test name pattern" --reporter=list
```

### Debug Mode (Step Through)

```bash
cd "Code/Disposition-Frontend" && npx playwright test e2e/tests/TESTNAME.spec.ts --debug
```

## On Failure

1. Read the failure screenshot from `test-results/` to understand what went wrong
2. Check if it's a selector issue (element not found) or a timing issue (timeout)
3. Report the failure with the screenshot and suggest a fix

## Arguments

The user's input after `/e2e-run` is parsed as:
- No args → run all tests headless
- A test name → run that specific test headless
- `--headed` or `--visible` or `with ui` → add `--headed` flag
- `--debug` → add `--debug` flag
