# PRD: Unified Routine Execution Contract

**Date:** 2026-05-19
**Status:** Draft
**Component:** TMS Bridge (`Code/Disposition-Abstraction-Layer`)

---

## Problem Statement

The TMS Bridge exposes two incompatible internal execution paths for database routines:

- **Functions** (`SqlFunctionExecutor`): returns `DataTable` with single column `"Result"` containing `object[]`, accessed **positionally**
- **Procedures** (`SqlProcedureExecutor`): returns `DataTable` with **named columns** per OUT parameter, accessed **by name**

Switching a DB routine from function to procedure (or vice versa) requires **rewriting mutation code** for parameter registration, operation type selection, and result parsing — even when the business contract (same inputs, same outputs) hasn't changed.

**Real case:** `CreateTransportOrderFromLeg` is currently a function but needs to become a procedure (it is already a procedure in Oracle, and the schemas are always kept in sync). The mutation code is written for the function path. Changing the DB object type means rewriting the mutation for no business reason.

---

## Affected Mutations

| Mutation | Current Type | OUT Params | Result Access |
|----------|-------------|------------|---------------|
| CreateTransportOrderFromLeg | Function | 0 (scalar array) | Positional `rowValues[0..6]` |
| CreateAndAddLeg | Procedure | 5 | Named `Field<T>("name")` |
| AssignLotToTransportOrder | Procedure | 4 | Named |
| CreateTransportOrderFromLot | Procedure | 4 (deprecated) | Named |
| AddTourpoint | Procedure | 1 | Named |
| DispMdeAhStartEntladung | Procedure | 2 | Named |
| DispMdeAhEndeEntladung | Procedure | 1 | Named |
| DispMdeAhScanBarcode | Procedure | 1 | Named |
| DispMdeEbAbschlNVE | Procedure | 1 | Named |
| DispMdeEbEndeEntladung | Procedure | 1 | Named |

---

## Current Architecture

### Two Execution Paths

```
Mutation
  |
  +-- OperationType.Function ──> SqlFunctionExecutor
  |     SQL: SELECT schema.func(params)
  |     .NET: ExecuteScalarAsync()
  |     Result: DataTable["Result"] = object[]
  |     Access: rowValues[0], rowValues[1], ...
  |
  +-- OperationType.Procedure ──> SqlProcedureExecutor
        SQL: CALL schema.proc(params)
        .NET: ExecuteNonQueryAsync()
        Result: DataTable["paramName1", "paramName2", ...]
        Access: Field<T>("paramName1"), Field<T>("paramName2"), ...
```

### Function-Based Mutation (Current CreateTransportOrderFromLeg)

```csharp
// Only input parameters — no output declaration
var functionParameters = parameterBuilder
    .AddInput("company", input.Company)
    .AddInput("branch", input.Branch)
    .AddInput("performanceDate", DateTime.SpecifyKind(input.PerformanceDate, DateTimeKind.Unspecified))
    .AddInput("transportMode", input.TransportMode ?? (object)DBNull.Value)
    .AddInput("regionId", DBNull.Value)
    .AddInput("shipmentId", input.ShipmentId)
    .AddInput("legType", input.LegType)
    .AddInput("mode", DBNull.Value)
    .Build();

var routine = new RoutineDto
{
    RoutineName = "pdis_transportorder.createtransportorderfromleg",
    Parameters = functionParameters
};

// Hardcoded to Function
var result = await executor.ExecuteRoutineAsync(dbContext, OperationType.Function, routine);

// Positional array access — breaks if DB changes to procedure
var rowValues = result.Rows[0].Field<object[]>("Result");
var response = new CreateTransportOrderFromLegResponse
{
    TransportOrderId = Convert.ToInt64(rowValues[0]),
    TransportOrderNumber = Convert.ToInt64(rowValues[1]),
    PickupPointId = Convert.ToInt64(rowValues[2]),
    IsNewPickupPoint = Convert.ToBoolean(rowValues[3]),
    DeliveryPointId = Convert.ToInt64(rowValues[4]),
    IsNewDeliveryPoint = Convert.ToBoolean(rowValues[5]),
    LegId = Convert.ToInt64(rowValues[6]),
};
```

### Procedure-Based Mutation (Current CreateAndAddLeg)

