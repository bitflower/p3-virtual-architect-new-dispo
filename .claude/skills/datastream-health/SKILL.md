---
name: datastream-health
description: End-to-end Datastream CDC health check combining database (psql) and cloud (gcloud) checks with KPI assessment. Use when the user wants a full health check, end-to-end CDC status, or complete pipeline assessment.
allowed-tools: Bash,Read
---

# Datastream Health Skill

Full end-to-end health assessment of the Datastream CDC pipeline. Combines database-side checks (replication slots, WAL, transactions) with cloud-side checks (stream state, CDC checkpoints, bucket activity) and produces a KPI-based assessment.

## When to Use

- User asks to "check datastream health", "full health check", "end-to-end CDC status", "pipeline health"
- As a regular health check combining both sides
- When investigating an incident and need the complete picture

## Arguments

- `/datastream-health` — full check of abn1034 (default, the active stream)
- `/datastream-health all` — check all databases and all streams
- `/datastream-health abn1034` or `/datastream-health abn2820` — specific database

## Execution Plan

Run database checks and cloud checks **in parallel** where possible, then combine into a single assessment.

### Phase 1: Database Side (psql)

Requires VPN. Use `-U tms1034` for abn1034 (user matches database name). Auth is via `.pgpass` — never use PGPASSWORD.

**1a. Replication Slot Status**

```bash
psql -h 10.100.47.236 -U tms1034 -d abn1034 -c "
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
"
```

**1b. WAL Sender State**

```bash
psql -h 10.100.47.236 -U tms1034 -d abn1034 -c "
SELECT
    pid, usename, application_name, state,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS send_lag,
    sync_state
FROM pg_stat_replication;
"
```

**1c. Hung Transactions**

```bash
psql -h 10.100.47.236 -U tms1034 -d abn1034 -c "
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
"
```

**1d. Safety Net**

```bash
psql -h 10.100.47.236 -U tms1034 -d abn1034 -c "SHOW max_slot_wal_keep_size;"
```

**1e. Slot xmin / catalog_xmin Diagnostic**

```bash
psql -h 10.100.47.236 -U tms1034 -d abn1034 -c "
SELECT
    slot_name,
    xmin,
    catalog_xmin,
    age(xmin) AS xmin_age,
    age(catalog_xmin) AS catalog_xmin_age,
    safe_wal_size,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS restart_lsn_lag,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS flush_lag
FROM pg_replication_slots
WHERE slot_type = 'logical';
"
```

### Phase 2: Cloud Side (gcloud)

Requires gcloud auth to project `prj-cal-w-wl5-t-6c00-53ad`.

**2a. Stream State**

```bash
gcloud datastream streams list --location=europe-west3 \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --format="table(name.basename(), state, displayName)"
```

**2b. CDC Checkpoint Progression**

```bash
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   resource.labels.stream_id="new-dispo-cdc-datastream-sendung-abn1034"
   jsonPayload.message:"CDC checkpointed"' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=5 \
  --format="table(timestamp, jsonPayload.message)" \
  --freshness=2h
```

Check if the log sequence number and event timestamp in the "CDC checkpointed" messages are advancing between entries. Frozen values = silent stall. Also expand freshness to 24h if 2h returns empty — the stream may write CDC data sporadically if the source table has infrequent changes.

**2c. Bucket Activity**

```bash
gsutil ls -l "gs://abn1043-sendung-bucket-1/tms1034_sendung/" | tail -5
```

**2d. Recent Errors**

```bash
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   severity>=WARNING' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=10 \
  --format="table(timestamp, severity, resource.labels.stream_id, jsonPayload.message)" \
  --freshness=24h
```

### Phase 3: KPI Assessment

After collecting all results, assess each KPI:

| # | KPI | Source | PASS | WARN | FAIL |
|---|-----|--------|------|------|------|
| 1 | Slot WAL Lag | Query 1a: `lag_bytes` | < 1 GB | 1–10 GB | > 10 GB |
| 2 | WAL Status | Query 1a: `wal_status` | `reserved` | `extended` | `lost` |
| 3 | Slot Active | Query 1a: `active` | `true` | — | `false` |
| 4 | WAL Sender | Query 1b: `state` | `streaming` | `catchup` > 1h | absent |
| 5 | Hung Txns | Query 1c: row count | 0 rows | 1+ rows < 4h | 1+ rows > 4h |
| 6 | Safety Net | Query 1d | configured | — | `-1` / not set |
| 7 | CDC Advancing | Check 2b: LSN progression | advancing | — | frozen |
| 8 | Bucket Writes | Check 2c: file timestamps | files < 5 min ago | files < 1h ago | no files > 1h |
| 9 | Stream State | Check 2a | RUNNING | — | PAUSED/FAILED |
| 10 | Error Logs | Check 2d | none | warnings only | errors present |
| 11 | catalog_xmin Age | Query 1e: `catalog_xmin_age` | < 1 M | 1–10 M | > 10 M txns |
| 12 | restart_lsn Divergence | Query 1e: restart vs flush lag | restart < 2× flush | restart 2–100× flush | restart > 100× flush AND restart > 10 GB |

