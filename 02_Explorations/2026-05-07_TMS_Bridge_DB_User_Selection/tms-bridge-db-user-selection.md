# TMS Bridge Credential Selection

**Date:** 2026-05-07
**Status:** Done

---

## Original User Input

New Dispo and Cloud4Log both access the TMS Bridge, but need different database users with different permission levels (e.g., Cloud4Log uses a read-only QM user, New Dispo uses a user with write permissions). The TMS Bridge currently resolves database connections through a single "database identifier" that maps 1:1 to a Secret Manager entry.

**Selected approach (Option 1):** Use a prefix in the database identifier (e.g., `dispo-o-10-60`) so each calling system resolves to its own Secret Manager entry and therefore its own database user credentials.

**Alternative (Option 2, not selected):** Unify user permissions on DB-level so both systems use the same user.

---

## How the TMS Bridge Resolves Database Identifiers Today

This section documents the current resolution chain from GraphQL request to database connection.

### Step 1: Identifier Enters via GraphQL

Every query and mutation accepts `databaseIdentifier` as a required `String!` parameter:

```graphql
mutation callSetTransportMode($databaseIdentifier: String!, $input: SetTransportModeInput!) {
    callSetTransportMode(databaseIdentifier: $databaseIdentifier, input: $input) { ... }
}
```

The identifier is passed to `IDbContextProvider.GetDbContext(databaseIdentifier)` which delegates to `BranchDbContextFactory`.

Cloud4Log sends the identifier via HTTP header (`DatabaseIdentifier`) rather than as a GraphQL variable, but it reaches the same resolution path.

### Step 2: Secret Manager Lookup (Connection String)

At startup, the bridge loads **all** secrets from a configured GCP project into the .NET configuration system:

```
GoogleSecretManagerConfigurationProvider.cs:
  Secret "D-10-60" → Configuration key "ConnectionStrings:D-10-60"
  Secret "O-10-60" → Configuration key "ConnectionStrings:O-10-60"
```

Each secret's value is a full connection string containing host, port, database, **username**, and **password**.

At request time, `DbConnectionStringProvider.GetConnectionString()` performs a direct key lookup:

```csharp
// DbConnectionStringProvider.cs:18
var connectionString = configuration.GetSection("ConnectionStrings")[databaseIdentifier];
```

**The identifier is used as-is** -- no transformation, no normalization. The identifier must exactly match a Secret Manager secret name.

### Step 3: Vendor Detection

The connection string is matched against regex patterns to determine if it's PostgreSQL or Oracle:

| Pattern | Vendor |
|---|---|
| `Host=...;Port=...;Database=...;Username=...;Password=...` | PostgreSQL |
| `User Id=...;Password=...;Data Source=...` | Oracle |

### Step 4: Schema Name Extraction

The identifier is parsed with a **strict regex** to derive the TMS schema name:

```csharp
// BranchDbContextFactory.cs:22
[GeneratedRegex(@"^[DO]-(\d{1,2})-(\d{1,3})$")]
private static partial Regex TmsSchemaNameRegex();
```

This means:
- `D-10-60` --> schema `tms1060` (PostgreSQL) or `TMS1060` (Oracle)
- `O-10-60` --> schema `tms1060`
- The `D`/`O` prefix is discarded; only the numeric parts matter for schema resolution

### Step 5: Connection Pool Caching

A singleton `DbDataSourceCache` caches `DbDataSource` instances keyed by the **raw database identifier**:

```csharp
// DbDataSourceCache.cs:15 — ConcurrentDictionary<string, Lazy<DbDataSource>>
var lazyDataSource = _cache.GetOrAdd(databaseIdentifier, ...);
```

Same identifier = same connection pool. Different identifiers = separate pools, even if they point to the same schema.

### Resolution Flow Diagram

```
GraphQL Request
  │
  │  databaseIdentifier = "D-10-60"
  ▼
┌─────────────────────────────────┐
│  DbConnectionStringProvider     │
│  config["ConnectionStrings"]    │──── key: "D-10-60"
│  ["D-10-60"]                    │──── value: "Host=...;Username=dispo_user;Password=..."
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Vendor Detection               │
│  (regex on connection string)   │──── Result: POSTGRESQL
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  DbDataSourceCache              │
│  cache.GetOrAdd("D-10-60", ..) │──── Creates or reuses connection pool
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Schema Name Extraction         │
│  Regex: ^[DO]-(\d{1,2})-(\d{1,3})$│
│  "D-10-60" → "tms1060"         │
└─────────────┬───────────────────┘
              │
              ▼
        BranchDbContext
   (connected to tms1060 schema
    with dispo_user credentials)
```

---

## Analysis: Can the Bridge Support Modified Identifiers?

### Common Ground (Both Options)

**Secret Manager lookup** and **connection pool caching** work without code changes for any identifier string. The bridge loads all secrets as `ConnectionStrings:{SecretId}` and caches pools by raw identifier. Only the **schema name regex** needs updating.

Current regex (`BranchDbContextFactory.cs:22`):
```csharp
[GeneratedRegex(@"^[DO]-(\d{1,2})-(\d{1,3})$")]
```

