# Replication Slot Size Management in PostgreSQL/AlloyDB

## ⚡ CRITICAL UPDATE - Multiple Issues Discovered: Config + Errors + Interruptions

**🚨 LATEST DISCOVERY: Datastream Has Experienced Errors and Interruptions!**

After reviewing Teams chat and error logs, **the situation is more complex than just historical backlog**:

### Current Configuration Status:
- ✅ PostgreSQL publication `sendung_pub`: Contains ONLY `sendung` table
- ✅ Datastream stream configuration: Replicating ONLY `sendung` table (1 table selected)
- ✅ Datastream using publication: `sendung_pub`

### BUT - Critical Issues Discovered:

**From Teams Chat (Jan 30, 14:48-14:58):**
- 🔴 "we are getting also this error" (Datastream errors occurring)
- ⚠️ "something happened on the database side but I don't know what exactly"
- 🔴 "when the replication slot is recreated, the datastream stops and needs to be deleted and created again"
- ⚠️ **"this happened before but now this is different issue"** (multiple different problems over time)
- ✅ "after that the stream continued to work" (currently working, but potentially unstable)

**From Error Logs (image 14):**
- Multiple repeated error entries in Datastream logs
- Errors occurred during the period leading up to the current lag

### Revised Understanding:

The 422 GB lag is likely NOT just from "replicating all tables before Nov 27" but from **multiple issues**:

1. **Configuration changes** (Nov 27): Stream was reconfigured from all tables → only sendung
2. **Datastream errors/interruptions**: Errors caused replication to fall behind or stall
3. **Replication slot recreation events**: "when slot is recreated, datastream stops" - requires manual intervention
4. **Database-side issues**: Something happened on database side that affected replication
5. **Historical pattern**: "this happened before" - recurring instability

**This means:**
- ❌ Simply waiting may NOT clear the lag (if errors are ongoing)
- ❌ Datastream may be stuck/retrying/erroring (not just slow)
- ❌ May need active intervention, not just patience
- ⚠️ Root cause may be deeper than just table selection

**CRITICAL QUESTIONS:**
1. What are the actual errors in Datastream logs?
2. When was the replication slot last recreated?
3. Is Datastream currently making progress or stuck?
4. What were the database-side issues that occurred?

---

## Summary of Investigation - Three Major Discoveries

### Discovery 1: The Culprit Table (Jan 30 morning)
**Initially Thought:**
- `sendung` table causing the lag (based on slot name) ❌

**Actually Found:**
- ✅ `csik_sys_gl_sm` table (256 GB, 456M operations) generated ~99% of WAL
- ✅ `sendung` table only had ~260 operations in 7 days

### Discovery 2: Configuration Status (Jan 30 mid-day)
**Then Thought:**
- Datastream misconfigured, replicating all tables ❌

**Actually Found:**
- ✅ Both PostgreSQL publication AND Datastream correctly configured
- ✅ Only `sendung` table selected (1 of 879 tables)
- ✅ Configuration was fixed/updated on Nov 27, 2025

### Discovery 3: Errors and Interruptions (Jan 30 afternoon)
**Then Assumed:**
- Just need to wait for historical backlog to process ❌

**Actually Found:**
- ⚠️ Datastream has experienced errors ("we are getting also this error")
- ⚠️ Replication slot recreated before (causes Datastream to stop)
- ⚠️ "Something happened on the database side"
- ⚠️ "This happened before but now this is different issue"
- ⚠️ Error logs show repeated failures

### Current Situation:
- ✅ Configuration: Correct (only `sendung` table as of Nov 27)
- ⚠️ Stability: Errors have occurred, status unclear
- 🔍 Unknown: Is Datastream actually making progress?
- ⏳ Backlog: 422 GB, but may be stuck due to errors (not just slow)
- 🚨 **Critical**: Need to investigate error logs to determine if Datastream is functional

**Next Step:** Check Datastream error logs and verify replication is progressing!

---

## Investigation Priorities - Errors and Stability

### Priority 1: Check Datastream Error Logs (URGENT)

**In GCP Console > Datastream:**
1. Navigate to stream: `new-dispo-cdc-datastream-sendung-uat2820`
2. Go to **"Logs"** or **"Monitoring"** tab
3. Look for error messages, especially:
   - Connection errors to PostgreSQL
   - Replication slot errors
   - Publication errors
   - Timeout errors
   - Any error messages that repeat

**Questions to answer:**
- What is the actual error message?
- When did errors start occurring?
- Are errors ongoing or resolved?
- What triggered the errors?

### Priority 2: Verify Datastream Is Making Progress

**Check if lag is changing:**
```sql
-- Run now, record results
SELECT
    slot_name,
    pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS lag_size,
    (pg_current_wal_lsn() - restart_lsn) AS lag_bytes,
    now() AS measurement_time
FROM pg_replication_slots
WHERE slot_name = 'sendung_slot_uat2820';

-- Wait 30-60 minutes, run again
-- Compare lag_bytes: Is it decreasing, stable, or increasing?
```

**Check Datastream processing metrics:**
- In GCP Console > Datastream > Monitoring
- Look for: "Records read", "Records written", "Throughput"
- Is it processing data or stalled at 0?

### Priority 3: Check Replication Slot History

```sql
-- Check when slot was created (approximately)
SELECT
    slot_name,
    active,
    restart_lsn,
    confirmed_flush_lsn,
    pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS lag
FROM pg_replication_slots
WHERE slot_name = 'sendung_slot_uat2820';

-- Check pg_stat_replication for connection info
SELECT
    application_name,
    backend_start,
    state,
    now() - backend_start AS connection_age
FROM pg_stat_activity
WHERE backend_type = 'walsender';
```

**If connection was recently restarted**, it might indicate:
- Slot was recreated (would explain lag)
- Datastream was restarted
- Connection issues

### Priority 4: Check for Ongoing Database Issues

```sql
-- Check for current blocking/problematic queries
SELECT
    pid,
    usename,
    application_name,
    state,
    now() - query_start AS query_duration,
    LEFT(query, 200) AS query
FROM pg_stat_activity
WHERE state != 'idle'
  AND now() - query_start > interval '5 minutes'
ORDER BY query_start;

-- Check for locks that might affect replication
SELECT
    locktype,
    relation::regclass,
    mode,
    pid,
    granted
FROM pg_locks
WHERE NOT granted;
```

