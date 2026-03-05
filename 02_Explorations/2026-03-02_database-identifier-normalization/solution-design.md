# Solution: Database Identifier Normalization in TMS Bridge

## Problem Statement

The TMS Bridge fails to resolve database identifier `10/1` correctly because it's not resilient to different formatting of branch numbers:
- `D-10-1` (no leading zero)
- `D-10-01` (with leading zero)

Currently, these resolve to **different** schemas (`tms101` vs `tms1001`), causing lookup failures.

## Target Solution

Make TMS Bridge resilient by **normalizing** database identifiers so that both formats resolve to the **same** TMS database:
- `D-10-1` → normalized to `D-10-1` → schema `tms101`
- `D-10-01` → normalized to `D-10-1` → schema `tms101`

## Implementation Strategy

### 1. Add Normalization Method

Create a static method to normalize database identifiers by removing leading zeros from company and branch numbers.

```csharp
/// <summary>
/// Normalizes database identifier by removing leading zeros from company and branch numbers.
/// Examples: D-10-01 -> D-10-1, D-10-1 -> D-10-1, O-05-003 -> O-5-3
/// </summary>
private static string NormalizeDatabaseIdentifier(string databaseIdentifier)
{
    var match = TmsSchemaNameRegex().Match(databaseIdentifier);
    if (!match.Success || match.Groups.Count != 3)
    {
        throw new FormatException(
            $"Database identifier {databaseIdentifier} does not match expected format {TmsSchemaNameRegex()}");
    }

    var prefix = databaseIdentifier[0]; // 'D' or 'O'
    var company = int.Parse(match.Groups[1].Value).ToString(); // Remove leading zeros
    var branch = int.Parse(match.Groups[2].Value).ToString();  // Remove leading zeros

    return $"{prefix}-{company}-{branch}";
}
```

### 2. Apply Normalization in CreateDbContext

Normalize the identifier at the **entry point** before any lookups:

```csharp
public T CreateDbContext<T>(string databaseIdentifier) where T : BranchDbContext
{
    // Normalize identifier to handle both D-10-1 and D-10-01
    var normalizedIdentifier = NormalizeDatabaseIdentifier(databaseIdentifier);

    var connectionString = connectionStringProvider.GetConnectionString(normalizedIdentifier);
    ArgumentException.ThrowIfNullOrEmpty(connectionString);

    var vendorName = connectionStringProvider.GetVendorName(connectionString);

    // Use normalized identifier for cache key
    var dataSource = cache.GetOrAdd(normalizedIdentifier, key => GetVendorDataSource(connectionString, vendorName));
    var databaseOptions = GetVendorContextOptions<T>(vendorName, dataSource);

    // Schema name construction will use already-normalized values
    var tmsSchema = GetTmsSchemaName(normalizedIdentifier, vendorName);

    var context = ActivatorUtilities.CreateInstance<T>(serviceProvider, databaseOptions, tmsSchema);
    logger.LogInformation("DbContext CREATED {hash} for identifier {identifier}",
        context.GetHashCode(), normalizedIdentifier);
    return context;
}
```

### 3. Simplify GetTmsSchemaName

The method can now trust that it receives normalized input:

```csharp
private static string GetTmsSchemaName(string normalizedDatabaseIdentifier, VendorName? vendorName)
{
    var match = TmsSchemaNameRegex().Match(normalizedDatabaseIdentifier);
    if (match.Success && match.Groups.Count == 3)
    {
        var vendorPrefix = vendorName switch
        {
            VendorName.POSTGRESQL => "tms",
            VendorName.ORACLE_DATABASE => "TMS",
            _ => throw new ArgumentException("TMS Bridge does not support data source.")
        };

        // Values are already normalized (no leading zeros)
        var company = match.Groups[1].Value;
        var branch = match.Groups[2].Value;

        return $"{vendorPrefix}{company}{branch}";
    }

    throw new FormatException(
        $"Normalized database identifier {normalizedDatabaseIdentifier} does not match expected format");
}
```

## Configuration Requirements

### Connection String Storage