```csharp
// Inputs AND explicit OUT parameters
var procedureParameters = parameterBuilder
    .AddInput("transportorderid", input.TransportOrderId)
    .AddInput("shipmentId", input.ShipmentId)
    .AddInput("legType", input.LegType)
    .AddInput("mode", DBNull.Value)
    .AddOutput("pickuppointid", typeof(long))
    .AddOutput("isnewpickuppoint", typeof(bool))
    .AddOutput("deliverypointid", typeof(long))
    .AddOutput("isnewdeliverypoint", typeof(bool))
    .AddOutput("legid", typeof(long))
    .Build();

var routine = new RoutineDto
{
    RoutineName = "pdis_transportorder.createandaddleg",
    Parameters = procedureParameters
};

// Hardcoded to Procedure
var result = await executor.ExecuteRoutineAsync(dbContext, OperationType.Procedure, routine);

// Named column access — breaks if DB changes to function
var response = new CreateAndAddLegResponse
{
    PickupPointId = Convert.ToInt64(result.Rows[0].Field<decimal>("pickuppointid")),
    IsNewPickupPoint = result.Rows[0].Field<bool>("isnewpickuppoint"),
    DeliveryPointId = Convert.ToInt64(result.Rows[0].Field<decimal>("deliverypointid")),
    IsNewDeliveryPoint = result.Rows[0].Field<bool>("isnewdeliverypoint"),
    LegId = Convert.ToInt64(result.Rows[0].Field<decimal>("legid")),
};
```

### The Contract Mismatch

Both executors implement `ISqlCommandExecutor<DataTable>`, suggesting they are interchangeable. They are not — the DataTable structure differs fundamentally:

| | Function | Procedure |
|--|----------|-----------|
| **Columns** | 1 (`"Result"`) | N (one per OUT param) |
| **Values** | Packed `object[]` in single cell | One value per cell |
| **Access** | Positional index | Parameter name |
| **Type info** | Lost (all `object`) | Preserved in column type |

---

## Proposed Solution: Declarative Output Contract

### Design Principle

**Mutations declare what outputs they expect (name + type). The execution layer figures out how to get them — function scalar, procedure OUT params, or any future mechanism.**

### Constraint: Schemas Are Always Aligned

The TMS Database schemas are always kept in sync between Oracle and PostgreSQL — a routine is always function/function or procedure/procedure across both engines. The problem is not vendor divergence but **schema evolution**: when the DB team changes a routine's type, the TMS Bridge mutation code must change too.

### Target Architecture

```
Mutation
  |
  +-- Declares: inputs + expected outputs
  |
  +-- RoutineExecutor (auto-detects operation type)
        |
        +-- Function path: ExecuteScalar → NormalizeResult → named DataTable
        +-- Procedure path: ExecuteNonQuery → OUT params → named DataTable
        |
        Result: ALWAYS DataTable["output1", "output2", ...]
        Access: ALWAYS Field<T>("outputName")
```

### 1. New API: `ExpectOutput()`

Add to `RoutineParameterBuilder`:

```csharp
public class RoutineParameterBuilder
{
    private readonly List<RoutineParameter> _parameters = new();
    private readonly List<OutputExpectation> _outputs = new();

    // Existing methods unchanged
    public RoutineParameterBuilder AddInput<T>(string name, T value) { /* unchanged */ }
    public RoutineParameterBuilder AddOutput(string name, Type outputType) { /* unchanged */ }
    public RoutineParameterBuilder AddInOut<T>(string name, T? value) { /* unchanged */ }

    // NEW: declare expected outputs without committing to function/procedure
    public RoutineParameterBuilder ExpectOutput(string name, Type outputType)
    {
        _outputs.Add(new OutputExpectation { Name = name, Type = outputType });
        return this;
    }

    // NEW: returns setup including output expectations
    public RoutineParameterSetup BuildSetup()
    {
        return new RoutineParameterSetup
        {
            Parameters = _parameters.ToArray(),
            ExpectedOutputs = _outputs.ToArray()
        };
    }

    // Existing Build() unchanged for backward compatibility
    public RoutineParameter[] Build() => _parameters.ToArray();
}

public record OutputExpectation
{
    public required string Name { get; set; }
    public required Type Type { get; set; }
}

public record RoutineParameterSetup
{
    public RoutineParameter[] Parameters { get; set; } = [];
    public OutputExpectation[] ExpectedOutputs { get; set; } = [];
}
```

### 2. Extended RoutineDto

