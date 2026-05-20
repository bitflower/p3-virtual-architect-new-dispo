---
name: tms-bridge-db-extractor
description: Extract all TMS database objects referenced by the TMS Bridge from C# source code
tools: [Read, Glob, Grep]
---

# TMS Bridge Database Object Extractor

Extract a complete, classified inventory of all TMS database objects accessed by `CALConsult.TMSBridge.API` directly from source code. Produces a structured markdown document suitable for wiki publication.

## Codebase Root

`Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/`
Tests: `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API.Tests/`

## Extraction Pipeline

Execute steps 1-7 in order. Each step produces a partial inventory. Step 8 merges and formats.

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
- Schema (second argument if present, otherwise infer — see Step 9)
- Entity type (from `modelBuilder.Entity<T>()` or the configuration class)
- EF mapping directive (`ToView` or `ToTable`)
- Whether the entity has a `DbSet<T>` property (entities without → "navigation-only")

Cross-reference: if an entity has a mapping in both its configuration AND BranchDbContext, the DbContext value wins.

---

### Step 2: Classify by actual database object type

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

### Step 3: Extract Stored Procedures

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

**Also check Startup.cs** for procedure-related registrations to ensure completeness.

---

### Step 4: Extract Functions

**Search pattern:**
```
Files: GraphQL/Mutations/**/*.cs, GraphQL/Queries/**/*.cs, Services/**/*.cs
Pattern: OperationType.Function
```

Extract same fields as Step 3. Additionally:
- **Access classification:** If the function is called from a Query class or is a pure getter (name starts with `get`), classify as READ. If called from a Mutation class and the name starts with `set`, `create`, `add`, `remove`, classify as WRITE.
- **Do not rely on naming alone** — check the actual call site context.

**Also search for DbFunction attributes:**
```
Pattern: [DbFunction(...)]  or  HasDbFunction(...)
```
These are EF-mapped functions called differently from IRoutineExecutor functions.

---

### Step 5: Extract Table Functions (Oracle-only)

**Search pattern:**
```
Files: GraphQL/Mutations/**/*.cs, Services/**/*.cs
Pattern: OperationType.Table
```

These generate `SELECT * FROM TABLE(schema.function(...))` via `OracleTableBuilder`. Flag as TABLE FUNCTION type. Always READ access.

---

### Step 6: Extract Custom Types

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

### Step 7: Detect Implicit Call Chains

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

### Step 8: Detect Obsolete/Inactive Entries

**Search pattern:**
```
File: Startup.cs (or Program.cs)
Pattern: commented-out AddTypeExtension lines, or mutations/queries not registered
```

Cross-reference: every mutation/query class found in Steps 3-5 should have a registration in Startup. If a class exists but is not registered (or is commented out), flag it as **obsolete**.

---

### Step 9: Schema Resolution

For each extracted object, determine the schema:

1. **Routine schemas** — extracted from qualified routine names (e.g., `pdis_transportorder.addtourpoint` → schema `pdis_transportorder`)
2. **View/table schemas** — from the second argument to `ToView`/`ToTable`:
   - If a `tmsSchema` or `schema` constructor parameter is passed → **tms** (tenant schema)
   - If no schema argument and configured in BranchDbContext directly → **public**
3. **Enum schemas** — from `HasPostgresEnum` first argument

---

### Step 10: Assemble Output

Produce a markdown document with this exact structure:

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

---

## Quality Checks (run before output)

1. **Completeness:** Count of mutations in Startup.cs registrations must match count of distinct routine names extracted
2. **No duplicates:** Each object name appears exactly once across all sections
3. **Schema coverage:** Every object has a schema assigned
4. **Access classification:** Every object has READ or WRITE
5. **Cross-reference DbSets:** Every `DbSet<T>` in BranchDbContext should map to exactly one table or view
6. **Rename detection:** Compare `ToView`/`ToTable` strings against SQL file names in `Code/tms-alloydb-schema/src/sql/view/` and `Code/tms-alloydb-schema/src/sql/scripts/` to detect name mismatches (potential pending renames)

---

## Known Pitfalls (from 2026-04-29 analysis)

These were real errors made during manual extraction. The agent must avoid them:

| Pitfall | How to Avoid |
|---------|-------------|
| Counting entities with `ToTable` as tables when DbContext overrides to `ToView` | Always check BranchDbContext overrides FIRST |
| Assuming `ToView()` target is a database VIEW | Cross-reference against TMS DB schema files (Step 2). `ToView()` = read-only EF mapping, not DB object type. Example: `sen_ref` is a TABLE mapped via `ToView()` |
| Missing `HasPostgresEnum` custom types | Explicitly scan for `HasPostgresEnum` |
| Miscounting procedures (got ~26, actual was 35) | Exhaustively grep ALL `OperationType.Procedure` sites |
| Missing routines only called from resolvers (not mutations) | Step 7 — scan resolvers and middleware too |
| Confusing function vs procedure classification | Use `OperationType` enum value, not naming |
| Missing mutations that have a class but no DB-section entry (e.g., `removedriver`) | Cross-reference mutation classes against extracted routine names |
| Missing routines behind `SetXServerDtoMutation` calling both get AND set | Read full mutation code — one mutation may call multiple routines |
