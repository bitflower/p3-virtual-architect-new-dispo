# Datastream Health Report — abn1034 — 2026-06-16

**Generated:** 2026-06-16 18:15 UTC
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
| 1 | Slot WAL Lag | 266 GB (restart), 68 GB (flush) | FAIL | PASS < 1 GB, WARN 1–10 GB, FAIL > 10 GB |
| 2 | WAL Status | extended | WARN | PASS = reserved, WARN = extended, FAIL = lost |
| 3 | Slot Active | false | FAIL | PASS = true, FAIL = false |
| 4 | WAL Sender | absent (no logical sender) | FAIL | PASS = streaming/connected, WARN = catchup > 1h, FAIL = absent |
| 5 | Hung Transactions | 0 | PASS | PASS = 0, WARN = any < 4h, FAIL = any > 4h |
| 6 | Safety Net | 800 GB | PASS | PASS = configured, WARN = not set (-1) |
| 7 | CDC Advancing | no — stream PAUSED, no checkpoints in 2h | FAIL | PASS = LSN advancing, FAIL = frozen |
| 8 | Bucket Writes | no Datastream writes (stream paused); pgnotify files active | FAIL | PASS < 5 min, WARN < 1h, FAIL > 1h |
| 9 | Stream State | PAUSED | FAIL | PASS = RUNNING, FAIL = PAUSED/FAILED |
| 10 | Error Logs | none for abn1034 stream (24h) | PASS | PASS = none, WARN = warnings only, FAIL = errors |
| 11 | catalog_xmin Age | 155,661,159 txns (~156M) | FAIL | PASS < 1 M, WARN 1–10 M, FAIL > 10 M txns |
| 12 | restart_lsn Divergence | 3.9x (266 GB / 68 GB) | WARN | PASS < 2x, WARN 2–100x, FAIL > 100x AND restart > 10 GB |

**Result: 3/12 KPIs passing, 2 warning, 7 failing**

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
- **< 2x**: Normal. Both positions advance together.
- **2–100x**: Moderate divergence. May indicate start of catalog_xmin pin or post-stall cleanup.
- **> 100x AND restart > 10 GB**: Critical. Consumer is current but slot retains massive WAL. Check KPI 11 to confirm catalog_xmin pin.

---

## Root Cause Analysis

### catalog_xmin Pin — Structural Slot Problem (ongoing)

| Field | Value |
|-------|-------|
| slot_name | sendung_slot_abn1034 |
| xmin | (null) |
| catalog_xmin | 2,783,335,241 |
| xmin_age | (null) |
| catalog_xmin_age | 155,661,159 |
| safe_wal_size | 573,861,460,552 (~534 GB remaining) |
| restart_lsn_lag | 266 GB |
| flush_lag | 68 GB |

**Diagnosis:** The slot's `catalog_xmin` is pinned at transaction 2,783,335,241, which is 156 million transactions behind the current transaction ID. This prevents PostgreSQL from advancing `restart_lsn` even when the consumer (Datastream) has confirmed processing WAL up to `confirmed_flush_lsn`. The result: WAL accumulates indefinitely at ~2.3 GB/hour regardless of consumer activity.

**How it happened:** The `catalog_xmin` is set when the logical replication slot needs to reference the system catalog (pg_class, pg_attribute, etc.) to decode WAL entries. When the consumer disconnects or stalls for an extended period, the catalog_xmin freezes. Even after the consumer reconnects and catches up on data, the catalog_xmin remains pinned — PostgreSQL cannot advance it without the consumer explicitly releasing it, which `pgoutput` (the plugin used by Datastream) does not do during normal operation.

**Why it won't self-heal:** The `catalog_xmin` is an internal slot property managed by the replication protocol. Datastream's WAL consumer does not issue the protocol messages needed to advance it. Pause/resume cycles do not reset it. Only dropping and recreating the slot clears the pinned catalog_xmin.

**Fix:** Coordinated slot drop and recreate with the Nagel GCP team. Steps:
1. Pause the Datastream stream (already PAUSED)
2. Drop `sendung_slot_abn1034` on AlloyDB
3. Recreate the slot (Datastream does this on resume)
4. Resume the stream — triggers full backfill
5. Verify catalog_xmin age is < 1M after reconnection

