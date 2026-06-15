# Datastream Health Check Runbook

**Date:** 2026-06-12
**Status:** Reference
**Sources:** Extracted from explorations 2026-01-30 through 2026-06-12

---

## Quick Reference: Copy-Paste Health Check

Run these three checks in sequence for a complete end-to-end assessment.

### 1. Replication Slot Health (psql → AlloyDB)

```sql
SELECT
    slot_name,
    slot_type,
    plugin,
    active,
    wal_status,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag_pretty,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS unconfirmed_pretty,
    pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS unconfirmed_bytes
FROM pg_replication_slots;
```

### 2. Datastream Stream State (gcloud)

```bash
gcloud datastream streams list --location=europe-west3 \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --format="table(name.basename(), state, displayName)"
```

### 3. GCS Bucket Activity (gcloud)

```bash
gsutil ls -l "gs://abn1043-sendung-bucket-1/tms1034_sendung/" | tail -5
```

---

## Part 1: Database-Level Checks (SQL via psql)

All queries run against AlloyDB instances directly. Use `.pgpass` for authentication.

### 1.1 Replication Slot Overview

The primary health indicator. Shows all slots, their type, consumer status, and WAL lag.

```sql
SELECT
    slot_name,
    slot_type,
    plugin,
    active,
    wal_status,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag_pretty,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS unconfirmed_pretty,
    pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS unconfirmed_bytes
FROM pg_replication_slots;
```

**What to look for:**

| Field | Healthy | Warning | Critical |
|-------|---------|---------|----------|
| `active` | `true` | — | `false` (consumer disconnected) |
| `wal_status` | `reserved` | `extended` (WAL growing beyond `wal_keep_size`) | `lost` (slot invalid, full resync needed) |
| `lag_bytes` | < 1 GB | 1–10 GB | > 10 GB |
| `unconfirmed_bytes` | < 500 MB | 500 MB – 5 GB | > 5 GB |

**Known slots:**

| Database | Slot Name | Publication | Datastream Stream |
|----------|-----------|-------------|-------------------|
| abn1034 | `sendung_slot_abn1034` | `sendung_pub` | `new-dispo-cdc-datastream-sendung-abn1034` |
| abn2820 | `sendung_slot_uat2820` | `sendung_pub` | `new-dispo-cdc-datastream-sendung-abn2820` |

### 1.2 WAL Sender Process State

Shows what the WAL Sender process is doing — the actual process that streams WAL to Datastream.

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS send_lag,
    sync_state
FROM pg_stat_replication;
```

**WAL Sender states:**

| State | Meaning | Action |
|-------|---------|--------|
| `streaming` | Healthy — real-time CDC active | None |
| `catchup` | Consumer behind, reading historical WAL | Monitor — should transition to `streaming` |
| `startup` | Just connected, initializing | Wait |
| (no row) | No active WAL sender — consumer disconnected | Check Datastream stream state |

### 1.3 Long-Running Transactions (Blocker Detection)

Long-running transactions prevent WAL cleanup and can cause replication lag to grow even when Datastream is healthy. This was the root cause of the Jan 2026 incident (422 GB lag on uat2820).

```sql
SELECT
    pid,
    usename,
    application_name,
    datname,
    state,
    now() - xact_start AS transaction_duration,
    now() - query_start AS query_duration,
    wait_event_type,
    wait_event,
    LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
  AND application_name NOT LIKE 'google_cloudsql%'
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
ORDER BY xact_start ASC;
```

**Thresholds:**

| Duration | Severity | Action |
|----------|----------|--------|
| > 1 hour | Warning | Investigate source application |
| > 4 hours | Critical | Likely hung — prepare to terminate |
| > 1 day | Emergency | Terminate immediately (`pg_terminate_backend(pid)`) |

### 1.4 Hung Transaction Count (Quick Check)

```sql
SELECT
    COUNT(*) AS hung_count,
    MAX(now() - xact_start) AS max_duration
FROM pg_stat_activity
WHERE state != 'idle'
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
  AND application_name NOT LIKE 'google_cloudsql%';
```

**Expected:** `hung_count = 0`

### 1.5 WAL Production Rate

Baseline reference: abn1034 produces ~2.4 GB/hour of WAL (observed June 8, 2026).

```sql
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS total_wal_produced;
```

Run twice with a time gap to calculate production rate:
```
Rate (GB/hour) = (wal_bytes_t2 - wal_bytes_t1) / seconds_elapsed * 3600 / (1024^3)
```

### 1.6 Replication Slot Lag Trend (Repeat Every 15–30 Min)

Track lag progression to determine if the consumer is catching up or falling behind.

```sql
SELECT
    slot_name,
    active,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS current_lag,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes,
    now() AS checked_at
