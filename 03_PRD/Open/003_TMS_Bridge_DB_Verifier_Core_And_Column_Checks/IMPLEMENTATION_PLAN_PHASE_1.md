# Implementation Plan: PRD-003 — TMS Bridge DB Verifier Core + Column Checks

**Status:** Approved by user, awaiting branch creation
**Branch:** `feature/003-db-verifier-core-column-checks`
**Worktrees:** No (single branch, disjoint file ownership)
**Date:** 2026-06-19

---

## Decisions locked in

| # | Question | Decision |
|---|----------|----------|
| 1 | Namespace strategy during .Core extraction | **B — Rename** namespaces to `TmsBridgeDbVerifier.Core.*`. Accept that characterization tests need a find-and-replace after M2. Tests are written against old namespaces first (M1), then updated as part of M2. |
| 2 | S1 type compatibility — descope or implement? | **Implement for both providers.** Registry types are EF Core's deterministic PostgreSQL type names — comparing against the catalog `data_type` is valid. PostgreSQL comparison is direct (same type name format). Oracle comparison uses a PostgreSQL-to-Oracle type compatibility map. **C2 elevated to Must Have.** |
| 3 | Objects with no column data in registry | **B — Warning.** Report as `"Columns: ⚠ no column data in registry"`. Not a pass/fail — purely informational. |
| 4 | `ObjectCheckResult` extension strategy | **B — Convert to class with property-init syntax.** Cleaner for extensibility. The record's positional constructor becomes a class with init-only properties and a constructor. |
| 5 | Worktrees | **No.** Single branch with disjoint file ownership. |
| 6 | Smoke test target | **abn1034** PostgreSQL instance. |
| 7 | S2/S3 (`IResultStore`/`IResultQuery`) | **Deferred** to Phase 5 (GCP host). Not in scope for this PRD. |

---

## Architectural notes that bind the implementation

### PRD divergences from actual repo (repo wins)

| PRD claim | Actual repo state | Impact |
|-----------|-------------------|--------|
| `Program.cs:99-163` is the verification loop (M3) | Lines 99-163 are the inner *object loop*. The `VerificationRunner` must encapsulate lines 76-170: the full schema loop, `allPassed` tracking, reporter interaction points, and exit-code logic. | VerificationRunner scope is larger than PRD implies |
| "Move all folders except `Program.cs`" (M2) | `Program.cs` also contains `ParseLevel()` (lines 180-188) and `CreateVerifier()` (lines 190-195). These are verification infrastructure, not CLI concerns. They move to `.Core`. | Two additional methods move |
| DbObject has columns — implied by M4 | `DbObject` record has no `Columns` property. `DbObjectRegistry.JsonDbObject` has no `columns` field. The JSON data (625 columns across 33 objects) is silently discarded during deserialization. PRD-002 delivered the JSON format but not the C# model. | Must add `ExpectedColumn` model, `ColumnarObject` subtype, `JsonColumn` deserialization, and `MapToModel` updates before any column verification code can work |
| No `.sln` file mentioned | No solution file exists for the `Disposition-Rollout-Tools` repo. `dotnet test` needs a solution or explicit project path. | Must create `TmsBridgeDbVerifier.sln` with all 3 projects |
| "Namespace: `TmsBridgeDbVerifier.Core`" works seamlessly | Renaming root namespace from `TmsBridgeDbVerifier` to `TmsBridgeDbVerifier.Core` changes the embedded resource name. `DbObjectRegistry.LoadFromJson()` uses `EndsWith("db-objects.json")` — this survives the rename. | No issue, but worth noting |

### Integration points verified in the repo

