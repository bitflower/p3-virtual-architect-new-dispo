# Incident Response: UAT2820 Replication Slot 422GB Lag

**Date**: 2026-01-30
**Database**: uat2820
**Replication Slot**: `sendung_slot_uat2820`
**Lag**: 422 GB (7 days behind)
**Status**: Datastream is running but very slow

## Executive Summary

Datastream is functional but processing data from Jan 23 (7 days behind). Multiple long-running transactions (1+ days) are blocking WAL cleanup, preventing the replication slot from advancing efficiently.

**Primary Action Required**: Identify and terminate hung transactions blocking WAL progression.

---

## Step-by-Step Resolution

### Step 1: Identify Long-Running Transactions

```sql
-- Find all transactions running longer than 1 hour
-- Excluding idle connections and replication slots
SELECT
    pid,
    usename,
    application_name,
    datname,
    state,
    now() - xact_start AS transaction_duration,
    now() - query_start AS query_duration,
    now() - state_change AS state_duration,
    wait_event_type,
    wait_event,
    LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()  -- Don't show this query
  AND application_name NOT LIKE 'google_cloudsql%'  -- Keep Datastream connections
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
ORDER BY xact_start ASC;
```

**Expected Output**: List of PIDs with their durations and query details

**Action**: Document the PIDs and queries before proceeding

### Step 2: Verify Which Sessions Are Safe to Terminate

```sql
-- Double-check these are NOT replication connections
SELECT
    pid,
    usename,
    application_name,
    backend_type,
    query
FROM pg_stat_activity
WHERE pid IN (<list_of_pids_from_step_1>);
```

**DO NOT TERMINATE**:
- `application_name` containing `google_cloudsql`, `datastream`, or `replication`
- `backend_type = 'walsender'`
- `query` starting with `START_REPLICATION SLOT`

**SAFE TO TERMINATE**:
- Application queries stuck in `active` state
- Queries with `SAVEPOINT` that have been running for days
- Cursor operations (`Close 'SQL_CUR...'`) stuck for extended periods
- SELECT queries from application connections

### Step 3: Terminate Hung Transactions

```sql
-- For each problematic PID, first try gentle termination
SELECT pg_cancel_backend(<pid>);

-- Wait 30 seconds, check if it's still there
SELECT pid, state FROM pg_stat_activity WHERE pid = <pid>;

-- If still present, force termination
SELECT pg_terminate_backend(<pid>);
```

**Template for Documentation**:
```
Terminated PIDs:
- PID: 15388, User: [user], App: [app], Duration: 1 day 20:27:38, Query: [first 100 chars]
- PID: 258399, User: [user], App: [app], Duration: [duration], Query: [first 100 chars]
...
```

### Step 4: Immediate Verification

```sql
-- Check replication slot lag
SELECT
    slot_name,
    active,
    pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS current_lag,
    pg_current_wal_lsn() - restart_lsn AS lag_bytes  -- For calculations
FROM pg_replication_slots
WHERE slot_name = 'sendung_slot_uat2820';
```

**Record the baseline**:
- Current lag size: _________
- Lag bytes: _________
- Timestamp: _________

### Step 5: Monitor Progress (Every 15-30 minutes)

```sql
-- Re-run the lag check
SELECT
    slot_name,
    active,
    pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS current_lag,
    (pg_current_wal_lsn() - restart_lsn) AS lag_bytes
FROM pg_replication_slots
WHERE slot_name = 'sendung_slot_uat2820';
```

**Calculate catchup rate**:
```
Rate (bytes/sec) = (previous_lag_bytes - current_lag_bytes) / seconds_elapsed
Rate (GB/hour) = rate_bytes_per_sec * 3600 / 1024^3

Estimated time to zero = current_lag_bytes / rate_bytes_per_sec / 3600 (hours)
```

**Progress Tracking Table**:
| Time | Lag (GB) | Lag (bytes) | Change | Rate (GB/hr) | ETA |
|------|----------|-------------|--------|--------------|-----|
| 10:00 | 422 | 453,093,474,304 | - | - | - |
| 10:30 | ___ | ___ | ___ | ___ | ___ |
| 11:00 | ___ | ___ | ___ | ___ | ___ |

### Step 6: Check for New Long-Running Transactions

