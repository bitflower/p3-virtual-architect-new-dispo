# PRD-003: TMS Bridge DB Verifier — Core Library + Column Verification

**Feature ID:** 003_TMS_Bridge_DB_Verifier_Core_And_Column_Checks
**Date:** 2026-06-11
**Status:** Draft
**Prerequisite:** PRD-002 (Column Registry) must be complete

---

## 1. Problem

The TMS Bridge DB Verifier checks 77 database objects but cannot verify column-level correctness. BUG-124918 proved this gap is production-critical: a view passed all 4 levels while missing a column the TMS Bridge depends on, causing a runtime crash.

PRD-002 delivers the column registry (the data). This PRD delivers the verification engine (the logic) — Level 3 column checks and Level 6 drift detection — plus the structural refactoring needed to make the verifier reusable across multiple hosts.

Today the verifier is a monolithic CLI tool. Four downstream consumers need to reference the verification logic without the CLI wrapper:
- Claude Code skill (Phase 2) — invokes CLI, parses JSON
- Pipeline gate (Phase 4) — invokes CLI, reads exit code
- GCP Cloud Host (Phase 5) — references `.Core` directly as a library
- Wiki reporter (Phase 3) — references `.Core` for `VerificationResult` model

Without extracting a shared `.Core` library, each host would duplicate or fork the verification logic.

Additionally, the existing verifier has **zero tests**. Extracting `.Core` is a structural refactoring of ~10 files across 5 namespaces. Without characterization tests locking in current behavior first, regressions are invisible.

**Evidence from prior art:**

- DB Access Test Automation: "column definitions not checked" — explicit known limitation (`02_Explorations/2026-05-07_TMS_Bridge_DB_Access_Test_Automation/`)
- ABN1060 Oracle Review: `U_TIME` missing from `V_DIS_TO_PICKUPPLANNING` found only by manual testing, not by verifier (`02_Explorations/2026-05-11_ABN1060_Oracle_TMS_Database_Review_-_First_Batch_Analysis/`)
- Source exploration: two-stage check (catalog + live `SELECT ... WHERE FALSE` probe) catches scenarios neither stage catches alone — Oracle stale catalogs, permission issues, view-over-view chain failures (`02_Explorations/2026-06-11_Advanced_TMS_Verifier_-_Continuous_Database_Monitoring_Service_in_GCP/`)

## 2. Direction Alignment

No direction/strategy documents configured. This PRD is Phase 1 of the 6-phase plan in the source exploration. It is the first phase that produces runnable verification code — everything downstream (skill, pipeline, cloud host) depends on `.Core` existing.

**Conscious scope reduction:** The exploration's Phase 1 includes `FirestoreResultStore` — descoped to Phase 5 (GCP host). Only the `IResultStore` interface and `FileResultStore` are in scope here, and only as Should Have.

## 3. Requirements (MoSCoW)

### Must Have

- **M1: Characterization tests for existing CLI behavior.** Before any refactoring, write MSTest tests that lock in:
  - Exit codes: 0 (all pass), 1 (failures), 2 (connection error)
  - Per-level verification logic: Level 1 (existence), Level 2 (type), Level 3 (signature), Level 4 (permissions)
  - Per-provider behavior: PostgreSQL and Oracle verifier paths
  - `ObjectCheckResult.Passed` logic for all status combinations
  - `DbObjectRegistry` deserialization of `db-objects.json`
  - `SchemaResolver` and `ProviderDetector` output for known inputs
- **M2: Extract `TmsBridgeDbVerifier.Core` class library.** Move all verification logic, models, registry, infrastructure, and reporting into a new `.Core` project. The CLI becomes a thin wrapper: argument parsing -> `VerificationRunner` -> output formatting. Namespace: `TmsBridgeDbVerifier.Core`.
  - Files to move: `Verification/`, `Model/`, `Registry/`, `Infrastructure/`, `Reporting/`
  - Files to keep in CLI: `Program.cs` only
  - `db-objects.json` embedded resource moves to `.Core`
  - CLI project references `.Core`
