# PRD-002: TMS Bridge Column Registry

**Feature ID:** 002_TMS_Bridge_Column_Registry
**Date:** 2026-06-11
**Status:** Draft

---

## 1. Problem

The TMS Bridge DB Verifier checks 77 database objects across Oracle and PostgreSQL but has no column-level verification. Objects can pass all 4 verification levels (existence, type, signature, permissions) while missing critical columns — a gap that caused **BUG-124918**: view `v_dis_tp_client_comm` existed with correct type and permissions, but lacked column `trucklicenseplate`. The TMS Bridge crashed at runtime with `42703: column does not exist`.

The root cause: there is no machine-readable registry of which columns each table/view must have. The `tms-bridge-db-extractor` agent extracts object names and types but not column definitions. Without a column registry, the Phase 1 Level 3 column verification (separate PRD) has nothing to verify against.

**Evidence from prior art:**

- ABN1060 Oracle Review: manual tester found `U_TIME` missing from `V_DIS_TO_PICKUPPLANNING` — automated verifier could not detect it (`02_Explorations/2026-05-11_ABN1060_Oracle_TMS_Database_Review_-_First_Batch_Analysis/`)
- ABN1060 Oracle Review: `Comment` (mixed case) in `V_DIS_TRANSPORTORDER` instead of `COMMENT` — queries failed because Oracle catalog expected uppercase. Separately, the column `comment` had to be renamed to `comment_` to avoid Oracle reserved word conflict (Issue 173645, commit `41881163`). Both incidents demonstrate that column name casing is a first-class verification concern. (`02_Explorations/2026-05-11_ABN1060_Oracle_TMS_Database_Review_-_First_Batch_Analysis/`)
- DB Access Test Automation: explicitly lists "column definitions not checked" as a known limitation (`02_Explorations/2026-05-07_TMS_Bridge_DB_Access_Test_Automation/`)
- DB Object Inventory: 7 views renamed in release/7.0.0.8 — demonstrates schema drift the verifier must track (`02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/`)

## 2. Direction Alignment

No direction/strategy documents configured. This PRD is grounded in the exploration at `02_Explorations/2026-06-11_Advanced_TMS_Verifier_-_Continuous_Database_Monitoring_Service_in_GCP/` which identifies the column registry as "Phase 0 — the foundation for everything else." It is a prerequisite for the 6-level verification model described there.

**Conscious scope reduction:** The exploration describes 6 phases (registry -> core library -> Claude Code skill -> wiki -> pipeline gate -> GCP host). This PRD covers Phase 0 only — the column registry. Phase 1 (core library + Level 3/6 verification) will be a separate PRD that consumes this registry.

## 3. Requirements (MoSCoW)

### Must Have

- **M1:** Extend the `tms-bridge-db-extractor` agent to extract `.HasColumnName()` calls from all `*EntityConfiguration.cs` files in `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/`
- **M2:** Extend the agent to extract `.HasColumnType()` calls where explicitly present; record `null` where absent (EF-inferred type)
- **M3:** Check `BranchDbContext.cs` for column-level overrides — DbContext wins over EntityConfiguration (per existing extractor convention)
- **M4:** Extend `db-objects.json` with a `columns` array on each Table and View entry, structured as:
  ```json
  {
    "kind": "View", "schema": "tms", "name": "v_dis_tp_client_comm", "permission": "SELECT",
    "columns": [
      { "name": "shipmentid", "type": "bigint" },
      { "name": "trucklicenseplate", "type": null },
      { "name": "comment_", "type": "character varying" }
    ]
  }
  ```
