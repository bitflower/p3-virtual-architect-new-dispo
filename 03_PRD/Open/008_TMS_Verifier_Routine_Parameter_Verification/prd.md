# PRD-008: TMS Verifier — Routine Parameter Verification

**Status:** Draft
**Date:** 2026-06-22

---

## Problem

The TMS Verifier checks routine signatures by comparing argument **count** only. It does not verify parameter **names** or **types**. This misses real drift — e.g., the TMS Bridge code calls `setparticipant` with a parameter named `p_mode`, while the PostgreSQL procedure defines it as `nMode`. The call works at runtime (positional binding) but the mismatch is invisible.

Tables and views already have column-level verification (L5: name existence, type compatibility). Routines lack the equivalent.

## Proposal

Add parameter-level verification for routines (procedures, functions, table functions) — checking name, type, and direction (IN/OUT/INOUT) of each parameter against a registry derived from the TMS Bridge source code.

## Registry Change

Extend `db-objects.json` routine entries with an `expectedParams` array, analogous to `columns` on views:

```json
{
  "kind": "Procedure",
  "schema": "pdis_transportorder",
  "name": "setparticipant",
  "permission": "EXECUTE",
  "expectedArgs": 11,
  "expectedParams": [
    { "name": "transportorderid", "type": "numeric", "direction": "IN" },
    { "name": "participanttype", "type": "varchar", "direction": "IN" },
    { "name": "personid", "type": "numeric", "direction": "IN" },
    { "name": "name", "type": "varchar", "direction": "IN" },
    { "name": "country", "type": "varchar", "direction": "IN" },
    { "name": "zipcode", "type": "varchar", "direction": "IN" },
    { "name": "city", "type": "varchar", "direction": "IN" },
    { "name": "district", "type": "varchar", "direction": "IN" },
    { "name": "street", "type": "varchar", "direction": "IN" },
    { "name": "email", "type": "varchar", "direction": "IN" },
    { "name": "p_mode", "type": "numeric", "direction": "IN" }
  ]
}
```

## Data Sources

### Extractor (TMS Bridge code → registry)

- Parameter **name**: first argument of `.AddInput("name", ...)` / `.AddOutput("name", ...)` / `.AddPlsqlBooleanOutput("name")`
- Parameter **direction**: `AddInput` → IN, `AddOutput` / `AddPlsqlBooleanOutput` → OUT
- Parameter **type**: inferred from the C# value type or explicit cast (same inference rules as column type extraction)

### PostgreSQL catalog

- `pg_proc.proargnames` — parameter name array
- `pg_proc.proallargtypes` — type OID array (resolve via `pg_type.typname`)
- `pg_proc.proargmodes` — direction array (`i`=IN, `o`=OUT, `b`=INOUT)

### Oracle catalog

- `ALL_ARGUMENTS` — columns: `ARGUMENT_NAME`, `DATA_TYPE`, `IN_OUT`, `POSITION`, `OVERLOAD`

## Verification Checks

For each routine with `expectedParams` defined:

1. **Name match**: does a parameter with this name exist in the matching overload? (case-insensitive)
2. **Type compatibility**: same `TypeCompatibility.IsCompatible()` logic already used for columns
3. **Direction match**: IN/OUT/INOUT matches expected direction
4. **Overload selection**: when multiple overloads exist, match against the overload whose parameter names best overlap with `expectedParams`

## Overload Matching

Both Oracle (packages) and PostgreSQL support routine overloading. The verifier must select the correct overload before checking parameters. Strategy: pick the overload with the highest parameter name overlap against `expectedParams`.

## Test Coverage

The overload-aware signature matching (prerequisite, shipped 2026-06-22) has no unit tests. Add tests for:

- Single overload — match and mismatch
- Multiple overloads — correct one matches, none match (report closest)
- No overloads found — returns Skipped
- `expectedArgs` is null — returns NotChecked with max overload count
- Oracle `OVERLOAD` grouping — args counted per overload, not summed across all

These require either mock-based tests with injected query results or an in-memory DB. Prefer the former to keep tests fast.

## Out of Scope

- Parameter default values
- Parameter ordering verification (positional binding means order matters at runtime, but verifying order requires more context than catalog queries provide on Oracle)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
