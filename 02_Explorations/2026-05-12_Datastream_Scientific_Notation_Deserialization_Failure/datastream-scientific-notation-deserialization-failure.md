# Datastream Scientific Notation Deserialization Failure

**Date:** 2026-05-12
**Status:** Exploration
**Affected Component:** Cloud Function `new-dispo-filter-shipment-records-abn1034`
**Secondary Risk:** New Dispo Backend CDC subscriber

---

## Original Error

```
Newtonsoft.Json.JsonReaderException: Input string '6E+1' is not a valid integer.
Path 'payload.tran_art', line 1, position 5878.
```

Occurred 2026-05-12T09:18:23Z in the FilterShipments Cloud Function when deserializing a CDC record from the Datastream bucket.

---

## Summary

Google Datastream serializes PostgreSQL `numeric(2,0)` values using scientific notation in JSON (e.g., `60` becomes `6E+1`). The C# DTO maps `tran_art` as `int?`, but Newtonsoft.Json's integer parser rejects scientific notation. The column has **always** been `numeric(2,0)` in AlloyDB -- there was no schema change. **Hypothesis:** The trigger may be PR #519 on `tms-alloydb-schema` (merged 2026-05-12), which fixed the `SetTransportMode` function and may have caused a new write of `tran_art = 60` -- this has not been confirmed.

---

## Data Pipeline

```
AlloyDB (sendung table)
  | column: tran_art numeric(2,0), value: 60
  v
PostgreSQL Logical Replication (pgoutput plugin)
  | replication slot captures WAL change
  v
Google Datastream (managed CDC service)
  | serializes numeric(2,0) value 60 as JSON number 6E+1
  v
Cloud Storage Bucket (JSONL, one record per line)
  | file contains: {..., "tran_art": 6E+1, ...}
  v
Cloud Function: FilterShipmentsTrigger
  | JsonConvert.DeserializeObject<GoogleBucketShipmentData>()
  | int? cannot parse "6E+1" --> CRASH
  v
PubSub Topic (never reached)
  v
Backend CDC Subscriber (would also crash -- int TransportMode, non-nullable)
```

---

## Root Cause Analysis

### Why scientific notation?

PostgreSQL's `numeric` type is a **variable-length decimal type**, not a native integer. Even `numeric(2,0)` with zero decimal places is stored internally as a decimal. When `pgoutput` emits change data, Google Datastream converts the PostgreSQL numeric representation to a JSON number. Datastream is free to use any valid JSON number format, including scientific notation.

`6E+1` is mathematically identical to `60` and is valid JSON per RFC 8259. The problem is entirely on the consumer side.

### Why did it work before?

Two possible explanations:

1. **Hypothesis: Value `60` was not written recently.** The `SetTransportMode` function supports values `10, 20, 21, 22, 23, 24, 25, 26, 27, 28, 60`. If `tran_art = 60` was rarely or never set for shipments flowing through this branch (ABN1034), Datastream never produced `6E+1` for this field. PR #519 (merged 2026-05-12, same day as the error) fixed `SetTransportMode` and may have caused a new `tran_art = 60` write. **This correlation has not been confirmed.**

2. **Datastream serialization is non-deterministic for numeric types.** The same value may be serialized differently depending on internal buffer states, batch sizes, or Datastream version. Google periodically updates managed services.

### Why doesn't it affect all numeric columns?

The C# DTOs already map most `numeric(N,0)` columns to `double`, which handles scientific notation natively. Only `tran_art` and `tour` are mapped to `int?`/`int` -- likely an oversight from when the DTOs were created.

---

## Proof

Unit tests added to `GoogleBucketShipmentDataDeserializationTests` exercise the actual `JsonConvert.DeserializeObject<GoogleBucketFileContentDto<GoogleBucketShipmentData>>()` call with JSON payloads mimicking Datastream output. Results confirm the deserialization fails for all non-plain-integer numeric representations:

