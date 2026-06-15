---
name: datastream-health-report
description: Generate a markdown report from a /datastream-health run. Writes a timestamped file to 02_Explorations/2026-06-12_Datastream_Health_Check_Runbook/reports/. Use after running /datastream-health to persist the results as a local file.
allowed-tools: Bash,Read,Write
---

# Datastream Health Report Skill

Generates a structured markdown report from the results of a `/datastream-health` run and saves it as a timestamped file.

## When to Use

- After running `/datastream-health` to persist the results
- User asks to "save the health check", "create a report", "write the results"
- For archiving health check results over time

## Arguments

- `/datastream-health-report` — generates a report from the most recent `/datastream-health` run in the current conversation

## Prerequisites

This skill expects a `/datastream-health` run to have completed in the current conversation. It reads the results from conversation context — it does not re-run the checks.

If no health check has been run yet, tell the user to run `/datastream-health` first.

## Output Path

```
02_Explorations/2026-06-12_Datastream_Health_Check_Runbook/reports/YYYY-MM-DD_HHmm_datastream-health.md
```

Create the `reports/` directory if it doesn't exist.

## Report Template

Generate the report using the exact structure below, filling in values from the health check results. Use the current UTC timestamp for the report header.

````markdown
# Datastream Health Report — <DATABASE> — <DATE>

**Generated:** <YYYY-MM-DD HH:MM UTC>
**Database:** <database> (<host>)
**Stream:** <stream_id>
**Overall Status:** <HEALTHY / WARNING / CRITICAL>

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
| 1 | Slot WAL Lag | <value> | <PASS/WARN/FAIL> | PASS < 1 GB, WARN 1–10 GB, FAIL > 10 GB |
| 2 | WAL Status | <value> | <PASS/WARN/FAIL> | PASS = reserved, WARN = extended, FAIL = lost |
| 3 | Slot Active | <value> | <PASS/FAIL> | PASS = true, FAIL = false |
| 4 | WAL Sender | <value> | <PASS/WARN/FAIL> | PASS = streaming/connected, WARN = catchup > 1h, FAIL = absent |
| 5 | Hung Transactions | <value> | <PASS/WARN/FAIL> | PASS = 0, WARN = any < 4h, FAIL = any > 4h |
| 6 | Safety Net | <value> | <PASS/WARN> | PASS = configured, WARN = not set (-1) |
| 7 | CDC Advancing | <value> | <PASS/FAIL> | PASS = LSN advancing, FAIL = frozen |
| 8 | Bucket Writes | <value> | <PASS/WARN/FAIL> | PASS < 5 min, WARN < 1h, FAIL > 1h |
| 9 | Stream State | <value> | <PASS/FAIL> | PASS = RUNNING, FAIL = PAUSED/FAILED |
| 10 | Error Logs | <value> | <PASS/WARN/FAIL> | PASS = none, WARN = warnings only, FAIL = errors |
| 11 | catalog_xmin Age | <value> | <PASS/WARN/FAIL> | PASS < 1 M, WARN 1–10 M, FAIL > 10 M txns |
| 12 | restart_lsn Divergence | <ratio> | <PASS/WARN/FAIL> | PASS < 2×, WARN 2–100×, FAIL > 100× AND restart > 10 GB |

**Result: <X>/12 KPIs passing**

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

<Include this section only when KPIs 11 or 12 FAIL, or when follow-up diagnostics reveal a structural slot problem. Otherwise omit.>

<When included, document: what was found (table of xmin/catalog_xmin/age values), diagnosis (what is blocking restart_lsn), how it happened, why it won't self-heal, and the fix (drop/recreate steps).>

---

## Database Side — Detail

### Replication Slots

<Paste the full pg_replication_slots query output as a markdown table. Include ALL slots, not just the CDC slot — the physical/lost AlloyDB slots are useful context.>

### WAL Sender

<Paste the pg_stat_replication output as a markdown table, or note "no rows" / "state column empty (permission-limited view)" as applicable.>

### Hung Transactions

<If 0 rows: "None detected."
If rows exist: paste as markdown table with pid, user, duration, query preview.>

### Safety Net

`max_slot_wal_keep_size = <value>`

<Note whether this is defined in the TMS database schema repo or set directly on the instance. As of 2026-06-15, it is NOT in the schema repo — set directly on the AlloyDB instance.>

---

## Cloud Side — Detail

### Stream States

<Paste the gcloud streams list output as a markdown table.>

### CDC Checkpoint Progression

<List the checkpoint entries with timestamps, LSN values, and event timestamps. Highlight whether LSNs are advancing or frozen. Calculate the LSN delta between entries if available.>

### Bucket Activity

<List the most recent GCS files with timestamps and sizes. Note the write pattern (continuous vs sporadic) and when the last file was written.>

### Error / Warning Logs

<List any errors or warnings from the last 24h. Note which stream they belong to. If none for the target stream, state "No errors or warnings for <stream_id> in the last 24h.">

---

## Interpretation

<Write 2-4 sentences explaining what the numbers mean in plain language. Distinguish between data freshness (confirmed_flush_lsn lag) and WAL retention (restart_lsn lag) when relevant. Reference incident history if the current values are comparable to past incidents.>

---

## Recommended Actions

<If HEALTHY: "No action required."
If WARNING or CRITICAL: list specific numbered actions based on which KPIs failed. Use the failure pattern recommendations from the datastream-health skill.>

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

Connection: `psql -h <HOST> -U <USER> -d <DATABASE>` (auth via .pgpass)

### Cloud Side (gcloud / gsutil)

```bash
# 5. Stream State
gcloud datastream streams list --location=europe-west3 \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --format="table(name.basename(), state, displayName)"

# 6. CDC Checkpoint Progression (silent stall detection)
gcloud logging read \
  'resource.type="datastream.googleapis.com/Stream"
   resource.labels.stream_id="<STREAM_ID>"
   jsonPayload.message:"CDC checkpointed"' \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --limit=5 \
  --format="table(timestamp, jsonPayload.message)" \
  --freshness=2h

# 7. Bucket Activity
gsutil ls -l "gs://<BUCKET>/<PATH>/" | tail -10

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
````

## Behavior Rules

1. **Fill every section** — do not skip sections even if a check returned no data. Write "No data — check returned empty" or "UNKNOWN — connection failed" rather than omitting.
2. **Use exact query output** — paste the real psql/gcloud output, formatted as markdown tables. Do not paraphrase or summarize raw data.
3. **Commands section is static** — always include the full SQL and gcloud commands as shown in the template. Replace `<HOST>`, `<USER>`, `<DATABASE>`, `<STREAM_ID>`, `<BUCKET>`, `<PATH>` with the actual values used in this run.
4. **Filename format** — use UTC time: `YYYY-MM-DD_HHmm_datastream-health.md`. Example: `2026-06-15_0924_datastream-health.md`.
5. **Don't re-run checks** — use the results already in conversation context from the `/datastream-health` run.
6. **Virtual Architect footer** — always include the footer div at the bottom.
