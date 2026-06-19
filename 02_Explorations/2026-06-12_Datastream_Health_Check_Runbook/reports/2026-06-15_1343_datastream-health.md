# Datastream Health Report — abn1034 — 2026-06-15

**Generated:** 2026-06-15 13:43 UTC
**Database:** abn1034 (10.100.47.236)
**Stream:** new-dispo-cdc-datastream-sendung-abn1034
**Overall Status:** CRITICAL

---

## Status Legend

| Symbol | Level | Meaning |
|--------|-------|---------|
| PASS | Healthy | Value is within normal operating range. No action needed. |
| WARN | Warning | Value is outside normal range but not yet dangerous. Investigate within hours. |
| FAIL | Critical | Value indicates an active problem or imminent risk. Investigate immediately. |
| UNKNOWN | No Data | Check could not be executed (connection failure, auth expired, permission denied). |

---

## KPI Summary

| # | KPI | Value | Status | Threshold |
|---|-----|-------|--------|-----------|
| 1 | Slot WAL Lag | 199 GB (213,880,394,584 bytes) | FAIL | PASS < 1 GB, WARN 1–10 GB, FAIL > 10 GB |
| 2 | WAL Status | extended | WARN | PASS = reserved, WARN = extended, FAIL = lost |
| 3 | Slot Active | false | FAIL | PASS = true, FAIL = false |
| 4 | WAL Sender | absent | FAIL | PASS = streaming/connected, WARN = catchup > 1h, FAIL = absent |
| 5 | Hung Transactions | 0 | PASS | PASS = 0, WARN = any < 4h, FAIL = any > 4h |
| 6 | Safety Net | 800 GB | PASS | PASS = configured, WARN = not set (-1) |
| 7 | CDC Advancing | advancing (1-min ticks) | PASS | PASS = LSN advancing, FAIL = frozen |
| 8 | Bucket Writes | 13:32 UTC (~11 min ago) | PASS | PASS < 5 min, WARN < 1h, FAIL > 1h |
| 9 | Stream State | PAUSED | FAIL | PASS = RUNNING, FAIL = PAUSED/FAILED |
| 10 | Error Logs | none (abn1034) | PASS | PASS = none, WARN = warnings only, FAIL = errors |
| 11 | catalog_xmin Age | 125,729,134 (~125.7 M txns) | FAIL | PASS < 1 M, WARN 1–10 M, FAIL > 10 M txns |
| 12 | restart_lsn Divergence | ~98× (199 GB / 2.03 GB) | WARN | PASS < 2×, WARN 2–100×, FAIL > 100× AND restart > 10 GB |

**Result: 5/12 KPIs passing**

---

## KPI Reference

What each KPI measures and what its values mean.

### 1. Slot WAL Lag
How many bytes of WAL PostgreSQL is retaining because the replication slot's consumer hasn't confirmed processing them yet. WAL is a sequential log of every write across all 774 tables — not just the `sendung` table. A stalled consumer causes WAL to accumulate for the entire database.
- **< 1 GB**: Consumer is keeping up in near real-time.
- **1–10 GB**: Consumer is falling behind. At ~2.4 GB/hour WAL production on abn1034, this is 0.4–4 hours of lag.
- **> 10 GB**: Significant backlog. The longer this grows, the more disk is consumed and the longer recovery takes.
- **> 200 GB**: Emergency. Past incidents hit 234 GB (Jun 8) and 422 GB (Jan 30).
Note: This KPI has two sub-values. `restart_lsn` lag is total WAL retained. `confirmed_flush_lsn` lag is how far behind the consumer actually is. When the consumer is current but `restart_lsn` hasn't advanced, the retained WAL is a disk concern, not a data freshness concern.

### 2. WAL Status
PostgreSQL's assessment of how much WAL a slot is holding back — a progression where each step is worse:
- **`reserved`**: Retaining WAL within normal `wal_keep_size` budget. No concern.
- **`extended`**: Retaining WAL *beyond* `wal_keep_size`. PostgreSQL is keeping extra WAL segments alive solely because this slot still needs them. Disk usage is growing beyond what PostgreSQL would normally allow.
- **`unreserved`**: Retained WAL exceeds `max_slot_wal_keep_size`. May be reclaimed at next checkpoint. Slot is at risk of going `lost`.
- **`lost`**: PostgreSQL has reclaimed WAL the slot still needed. Consumer can no longer resume. Recovery requires dropping the slot, recreating the Datastream stream, and doing a full backfill.