| Component | File | What matters |
|-----------|------|-------------|
| CLI argument parsing | `Program.cs:8-44` | Uses `System.CommandLine` 2.0.0-beta4. New `--output` flag follows same `Option<string>` pattern. |
| Provider detection | `Infrastructure/ProviderDetector.cs` | Regex-based, returns `DbProvider` enum. Column checks need `DbProvider` to select the right catalog query and type map. |
| Schema resolution | `Infrastructure/SchemaResolver.cs` | `Resolve()` maps `"tms"` → tenant schema, handles Oracle uppercasing. Column checks reuse this for `information_schema` / `ALL_TAB_COLUMNS` queries. |
| Embedded resource | `.csproj:18-20` | `db-objects.json` is `EmbeddedResource`. Moves to `.Core.csproj` with same include path. |
| Oracle package routines | `OracleVerifier.cs:189-203` | Routines live in packages under `TenantSchema`. Column checks for tables/views use `OWNER` (the resolved schema), not `TenantSchema`. |
| Object registry | `DbObjectRegistry.cs:29-44` | `MapToModel()` dispatches on `Kind` string. Must add column mapping for `Table`/`View` kinds and handle the new `JsonColumn[]` field. |

### Type compatibility maps (binding for S1 + C2)

**PostgreSQL alias map** — used when comparing registry type against `information_schema.columns.data_type`:

| Registry type | Catalog equivalents (any match = compatible) |
|---------------|----------------------------------------------|
| `text` | `text`, `character varying` |
| `character varying` | `character varying`, `text` |
| `integer` | `integer`, `int4` |
| `bigint` | `bigint`, `int8` |
| `smallint` | `smallint`, `int2` |
| `numeric` | `numeric`, `decimal` |
| `double precision` | `double precision`, `float8` |
| `boolean` | `boolean`, `bool` |
| `timestamp with time zone` | `timestamp with time zone`, `timestamptz` |
| `timestamp without time zone` | `timestamp without time zone`, `timestamp` |

**Oracle type compatibility map** — used when comparing registry (PostgreSQL-native) type against `ALL_TAB_COLUMNS.DATA_TYPE`:

| Registry type (PostgreSQL) | Oracle compatible types |
|----------------------------|------------------------|
| `text` | `VARCHAR2`, `NVARCHAR2`, `CLOB`, `NCLOB`, `CHAR`, `NCHAR` |
| `character varying` | `VARCHAR2`, `NVARCHAR2` |
| `integer` | `NUMBER` |
| `bigint` | `NUMBER` |
| `smallint` | `NUMBER` |
| `numeric` | `NUMBER`, `FLOAT` |
| `double precision` | `BINARY_DOUBLE`, `FLOAT`, `NUMBER` |
| `boolean` | `NUMBER`, `CHAR` |
| `timestamp with time zone` | `TIMESTAMP WITH TIME ZONE`, `TIMESTAMP(6) WITH TIME ZONE`, `TIMESTAMP WITH LOCAL TIME ZONE`, `TIMESTAMP(6) WITH LOCAL TIME ZONE` |
| `timestamp without time zone` | `TIMESTAMP`, `TIMESTAMP(6)`, `DATE` |

Implementation: a static `TypeCompatibility` class in `Core/Verification/` with `bool IsCompatible(string expectedType, string actualType, DbProvider provider)`. The map is a `Dictionary<string, HashSet<string>>` per provider, normalized to lowercase for PostgreSQL and uppercase for Oracle. An exact match (after normalization) always passes even if not in the map — the map only handles known aliases.

---

## Schema

### New model types in `TmsBridgeDbVerifier.Core.Model`

**`ExpectedColumn` record:**

| Property | Type | Source | Notes |
|----------|------|--------|-------|
| `Name` | `string` | `db-objects.json` `.columns[].name` | Case-sensitive for PG, case-insensitive for Oracle |
| `Type` | `string?` | `db-objects.json` `.columns[].type` | PostgreSQL-native type name. `null` if not extractable. |
| `InferredType` | `bool` | `db-objects.json` `.columns[].inferredType` | `true` = EF Core convention, `false` = explicit `.HasColumnType()` |

**`ColumnCheckResult` class:**

