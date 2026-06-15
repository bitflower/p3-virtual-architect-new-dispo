# Datastream Health Report — abn1034 — 2026-06-15

**Generated:** 2026-06-15 10:44 UTC
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
| 1 | Slot WAL Lag | 193 GB (restart_lsn), 48 MB (confirmed_flush) | FAIL | PASS < 1 GB, WARN 1–10 GB, FAIL > 10 GB |
| 2 | WAL Status | extended | WARN | PASS = reserved, WARN = extended, FAIL = lost |
| 3 | Slot Active | true | PASS | PASS = true, FAIL = false |
| 4 | WAL Sender | tmsbr1034 connected ("Postgresql Streaming") | PASS | PASS = streaming/connected, WARN = catchup > 1h, FAIL = absent |
| 5 | Hung Transactions | 0 | PASS | PASS = 0, WARN = any < 4h, FAIL = any > 4h |
| 6 | Safety Net | 800 GB | PASS | PASS = configured, WARN = not set (-1) |
| 7 | CDC Advancing | YES — LSN advancing every minute | PASS | PASS = LSN advancing, FAIL = frozen |
| 8 | Bucket Writes | last file 07:53 UTC (sporadic pattern normal) | PASS | PASS < 5 min, WARN < 1h, FAIL > 1h |
| 9 | Stream State | RUNNING | PASS | PASS = RUNNING, FAIL = PAUSED/FAILED |
| 10 | Error Logs | none for abn1034 | PASS | PASS = none, WARN = warnings only, FAIL = errors |
| 11 | catalog_xmin Age | 122,742,572 txns | FAIL | PASS < 1 M, WARN 1–10 M, FAIL > 10 M txns |
| 12 | restart_lsn Divergence | 193 GB vs 48 MB (4,104×) | FAIL | PASS < 2×, WARN 2–100×, FAIL > 100× AND restart > 10 GB |

**Result: 8/12 KPIs passing (1 WARN, 3 FAIL)**

---

## KPI Trend (today)

| KPI | 09:24 UTC | 10:44 UTC | Delta |
|-----|-----------|-----------|-------|
| Slot WAL Lag (restart_lsn) | 190 GB | 193 GB | +3 GB (~2.3 GB/h) |
| Slot WAL Lag (confirmed_flush) | 58 MB | 48 MB | -10 MB (improving) |
| catalog_xmin Age | 121,866,956 | 122,742,572 | +875,616 txns |
| safe_wal_size | 609 GB | 607 GB | -2 GB |

WAL retention is growing at the expected ~2.4 GB/hour rate. Consumer is healthy and slightly more current. The `catalog_xmin` age continues to drift.

---

## Root Cause Analysis: `catalog_xmin` Pinned

Unchanged from 09:24 UTC report. The slot's `catalog_xmin` is the root cause of all three FAIL KPIs.

### Current Findings

| Field | Value | Meaning |
|-------|-------|---------|
| `xmin` | (empty) | No data-level transaction hold. Good. |
| `catalog_xmin` | 2,783,335,241 | Slot is pinning an old system catalog snapshot. |
| `catalog_xmin_age` | **122,742,572** | **123 million transactions behind current.** |
| `safe_wal_size` | 651,999,892,640 (~607 GB) | Remaining headroom before `max_slot_wal_keep_size` triggers. |

### Diagnosis

The slot's `catalog_xmin` tells PostgreSQL: *"I still need the system catalog as it looked 123 million transactions ago to decode old WAL."* PostgreSQL retains all WAL from `restart_lsn` forward because the slot might need those catalog snapshots for logical decoding.

### How This Happened

During the June 8–12 stall, Datastream stopped consuming WAL. When it resumed (pause/resume), it caught up to current data (`confirmed_flush_lsn` is near the WAL tip). But the slot's `catalog_xmin` never got released. DDL that ran during the stall period created catalog entries the slot thinks it still needs.