FROM pg_replication_slots
WHERE slot_name LIKE 'sendung_%';
```

**Catchup rate formula:**
```
Rate (GB/hr) = (previous_lag_bytes - current_lag_bytes) / seconds_elapsed * 3600 / (1024^3)
ETA to zero = current_lag_bytes / rate_bytes_per_sec / 3600 (hours)
```

### 1.7 Database Disk Usage

WAL accumulation from stalled consumers creates disk pressure.

```sql
SELECT
    pg_size_pretty(pg_database_size(current_database())) AS db_size,
    pg_size_pretty(pg_total_relation_size('sendung')) AS sendung_table_size;
```

### 1.8 Publication Configuration

Verify the publication is correctly scoped to a single table (not `FOR ALL TABLES`).

```sql
SELECT
    p.pubname,
    p.puballtables,
    pt.schemaname,
    pt.tablename
FROM pg_publication p
LEFT JOIN pg_publication_tables pt ON p.pubname = pt.pubname
WHERE p.pubname LIKE 'sendung%';
```

**Expected:** `puballtables = false`, single table listed per publication.

### 1.9 Safety Net Configuration Check

Check if `max_slot_wal_keep_size` is configured (recommended: 100 GB).

```sql
SHOW max_slot_wal_keep_size;
```

**Expected:** A configured value (e.g., `100GB`). If empty or `-1`, there is no safety net — a stalled consumer can grow WAL indefinitely.

---

## Part 2: Google Cloud Checks (gcloud CLI)

All commands target project `prj-cal-w-wl5-t-6c00-53ad` in `europe-west3`.

### 2.1 Authentication

```bash
gcloud auth login
gcloud config set project prj-cal-w-wl5-t-6c00-53ad
```

### 2.2 Datastream Stream State

```bash
gcloud datastream streams list --location=europe-west3 \
  --format="table(name.basename(), state, displayName)"
```

**Expected states:**

| Stream | Expected State |
|--------|---------------|
| `new-dispo-cdc-datastream-sendung-abn1034` | RUNNING |
| `new-dispo-cdc-datastream-sendung-abn2820` | NOT_STARTED (not yet active) |
| `orauat-1060-bucket` | RUNNING |

**Important:** `RUNNING` does NOT mean healthy. The June 8 incident proved Datastream can report RUNNING while silently stalled.

### 2.3 Datastream Stream Details

Full configuration dump for a specific stream:

```bash
gcloud datastream streams describe new-dispo-cdc-datastream-sendung-abn1034 \
  --location=europe-west3 --format=json
```

### 2.4 CDC Checkpoint Logs (Silent Stall Detection)

The most important check for detecting silent stalls. Datastream logs `POSTGRES_CDC_FETCH_CHECKPOINT` every minute with the current LSN and event timestamp. If these values are frozen, the stream is stalled.

```bash
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   resource.labels.stream_id="new-dispo-cdc-datastream-sendung-abn1034"
   jsonPayload.message:"POSTGRES_CDC_FETCH_CHECKPOINT"' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=10 \
  --format="table(timestamp, jsonPayload.message)" \
  --freshness=1h
```

**What to look for:**
- `Latest fetched log sequence number` should be **increasing** between entries
- `Latest fetched event timestamp` should be **advancing**
- If both are frozen across multiple entries → **silent stall confirmed**

### 2.5 Datastream Error Logs

Check for any error conditions (note: silent stalls produce NO errors):

```bash
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   resource.labels.stream_id="new-dispo-cdc-datastream-sendung-abn1034"
   severity>=ERROR' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=20 \
  --format="table(timestamp, severity, jsonPayload.message)" \
  --freshness=7d
```

### 2.6 GCS Bucket Write Activity

Check when the last CDC files were written to the destination bucket:

```bash
gsutil ls -l "gs://abn1043-sendung-bucket-1/tms1034_sendung/" | tail -10
```

For a time-windowed check (files written in the last hour):

```bash
gsutil ls -l "gs://abn1043-sendung-bucket-1/tms1034_sendung/$(date -u +%Y/%m/%d/%H)/"
```

**What to look for:**
- Files should be appearing every ~60 seconds (configured rotation interval)
- File sizes should be > 0 bytes
- No files for > 5 minutes → consumer may be stalled

### 2.7 Datastream Pause/Resume (Intervention)

When a silent stall is confirmed, pause and resume the stream to reset the consumer:

```bash
# Pause
gcloud datastream streams update new-dispo-cdc-datastream-sendung-abn1034 \
  --location=europe-west3 \
  --state=PAUSED \
  --update-mask=state