| Property | Type | Notes |
|----------|------|-------|
| `ColumnName` | `string` | The expected column name |
| `Status` | `ColumnStatus` enum | `Present`, `Missing`, `Error` |
| `TypeExpected` | `string?` | From registry |
| `TypeActual` | `string?` | From catalog query |
| `TypeCompatible` | `bool?` | `null` if no type data, `true`/`false` from compatibility map |
| `LiveProbeError` | `string?` | Error message from `SELECT ... WHERE FALSE` if column failed |

**`ColumnStatus` enum:** `Present`, `Missing`, `Error`

**`ColumnVerificationResult` class:**

| Property | Type | Notes |
|----------|------|-------|
| `Expected` | `int` | Count of columns in registry |
| `Present` | `int` | Count found in catalog |
| `Missing` | `string[]` | Column names not in catalog |
| `TypeMismatches` | `ColumnCheckResult[]` | Columns where type is incompatible |
| `LiveProbeError` | `string?` | Full error from SELECT probe, if any |
| `Passed` | `bool` | `true` if no Missing and no Error. Type mismatches are warnings, not failures. |

**`DriftResult` class:**

| Property | Type | Notes |
|----------|------|-------|
| `ExtraColumns` | `string[]` | Columns in DB but not in registry |
| `HasDrift` | `bool` | `ExtraColumns.Length > 0` — advisory, never affects `Passed` |

**`ColumnCheckStatus` enum (on ObjectCheckResult):** `Passed`, `Failed`, `NotChecked`, `Skipped`, `NotConfigured`

**`ObjectCheckResult` converted from record to class:**

| Property | Type | Init | Notes |
|----------|------|------|-------|
| `Object` | `DbObject` | required | Existing |
| `ResolvedSchema` | `string` | required | Existing |
| `Existence` | `ExistenceStatus` | required | Existing |
| `TypeCheck` | `TypeStatus` | required | Existing |
| `ActualKind` | `DbObjectKind?` | required | Existing |
| `Signature` | `SignatureStatus` | required | Existing |
| `ActualArgs` | `int?` | required | Existing |
| `Permission` | `PermissionStatus` | required | Existing |
| `ColumnCheck` | `ColumnCheckStatus` | `= NotChecked` | **New.** |
| `ColumnResult` | `ColumnVerificationResult?` | `= null` | **New.** |
| `DriftResult` | `DriftResult?` | `= null` | **New.** Advisory only. |
| `Passed` | `bool` (computed) | — | Extended: includes `ColumnCheck` (fail = not passed), excludes drift |

**Updated `Passed` logic:**
```
Existence is Found or Skipped
&& TypeCheck is Match or NotChecked or Skipped
&& Signature is Match or NotChecked or Skipped
&& Permission is Granted or NotChecked or Skipped
&& ColumnCheck is Passed or NotChecked or Skipped or NotConfigured   ← NEW
```

### VerificationLevel enum extension

| Flag | Value | CLI `--level` | Cumulative meaning |
|------|-------|---------------|-------------------|
| `Existence` | 1 | `1` | Existence only |
| `Type` | 2 | `2` | 1 + Type |
| `Signature` | 4 | `3` | 1-2 + Signature |
| `Permissions` | 8 | `4` (default) | 1-3 + Permissions |
| `Columns` | 16 | `5` | 1-4 + Column checks |
| `Drift` | 32 | `6` | 1-5 + Drift detection |
| `All` | 63 | `all` | Everything |

### IDbVerifier interface additions

```csharp
// Level 5: Columns
Task<ColumnVerificationResult> CheckColumns(
    DbObject obj, string schema, string name,
    ExpectedColumn[] columns, CancellationToken ct = default);

// Level 6: Drift
Task<DriftResult> CheckDrift(
    DbObject obj, string schema, string name,
    ExpectedColumn[] columns, CancellationToken ct = default);
```

---

## File-level work breakdown

### Stream 0 — Foundation (main session, sequential)

**Owns:**