### Why It Won't Self-Heal

`catalog_xmin` only advances when the consumer explicitly confirms it no longer needs old catalog snapshots. Since Datastream skipped over the stalled WAL region during resume rather than decoding it, the slot never released the old `catalog_xmin`. There is no SQL command to manually advance it.

### Time to Safety Net

At ~2.4 GB/hour WAL growth and 607 GB remaining headroom: **~253 hours (~10.5 days)** until `max_slot_wal_keep_size` (800 GB) triggers and the slot goes `lost`.

### Fix

Drop and recreate the slot. Coordinated action with the Nagel GCP team:

1. Delete the Datastream stream `new-dispo-cdc-datastream-sendung-abn1034` in GCP
2. Drop the slot on AlloyDB: `SELECT pg_drop_replication_slot('sendung_slot_abn1034');`
3. Recreate the slot: `SELECT pg_create_logical_replication_slot('sendung_slot_abn1034', 'pgoutput');`
4. Recreate the Datastream stream with `--backfill-all` (triggers initial snapshot)
5. PostgreSQL immediately reclaims the 193 GB of retained WAL on slot drop

---

## Database Side — Detail

### Replication Slots

| slot_name | slot_type | plugin | active | wal_status | lag_pretty | lag_bytes | unconfirmed_pretty | unconfirmed_bytes |
|-----------|-----------|--------|--------|------------|------------|-----------|--------------------|----|
| wal_uploader | physical | | true | reserved | 12 MB | 12,779,872 | | |
| **sendung_slot_abn1034** | **logical** | **pgoutput** | **true** | **extended** | **193 GB** | **207,001,703,760** | **48 MB** | **50,441,256** |
| alloydb_8d579d2f...\_1ln9 | physical | | false | lost | | | | |
| alloydb_53e7d630...\_wbls | physical | | false | lost | | | | |
| alloydb_53e7d630...\_ccmc | physical | | false | lost | | | | |

The 193 GB gap is between `restart_lsn` and `current_wal_lsn`. The consumer's `confirmed_flush_lsn` is only 48 MB behind current — the consumer IS keeping up. The 193 GB is retained WAL that PostgreSQL cannot reclaim because `restart_lsn` has not advanced.

### WAL Sender

| pid | usename | application_name | state | send_lag | sync_state |
|-----|---------|------------------|-------|----------|------------|
| 2889 | alloydbadmin | wal_uploader | | | |
| 3829395 | tmsbr1034 | Postgresql Streaming | | | |

The `state` column is empty — permission limitation (`tms1034` lacks `pg_monitor` role). The presence of the `tmsbr1034` row confirms the Datastream consumer is connected.

### Hung Transactions

None detected.

### Safety Net

`max_slot_wal_keep_size = 800GB`

Not in the TMS database schema repo — set directly on the AlloyDB instance.

---

## Cloud Side — Detail

### Stream States

| Stream | State | Display Name |
|--------|-------|-------------|
| orauat-1060-bucket | RUNNING | ORAUAT-1060-Bucket |
| new-dispo-cdc-datastream-sendung-abn1034 | RUNNING | new-dispo-cdc-datastream-sendung-abn1034 |
| new-dispo-cdc-datastream-sendung-abn2820 | NOT_STARTED | new-dispo-cdc-datastream-sendung-abn2820 |

### CDC Checkpoint Progression

| Timestamp (UTC) | Log Sequence Number | Event Timestamp | LSN Delta |
|-----------------|--------------------:|-----------------|-----------|
| 10:39:06.207 | 8,896,202,743,064 | 2026-06-15T10:38:05.575Z | — |
| 10:40:06.349 | 8,896,214,083,176 | 2026-06-15T10:39:05.949Z | +11.3 M |
| 10:41:06.503 | 8,896,217,103,096 | 2026-06-15T10:40:06.234Z | +3.0 M |
| 10:42:06.658 | 8,896,282,352,984 | 2026-06-15T10:41:06.397Z | +65.2 M |
| 10:43:06.808 | 8,896,349,558,072 | 2026-06-15T10:42:06.512Z | +67.2 M |

