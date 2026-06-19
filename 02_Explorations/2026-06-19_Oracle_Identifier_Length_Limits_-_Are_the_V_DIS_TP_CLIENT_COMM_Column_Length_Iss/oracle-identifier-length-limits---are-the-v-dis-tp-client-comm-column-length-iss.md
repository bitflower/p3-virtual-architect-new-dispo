# Oracle Identifier Length Limits — Are the V_DIS_TP_CLIENT_COMM Column Length Issues Real?

**Date:** 2026-06-19
**Status:** Concluded — latent TMS Bridge bug identified

---

## Original User Input

During PRD-003 (TMS Bridge DB Verifier Column Checks) smoke testing against ABN1060 on Oracle, the view `V_DIS_TP_CLIENT_COMM` (88 columns) failed the live SELECT probe with `ORA-00972: Bezeichner ist zu lang` (identifier too long). The TMS DB admins previously stated that using quoted identifiers in SELECT statements "stimulates these length errors" and is "the wrong way to do things."

This exploration investigates: (1) whether quoted vs unquoted identifiers have different length limits in Oracle, (2) what the actual Oracle version/configuration is on ABN1060, and (3) whether the long column names are a tool bug, an Oracle bug, or a TMS Bridge bug.

---

## TL;DR

**It's a latent bug in the TMS Bridge.** The TMS Bridge C# code is harmonized for Oracle and PostgreSQL, but 2 column names in `V_DIS_TP_CLIENT_COMM` exceed Oracle 12.1's hard 30-byte identifier limit. The columns don't exist in Oracle's catalog — they were added to the AlloyDB view definition but never existed on Oracle. However, the TMS Bridge `BranchDbContext` blindly uppercases all column names for Oracle (line 176) without checking the 30-byte limit, and Entity Framework will generate SQL with these names if a GraphQL client ever requests them.

The `[UseProjection]` attribute on the GraphQL query means EF only SELECTs columns the client requests — so the bug only triggers if a client requests `loadingLocationGlobalLocationNumber` or `palletPlacesQuantity` against an Oracle tenant. It is latent, not active.

The DBAs' claim that "quoting causes length errors" is factually incorrect — both quoted and unquoted identifiers have the same 30-byte limit on Oracle 12.1.

---

## Analysis

### 1. ABN1060 Oracle Version

```
Oracle Database 12c Enterprise Edition Release 12.1.0.2.0 - 64bit Production
```

This is **pre-12.2**, which means:
- Hard 30-byte identifier length limit (no configuration knob)
- The 128-byte extended identifier feature was introduced in 12.2 via the `COMPATIBLE` parameter
- `V$PARAMETER` access denied for `TMSBR1060` (read-only bridge user), but the version banner confirms 12.1

### 2. Quoted vs Unquoted — Same Limit

Tested both forms against the 41-character column name:

| Probe | SQL | Result |
|-------|-----|--------|
| Unquoted | `SELECT SHIPPINGUNITSQUANTITYPALLETPLACESQUANTITY FROM TMS1060.V_DIS_TP_CLIENT_COMM WHERE 1=0` | **ORA-00972** |
| Quoted | `SELECT "SHIPPINGUNITSQUANTITYPALLETPLACESQUANTITY" FROM "TMS1060"."V_DIS_TP_CLIENT_COMM" WHERE 1=0` | **ORA-00972** |

Both fail identically. The Oracle SQL parser applies the same 30-byte limit regardless of quoting. The DBAs' statement that quoting "stimulates" length errors has no technical basis.

### 3. Columns Don't Exist in Oracle Catalog

```sql
SELECT COLUMN_NAME FROM ALL_TAB_COLUMNS
WHERE OWNER = 'TMS1060' AND TABLE_NAME = 'V_DIS_TP_CLIENT_COMM'
  AND COLUMN_NAME IN (
    'SHIPPINGUNITSQUANTITYPALLETPLACESQUANTITY',
    'LOADINGLOCATIONGLOBALLOCATIONNUMBER'
  );
-- Result: 0 rows
```

The columns are **not in `ALL_TAB_COLUMNS`**. They were added to the AlloyDB view definition during the migration and never existed on Oracle.

### 4. TMS Bridge Harmonization — The Real Issue

The TMS Bridge uses a single codebase for Oracle and PostgreSQL. The Entity Framework configuration hardcodes both column names:

```csharp
// TourpointClientCommunicationEntityConfiguration.cs
builder.Property(e => e.LoadingLocationGlobalLocationNumber)
  .HasColumnName("loadinglocationgloballocationnumber");   // 35 chars > 30 limit

builder.Property(e => e.PalletPlacesQuantity)
  .HasColumnName("shippingunitsquantitypalletplacesquantity"); // 41 chars > 30 limit
```

When running on Oracle, `BranchDbContext.AdjustTablesAndViews()` uppercases all column names:

```csharp
// BranchDbContext.cs, line 161-180
if (Database.IsOracle())
{
    // This assumes that all oracle models have same naming and types as the postgre models
    foreach (var property in entity.GetProperties())
    {
        property.SetColumnName(upperCasedName?.ToUpper());
    }
}
```