| File | Action | Notes |
|------|--------|-------|
| `TmsBridgeDbVerifier.sln` | **Create** | New solution with CLI, .Core, .Tests projects |
| `TmsBridgeDbVerifier.Core/TmsBridgeDbVerifier.Core.csproj` | **Create** | Class library, net9.0, Npgsql + Oracle deps |
| `TmsBridgeDbVerifier.Tests/TmsBridgeDbVerifier.Tests.csproj` | **Create** | MSTest project, references CLI project (pre-extraction) then .Core (post-extraction) |
| `TmsBridgeDbVerifier.Tests/Model/ObjectCheckResultTests.cs` | **Create** | Characterization: `Passed` logic for all status combinations |
| `TmsBridgeDbVerifier.Tests/Registry/DbObjectRegistryTests.cs` | **Create** | Characterization: deserialization of db-objects.json, object count, kind distribution |
| `TmsBridgeDbVerifier.Tests/Infrastructure/ProviderDetectorTests.cs` | **Create** | Characterization: PG/Oracle/invalid connection strings |
| `TmsBridgeDbVerifier.Tests/Infrastructure/SchemaResolverTests.cs` | **Create** | Characterization: tms→tenant, public→tenant (Oracle), case transforms |
| `TmsBridgeDbVerifier.Tests/Model/VerificationLevelTests.cs` | **Create** | Characterization: flag combinations, HasFlag behavior |
| `TmsBridgeDbVerifier/TmsBridgeDbVerifier.csproj` | **Modify** | Add `<ProjectReference>` to `.Core`, remove moved source files |
| All files in `Model/`, `Verification/`, `Registry/`, `Infrastructure/`, `Reporting/` | **Move** to `.Core` | Namespace rename `TmsBridgeDbVerifier.*` → `TmsBridgeDbVerifier.Core.*` |
| `TmsBridgeDbVerifier/Program.cs` | **Modify** | Slim to thin wrapper. `ParseLevel()` and `CreateVerifier()` move to `.Core`. |
| `TmsBridgeDbVerifier.Core/Model/ExpectedColumn.cs` | **Create** | `ExpectedColumn` record |
| `TmsBridgeDbVerifier.Core/Model/ColumnCheckResult.cs` | **Create** | `ColumnCheckResult`, `ColumnVerificationResult`, `DriftResult`, `ColumnStatus`, `ColumnCheckStatus` |
| `TmsBridgeDbVerifier.Core/Model/ObjectCheckResult.cs` | **Modify** | Convert from record to class, add `ColumnCheck`, `ColumnResult`, `DriftResult` properties, update `Passed` |
| `TmsBridgeDbVerifier.Core/Model/VerificationLevel.cs` | **Modify** | Add `Columns = 16`, `Drift = 32`, update `All = 63` |
| `TmsBridgeDbVerifier.Core/Model/DbObject.cs` | **Modify** | Add `ExpectedColumn[]? Columns` to base `DbObject` record (optional, defaults null) |
| `TmsBridgeDbVerifier.Core/Verification/IDbVerifier.cs` | **Modify** | Add `CheckColumns()` and `CheckDrift()` methods |
| `TmsBridgeDbVerifier.Core/Verification/VerificationRunner.cs` | **Create** | Orchestrator extracted from Program.cs lines 76-170 |
| `TmsBridgeDbVerifier.Core/Registry/DbObjectRegistry.cs` | **Modify** | Add `JsonColumn` class, deserialize `columns` array, map to `ExpectedColumn[]` on `DbObject` |
| `TmsBridgeDbVerifier.Core/Registry/JsonColumn.cs` | **Create** | Internal JSON deserialization class for column data |
| `TmsBridgeDbVerifier.Core/Verification/TypeCompatibility.cs` | **Create** | Static class with PostgreSQL and Oracle type alias maps + `IsCompatible()` |

**Constraints for Stream 0:**
- Characterization tests (M1) are written FIRST, before any file moves
- After .Core extraction (M2), update test `using` statements and verify all characterization tests pass
- After VerificationRunner extraction (M3), verify characterization tests still pass
- `ParseLevel()` moves to a `LevelParser` static class in `.Core` (not left in Program.cs)
- `CreateVerifier()` moves to `VerifierFactory` static class in `.Core`