**Safety margin:** safe_wal_size = 534 GB remaining. At ~2.3 GB/hour WAL production, the slot will hit the 800 GB cap in approximately **9.7 days** (~June 26). At that point PostgreSQL will invalidate the slot (`wal_status = lost`) and the stream will require full recovery regardless.

### Stream Intentionally Paused

The stream state is **PAUSED** — this is a deliberate action, not a failure. However, while paused, the slot remains on the database and WAL continues to accumulate. Combined with the pinned catalog_xmin, the pause accelerates the countdown to slot invalidation because both restart_lsn AND confirmed_flush_lsn lag grow simultaneously.

**Trend across all reports:**

| Report | restart_lsn Lag | flush Lag | catalog_xmin Age | safe_wal_size |
|--------|----------------|-----------|------------------|---------------|
| Jun 15, 09:24 | 175 GB | — | 113M | 671 GB |
| Jun 15, 10:44 | 179 GB | — | 115M | 667 GB |
| Jun 15, 13:43 | 186 GB | — | 120M | 659 GB |
| Jun 16, 07:00 | 238 GB | 41 GB | 143M | 562 GB |
| **Jun 16, 18:15** | **266 GB** | **68 GB** | **156M** | **534 GB** |

WAL lag grew 28 GB in ~11 hours since the morning check (~2.5 GB/hr). The flush lag also grew 27 GB — confirming the stream is paused and consumer backlog is now growing at the same rate as the restart_lsn lag.

---

## Database Side — Detail

### Replication Slots

| slot_name | slot_type | plugin | active | wal_status | lag_pretty | lag_bytes | unconfirmed_pretty | unconfirmed_bytes |
|-----------|-----------|--------|--------|------------|------------|-----------|--------------------|--------------------|
| wal_uploader | physical | | t | reserved | 3088 kB | 3,162,560 | | |
| sendung_slot_abn1034 | logical | pgoutput | f | extended | 266 GB | 285,140,358,576 | 68 GB | 73,381,244,632 |
| alloydb_8d579d2f_5477_4ff6_b5e0_a7763395fc81_1ln9 | physical | | f | lost | | | | |
| alloydb_53e7d630_89e7_4de4_a9b1_33edeeb760f6_wbls | physical | | f | lost | | | | |
| alloydb_53e7d630_89e7_4de4_a9b1_33edeeb760f6_ccmc | physical | | f | lost | | | | |

Note: The 3 AlloyDB physical slots (`alloydb_*`) are all inactive with `wal_status = lost`. These appear to be orphaned replica slots from previous AlloyDB read-replica configurations — not CDC-related. They should be cleaned up by the GCP team to avoid confusion.

### WAL Sender

| pid | usename | application_name | state | send_lag | sync_state |
|-----|---------|------------------|-------|----------|------------|
| 2889 | alloydbadmin | wal_uploader | | | |

Only the physical `wal_uploader` sender is present. No logical replication WAL sender exists for `sendung_slot_abn1034` — expected since the stream is PAUSED. The empty `state` column is likely a permissions limitation of the `tms1034` user.

### Hung Transactions

None detected.

### Safety Net

`max_slot_wal_keep_size = 800GB`

This is set directly on the AlloyDB instance. As of 2026-06-15, this parameter is NOT managed in the `tms-alloydb-schema` repository — it was configured manually on the instance by the Nagel GCP team.

---

## Cloud Side — Detail

### Stream States

| Name | State | Display Name |
|------|-------|-------------|
| orauat-1060-bucket | RUNNING | ORAUAT-1060-Bucket |
| new-dispo-cdc-datastream-sendung-abn1034 | PAUSED | new-dispo-cdc-datastream-sendung-abn1034 |
| new-dispo-cdc-datastream-sendung-abn2820 | NOT_STARTED | new-dispo-cdc-datastream-sendung-abn2820 |

The abn1034 stream is **PAUSED**. The abn2820 stream has never been started.

### CDC Checkpoint Progression

No checkpoint entries found in the last 2 hours. Expected — the stream is PAUSED and not producing CDC checkpoints.

### Bucket Activity