```sql
-- Ensure no new hung transactions are appearing
SELECT
    COUNT(*) as hung_count,
    MAX(now() - xact_start) as max_duration
FROM pg_stat_activity
WHERE state != 'idle'
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
  AND application_name NOT LIKE 'google_cloudsql%';
```

**Expected**: `hung_count = 0` after cleanup

**If new hung transactions appear**: Investigate the source application and coordinate with the development team.

### Step 7: Review Datastream Logs

In GCP Console:
1. Navigate to **Datastream > [your stream name]**
2. Check **Logs** tab
3. Look for:
   - Latest fetched timestamp (should be advancing)
   - Error messages
   - Write throughput

**What to look for**:
- Timestamp should be advancing steadily (even if slowly)
- No error messages or warnings
- Consistent write patterns (not stuck)

### Step 8: Consider Resource Scaling (If Progress Is Too Slow)

**If catchup rate shows > 24 hours remaining**:

1. In GCP Console > Datastream > [your stream]
2. Check current vCPU allocation
3. Consider temporarily increasing:
   - vCPUs (e.g., from 2 to 4 or 4 to 8)
   - Max concurrent CDC tasks
   - Network bandwidth allocation

**Note**: Scaling changes may require brief stream pause/restart

---

## Success Criteria

✅ **Immediate (0-1 hour)**:
- All hung transactions terminated
- No new long-running transactions appearing
- Replication slot lag measurably decreasing

✅ **Short-term (4-8 hours)**:
- Lag reduced by at least 50%
- Steady catchup rate established
- Datastream logs show consistent progress

✅ **Resolution (24-72 hours)**:
- Lag < 1 GB (< 1 hour behind)
- Datastream processing current events
- No recurring transaction blocking issues

---

## Escalation Criteria

**Escalate to senior DBA/architect if**:
1. Lag continues to grow despite transaction cleanup
2. Cannot identify source of hung transactions
3. Catchup rate suggests > 1 week to resolve
4. Datastream errors appear in logs
5. Database performance degradation observed

**Escalate to business stakeholders if**:
1. Need to consider drop/recreate slot (requires full resync)
2. Catchup time exceeds acceptable data freshness SLA
3. Disk space exhaustion risk due to WAL accumulation

---

## Post-Incident Actions

### 1. Root Cause Analysis
- Identify which application/process created the hung transactions
- Review application code for missing commits or error handling
- Check for any recent deployments or configuration changes

### 2. Implement Preventive Measures

```sql
-- Set statement timeout for application users
ALTER ROLE [application_user] SET statement_timeout = '30min';

-- Set idle_in_transaction_session_timeout
ALTER DATABASE uat2820 SET idle_in_transaction_session_timeout = '10min';
```

### 3. Setup Monitoring Alerts

**Alert Rules to Create**:
- Replication slot lag > 10 GB (Warning)
- Replication slot lag > 50 GB (Critical)
- Transaction duration > 1 hour (Warning)
- Transaction duration > 4 hours (Critical)
- Datastream behind by > 6 hours (Warning)

### 4. Documentation
- Document which applications were causing hung transactions
- Update application deployment procedures to check for open transactions
- Add replication lag monitoring to operational runbooks

---

## Quick Reference Commands

```sql
-- Current lag
SELECT slot_name, pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS lag
FROM pg_replication_slots WHERE slot_name = 'sendung_slot_uat2820';

-- Hung transactions
SELECT pid, usename, now() - xact_start AS duration, LEFT(query, 80)
FROM pg_stat_activity
WHERE xact_start IS NOT NULL AND now() - xact_start > interval '1 hour'
AND application_name NOT LIKE 'google_cloudsql%';

-- Terminate (use with caution!)
SELECT pg_terminate_backend(<pid>);

-- WAL generation rate (current)
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS total_wal;
```

---

## Contact Information

**Incident Reporter**: Nikolay
**Date Reported**: 2026-01-30
**Severity**: High (data replication 7 days behind)
**Impact**: Downstream analytics/reporting out of date

---

## Notes Section

Use this section to track actions taken:

```
[2026-01-30 HH:MM] - Initial assessment completed
[2026-01-30 HH:MM] - Terminated PIDs: [list]
[2026-01-30 HH:MM] - Baseline lag: [value]
[2026-01-30 HH:MM] - [next action]
```
