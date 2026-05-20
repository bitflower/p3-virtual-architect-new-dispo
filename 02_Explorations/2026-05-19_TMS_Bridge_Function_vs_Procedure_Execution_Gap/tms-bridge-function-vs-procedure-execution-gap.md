# TMS Bridge Function vs Procedure Execution Gap

**Date:** 2026-05-19
**Status:** Exploration

---

## Verified Type Mismatches (Oracle ABN TMS1060, 2026-05-20)

Detected by `TmsBridgeDbVerifier --level 2` (Type check), which cross-validates the object kind declared in the TMS Bridge source code against the Oracle database catalog (`ALL_ARGUMENTS`).

| Object | TMS Bridge assumes | Oracle catalog reports | Impact |
|--------|-------------------|----------------------|--------|
| `PDIS_TRANSPORTORDER.GETDRIVER` | Function | Procedure | `ExecuteFunction` generates `SELECT` instead of `CALL` |
| `PDIS_TRANSPORTORDER.CREATETRANSPORTORDERFROMLEG` | Function | Procedure | Same — wrong SQL generated |
| `CAL_UNIFACE.LIST2DBTT` | TableFunction | Function | `OracleTableBuilder` wraps in `SELECT * FROM TABLE(...)` — type incorrect but may still work |
| `DISP_MDE_AH.SCANBARCODE` | Procedure | Function | `ExecuteProcedure` generates `CALL` instead of `SELECT` |

---

## Original User Input

> `CreateTransportOrderFromLeg` exists in Oracle as a **procedure** (no return value, uses OUT parameters) and in PostgreSQL as a **function** (with return value). The TMS Bridge handles these two DB object types through completely different internal code paths. Switching a DB routine from function to procedure (or vice versa) requires rewriting the mutation code, even though the business contract (inputs/outputs) hasn't changed.
>
> The central question: how are OUT parameters handled in the code, and why does this create a coupling between DB implementation detail and TMS Bridge mutation code?

---

## Summary

The TMS Bridge uses two separate execution paths for database functions and procedures. These paths impose **different result contracts** on mutation code:

- **Functions**: scalar return value, accessed positionally via `result.Rows[0].Field<object[]>("Result")[index]`
- **Procedures**: OUT parameters, accessed by name via `result.Rows[0].Field<T>("paramName")`

This means changing a DB routine from function to procedure (same inputs, same outputs) forces a **code change in the mutation layer** — not because the business logic changed, but because the internal execution mechanism changed.

---

## Analysis

### The Two Execution Paths

Both paths ultimately return a `DataTable`, but the **contract of that DataTable differs**:

| Aspect | Function Path | Procedure Path |
|--------|--------------|----------------|
| Executor | `SqlFunctionExecutor` | `SqlProcedureExecutor` |
| SQL syntax | `SELECT schema.func(params)` | `CALL schema.proc(params)` |
| .NET execution | `ExecuteScalarAsync()` | `ExecuteNonQueryAsync()` |
| Result shape | Single column `"Result"` containing an `object[]` | One column per OUT parameter, named after the parameter |
| Result access | **Positional**: `rowValues[0]`, `rowValues[1]`, ... | **Named**: `Field<T>("p_paramName")` |
| Parameter registration | Only `.AddInput()` | `.AddInput()` + `.AddOutput()` / `.AddInOut()` |

### How OUT Parameters Work (Procedure Path)

`SqlProcedureExecutor` (lines 9-40):

1. Before execution: collects all `DbParameter` objects with `Direction.Output` or `Direction.InputOutput`
2. Creates DataTable columns named after each output parameter
3. Calls `ExecuteNonQueryAsync()` — the DB engine populates the parameter values
4. Reads back each output parameter's `.Value` into the DataTable row

The mutation accesses results by parameter name:
```csharp
long tourpointId = Convert.ToInt64(result.Rows[0].Field<decimal>("p_new_tourpoint_tix"));
```

### How Function Return Works (Function Path)

`SqlFunctionExecutor` (lines 9-29):

1. Calls `ExecuteScalarAsync()` — returns a single scalar value
2. Wraps it in a DataTable with a single column named `"Result"`

