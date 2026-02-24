# Database Connection Architecture

This is a .NET 8.0 application using a **multi-tenant database connection architecture** with Oracle.

## Technology Stack

- **ORM:** Entity Framework Core 8.0.8
- **Database:** Oracle (using `Oracle.ManagedDataAccess.Core` and `Oracle.EntityFrameworkCore`)

## Connection Flow

1. **Factory Pattern** - The application uses `IDigiLiSDbContextFactory` to create database contexts dynamically per tenant:
   - `Cloud4Log.Http/DigiLiS/Data/DbContexts/DigiLiSDbContextFactory.cs:15`

2. **Connection String Retrieval** - Connection strings are fetched from **Google Secret Manager** at runtime:
   ```csharp
   var connectionString = await googleSecretManagerService.GetLatestSecretVersionAsync(secretName);
   ```

3. **Oracle Connection Creation** - A new Oracle connection is created with the retrieved connection string:
   ```csharp
   var oracleConnection = new OracleConnection(connectionString);
   return optionsBuilder.UseOracle(oracleConnection).Options;
   ```

4. **Schema-aware DbContext** - The `DigiLiSDbContext` is created with a dynamic schema name (format: `DIGILIS{company}{branch}`):
   - `Cloud4Log.Http/DigiLiS/Data/DbContexts/DigiLiSDbContext.cs:3`

## Multi-tenant Pattern

The database identifier format is `O-{company}-{branch}` (e.g., "O-10-33"). This maps to:
- Secret name: `DIGILIS-10-33`
- Schema name: `DIGILIS1033`

## Key Components

| Component | Location |
|-----------|----------|
| Factory Interface | `DigiLiS/Data/DbContexts/Intefaces/IDigiLiSDbContextFactory.cs` |
| Factory Implementation | `DigiLiS/Data/DbContexts/DigiLiSDbContextFactory.cs` |
| DbContext | `DigiLiS/Data/DbContexts/DigiLiSDbContext.cs` |
| Cache Key Factory | `DigiLiS/Data/DbContexts/DigiLiSDbContextCacheKeyFactory.cs` |
| Secret Manager Service | `GoogleCloudPlatform/SecretManager/GoogleSecretManagerService.cs` |
| DI Setup | `Infrastructure/SetupExtensions/DigiLiSSetupExtension.cs` |

## Usage in Services

Services inject `IDigiLiSDbContextProvider` and get a context for a specific tenant:

```csharp
var digiLiSContext = await dbContextProvider.GetDbContext(databaseIdentifier);
```
