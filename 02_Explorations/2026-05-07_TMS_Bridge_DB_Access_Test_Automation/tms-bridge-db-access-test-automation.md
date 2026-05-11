# TMS Bridge: Automated Database Permission Verification

**Date:** 2026-05-07
**Status:** Exploration

---

## Original User Input

> Explore an automated solution to test the access to the database objects defined in `02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md`
>
> The solution must support **both Oracle and PostgreSQL** databases, similar to how the TMS Bridge itself handles dual-provider connectivity. Production currently runs on Oracle; PostgreSQL/AlloyDB is the migration target. The database schemas and objects are the same on both platforms.

---

## Summary

The TMS Bridge accesses **77 database objects** (11 tables, 20 views, 11 functions, 35 stored procedures, 1 custom type) across 9 schemas. Today there is **no automated verification** that the Bridge's database user actually has the required permissions on these objects. Permission failures surface only at runtime when a user triggers the affected feature.

The solution is a **.NET console tool** with **three verification levels** (existence → signature → permissions) controlled via CLI flags, supporting both Oracle and PostgreSQL through the same provider abstraction the Bridge itself uses.

A **change-detection mechanism** (CI hook on TMS Bridge PRs) keeps the tool's object registry in sync with the actual codebase without full re-scans.

---

## Problem Statement

### What can go wrong

1. **Permission drift** — A DBA modifies grants, a new database version is deployed, or a new location schema is provisioned without applying the full permission set.
2. **Object drift** — Views or functions are renamed (7 views were renamed in `release/7.0.0.8+NEW-DISPO`), dropped, or moved to a different schema without updating the Bridge or the grants.
3. **Schema-per-location gaps** — Each location has its own tenant schema (e.g., `TMS01060` for location 1060). Permissions may be applied to one location but missed on another when a new location is onboarded or when grants are re-applied selectively. Environments (dev, abn, uat, prod) are separate database instances, so grants must be verified per environment *and* per location.
4. **Provider-specific gaps** — A permission exists on Oracle but is missing on PostgreSQL (or vice versa), discovered only during or after migration.
5. **Cross-environment drift** — Permissions work in dev but are missing in prod because the grant script was only run against the dev instance.

### Current state

| Aspect | Status |
|--------|--------|
| Permission verification | None |
| Health-check endpoint | None |
| Integration tests against real DB | Testcontainers for unit-level tests (PostgreSQL only) |
| Deployment pipeline | `manual_db_privileges_create.yml` applies grants (PostgreSQL) but does not verify them |

---

## Verification Levels

The tool supports three verification levels. Each level builds on the previous one:

```
Level 1.0          Level 1.5              Level 2.0
Existence          Signature              Permissions
───────────────    ───────────────        ───────────────
Does the object    Does the routine       Does the user
exist in the       have the expected      have the required
catalog?           parameters?            GRANT?

Tables ✓           Tables: n/a            Tables ✓
Views ✓            Views: n/a             Views ✓
Functions ✓        Functions ✓            Functions ✓
Procedures ✓       Procedures ✓           Procedures ✓
Types ✓            Types: n/a             Types ✓
```

### Level 1.0 — Existence

Confirms that all 77 database objects exist in the target schema. No parameter values needed. Uses catalog lookups only.

| Provider | Tables/Views | Functions/Procedures | Types |
|----------|-------------|---------------------|-------|
| PostgreSQL | `pg_class` + `pg_namespace` | `pg_proc` + `pg_namespace` | `pg_type` + `pg_namespace` |
| Oracle | `ALL_OBJECTS` (TABLE, VIEW) | `ALL_PROCEDURES` (PACKAGE + PROCEDURE_NAME) | N/A (PostgreSQL-only) |

**Use case:** After a DB schema deployment — "Did the migration create everything the Bridge needs?"

**Who can run it:** Any user with catalog read access (e.g., superuser, DBA). Does not require the Bridge user's credentials.

### Level 1.5 — Signature Verification

For functions and procedures only. Confirms that each routine's parameter signature matches expectations — catches renames, parameter type changes, and dropped/added parameters without executing anything.

| Provider | How |
|----------|-----|
| PostgreSQL | `pg_proc.proargtypes`, `pg_proc.proargnames` — verify argument count and types |
| Oracle | `ALL_ARGUMENTS` — verify `ARGUMENT_NAME`, `DATA_TYPE`, `IN_OUT`, `POSITION` per routine |

**Use case:** After a DB schema upgrade that may have changed routine signatures — "Will the Bridge's `IRoutineExecutor` calls still work?"