Store connection strings using **normalized** identifiers (without leading zeros):

```json
{
  "ConnectionStrings": {
    "D-10-1": "Host=localhost;Database=tms101;...",
    "D-10-34": "Host=localhost;Database=tms1034;...",
    "D-28-20": "Host=localhost;Database=tms2820;..."
  }
}
```

### Google Secret Manager

Secrets should also use normalized keys:
- `D-10-1` (not `D-10-01`)
- `D-5-3` (not `D-05-003`)

## Testing Strategy

### Unit Tests to Add

```csharp
[TestMethod]
[DataRow("D-10-1", "D-10-1")]   // Already normalized
[DataRow("D-10-01", "D-10-1")]  // Remove leading zero from branch
[DataRow("D-05-1", "D-5-1")]    // Remove leading zero from company
[DataRow("D-05-003", "D-5-3")]  // Remove leading zeros from both
[DataRow("O-10-001", "O-10-1")] // Oracle prefix
public void NormalizeDatabaseIdentifier_VariousFormats_ReturnsNormalized(
    string input, string expected)
{
    var actual = BranchDbContextFactory.NormalizeDatabaseIdentifier(input);
    Assert.AreEqual(expected, actual);
}

[TestMethod]
[DataRow("D-10-1", "tms101")]
[DataRow("D-10-01", "tms101")]   // Both should result in same schema
public void CreateDbContext_WithDifferentFormats_ResolvesToSameSchema(
    string databaseIdentifier, string expectedSchema)
{
    // Setup mocks
    var connectionString = "Host=localhost;Database=tms101;...";

    _mockConnectionStringProvider
        .Setup(x => x.GetConnectionString("D-10-1")) // Normalized key
        .Returns(connectionString);

    _mockConnectionStringProvider
        .Setup(x => x.GetVendorName(connectionString))
        .Returns(VendorName.POSTGRESQL);

    var dbContext = _factory.CreateDbContext<BranchDbContext>(databaseIdentifier);

    var actualSchema = GetSchemaPropertyValue(dbContext);
    Assert.AreEqual(expectedSchema, actualSchema);
}
```

## Benefits

1. **Resilience**: Accepts both `D-10-1` and `D-10-01`
2. **Consistency**: Always resolves to the same database/schema
3. **Cache Efficiency**: Same cache entry for equivalent identifiers
4. **Backward Compatible**: Existing normalized identifiers continue to work
5. **Clear Errors**: Fails fast with clear message for invalid formats

## Migration Path

### Phase 1: Code Changes
1. Deploy normalization logic to TMS Bridge
2. Test with both formats in development

### Phase 2: Configuration Cleanup (Optional)
1. Audit all configuration sources (appsettings, Google Secret Manager)
2. Standardize to normalized format
3. Remove any duplicates with leading zeros

### Phase 3: Documentation
1. Update API documentation to specify normalized format
2. Document that both formats are accepted but normalized internally
3. Add examples to configuration guides

## Edge Cases Handled

| Input | Normalized | Schema | Notes |
|-------|------------|--------|-------|
| `D-10-1` | `D-10-1` | `tms101` | Already normalized |
| `D-10-01` | `D-10-1` | `tms101` | Leading zero removed |
| `D-5-3` | `D-5-3` | `tms53` | Single digits |
| `D-05-003` | `D-5-3` | `tms53` | Multiple leading zeros |
| `O-10-1` | `O-10-1` | `TMS101` | Oracle prefix |
| `D-99-999` | `D-99-999` | `tms99999` | Max values |

## Potential Issues

### Issue: Existing configurations with leading zeros
**Solution**: Normalization happens automatically - old configs work

### Issue: Cache keys change
**Solution**: Cache uses normalized key from the start, no migration needed

### Issue: Logging/debugging confusion
**Solution**: Log both original and normalized identifiers

## Recommendation

**Implement this solution immediately** as it:
- Solves the `10/1` resolution issue
- Prevents future similar issues
- Requires minimal configuration changes
- Is backward compatible
- Follows principle of robustness ("Be liberal in what you accept")
