# GCS Cloud Storage processed-file tracking and cleanup patterns Cloud Function triggers

**Date:** 2026-06-23
**Status:** Exploration

---

## TL;DR

- **GCS has no native "processed" flag.** Objects are immutable and the bucket tracks no processing state; a function "returning success" only drives event ack/retry — it marks nothing durable. Tracking must be designed explicitly.
- **Industry standard = two complementary patterns:** zone separation (`incoming/` → `processed/` prefix or archive bucket) + **Lifecycle Management** for *physical cleanup*; an **external ledger** keyed by *object name + generation* for *robust tracking / idempotency / audit*. Mature pipelines combine both.
- **GCS triggers are at-least-once** → cleanup logic must be idempotent and based on durable state, not on the ephemeral success return.
- **Our `FilterShipments.Bucket` function only reads the source object** (verified 2026-06-23) — it never flags, moves, copies, sets metadata on, or deletes it. So there is no "processed" signal and no cleanup today; CDC files accumulate. It also has **no idempotency guard** (a mid-file `throw` re-processes the whole file on redelivery).
- **None of the 6 CDC buckets has a Lifecycle policy** (only the default 7-day soft-delete, which is *not* cleanup). **A Lifecycle `age` rule is the missing piece** — the lowest-touch fit, since the function leaves files in place. Confirm retention/replay needs first.

---

<internal>

## Original User Input

> In GCP in cloud storage, is there a way to find out if a file has been processed in the case that every file entering the bucket triggers a cloud function and the cloud function reports back a success message or something. Do the files get a flag or something that we can use to identify them so we can build a cleanup process around it and delete all files that are no longer needed. What's the industry standard for this?

</internal>

---

## Summary

**Cloud Storage has no built-in "processed" flag.** GCS objects are immutable blobs; the bucket does not track whether a downstream Cloud Function consumed them. The function "returning success" only matters to the event system (for ack/retry) — it does not durably mark the object anywhere. Tracking must be designed explicitly.

Two patterns dominate in practice:
- **Cleanup-focused / pipelines:** zone separation (`incoming/` → `processed/` prefix or archive bucket) **+ Lifecycle Management** for retention.
- **Robust tracking / idempotency / audit:** an **external ledger** keyed by `object name + generation`, often with Pub/Sub + a dead-letter queue.

Mature setups combine both: ledger for *truth and idempotency*, zones + Lifecycle for *physical cleanup*.

## Analysis

### Why "report back success" is not enough on its own

Cloud Storage triggers are **at-least-once** delivery — the same object can fire the function more than once, and events can arrive out of order. Any cleanup logic must therefore be **idempotent** and based on *durable* state, not on a one-time success return value that disappears when the function exits.

### Option 1 — Custom object metadata (a flag on the object)

After processing, the function patches the object with custom metadata, e.g. `x-goog-meta-processed=true`, `x-goog-meta-processed-at=<ts>`.

- ✅ The flag lives with the object.
- ⚠️ Metadata updates fire a *separate* event type (`metadataUpdated`), **not** `finalized`/`created`. If the trigger only listens to object **creation**, writing the flag will **not** re-trigger the function (no infinite loop). Subscribing to metadata-update events *would* loop.
- ⚠️ **GCS cannot be queried by metadata.** Listing is by name/prefix only. Finding "all unprocessed files" means listing every object and reading each one's metadata — expensive at scale.
- ⚠️ **Lifecycle rules cannot read custom metadata** — so this flag alone cannot drive auto-cleanup.

### Option 2 — Zone separation (move processed files)

Use an `incoming/` → `processed/` prefix (or a separate archive bucket). On success the function copies the object to `processed/` and deletes the original.

- ✅ State is **visible by location**: anything still in `incoming/` is unprocessed or failed.
- ✅ Cleanup becomes trivial — point a Lifecycle rule at the `processed/` prefix.
- This is the de-facto standard in data lakes (raw → curated zones, or the Spark/Hadoop `_SUCCESS` marker-file convention).

### Option 3 — External processing ledger (most robust)

Record state in Firestore / Cloud SQL / BigQuery, keyed by **object name + generation number**. Status = pending/processed/failed + timestamps.

- ✅ Doubles as the **idempotency key** — dedupes at-least-once re-fires.
- ✅ Fully queryable → easy to drive cleanup ("delete objects where status=processed AND processed_at < now − retention") and gives an audit trail.
- The choice when correctness/auditability matters.

