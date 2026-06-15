# PRD: Nested GCS Path Structure for SendungCdcWriter

**Feature ID:** 005_Sendung_CDC_Writer_Nested_GCS_Paths
**Status:** Draft
**Date:** 2026-06-15
**Work Item:** [Technical PBI 125273](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/125273)

---

## 1. Problem

The SendungCdcWriter (PRD 004) writes all JSONL files flat into `tms1034_sendung/`:

```
gs://abn1043-sendung-bucket-1/tms1034_sendung/{uuid}_pgnotify_{ts}.jsonl
```

Datastream's native output uses date-partitioned nesting:

```
gs://abn1043-sendung-bucket-1/tms1034_sendung/2026/06/15/11/15/{hash}_postgresql-cdc_{id}.jsonl
```

This mismatch creates two problems:

1. **Flat directory accumulation.** Every CDC event creates a new file at the same path level. Over days/weeks, this creates a single directory with thousands of files -- harder to browse, debug, and audit.
2. **Inconsistent bucket layout.** Datastream and pg_notify files coexist in the same bucket but follow different structures. Any tooling or manual inspection that expects the date-nested layout (e.g., checking "what arrived today at 14:00?") doesn't work for pg_notify files.

### Evidence from live bucket (verified 2026-06-15)

```
tms1034_sendung/
  194793c3-..._pgnotify_1781530366878.jsonl     <- flat (pg_notify)
  6ac3eabb-..._pgnotify_1781529416465.jsonl     <- flat (pg_notify)
  aaf5e658-..._pgnotify_1781530370082.jsonl     <- flat (pg_notify)
  2026/06/15/11/15/                             <- nested (Datastream)
    ed46b7f9..._postgresql-cdc_...7631.jsonl
    ed46b7f9..._postgresql-cdc_...7632.jsonl
```

---

## 2. Direction Alignment

This change aligns the pg_notify writer with the established Datastream convention. The SendungCdcWriter was explicitly designed to produce Datastream-compatible JSONL envelopes (PRD 004, M3-M6). The path structure is the remaining incompatibility.

| Source | Reference |
|---|---|
| PRD 004 (Closed) | pg_notify writer designed as Datastream drop-in replacement -- envelope format matches, path does not |
| gcloud operations guide (line 355-359) | Documents `SCHEMA.TABLE/yyyy/mm/dd/hh/mm/filename` as the standard GCS output structure |
| Live bucket `abn1043-sendung-bucket-1` | Verified 2026-06-15: Datastream uses 5-level date nesting under `tms1034_sendung/` |

---

## 3. Requirements

### Must Have

| ID | Requirement |
|---|---|
| **M1** | GcsJsonlWriter constructs object paths as `{prefix}/{yyyy}/{MM}/{dd}/{HH}/{mm}/{filename}` matching the verified Datastream nesting pattern |
| **M2** | Date components derived from `DateTimeOffset.UtcNow` (write time), matching Datastream's rotation-time-based partitioning |
| **M3** | All date segments zero-padded to 2 digits (month, day, hour, minute); year is 4 digits |

### Should Have

| ID | Requirement |
|---|---|
| **S1** | Unit test covering the path construction logic (date formatting, zero-padding) |

### Could Have

| ID | Requirement |
|---|---|
| **C1** | Cleanup of the 3 existing flat pg_notify files in the bucket root (manual `gsutil mv` or delete) |

### Won't Have

| ID | Requirement | Rationale |
|---|---|---|
| **W1** | Configurable nesting pattern | Only one pattern matters (Datastream's). No foreseeable need for alternatives. |
| **W2** | Matching Datastream's filename format (`{hash}_postgresql-cdc_{id}`) | The `{uuid}_pgnotify_{ts}` format is intentionally different to distinguish pg_notify from Datastream files. No consumer depends on filename format. |
| **W3** | Switching the path prefix from underscore to dot (`tms1034.sendung`) | The bucket already uses underscore for both sources. Changing would break existing config. |
| **W4** | Migration/relocation of historical flat files | Consumer processes them regardless of path depth. |

---

## 4. Out of Scope

- **No changes to the FilterShipmentsTrigger Cloud Function.** It matches on `.jsonl` extension only (`BucketDataStreamFileContentProcessor.cs:18`), not on path structure.
- **No changes to the JSONL envelope format.** Content stays identical; only the GCS object path changes.
- **No changes to `appsettings.json`.** The `PathPrefix` config value (`tms1034_sendung`) remains the same -- date nesting is appended in code.
- **No Datastream configuration changes.** This only affects the pg_notify writer.

---

## 5. Implementation Approach

**Single file change** in `GcsJsonlWriter.cs:22-23`:

Current:
```csharp
var filename = $"{Guid.NewGuid()}_pgnotify_{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}.jsonl";
var objectName = $"{_pathPrefix}/{filename}";
```

Target:
```csharp
var now = DateTimeOffset.UtcNow;
var filename = $"{Guid.NewGuid()}_pgnotify_{now.ToUnixTimeMilliseconds()}.jsonl";
var objectName = $"{_pathPrefix}/{now:yyyy}/{now:MM}/{now:dd}/{now:HH}/{now:mm}/{filename}";
```

The `DateTimeOffset.UtcNow` call is captured once to ensure the timestamp in the filename and the directory path are consistent.

---

## 6. Files Likely to Change

| File | Change | New/Modified |
|---|---|---|
| `Code/Nagel-GCP/SendungCdcWriter/SendungCdcWriter/Services/GcsJsonlWriter.cs` | Path construction logic (lines 22-23) | Modified |
| `Code/Nagel-GCP/SendungCdcWriter/SendungCdcWriter.Tests/GcsJsonlWriterTests.cs` (if S1 accepted) | New test for path formatting | New or Modified |

---

## 7. Verification

| Step | Method |
|---|---|
| **Build** | `dotnet build` succeeds on `SendungCdcWriter.sln` |
| **Unit test** | New test verifies path format matches `{prefix}/yyyy/MM/dd/HH/mm/{uuid}_pgnotify_{ts}.jsonl` |
| **Deploy to abn1034** | Redeploy via existing Azure pipeline (`azure-pipelines-cloudrun-t-t-abn1034.yml`) |
| **End-to-end** | Trigger a sendung change on abn1034 -> verify new file appears at nested path in `gs://abn1043-sendung-bucket-1/tms1034_sendung/{yyyy}/{MM}/{dd}/{HH}/{mm}/` |
| **Consumer** | Verify FilterShipmentsTrigger fires on the nested-path file and publishes to Pub/Sub |

---

## 8. Related

| Reference | Path/Link |
|---|---|
| PRD 004 (parent feature) | `03_PRD/Closed/004_PG_Notify_CDC_Sendung/PRD.md` |
| GcsJsonlWriter source | `Code/Nagel-GCP/SendungCdcWriter/SendungCdcWriter/Services/GcsJsonlWriter.cs` |
| Consumer CanHandle logic | `Code/Nagel-GCP/CALConsult.Disposition.Functions/CALConsult.Disposition.Functions.FilterShipments.Bucket/Bucket/ContentProvider/BucketDataStreamFileContentProcessor.cs:16-18` |
| Datastream GCS path docs | `02_Explorations/2026-06-09_gcloud-tooling/gcp-datastream-gcloud-operations-guide.md:355-359` |
| Live bucket | `gs://abn1043-sendung-bucket-1/tms1034_sendung/` |
