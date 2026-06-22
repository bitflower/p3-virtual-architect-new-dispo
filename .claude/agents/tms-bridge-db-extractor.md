---
name: tms-bridge-db-extractor
description: Extract all TMS database objects and their column definitions referenced by the TMS Bridge from C# source code
tools: [Read, Glob, Grep]
---

# TMS Bridge Database Object Extractor

Extract a complete, classified inventory of all TMS database objects accessed by `CALConsult.TMSBridge.API` directly from source code, including column-level metadata for tables and views. Produces a structured markdown document suitable for wiki publication and a JSON registry (`db-objects.json`) with column definitions for machine consumption.

## Codebase Root

`Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/`
Tests: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API.Tests/`

## Extraction Pipeline

Execute all steps in order. Steps 1-9 extract database objects and column metadata. Step 10 resolves schemas. Step 11 assembles output.

---

### Step 1: Collect all EF mappings

Collect every `ToView()` and `ToTable()` call from two sources. The DbContext is the final authority — if it overrides an entity configuration, the DbContext value wins.

**Source A — Entity configurations:**
```
Files: Data/Entities/**/EntityConfiguration.cs
Patterns: builder.ToView("...", ...) and builder.ToTable("...", ...)
```

**Source B — BranchDbContext overrides:**
```
File: Data/DbContexts/BranchDbContext.cs
Patterns: .ToView("...") and .ToTable("...")
```

For each entity, record:
- DB object name (string argument)
- Schema (second argument if present, otherwise infer — see Step 10)
- Entity type (from `modelBuilder.Entity<T>()` or the configuration class)
- EF mapping directive (`ToView` or `ToTable`)
- Whether the entity has a `DbSet<T>` property (entities without → "navigation-only")

Cross-reference: if an entity has a mapping in both its configuration AND BranchDbContext, the DbContext value wins.

---

### Step 2: Extract Column Definitions

For each entity discovered in Step 1, extract column-level metadata from its EntityConfiguration file and the corresponding entity class.

**2a. Identify the entity class for each EntityConfiguration:**

Each EntityConfiguration implements `IEntityTypeConfiguration<TEntity>`. Extract `TEntity` to locate the entity class file.
```
Pattern: class *EntityConfiguration : IEntityTypeConfiguration<TEntity>
Entity class file: Data/Entities/**/{TEntity}.cs
```

If the file is not found at the expected path, grep for `public class {TEntity}` or `public partial class {TEntity}` across all `Data/Entities/**/*.cs` files.

**2b. Extract column names from EntityConfiguration files:**
```
Files: Data/Entities/**/*EntityConfiguration.cs
Pattern: builder.Property(e => e.{PropertyName}).HasColumnName("{column_name}")
Optional chain: .HasColumnType("{pg_type}")
```

Handle multi-line fluent API chains — `.HasColumnName()` and `.HasColumnType()` may appear on separate lines:
```csharp
builder.Property(e => e.SomeProperty)
    .HasColumnName("some_column")
    .HasColumnType("timestamp without time zone");