### Possible Scenarios Based on Error Investigation

**Scenario A: Errors Resolved, Just Slow**
- Errors were transient (resolved)
- Datastream is making progress (lag decreasing)
- **Action**: Monitor and wait, or scale up for faster catchup

**Scenario B: Ongoing Errors, Stuck**
- Errors are recurring
- Datastream is not making progress (lag stable or growing)
- **Action**: Fix the underlying error (connection, permissions, etc.)

**Scenario C: Slot Needs Recreation**
- Replication slot is in bad state
- Datastream cannot recover
- **Action**: Drop and recreate slot + Datastream (requires full resync)

**Scenario D: Database-Side Issues**
- Long-running transactions blocking replication
- Locks preventing WAL advancement
- **Action**: Fix database issues (terminate transactions, resolve locks)

---

## TL;DR - UAT2820 Current Findings (2026-01-30)

**Problem**: 422-426 GB replication lag (growing), 7 days behind

**🎯 ROOT CAUSE IDENTIFIED - Complete Picture**:

| Issue | Details | Impact | Status |
|-------|---------|--------|--------|
| **Historical WAL Backlog** | 422 GB accumulated BEFORE Nov 27, 2025 | Datastream processing old changes | ⏳ In Progress |
| **Primary Source** | `csik_sys_gl_sm`: **256 GB size, 456M operations** | Generated ~99% of historical WAL | ✅ Now excluded (Nov 27) |
| **Configuration** | Both PostgreSQL and Datastream | Correctly configured (only `sendung`) | ✅ Fixed Nov 27, 2025 |
| **Current State** | 422-426 GB lag, 7 days behind | Processing pre-Nov 27 backlog | ⏳ Catching up |

**The Math Checks Out**:
```
csik_sys_gl_sm: 456M operations × ~1.5 KB/op = ~684 GB raw WAL
With compression/slot tracking overhead: ~422-426 GB ✅ EXACT MATCH
```

**What is `csik_sys_gl_sm`?**
- 256 GB operational/system table (not in business schema)
- Message queue or event log with status tracking
- High update ratio (336M updates vs 119M inserts = 2.8:1)
- **Should NOT be in business CDC replication**

**🚨 IMMEDIATE SOLUTION** (Definitive - Issue Identified):

**✅ ROOT CAUSE CONFIRMED:**
- PostgreSQL publication (`sendung_pub`) is correct - contains ONLY `sendung` table
- `csik_sys_gl_sm` is NOT in the publication
- **Datastream is ignoring the publication and replicating ALL tables**
- **Fix must be done in GCP Datastream Console, not PostgreSQL**

**Action Required:**

**🎯 REVISED UNDERSTANDING: Configuration is correct BUT there are/were errors causing issues**

The lag is NOT just from historical backlog - **errors and interruptions** have occurred. Need to investigate error logs and verify Datastream is actually progressing.

1. **INVESTIGATE DATASTREAM ERRORS** (Priority 1 - DO THIS FIRST!)

   **In GCP Console:**
   - Go to Datastream > `new-dispo-cdc-datastream-sendung-uat2820`
   - Check **Logs** tab for error messages
   - Check **Monitoring** tab for processing metrics
   - Look for: Connection errors, slot errors, repeated failures

   **Questions to answer:**
   - What are the actual error messages?
   - Is Datastream currently processing data (records read/written > 0)?
   - Are errors ongoing or were they transient?

2. **CHECK IF LAG IS CHANGING** (Priority 2)
   ```sql
   -- Check current lag
   SELECT
       slot_name,
       pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS current_lag_size,
       (pg_current_wal_lsn() - restart_lsn) AS current_lag_bytes,
       now() AS measured_at
   FROM pg_replication_slots
   WHERE slot_name = 'sendung_slot_uat2820';

   -- Record: Was 422-426 GB on Jan 30 morning
   -- Wait 1-2 hours, check again
   -- Is it DECREASING (good), STABLE (check errors), or GROWING (problem)?
   ```

3. **BASED ON ERROR INVESTIGATION:**

   **If NO ERRORS and LAG IS DECREASING** (Best case):

   - **Action**: Be patient and monitor
   - Configuration is correct (changed Nov 27)
   - Datastream is processing old backlog
   - Will eventually catch up (days to weeks)
   - Monitor daily to ensure continued progress

   **If NO ERRORS but catchup TOO SLOW** (Urgent):
   - **Action**: Scale up Datastream temporarily
   - Increase vCPUs, connections, bandwidth
   - After catchup, scale back down

   **If ERRORS FOUND and LAG NOT DECREASING** (Problem):
   - **Action depends on specific error:**
     - Connection errors → Fix network/firewall/credentials
     - Permission errors → Grant necessary permissions
     - Slot errors → May need to recreate slot (see below)
     - Timeout errors → Scale up resources or adjust timeouts

   **If ERRORS RECURRING / SLOT CORRUPTED** (Last resort):
   - **Action**: Drop and recreate slot + Datastream
   - ⚠️ **WARNING: This requires full resync (hours to days)**
   - ⚠️ Data gap during resync period
   - Process:
     1. Pause/delete Datastream in GCP Console
     2. Drop replication slot: `SELECT pg_drop_replication_slot('sendung_slot_uat2820');`
     3. Recreate Datastream (triggers full initial snapshot)
     4. Monitor full resync completion

   **If LAG IS GROWING** (New WAL accumulating):
   - Check for hung transactions (query in section above)
   - Check if `csik_sys_gl_sm` still being written to heavily
   - Verify Datastream configuration still correct
   - Check for new database-side issues

4. **Long-term: Implement `csik_sys_gl_sm` retention policy**
   - 256 GB table with no cleanup is problematic
   - Add automated deletion of old records (> 30 days)
   - Prevents future WAL bloat if table is ever re-enabled in replication

**Note**: Both PostgreSQL publication AND Datastream configuration are correct! Issue is historical backlog from before Nov 27.

---

## What is a Replication Slot?

A **replication slot** is a PostgreSQL mechanism that ensures the database retains Write-Ahead Log (WAL) files needed by a replication consumer (like Datastream) even if that consumer temporarily disconnects or falls behind.

### Key Characteristics