**Must NOT touch:** `PostgreSqlVerifier.cs`, `OracleVerifier.cs` (owned by Stream A), `ConsoleReporter.cs` (owned by Stream B)

### Stream A — Column Verification (parallel agent, backend-expert)

**Owns:**

| File | Action | Notes |
|------|--------|-------|
| `TmsBridgeDbVerifier.Core/Verification/PostgreSqlVerifier.cs` | **Modify** | Add `CheckColumns()` and `CheckDrift()` implementations |
| `TmsBridgeDbVerifier.Core/Verification/OracleVerifier.cs` | **Modify** | Add `CheckColumns()` and `CheckDrift()` implementations |
| `TmsBridgeDbVerifier.Tests/Verification/TypeCompatibilityTests.cs` | **Create** | Test all alias map entries for both providers |
| `TmsBridgeDbVerifier.Tests/Verification/ColumnCheckTests.cs` | **Create** | Unit tests for CheckColumns scenarios (mock DB or test catalog responses) |
| `TmsBridgeDbVerifier.Tests/Verification/DriftCheckTests.cs` | **Create** | Unit tests for CheckDrift scenarios |

**Constraints for Stream A:**
- Column check implementation follows the two-stage pattern from the PRD: Stage A (catalog query) + Stage B (live SELECT probe)
- PostgreSQL catalog query: `SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = @schema AND table_name = @name`
- Oracle catalog query: `SELECT COLUMN_NAME, DATA_TYPE FROM ALL_TAB_COLUMNS WHERE OWNER = :owner AND TABLE_NAME = :name`
- PostgreSQL live probe: `SELECT {col1}, {col2}, ... FROM {schema}.{name} WHERE FALSE`
- Oracle live probe: `SELECT {COL1}, {COL2}, ... FROM {SCHEMA}.{NAME} WHERE 1=0`
- Column name comparison: case-sensitive for PostgreSQL, case-insensitive for Oracle
- Type comparison: use `TypeCompatibility.IsCompatible()` from Stream 0
- Drift query: same catalog queries, but comparing actual columns against expected (reverse direction)
- `PostgreSqlOnly` objects: return `ColumnCheckStatus.Skipped` for Oracle
- Objects with `Columns == null`: return `ColumnCheckStatus.NotConfigured`
- Must NOT touch: `Program.cs`, `ConsoleReporter.cs`, `JsonReporter.cs`, `VerificationRunner.cs`, any model files

### Stream B — CLI + Reporting (parallel agent, backend-expert)

**Owns:**

| File | Action | Notes |
|------|--------|-------|
| `TmsBridgeDbVerifier/Program.cs` | **Modify** | Add `--output json` option, update `ParseLevel` call to use `LevelParser`, delegate to `VerificationRunner` |
| `TmsBridgeDbVerifier.Core/Reporting/ConsoleReporter.cs` | **Modify** | Add `FormatColumns()`, `FormatDrift()` format methods, update `PrintSummary()` for Level 5/6, update `PrintGroup()` to show column/drift info, update `FormatLevels()` |
| `TmsBridgeDbVerifier.Core/Reporting/JsonReporter.cs` | **Create** | Serializes `VerificationResult` to JSON matching the schema in PRD M9 |
| `TmsBridgeDbVerifier.Core/Verification/VerificationResult.cs` | **Create** | Top-level result model: timestamp, database, schema, provider, level, duration, summary, objects list |
| `TmsBridgeDbVerifier.Tests/Reporting/JsonReporterTests.cs` | **Create** | Verify JSON output structure, validate with sample data |
| `TmsBridgeDbVerifier.Tests/Reporting/ConsoleReporterTests.cs` | **Create** | Verify new format methods produce expected output |