### Option 4 — `customTime` + Lifecycle (native cleanup trick)

GCS Lifecycle Management is the *native* deletion tool, but its conditions are limited (`age`, `createdBefore`, `matchesPrefix/Suffix`, `numNewerVersions`, `daysSinceCustomTime`, …) and **cannot read custom metadata**.

- The bridge: each object has a settable `customTime` field. After processing, set `customTime = now`, then add a Lifecycle rule **"delete when `daysSinceCustomTime >= N`."**
- Ties auto-cleanup to a *processing event* rather than upload time, **without moving the file**.

### Comparison

| Approach | Marks "done"? | Queryable | Drives auto-cleanup | Idempotency | Notes |
| --- | --- | --- | --- | --- | --- |
| Custom metadata flag | ✅ | ❌ (scan only) | ❌ (Lifecycle can't read it) | Partial | Safe from loops if only triggering on create |
| Zone separation | ✅ (by location) | ✅ (prefix) | ✅ (Lifecycle on prefix) | Partial | Standard pipeline pattern |
| External ledger | ✅ | ✅ | ✅ (query-driven) | ✅ (by generation) | Most robust; needs a datastore |
| `customTime` + Lifecycle | Indirect | ❌ | ✅ (native) | — | No file move needed |

## Source Code Evidence

Reviewed (2026-06-23): `Code/Nagel-GCP/CALConsult.Disposition.Functions/CALConsult.Disposition.Functions.FilterShipments.Bucket`

**Deployed function:** `new-dispo-filter-shipment-records-<env>` — Gen2 Cloud Run function, `dotnet8`, region `europe-west3`. Trigger declared in `devops/azure-pipelines-*.yml`:
- `--gen2 --trigger-bucket $(WL5_CDC_BUCKET_<env>)` → Eventarc trigger on **`google.cloud.storage.object.v1.finalized`** (object creation/finalize), **not** metadata-update events. (dev bucket = `test-cdc-2`.)

**Entry point — `Trigger/FilterShipmentsTrigger.cs`** (`ICloudEventFunction<StorageObjectData>`):
1. Receives the finalize CloudEvent; reads `Bucket` + `Name` (lines 21-22).
2. `storageClient.DownloadObjectAsync(...)` into a `MemoryStream` (line 27) — **read only**.
3. Selects a processor by filename via `CanHandle` (line 33); if none, logs "File skipped" (line 41).
4. On any exception: logs and **`throw`** (lines 44-51) → event is nacked → Eventarc/Pub/Sub redelivers (at-least-once).

**Routing / processing:**
- `BucketDataStreamFileContentProcessor` — handles `*.jsonl` (Datastream CDC), line-by-line; reconstructs INSERT / UPDATE / UPDATE-DELETE+UPDATE-INSERT / DELETE.
- `BucketStriimFileContentProcessor` — handles filenames ending in a digit (`\d$`), whole-file JSON array (Striim CDC).
- Both filter to `ShipmentType == "A"` **AND** consignor whitelisted, then publish matched records.

**Whitelist — `WhitelistFileProvider.cs`:** `DownloadObjectAsync` of a whitelist object (`GcsSettings:BucketName` / `WhitelistFileName`); used by `ClientWhitelistService`, cached via `IMemoryCache`. Also **read only**.

**Publish — `PubSubPublisher.cs` / `PubSubClientFactory.cs`:** each matched record published to a Pub/Sub topic with **message ordering enabled** (`EnableMessageOrdering = true`), ordering key = `ShipmentId`.

**Bucket write-back: NONE.** The only `StorageClient` calls in the entire project are two `DownloadObjectAsync` (trigger file + whitelist). No `DeleteObject`, `UpdateObject`/`PatchObject` (metadata), `CopyObject`, `UploadObject`, or `customTime` anywhere. The source object is left **untouched** in the bucket after processing.

## Findings

- There is **no native processed flag** in Cloud Storage; objects are immutable and the bucket holds no processing state.
- Function success/return values are **ephemeral** — durable state must be written somewhere (metadata, location, or external store).
- GCS triggers are **at-least-once** → idempotency is mandatory regardless of approach.
- **Lifecycle Management is the only native auto-delete mechanism**, but keys off object fields (age, prefix, `customTime`), **not** custom metadata.
- **Industry standard:** zone separation + Lifecycle for cleanup; external ledger (keyed by object name + generation) for robust tracking/idempotency/audit; combine the two for mature pipelines.

### Confirmed against `FilterShipments.Bucket` (2026-06-23)

- The function **does not flag, move, copy, set metadata on, or delete** the source object — it only reads it. So there is currently **no "processed" signal** and **no cleanup** produced by this function; the CDC files accumulate in the trigger bucket.
- Cleanup therefore has to be **external**. Given the function leaves files in place, **Lifecycle Management on the CDC bucket** (delete by `age`, optionally scoped by prefix) is the lowest-touch fit. CDC drop files are reproducible/transient, so age-based deletion is usually acceptable — but confirm replay/retention needs first.
- Trigger is on **finalize only**, so a future per-object metadata flag would **not** cause re-trigger loops — but it still couldn't drive Lifecycle (which can't read custom metadata), so `customTime` or a prefix move would be needed for flag-driven cleanup.
- **No idempotency guard:** a `throw` mid-file causes Eventarc/Pub/Sub to redeliver and the **whole file is re-processed from the top**, re-publishing already-sent records. Downstream must dedupe (Pub/Sub ordering by `ShipmentId` is enabled, but ordering ≠ dedup).