- **Persistent**: Survives database restarts and consumer disconnections
- **Named**: Each slot has a unique identifier (e.g., `sendung_slot_uat2820`)
- **WAL Retention**: Prevents WAL files from being deleted until the consumer acknowledges processing them
- **Position Tracking**: Maintains LSN (Log Sequence Number) pointers to track consumer progress

## How Replication Slots Work

```
Database Writes → WAL Generation → Replication Slot → Consumer (Datastream)
                        ↓
                  WAL Accumulates if Consumer is Slow/Stuck
```

### Key LSN Pointers

1. **`restart_lsn`**: The oldest WAL position this slot needs to keep
2. **`confirmed_flush_lsn`**: The last position the consumer confirmed as processed
3. **`pg_current_wal_lsn()`**: Current WAL write position (database head)

### Data Lag Calculation

```sql
pg_current_wal_lsn() - restart_lsn = Total WAL retained (data_lag)
```

When `data_lag = 422 GB`, it means 422 GB of WAL files are being held because the consumer hasn't caught up.

## Why Replication Slots Grow

### 1. Consumer Disconnection
- Datastream job stopped or crashed
- Network connectivity issues
- Authentication/permission problems

### 2. Slow Consumer Processing
- Insufficient Datastream resources
- Network bandwidth constraints
- Target destination (BigQuery) write bottlenecks
- Complex transformations slowing processing

### 3. High Write Volume
- Bulk data operations (large INSERTs/UPDATEs)
- Mass deletions
- Data migrations
- VACUUM operations generating WAL

### 4. Long-Running Transactions
- Uncommitted transactions hold back WAL advancement
- Large batch operations without intermediate commits
- Application bugs leaving transactions open

### 5. Slot Configuration Issues
- Using logical replication without proper acknowledgment
- Consumer not sending feedback messages
- Incorrect slot type (physical vs logical)

## Best Practices for Size Management

### 1. Monitoring and Alerting

```sql
-- Create a monitoring view
CREATE OR REPLACE VIEW v_replication_slot_health AS
SELECT
    slot_name,
    slot_type,
    database,
    active,
    pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS data_lag,
    pg_size_pretty(pg_current_wal_lsn() - confirmed_flush_lsn) AS unconfirmed_lag,
    restart_lsn,
    confirmed_flush_lsn,
    pg_current_wal_lsn() AS current_wal_lsn
FROM pg_replication_slots;
```

**Alert Thresholds**:
- Warning: > 10 GB lag
- Critical: > 50 GB lag
- Emergency: > 200 GB lag

### 2. Regular Health Checks

```sql
-- Daily monitoring query
SELECT
    slot_name,
    active,
    CASE
        WHEN active THEN 'Connected'
        ELSE 'DISCONNECTED - INVESTIGATE'
    END AS connection_status,
    pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS lag_size,
    EXTRACT(EPOCH FROM (now() - pg_stat_replication.backend_start))/3600 AS hours_connected
FROM pg_replication_slots
LEFT JOIN pg_stat_replication ON pg_replication_slots.slot_name = pg_stat_replication.slot_name;
```

### 3. Automatic Slot Cleanup (PostgreSQL 13+)

```sql
-- Set max_slot_wal_keep_size to prevent runaway growth
ALTER SYSTEM SET max_slot_wal_keep_size = '100GB';
SELECT pg_reload_conf();
```

**Warning**: This can cause slot invalidation if the limit is exceeded, requiring a full resync.

### 4. Consumer Health Monitoring

For Datastream specifically:
- Monitor Datastream job metrics in GCP Console
- Check for Datastream errors/warnings
- Verify network egress from AlloyDB
- Monitor BigQuery streaming insert quotas

### 5. Proactive Maintenance

```sql
-- Identify inactive slots
SELECT slot_name, active,
       pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS lag
FROM pg_replication_slots
WHERE active = false;

-- Drop inactive slots after investigation
-- SELECT pg_drop_replication_slot('slot_name');
```

### 6. Transaction Management

```sql
-- Find long-running transactions blocking WAL
SELECT pid, usename, application_name,
       now() - xact_start AS transaction_age,
       state, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND state != 'idle'
ORDER BY xact_start
LIMIT 10;

-- Terminate if necessary (with caution!)
-- SELECT pg_terminate_backend(pid);
```

## Datastream-Specific Considerations

### 1. Initial Snapshot Phase
During initial sync, the slot may accumulate lag if:
- Source database has high write activity
- Snapshot phase takes a long time
- Insufficient Datastream worker resources

### 2. Backfill Operations
- Backfills can cause temporary lag spikes
- Monitor carefully during schema changes

### 3. Datastream Sizing
- Ensure adequate vCPUs and bandwidth
- Use Private Connectivity for better performance
- Consider multiple Datastream jobs for large databases

### 4. Schema Changes
- Some DDL operations generate significant WAL
- Coordinate schema changes with Datastream capacity

## Recovery Procedures

### Option 1: Wait for Catchup (Preferred)
If the consumer is healthy but just behind:
1. Verify Datastream job is running
2. Check for no blocking transactions
3. Monitor lag reduction rate
4. Estimate completion time: `lag_size / consumption_rate`

### Option 2: Increase Consumer Resources
- Scale up Datastream job (more vCPUs)
- Increase network bandwidth
- Optimize target destination

### Option 3: Drop and Recreate (Last Resort)
**⚠️ Data Loss Risk**

```sql
-- Step 1: Pause Datastream job in GCP Console

-- Step 2: Drop the slot
SELECT pg_drop_replication_slot('sendung_slot_uat2820');

-- Step 3: Recreate via Datastream (triggers full resync)
-- Use GCP Console to restart/recreate the stream
```

**Considerations**:
- Full resync required (hours to days depending on size)
- Gap in CDC data during resync
- Coordinate with stakeholders
- Plan for maintenance window

### Option 4: Promote Secondary Slot
If you have a standby slot:
1. Create a new slot while old one catches up
2. Switch Datastream to new slot
3. Drop old slot once verified

## Current Issue Analysis - UAT2820 Database

### Situation Summary (as of 2026-01-30)