**What it does NOT do:** It does not call the routines. No parameter values are needed. It only reads the catalog metadata about what parameters each routine expects.

**Prerequisite:** The tool needs a reference signature for each routine. This can be:
- Hardcoded in the object registry (extracted once from the current DB or from the Bridge's `IRoutineExecutor` call sites)
- Or declared as "verify arg count only" for a lighter check

### Level 2.0 — Permissions

Confirms that the connected database user has the required GRANT (SELECT, EXECUTE, USAGE) on each object. Implicitly includes Level 1.0 — a missing object is reported as "NOT FOUND" rather than "DENIED".

| Provider | Tables/Views | Functions/Procedures | Types |
|----------|-------------|---------------------|-------|
| PostgreSQL | `has_table_privilege()` | `has_function_privilege()` via OID | `has_type_privilege()` |
| Oracle | `ALL_TAB_PRIVS` (GRANTEE, PRIVILEGE) | `ALL_TAB_PRIVS` on package (EXECUTE) | N/A |

**Use case:** After a GRANT script runs — "Can the Bridge user access everything?"

**Who must run it:** The Bridge database user (or a user with the same role grants), since permissions are user-specific.

### Level mapping to CLI

```bash
# Level 1.0: existence only
dotnet run -- --connection-string "..." --schema TMS01060 --level existence

# Level 1.5: existence + signature verification
dotnet run -- --connection-string "..." --schema TMS01060 --level signature

# Level 2.0: existence + permissions (default)
dotnet run -- --connection-string "..." --schema TMS01060 --level permissions

# All levels combined
dotnet run -- --connection-string "..." --schema TMS01060 --level all
```

### Output per level

```
TMS Bridge DB Verification — Level: all
Provider: Oracle | User: BRIDGE_USER | Schema: TMS01060
═══════════════════════════════════════════════════════════

  TABLES (11)
  ✓ TMS01060.BORDERO .......... EXISTS   SELECT granted
  ✓ TMS01060.FAHRER ........... EXISTS   SELECT granted
  ✗ TMS01060.ORT .............. EXISTS   SELECT DENIED       ← L2.0 failure
  ...

  VIEWS (20)
  ✗ TMS01060.V_DIS_TO_FEATURES  NOT FOUND                   ← L1.0 failure
  ✓ PUBLIC.V_DIS_TRANSPORTORDER EXISTS   SELECT granted
  ...

  FUNCTIONS (11)
  ✓ PDIS_TRANSPORTORDER.GETXSERVERDTO
      EXISTS   signature OK (4 args)   EXECUTE granted
  ✗ PDIS_TRANSPORTORDER.SETXSERVERDTO
      EXISTS   signature MISMATCH (expected 5, got 6)        ← L1.5 failure
  ...

  PROCEDURES (35)
  ✓ PDIS_TRANSPORTORDER.DELETE
      EXISTS   signature OK (2 args)   EXECUTE granted
  ...

  TYPES (1)
  ○ PDIS_TRANSPORTORDER.LEGTYPE ...... SKIPPED (PostgreSQL-only)

═══════════════════════════════════════════════════════════
  Level 1.0 (Existence):  76/77 passed, 1 NOT FOUND
  Level 1.5 (Signature):  45/46 passed, 1 MISMATCH
  Level 2.0 (Permission): 75/76 passed, 1 DENIED
  Exit code: 1
```

---

## Provider Differences

| Aspect | PostgreSQL | Oracle |
|--------|-----------|--------|
| Schema case | lowercase (`tms01060`) | uppercase (`TMS01060`) |
| Table/View privilege check | `has_table_privilege()` | `ALL_TAB_PRIVS` / `USER_TAB_PRIVS` |
| Function/Procedure privilege check | `has_function_privilege()` via `pg_proc` OID | `ALL_TAB_PRIVS` on package name |
| Routine signature check | `pg_proc.proargtypes` / `proargnames` | `ALL_ARGUMENTS` |
| Type privilege check | `has_type_privilege()` | N/A (`legtype` is PostgreSQL-only enum) |
| Routine model | Schema-scoped functions/procedures | Package-scoped functions/procedures |
| Routine schemas | `pdis_transportorder.setdriver` (schema.function) | `PDIS_TRANSPORTORDER.SETDRIVER` (package.function) |

---

## Solution Architecture

### Core: .NET Console Tool

A standalone .NET console application that auto-detects the database provider from the connection string (same pattern as the Bridge's `DbConnectionStringProvider`) and runs provider-appropriate verification queries at the selected level.

```
┌─────────────────────────────────────────────────────────────┐
│  TmsBridgeDbVerifier (Console App)                          │
│                                                             │
│  Input: --connection-string "..."                           │
│         --schema TMS01060[,TMS01034]                        │
│         --level existence | signature | permissions | all   │
│                                                             │
│  ┌─────────────────────┐   ┌──────────────────────┐        │
│  │ Provider Detection   │   │ Object Registry      │        │
│  │ Oracle ↔ PostgreSQL  │   │ 77 objects + sigs    │        │
│  └──────────┬──────────┘   └──────────┬───────────┘        │
│             │                         │                     │
│  ┌──────────▼─────────────────────────▼──────────┐         │
│  │ IDbVerifier                                    │         │
│  │ ┌────────────────┐  ┌─────────────────┐       │         │
│  │ │ PostgreSql     │  │ Oracle          │       │         │
│  │ │ Verifier       │  │ Verifier        │       │         │
│  │ │                │  │                 │       │         │
│  │ │ L1.0 pg_class  │  │ L1.0 ALL_OBJECTS│       │         │
│  │ │ L1.5 pg_proc   │  │ L1.5 ALL_ARGS  │       │         │
│  │ │ L2.0 has_*_priv│  │ L2.0 ALL_TAB_P │       │         │
│  │ └────────────────┘  └─────────────────┘       │         │
│  └───────────────────────┬───────────────────────┘         │
│                          │                                  │
│  ┌───────────────────────▼───────────────────────┐         │
│  │ Result Reporter                                │         │
│  │ Console table + per-level summary + exit code  │         │
│  └────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Object Registry

All 77 objects declared once, provider-agnostic. For Level 1.5, routines include expected argument count (and optionally argument types):

```csharp
static readonly DbObject[] RequiredObjects = [
    // Tables (11) — L1.0 + L2.0 only
    new Table("tms", "bordero"),
    new Table("tms", "fahrer"),
    new Table("tms", "ort"),
    new Table("tms", "person"),
    new Table("tms", "pst_hst"),
    new Table("tms", "rollkart"),
    new Table("tms", "sendung"),
    new Table("tms", "sen_ls_pst"),
    new Table("tms", "sen_ls_ref"),
    new Table("tms", "sen_zuord"),
    new Table("tms", "sen_ref"),

    // Views (20) — L1.0 + L2.0 only
    new View("public", "v_dis_transportorder"),
    new View("public", "v_dis_to_filter"),
    new View("public", "v_dis_to_pickupplanning"),
    new View("public", "v_dis_shipment_all"),
    new View("public", "v_dis_to_tourpoint"),
    new View("public", "v_dis_freight_exchange_tp"),
    new View("public", "v_dis_to_presettemp"),
    new View("public", "v_dis_branch_address"),
    new View("public", "v_dis_leg"),
    new View("tms", "v_dis_to_features"),
    new View("tms", "v_dis_contact_details"),
    new View("tms", "v_dis_to_tp_target_dates"),
    new View("tms", "v_dis_tp_client_comm"),
    new View("tms", "v_pers_tb"),
    new View("tms", "v_ebv_shipment"),
    new View("tms", "v_ebv_delivery_note"),
    new View("tms", "v_ebv_leg"),
    new View("tms", "v_ebv_participant"),
    new View("tms", "v_ebv_service"),
    new View("tms", "v_sen_ls"),

    // Functions (11) — L1.0 + L1.5 + L2.0
    new Routine("pdis_transportorderdto", "get",
        RoutineKind.Function, ExpectedArgs: 4),
    new Routine("pdis_transportorder", "getxserverdto",
        RoutineKind.Function, ExpectedArgs: 4),
    new Routine("pdis_transportorder", "getdriver",
        RoutineKind.Function, ExpectedArgs: 2),
    new Routine("pdis_transportorder", "geterrormessage",
        RoutineKind.Function, ExpectedArgs: 1),
    new Routine("pdis_transportorder", "setxserverdto",
        RoutineKind.Function, ExpectedArgs: 5),
    new Routine("pdis_transportorder", "createtransportorderfromleg",
        RoutineKind.Function, ExpectedArgs: 5),
    new Routine("pdis_transportorder", "createtransportorderfromshipment",
        RoutineKind.Function, ExpectedArgs: 4),
    new Routine("pdis_transportorder", "addshipment",
        RoutineKind.Function, ExpectedArgs: 3),
    new Routine("pdis_leg", "getstaysloadedstatus",
        RoutineKind.Function, ExpectedArgs: 2),
    new Routine("cal_uniface", "item",
        RoutineKind.Function, ExpectedArgs: 3),
    new Routine("cal_uniface", "list2dbtt",
        RoutineKind.TableFunction, ExpectedArgs: 2),

    // Procedures (35) — L1.0 + L1.5 + L2.0
    new Routine("pdis_transportorder", "delete",
        RoutineKind.Procedure, ExpectedArgs: 2),
    // ... all 35 procedures with expected arg counts ...

    // Custom Types (1) — PostgreSQL only
    new CustomType("pdis_transportorder", "legtype"),
];
```

> **Note on `ExpectedArgs`:** The argument counts must be extracted once from the current database or from the Bridge's `IRoutineExecutor` call sites. They serve as a lightweight signature check. A full signature match (argument names + types) is possible but adds maintenance burden — arg count catches the most common breaking changes (added/removed parameters).

### Provider-Specific Verification

```csharp
public interface IDbVerifier
{
    // Level 1.0
    Task<bool> ObjectExists(DbObject obj, string tenantSchema);

    // Level 1.5 (routines only)
    Task<SignatureResult> VerifySignature(Routine routine, string tenantSchema);

    // Level 2.0
    Task<bool> HasPermission(DbObject obj, string tenantSchema);
}
```

Each provider implements this interface with catalog-specific queries. No routine is ever called — all verification is read-only against system catalogs.

### CLI Usage

```bash
# Oracle production — single location, all levels
dotnet run -- \
  --connection-string "User Id=bridge_user;Password=***;Data Source=tms-prod:1521/TMSPROD" \
  --schema TMS01060

# PostgreSQL dev — existence check only (any user)
dotnet run -- \
  --connection-string "Host=alloydb-dev;Port=5432;Database=tmsdb;Username=admin;Password=***" \
  --schema tms01060 \
  --level existence

# Multiple locations, signature + permissions
dotnet run -- \
  --connection-string "..." \
  --schema TMS01060,TMS01034 \
  --level signature,permissions
```

> **Schema naming:** The number (e.g., 1060) identifies a location (Niederlassung). Each environment (dev, abn, uat, prod) is a separate database instance containing one or more location schemas. Run the tool once per environment, each with its own connection string.

---

## Registry Maintenance: Change-Detection Hook

Rather than re-scanning the entire TMS Bridge codebase periodically, a **CI hook** watches for changes to the specific files that define database object references. It triggers only when those files change on a PR.

### Trigger surface

Only a small set of file patterns in the TMS Bridge repo affect the object registry:

| What it defines | File pattern | What to detect |
|---|---|---|
| Table/View mappings | `*EntityConfiguration.cs` | `ToTable("...")`, `ToView("...")` |
| Routine calls | `*Mutation.cs`, `*Query.cs` | `IRoutineExecutor.Execute*(...)` with schema + routine name |
| View overrides | `BranchDbContext.cs` | `OnModelCreating` → `ToView(...)` overrides |
| Custom types | `BranchDbContext.cs` | `HasPostgresEnum<...>()` |

### How it works

```
TMS Bridge PR
      │
      ▼
  CI: changed files filter
  (paths-filter on EntityConfiguration, Mutation, Query, BranchDbContext)
      │
      │ no matching files → skip
      │ matching files found ↓
      ▼
  Extractor step
  (scan changed + surrounding files → extract DB object references)
      │
      ▼
  Diff against current object registry
      │
      ├─ no changes → ✓ pass
      │
      ├─ additions → ⚠ PR comment:
      │    "New DB object reference: pdis_transportorder.newfunction
      │     → add to DbObjectRegistry + update permission scope doc"
      │
      └─ removals → ⚠ PR comment:
           "DB object reference removed: pdis_transportorder.oldfunction
            → remove from DbObjectRegistry + update permission scope doc"
```

### Implementation options

| Approach | Complexity | Notes |
|----------|-----------|-------|
| **GitHub Actions + grep** | Low | `paths-filter` action triggers a shell script that greps for `ToTable`, `ToView`, `Execute` patterns in changed files, compares with known list |
| **Claude Code agent in CI** | Medium | The `tms-bridge-db-extractor` agent runs in a GitHub Actions step, but only on PRs touching the trigger files |
| **Pre-commit hook** | Low | Local-only, runs on the developer's machine before commit — lighter but not enforced |

The key insight: this is not about regenerating the full list — it's about **flagging deltas** on PRs so the registry stays in sync through the normal review process.

---

## Alternative: Health-Check Endpoint (Optional Add-On)

Add a custom ASP.NET `IHealthCheck` to the TMS Bridge API that runs Level 1.0 + 2.0 checks at runtime. This reuses the same verification logic from the console tool but runs inside the Bridge process.

```
GET /health/db-permissions?database=D-10-60

{
  "status": "Degraded",
  "results": {
    "db-permissions": {
      "status": "Degraded",
      "provider": "Oracle",
      "schema": "TMS01060",
      "existence": "77/77",
      "permissions": "76/77",
      "failures": ["TMS01060.ORT: SELECT denied"]
    }
  }
}
```

**Advantages:** Zero additional infrastructure, uses the exact production connection path, can be wired to monitoring/alerting.

**Disadvantages:** Requires a TMS Bridge release, cannot verify *before* deployment.

**Recommendation:** Consider as a Phase 2 add-on if permission issues recur in production. Not the starting point.

---

## Comparison: Levels vs. Approaches

| | Console Tool | Change-Detection Hook | Health-Check Endpoint |
|---|---|---|---|
| **Level 1.0 (Existence)** | ✓ | — (not applicable) | ✓ |
| **Level 1.5 (Signature)** | ✓ | — | Possible but heavy |
| **Level 2.0 (Permissions)** | ✓ | — | ✓ |
| **Registry maintenance** | Manual | Automated (PR-level) | Shares registry with tool |
| **Dual-provider** | Yes (Oracle + PostgreSQL) | N/A (code-level) | Yes (automatic) |
| **When it runs** | On-demand / CI | On TMS Bridge PRs | Runtime (continuous) |
| **Infra requirements** | .NET SDK | GitHub Actions | None (in-app) |

These three are complementary, not competing:
- **Console Tool** = the verifier (runs checks)
- **Change-Detection Hook** = the maintainer (keeps the registry current)
- **Health-Check Endpoint** = the monitor (continuous runtime verification)

---

## Recommendation

### Phasing

| Phase | What | Levels | When |
|-------|------|--------|------|
| **1** | Console tool with hardcoded registry | L1.0 + L2.0 | Now |
| **2** | Add Level 1.5 signature checks | L1.5 | After extracting arg counts from DB |
| **3** | Change-detection hook on TMS Bridge PRs | Registry maintenance | When tool proves useful |
| **4** | (Optional) Health-check endpoint in Bridge | L1.0 + L2.0 runtime | If permission issues recur |

### Why this order

- **Phase 1** delivers immediate value: connect to Oracle prod, verify all 77 objects are accessible. The `--level existence` mode alone is useful for the DB team after schema deployments.
- **Phase 2** adds signature checks, which catch a different class of issues (routine parameter changes after DB upgrades). Requires a one-time extraction of expected argument counts.
- **Phase 3** prevents the registry from going stale. The 77 objects change infrequently today, but the hook is cheap insurance once the tool is established.
- **Phase 4** only if needed — the console tool covers the main use cases.

---

## Implementation Sketch

### Project structure

```
tools/
  TmsBridgeDbVerifier/
    TmsBridgeDbVerifier.csproj
    Program.cs                          ← CLI parsing, orchestration
    Model/
      DbObject.cs                       ← Table, View, Routine, CustomType records
      VerificationResult.cs             ← Per-object result (exists, signature, permission)
      SignatureResult.cs                 ← Arg count match/mismatch
    Registry/
      DbObjectRegistry.cs              ← All 77 objects with expected arg counts
    Verification/
      IDbVerifier.cs                    ← L1.0 + L1.5 + L2.0 interface
      PostgreSqlVerifier.cs
      OracleVerifier.cs
    Infrastructure/
      ProviderDetector.cs               ← Connection string → Oracle/PostgreSQL
      SchemaResolver.cs                 ← Case + tenant schema handling
    Reporting/
      ConsoleReporter.cs                ← Formatted output + exit code
```

### NuGet dependencies

```xml
<PackageReference Include="Npgsql" Version="8.*" />
<PackageReference Include="Oracle.ManagedDataAccess.Core" Version="23.*" />
<PackageReference Include="System.CommandLine" Version="2.*" />
```

### Key implementation details

#### Provider detection (mirrors `DbConnectionStringProvider.cs`)

```csharp
public static class ProviderDetector
{
    static readonly Regex PostgresPattern = new(
        @"(?=.*\bHost=[^;]+)(?=.*\bPort=\d+)(?=.*\bDatabase=[^;]+)");
    static readonly Regex OraclePattern = new(
        @"(?=.*\bUser\s*Id=[^;]+)(?=.*\bData\s*Source=[^;]+)");

    public static DbProvider Detect(string connectionString)
    {
        if (PostgresPattern.IsMatch(connectionString)) return DbProvider.PostgreSql;
        if (OraclePattern.IsMatch(connectionString)) return DbProvider.Oracle;
        throw new ArgumentException("Cannot detect provider from connection string");
    }
}
```

#### Schema case handling

```csharp
// PostgreSQL: schemas are lowercase (tms01060)
// Oracle: schemas are uppercase (TMS01060)
// The object registry uses lowercase "tms" as placeholder for the tenant schema.
// Fixed routine schemas (pdis_transportorder, etc.) are also lowercase in registry.
// The verifier adjusts case based on provider.

string ResolveSchema(string registrySchema, string tenantSchema, DbProvider provider)
{
    if (registrySchema == "tms")
        return tenantSchema; // already in correct case from CLI arg
    return provider == DbProvider.Oracle
        ? registrySchema.ToUpperInvariant()
        : registrySchema.ToLowerInvariant();
}
```

#### Oracle: package-level EXECUTE check (Level 2.0)

On Oracle, EXECUTE permission is granted on the **package**, not on individual routines. The check is:

```sql
-- Does the user have EXECUTE on the package?
SELECT COUNT(*) FROM ALL_TAB_PRIVS
WHERE GRANTEE IN (USER, 'PUBLIC')
  AND OWNER = :schema AND TABLE_NAME = :package AND PRIVILEGE = 'EXECUTE'
```

#### Oracle: routine signature check (Level 1.5)

```sql
-- Verify routine exists with expected argument count
SELECT COUNT(*) AS actual_args FROM ALL_ARGUMENTS
WHERE OWNER = :schema
  AND PACKAGE_NAME = :package
  AND OBJECT_NAME = :routine
  AND ARGUMENT_NAME IS NOT NULL  -- exclude RETURN value
```

#### PostgreSQL: routine signature check (Level 1.5)

```sql
-- Verify routine exists with expected argument count
SELECT pronargs AS actual_args FROM pg_proc
WHERE proname = :routine
  AND pronamespace = :schema::regnamespace
```

---

## Open Items

1. **Expected argument counts** — Must be extracted once from the current database for all 46 routines. Can be done with a one-off query against `ALL_ARGUMENTS` (Oracle) or `pg_proc` (PostgreSQL) and hardcoded into the registry.
2. **Oracle package ownership model** — Verify that the routine schema names in the permission scope document match Oracle's `OWNER` + `OBJECT_NAME` structure for packages. The Bridge uses `schema.routine` where schema = package name on Oracle.
3. **Function overloads** — On PostgreSQL, `pg_proc` may return multiple rows for the same function name (overloads). The checker should verify at least one overload matches the expected arg count.
4. **Connection string security** — The tool should accept connection strings via environment variables or a config file (not just CLI arguments) to avoid exposing credentials in process listings.
5. **`legtype` custom type** — PostgreSQL-only (`HasPostgresEnum`). The Oracle verifier should report it as "SKIPPED" rather than "passed" or "failed".
6. **`public` schema on Oracle** — PostgreSQL views in the `public` schema may live in a different schema on Oracle. Verify the mapping.

---

## Related Files

- `02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md` — Source inventory (77 objects)
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContextFactory.cs` — Schema resolution + provider detection
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Services/DbConnectionStringProvider.cs` — Connection string handling + Oracle/PostgreSQL regex detection
- `Code/tms-alloydb-schema/.github/workflows/manual_db_privileges_create.yml` — Existing privilege deployment workflow
- `Code/tms-alloydb-schema/src/sql/scripts/tms-db-privileges-scripts.sh` — Existing privilege grant script

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-07 | Matthias Max | Initial exploration: 4 options evaluated, .NET console tool recommended. Dual Oracle/PostgreSQL provider support as key constraint. |
| 1.1 | 2026-05-07 | Matthias Max | Major restructure: introduced 3 verification levels (existence → signature → permissions). Revised auto-generation to change-detection hook on PRs. Added dual-mode CLI flag. Corrected environment model (dev/abn/uat/prod, location-based schemas). |

---

<div align="center">Created and maintained by <strong>Virtual Architect</strong></div>