```

For each `.HasColumnName()` call, record:
- **Column name:** string argument to `.HasColumnName("...")`
- **Explicit PostgreSQL type:** string argument to `.HasColumnType("...")` if chained on the same property (rare — very few instances across the codebase)
- **C# property name:** `{PropertyName}` from `e => e.{PropertyName}`

Only extract columns where `.HasColumnName()` is explicitly called. Properties configured via `builder.Property(...)` without `.HasColumnName()` use EF convention naming and are excluded from the column list.

**2c. Resolve column types via C# type inference:**

Look up each C# property's type in the entity class and map to PostgreSQL:

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
| (unknown) | `null` — flag in report |

**Type resolution priority:** If `.HasColumnType()` is present, use its explicit value and set `inferredType: false`. Otherwise, infer from the C# property type and set `inferredType: true`. If the C# type has no mapping entry, set `type` to `null` and flag in report.

**Value conversions:** If `.HasConversion<T>()` or `.HasConversion(...)` is chained on the property, the stored database type may differ from the C# property type. Flag these as `type: null` with `inferredType: true` and note the conversion in the report for manual review.

**2d. BranchDbContext column override check:**
```
File: Data/DbContexts/BranchDbContext.cs
Patterns: .HasColumnName("...") and .HasColumnType("...")
```
Verify no column-level overrides exist in BranchDbContext. Currently none are expected — this is a defensive check. If any are found, they take priority over EntityConfiguration values (same override principle as `ToView`/`ToTable` in Step 1). Replace the corresponding EntityConfiguration column values (name and/or type) and log each override in the report.

**2e. Property-count safety net:**

For each entity, compare:
- Total public settable properties in the entity class (`public {Type} {Name} { get; set; }`)
- Count of `.HasColumnName()` calls in its EntityConfiguration

If counts differ, report the mismatch:
- Entity name
- Entity class property count
- `.HasColumnName()` call count
- Delta and list of unmatched property names

Properties without `.HasColumnName()` may be navigation properties (relationships to other entities) or convention-named columns. The `.HasColumnName()` calls are authoritative — only explicitly mapped columns appear in the output. Flag mismatches for review but do not add unmapped properties to the column list.

**2f. Multi-entity UNION dedup:**

When multiple EntityConfigurations map to the same database object (from Step 1 cross-reference):
1. Collect columns from ALL entity configurations for that object
2. UNION by column name (case-sensitive match)
3. Same column name + same type → deduplicate (keep one)
4. Same column name + different types → flag as **CONFLICT** in report, keep both types noted
5. No "primary" entity concept — all configurations contribute equally

**Output per database object:**
For each Table/View from Step 1, record an ordered list of columns: `{ name, type, inferredType }` ordered by the sequence of `builder.Property(...)` calls as they appear top-to-bottom in the EntityConfiguration file. For multi-entity views, columns from the first configuration (alphabetical by filename) appear first, then additional columns from subsequent configurations.

---

### Step 3: Classify by actual database object type

**Classification principle:** Objects are classified by their **actual database type** (TABLE or VIEW), not by the EF Core mapping directive. `ToView()` means "treat as read-only" — it does NOT imply the database object is a view. `ToTable()` means "treat as writable" — it does NOT guarantee the object is a table if overridden.

**Cross-reference against TMS database schema:**
```
Tables: Code/tms-alloydb-schema/src/sql/table/{name}.sql
Views:  Code/tms-alloydb-schema/src/sql/view/{name}.sql
Also:   Code/tms-alloydb-schema/src/sql/scripts/view/all_create_views.sql
        Code/tms-alloydb-schema/src/sql/scripts/table/all_create_tms_tables.sql