# Wait for PAUSED state, then resume
gcloud datastream streams update new-dispo-cdc-datastream-sendung-abn1034 \
  --location=europe-west3 \
  --state=RUNNING \
  --update-mask=state
```

**Requires:** `datastream.streams.update` permission (currently held by Nagel GCP team, not by `x_matthias.max@nagel-group.com`).

### 2.8 Connection Profile Inventory

```bash
gcloud datastream connection-profiles list --location=europe-west3 \
  --format="table(name.basename(), type, displayName)"
```

### 2.9 Private Connection Health

```bash
gcloud datastream private-connections list --location=europe-west3 \
  --format="table(name.basename(), state, displayName)"
```

**Expected:** All private connections in `CREATED` state.

---

## Part 3: Monitoring KPIs and Alert Thresholds

### 3.1 Primary KPIs

These are the indicators that would have caught all three documented incidents early.

| KPI | Source | How to Check | Warning | Critical | Emergency |
|-----|--------|-------------|---------|----------|-----------|
| **Replication slot WAL lag** | `pg_replication_slots` SQL | Query 1.1 | > 10 GB (~4h at 2.4 GB/hr) | > 50 GB (~21h) | > 200 GB (disk pressure) |
| **WAL status** | `pg_replication_slots` SQL | Query 1.1 | `extended` | — | `lost` |
| **Slot active** | `pg_replication_slots` SQL | Query 1.1 | — | `false` (unexpected) | — |
| **WAL Sender state** | `pg_stat_replication` SQL | Query 1.2 | `catchup` for > 1h | No WAL sender row | — |
| **CDC checkpoint advancing** | gcloud logging | Command 2.4 | Frozen > 15 min | Frozen > 1h | Frozen > 6h |
| **GCS file writes** | gsutil | Command 2.6 | No files > 5 min | No files > 30 min | No files > 2h |
| **Hung transactions** | `pg_stat_activity` SQL | Query 1.3 | > 1 hour | > 4 hours | > 1 day |

### 3.2 Datastream Cloud Monitoring Metrics

Native GCP metrics — useful as supplementary signals but **cannot reliably detect silent stalls**.

| Metric | What It Shows | Limitation |
|--------|--------------|------------|
| `datastream.googleapis.com/stream/total_latency` | End-to-end CDC latency | Stops updating when stalled — no native "stale metric" alert |
| `datastream.googleapis.com/stream/event_count` | CDC events processed | Drops to zero, but zero can be legitimate (no source changes) |
| `datastream.googleapis.com/stream/unsupported_event_count` | Unprocessable events | Does not cover stalls |

**Supplementary alert:** Create a **metric-absence alert** on `total_latency` — if no data points for > 15 minutes, alert as Warning. This requires an MQL-based alerting policy.

### 3.3 AlloyDB Cloud Monitoring Metrics

Native AlloyDB metrics — do NOT cover replication slots.

| Metric | What It Shows | Covers Replication Slots? |
|--------|--------------|--------------------------|
| `alloydb.googleapis.com/instance/postgres/replication/maximum_lag` | Read replica lag | No — physical replicas only |
| `alloydb.googleapis.com/instance/postgres/replication/replicas` | Replica count | No |
| System Insights (CPU, memory, connections) | Instance health | No |

**Gap:** No native visibility into logical replication slot WAL lag. All replication slot monitoring requires executing SQL against the database directly.

### 3.4 Proposed Custom Metrics (Not Yet Implemented)

From the [monitoring concept](../2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/replication-slot-monitoring-concept-for-alloydb.md) — Cloud Function publishing to Cloud Monitoring:

| Custom Metric | Type | Description |
|---------------|------|-------------|
| `custom.googleapis.com/alloydb/replication_slot/lag_bytes` | GAUGE INT64 | WAL lag in bytes |
| `custom.googleapis.com/alloydb/replication_slot/unconfirmed_bytes` | GAUGE INT64 | Unconfirmed flush lag |
| `custom.googleapis.com/alloydb/replication_slot/active` | GAUGE INT64 | 1 = active, 0 = inactive |
| `custom.googleapis.com/alloydb/replication_slot/wal_status` | GAUGE INT64 | 0=reserved, 1=extended, 2=unreserved, 3=lost |

---

## Part 4: Emergency Response Procedures

### 4.1 Silent Stall Detected

**Symptoms:** Replication slot lag growing, stream reports RUNNING, CDC checkpoint frozen, no error logs.

**Steps:**
1. Confirm stall: Run Query 1.1 + Command 2.4
2. Request pause/resume from Nagel GCP team (or self-service if permission granted)
3. After resume: monitor lag every 15 min using Query 1.6
4. Calculate catchup ETA from lag trend

### 4.2 Hung Transactions Blocking WAL

**Symptoms:** Replication slot lag growing, WAL sender state is `streaming` (consumer is fine, but WAL can't be reclaimed).

**Steps:**
1. Identify blockers: Run Query 1.3
2. Verify safe to terminate: Run Query in [Incident Response Step 2](../2026-01-30-replication-slot-size/INCIDENT-RESPONSE.md)
3. Terminate: `SELECT pg_cancel_backend(<pid>);` (gentle), then `SELECT pg_terminate_backend(<pid>);` (force)
4. Monitor lag reduction: Query 1.6 every 15 min

**DO NOT terminate:**
- `application_name` containing `google_cloudsql`, `datastream`, or `replication`
- `backend_type = 'walsender'`
- `query` starting with `START_REPLICATION SLOT`

### 4.3 Slot Status `lost`

**Symptoms:** `wal_status = 'lost'` in Query 1.1. The safety net (`max_slot_wal_keep_size`) triggered, or PostgreSQL reclaimed WAL the consumer hadn't read yet.

**Steps:**
1. Record the last `confirmed_flush_lsn` — this marks the boundary of the data gap
2. Drop the invalidated slot: `SELECT pg_drop_replication_slot('sendung_slot_abn1034');`
3. Drop and recreate the Datastream stream (triggers full backfill)
4. Backfill the lost time window via targeted reconciliation or Datastream initial snapshot

### 4.4 Preventive Measures

```sql
-- Set transaction timeout to prevent hung transactions
ALTER ROLE [application_user] SET statement_timeout = '30min';
ALTER DATABASE abn1034 SET idle_in_transaction_session_timeout = '10min';

