# PutSignature — Cloud4Log Upload Flow Analysis

**Date:** 2026-04-30
**Result:** No connection found. PutSignature state changes do NOT trigger any Cloud4Log upload flow.

---

## Cloud4Log Architecture

Cloud4Log is **pull-based** (not CDC). It has exactly 3 cloud functions, all triggered via HTTP POST with a time window (`startTime` + `offset`). All pull data from the TMS Bridge via GraphQL.

| Function | Pull trigger | GraphQL filter | Data source |
|---|---|---|---|
| `BorderoUploadFunction` | time-based | `druckdatumE` range + `verkehrsstrom` contains "30" | `borderoCartages` query |
| `RollkartUploadFunction` | time-based | `druckdatumE` range + `tranArt` not in [3,6] | `rollkartCartages` query |
| `DownloadProofOfDeliveryFunction` | time-based | Closed delivery notes from Cloud4Log API, then `rollkN` | Cloud4Log API + `sendungPagedEntities` |

**Source:** `Code/Nagel-GCP/Cloud4Log/Cloud4Log.Http/Functions/`

---

## PutSignature State Changes vs Cloud4Log Queries

None of the 6 tables/values written by PutSignature are referenced by any Cloud4Log function:

| PutSignature writes | Table | Key values | Referenced by Cloud4Log? |
|---|---|---|---|
| Optimistic lock bump | `SENDUNG` | `U_VERSION`, `U_TIME`, `OLS_USER` | NO |
| AUTOABF signed bit | `SEN_ZUSTAND` | `BEREICH_K='AUTOABF'`, `STATUS` bit 16 | NO |
| Signature history event | `SEN_HST` | `STATUS=230` (SIG), `META_T` contains `DocType=TO_MP4_SIG_DRIVER` | NO |
| Signature image | `LOB` | `TYP='jpg'`, `T='Signatur'` | NO |
| History-to-LOB link | `SEN_HST2LOB` | FK linking SEN_HST to LOB | NO |
| DFV sync marker | `SEN_TS` | `TRAN_CODE='32'`, `TRAN_K='1'` | NO |

---

## Driver Signature in Cloud4Log is Unrelated

Both `BorderoUploadFunction` and `RollkartUploadFunction` use a "driver signature" — but it is a **static file** downloaded from a GCS bucket, not the per-transport-order signature stored by PutSignature:

```csharp
// BorderoUploadFunction.cs line 422, RollkartUploadFunction.cs line 302
private async Task<string> RetrieveDriverSignatureAsync()
{
    await storageClient.DownloadObjectAsync(
        storageConfig.Value.Buckets.C4LStaticFiles,
        "signatureImage.txt",
        fileContentsStream);
    ...
}
```

This is a fixed image used for all uploads, not the individual driver signature captured at the terminal.

---

## Tangential Overlap: LoadCarrierService

`LoadCarrierService` queries `pstHsts` (PST_HST table) with `status: 660` and `mp: 4` or `mp: 7`. These measuring point values (4 and 7) are the same ones PutSignature uses for `SEN_HST.MP`, but:

- Different table: `PST_HST` vs `SEN_HST`
- Different status: `660` vs `230`
- No causal connection

**Source:** `Code/Nagel-GCP/Cloud4Log/Cloud4Log.Http/Services/LoadCarrierService/LoadCarrierService.cs` (lines 144, 172)

---

## Conclusion

The Cloud4Log pipeline operates independently from the Driver Terminal's PutSignature flow. Upload decisions are driven by time-windowed queries against bordero/rollkart print dates and delivery note bundle status — none of which are affected by signing a transport order.

---

<div align="center">
  <sub>Created by <strong>Virtual Architect</strong></sub>
</div>