| Test | JSON value for `tran_art` | Result |
|---|---|---|
| `Deserialize_TranArt_PlainInteger_Succeeds` | `60` | **PASS** |
| `Deserialize_TranArt_Null_Succeeds` | `null` | **PASS** |
| `Deserialize_TranArt_ScientificNotation_Succeeds` | `6E+1` | **FAIL** -- `JsonReaderException: Input string '6E+1' is not a valid integer` |
| `Deserialize_TranArt_ScientificNotationLowercase_Succeeds` | `6e+1` | **FAIL** -- `JsonReaderException: Input string '6e+1' is not a valid integer` |
| `Deserialize_Tour_ScientificNotation_Succeeds` | `1.2E+2` (tour field) | **FAIL** -- `JsonReaderException: Input string '1.2E+2' is not a valid integer` |
| `Deserialize_NumericFields_WithDecimalPoint_Succeeds` | `60.0` | **FAIL** -- `JsonReaderException: Input string '60.0' is not a valid integer` |

Key takeaway: Newtonsoft.Json's `int`/`int?` parser rejects **any** JSON number that is not a plain digit string. Scientific notation (`6E+1`), lowercase scientific notation (`6e+1`), and decimal notation (`60.0`) all fail. All three are valid JSON per RFC 8259 and could be produced by Google Datastream for `numeric(2,0)` columns.

Test file: `CALConsult.Disposition.Functions.FilterShipments.Bucket.Tests/Dtos/GoogleBucketShipmentDataDeserializationTests.cs`

---

## Type Mismatch Audit

### Database `numeric(N,0)` columns vs. C# DTO types

| DB Column | DB Type | Cloud Function C# | Backend C# | Scientific Notation Risk |
|---|---|---|---|---|
| `sendung_tix` | `numeric(22,0)` | `long` | `long` | **Medium** -- `long` also rejects scientific notation |
| `firma` | `numeric(3,0)` | `double` | `double?` | None -- `double` handles it |
| `niederlassung` | `numeric(2,0)` | `double` | `double` | None |
| `sendung_n` | `numeric(7,0)` | `double?` | `double` | None |
| **`tran_art`** | **`numeric(2,0)`** | **`int?`** | **`int`** | **HIGH -- already failed** |
| **`tour`** | **`numeric(3,0)`** | **`int?`** | **`int?`** | **HIGH -- same risk** |
| `gewicht` | `numeric(9,3)` | `double?` | `double` | None |
| `stellplatz_c` | `numeric(5,2)` | `double?` | `double?` | None |
| `bodenstpl_c` | `numeric(5,2)` | `double?` | `double?` | None |
| `volstpl_c` | `numeric(5,2)` | `double?` | `double?` | None |

### Nullability mismatches (Cloud Function vs. Backend)

The Backend DTO uses **non-nullable types** for several fields that are nullable in the database and in the Cloud Function DTO. If the DB value is `NULL`, the Backend deserialization would fail silently (default to `0` or `0001-01-01`) or throw, depending on context.

| Property | Cloud Function | Backend | Risk |
|---|---|---|---|
| `TransportMode` | `int?` | `int` | Backend crashes on `null` |
| `CreationTime` | `DateTime?` | `DateTime` | Backend defaults to `0001-01-01` |
| `LoadingDate` | `DateTime?` | `DateTime` | Backend defaults to `0001-01-01` |
| `FixedDeliveryDate` | `DateTime?` | `DateTime` | Backend defaults to `0001-01-01` |
| `ShipmentNumber` | `double?` | `double` | Backend defaults to `0` |
| `Weight` | `double?` | `double` | Backend defaults to `0` |

---

## Affected Source Files

### Cloud Function (FilterShipments)

| File | Role |
|---|---|
| `Code/Nagel-GCP/.../Dtos/GoogleBucketShipmentData.cs` | DTO with `int? TransportMode` (line 38) |
| `Code/Nagel-GCP/.../Bucket/ContentProvider/BucketFileContentProvider.cs` | Deserialization with default settings (line 31) |
| `Code/Nagel-GCP/.../Trigger/FilterShipmentsTrigger.cs` | Cloud Function entry point |

### Backend (CDC Subscriber)

| File | Role |
|---|---|
| `Code/Disposition-Backend/.../Dtos/GoogleBucketShipmentData.cs` | DTO with `int TransportMode` (line 39, **non-nullable**) |