### Bucket configuration — verified live (2026-06-23)

Project `prj-cal-w-wl5-t-6c00-53ad`, account `x_matthias.max@nagel-group.com`, region `europe-west3`. CDC buckets found:

| Bucket | Lifecycle | Versioning | Soft-delete |
| --- | --- | --- | --- |
| `new-dispo-cdc-bucket` (ABN1034 — holds `tms1034_sendung/`) | **none** | off | 7 days (default) |
| `new-dispo-cdc-bucket-abn2820` | **none** | off | 7 days |
| `new-dispo-cdc-bucket-uat2820` | **none** | off | 7 days |
| `wl5-cdc-bucket-abn1060` | **none** | off | 7 days |
| `wl5-cdc-bucket-uat1060` | **none** | off | 7 days |
| `tms-alloydb-datastream-bucket-wl5-t-t` | **none** | off | 7 days |

- **No Lifecycle policy on any CDC bucket** (`gsutil lifecycle get` → "has no lifecycle configuration"). Nothing deletes these files; objects accumulate indefinitely.
- **Soft-delete = 604800s (7 days)** on all — this is GCS's *default* policy. It does **not** delete anything; it only retains *already-deleted* objects for 7-day recovery and bills for that soft-deleted storage. It is **not** a cleanup mechanism.
- **Versioning off** (so no noncurrent-version growth).
- `new-dispo-cdc-bucket` has `public_access_prevention: enforced`; objects are organized under per-table prefixes (e.g. `tms1034_sendung/`) by Datastream.
- Net: combined with the function never deleting/flagging objects, **nothing currently cleans these buckets** — a Lifecycle `age` rule is the missing piece.
- (Dev bucket `test-cdc-2` in project `nagel-new-disposition` not checked — out of scope / no access.)

## Questions/Open Items

- ~~What is the current GCS trigger type?~~ **Resolved:** Gen2 + `--trigger-bucket` → Eventarc `google.cloud.storage.object.v1.finalized` (finalize only; no metadata re-trigger risk).
- What is the actual retention requirement ("no longer needed" = how long after the file lands / is consumed)? Drives the Lifecycle `age`.
- Are CDC drop files safely reproducible (can the source re-emit), or is any replay/audit needed before deleting? Determines whether plain age-based Lifecycle is safe or a ledger is warranted.
- ~~Is there already a Lifecycle policy on the CDC buckets?~~ **Resolved (2026-06-23):** No — none of the 6 CDC buckets has a Lifecycle config; only the default 7-day soft-delete is active. See "Bucket configuration" above.
- Does the whitelist file live in the **same** trigger bucket? If so, confirm its name doesn't match `*.jsonl` or end in a digit, or it will be (harmlessly) downloaded and "skipped" on every upload.
- Volume/scale of files entering the bucket (affects whether age-based Lifecycle alone suffices vs. needing a ledger)?

<internal>

## Related Files

- `02_Explorations/2026-06-23_GCS_Cloud_Storage_processed-file_tracking_and_cleanup_patterns_Cloud_Function_tr/` — this exploration

</internal>

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