### 3. Slot Active
Whether a consumer process (Datastream's WAL sender) is currently connected to the replication slot.
- **`true`**: Datastream has an active connection and is (or should be) reading WAL.
- **`false`**: No consumer connected. WAL accumulates with no one consuming it.

### 4. WAL Sender
The PostgreSQL process that reads WAL and streams it to Datastream:
- **`streaming`**: Consumer is caught up, receiving changes in real-time. Healthy state.
- **`catchup`**: Consumer is behind, reading historical WAL from disk. Normal after pause/resume, concerning if it persists for hours.
- **`startup`**: Just connected, initializing. Transient.
- **absent (no row)**: No WAL sender process exists. Consumer is disconnected.
Note: The `tms1034` user may not have `pg_monitor` privileges, causing the `state` column to appear empty. The row existing at all confirms the consumer is connected.

### 5. Hung Transactions
Long-running transactions (> 1h) that prevent PostgreSQL from reclaiming WAL. Root cause of the Jan 2026 incident (422 GB from transactions running 1+ days).
- **0**: No blocked cleanup. Healthy.
- **Any > 1 hour**: WAL cleanup is being delayed. Identify source application.
- **Any > 4 hours**: Likely hung/abandoned. Should be terminated after verifying it's not a replication connection.

### 6. Safety Net
`max_slot_wal_keep_size` — caps how much WAL a single slot can retain. When exceeded, PostgreSQL reclaims WAL and marks the slot `lost`.
- **Configured (e.g. 100 GB, 800 GB)**: Database is protected against unbounded WAL growth.
- **`-1` or not set**: No limit. A stalled consumer can grow WAL until disk fills and database crashes.

### 7. CDC Advancing
Whether Datastream's checkpoint LSN is advancing over time. Datastream logs a checkpoint every ~60 seconds.
- **Advancing**: LSN and event timestamp increase between entries. Stream is actively processing WAL.
- **Frozen**: Identical values across 3+ entries spanning > 5 minutes. Silent stall — reports RUNNING but not consuming data. Exact pattern from the June 8 incident.

### 8. Bucket Writes
Whether new CDC data files are appearing in the GCS destination bucket.
- **Recent (< 5 min)**: Active writes.
- **< 1 hour**: May be normal if `sendung` has infrequent updates. Cross-reference with KPI 7.
- **> 1 hour**: Likely stalled unless source table is genuinely idle.
Note: `sendung` on abn1034 receives sporadic updates (3–5 batches/day), so hours without writes can be normal.

### 9. Stream State
State reported by the Datastream service. **RUNNING does NOT guarantee health** — the June 8 silent stall proved Datastream reports RUNNING even when frozen. Always cross-reference with KPI 7.
- **`RUNNING`**: Stream is active (but verify via CDC checkpoint).
- **`PAUSED`**: Intentionally paused.
- **`NOT_STARTED`**: Created but never activated.
- **`FAILED`**: Unrecoverable error.

### 10. Error Logs
Errors/warnings logged by Datastream in the last 24h. Silent stalls produce no errors — this catches other problems (connection failures, schema issues, oversized logs).

### 11. catalog_xmin Age
Age (in transactions) of the slot's `catalog_xmin` — how far behind the slot's system catalog snapshot is from the current transaction ID. Root cause indicator for "consumer is current but WAL keeps growing."
- **< 1 M**: Normal. Catalog snapshot reference is current.
- **1–10 M**: Elevated. Monitor — should resolve if consumer processes retained WAL. If no decrease in 24h, slot may need recreation.
- **> 10 M**: Critical. Slot is pinning an old catalog snapshot. restart_lsn will not advance. Only fix: drop and recreate the slot.
- **(empty / NULL)**: No catalog_xmin hold. Check xmin instead.

### 12. restart_lsn Divergence
Ratio between restart_lsn lag (total WAL retained) and confirmed_flush_lsn lag (actual consumer backlog). When consumer is current but restart_lsn is far behind, the slot has a structural problem.
- **< 2×**: Normal. Both positions advance together.
- **2–100×**: Moderate divergence. May indicate start of catalog_xmin pin or post-stall cleanup.
- **> 100× AND restart > 10 GB**: Critical. Consumer is current but slot retains massive WAL. Check KPI 11 to confirm catalog_xmin pin.

---

## Root Cause Analysis

### Orphaned Replication Slot — `sendung_slot_abn1034`

The Datastream stream `new-dispo-cdc-datastream-sendung-abn1034` was intentionally PAUSED on or before 2026-06-15 because the pg_notify CDC writer (Cloud Run) was deployed as a replacement (PRD 004). However, the logical replication slot `sendung_slot_abn1034` that Datastream created was **not dropped** when the stream was paused.

**Slot diagnostic:**

| Field | Value |
|-------|-------|
| slot_name | sendung_slot_abn1034 |
| slot_type | logical |
| plugin | pgoutput |
| active | false |
| wal_status | extended |
| xmin | (null) |
| catalog_xmin | 2,783,335,241 |
| catalog_xmin_age | 125,729,134 |
| safe_wal_size | 645,115,243,768 (~645 GB remaining) |
| restart_lsn lag | 199 GB |
| confirmed_flush_lsn lag | 2,029 MB (~2 GB) |

**Diagnosis:** The slot's `catalog_xmin` is pinned at transaction ID 2,783,335,241 (125.7 million transactions behind current). This prevents `restart_lsn` from advancing even though `confirmed_flush_lsn` is relatively current (only 2 GB behind). The result is that PostgreSQL retains 199 GB of WAL that can never be released while this slot exists.

**Why it happened:** When Datastream was paused, it disconnected from the replication slot (`active = false`) but the slot itself remains. The slot's `catalog_xmin` was set when Datastream last connected and has been aging ever since. No consumer is advancing it.

**Why it won't self-heal:** The slot is inactive — no consumer will ever connect to advance `catalog_xmin` or `restart_lsn`. WAL will continue accumulating at ~2.4 GB/hour. The 800 GB safety net has ~645 GB remaining, giving approximately **268 hours (~11 days)** before the slot is marked `lost` and WAL is forcibly reclaimed.

**Impact beyond WAL retention:** The pinned `catalog_xmin` also prevents `VACUUM` from removing dead tuples in system catalogs across ALL tables in the database, not just `sendung`. This leads to catalog bloat over time.

**Fix:** Drop the orphaned replication slot:
```sql
SELECT pg_drop_replication_slot('sendung_slot_abn1034');
```
This immediately releases 199 GB of retained WAL and unpins `catalog_xmin`, allowing VACUUM to resume. The pg_notify CDC writer does NOT use this slot — it uses LISTEN/NOTIFY via PL/pgSQL triggers, so dropping the slot has zero impact on the active CDC pipeline.

**Prerequisite:** Confirm with Nagel GCP team that the Datastream stream will not be resumed. If it might be resumed in the future, the slot should be kept — but then the stream must be resumed promptly to drain the backlog.

---

## Database Side — Detail

### Replication Slots

| slot_name | slot_type | plugin | active | wal_status | lag_pretty | lag_bytes | unconfirmed_pretty | unconfirmed_bytes |
|-----------|-----------|--------|--------|------------|------------|-----------|--------------------|--------------------|
| wal_uploader | physical | | t | reserved | 12 MB | 12,812,136 | | |
| sendung_slot_abn1034 | logical | pgoutput | f | extended | 199 GB | 213,880,394,584 | 2023 MB | 2,121,280,640 |
| alloydb_8d579d2f_5477_4ff6_b5e0_a7763395fc81_1ln9 | physical | | f | lost | | | | |
| alloydb_53e7d630_89e7_4de4_a9b1_33edeeb760f6_wbls | physical | | f | lost | | | | |
| alloydb_53e7d630_89e7_4de4_a9b1_33edeeb760f6_ccmc | physical | | f | lost | | | | |

Note: 3 AlloyDB-internal physical slots are in `lost` status. These are likely from stale read replicas or maintenance operations. They should be investigated with Nagel GCP team — `lost` physical slots indicate the replica can no longer catch up and may need to be recreated.

### WAL Sender

| pid | usename | application_name | state | send_lag | sync_state |
|-----|---------|------------------|-------|----------|------------|
| 2889 | alloydbadmin | wal_uploader | | | |

Only the `wal_uploader` (AlloyDB physical replication) has a WAL sender. No WAL sender exists for the logical slot `sendung_slot_abn1034` — consistent with KPI 3 (slot inactive) and KPI 4 (absent). The `state` column is empty, likely due to permission restrictions on the `tms1034` user.

### Hung Transactions

None detected.

### Safety Net

`max_slot_wal_keep_size = 800GB`

This is set directly on the AlloyDB instance. As of 2026-06-15, this parameter is NOT managed in the tms-alloydb-schema repo.

---

## Cloud Side — Detail

### Stream States

| NAME | STATE | DISPLAY_NAME |
|------|-------|-------------|
| orauat-1060-bucket | RUNNING | ORAUAT-1060-Bucket |
| new-dispo-cdc-datastream-sendung-abn1034 | PAUSED | new-dispo-cdc-datastream-sendung-abn1034 |
| new-dispo-cdc-datastream-sendung-abn2820 | NOT_STARTED | new-dispo-cdc-datastream-sendung-abn2820 |

The abn1034 sendung stream is PAUSED — intentionally replaced by the pg_notify CDC writer (PRD 004, deployed 2026-06-15). The abn2820 stream remains NOT_STARTED.

### CDC Checkpoint Progression

| Timestamp | LSN | Event Timestamp |
|-----------|-----|-----------------|
| 2026-06-15T12:44:34Z | 8,901,157,409,512 | 2026-06-15T12:43:33Z |
| 2026-06-15T12:43:33Z | 8,901,121,485,208 | 2026-06-15T12:42:33Z |
| 2026-06-15T12:42:33Z | 8,901,065,325,408 | 2026-06-15T12:41:33Z |
| 2026-06-15T12:41:33Z | 8,900,998,413,296 | 2026-06-15T12:40:32Z |
| 2026-06-15T12:40:33Z | 8,900,967,651,384 | 2026-06-15T12:39:32Z |

LSN is advancing: delta of ~190 M between entries (~1 min apart). Event timestamps also advance. Despite the PAUSED state, these checkpoints from ~12:40-12:44 UTC suggest the stream was active at that time and was paused shortly after, or the checkpointing mechanism continues briefly after pause.

### Bucket Activity

| Size | Timestamp | File |
|------|-----------|------|
| 8,916 | 2026-06-15T13:16:57Z | `tms1034_sendung/6ac3eabb-..._pgnotify_1781529416465.jsonl` |
| 8,936 | 2026-06-15T13:32:50Z | `tms1034_sendung/aaf5e658-..._pgnotify_1781530370082.jsonl` |

Additionally, subdirectories `2025/` and `2026/` exist — these contain files written by Datastream (which uses date-partitioned paths). The `_pgnotify_` suffix in the filenames at the root level identifies files written by the new pg_notify CDC writer. Total: 4 objects, 22,311 bytes.

The pg_notify CDC writer is actively producing output. Most recent file: 13:32 UTC (~11 minutes before this check).

### Error / Warning Logs

No errors or warnings for `new-dispo-cdc-datastream-sendung-abn1034` in the last 24h.

Warnings were logged for `orauat-1060-bucket` (4 entries, all about archive log file size exceeding 1 GB recommendation). These are unrelated to the abn1034 CDC pipeline.

---

## Supplemental: pg_notify CDC Writer (Cloud Run)

Since the Datastream stream is intentionally PAUSED and replaced by the pg_notify CDC writer, this section documents the health of the replacement mechanism.

| Check | Value | Status |
|-------|-------|--------|
| Cloud Run Ready | True | PASS |
| ConfigurationsReady | True | PASS |
| RoutesReady | True | PASS |
| Last Deploy | 2026-06-15T13:03:50Z | |
| Errors (last 1h) | none | PASS |
| Last Bucket Write | 2026-06-15T13:32:50Z | PASS |

The pg_notify CDC writer is healthy and actively processing events. It writes Datastream-compatible JSONL files to the same GCS bucket, which the existing Cloud Function picks up unchanged.

---

## Interpretation

The abn1034 CDC pipeline is in a **transitional state**: the original Datastream mechanism has been intentionally replaced by a pg_notify CDC writer (Cloud Run, PRD 004), but the cleanup of the old Datastream's replication slot has not been completed. The new pipeline is healthy — Cloud Run is running, JSONL files are being written to GCS, and the downstream Cloud Function is processing them successfully.

The critical issue is the orphaned logical replication slot `sendung_slot_abn1034`. With no consumer connected, it retains 199 GB of WAL (comparable to the 234 GB reached during the June 8 incident) and pins `catalog_xmin` at 125.7 M transactions behind current. At the current WAL production rate of ~2.4 GB/hour, the 800 GB safety net will be exhausted in approximately 11 days if the slot is not dropped. This is a ticking clock, not an emergency — but action is needed within days, not weeks.

The 3 `lost` AlloyDB physical slots are a secondary concern. They cannot accumulate WAL (their WAL was already reclaimed), but they indicate stale replicas that may need cleanup.

---

## Recommended Actions

1. **DROP the orphaned replication slot** (URGENT — within 48 hours):
   ```sql
   SELECT pg_drop_replication_slot('sendung_slot_abn1034');
   ```
   Coordinate with Nagel GCP team. Confirm the Datastream stream will not be resumed. This immediately releases 199 GB of WAL and unpins catalog_xmin.

2. **Investigate 3 `lost` AlloyDB physical slots** (LOW — within 1 week):
   Discuss with Nagel GCP team whether these represent stale read replicas that should be cleaned up.

3. **Re-run `/datastream-health` after slot drop** to confirm KPIs 1, 2, 3, 4, 11, 12 resolve. Expected post-drop state:
   - KPI 1: < 1 GB (only wal_uploader slot retaining WAL)
   - KPI 2: reserved
   - KPI 3: N/A (slot no longer exists)
   - KPI 11: N/A (no logical slots)
   - KPI 12: N/A (no logical slots)

4. **Consider deleting the PAUSED Datastream stream** after the slot is dropped, to avoid future confusion. This is a Datastream-level operation:
   ```bash
   gcloud datastream streams delete new-dispo-cdc-datastream-sendung-abn1034 \
     --location=europe-west3 \
     --project=prj-cal-w-wl5-t-6c00-53ad
   ```

---

## Commands Used

### Database Side (psql)

```sql
-- 1. Replication Slot Overview
SELECT
    slot_name, slot_type, plugin, active, wal_status,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag_pretty,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS unconfirmed_pretty,
    pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS unconfirmed_bytes
FROM pg_replication_slots;

-- 2. WAL Sender State
SELECT
    pid, usename, application_name, state,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS send_lag,
    sync_state
FROM pg_stat_replication;

-- 3. Hung Transactions (> 1 hour)
SELECT
    pid, usename, application_name, state,
    now() - xact_start AS transaction_duration,
    LEFT(query, 80) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
  AND application_name NOT LIKE 'google_cloudsql%'
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
ORDER BY xact_start ASC;

-- 4. Safety Net
SHOW max_slot_wal_keep_size;

-- 5. Slot xmin / catalog_xmin Diagnostic
SELECT
    slot_name, xmin, catalog_xmin,
    age(xmin) AS xmin_age,
    age(catalog_xmin) AS catalog_xmin_age,
    safe_wal_size
FROM pg_replication_slots
WHERE slot_type = 'logical';
```

Connection: `psql -h 10.100.47.236 -U tms1034 -d abn1034` (auth via .pgpass)

### Cloud Side (gcloud / gsutil)

```bash
# 5. Stream State
gcloud datastream streams list --location=europe-west3 \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --format="table(name.basename(), state, displayName)"

# 6. CDC Checkpoint Progression (silent stall detection)
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   resource.labels.stream_id="new-dispo-cdc-datastream-sendung-abn1034"
   jsonPayload.message:"CDC checkpointed"' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=5 \
  --format="table(timestamp, jsonPayload.message)" \
  --freshness=24h

# 7. Bucket Activity
gsutil ls -l "gs://abn1043-sendung-bucket-1/tms1034_sendung/" | tail -5

# 8. Error / Warning Logs (last 24h)
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   severity>=WARNING' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=10 \
  --format="table(timestamp, severity, resource.labels.stream_id, jsonPayload.message)" \
  --freshness=24h
```

---

## Reference

- Full runbook: `02_Explorations/2026-06-12_Datastream_Health_Check_Runbook/datastream-health-check-runbook.md`
- Monitoring concept: `02_Explorations/2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/`
- Incident history: Jan 2026 (422 GB uat2820), Mar 2026 (slot outage), Jun 8 2026 (234 GB abn1034 silent stall), Jun 12 2026 (107 GB abn1034 3-day stall)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