- **M3: `VerificationRunner` orchestrator.** New class in `.Core` that encapsulates the verification loop currently in `Program.cs:99-163`. Signature: `Task<VerificationResult> RunAsync(string connectionString, string[] schemas, VerificationLevel level)`. Returns structured results — replaces the inline loop.
- **M4: Level 3 — Column Verification (tables + views only).** For each table/view with a `columns` array in the registry:
  - **Stage A (Catalog check):** Query `information_schema.columns` (PostgreSQL) / `ALL_TAB_COLUMNS` (Oracle) for the object. Compare each expected column name against actual columns. Case-sensitive for PostgreSQL, case-insensitive for Oracle (per PRD-002 M8 contract).
  - **Stage B (Live SELECT probe):** Execute `SELECT col1, col2, ... FROM schema.object WHERE FALSE` (PostgreSQL) / `SELECT col1, col2, ... FROM SCHEMA.OBJECT WHERE 1=0` (Oracle). If the DB returns an error, capture the error message identifying the failing column.
  - Report per column: present / missing / error
- **M5: Level 6 — Drift Detection (advisory).** Reverse of Level 3: detect columns in the database catalog that are NOT in the registry. Report as warnings, not failures. `ObjectCheckResult.Passed` must NOT be affected by drift warnings.
- **M6: Extend `VerificationLevel` enum.** Add `Columns = 16` and `Drift = 32`. Update `All` to include both. Update CLI `--level` parsing: `5` = Levels 1-4 + Columns, `6` = Levels 1-5 + Drift, `all` = everything.
- **M7: Extend `IDbVerifier` interface.** Add:
  - `Task<ColumnCheckResult> CheckColumns(DbObject obj, string schema, string name, ExpectedColumn[] columns, CancellationToken ct)`
  - `Task<DriftResult> CheckDrift(DbObject obj, string schema, string name, ExpectedColumn[] columns, CancellationToken ct)`
- **M8: Extend `ObjectCheckResult`.** Add column check status and drift result fields. Extend `Passed` property to include column status (fail = not passed) but exclude drift (advisory only).
- **M9: JSON output mode.** Add `--output json` flag to CLI. When set, suppress console output and write `VerificationResult` as a JSON document to stdout. Structure:
  ```json
  {
    "timestamp": "2026-06-11T14:30:00Z",
    "database": "D-10-34",
    "schema": "tms1034",
    "provider": "PostgreSQL",
    "level": 6,
    "duration_ms": 1250,
    "summary": { "pass": 74, "fail": 2, "warn": 1, "total": 77 },
    "objects": [
      {
        "name": "v_dis_tp_client_comm",
        "type": "View",
        "existence": "PASS",
        "type_check": "PASS",
        "columns": {
          "expected": 88,
          "present": 87,
          "missing": ["trucklicenseplate"],
          "type_mismatches": [],
          "extra": ["legacy_col_xyz"]
        },
        "permissions": "PASS",
        "live_probe": "FAIL: column \"trucklicenseplate\" does not exist"
      }
    ]
  }
  ```
- **M10: Existing CLI behavior unchanged.** All existing flags (`-c`, `-s`, `-l`, `-v`), exit codes (0/1/2), and default console output must work identically after the refactoring. Characterization tests (M1) must pass without modification.

### Should Have

- **S1: Column type compatibility checks.** In Stage A, compare expected type (from registry) against actual type. Require a compatibility map for common aliases: `varchar` <-> `character varying`, `int4` <-> `integer`, `int8` <-> `bigint`, `numeric` <-> `decimal`. Report mismatches as warnings (not failures) since `type: null` columns (no explicit `.HasColumnType()`) can't be checked.
- **S2: `IResultStore` interface + `FileResultStore`.** Interface in `.Core`: `Task StoreAsync(VerificationResult result)`. `FileResultStore` writes timestamped JSON files to a directory. CLI gets `--store-dir ./results` flag. `NullResultStore` for pipeline use (no persistence).
- **S3: `IResultQuery` interface.** Read history by database, time range, object name. `FileResultQuery` reads from the same directory `FileResultStore` writes to.

### Could Have

- **C1: `MarkdownReporter` in `.Core`.** Generates a markdown status page from `VerificationResult` — consumed by the wiki publisher skill (Phase 3).
- **C2: Oracle type compatibility map.** Extend S1 for Oracle-specific types: `VARCHAR2` <-> `character varying`, `NUMBER` <-> `numeric`/`bigint`/`integer`.

### Won't Have