Most recent files in `gs://abn1043-sendung-bucket-1/tms1034_sendung/`:

| Timestamp | Size | File |
|-----------|------|------|
| 2026-06-16T13:35:59Z | 8,952 B | `fe08e5d7-..._pgnotify_1781616959355.jsonl` |
| 2026-06-16T11:07:58Z | 8,928 B | `ff114db2-..._pgnotify_1781608078474.jsonl` |

These are **PG Notify CDC files** (from the alternative Cloud Function CDC mechanism), NOT Datastream output. Datastream writes are in the `2026/` subfolder. No new Datastream writes expected while stream is paused.

The PG Notify mechanism is active and writing — last file 2026-06-16T13:35:59Z (~4.5 hours ago). This is the operational CDC path while the Datastream stream remains paused.

Total bucket contents: 190 objects, 1.41 MiB.

### Error / Warning Logs

No errors or warnings for `new-dispo-cdc-datastream-sendung-abn1034` in the last 24 hours.

Warnings present for `orauat-1060-bucket` (Oracle stream, unrelated):

| Timestamp | Severity | Stream | Message |
|-----------|----------|--------|---------|
| 2026-06-16T18:12:19Z | WARNING | orauat-1060-bucket | Log file size exceeds recommended 1GB |
| 2026-06-16T11:01:44Z | WARNING | orauat-1060-bucket | Log file size exceeds recommended 1GB |
| 2026-06-16T09:07:41Z | WARNING | orauat-1060-bucket | Log file size exceeds recommended 1GB |
| 2026-06-16T01:01:26Z | WARNING | orauat-1060-bucket | Log file size exceeds recommended 1GB |
| 2026-06-15T23:25:19Z | WARNING | orauat-1060-bucket | Log file size exceeds recommended 1GB |

These are recurring Oracle archive log size warnings on the UAT-1060 stream. Not actionable for the abn1034 CDC pipeline.

---

## Interpretation

The CDC pipeline for abn1034 is in a **critical but stable-degraded state**. The Datastream stream has been intentionally **PAUSED**, which explains the inactive slot, absent WAL sender, and lack of CDC checkpoints — these are consequences of the pause, not independent failures. WAL is accumulating at ~2.3–2.5 GB/hour against a 800 GB cap with 534 GB remaining, giving roughly 9.7 days before forced slot invalidation (~June 26).

The structural problem is the pinned `catalog_xmin` at 156 million transactions behind current. Even if the stream is resumed, the restart_lsn lag (266 GB) will never fully resolve because the catalog_xmin prevents WAL cleanup. The flush lag (68 GB) represents the actual consumer backlog that would need to be processed on resume — at typical catchup rates, this could take 1–2 days.

The **PG Notify CDC mechanism is operational** — recent pgnotify files in the bucket (last write ~4.5 hours ago) confirm the alternative CDC path is serving production data needs while Datastream remains paused. This mitigates the immediate data freshness risk but does not address the growing WAL retention problem on the database.

---

## Recommended Actions

1. **Decide on the Datastream stream's future** (KPI 9 — PAUSED): The stream is intentionally paused, but the slot continues consuming WAL. Two options:
   - **If Datastream CDC will be used again:** Plan coordinated slot drop/recreate before June 26. Resume stream after slot recreation.
   - **If PG Notify CDC has replaced Datastream permanently:** Drop the slot entirely to stop WAL accumulation. Delete or archive the stream.

2. **Drop the replication slot** (KPI 11 — catalog_xmin pinned at 156M): Regardless of whether Datastream continues, the current slot is structurally broken. The catalog_xmin will never advance, and WAL will grow until the 800 GB cap is hit. Dropping the slot is the only way to release the retained 266 GB of WAL.

3. **Clean up orphaned AlloyDB slots**: Three physical slots (`alloydb_*`) are inactive with `wal_status = lost`. Drop them to reduce confusion: `SELECT pg_drop_replication_slot('<slot_name>');`

4. **Monitor WAL growth rate**: If no action is taken, the slot reaches the 800 GB cap around June 26. Set a calendar reminder for June 23 (3-day warning) to force a decision.

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
    safe_wal_size,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS restart_lsn_lag,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS flush_lag
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
  --freshness=2h

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