```csharp
public record RoutineDto
{
    public required string RoutineName { get; set; }
    public RoutineParameter[] Parameters { get; set; } = [];
    public DbTransaction? Transaction { get; set; }
    public string? Schema { get; set; }
    public OutputExpectation[] ExpectedOutputs { get; set; } = []; // NEW
}
```

### 3. Auto-Detection + Normalization in RoutineExecutor

```csharp
public class RoutineExecutor : IRoutineExecutor
{
    // Auto-detect based on whether OUT parameters are declared
    private static string DetermineOperationType(RoutineDto routine)
    {
        var hasOutputParameters = routine.Parameters
            .Any(p => p.ParameterDirection is ParameterDirection.Output
                                           or ParameterDirection.InputOutput);

        return hasOutputParameters ? OperationType.Procedure : OperationType.Function;
    }

    public async Task<DataTable> ExecuteRoutineAsync(
        DbContext dbContext,
        string? operationType, // NULLABLE — auto-detect when null
        RoutineDto routine)
    {
        operationType ??= DetermineOperationType(routine);

        // ... existing transaction/savepoint/connection logic unchanged ...

        DataTable result = await sqlRoutineExecutor.ExecuteCommandAsync(routineCommand);

        // NEW: normalize function results to match expected outputs
        if (routine.ExpectedOutputs.Length > 0 && operationType == OperationType.Function)
        {
            result = NormalizeFunctionResult(result, routine.ExpectedOutputs);
        }

        return result;
    }

    private static DataTable NormalizeFunctionResult(
        DataTable result,
        OutputExpectation[] expectedOutputs)
    {
        var normalized = new DataTable();

        foreach (var output in expectedOutputs)
        {
            var column = normalized.Columns.Add(output.Name, output.Type);
            column.AllowDBNull = true;
        }

        var functionResult = result.Rows[0].Field<object>("Result");

        if (functionResult is object[] compositeResult)
        {
            if (compositeResult.Length != expectedOutputs.Length)
                throw new InvalidOperationException(
                    $"Function returned {compositeResult.Length} values " +
                    $"but {expectedOutputs.Length} outputs were expected");

            var row = normalized.NewRow();
            for (int i = 0; i < expectedOutputs.Length; i++)
            {
                row[expectedOutputs[i].Name] = compositeResult[i] ?? DBNull.Value;
            }
            normalized.Rows.Add(row);
        }
        else
        {
            if (expectedOutputs.Length != 1)
                throw new InvalidOperationException(
                    $"Function returned single value " +
                    $"but {expectedOutputs.Length} outputs were expected");

            var row = normalized.NewRow();
            row[expectedOutputs[0].Name] = functionResult ?? DBNull.Value;
            normalized.Rows.Add(row);
        }

        return normalized;
    }

    // Error handling path stays unchanged — it directly uses
    // OperationType.Function and SqlFunctionExecutor for
    // pdis_transportorder.geterrormessage (internal infrastructure,
    // not affected by this change)
}
```

### 4. IRoutineExecutor Interface Change

```csharp
public interface IRoutineExecutor
{
    // operationType becomes nullable — null means auto-detect
    Task<DataTable> ExecuteRoutineAsync(
        DbContext dbContext,
        string? operationType,
        RoutineDto routine);
}
```

---

## Before / After: CreateTransportOrderFromLeg

### Before (coupled to Function)

```csharp
var functionParameters = parameterBuilder
    .AddInput("company", input.Company)
    .AddInput("branch", input.Branch)
    .AddInput("performanceDate", DateTime.SpecifyKind(input.PerformanceDate, DateTimeKind.Unspecified))
    .AddInput("transportMode", input.TransportMode ?? (object)DBNull.Value)
    .AddInput("regionId", DBNull.Value)
    .AddInput("shipmentId", input.ShipmentId)
    .AddInput("legType", input.LegType)
    .AddInput("mode", DBNull.Value)
    .Build();

var routine = new RoutineDto
{
    RoutineName = "pdis_transportorder.createtransportorderfromleg",
    Parameters = functionParameters
};

var result = await executor.ExecuteRoutineAsync(dbContext, OperationType.Function, routine);

var rowValues = result.Rows[0].Field<object[]>("Result");
var response = new CreateTransportOrderFromLegResponse
{
    TransportOrderId = Convert.ToInt64(rowValues[0]),
    TransportOrderNumber = Convert.ToInt64(rowValues[1]),
    PickupPointId = Convert.ToInt64(rowValues[2]),
    IsNewPickupPoint = Convert.ToBoolean(rowValues[3]),
    DeliveryPointId = Convert.ToInt64(rowValues[4]),
    IsNewDeliveryPoint = Convert.ToBoolean(rowValues[5]),
    LegId = Convert.ToInt64(rowValues[6]),
};
```