- **W1: `FirestoreResultStore`** — interface is in `.Core` (S2), Firestore implementation deferred to Phase 5 GCP host
- **W2: Cloud Function / Cloud Run host** — Phase 5
- **W3: Claude Code skill** — Phase 2 (separate PRD)
- **W4: Pipeline gate integration** — Phase 4 (separate PRD)
- **W5: Wiki publishing** — Phase 3 (separate PRD)
- **W6: CI automation for column registry updates** — deferred per PRD-002 W1
- **W7: Any changes to TMS Bridge source code**

## 4. Out of Scope

- Alerting, dashboards, or monitoring infrastructure
- Secret Manager integration (cloud host concern)
- Cloud Scheduler or Cloud Workflow setup
- Multi-schema parallel verification (single-threaded per schema is fine for now)
- Any new GCP infrastructure

## 5. Implementation Approach (unverified hint)

### Implementation order (sequence matters)

**Step 1: Characterization tests (M1)**
New project: `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Tests/TmsBridgeDbVerifier.Tests.csproj` (MSTest). Tests target the existing monolithic project. Cover: `ProviderDetector`, `SchemaResolver`, `DbObjectRegistry` deserialization, `ObjectCheckResult.Passed` logic, `VerificationLevel` flag combinations. Provider-specific verifier tests can use a mock/stub connection or test against known catalog responses.

**Step 2: Extract `.Core` (M2)**
New project: `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/TmsBridgeDbVerifier.Core.csproj` (class library, net9.0). Move all folders except `Program.cs`. Update namespaces from `TmsBridgeDbVerifier.*` to `TmsBridgeDbVerifier.Core.*`. CLI project gets a `<ProjectReference>` to `.Core`. Run characterization tests — must pass unchanged.

**Step 3: `VerificationRunner` (M3)**
Extract the loop from `Program.cs:46-173` into `VerificationRunner.RunAsync()`. CLI delegates to it. Run characterization tests again.

**Step 4: Extend model + interface (M6, M7, M8)**
Add new enum flags, interface methods, result fields. Existing tests still pass (new fields default to NotChecked/empty).

**Step 5: Level 3 + Level 6 (M4, M5)**
Implement `CheckColumns()` and `CheckDrift()` in both `PostgreSqlVerifier` and `OracleVerifier`. Write new tests for column verification.

**Step 6: JSON output (M9)**
Add `--output json` flag. `JsonReporter` in `.Core` serializes `VerificationResult` to stdout.

### Module layout after refactoring

```
Code/Disposition-Rollout-Tools/
+-- TmsBridgeDbVerifier.Core/
|   +-- TmsBridgeDbVerifier.Core.csproj
|   +-- Model/
|   |   +-- DbObject.cs (+ ExpectedColumn record)
|   |   +-- ObjectCheckResult.cs (+ ColumnCheckResult, DriftResult)
|   |   +-- VerificationLevel.cs (+ Columns, Drift flags)
|   |   +-- VerificationResult.cs (new — top-level result)
|   +-- Registry/
|   |   +-- db-objects.json (embedded resource, moved from CLI)
|   |   +-- DbObjectRegistry.cs
|   +-- Verification/
|   |   +-- IDbVerifier.cs (+ CheckColumns, CheckDrift)
|   |   +-- PostgreSqlVerifier.cs
|   |   +-- OracleVerifier.cs
|   |   +-- VerificationRunner.cs (new)
|   +-- Infrastructure/
|   |   +-- ProviderDetector.cs
|   |   +-- SchemaResolver.cs
|   +-- Reporting/
|   |   +-- ConsoleReporter.cs
|   |   +-- JsonReporter.cs (new)
|   +-- Storage/ (S2 — Should Have)
|       +-- IResultStore.cs
|       +-- IResultQuery.cs
|       +-- FileResultStore.cs
|       +-- NullResultStore.cs
+-- TmsBridgeDbVerifier/
|   +-- TmsBridgeDbVerifier.csproj (references .Core)
|   +-- Program.cs (thin wrapper only)
+-- TmsBridgeDbVerifier.Tests/
    +-- TmsBridgeDbVerifier.Tests.csproj (MSTest)
    +-- ... (characterization + new level tests)
```

## 6. Files Likely to Change