- **M5:** Column names must be extracted exactly as declared in `.HasColumnName("...")` — no case transformation
- **M6:** Validate the generated registry against ABN 1034 (AlloyDB/PostgreSQL) by running a `SELECT column_name FROM information_schema.columns` query per table/view and comparing:
  - Every column in the registry exists in the live database
  - Every column in the live database is accounted for in the registry (advisory — flag extras, don't fail)
- **M7:** Report validation results: count of matched columns, missing columns (in registry but not in DB), extra columns (in DB but not in registry), columns with `null` type (no explicit `.HasColumnType()`)
- **M8:** Record the case-sensitivity contract in the registry: column names are stored as declared in `.HasColumnName()` (lowercase). Downstream consumers must compare case-insensitively against Oracle catalogs (`ALL_TAB_COLUMNS` stores uppercase) and case-sensitively against PostgreSQL catalogs (`information_schema.columns` stores exact case). Document this contract in the `db-objects.json` schema or a companion README in the Registry folder.

### Should Have

- **S1:** For columns with `null` type, attempt to infer the PostgreSQL type from the C# property type using EF Core conventions (e.g., `string` -> `text`, `long` -> `bigint`, `decimal` -> `numeric`) and record as `inferredType` alongside `type: null`
- **S2:** Produce a summary table showing `.HasColumnType()` coverage per entity (e.g., "TourpointClientCommunicationEntity: 45/88 columns have explicit types") to quantify the gap

### Could Have

- **C1:** Cross-validate the registry against a second database (ABN 1060 Oracle) to confirm dual-provider applicability
- **C2:** Detect column name patterns that differ between Oracle and PostgreSQL (uppercase vs lowercase catalog representation)

### Won't Have

- **W1:** CI automation for keeping the registry in sync on TMS Bridge PRs — deferred per exploration decision D5 ("agent on demand first, CI auto-generation later")
- **W2:** Nullable/precision metadata beyond basic data type
- **W3:** Column verification logic (Level 3/6 checks) — that is Phase 1, separate PRD
- **W4:** Any changes to the TMS Bridge source code itself
- **W5:** Routine parameter column extraction (functions/procedures) — only tables and views

## 4. Out of Scope

- Modifying the existing 4-level verification logic in `TmsBridgeDbVerifier`
- Building any GCP infrastructure (Cloud Functions, Firestore, dashboards)
- Creating a Claude Code skill (`/verify-databases`)
- Pipeline gate integration
- Any wiki publishing

## 5. Implementation Approach (unverified hint)

The `tms-bridge-db-extractor` agent (`.claude/agents/tms-bridge-db-extractor.md`) already has a 10-step extraction pipeline that finds all EntityConfiguration files, maps `ToView()`/`ToTable()` to DB objects, and resolves schemas. The column extraction extends this pipeline:

**Extraction logic (new step between current Steps 1 and 2):**

1. For each EntityConfiguration class already identified in Step 1, scan the `Configure()` method body for:
   - `builder.Property(e => e.X).HasColumnName("column_name")` -> extract column name
   - `.HasColumnType("type_name")` -> extract type (may be absent)
2. Cross-reference with the entity's C# class to enumerate all mapped properties (some may use convention-based naming without explicit `.HasColumnName()`)
3. For BranchDbContext overrides (Step 1 Source B), check for property-level column mappings that override EntityConfiguration

**Output:** Extended `db-objects.json` with `columns` arrays on Table/View entries.

**Validation:** Run `psql` against ABN 1034 with `information_schema.columns` queries, compare output to registry using a simple diff script or inline in the agent.

## 6. Files Likely to Change

| File | Change | New/Modified |
|---|---|---|
| `.claude/agents/tms-bridge-db-extractor.md` | Add column extraction step to pipeline | Modified |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/Registry/db-objects.json` | Add `columns` arrays to all Table/View entries | Modified |

## 7. Verification

- **V1 — Completeness:** Run the extended extractor against the TMS Bridge source. Every Table and View entry in `db-objects.json` must have a non-empty `columns` array.
- **V2 — Accuracy:** For `v_dis_tp_client_comm` specifically, confirm the registry contains all 88 columns including `trucklicenseplate` — the BUG-124918 column.
- **V3 — Live validation:** Run the registry against ABN 1034 (`tms1034` schema). Zero missing columns (registry columns not found in DB). Extra columns are advisory, not failures. Column name comparison must be case-sensitive (PostgreSQL stores exact case). If C1 (Oracle cross-validation) is performed, comparison must be case-insensitive (Oracle uppercases all names in `ALL_TAB_COLUMNS`).
- **V4 — Type coverage report:** Produce a summary showing how many columns have explicit `.HasColumnType()` vs `null`. This quantifies the gap for Phase 1 to address.
- **V5 — Backward compatibility:** The extended `db-objects.json` must still be loadable by the existing `DbObjectRegistry.cs` in the verifier — entries without `columns` (routines, custom types) must not break deserialization.

## 8. Related

### Prior Art

- `02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/` — 77-object baseline, EntityConfiguration -> DB object mapping
- `02_Explorations/2026-05-07_TMS_Bridge_DB_Access_Test_Automation/` — verifier design, "column definitions not checked" gap
- `02_Explorations/2026-05-11_ABN1060_Oracle_TMS_Database_Review_-_First_Batch_Analysis/` — column-level issues found manually (`U_TIME`, `Comment` casing, `comment_` rename)
- `02_Explorations/2026-06-11_Advanced_TMS_Verifier_-_Continuous_Database_Monitoring_Service_in_GCP/` — parent exploration defining the 6-phase plan
- `20_Bug-Analysis/2026-05-28_BUG-124918_Email-Cannot-Be-Sent.md` — the incident that exposed the column verification gap

### Downstream

- **Phase 1 PRD (next):** Core Library + Level 3/6 Verification — consumes `db-objects.json` with columns to perform column existence and drift checks
- **ADR-004:** TMS Bridge Database Identifier — schema resolution patterns used by the verifier
- **ADR-009:** TMS Bridge Credential Isolation — connection string patterns

### Existing Artifacts

- `.claude/agents/tms-bridge-db-extractor.md` — agent to extend
- `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/Registry/db-objects.json` — file to extend
- `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/Registry/DbObjectRegistry.cs` — must remain compatible

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