### After (agnostic)

```csharp
var setup = parameterBuilder
    .AddInput("company", input.Company)
    .AddInput("branch", input.Branch)
    .AddInput("performanceDate", DateTime.SpecifyKind(input.PerformanceDate, DateTimeKind.Unspecified))
    .AddInput("transportMode", input.TransportMode ?? (object)DBNull.Value)
    .AddInput("regionId", DBNull.Value)
    .AddInput("shipmentId", input.ShipmentId)
    .AddInput("legType", input.LegType)
    .AddInput("mode", DBNull.Value)
    .ExpectOutput("transportOrderId", typeof(long))
    .ExpectOutput("transportOrderNumber", typeof(long))
    .ExpectOutput("pickupPointId", typeof(long))
    .ExpectOutput("isNewPickupPoint", typeof(bool))
    .ExpectOutput("deliveryPointId", typeof(long))
    .ExpectOutput("isNewDeliveryPoint", typeof(bool))
    .ExpectOutput("legId", typeof(long))
    .BuildSetup();

var routine = new RoutineDto
{
    RoutineName = "pdis_transportorder.createtransportorderfromleg",
    Parameters = setup.Parameters,
    ExpectedOutputs = setup.ExpectedOutputs
};

var result = await executor.ExecuteRoutineAsync(dbContext, null, routine);

var response = new CreateTransportOrderFromLegResponse
{
    TransportOrderId = result.Rows[0].Field<long>("transportOrderId"),
    TransportOrderNumber = result.Rows[0].Field<long>("transportOrderNumber"),
    PickupPointId = result.Rows[0].Field<long>("pickupPointId"),
    IsNewPickupPoint = result.Rows[0].Field<bool>("isNewPickupPoint"),
    DeliveryPointId = result.Rows[0].Field<long>("deliveryPointId"),
    IsNewDeliveryPoint = result.Rows[0].Field<bool>("isNewDeliveryPoint"),
    LegId = result.Rows[0].Field<long>("legId"),
};
```

### What Changed

| Aspect | Before | After |
|--------|--------|-------|
| Output declaration | None (implicit in positional access) | Explicit via `ExpectOutput()` |
| Operation type | Hardcoded `OperationType.Function` | `null` (auto-detected) |
| Result access | `Field<object[]>("Result")[index]` | `Field<T>("name")` |
| Schema evolution | Rewrite mutation when type changes | No mutation change needed |
| Type safety | Runtime cast from `object` | Named + typed column access |

---

## Backward Compatibility

### Coexistence Strategy

Old and new patterns coexist — no big-bang migration required.

**Old mutation (unchanged, still works):**

```csharp
var parameters = parameterBuilder
    .AddInput("param", value)
    .Build(); // Returns RoutineParameter[] as before

var routine = new RoutineDto
{
    RoutineName = "legacy_function",
    Parameters = parameters
    // ExpectedOutputs defaults to empty array
};

// Explicit operation type — works as before
var result = await executor.ExecuteRoutineAsync(dbContext, OperationType.Function, routine);

// Legacy positional access — works because NormalizeResult
// only runs when ExpectedOutputs.Length > 0
var value = result.Rows[0].Field<object[]>("Result")[0];
```

**New mutation (coexists):**

```csharp
var setup = parameterBuilder
    .AddInput("param", value)
    .ExpectOutput("outputName", typeof(long))
    .BuildSetup();

var routine = new RoutineDto
{
    RoutineName = "new_routine",
    Parameters = setup.Parameters,
    ExpectedOutputs = setup.ExpectedOutputs
};

// Auto-detected
var result = await executor.ExecuteRoutineAsync(dbContext, null, routine);
var value = result.Rows[0].Field<long>("outputName");
```

### Migration Guard Rail

`NormalizeResult` only activates when **both conditions** are true:
1. `ExpectedOutputs.Length > 0` (mutation opted in)
2. `operationType == OperationType.Function` (needs transformation)

Procedure-based mutations already return named columns — normalization is a no-op for them.

---

## Edge Cases

### Error Handling Path

`RoutineExecutor` catches exceptions and calls `pdis_transportorder.geterrormessage` as a Function:

```csharp
catch (Exception ex)
{
    var errorRoutine = new RoutineDto
    {
        RoutineName = "pdis_transportorder.geterrormessage",
        Parameters = []
    };

    await using var errorMessageCommand = commandFactory.CreateCommand(
        dbContext, errorRoutine, OperationType.Function);

    var sqlFunctionExecutor = serviceProvider
        .GetKeyedService<ISqlCommandExecutor<DataTable>>(OperationType.Function);

    var errorResult = await sqlFunctionExecutor.ExecuteCommandAsync(errorMessageCommand);
    var errorMessage = errorResult.Rows[0].Field<string>("Result") ?? ex.Message;

    throw new InvalidOperationException(errorMessage);
}
```

**No change needed.** This code bypasses `ExecuteRoutineAsync` entirely — it directly calls `SqlFunctionExecutor`. It has no `ExpectedOutputs` and uses the legacy `"Result"` column. It's internal infrastructure, not a mutation.

### Procedures Without OUT Parameters (Fire-and-Forget)

Some procedures have no outputs (e.g., `StaysLoadedMutation`). These continue to work unchanged — `ExpectedOutputs` stays empty, no normalization runs, result is discarded.

---

## Alternatives Considered

### A: Result Mapper Layer

Introduce `IResultMapper<TResponse>` per mutation that knows how to extract typed responses from both function and procedure results.

```csharp
public interface IResultMapper<TResponse>
{
    TResponse Map(DataTable result, string operationType);
}
```

**Rejected:** Still requires knowing the operation type. More boilerplate (one mapper per mutation) without solving the fundamental coupling.

### B: Keep Separate APIs, Document Convention

Accept the gap and document that mutations must be rewritten when the DB object type changes.

**Rejected:** The Oracle/PostgreSQL alignment effort will trigger this repeatedly. The cost compounds.

---

## Implementation Scope

### Phase 1: Foundation (non-breaking)

| File | Change |
|------|--------|
| `Shared/Utils/RoutineParameterBuilder.cs` | Add `ExpectOutput()`, `BuildSetup()`, new DTOs |
| `Shared/Dtos/RoutineExecutor/RoutineDto.cs` | Add `ExpectedOutputs` property |
| `Services/Interfaces/IRoutineExecutor.cs` | Make `operationType` nullable |
| `Services/RoutineExecutor.cs` | Add `DetermineOperationType()`, `NormalizeFunctionResult()` |

No existing code breaks. All existing mutations continue to work as-is.

### Phase 2: Incremental Migration

Migrate mutations one-by-one. Priority order:

1. `CreateTransportOrderFromLeg` — the motivating case
2. `CreateAndAddLeg` — verify procedure path unchanged
3. Remaining mutations as needed

### Phase 3: Cleanup (optional, future)

- Deprecate explicit `operationType` parameter
- Remove positional array access from conventions
- Consolidate `Build()` and `BuildSetup()`

---

## Files Referenced

| File | Role |
|------|------|
| `Services/Function/SqlFunctionExecutor.cs` | Function execution: `ExecuteScalarAsync` |
| `Services/Procedure/SqlProcedureExecutor.cs` | Procedure execution: `ExecuteNonQueryAsync` + OUT params |
| `Services/RoutineExecutor.cs` | Dispatcher + transaction management |
| `Services/Commands/Factories/DbCommandFactory.cs` | Builder selection per vendor + type |
| `Services/Commands/Builders/Postgres/PostgreFunctionBuilder.cs` | `SELECT func(params)` |
| `Services/Commands/Builders/Postgres/PostgreProcedureBuilder.cs` | `CALL proc(params)` |
| `Services/Commands/Builders/Oracle/OracleFunctionBuilder.cs` | `SELECT schema.func(params) FROM dual` |
| `Services/Commands/Builders/Oracle/OracleProcedureBuilder.cs` | `CALL schema.proc(params)` |
| `Shared/Utils/OperationType.cs` | Constants: Function, Procedure, Table |
| `Shared/Utils/RoutineParameterBuilder.cs` | Parameter builder: AddInput, AddOutput, AddInOut |
| `Mutations/.../CreateTransportOrderFromLegMutation.cs` | Affected: function, 7 return values |
| `Mutations/.../CreateAndAddLegMutation.cs` | Reference: procedure, 5 OUT params |
| `Mutations/.../AssignLotToTransportOrderMutation.cs` | Reference: procedure, 4 OUT params |

---

*Analysis by Virtual Architect*
