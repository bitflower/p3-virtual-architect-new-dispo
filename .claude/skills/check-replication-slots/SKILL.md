---
name: check-replication-slots
description: Check AlloyDB replication slot health via psql. Runs WAL lag, WAL sender state, hung transaction, publication, and safety net queries. Use when the user wants to check replication health, WAL lag, or database-side CDC status.
allowed-tools: Bash,Read
---

# Check Replication Slots Skill

Runs all database-side health checks against AlloyDB via psql. Requires VPN and `.pgpass` configured.

## When to Use

- User asks to "check replication slots", "check WAL lag", "check database health", "check CDC database side"
- During or after a Datastream incident
- Routine health check of the CDC pipeline database layer

## Arguments

The skill accepts an optional database argument:

- `/check-replication-slots` — checks **abn1034** (default)
- `/check-replication-slots abn2820` — checks abn2820
- `/check-replication-slots all` — checks both abn1034 and abn2820

## Known Databases

| Database | Host | Port | User | Schema | Replication Slot |
|----------|------|------|------|--------|-----------------|
| abn1034 | 10.100.47.236 | 5432 | tms1034 | tms1034 | `sendung_slot_abn1034` |
| abn2820 | (use AlloyDB IP) | 5432 | tms2820 | tms2820 | `sendung_slot_uat2820` |

The psql user matches the database name. Auth is via `.pgpass` — never use PGPASSWORD.

## Execution Steps

For each target database, run these queries **sequentially** via `psql`. Never use PGPASSWORD — the user has `.pgpass` configured.

### Step 1: Replication Slot Overview

```bash
psql -h <HOST> -U <DB_USER> -d <DATABASE> -c "
SELECT
    slot_name,
    slot_type,
    plugin,
    active,
    wal_status,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag_pretty,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS unconfirmed_pretty
FROM pg_replication_slots;
"
```

Assess each slot against these thresholds:

| Field | Healthy | Warning | Critical |
|-------|---------|---------|----------|
| `active` | `true` | — | `false` |
| `wal_status` | `reserved` | `extended` | `lost` |
| `lag_bytes` | < 1 GB | 1–10 GB | > 10 GB |

### Step 2: WAL Sender State

```bash
psql -h <HOST> -U <DB_USER> -d <DATABASE> -c "
SELECT
    pid,
    usename,
    application_name,
    state,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS send_lag,
    sync_state
FROM pg_stat_replication;
"
```

Key states: `streaming` = healthy, `catchup` = behind, no rows = consumer disconnected.

### Step 3: Hung Transaction Check

```bash
psql -h <HOST> -U <DB_USER> -d <DATABASE> -c "
SELECT
    pid,
    usename,
    application_name,
    state,
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

Any rows returned = hung transactions that may block WAL cleanup. Threshold: > 1h warning, > 4h critical, > 1 day emergency.

### Step 4: Publication Scope

```bash
psql -h <HOST> -U <DB_USER> -d <DATABASE> -c "
SELECT
    p.pubname,
    p.puballtables,
    pt.schemaname,
    pt.tablename
FROM pg_publication p
LEFT JOIN pg_publication_tables pt ON p.pubname = pt.pubname
WHERE p.pubname LIKE 'sendung%';
"
```

Expected: `puballtables = false`, single table per publication.

### Step 5: Safety Net Check

```bash
psql -h <HOST> -U <DB_USER> -d <DATABASE> -c "SHOW max_slot_wal_keep_size;"
```

Expected: a configured value (e.g. `100GB`). If `-1` or empty, there is no safety net.

## Output Format

After running all queries, produce a structured summary:

```
Replication Slot Health — <DATABASE>
=====================================
Checked at: <timestamp>

Slot: sendung_slot_<id>
  Active:       <true/false>      <PASS/FAIL>
  WAL Status:   <reserved/extended/lost>  <PASS/WARN/FAIL>
  WAL Lag:      <pretty>          <PASS/WARN/FAIL based on thresholds>
  Unconfirmed:  <pretty>

WAL Sender:     <state or "NO ACTIVE SENDER">  <PASS/WARN/FAIL>

Hung Transactions: <count>        <PASS if 0, WARN/FAIL otherwise>
  (list PIDs and durations if any)

Publication:    <name> → <schema.table>  <PASS if single table>
Safety Net:     max_slot_wal_keep_size = <value>  <PASS if set, WARN if -1>

Overall: <HEALTHY / WARNING / CRITICAL>
```

Use these severity rules for the overall assessment:
- **HEALTHY**: All checks pass, lag < 1 GB, status = reserved, active = true, no hung transactions
- **WARNING**: Lag 1–10 GB, OR wal_status = extended, OR 1+ hung transactions < 4h
- **CRITICAL**: Lag > 10 GB, OR wal_status = lost, OR active = false, OR hung transactions > 4h, OR no WAL sender

## Connection Details

The psql user matches the database name (abn1034 → `-U tms1034`, abn2820 → `-U tms2820`). Auth is via `.pgpass` — never use PGPASSWORD. Note: the `tms1034` user may not have `pg_monitor` role, so some `pg_stat_replication` columns may appear empty — the row existing is the key signal.

## Reference

Full runbook: `02_Explorations/2026-06-12_Datastream_Health_Check_Runbook/datastream-health-check-runbook.md`
Incident history: Jan 2026 (422 GB uat2820), June 2026 (234 GB abn1034), June 12 2026 (107 GB abn1034 3-day stall)