**Constraints for Stream B:**
- `--output json` flag: `new Option<string>("--output", "Output format: console (default), json", () => "console")`. When `json`: suppress all console output, write JSON to stdout, use `VerificationResult` model.
- `ParseLevel` updates: add `"5" or "columns"` and `"6" or "drift"` cases. Default `_` case remains `All` (now 63).
- `ConsoleReporter.PrintSummary()` adds Level 5 and Level 6 lines following the exact pattern of existing Level 1-4 lines. Level 5 shows `columns OK / missing / no data`. Level 6 shows `N objects with extra columns (advisory)`.
- `ConsoleReporter.FormatLevels()` adds `"5-Columns"` and `"6-Drift"` entries.
- JSON output must match PRD's M9 schema exactly (property names, nesting, types).
- Must NOT touch: `PostgreSqlVerifier.cs`, `OracleVerifier.cs`, model files, `IDbVerifier.cs`, `TypeCompatibility.cs`

---

## Code review gates

| Gate | After | Lenses | What to look for |
|------|-------|--------|------------------|
| **G1** | Stream 0 (Foundation) | Architectural + Clean-code (parallel) | Schema/contract correctness, namespace consistency, `Passed` logic integrity, record→class migration correctness, `ExpectedColumn` model completeness, characterization test coverage, `TypeCompatibility` map completeness |
| **G2a** | Stream A (Column verification) | Architectural + Clean-code (parallel) | SQL injection in catalog/probe queries (must use parameterized queries), Oracle schema resolution correctness (`OWNER` vs `TenantSchema`), case-sensitivity handling, error handling for connection failures mid-check, test coverage of both providers |
| **G2b** | Stream B (CLI + Reporting) | Clean-code + Architectural mini-pass | JSON serialization correctness, `ParseLevel` backward compatibility, console output formatting consistency with existing levels, stdout/stderr separation for JSON mode |
| **G3** | Integration | Architectural | Does the assembled feature work under: all-pass path, column-missing path, drift-only path, no-column-data path, connection-failure path? Cross-cutting behavior correctness. |

**Review handling:**
- Critical / High: fixed before next step, committed as `review-fix: <area>`
- Medium: fixed in next step if cheap, else logged in Deferred section below
- Low: logged only
- Contradiction with plan: stop and ask user

---

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Oracle type map has edge cases not covered (e.g., `LONG`, `RAW`, `BLOB` columns) | Medium | Low (type check reports warning, not failure) | Map covers the 9 types in the registry. Unknown types get `TypeCompatible = null` (inconclusive). Log and extend map in future. |
| Live SELECT probe times out on large views with complex joins | Low | Medium | Add `CancellationToken` with timeout to probe queries. Catch `OperationCanceledException`, report as `Error` with timeout message. |
| `information_schema.columns` returns different `data_type` values across PostgreSQL versions | Low | Low | The type alias map covers known variants. abn1034 runs PG 15 (AlloyDB). |
| Characterization tests are fragile (depend on exact db-objects.json content) | Medium | Low | Tests assert structural properties (count ranges, kind distribution, required fields) not exact values. |
| `ObjectCheckResult` record→class conversion breaks serialization or pattern matching | Medium | High | Characterization tests lock in `Passed` behavior. Review gate G1 specifically checks this. |
| Oracle stale catalog (column visible in `ALL_TAB_COLUMNS` but not actually usable) | Medium | Medium | Two-stage check: Stage A (catalog) + Stage B (live probe). If A passes but B fails, column is reported as `Error`. This is the design's primary value proposition. |

---

## Out of scope

- `FirestoreResultStore` (Phase 5 GCP host)
- `IResultStore` / `IResultQuery` / `FileResultStore` interfaces (deferred from S2/S3)
- `MarkdownReporter` (C1 — Phase 3 wiki)
- Cloud Function / Cloud Run host (Phase 5)
- Claude Code `/verify-databases` skill (Phase 2)
- Pipeline gate integration (Phase 4)
- Wiki publishing (Phase 3)
- CI automation for column registry updates
- Any changes to TMS Bridge source code
- Multi-schema parallel verification
- Column precision/scale checks (`numeric(18,2)` vs `numeric`)
- Alerting, dashboards, monitoring infrastructure
- Secret Manager integration

