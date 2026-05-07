# TMS Bridge Database Identifier Resolution

How the TMS Bridge resolves a `databaseIdentifier` string into a database connection with the correct schema and credentials.

---

## Overview

Every GraphQL query and mutation in the TMS Bridge requires a `databaseIdentifier` parameter. This identifier drives a five-step resolution chain that determines **which Secret Manager entry** (and therefore which database user credentials) and **which TMS schema** to use.

---

## Step 1: Identifier Enters via GraphQL

Every query and mutation accepts `databaseIdentifier` as a required `String!` parameter:

```graphql
mutation callSetTransportMode($databaseIdentifier: String!, $input: SetTransportModeInput!) {
    callSetTransportMode(databaseIdentifier: $databaseIdentifier, input: $input) { ... }
}
```

The identifier is passed to `IDbContextProvider.GetDbContext(databaseIdentifier)` which delegates to `BranchDbContextFactory`.

Cloud4Log sends the identifier via HTTP header (`DatabaseIdentifier`) rather than as a GraphQL variable, but it reaches the same resolution path.

## Step 2: Secret Manager Lookup (Connection String)

At startup, the bridge loads **all** secrets from a configured GCP project into the .NET configuration system:

```
GoogleSecretManagerConfigurationProvider.cs:
  Secret "D-10-60" -> Configuration key "ConnectionStrings:D-10-60"
  Secret "O-10-60" -> Configuration key "ConnectionStrings:O-10-60"
```

Each secret's value is a full connection string containing host, port, database, **username**, and **password**.

At request time, `DbConnectionStringProvider.GetConnectionString()` performs a direct key lookup:

```csharp
var connectionString = configuration.GetSection("ConnectionStrings")[databaseIdentifier];
```

**The identifier is used as-is** -- no transformation, no normalization. The identifier must exactly match a Secret Manager secret name.

## Step 3: Vendor Detection

The connection string is matched against regex patterns to determine if it's PostgreSQL or Oracle:

| Pattern | Vendor |
|---|---|
| `Host=...;Port=...;Database=...;Username=...;Password=...` | PostgreSQL |
| `User Id=...;Password=...;Data Source=...` | Oracle |

## Step 4: Schema Name Extraction

The identifier is parsed with a **strict regex** to derive the TMS schema name:

```csharp
[GeneratedRegex(@"^[DO]-(\d{1,2})-(\d{1,3})$")]
private static partial Regex TmsSchemaNameRegex();
```

This means:
- `D-10-60` --> schema `tms1060` (PostgreSQL) or `TMS1060` (Oracle)
- `O-10-60` --> schema `tms1060`
- The `D`/`O` prefix is discarded; only the numeric parts matter for schema resolution

## Step 5: Connection Pool Caching

A singleton `DbDataSourceCache` caches `DbDataSource` instances keyed by the **raw database identifier**:

```csharp
// ConcurrentDictionary<string, Lazy<DbDataSource>>
var lazyDataSource = _cache.GetOrAdd(databaseIdentifier, ...);
```

Same identifier = same connection pool. Different identifiers = separate pools, even if they point to the same schema.

---

## Resolution Flow

```
GraphQL Request
  |
  |  databaseIdentifier = "D-10-60"
  v
+----------------------------------+
|  DbConnectionStringProvider      |---- key: "D-10-60"
|  config["ConnectionStrings"]     |---- value: "Host=...;Username=dispo_user;Password=..."
|  ["D-10-60"]                     |
+----------------+-----------------+
                 |
                 v
+----------------------------------+
|  Vendor Detection                |
|  (regex on connection string)    |---- Result: POSTGRESQL
+----------------+-----------------+
                 |
                 v
+----------------------------------+
|  DbDataSourceCache               |
|  cache.GetOrAdd("D-10-60", ..)  |---- Creates or reuses connection pool
+----------------+-----------------+
                 |
                 v
+----------------------------------+
|  Schema Name Extraction          |
|  Regex: ^[DO]-(\d{1,2})-(\d{1,3})$
|  "D-10-60" -> "tms1060"         |
+----------------+-----------------+
                 |
                 v
        BranchDbContext
   (connected to tms1060 schema
    with dispo_user credentials)
```

---

## Key Implications

- **The database identifier is the single input** that determines both the credentials (via Secret Manager) and the schema (via regex). There is no separate mechanism to choose one independently of the other.
- **The identifier is an opaque string** for Secret Manager lookup and connection pool caching. Only schema name extraction applies a strict format check.
- **Connection pools are per-identifier**, not per-schema. Two different identifiers pointing to the same schema will maintain separate pools.

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
