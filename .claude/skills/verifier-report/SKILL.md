---
name: verifier-report
description: Turn a TMS Verifier JSON output file into a readable markdown report. Use when the user has a verifier JSON (e.g. from Disposition-Rollout-Tools/reports/) and wants a human-friendly summary.
allowed-tools: Bash,Read,Write
---

# TMS Verifier Report Skill

Converts a TMS Database Verifier JSON output into a structured, readable markdown report.

## Arguments

`/verifier-report <path-to-json>` — path to the verifier output JSON file (relative or absolute).

If no path is given, look for the most recent `.json` file in `Code/Disposition-Rollout-Tools/reports/` and ask the user to confirm.

## Behavior

1. **Read** the JSON file with the Read tool.
2. **Parse** using a Python script via Bash (the files can be 2500+ lines).
3. **Write** a markdown report to the same directory as the input file, with the same base name but `.md` extension. E.g. `abn1060-oracle-l6.json` → `abn1060-oracle-l6.md`.
4. **Print** the report path and a one-line summary to the user.

## Parsing — use Python via Bash

The JSON files are large. Use a Python script via Bash to extract all data and produce the markdown in one pass. Do NOT attempt to read/parse the JSON manually line by line.

The Python script must:
- Read the JSON from the file path passed as argv[1]
- Write the markdown to the output path passed as argv[2]
- Print a brief summary to stdout

## Verification Level Hierarchy

The verifier checks are cumulative levels — each level includes all checks from previous levels:

| Level | Check | Severity | What it means |
|-------|-------|----------|---------------|
| L1 | Existence | CRITICAL | Object doesn't exist in the database at all |
| L2 | Type | HIGH | Object exists but is wrong kind (e.g. Function instead of Procedure) |
| L3 | Signature | MEDIUM | Callable exists but has wrong argument count |
| L4 | Permissions | HIGH | Object exists but user lacks required permission |
| L5 | Columns | MEDIUM | Table/View missing expected columns |
| L6 | Drift | LOW | Extra columns in DB not tracked by TMS Bridge (informational) |

The report **must lead with violations, sorted by level** (L1 first = most critical). This is the primary value of the report — a reader should see the worst problems first.

## Report Template

Generate the report using this exact structure:

````markdown
# TMS Verifier Report — <SCHEMA> on <PROVIDER>

**Generated:** <report generation timestamp>
**Verified:** <timestamp from JSON>
**Schema:** <schema>
**Provider:** <provider>
**Level:** <level>
**Duration:** <duration>
**Result:** <PASSED ✅ / FAILED ❌>

---

## Summary

| Check | Level | Passed | Failed |
|-------|-------|--------|--------|
| Existence | L1 | <n> | <n> |
| Type | L2 | <n> | <n> |
| Signature | L3 | <n> | <n> |
| Permissions | L4 | <n> | <n> |

**Columns (L5):** <columnsOk> OK across <objectsChecked> objects — <columnsMissing> missing
**Drift (L6):** <objectsWithDrift> objects with <totalExtraColumns> extra columns

---

## All Objects

<Compact table of all active (non-skipped) objects. Sort: failed first, then by name:>

| # | Object | Kind | Schema | Passed | Existence | Type | Signature | Permission | Columns |
|---|--------|------|--------|--------|-----------|------|-----------|------------|---------|
| 1 | <name> | <kind> | <schema> | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | <ok>/<expected> or — |

<Use ✅ for pass, ❌ for fail, — for not applicable>

---

## Verification Levels

| Level | Check | Severity | Meaning |
|-------|-------|----------|---------|
| L1 | Existence | CRITICAL | Object doesn't exist in the database |
| L2 | Type | HIGH | Wrong object kind (e.g. Function instead of Procedure) |
| L3 | Signature | MEDIUM | Wrong argument count on callable |
| L4 | Permissions | HIGH | User lacks required permission |
| L5 | Columns | MEDIUM | Table/View missing expected columns |
| L6 | Drift | LOW | Extra columns not tracked by TMS Bridge (informational) |

Levels are cumulative — L6 includes all checks from L1–L5.

---

## Violations

<Group violations by level, highest severity first.
Only include level headings that have actual violations.
If zero violations across all levels, write: "All <N> objects passed all checks.">

### L1 — Existence Failures (CRITICAL)

<For each object where existence = NotFound:>

| Object | Kind | Schema |
|--------|------|--------|
| <name> | <kind> | <schema> |

### L2 — Type Mismatches (HIGH)

<For each object where typeCheck = Mismatch:>

| Object | Expected | Actual | Schema |
|--------|----------|--------|--------|
| <name> | <kind> | <actualKind> | <schema> |

### L3 — Signature Mismatches (MEDIUM)

<For each object where signature = Mismatch. Look up expectedArgs from the db-objects.json
registry at TmsBridgeDbVerifier.Core/Registry/db-objects.json (match by name + schema, case-insensitive):>

| Object | Kind | Expected Args | Actual Args | Schema |
|--------|------|---------------|-------------|--------|
| <name> | <kind> | <expectedArgs> | <actualArgs> | <schema> |

### L4 — Permission Failures (HIGH)

<For each object where permission is Denied or failed:>

| Object | Kind | Required | Schema |
|--------|------|----------|--------|
| <name> | <kind> | <requiredPermission> | <schema> |

### L5 — Column Failures (MEDIUM)

<For each object with missing columns or liveProbeError:>

#### <name> (<kind>, <schema>)

**Missing columns (<count>):** `col1`, `col2`

<If liveProbeError:>
**Live probe error:** <error text>

---

## Appendix

### Column Type Mismatches

<Table of ALL type mismatches across all objects, including passed ones — these are
informational since Oracle DATE vs PostgreSQL timestamp with time zone is a known
cross-provider pattern:>

| Object | Column | Expected | Actual | Compatible |
|--------|--------|----------|--------|------------|
| <name> | <col> | <expected> | <actual> | <yes/no> |

<If no type mismatches: "No column type mismatches detected.">

### Schema Drift

<Table of objects with extra columns, sorted by count descending:>

| Object | Kind | Extra Columns |
|--------|------|---------------|
| <name> | <kind> | <count> |

**Total:** <totalExtraColumns> extra columns across <objectsWithDrift> objects

<If no drift: "No schema drift detected.">

### Deprecated Objects

| Object | Kind | Status |
|--------|------|--------|
| <name> | <kind> | Skipped |

<If none: "No deprecated objects.">

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
````

## Rules

1. **Use Python for parsing** — never parse 2500-line JSON by reading line ranges.
2. **Include all sections** — even if empty (write "None" or "No X detected").
3. **Violations sorted by level** — L1 first (most critical), L6 last (informational). This is the primary value of the report.
4. **Omit empty violation levels** — don't show "L1 — Existence Failures" if there are none.
5. **Drift details** — only show counts per object, not individual column names (those lists can be 50+ items).
6. **Type mismatches are informational** — objects can still be "passed" with type mismatches. Show them all under L6.
7. **Virtual Architect footer** — always include.
8. **Output file** — write to the same directory as the input, same name with `.md` extension.
9. **Failed objects first** — in the "All Objects" table, list failed objects at the top.