| File | Change | New/Modified |
|---|---|---|
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/TmsBridgeDbVerifier.Core.csproj` | New class library project | New |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/Model/*.cs` | Moved from CLI + extended | New (moved) |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/Verification/*.cs` | Moved from CLI + extended with CheckColumns/CheckDrift | New (moved) |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/Registry/*` | Moved from CLI (db-objects.json + DbObjectRegistry.cs) | New (moved) |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/Infrastructure/*` | Moved from CLI | New (moved) |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/Reporting/*` | Moved from CLI + new JsonReporter | New (moved) |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/Verification/VerificationRunner.cs` | New orchestrator | New |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/TmsBridgeDbVerifier.csproj` | Remove source files, add .Core reference | Modified |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/Program.cs` | Slim to thin wrapper delegating to VerificationRunner | Modified |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Tests/TmsBridgeDbVerifier.Tests.csproj` | New MSTest project | New |

## 7. Verification

- **V1 — Characterization tests pass after refactoring.** All tests written in M1 must pass after the `.Core` extraction (M2) and `VerificationRunner` extraction (M3) without modification.
- **V2 — CLI backward compatibility.** Run the refactored CLI against ABN 1034 with `-l 4` (existing levels only). Output and exit code must match pre-refactoring behavior.
- **V3 — Level 3 column check catches the BUG-124918 scenario.** Run with `-l 5` against a database where a known column is missing (or simulate by removing `trucklicenseplate` from the registry and checking it reports as "extra" via Level 6). Exit code must be 1.
- **V4 — Level 6 drift detection is advisory.** Run with `-l 6`. If extra columns exist in the database, they appear as warnings but exit code remains 0 (assuming all other levels pass).
- **V5 — JSON output.** Run with `--output json -l 6`. Output is valid JSON matching the `VerificationResult` schema. Parseable by `jq`.
- **V6 — Live SELECT probe.** Level 3 runs both Stage A (catalog) and Stage B (SELECT WHERE FALSE). If Stage A passes but Stage B fails (e.g., Oracle stale catalog), the column is reported as failed.
- **V7 — Cross-provider.** Level 3 and 6 work for both PostgreSQL (case-sensitive name match) and Oracle (case-insensitive name match) verifiers.

## 8. Related

### Prior Art

- `02_Explorations/2026-05-07_TMS_Bridge_DB_Access_Test_Automation/` — original verifier design, 3-level model, "column definitions not checked"
- `02_Explorations/2026-05-11_ABN1060_Oracle_TMS_Database_Review_-_First_Batch_Analysis/` — manual column-level issues (`U_TIME`, `Comment` casing, `comment_` rename)
- `02_Explorations/2026-06-11_Advanced_TMS_Verifier_-_Continuous_Database_Monitoring_Service_in_GCP/` — 6-level model, two-stage check design, result store, architecture
- `02_Explorations/2026-05-19_TMS_Bridge_Function_vs_Procedure_Execution_Gap/` — type mismatch patterns
- `02_Explorations/2026-06-19_Oracle_Identifier_Length_Limits_-_Are_the_V_DIS_TP_CLIENT_COMM_Column_Length_Iss/` — Oracle 12.1 30-byte identifier limit, latent TMS Bridge bug in `V_DIS_TP_CLIENT_COMM` (discovered during PRD-003 smoke testing)

### Prerequisites

- **PRD-002 (Column Registry):** `db-objects.json` with `columns` arrays must exist before Level 3/6 can verify anything

### Downstream

- **Phase 2:** Claude Code `/verify-databases` skill — invokes CLI with `--output json`
- **Phase 3:** Wiki status page — uses `MarkdownReporter` (C1) or generates markdown from JSON
- **Phase 4:** Pipeline gate — invokes CLI, reads exit code
- **Phase 5:** GCP Cloud Host — references `.Core` directly, adds `FirestoreResultStore`

### Existing Artifacts

- `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/` — existing CLI to refactor
- `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/Registry/db-objects.json` — registry (extended by PRD-002), includes `extractedFromCommit` watermark for diff-driven sync
- `.claude/agents/tms-bridge-db-extractor.md` — agent that produces the registry
- `.claude/skills/sync-db-registry/SKILL.md` — diff-driven sync skill: compares TMS Bridge `origin/master` against watermark, classifies changes, triggers targeted patch or full re-extraction. Use via `/loop 30m /sync-db-registry` for continuous sync (replaces W6 CI automation for local dev)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