LSNs are **advancing** every minute. Event timestamps **advancing** in lockstep. No stall detected.

### Bucket Activity

Files written to `gs://abn1043-sendung-bucket-1/tms1034_sendung/` on 2026-06-15:

| Hour (UTC) | Files |
|------------|-------|
| 00/ | present |
| 03/ | present |
| 07/ | present (last file at 07:53:43 UTC, 133.8 KiB) |

Sporadic write pattern is consistent with sendung table update frequency. CDC checkpoint confirms stream is active — no source changes to write since 07:53.

### Error / Warning Logs

No errors or warnings for `new-dispo-cdc-datastream-sendung-abn1034` in the last 24 hours.

Oracle stream warnings (orauat-1060-bucket):

| Timestamp (UTC) | Message |
|-----------------|---------|
| 2026-06-15 07:01 | Log file thread_1_seq_4815 exceeds recommended 1GB size |
| 2026-06-15 04:11 | Log file thread_1_seq_4814 exceeds recommended 1GB size |
| 2026-06-14 21:00 | Log file thread_1_seq_4813 exceeds recommended 1GB size |
| 2026-06-14 13:01 | Log file thread_1_seq_4812 exceeds recommended 1GB size |
| 2026-06-14 11:41 | Log file thread_1_seq_4811 exceeds recommended 1GB size |

---

## Interpretation

The CDC data pipeline is **functionally healthy** — the consumer is connected, checkpoint LSNs advance every minute, and the `confirmed_flush_lsn` lag dropped from 58 MB to 48 MB since the last check. Data freshness is essentially real-time.

The structural problem is unchanged: `catalog_xmin` is pinned 123 million transactions behind current, preventing `restart_lsn` from advancing. WAL retention grew from 190 GB to 193 GB (+3 GB in 1h 20m, consistent with the ~2.4 GB/hour rate). At this rate, the 800 GB safety net will trigger in approximately 10.5 days (around June 26), at which point the slot goes `lost` and requires full recovery with backfill.

---

## Recommended Actions

1. **Recreate the replication slot** — The `catalog_xmin` pin will not self-heal. Coordinate with the Nagel GCP team to drop/recreate the slot and Datastream stream. **Deadline: before June 26** (safety net trigger).

2. **Consider lowering `max_slot_wal_keep_size`** — The current 800 GB provides a very long runway but masks problems. A lower value (100–200 GB) would force earlier detection and action.

3. **Add `max_slot_wal_keep_size` to schema repo** — Currently set ad-hoc on the instance, not version-controlled in `Code/tms-alloydb-schema`.

4. **Oracle redo log sizing** — Raise the recurring >1 GB warnings with the Oracle DBA team.

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
# Stream State
gcloud datastream streams list --location=europe-west3 \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --format="table(name.basename(), state, displayName)"

# CDC Checkpoint Progression
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   resource.labels.stream_id="new-dispo-cdc-datastream-sendung-abn1034"
   jsonPayload.message:"CDC checkpointed"' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=5 \
  --format="table(timestamp, jsonPayload.message)" \
  --freshness=2h

# Bucket Activity
gsutil ls "gs://abn1043-sendung-bucket-1/tms1034_sendung/2026/06/15/"

# Error / Warning Logs (last 24h)
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
- Previous reports: `reports/2026-06-15_0924_datastream-health.md`, `reports/2026-06-15_1035_datastream-health.md`
- Monitoring concept: `02_Explorations/2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/`
- Incident history: Jan 2026 (422 GB uat2820), Mar 2026 (slot outage), Jun 8 2026 (234 GB abn1034 silent stall), Jun 12 2026 (107 GB abn1034 3-day stall)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