```

For each `ToView()` target:
1. Check if a file exists at `src/sql/view/{name}.sql` → actual VIEW
2. Check if a file exists at `src/sql/table/{name}.sql` → actual TABLE mapped read-only via `ToView`
3. If found in both or neither, flag for manual review

**Output classification:**

| EF Directive | DB Object Type | Classification | Section |
|---|---|---|---|
| `ToTable` (no override) | TABLE | TABLE | Section 1 |
| `ToView` | VIEW | VIEW | Section 2 |
| `ToView` | TABLE | TABLE (read-only via `ToView`) | Section 1 |
| `ToTable` → DbContext `ToView` | VIEW | VIEW | Section 2 |

For tables classified from `ToView`, add an `EF Mapping` column showing `ToView` and note in the remarks that the object is a database table accessed read-only.

---

### Step 4: Extract Stored Procedures

**Search pattern:**
```
Files: GraphQL/Mutations/**/*.cs, Services/**/*.cs
Pattern: OperationType.Procedure
```

For each match, extract:
- **Routine name:** from `RoutineName = "..."` or `.RoutineName("...")` in the surrounding RoutineDto/builder
- **Schema:** from the routine name if qualified (e.g., `disp_mde_ah.scanbarcode`), or from the folder/namespace convention
- **GraphQL entry point:** the mutation class name (from the `[ExtendObjectType(typeof(Mutation))]` class)
- **Access:** always WRITE for procedures
- **expectedArgs:** count ALL parameter builder calls in the same method that builds the RoutineDto. Count each `.AddInput(...)`, `.AddOutput(...)`, and `.AddPlsqlBooleanOutput(...)` call as one argument. The total is the expectedArgs value. This counts IN + OUT args, matching Oracle's `ALL_ARGUMENTS` and PostgreSQL's `proallargtypes`.

**Also check Startup.cs** for procedure-related registrations to ensure completeness.

---

### Step 5: Extract Functions

**Search pattern:**
```
Files: GraphQL/Mutations/**/*.cs, GraphQL/Queries/**/*.cs, Services/**/*.cs
Pattern: OperationType.Function
```

Extract same fields as Step 4 (including **expectedArgs** — same counting rule). Additionally:
- **Access classification:** If the function is called from a Query class or is a pure getter (name starts with `get`), classify as READ. If called from a Mutation class and the name starts with `set`, `create`, `add`, `remove`, classify as WRITE.
- **Do not rely on naming alone** — check the actual call site context.

**Also search for DbFunction attributes:**
```
Pattern: [DbFunction(...)]  or  HasDbFunction(...)
```
These are EF-mapped functions called differently from IRoutineExecutor functions.

---

### Step 6: Extract Table Functions (Oracle-only)

**Search pattern:**
```
Files: GraphQL/Mutations/**/*.cs, Services/**/*.cs
Pattern: OperationType.Table
```

These generate `SELECT * FROM TABLE(schema.function(...))` via `OracleTableBuilder`. Flag as TABLE FUNCTION type. Always READ access. Include **expectedArgs** (same counting rule as Step 4).

---

### Step 7: Extract Custom Types

**Search pattern:**
```
File: Data/DbContexts/BranchDbContext.cs
Pattern: HasPostgresEnum<T>("schema", "typename")
```

Extract:
- Type name
- Schema
- C# enum type (the `<T>` generic parameter)

Then find the enum definition to extract values:
```
Files: Data/Entities/DbTypes/*.cs
Pattern: public enum {T} { ... }
```

Find usage sites by grepping for the enum type name in mutation input DTOs and AddInput calls.

---

### Step 8: Detect Implicit Call Chains

Some database calls are triggered indirectly — not from a GraphQL mutation/query directly, but from resolver classes or middleware.

**Search pattern:**
```
Files: Services/Resolvers/**/*.cs, Infrastructure/**/*.cs
Pattern: IRoutineExecutor or ExecuteRoutineAsync
```

For each match, trace back to understand:
- Which GraphQL field triggers this resolver
- Which DB routines it calls
- Whether the chain is conditional (e.g., only when a specific field is requested)

**Known pattern:** `PstHstMetaDataResolver` chains `cal_uniface.item` → `cal_uniface.list2dbtt` when `decodedMetaData` field is queried.

---

### Step 9: Detect Obsolete/Inactive Entries

**Search pattern:**
```
File: Startup.cs (or Program.cs)
Pattern: commented-out AddTypeExtension lines, or mutations/queries not registered
```

Cross-reference: every mutation/query class found in Steps 4-6 should have a registration in Startup. If a class exists but is not registered (or is commented out), flag it as **obsolete**.

---

### Step 10: Schema Resolution

For each extracted object, determine the schema:

1. **Routine schemas** — extracted from qualified routine names (e.g., `pdis_transportorder.addtourpoint` → schema `pdis_transportorder`)
2. **View/table schemas** — from the second argument to `ToView`/`ToTable`:
   - If a `tmsSchema` or `schema` constructor parameter is passed → **tms** (tenant schema)
   - If no schema argument and configured in BranchDbContext directly → **public**
3. **Enum schemas** — from `HasPostgresEnum` first argument

---

### Step 11: Assemble Output

Produce two outputs: a markdown document and a JSON registry.

**Markdown Document:**

```markdown
# TMS Bridge: Database Objects

**Date:** {today}
**TMS Database Version:** {from git - branch name and short commit hash}

---

## Schema Convention
{list all schemas found with descriptions}