The comment itself admits the assumption: *"This assumes that all oracle models have same naming and types as the postgre models."* This assumption is wrong for these 2 columns.

### 5. Why It Hasn't Crashed in Production (Yet)

The GraphQL query uses `[UseProjection]`:

```csharp
[UseProjection]
[UseFiltering]
[UseSorting]
public IQueryable<TourpointClientCommunicationEntity> GetTourpointClientCommunication(...)
```

HotChocolate's `[UseProjection]` makes EF only SELECT columns the GraphQL client actually requests. If no client ever requests `loadingLocationGlobalLocationNumber` or `palletPlacesQuantity` against an Oracle tenant, the long column names never appear in the generated SQL.

This makes it a **latent bug** — it exists in the code but only triggers under specific conditions.

---

## Oracle Identifier Length Rules (Reference)

| Oracle Version | Max Identifier Length | Controlled By |
|---|---|---|
| 11g, 12.1 | **30 bytes** | Hard limit, no configuration |
| 12.2+ | **128 bytes** | `COMPATIBLE` parameter (must be >= 12.2) |
| 23ai+ | **128 bytes** | Default |

- Limit is in **bytes**, not characters (matters for multi-byte character sets)
- Applies equally to quoted and unquoted identifiers
- Quoted identifiers additionally enforce case sensitivity and allow reserved words

### Why DBAs Advise Against Quoting (Legitimately)

The general DBA advice to avoid quoting is valid, but for reasons unrelated to length:
- Quoted identifiers are **case-sensitive** (`"MyCol"` ≠ `MYCOL`) — a common source of bugs
- `DBMS_METADATA` output includes unnecessary quotes that are hard to strip
- Breaks cross-platform portability assumptions
- Creates confusion when developers mix quoted and unquoted references

Sources:
- [Oracle official ORA-00972 documentation](https://docs.oracle.com/en/error-help/db/ora-00972/)
- [ORACLE-BASE: Long Identifiers in 12cR2](https://oracle-base.com/articles/12c/long-identifiers-12cr2)
- [Mike Dietrich: Long Identifiers in 12.2 May Cause Trouble](https://mikedietrichde.com/2018/07/03/long-identifiers-in-oracle-12-2-may-cause-trouble/)
- [Philipp Salvisberg: Quoted Identifiers](https://www.salvis.com/blog/2022/10/11/quoted-identifiers-joelkallmanday/)

---

## Findings

1. **Latent TMS Bridge bug**: 2 column names in `TourpointClientCommunicationEntityConfiguration` exceed Oracle 12.1's 30-byte limit. EF will generate SQL with these names if a GraphQL client requests them against an Oracle tenant.
2. **The columns don't exist on Oracle**: `ALL_TAB_COLUMNS` returns 0 rows for both. They were added in the AlloyDB migration only.
3. **`[UseProjection]` masks the bug**: Only triggers if a client specifically requests `loadingLocationGlobalLocationNumber` or `palletPlacesQuantity` against an Oracle-backed `databaseIdentifier`.
4. **Quoted vs unquoted: same limit** — the DBA claim about quoting is incorrect for length errors.
5. **The DB Verifier correctly surfaces the issue** — the ORA-00972 in the live probe and the catalog miss are both accurate signals of a real schema divergence.

## Impact Assessment

| Component | Impact |
|-----------|--------|
| **TMS Bridge on Oracle** | Latent bug — will crash with ORA-00972 if those 2 fields are queried |
| **TMS Bridge on AlloyDB** | No issue — PostgreSQL supports up to 63-char identifiers |
| **DB Verifier tool** | Working correctly — accurately reports the divergence |
| **db-objects.json** | Correctly reflects the C# source code; the issue is in the TMS Bridge, not the registry |

## Recommended Actions

1. **Raise as TMS Bridge bug** (low priority, latent): The `AdjustTablesAndViews()` method in `BranchDbContext` should either validate column name lengths for Oracle or the view definition on AlloyDB should use names ≤ 30 chars for Oracle compatibility.
2. **No changes to the DB Verifier** — it correctly reports the situation.
3. **Communicate to DBAs**: The quoting claim is incorrect for identifier length; share the test evidence.

---

## Related PRD

- `03_PRD/Open/003_TMS_Bridge_DB_Verifier_Core_And_Column_Checks/PRD.md` — this issue was discovered during PRD-003 smoke testing against ABN1060 on Oracle

## Related Files

- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/Entities/TourpointClientCommunication/TourpointClientCommunicationEntityConfiguration.cs` — EF column mapping with long names
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContext.cs:161-180` — Oracle uppercasing logic
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Queries/TourpointClientCommunicationQuery.cs` — GraphQL query with [UseProjection]
- `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier.Core/Registry/db-objects.json` — column registry
- `Code/Disposition-Rollout-Tools/reports/abn1060-oracle-l6.json` — full Oracle verification report
- `Code/Disposition-Rollout-Tools/reports/abn1034-postgresql-l6.json` — PostgreSQL verification report
