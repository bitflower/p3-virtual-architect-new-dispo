# Implementation Plan: PRD-002 TMS Bridge Column Registry

**Status:** Awaiting approval
**Branching:**
- Root repo (Virtual Architect): stays on `main` — agent definition + plan committed directly
- `Code/Disposition-Rollout-Tools`: branch `feature/column-registry` — db-objects.json changes
- `Code/Disposition-Abstraction-Layer`: **read-only** — no branch needed

**Worktrees:** No — sequential work
**Date:** 2026-06-11

---

## Decisions Locked In

| # | Question | Decision |
|---|---|---|
| 1 | Missing views in db-objects.json | Agent handles generically — any entity it discovers gets an entry. `v_dis_shipment` and `v_dis_to_tp_tour_number` gaps fixed as side effect. |
| 2 | S1 type inference priority | **Elevated to Must Have.** Only 1/627 columns has explicit `.HasColumnType()`. Without inference, `type` is null for 99.8% of columns. |
| 3 | Column name source | `.HasColumnName()` string literals are authoritative. Safety net: compare entity class property count vs `.HasColumnName()` call count; flag mismatches as convention-named (use C# property name). |
| 4 | Live DB access | psql to ABN 1034 (`tms1034` schema) available from this machine. |
| 5 | Multi-entity deduplication | UNION columns across all entity configurations that map to the same view/table. No "primary" concept. |
| 6 | Execution shape | Sequential single-stream. No worktrees, no parallel agents. |

---

## Architectural Notes That Bind the Implementation

### Source of truth: EntityConfiguration files

- **33 EntityConfiguration files** in `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/`
- Each contains a `Configure()` method with `builder.Property(e => e.X).HasColumnName("column_name")` calls
- **627 total `.HasColumnName()` calls** across all 33 files
- **1 total `.HasColumnType()` call** — in `TransportOrderPickupPlanningEntityConfiguration.cs:74` (`"timestamp without time zone"` for `u_time`)

### BranchDbContext column overrides: none exist

- `BranchDbContext.cs` has zero `HasColumnName`/`HasColumnType` calls
- Only `ToView()`/`ToTable()` overrides at the object level
- Agent must still check on each run (defensive), but framed as "verify none exist" not "extract overrides"

### Multi-entity → same view

| View | Entity configurations |
|---|---|
| `v_dis_to_filter` | `TransortOrderCutEntitytConfiguration` (note: typo in actual filename) |

The existing extractor already handles the object-level dedup (one db-objects.json entry per view/table). Column extraction must UNION columns from all entities mapping to the same view.

### Views missing from current db-objects.json

| View | Entity | Status |
|---|---|---|
| `v_dis_shipment` | `DISUnplannedShipmentEntityConfiguration` | Not in registry |
| `v_dis_to_tp_tour_number` | `TourNumberEntityConfiguration` | Not in registry |

These will be added naturally when the agent processes all 33 entities. The agent already has the logic to discover them (Step 1 of current pipeline).

### Backward compatibility

`DbObjectRegistry.cs` deserializes `db-objects.json` using `System.Text.Json` with `PropertyNameCaseInsensitive = true`. The `JsonDbObject` class has no `Columns` property. `System.Text.Json` silently ignores unknown JSON properties by default. Adding `"columns"` arrays to Table/View entries will NOT break deserialization.

Routines (Function, Procedure, TableFunction) and CustomType entries will NOT get `"columns"` — they remain unchanged.

### PRD file path corrections

All PRD file paths verified correct — no corrections needed.

---

## Schema: Extended db-objects.json

Each Table and View entry gains an optional `columns` array:

```json
{
  "kind": "View",
  "schema": "tms",
  "name": "v_dis_tp_client_comm",
  "permission": "SELECT",
  "columns": [
    { "name": "shipmentid", "type": "bigint", "inferredType": false },
    { "name": "trucklicenseplate", "type": "text", "inferredType": true },
    { "name": "comment_", "type": "text", "inferredType": true }
  ]
}
```

Column fields:

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Column name exactly as declared in `.HasColumnName("...")` — lowercase, no transformation |
| `type` | `string` | PostgreSQL type from `.HasColumnType("...")` if explicit, else inferred from C# property type |
| `inferredType` | `boolean` | `false` if `.HasColumnType()` was explicit, `true` if inferred from C# type |

### Type inference mapping (Must Have — elevated from S1)

| C# Type | PostgreSQL Type |
|---|---|
| `string` | `text` |
| `long` / `long?` | `bigint` |
| `int` / `int?` | `integer` |
| `short` / `short?` | `smallint` |
| `decimal` / `decimal?` | `numeric` |
| `double` / `double?` | `double precision` |
| `float` / `float?` | `real` |
| `bool` / `bool?` | `boolean` |
| `DateTime` / `DateTime?` | `timestamp with time zone` |
| `DateOnly` / `DateOnly?` | `date` |
| `TimeOnly` / `TimeOnly?` | `time without time zone` |
| `Guid` / `Guid?` | `uuid` |
| `byte[]` | `bytea` |
| (unknown) | `null` — flagged in report |

Exception: if `.HasColumnType()` overrides the inference (like `u_time` → `"timestamp without time zone"`), the explicit type wins and `inferredType` is `false`.

---

## File-Level Work Breakdown

### Single stream (sequential)

This is agent-definition-editing + data-generation work. No parallel streams apply.

**Files owned:**

| File | Change | New/Modified |
|---|---|---|
| `.claude/agents/tms-bridge-db-extractor.md` | Add column extraction pipeline step + type inference + dedup logic | Modified |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/Registry/db-objects.json` | Extended with `columns` arrays on all Table/View entries | Modified (generated) |

**Files read (not modified):**

| File/pattern | Purpose |
|---|---|
| `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/**/*EntityConfiguration.cs` | Extract `.HasColumnName()` / `.HasColumnType()` calls |
| `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/**/*Entity.cs` | Cross-reference property types for inference; property count for safety net |
| `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContext.cs` | Verify no column-level overrides |
| `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/Registry/DbObjectRegistry.cs` | Verify backward compatibility |

**Constraints:**
- Agent must NOT modify any TMS Bridge source code (PRD W4)
- Agent must NOT modify DbObjectRegistry.cs (backward compat only)
- Column names stored exactly as in `.HasColumnName()` — no case transformation (PRD M5)

---

## Code Review Gates

| After step | Lens | What to check |
|---|---|---|
| Step 1 (agent edit) | Architectural + Clean-code | Pipeline step correctness, type inference table completeness, dedup logic for multi-entity views, safety-net property-count check, clear instructions that won't confuse the agent |
| Step 2 (generated JSON) | Architectural | Schema correctness, completeness (every Table/View has columns), V2 spot-check (trucklicenseplate in v_dis_tp_client_comm), no columns on routines/custom types |
| Step 3 (validation) | Architectural | Live DB comparison results, type coverage report accuracy |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Agent misparses `.HasColumnName()` across multi-line chains | Missing columns in registry | Agent instructions include explicit pattern examples including multi-line fluent API chains |
| C# type inference produces wrong PostgreSQL type | Phase 1 verification uses wrong expected type | `inferredType: true` flag lets Phase 1 treat inferred types as advisory, not authoritative |
| Entity class has property without `.HasColumnName()` (convention-based) | Column silently missing from registry | Safety net: compare property count in entity class vs `.HasColumnName()` count; flag mismatches |
| Multiple entities map to same view with conflicting column names | Duplicate/conflicting columns in registry entry | UNION with dedup by column name; if two entities declare same column name with different types, flag as conflict |
| `db-objects.json` becomes too large after adding ~627 columns | Slower deserialization, harder to read | Acceptable — JSON is machine-consumed. Type coverage summary produced separately for human consumption |
| ABN 1034 schema drift since last deployment | Live validation shows false-positive "missing" columns | Compare against the AlloyDB schema SQL files as a second source of truth |

---

## Out of Scope

- Modifying `DbObjectRegistry.cs` to consume the `columns` field (Phase 1 work)
- Column extraction for routines/procedures (PRD W5)
- CI automation for registry sync (PRD W1)
- Nullable/precision metadata beyond basic data type (PRD W2)
- Any GCP infrastructure, Cloud Functions, dashboards
- Any wiki publishing
- Any TMS Bridge source code changes

---

## Acceptance Checklist

Derived from PRD Verification section:

- [ ] **V1 — Completeness:** Every Table and View entry in `db-objects.json` has a non-empty `columns` array
- [ ] **V2 — Accuracy:** `v_dis_tp_client_comm` contains all 88 columns including `trucklicenseplate`
- [ ] **V3 — Live validation:** Registry columns validated against ABN 1034 `information_schema.columns`. Zero missing columns (registry columns not found in DB). Extra columns are advisory. Case-sensitive comparison for PostgreSQL.
- [ ] **V4 — Type coverage:** Summary table showing explicit `.HasColumnType()` vs inferred type counts per entity. Expected: ~1 explicit, ~626 inferred.
- [ ] **V5 — Backward compatibility:** Extended `db-objects.json` loads through `DbObjectRegistry.cs` without error. Entries without `columns` (routines, custom types) unaffected.
- [ ] **V6 — Safety net:** Agent reports property-count vs `.HasColumnName()-count` comparison per entity. Any mismatches flagged and resolved.
- [ ] **V7 — Multi-entity dedup:** Views with multiple entity configurations have UNION of columns, no duplicates.
- [ ] **V8 — Case-sensitivity contract:** Documented in db-objects.json schema or companion README — column names stored as-declared (lowercase), PostgreSQL comparison case-sensitive, Oracle comparison case-insensitive.

---

## Execution Order

1. **Root repo (main):** Commit plan + agent definition changes directly to `main`
2. **Rollout-Tools repo:** Create branch `feature/column-registry` in `Code/Disposition-Rollout-Tools`
3. **Step 1 — Edit agent definition:** Add column extraction step to `tms-bridge-db-extractor.md`
   - Add new pipeline step between existing Steps 1 and 2
   - Include: `.HasColumnName()` extraction, `.HasColumnType()` extraction, C# type inference, property-count safety net, multi-entity UNION dedup, BranchDbContext column override check
   - Update Step 10 (output assembly) to include `columns` arrays in JSON output format
4. **Review gate 1:** Architecture + clean-code review of agent definition changes
5. **Step 2 — Run agent:** Execute extended `tms-bridge-db-extractor` agent against TMS Bridge source
   - Agent produces extended `db-objects.json`
   - Spot-check: V1 (completeness), V2 (trucklicenseplate), V7 (multi-entity dedup)
6. **Review gate 2:** Architecture review of generated JSON
7. **Step 3 — Live validation:** Query ABN 1034 `information_schema.columns` via psql, compare against registry
   - Produce validation report (V3)
   - Produce type coverage summary (V4)
   - Verify backward compatibility (V5)
   - Document case-sensitivity contract (V8)
8. **Review gate 3:** Final review of validation results
9. **Commit:** Agent definition on `main` (root repo), db-objects.json on `feature/column-registry` (Rollout-Tools)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