## 1. Tables ({count})
{table with columns: #, Object Name, Type, Schema, EF Mapping, Access, Required Permission}
{Include classification principle note. For entries where EF Mapping = ToView, show Access as "READ (read-only)"}

## 2. Views ({count})
### 2a. Disposition Views
### 2b. EBV Views
### 2c. Sendung Views
{tables with columns: #, Object Name, Type, Schema, Access, Required Permission, Notes}

## 3. Functions ({count})
{table with columns: #, Object Name, Type, Schema, Access, Required Permission, Called By}
{notes about implicit chains}

## 4. Stored Procedures ({count})
### 4a-e. Grouped by schema
{tables with columns: #, Object Name, Type, Schema, Access, Required Permission, Called By}

## 5. Custom Types ({count})
{table with columns: #, Object Name, Type, Schema, Required Permission, Values, Notes}

## Summary: Permission Scope
### By Access Pattern
### By Schema

## View Rename Reference
{only if renamed views detected — compare view SQL filenames vs ToView strings}

## Version History
{append new row with version bump}
```

**Categorize views** into DIS/EBV/Sendung/Other based on name prefix:
- `v_dis_*` → Disposition
- `v_ebv_*` → EBV
- `v_sen_*` or `sen_*` → Sendung
- `v_pers_*` or other → Other

**Permission mapping:**
- Tables/Views → SELECT
- Functions/Procedures/Table Functions → EXECUTE
- Custom Types → USAGE

**JSON Registry Output (`db-objects.json`):**

In addition to the markdown document, produce a complete `db-objects.json` array. Each Table and View entry includes a `columns` array from Step 2. Routines (Function, Procedure, TableFunction) and CustomType entries do NOT get `columns`.

Entry format for Tables and Views:
```json
{
  "kind": "View",
  "schema": "tms",
  "name": "v_dis_tp_client_comm",
  "permission": "SELECT",
  "columns": [
    { "name": "shipmentid", "type": "bigint", "inferredType": false },
    { "name": "trucklicenseplate", "type": "text", "inferredType": true }
  ]
}
```

Entry format for routines (no `columns`, but includes `expectedArgs`):
```json
{
  "kind": "Procedure",
  "schema": "pdis_transportorder",
  "name": "addtourpoint",
  "permission": "EXECUTE",
  "expectedArgs": 21
}
```

`expectedArgs` = total count of `.AddInput()` + `.AddOutput()` + `.AddPlsqlBooleanOutput()` calls for that routine. This counts all parameter directions (IN + OUT), matching how both Oracle (`ALL_ARGUMENTS`) and PostgreSQL (`proallargtypes`) report arg counts. For `DbFunction`-attributed functions that don't use `RoutineParameterBuilder`, count the C# method parameters (excluding the `this` parameter if it's an extension method).

Entry format for custom types (no `columns`, no `expectedArgs`):
```json
{
  "kind": "CustomType",
  "schema": "pdis_transportorder",
  "name": "legtype",
  "permission": "USAGE"
}
```

Column fields:

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Column name exactly as in `.HasColumnName("...")` — no case transformation |
| `type` | `string` or `null` | PostgreSQL type: explicit from `.HasColumnType()` or inferred from C# type. `null` if type unmappable |
| `inferredType` | `boolean` | `false` if `.HasColumnType()` was explicit, `true` if inferred from C# type |

Column ordering: as defined in Step 2f (top-to-bottom `builder.Property(...)` call order; multi-entity views sorted alphabetically by filename).

---

## Quality Checks (run before output)

1. **Completeness:** Count of mutations in Startup.cs registrations must match count of distinct routine names extracted
2. **No duplicates:** Each object name appears exactly once across all sections
3. **Schema coverage:** Every object has a schema assigned
4. **Access classification:** Every object has READ or WRITE
5. **Cross-reference DbSets:** Every `DbSet<T>` in BranchDbContext should map to exactly one table or view
6. **Rename detection:** Compare `ToView`/`ToTable` strings against SQL file names in `Code/tms-alloydb-schema/src/sql/view/` and `Code/tms-alloydb-schema/src/sql/scripts/` to detect name mismatches (potential pending renames)
7. **Column completeness:** Every Table and View entry in the JSON registry has a non-empty `columns` array
8. **Column dedup:** No duplicate column names within a single database object entry
9. **Type coverage:** Report count of explicit `.HasColumnType()` vs inferred types vs `null` types across all columns (expected: very few explicit, several hundred inferred)
10. **Property-count safety net:** Report all entity property-count vs `.HasColumnName()`-count mismatches with entity names and deltas

---

## Known Pitfalls (from 2026-04-29 analysis)

These were real errors made during manual extraction. The agent must avoid them:

| Pitfall | How to Avoid |
|---------|-------------|
| Counting entities with `ToTable` as tables when DbContext overrides to `ToView` | Always check BranchDbContext overrides FIRST |
| Assuming `ToView()` target is a database VIEW | Cross-reference against TMS DB schema files (Step 3). `ToView()` = read-only EF mapping, not DB object type. Example: `sen_ref` is a TABLE mapped via `ToView()` |
| Missing `HasPostgresEnum` custom types | Explicitly scan for `HasPostgresEnum` |
| Miscounting procedures (got ~26, actual was 35) | Exhaustively grep ALL `OperationType.Procedure` sites |
| Missing routines only called from resolvers (not mutations) | Step 8 — scan resolvers and middleware too |
| Confusing function vs procedure classification | Use `OperationType` enum value, not naming |
| Missing mutations that have a class but no DB-section entry (e.g., `removedriver`) | Cross-reference mutation classes against extracted routine names |
| Missing routines behind `SetXServerDtoMutation` calling both get AND set | Read full mutation code — one mutation may call multiple routines |
| Missing `.HasColumnName()` in multi-line fluent chains | Read the full `builder.Property(...)` chain including continuation lines across multiple lines |
| Confusing navigation properties with mapped columns in property count | Navigation properties don't have `.HasColumnName()` — they affect the property-count safety net delta but are not errors |
| Missing columns from second entity on shared view | UNION columns from ALL entity configurations mapped to same database object (Step 2f) |