The mutation accesses results by position in the scalar array:
```csharp
var rowValues = result.Rows[0].Field<object[]>("Result");
var transportOrderId = Convert.ToInt64(rowValues[0]);
var transportOrderNumber = Convert.ToInt64(rowValues[1]);
```

### The Coupling Problem

When `CreateTransportOrderFromLeg` changes from function to procedure, three things must change in the mutation:

1. **Parameter registration** — add 7x `.AddOutput(name, typeof(T))` calls for each return value
2. **OperationType** — change `OperationType.Function` → `OperationType.Procedure`
3. **Result parsing** — rewrite from positional array access to named parameter access

None of these changes reflect a business logic change. The inputs are the same, the outputs are the same, the side effects are the same. The mutation code changes purely because the **DB-level implementation detail** (function vs. procedure) leaked into the application layer.

---

## Source Code Evidence

### SqlFunctionExecutor

**File:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Services/Function/SqlFunctionExecutor.cs`

```csharp
public async Task<DataTable> ExecuteCommandAsync(DbCommand command)
{
    var result = await command.ExecuteScalarAsync();
    var dataTable = new DataTable();

    if (result is DBNull)
        dataTable.Columns.Add("Result");
    else
        dataTable.Columns.Add("Result", result.GetType());

    var row = dataTable.NewRow();
    row[0] = result;
    dataTable.Rows.Add(row);
    return dataTable;
}
```

### SqlProcedureExecutor

**File:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Services/Procedure/SqlProcedureExecutor.cs`

```csharp
public async Task<DataTable> ExecuteCommandAsync(DbCommand command)
{
    var dataTable = new DataTable();

    var outputParameters = command.Parameters
        .Cast<DbParameter>()
        .Where(p => p.Direction is ParameterDirection.Output or ParameterDirection.InputOutput)
        .ToList();

    dataTable.Columns.AddRange(outputParameters
        .Select(x => new DataColumn(x.ParameterName, x.Value?.GetType() ?? typeof(object)))
        .ToArray());

    await command.ExecuteNonQueryAsync();

    var row = dataTable.NewRow();
    outputParameters.ForEach(x => row[x.ParameterName] = x.Value);
    dataTable.Rows.Add(row);
    return dataTable;
}
```

### CreateTransportOrderFromLeg (current — Function)

**File:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/CreateTransportOrderFromLeg/CreateTransportOrderFromLegMutation.cs`

```csharp
// Parameter setup: only inputs
var functionParameters = parameterBuilder
    .AddInput("company", input.Company)
    .AddInput("branch", input.Branch)
    .AddInput("performanceDate", ...)
    .AddInput("transportMode", ...)
    .AddInput("regionId", DBNull.Value)
    .AddInput("shipmentId", input.ShipmentId)
    .AddInput("legType", input.LegType)
    .AddInput("mode", DBNull.Value)
    .Build();

// Execution: as Function
var result = await executor.ExecuteRoutineAsync(dbContext, OperationType.Function, routine);

// Result parsing: positional array access
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

### Example Procedure with OUT Parameters (existing pattern)

**File:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTourpoint/AddTourpoint/AddTourpointMutation.cs`

```csharp
// Parameter setup: inputs + output
var procedureParameters = parameterBuilder
    .AddInput("p_transportorderid", input.TransportOrderId)
    .AddInput("p_tourpointtype", input.TourpointType)
    .AddOutput("p_new_tourpoint_tix", typeof(long))   // <-- OUT parameter
    .Build();

// Execution: as Procedure
var result = await executor.ExecuteRoutineAsync(dbContext, OperationType.Procedure, routine);