-- Safety net: cap WAL retention per slot (recommended: 100 GB)
ALTER SYSTEM SET max_slot_wal_keep_size = '100GB';
SELECT pg_reload_conf();
```

---

## Part 5: Environment Reference

### Databases

| Database | Type | Replication Slot | Publication | Datastream Stream | IP |
|----------|------|-----------------|-------------|-------------------|----|
| abn1034 | AlloyDB | `sendung_slot_abn1034` | `sendung_pub` | `new-dispo-cdc-datastream-sendung-abn1034` | 10.100.47.236 |
| abn2820 | AlloyDB | `sendung_slot_uat2820` | `sendung_pub` | `new-dispo-cdc-datastream-sendung-abn2820` | — |

### GCP Resources

| Resource | ID |
|----------|----|
| Project | `prj-cal-w-wl5-t-6c00-53ad` |
| Region | `europe-west3` |
| GCS Bucket (abn1034) | `abn1043-sendung-bucket-1` |
| VPC Peering Connection | `datastream-connectivity-wl5-t-t` |
| PSC Connection (Oracle) | `psc-datastream-t-wl5` |

### Incident History

| Date | Database | Slot | Peak Lag | Root Cause | Detection |
|------|----------|------|----------|------------|-----------|
| 2026-01-30 | uat2820 | `sendung_slot_uat2820` | 422 GB | Hung transactions (1+ day) blocking WAL | Manual discovery |
| 2026-03-17 | — | — | — | Replication slot outage | Manual discovery |
| 2026-06-08 | abn1034 | `sendung_slot_abn1034` | 234 GB | Silent Datastream stall (RUNNING, no errors) | Manual SQL check |
| 2026-06-12 | abn1034 | `sendung_slot_abn1034` | 107 GB | Bucket not receiving events for 3 days | Boyan reported via chat |

### Baseline Metrics

| Metric | Value | Source |
|--------|-------|--------|
| WAL production rate (abn1034) | ~2.4 GB/hour | Observed June 8, 2026 |
| Table count in abn1034 | 774 | `tms-alloydb-schema` repo |
| CDC table | 1 (`sendung`) | Publication `sendung_pub` |
| WAL filtering ratio | 1:774 | WAL Sender must parse all 774 tables' WAL to find sendung changes |

---

## Source Documents

| Document | Path |
|----------|------|
| June 8 Stall Investigation | `02_Explorations/2026-06-08_GCP_Datastream_Stall_Investigation_-_sendung_slot_abn1034_234GB_WAL_Lag/` |
| Monitoring Concept | `02_Explorations/2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/` |
| gcloud Operations Guide | `02_Explorations/2026-06-09_gcloud-tooling/` |
| WAL/Replication Reference (Gemini) | `00_Input/2026-06-10_Postgres-WAL-replication-slots-datastream-gemini.md` |
| Jan 2026 Incident (422 GB) | `02_Explorations/2026-01-30-replication-slot-size/` |
| June 12 Chat (107 GB, 3 days) | `00_Meetings/2026-06-12_abn1034-datastream-replication-slot-problem/` |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