### TMS Database

| File | Role |
|---|---|
| `Code/tms-alloydb-schema/src/sql/table/sendung.sql` | `tran_art numeric(2,0)` (line 164) |
| `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql` | `SetTransportMode` function (PR #519) |

---

## Solution Options

### Option A: Change `int?` / `int` to `double?` (Quick Fix)

Change the C# type of `TransportMode` and `TourNumber` from `int?`/`int` to `double?` in both DTOs. Cast to `int` at the point of use.

**Pros:**
- Minimal code change (2 files, 2 properties each)
- `double` natively parses scientific notation
- Consistent with how `firma`, `niederlassung`, `sendung_n` are already mapped

**Cons:**
- Hides the real problem (fragile deserialization)
- Loses type safety at the DTO level
- Downstream code that expects `int` needs casting

### Option B: Custom JsonConverter for scientific notation integers

Create a `ScientificNotationIntConverter` that parses via `double` and casts to `int`. Apply with `[JsonConverter]` attribute on affected properties.

```csharp
public class ScientificNotationIntConverter : JsonConverter<int?>
{
    public override int? ReadJson(JsonReader reader, ...)
    {
        if (reader.TokenType == JsonToken.Null) return null;
        if (reader.TokenType == JsonToken.Float || reader.TokenType == JsonToken.Integer)
            return Convert.ToInt32(reader.Value);
        if (reader.TokenType == JsonToken.String)
            return (int)double.Parse((string)reader.Value);
        throw new JsonSerializationException(...);
    }
}
```

**Pros:**
- Targeted fix, no type change
- Handles all numeric JSON representations (integer, float, scientific notation)
- Reusable for `long` fields (`sendung_tix`) if needed

**Cons:**
- More code to maintain
- Must be applied to every affected property

### Option C: Global JsonSerializerSettings with FloatParseHandling

Configure `JsonSerializerSettings` in `BucketFileContentProvider` with `FloatParseHandling.Double` and use it for all deserialization.

**Pros:**
- One-time change in the deserialization call
- Protects all fields globally

**Cons:**
- Changes behavior for ALL fields, not just the affected ones
- Does not fix the `int` parse issue directly -- still needs a converter or type change
- Could mask other type issues

### Recommended Approach

**Option A for immediate fix** (change `int?`/`int` to `double?` for `tran_art` and `tour` -- aligns with the existing pattern used for other `numeric(N,0)` columns like `firma` and `niederlassung`).

**Option B as follow-up** if the team prefers to keep integer semantics at the DTO level. Also apply to `sendung_tix` (`long`) which has the same theoretical risk.

---

## Questions / Open Items

1. **Verify the trigger:** Confirm that PR #519 (`SetTransportMode` fix) caused a new `tran_art = 60` write for a shipment in ABN1034. Check the Datastream bucket file that caused the error to confirm the `6E+1` value.

2. **Datastream documentation:** Does Google document which PostgreSQL types may produce scientific notation? This would help create a comprehensive mapping guideline.

3. **CrossDockEventPublisher:** The other Cloud Function consuming from the same bucket uses `long` for its numeric fields (`SenTransportOrderNumber`) -- same `long` parsing risk with scientific notation.

4. **Backend impact:** The Backend receives data via PubSub after the Cloud Function re-serializes it. Since the Cloud Function crashed, the Backend was not affected this time. But if the Cloud Function is fixed and starts forwarding `tran_art = 60`, the Backend's non-nullable `int TransportMode` might fail on a `null` value in a future record. Both DTOs should be fixed together.

5. **Monitoring:** Should we add alerting for deserialization failures in the CDC pipeline? Currently, the Cloud Function fails silently (from the business perspective) -- the shipment is simply not forwarded.

---

## Related Files

- `02_Explorations/2026-01-16-Oracle-CDC/` -- CDC pipeline exploration (Oracle era)
- `08_Documentation/2026-02-26_leg-lot-creation-table-sendung/shipment-data-flow-architecture.md` -- Full pipeline documentation
- `09_ADRs/ADR-007-datastream-psc-proxy-retention/` -- Datastream network architecture

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