// Result parsing: named access
long tourpointId = Convert.ToInt64(result.Rows[0].Field<decimal>("p_new_tourpoint_tix"));
```

### Existing Mutations Using OUT Parameters

| Mutation | OUT Parameters |
|----------|---------------|
| AddTourpointMutation | 1 (`p_new_tourpoint_tix`) |
| CreateAndAddLegMutation | 5 |
| AssignLotToTransportOrderMutation | 4 |
| CreateTransportOrderFromLotMutation | 4 (deprecated) |
| DispMdeAhStartEntlandungMutation | 2 (`o_vorgang_tix`, `o_erg`) |
| DispMdeAhEndeEntladungMutation | 1 |
| DispMdeAhScanBarcodeMutation | 1 |
| DispMdeEbAbschlNVEMutation | 1 |
| DispMdeEbEndeEntladungMutation | 1 |

---

## Findings

### 1. The TMS Bridge leaks DB implementation detail into mutation code

The distinction between function and procedure is a **database-level concern** (how values are returned), not a business concern (what values are returned). The TMS Bridge forces every mutation to know and code against this distinction.

### 2. Both executors return DataTable but with incompatible contracts

Both `SqlFunctionExecutor` and `SqlProcedureExecutor` implement `ISqlCommandExecutor<DataTable>`, suggesting they're interchangeable. They're not — the DataTable structure differs fundamentally (single "Result" column vs. named columns per OUT parameter).

### 3. Switching types requires mutation rewrite, not configuration

Changing `CreateTransportOrderFromLeg` from function to procedure means:
- Adding 7 `.AddOutput()` parameter registrations
- Changing `OperationType.Function` → `OperationType.Procedure`
- Rewriting result parsing from positional to named access
- Updating unit tests

This is a code change across multiple files for what should be a transparent infrastructure concern.

### 4. The problem surfaces when DB schemas evolve

The TMS Database schemas are always kept in sync between Oracle and PostgreSQL — a routine is always function/function or procedure/procedure across both engines. When the DB team decides to change a routine from function to procedure (e.g., `CreateTransportOrderFromLeg` is currently a function in PostgreSQL but already a procedure in Oracle, meaning PostgreSQL needs to align), the TMS Bridge mutation code must be rewritten even though the business contract hasn't changed. The coupling turns a schema-level refactoring decision into an application-level code change.

---

## Proposed Solution

A unified execution contract that makes mutations agnostic to whether the DB routine is a function or procedure. Full PRD with code snippets, before/after comparison, backward compatibility strategy, edge cases, and implementation roadmap:

**[PRD: Unified Routine Execution Contract](./prd-unified-routine-execution-contract.md)**

Core idea: Mutations declare expected outputs via `ExpectOutput(name, type)`. The `RoutineExecutor` auto-detects the operation type and normalizes the result into a DataTable with named columns — regardless of whether the underlying DB routine is a function or procedure.

---

## Questions/Open Items

1. **Team alignment**: Does the development team agree that this coupling is worth addressing, or is the current approach acceptable given the low frequency of function-to-procedure changes?
2. **Impact assessment**: How many current mutations would benefit from a unified execution path? (At least `CreateTransportOrderFromLeg` is affected now; others may follow as Oracle compatibility is addressed.)
3. **Backward compatibility**: The PRD proposes incremental migration — existing mutations continue to work unchanged. Is this acceptable, or should all mutations migrate at once?
4. **Priority**: Should this be addressed before or after the Oracle/PostgreSQL alignment effort (GoLive 1060)?

---

## Related Files

| File | Role |
|------|------|
| `CALConsult.TMSBridge.API/Services/Function/SqlFunctionExecutor.cs` | Function execution path |
| `CALConsult.TMSBridge.API/Services/Procedure/SqlProcedureExecutor.cs` | Procedure execution path |
| `CALConsult.TMSBridge.API/Services/RoutineExecutor.cs` | Unified dispatcher (delegates to keyed executors) |
| `CALConsult.TMSBridge.API/Services/Commands/Factories/DbCommandFactory.cs` | Builder selection per vendor + operation type |
| `CALConsult.TMSBridge.API/Shared/Utils/OperationType.cs` | Operation type constants (Function, Procedure, Table) |
| `CALConsult.TMSBridge.API/Shared/Utils/RoutineParameterBuilder.cs` | Parameter builder (AddInput, AddOutput, AddInOut) |
| `CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/CreateTransportOrderFromLeg/` | Affected mutation |

---

## Related User Stories/Tasks

- Related to Oracle/PostgreSQL schema alignment effort (GoLive 1060)
- Affects any DB routine that changes from function to procedure (or vice versa) during schema evolution

---

<div align="center">Created and maintained by <strong>Virtual Architect</strong></div>