### Phase 4: Output

```
Datastream CDC Pipeline — End-to-End Health Check
===================================================
Database: abn1034 (10.100.47.236)
Stream:   new-dispo-cdc-datastream-sendung-abn1034
Checked:  <timestamp>

DATABASE SIDE
─────────────
 1. Slot WAL Lag:      <value>          <PASS/WARN/FAIL>
 2. WAL Status:        <value>          <PASS/WARN/FAIL>
 3. Slot Active:       <value>          <PASS/FAIL>
 4. WAL Sender:        <state>          <PASS/WARN/FAIL>
 5. Hung Transactions: <count>          <PASS/WARN/FAIL>
 6. Safety Net:        <value>          <PASS/WARN>

SLOT HEALTH
───────────
11. catalog_xmin Age: <value>          <PASS/WARN/FAIL>
12. restart_lsn Div.: <ratio>          <PASS/WARN/FAIL>

CLOUD SIDE
──────────
 7. CDC Advancing:     <status>         <PASS/FAIL>
 8. Bucket Writes:     <last timestamp> <PASS/WARN/FAIL>
 9. Stream State:      <state>          <PASS/FAIL>
10. Error Logs:        <count>          <PASS/WARN/FAIL>

OVERALL: <HEALTHY / WARNING / CRITICAL>
KPIs:    <X>/12 passing

<If WARNING or CRITICAL, add a "Recommended Actions" section listing specific next steps based on which KPIs failed. Reference the emergency procedures from the runbook.>
```

## Overall Severity Rules

- **HEALTHY**: All 12 KPIs pass
- **WARNING**: Any KPI at WARN level, none at FAIL
- **CRITICAL**: Any KPI at FAIL level

## Error Handling

- If psql fails to connect: report database side as UNREACHABLE, continue with cloud checks
- If gcloud auth is expired: tell user to run `! gcloud auth login`, skip cloud checks, report what we have from database side
- If a specific query fails: report that KPI as UNKNOWN, continue with remaining checks
- Always produce the summary even if some checks fail — partial information is better than none

## Recommended Actions by Failure Pattern

Include these in the output when relevant:

**Silent Stall (KPI 7 FAIL + KPI 1 FAIL):**
→ Request pause/resume from Nagel GCP team or self-service if permission granted

**Hung Transactions (KPI 5 FAIL):**
→ Identify and terminate via `pg_terminate_backend()` after verifying not a replication connection

**Slot Lost (KPI 2 = `lost`):**
→ Full recovery needed: drop slot, recreate Datastream stream, backfill gap

**Consumer Disconnected (KPI 3 FAIL):**
→ Check Datastream stream state, may need restart

**catalog_xmin Pinned (KPI 11 FAIL + KPI 12 FAIL):**
→ Slot's catalog_xmin is preventing restart_lsn from advancing. Consumer is current but WAL accumulates indefinitely. Only fix: drop and recreate slot (coordinated with Nagel GCP team). See Root Cause Analysis in the Jun 15 health report.

**restart_lsn Divergence Without catalog_xmin (KPI 12 FAIL, KPI 11 PASS):**
→ Check for hung transactions (KPI 5), prepared transactions (`pg_prepared_xacts`), or xmin holds from other consumers.

## Baseline Reference

| Metric | Known Value | Source |
|--------|-------------|--------|
| WAL production rate (abn1034) | ~2.4 GB/hour | Observed June 8, 2026 |
| Table count | 774 | tms-alloydb-schema repo |
| WAL filtering ratio | 1:774 | Single table out of 774 |
| Historic peak lag | 422 GB | Jan 2026 uat2820 incident |

## Reference

Full runbook: `02_Explorations/2026-06-12_Datastream_Health_Check_Runbook/datastream-health-check-runbook.md`
Monitoring concept: `02_Explorations/2026-06-10_Replication_Slot_Monitoring_Concept_for_AlloyDB/`
gcloud operations: `02_Explorations/2026-06-09_gcloud-tooling/`