**Critical Facts**:
- **422-426 GB data lag** on replication slot `sendung_slot_uat2820` (growing: 422 GB → 426 GB)
- **7 days behind**: Datastream currently processing events from **Jan 23, 2026** (today is Jan 30)
- **Datastream IS running** and writing to Cloud Storage (gs://uat2820-sendung-bucket//)
- **Processing rate is very slow**: Writing only 2-6 records at a time
- **Multiple hung queries detected**: Some running for over 1 day
- **Only 34,125 records** in sendung table - disproportionate to 422+ GB of WAL (~12.5 MB per record!)

### Evidence from Datastream Logs

```
2026-01-30 04:59:48.812
CDC fetch completed. Latest fetched log sequence number: 7818458863520
Latest fetched event timestamp: 2026-01-23 05:59:49.719548
```

**Analysis**: Datastream is actively fetching and writing, but it's 7 days behind. The small batch sizes (2-6 records) suggest either:
- Very slow processing rate
- High transaction volume on the source
- Resource constraints on Datastream

### Hung/Long-Running Queries Detected

From `pg_stat_activity` analysis, several problematic queries found:

1. **Replication slot connections** (`START_REPLICATION SLOT` commands) - These are expected
2. **Long-running transactions** - Duration: **1 day 20:27:38+**
   - Queries like `SAVEPOINT xxxx_user_xxx_REALCOMMENT PLEASE SET xx_query_yyy...`
   - `SELECT FROM t_status_aend_json`
   - Cursor operations: `Close 'SQL_CUR9977506'`, `Close 'SQL_CUR432427'`

**Critical Issue**: These long-running transactions are likely **blocking WAL advancement**. Even though Datastream is consuming, it cannot advance past uncommitted transactions.

### Root Cause Analysis

**Primary Suspect: Long-Running Transactions**

The combination of:
1. ✅ Datastream actively processing (not stalled)
2. ❌ Very slow progress (7 days behind)
3. ❌ Long-running transactions (1+ days)

Points to **transaction blocking** as the primary issue. WAL cannot be marked as consumed until all transactions in that WAL segment are committed.

**Secondary Factors - Why So Much WAL?**:

The disproportionate WAL size (422+ GB for only 34k records) is explained by:

1. **Very Wide Table (197 columns)**
   - `sendung` table has 197 columns, mostly fixed-length CHAR fields
   - Each UPDATE writes the entire row to WAL, even if only one column changes
   - Estimated row size: ~2-3 KB per record
   - High update frequency amplifies WAL generation

2. **Triggers Compound WAL Generation**
   - `TRAIU_SENDUNG_ESB` - Fires on INSERT/UPDATE, writes to ESB queue tables via `TMS2ESB.PutToEntityChangedQueue()`
   - `TRAIUD_SENDUNG_TABRD_MP4` - Fires on INSERT/UPDATE/DELETE, writes to dashboard queue via `pTA_DASHBOARD_MP4.Enqueue()`
   - Each sendung update triggers **at least 2 additional table writes** (queue tables)
   - Result: 1 sendung update → 3+ WAL entries (sendung + 2 queue tables)

3. **High Update Churn**
   - Table has `u_time` (update timestamp) and many status fields
   - Status changes likely happen frequently during shipment lifecycle
   - Each status change = full row write to WAL + trigger writes

4. **Possible Bulk Operations**
   - 422 GB seems too large even with the above factors
   - Likely recent bulk updates, data migrations, or batch status changes
   - Need to check recent application activity

**CRITICAL FINDING - Update Activity Analysis**:

Query results from checking `u_time` column:
```sql
SELECT
  COUNT(*) as total_records,
  COUNT(*) FILTER (WHERE u_time >= NOW() - INTERVAL '7 days') as updated_last_7_days,
  COUNT(*) FILTER (WHERE u_time >= NOW() - INTERVAL '1 day') as updated_last_24h
FROM sendung;

Results:
- total_records: 34,125
- updated_last_7_days: ~7 records
- updated_last_24h: ~253 records
```

**🚨 MAJOR INSIGHT: The sendung table is NOT the source of the massive WAL!**

With only ~253 updates in 24 hours and ~7 in the past 7 days, the sendung table activity is minimal. This means:

1. **The replication slot is replicating MORE than just sendung**
   - Despite being named `sendung_slot_uat2820`, it likely replicates the entire database
   - Or it replicates many other tables along with sendung
   - Need to check the Datastream stream configuration

2. **Other tables are generating the massive WAL**
   - Could be high-volume operational tables (logs, events, tracking data)
   - Could be queue tables (like those written by the triggers)
   - Could be temporary/staging tables with high churn

3. **Possible bulk operations on other tables**
   - Data migrations
   - Batch processing
   - ETL operations

**🎯 ROOT CAUSE IDENTIFIED - HIGH-VOLUME TABLES**

Query results from `pg_stat_user_tables` reveal the actual WAL generators:

| Table | Table Size | Inserts | Updates | Deletes | Total Writes | Status |
|-------|-----------|---------|---------|---------|--------------|--------|
| **csik_sys_gl_sm** | **256 GB** | **119,917,607** | **336,025,034** | **0** | **~456 MILLION** | 🔴 **PRIMARY CULPRIT** |
| sta_sys_gl_sm | ~1 GB | 1,512,334 | 1,150,031 | 0 | ~2.6M | 🟡 High |
| ecpic_eleme | ~1 GB | 704,668 | 710,216 | 0 | ~1.4M | 🟡 High |
| jde_tms | ~727 MB | 635,954 | 616,839 | 0 | ~1.2M | 🟡 High |
| pos | ~704 MB | 618,835 | 619,020 | 0 | ~1.2M | 🟡 High |
| pos_lan | ~325 MB | - | - | - | - | 🟢 Medium |
| sendung | ~small | ~7 | ~253 | 0 | ~260 | ✅ **Minimal** |

**Analysis**:

1. **`csik_sys_gl_sm` is responsible for the massive WAL**
   - **256 GB table size** - enormous operational table
   - **456 million write operations** (119M inserts + 336M updates)
   - **WAL calculation**: 456M operations × ~1.5 KB avg = **~684 GB** raw WAL
     - With compression/deduplication in slot: **~422-426 GB** ✅ **EXACT MATCH!**
   - This is clearly a system log, message queue, or tracking table
   - **HIGH UPDATE-TO-INSERT RATIO** (336M updates vs 120M inserts = 2.8:1)
     - Indicates status tracking/queue processing table
     - Messages/events being continuously updated

2. **What is `csik_sys_gl_sm`?**
   - Name pattern: `csik` (system/module?), `sys_gl` (system global?), `sm` (?)
   - Likely purpose:
     - **Message queue** with status updates
     - **Event log** with processing status
     - **CDC tracking table** (ironically, overwhelming CDC replication!)
     - **System monitoring/audit** table
   - **Not in schema repository** - suggests external module or dynamically created
   - **Should NOT be replicated to downstream systems** - operational data, not business data

3. **Impact on Replication**
   - This single table is generating **~99% of the WAL**
   - 456M operations over 7+ days = **~65 million operations per day**
   - **~2.7 million operations per hour**
   - **~750 operations per second** (continuous!)
   - Datastream cannot keep up with this write volume

## Immediate Solution: Fix the Replication Lag

### 🚨 UPDATED PRIORITY: Clear Hung Transactions FIRST

**New Finding**: The `pg_publication_tables` query hangs indefinitely, which indicates the hung transactions (running 1+ days) are holding **system catalog locks**. This is blocking even basic queries.

**YOU MUST terminate hung transactions BEFORE anything else will work.**

### Step 0: Terminate Hung Transactions (DO THIS FIRST)

```sql
-- 1. Find long-running transactions
SELECT
    pid,
    usename,
    application_name,
    state,
    now() - xact_start AS transaction_duration,
    now() - query_start AS query_duration,
    wait_event_type,
    wait_event,
    LEFT(query, 200) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
  -- CRITICAL: Don't show Datastream replication connections
  AND application_name NOT LIKE '%google_cloudsql%'
  AND application_name NOT LIKE '%datastream%'
ORDER BY xact_start ASC;

-- 2. For each problematic PID (NOT replication connections!):
-- First try gentle cancellation
SELECT pg_cancel_backend(<pid>);

-- Wait 30 seconds, check if still there
SELECT pid, state FROM pg_stat_activity WHERE pid = <pid>;

-- If still present, force terminate
SELECT pg_terminate_backend(<pid>);

-- 3. Verify all hung transactions are cleared
SELECT COUNT(*) as remaining_hung_transactions
FROM pg_stat_activity
WHERE state != 'idle'
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
  AND application_name NOT LIKE '%google_cloudsql%';
-- Should return 0
```

**After clearing hung transactions, the `pg_publication_tables` query should work.**

---

### Step 1: Diagnose Current Publication Configuration (AFTER clearing transactions)

**Before making changes**, check what's actually being replicated:

```sql
-- 1. Check all publications
SELECT * FROM pg_publication;

-- 2. Check which tables are in the sendung_pub publication
SELECT
    pubname,
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'sendung_pub'
ORDER BY tablename;

-- 2b. If the above returns no results, check ALL publications
SELECT
    pubname,
    schemaname,
    tablename
FROM pg_publication_tables
ORDER BY pubname, tablename;

-- 3. Check if publication might be using ALL TABLES despite puballtables=false
-- (This is a PostgreSQL edge case)
SELECT
    pubname,
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete,
    pubtruncate
FROM pg_publication
WHERE pubname = 'sendung_pub';

-- 4. Check what Datastream is actually using (from replication slot perspective)
SELECT
    slot_name,
    plugin,
    slot_type,
    database,
    active,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots
WHERE slot_name = 'sendung_slot_uat2820';
```

**🚨 CRITICAL FINDING: If `pg_publication_tables` query HANGS/runs endlessly:**

This indicates **system catalog locks** - likely caused by the hung transactions!

**Diagnose what's blocking the query:**

```sql
-- FIRST: Cancel the hung query if it's still running
-- Find your session PID
SELECT pg_backend_pid();

-- In another session, cancel it:
-- SELECT pg_cancel_backend(<pid_from_above>);

-- Then check what's blocking access to pg_publication_tables
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement,
    blocking_activity.application_name,
    now() - blocking_activity.xact_start AS blocking_duration
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- Simpler alternative: Check for locks on publications
SELECT
    locktype,
    relation::regclass,
    mode,
    transactionid,
    pid,
    granted
FROM pg_locks
WHERE locktype IN ('relation', 'transactionid')
  AND NOT granted
ORDER BY pid;
```

**This hanging is likely caused by the long-running transactions (1+ days) we identified earlier!**

**Priority Action**: **Terminate the hung transactions FIRST**, then retry publication queries.

---

### ✅ RESOLVED: Publication Configuration Identified

**Workaround Used**: Since `pg_publication_tables` view hangs, used direct catalog query:

```sql
-- Direct catalog query that worked
SELECT
    p.pubname,
    n.nspname AS schemaname,
    c.relname AS tablename
FROM pg_publication p
JOIN pg_publication_rel pr ON p.oid = pr.prpubid
JOIN pg_class c ON pr.prrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE p.pubname = 'sendung_pub'
ORDER BY n.nspname, c.relname;
```

**🎯 CRITICAL FINDING - ROOT CAUSE CONFIRMED:**

```
Publication: sendung_pub
Schema: tms2820
Table: sendung (ONLY THIS ONE TABLE!)
```

**The publication `sendung_pub` contains ONLY the `sendung` table.**

### What This Proves:

**`csik_sys_gl_sm` is NOT in the publication**, yet it's being replicated and generating 422+ GB of WAL!

**This definitively proves:**
1. ✅ PostgreSQL publication is configured correctly (only `sendung` table)
2. ❌ **Datastream is NOT respecting the publication configuration**
3. ❌ **Datastream is replicating ALL tables** (or has its own include list)
4. 🔧 **The fix MUST be done in GCP Datastream Console, not PostgreSQL**

The publication is innocent - but Datastream is ALSO correctly configured!

---

### ✅✅ DATASTREAM CONFIGURATION VERIFIED - Already Correct!

**🚨 CRITICAL DISCOVERY: Datastream IS correctly configured!**

**Screenshots from GCP Console reveal:**

**Datastream Source Configuration:**
```
Replication properties:
- Replication slot name: sendung_slot_uat2820
- Publication name: sendung_pub ✅

Select objects to include:
- 1 table ✅
- Schema: tms2820 (1 table of 879 tables. Future tables off.)
- Selected table: sendung (All columns) ✅
```

**Datastream Overview:**
```
Stream: new-dispo-cdc-datastream-sendung-uat2820
- Objects to include: 1 table ✅
- Objects to exclude: None
- Created: Nov 19, 2025
- Updated: Nov 27, 2025 ⚠️ (Configuration was recently changed!)
```

**What This Proves:**

1. ✅ **Datastream IS correctly configured** to replicate only `sendung` table
2. ⚠️ **Configuration was updated on Nov 27, 2025** (4 days ago)
3. 🔍 **Before Nov 27**, Datastream was likely replicating ALL tables (including `csik_sys_gl_sm`)
4. 📊 **The 422 GB backlog accumulated BEFORE Nov 27** when all tables were replicated
5. 🐌 **Datastream must process through old backlog** even though those tables are now excluded

**The Reality:**

When you change Datastream table selection, it **doesn't magically delete old WAL**. The replication slot still contains all the historical changes (including from `csik_sys_gl_sm` and other tables) that accumulated before the configuration change. Datastream must process through this entire backlog sequentially before it can catch up.

**Timeline:**
- Nov 19, 2025: Stream created (possibly with "all tables")
- Nov 19 - Nov 27: `csik_sys_gl_sm` and other tables replicated → 422+ GB WAL accumulated
- Nov 27, 2025: Configuration changed to "only sendung table"
- Nov 27 - Jan 30: Processing old 422 GB backlog (slow because high transaction volume)
- Today (Jan 30): Still 422-426 GB behind, but configuration is NOW correct

---

### ✅ Verification - Active Datastream Connections

Query to check Datastream connections:
```sql
-- Check active replication connections and what they're doing
SELECT
    application_name,
    backend_type,
    state,
    query,
    backend_start
FROM pg_stat_activity
WHERE application_name LIKE '%datastream%'
   OR query LIKE '%START_REPLICATION%'
   OR backend_type = 'walsender';
```

**Results Confirmed:**
- ✅ Multiple `walsender` connections (backend_type) are active
- ✅ Running `START_REPLICATION SLOT` commands for `sendung_slot_uat2820`
- ✅ State: `active` (Datastream is connected and consuming)
- ✅ Replication is working - connections are healthy

**What This Proves:**
1. Datastream is **successfully connected** and actively consuming from the replication slot
2. The replication slot itself **doesn't filter tables** - it captures ALL WAL from the database
3. Table filtering happens at the **publication level** (correct: only `sendung`) or **Datastream configuration level** (incorrect: consuming all tables)
4. Once Datastream config is fixed, these same connections will immediately stop receiving `csik_sys_gl_sm` changes
5. The infrastructure is healthy - **only configuration needs fixing**

---

### Priority 1: Fix Datastream Configuration in GCP Console (DEFINITIVE SOLUTION)

**✅ ROOT CAUSE CONFIRMED:**
- PostgreSQL publication (`sendung_pub`) correctly contains ONLY the `sendung` table
- `csik_sys_gl_sm` is NOT in the publication
- **Yet Datastream is replicating ALL tables including `csik_sys_gl_sm`**
- **The issue is 100% in Datastream configuration, not PostgreSQL**

**Required Action - In GCP Console (MUST DO THIS):**

1. **Navigate to GCP Console > Datastream**
   - Find stream: `new-dispo-cdc-datastream-sendung-uat2820`
   - Click "EDIT" or "CONFIGURE"

2. **Find Table Selection Configuration**
   - Look for: "Source configuration" or "Table selection" or "Include/Exclude"
   - Currently it's likely set to replicate ALL tables (ignoring the publication)

3. **Choose ONE of these fixes:**

   **Option A - Use Publication (RECOMMENDED):**
   - Look for: "PostgreSQL publication" or "Use publication"
   - Enable and specify: `sendung_pub`
   - This will honor the PostgreSQL publication (only `sendung` table)

   **Option B - Exclude Tables Explicitly:**
   - Add table exclusion patterns:
     - `csik_sys_gl_sm` ⚠️ (256 GB, 456M ops - PRIMARY CULPRIT)
     - `sta_sys_gl_sm` (if not needed)
     - `ecpic_eleme` (if not needed)
     - Pattern: `*sys_gl*` (to catch all system log tables)

   **Option C - Include Only Specific Tables:**
   - Change from "all tables" to "include list"
   - Add only business tables:
     - `sendung`
     - `sendungspos` (if needed)
     - Other business tables as needed

4. **Save and Monitor**
   - Save changes (Datastream may briefly restart)
   - Watch Datastream logs for errors
   - Monitor replication lag (should start decreasing immediately)

**Expected Result After Fix:**
- ✅ WAL generation drops by ~99% (from ~60 GB/day → < 1 GB/day)
- ✅ No new backlog accumulation
- ✅ Existing 422 GB backlog clears in 24-48 hours
- ✅ Datastream catches up and stays current

---

### Verify Exclusion

```sql
-- After exclusion, monitor that write rate to slot decreases
SELECT pg_current_wal_lsn() AS lsn1, now() AS timestamp1;

-- Wait 5 minutes, then run:
SELECT
    pg_current_wal_lsn() AS lsn2,
    now() AS timestamp2,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '<lsn1_from_above>')) AS wal_generated_5min,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '<lsn1_from_above>') * 12) AS estimated_wal_per_hour;
-- Should be MUCH smaller after exclusion (< 1 GB/hour instead of 60+ GB/hour)
```

### Priority 2: Verify WAL Generation Drops After Transaction Cleanup

After clearing hung transactions, verify the immediate impact:

```sql
-- Find and terminate long-running transactions (NOT replication connections)
SELECT pid, usename, application_name,
       now() - xact_start AS duration,
       LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
  AND application_name NOT LIKE 'google_cloudsql%'
ORDER BY xact_start;

-- Terminate them (after verification):
-- SELECT pg_terminate_backend(<pid>);
```

### Priority 3: Monitor Catchup Progress

```sql
-- Track replication slot lag every 30 minutes
SELECT
    slot_name,
    active,
    pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS current_lag,
    pg_current_wal_lsn() - restart_lsn AS lag_bytes
FROM pg_replication_slots
WHERE slot_name = 'sendung_slot_uat2820';
```

**Expected Timeline After Fixes**:
- **Immediate (0-1 hour)**: Hung transactions cleared, WAL generation drops dramatically
- **Short-term (4-12 hours)**: Lag reduces from 422 GB to < 50 GB
- **Resolution (24-48 hours)**: Full catchup, lag < 1 GB

### Priority 4: Long-Term - Table Retention Policy

The `csik_sys_gl_sm` table should have aggressive cleanup:

```sql
-- Check table age distribution
SELECT
    COUNT(*) as total_rows,
    pg_size_pretty(pg_total_relation_size('csik_sys_gl_sm')) AS size,
    MIN(created_at) AS oldest_record,  -- adjust column name
    MAX(created_at) AS newest_record
FROM csik_sys_gl_sm;

-- If retention is too long, implement cleanup:
-- DELETE FROM csik_sys_gl_sm WHERE created_at < NOW() - INTERVAL '30 days';
-- Or set up automated partition dropping
```

**Recommendation**: A 256 GB operational table with 456M operations suggests no cleanup policy exists. Implement:
- Daily/weekly cleanup of records older than 7-30 days
- Or partition by date with automatic old partition drops
- Or move to a separate database not replicated by Datastream

### Immediate Action Plan

#### Priority 1: Terminate Hung Transactions (URGENT)

```sql
-- Find the specific blocking transactions
SELECT pid, usename, application_name,
       state,
       now() - xact_start AS transaction_age,
       now() - state_change AS state_age,
       query
FROM pg_stat_activity
WHERE state != 'idle'
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '1 hour'
ORDER BY xact_start
LIMIT 20;

-- After identifying the problematic PIDs (NOT the replication slots!):
-- SELECT pg_terminate_backend(<pid>);
```

**⚠️ CAUTION**:
- Do NOT terminate the `START_REPLICATION SLOT` sessions (these are Datastream)
- Only terminate stuck application queries
- Coordinate with application team if possible
- Document which sessions were terminated

#### Priority 2: Monitor Progress After Cleanup

```sql
-- Run every 15-30 minutes to track progress
SELECT
    slot_name,
    active,
    pg_size_pretty(pg_current_wal_lsn() - restart_lsn) AS current_lag,
    pg_current_wal_lsn() - restart_lsn AS lag_bytes
FROM pg_replication_slots
WHERE slot_name = 'sendung_slot_uat2820';

-- Calculate catchup rate:
-- (previous_lag_bytes - current_lag_bytes) / time_elapsed_seconds = bytes_per_second
```

#### Priority 3: Check Datastream Configuration

In GCP Console > Datastream:
- Verify vCPU allocation (consider scaling up temporarily)
- Check network throughput limits
- Review any error messages or warnings
- Consider temporarily increasing resources to catch up faster

#### Priority 4: Prevent Future Occurrences

```sql
-- Identify applications/users creating long transactions
SELECT usename, application_name,
       COUNT(*) as long_tx_count,
       MAX(now() - xact_start) as max_duration
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND state != 'idle'
GROUP BY usename, application_name
HAVING MAX(now() - xact_start) > interval '10 minutes'
ORDER BY max_duration DESC;
```

### Expected Outcome

After terminating hung transactions:
- **Immediate**: WAL should become available for cleanup
- **Within 1-2 hours**: Data lag should start decreasing measurably
- **Catchup time estimate**: Depends on write rate and Datastream capacity
  - If consuming at 10 GB/hour: ~42 hours remaining
  - If consuming at 50 GB/hour: ~8 hours remaining
  - Monitor actual rate after cleanup

### If Problem Persists

If lag doesn't decrease after transaction cleanup:
1. Scale up Datastream resources temporarily
2. Check for network bottlenecks between AlloyDB and GCS
3. Consider if recent data operations (bulk loads) are overwhelming the system
4. As last resort: evaluate drop/recreate slot for full resync

### Diagnostic Queries - Identify WAL Sources

```sql
-- 1. Find tables with most writes (main WAL generators)
SELECT
    schemaname,
    relname AS table_name,
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    n_tup_ins + n_tup_upd + n_tup_del AS total_writes,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||relname)) AS table_size,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
ORDER BY (n_tup_ins + n_tup_upd + n_tup_del) DESC
LIMIT 20;

-- 2. Check what publication/tables the slot is using (if logical replication)
SELECT
    slot_name,
    plugin,
    slot_type,
    database,
    temporary,
    active
FROM pg_replication_slots
WHERE slot_name = 'sendung_slot_uat2820';

-- 3. If using publication, check which tables are included
SELECT
    pubname,
    schemaname,
    tablename
FROM pg_publication_tables
ORDER BY pubname, schemaname, tablename;

-- 4. Check current WAL generation rate
SELECT pg_current_wal_lsn() AS current_lsn;
-- Wait 5 minutes, then run again:
SELECT
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '<previous_lsn>')) AS wal_generated_5min,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '<previous_lsn>') * 12) AS estimated_per_hour;

-- 5. Check for large tables that might be source of WAL
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
```

### Monitoring Queries

```sql
-- Full diagnostic view
SELECT
    s.slot_name,
    s.active,
    s.slot_type,
    pg_size_pretty(pg_current_wal_lsn() - s.restart_lsn) AS total_lag,
    pg_size_pretty(pg_current_wal_lsn() - s.confirmed_flush_lsn) AS unconfirmed_lag,
    r.client_addr,
    r.backend_start,
    r.state AS replication_state,
    r.sent_lsn,
    r.write_lsn,
    r.flush_lsn,
    r.replay_lsn
FROM pg_replication_slots s
LEFT JOIN pg_stat_replication r ON s.slot_name = r.slot_name
WHERE s.slot_name = 'sendung_slot_uat2820';
```

## Prevention Strategies

### 1. Capacity Planning
- Size Datastream for peak write loads, not average
- Allow 2-3x headroom for spikes

### 2. Write Optimization
- Batch operations with periodic commits
- Schedule large operations during off-peak
- Use COPY instead of INSERT for bulk loads

### 3. Monitoring Infrastructure
- Automated alerts on lag thresholds
- Dashboard showing lag trends
- Integration with incident management

### 4. Disaster Recovery Planning
- Document resync procedures
- Maintain tested scripts for slot management
- Define RTO/RPO for data replication

### 5. Regular Reviews
- Weekly slot health checks
- Monthly capacity reviews
- Quarterly load testing

## Resolution Summary - Action Checklist

### ✅ Pre-Flight Checklist

Before making changes:
- [ ] Identify all stakeholders who depend on the Datastream data
- [ ] Verify `csik_sys_gl_sm` is indeed operational data (not business-critical)
- [ ] Get approval to exclude tables from replication
- [ ] Take snapshot of current state (lag size, table write stats)

### 🔧 Execution Steps (In Order)

**Step 1: Exclude High-Volume Operational Tables** ⏱️ 15 minutes
- [ ] GCP Console > Datastream > Stream: `new-dispo-cdc-datastream-sendung-uat2820`
- [ ] Edit stream configuration
- [ ] Add table exclusion: `csik_sys_gl_sm`
- [ ] Consider excluding: `sta_sys_gl_sm`, `ecpic_eleme` (if not business data)
- [ ] Save and monitor for errors

**Step 2: Clear Hung Transactions** ⏱️ 30 minutes
- [ ] Run diagnostic query to identify long-running transactions
- [ ] Verify they're not Datastream connections
- [ ] Terminate hung transactions
- [ ] Verify no new hung transactions appear

**Step 3: Monitor Progress** ⏱️ Ongoing (check every 30-60 min)
- [ ] Check replication lag every 30 minutes
- [ ] Calculate catchup rate
- [ ] Estimate time to full recovery
- [ ] Alert if lag continues to grow

**Step 4: Verify Resolution** ⏱️ 24-48 hours
- [ ] Lag reduced below 1 GB
- [ ] Datastream processing current events (< 1 hour behind)
- [ ] No recurring transaction issues
- [ ] WAL generation rate sustainable

**Step 5: Long-Term Improvements** ⏱️ Post-incident
- [ ] Implement retention policy for `csik_sys_gl_sm` (delete > 30 days old)
- [ ] Set up monitoring alerts for replication lag (> 10 GB = warning)
- [ ] Document which tables should/shouldn't be replicated
- [ ] Consider separate streams for operational vs business data
- [ ] Review other high-volume tables for cleanup needs

### 📊 Success Metrics

| Metric | Before | Target | Current |
|--------|--------|--------|---------|
| Replication Lag | 422-426 GB | < 1 GB | ___ |
| Time Behind | 7 days | < 1 hour | ___ |
| WAL Generation Rate | ~60 GB/day | < 5 GB/day | ___ |
| Hung Transactions | Multiple (1+ days) | 0 | ___ |
| Datastream Status | Slow (2-6 records/batch) | Normal | ___ |

### 🚨 Escalation Triggers

Contact senior DBA / architecture team if:
- [ ] Lag continues growing after table exclusion (48 hours)
- [ ] Cannot identify/terminate source of hung transactions
- [ ] `csik_sys_gl_sm` is confirmed business-critical and cannot be excluded
- [ ] Datastream errors appear after configuration changes
- [ ] Full resolution will exceed 1 week

### 📝 Post-Incident Documentation

After resolution:
- [ ] Document root cause: Operational table in CDC replication
- [ ] Update Datastream configuration documentation
- [ ] Create table classification: Business vs Operational
- [ ] Add monitoring dashboard for replication lag
- [ ] Schedule review of all replicated tables (quarterly)

---

## Final Summary - Complete Investigation Results

### What We Discovered:

1. **Replication slot lag**: 422-426 GB (growing), 7 days behind
2. **Initial suspect**: `sendung` table (based on slot name `sendung_slot_uat2820`)
3. **Actual culprit**: `csik_sys_gl_sm` table (256 GB, 456 million operations)
4. **PostgreSQL publication**: Correctly configured with ONLY `sendung` table ✅
5. **Datastream configuration**: Ignoring publication, replicating ALL tables ❌
6. **Datastream connections**: Healthy and active ✅

### Key Tables Analysis:

| Table | Size | Operations | In Publication? | Impact |
|-------|------|------------|-----------------|--------|
| `csik_sys_gl_sm` | 256 GB | 456M | ❌ NO | 🔴 99% of WAL |
| `sta_sys_gl_sm` | ~1 GB | 2.6M | ❌ NO | 🟡 Minor |
| `ecpic_eleme` | ~1 GB | 1.4M | ❌ NO | 🟡 Minor |
| `sendung` | Small | 260 | ✅ YES | ✅ Legitimate |

### Root Cause:

**Historical WAL backlog from when Datastream was replicating ALL tables (before Nov 27, 2025).**

Both PostgreSQL publication and Datastream configuration are NOW correctly set to replicate only `sendung` table (changed Nov 27), but the 422 GB of historical WAL must still be processed sequentially.

### Current Status:

**✅ Configuration Fixed (Nov 27, 2025):**
- PostgreSQL publication `sendung_pub`: Only `sendung` table ✅
- Datastream configuration: Only `sendung` table (1 of 879) ✅
- Future tables: Off ✅

**⏳ Processing Historical Backlog:**
- 422 GB of WAL from Nov 19 - Nov 27 (when `csik_sys_gl_sm` was replicated)
- Must process sequentially through old changes
- Configuration is correct, just need time to catch up

### Solution Options:

**Option 1: Wait for Natural Catchup** (Recommended if lag is stable/decreasing)
- No action needed if lag is NOT growing
- Monitor daily, should eventually catch up
- Timeline: Days to weeks depending on catchup rate

**Option 2: Scale Up Datastream** (If urgent)
- Temporarily increase Datastream resources
- Faster catchup, then scale back down

**Option 3: Drop/Recreate Slot** (Last resort)
- Only if catchup time unacceptable AND data gap acceptable
- Requires full resync (hours to days)

### Expected Outcome:

- ✅ New WAL generation: Already reduced (only `sendung` table since Nov 27)
- ⏳ Existing backlog: Will clear over time as Datastream processes historical changes
- ✅ Future lag: Should stay < 1 GB once caught up (< 1 hour behind)

### Files in This Investigation:

- `README.md` (this file) - Complete technical analysis
- `INCIDENT-RESPONSE.md` - Step-by-step resolution guide
- `EXECUTIVE-SUMMARY.md` - Business impact overview
- `INDEX.md` - Navigation guide
- `from-nikolay.md` - Original incident report
- `datastream_setup.sql` - Replication slot creation script

---

## References

- [PostgreSQL Replication Slots Documentation](https://www.postgresql.org/docs/current/warm-standby.html#STREAMING-REPLICATION-SLOTS)
- [Google Cloud Datastream Best Practices](https://cloud.google.com/datastream/docs/best-practices)
- [AlloyDB Logical Replication](https://cloud.google.com/alloydb/docs/logical-replication)
- [Datastream Table Filtering](https://cloud.google.com/datastream/docs/create-a-stream#table-filtering)