---

## Acceptance checklist

Derived from PRD Section 7 (Verification):

- [ ] **V1** — All characterization tests (M1) pass after .Core extraction and VerificationRunner extraction, with only `using` statement changes
- [ ] **V2** — CLI backward compatibility: run refactored CLI against abn1034 with `-l 4`. Output and exit code match pre-refactoring behavior
- [ ] **V3** — Level 5 column check catches missing columns: run with `-l 5` against abn1034. Any missing column → exit code 1, reported in output
- [ ] **V4** — Level 6 drift detection is advisory: run with `-l 6`. Extra columns appear as warnings, exit code remains 0 if all other levels pass
- [ ] **V5** — JSON output: run with `--output json -l 6`. Output is valid JSON, parseable by `jq`, matches the `VerificationResult` schema
- [ ] **V6** — Live SELECT probe: Level 5 runs both Stage A (catalog) and Stage B (SELECT WHERE FALSE). If Stage A passes but Stage B fails, column is reported as `Error`
- [ ] **V7** — Cross-provider: Level 5 and 6 work for PostgreSQL (case-sensitive name match) and Oracle (case-insensitive name match)
- [ ] **V8** — Type compatibility (S1+C2): PostgreSQL type alias map correctly resolves `text`↔`character varying`, `integer`↔`int4`, etc. Oracle type map correctly maps PostgreSQL types to Oracle equivalents (`text`→`VARCHAR2`, `bigint`→`NUMBER`, etc.)
- [ ] **V9** — Objects without column data: tables/views with no `columns` array in registry show `"⚠ no column data in registry"` warning
- [ ] **V10** — All new tests pass: `dotnet test TmsBridgeDbVerifier.sln`
- [ ] **V11** — No regression in existing `-l 4` behavior after all changes

---

## Execution order

1. **Phase 2:** Create branch `feature/003-db-verifier-core-column-checks`, commit this plan → wait for user go
2. **Stream 0 — Step 1:** Create `.sln` file
3. **Stream 0 — Step 2:** Create `.Tests` project, write characterization tests (M1)
4. **Stream 0 — Step 3:** Create `.Core` project, move files, rename namespaces (M2), update test `using` statements, verify tests pass
5. **Stream 0 — Step 4:** Extract `VerificationRunner` (M3), slim `Program.cs`, verify tests pass
6. **Stream 0 — Step 5:** Bridge column deserialization gap (`JsonColumn`, `ExpectedColumn`, `DbObject.Columns`, `DbObjectRegistry` updates)
7. **Stream 0 — Step 6:** Extend model + interface (M6, M7, M8) — `VerificationLevel` flags, `IDbVerifier` methods, `ObjectCheckResult` class conversion
8. **Stream 0 — Step 7:** Create `TypeCompatibility` class with both provider maps
9. **Review gate G1** — Architectural + Clean-code on Stream 0 → fix Critical/High
10. **Streams A + B in parallel** (single message, two agents):
    - Stream A: Implement `CheckColumns()` + `CheckDrift()` in PostgreSqlVerifier and OracleVerifier + tests
    - Stream B: `JsonReporter`, `--output json` flag, `ParseLevel` updates, `ConsoleReporter` column/drift output, `VerificationResult` model + tests
11. **Review gates G2a + G2b in parallel** — fix Critical/High
12. **Integration:** Wire VerificationRunner to call CheckColumns/CheckDrift in the verification loop, rebase if needed
13. **Review gate G3** — Architectural on integrated feature
14. **Smoke test:** Run against abn1034 with `-l 6` and `--output json -l 6`
15. **Full test suite:** `dotnet test TmsBridgeDbVerifier.sln`
16. **Report**

---

## Deferred findings

*(Empty — populated during review gates)*

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