Any identifier that doesn't match this pattern throws a `FormatException`. This is the **only blocking issue** for both options.

---

### Option A: Prefix (e.g., `dispo-D-10-60`)

**Regex change:**
```csharp
[GeneratedRegex(@"^(?:[a-z0-9]+-)?[DO]-(\d{1,2})-(\d{1,3})$")]
```

**Example identifiers:** `dispo-D-10-60`, `cloud4log-O-10-60`

| | |
|---|---|
| **+ Reads naturally** | "dispo's D-10-60" -- the system name comes first, like a namespace |
| **+ Original identifier visible** | `D-10-60` is still recognizable at the end, easy to spot in logs |
| **+ Convention is common** | Namespacing via prefix is a widespread pattern (e.g., `env-resource`) |
| **- Ambiguity risk** | A prefix with hyphens could be confused with the `D-`/`O-` part. Regex must be careful not to greedily consume. Mitigated by anchoring on `[DO]-` |
| **- Breaks lexicographic grouping** | Secrets sort by system first (`cloud4log-D-10-60`, `dispo-D-10-60`) rather than by branch. Makes it harder to see all secrets for one branch side by side |

---

### Option B: Postfix (e.g., `D-10-60-dispo`)

**Regex change:**
```csharp
[GeneratedRegex(@"^[DO]-(\d{1,2})-(\d{1,3})(?:-[a-z0-9]+)?$")]
```

**Example identifiers:** `D-10-60-dispo`, `O-10-60-cloud4log`

| | |
|---|---|
| **+ Secrets sort by branch** | `D-10-60-cloud4log` and `D-10-60-dispo` appear next to each other in Secret Manager. Easier to audit per-branch |
| **+ Cleaner regex** | The capture groups `(\d{1,2})` and `(\d{1,3})` stay in the same position; the optional part is appended after. Less risk of matching errors |
| **+ Branch identifier stays primary** | Grep/filter for `D-10-60` still finds all variants |
| **- Less intuitive to read** | "D-10-60 for dispo" reads backwards compared to typical naming |
| **- Less familiar convention** | Prefix-based namespacing (e.g., `env-resource`) is more common in infrastructure tooling |

---

### Comparison Matrix

| Aspect | Prefix (`dispo-D-10-60`) | Postfix (`D-10-60-dispo`) |
|---|---|---|
| Regex complexity | Slightly higher (non-greedy prefix match) | Lower (optional trailing group) |
| Secret Manager sorting | By system, then branch | By branch, then system |
| Log readability | System name jumps out first | Branch jumps out first |
| Backward compatibility | `D-10-60` still works | `D-10-60` still works |
| Caller implementation | Prepend string | Append string |
| Code change scope | Single-line regex | Single-line regex |
| Ambiguity risk | Low (anchored on `[DO]-`) | Very low |

Both options are equally viable from a technical standpoint. The choice is a naming convention preference.

---

### Shared Side Effects (Both Options)

| Concern | Impact |
|---|---|
| **Separate connection pools** | Modified identifier and original get separate pools. Doubles pool count per branch. Acceptable -- pools are lazy. |
| **Secrets to create** | Each calling system needs its own secret per branch in Secret Manager. |
| **Caller changes** | New Dispo Backend must send modified identifier. Cloud4Log can keep existing identifiers unchanged. |
| **GraphQL schema** | No change needed -- `databaseIdentifier` is already `String!`. |

---

## Findings

1. **Both prefix and postfix are feasible with a single-line regex change** in `BranchDbContextFactory.cs:22`. Everything else in the resolution chain works with arbitrary identifier strings already.

2. **The bridge treats the database identifier as an opaque string** everywhere except for schema name extraction. This clean separation makes either approach low-risk.

3. **No infrastructure changes needed in the bridge** beyond the regex. The Secret Manager and the calling systems (New Dispo, Cloud4Log) need configuration updates.

4. **Connection pool isolation is a natural side effect** -- different identifiers automatically get separate pools, which provides clean separation between callers.

---

## Implementation Checklist

- [ ] **Team decision:** Prefix or postfix naming convention
- [ ] **TMS Bridge:** Update regex in `BranchDbContextFactory.cs:22`
- [ ] **Secret Manager:** Create new secrets with chosen naming (e.g., `dispo-D-10-60` or `D-10-60-dispo`) containing New Dispo user connection strings
- [ ] **New Dispo Backend:** Update `databaseIdentifier` values to include system qualifier
- [ ] **Cloud4Log:** Decide whether to keep current identifiers or adopt own qualifier

---

## Key Source Files

| File | Role |
|---|---|
| `CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContextFactory.cs` | Schema regex + context creation |
| `CALConsult.TMSBridge.API/Services/DbConnectionStringProvider.cs` | Secret Manager config lookup |
| `CALConsult.TMSBridge.API/Services/Caches/DbDataSourceCache.cs` | Connection pool cache |
| `CALConsult.TMSBridge.API/Infrastructure/GoogleSecretManager/.../GoogleSecretManagerConfigurationProvider.cs` | Loads all secrets at startup |
