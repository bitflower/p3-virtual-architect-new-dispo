# Replication Slot Monitoring Concept for AlloyDB

**Date:** 2026-06-10
**Status:** Concept

---

## Original User Input

> Are there native built-in ways to monitor replication slots on AlloyDB in Google Cloud and create alerts based on certain thresholds, or would I have to build something custom which actually executes the mentioned SQL?
>
> Context: The Datastream instance `new-dispo-cdc-datastream-sendung-abn1034` silently stalled on 2026-06-08. It reported as RUNNING but hadn't consumed WAL since 11:38 UTC. The replication slot `sendung_slot_abn1034` accumulated 234 GB of WAL lag with no errors logged. This is a recurring pattern -- similar incidents occurred in January 2026 (422 GB on uat2820) and March 2026.

---

## Summary

AlloyDB and Datastream do **not** provide native metrics for replication slot WAL lag. The only way to monitor `pg_replication_slots` is by executing SQL against the database and publishing results as custom metrics to Cloud Monitoring. This document proposes a Cloud Scheduler + Cloud Function solution that covers all AlloyDB instances, publishes custom metrics, and enables threshold-based alerting.

---

## 1. Native GCP Monitoring Capabilities (Gap Analysis)

### AlloyDB Cloud Monitoring

| Metric | What It Covers | Covers Replication Slots? |
|--------|---------------|--------------------------|
| `alloydb.googleapis.com/instance/postgres/replication/maximum_lag` | Read replica lag from primary | No -- physical replicas only |
| `alloydb.googleapis.com/instance/postgres/replication/replicas` | Number of replica nodes | No |
| `alloydb.googleapis.com/instance/postgres/replay_lag` | Per-node WAL replay lag | No -- read replicas only |
| System Insights (CPU, memory, connections, query perf) | Instance-level health | No |

**Verdict:** AlloyDB monitoring is limited to read replica health. No visibility into logical replication slots whatsoever.

### Datastream Cloud Monitoring

| Metric | What It Covers | Catches Silent Stalls? |
|--------|---------------|----------------------|
| `datastream.googleapis.com/stream/total_latency` | End-to-end CDC latency | Partially -- stops updating when stalled, but no "stale metric" alert available natively |
| `datastream.googleapis.com/stream/event_count` | CDC events processed | Drops to zero, but zero can be legitimate (no source changes) |
| `datastream.googleapis.com/stream/unsupported_event_count` | Unprocessable events | No |
| Stream state in console | RUNNING / PAUSED / etc. | No -- reports RUNNING even when stalled |

**Verdict:** Datastream metrics can *supplement* monitoring but cannot reliably detect silent stalls. The June 8 incident proved this: the stream reported RUNNING, logged no errors, and `total_latency` simply stopped updating without triggering any alert.

### The Gap

There is **no native way** to:
- Monitor individual replication slot WAL lag in bytes
- Alert when a slot's `wal_status` changes to `extended` or `lost`
- Detect that a slot consumer has stopped advancing
- Track `restart_lsn` vs `confirmed_flush_lsn` drift

All of these require executing SQL against `pg_replication_slots` and `pg_stat_replication`.

---

## 2. Recommended Solution: Cloud Scheduler + Cloud Function

### Architecture

```
Cloud Scheduler (every 5 min)
        |
        v
Cloud Function (Python / Node.js)
        |
        +---> Connect to AlloyDB instance(s) via Private IP
        |     (VPC connector / Serverless VPC Access)
        |
        +---> Execute monitoring SQL
        |
        +---> Publish custom metrics to Cloud Monitoring
        |     (monitoring.v3.MetricServiceClient)
        |
        v
Cloud Monitoring
        |
        +---> Alerting Policy: lag_bytes > threshold
        +---> Alerting Policy: wal_status = 'extended' or 'lost'
        +---> Alerting Policy: slot active = false (unexpected)
        +---> Notification Channel (email / Slack / PagerDuty)
```

### Monitoring SQL

The Cloud Function executes this query against each AlloyDB database:

```sql
SELECT
    slot_name,
    slot_type,
    plugin,
    active,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes,
    pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS unconfirmed_bytes,
    wal_status
FROM pg_replication_slots;
```

### Custom Metrics

Published to Cloud Monitoring under a custom metric descriptor:

| Metric Name | Type | Labels | Description |
|-------------|------|--------|-------------|
| `custom.googleapis.com/alloydb/replication_slot/lag_bytes` | GAUGE (INT64) | `database`, `slot_name`, `slot_type` | WAL lag in bytes (`pg_current_wal_lsn() - restart_lsn`) |
| `custom.googleapis.com/alloydb/replication_slot/unconfirmed_bytes` | GAUGE (INT64) | `database`, `slot_name` | Unconfirmed flush lag |
| `custom.googleapis.com/alloydb/replication_slot/active` | GAUGE (INT64) | `database`, `slot_name` | 1 = active, 0 = inactive |
| `custom.googleapis.com/alloydb/replication_slot/wal_status` | GAUGE (INT64) | `database`, `slot_name` | Encoded: 0=reserved, 1=extended, 2=unreserved, 3=lost |

### Alerting Thresholds

Based on incident history and the thresholds from the January 2026 exploration:

| Level | Threshold (`lag_bytes`) | Approx. Size | Rationale |
|-------|------------------------|-------------|-----------|
| **Warning** | > 10 GB | ~10 GB | Early sign of consumer falling behind. At ~2.4 GB/hour WAL production (observed on abn1034), this represents ~4 hours of lag. |
| **Critical** | > 50 GB | ~50 GB | Consumer significantly behind. Requires investigation within hours. At observed WAL rates, ~21 hours of accumulation. |
| **Emergency** | > 200 GB | ~200 GB | Disk pressure imminent. The June 8 incident hit 234 GB. Requires immediate intervention (pause/resume stream or drop slot). |

Additional alerting policies:

| Condition | Alert Level | Rationale |
|-----------|-------------|-----------|
| `wal_status` = `extended` (value 1) | Warning | WAL retention beyond `wal_keep_size`, slot holding back cleanup |
| `wal_status` = `lost` (value 3) | Emergency | Slot has lost required WAL segments, consumer cannot recover |
| `active` = 0 for a known CDC slot | Critical | Consumer disconnected unexpectedly |
| `lag_bytes` increasing for 3 consecutive checks (15 min) | Critical | Consumer is connected but not making progress (silent stall pattern) |

### Supplementary: Datastream Latency Staleness

As a defense-in-depth measure, create a **metric-absence alert** on `datastream.googleapis.com/stream/total_latency`:

- If no data points arrive for > 15 minutes, alert as Warning
- This catches the exact pattern from June 8: the stream was "RUNNING" but the metric stopped updating

This requires a Cloud Monitoring **MQL-based** alerting policy since standard threshold alerts don't support absence detection. Alternative: the Cloud Function can also check Datastream stream state via the Datastream API and alert if `state = RUNNING` but `total_latency` is stale.

---

## 3. Implementation Details

### Cloud Function Design

**Runtime:** Python 3.12 (matches existing Cloud Functions pattern in the project)

**Dependencies:**
- `google-cloud-monitoring` -- publish custom metrics
- `pg8000` or `asyncpg` -- PostgreSQL driver (AlloyDB uses Postgres wire protocol)
- `google-cloud-alloydb-connector` -- secure connection to AlloyDB private IP

**Configuration (environment variables or Secret Manager):**

| Variable | Description | Example |
|----------|-------------|---------|
| `ALLOYDB_INSTANCES` | JSON array of instance configs | `[{"instance": "abn1034", "ip": "10.100.47.236", "database": "abn1034", "user": "monitoring_user"}]` |
| `DB_PASSWORD_SECRET` | Secret Manager resource path | `projects/PROJECT/secrets/alloydb-monitor-pw/versions/latest` |
| `PROJECT_ID` | GCP project for custom metrics | `prj-cal-w-wl5-t-6c00-53ad` |

**Pseudocode:**

```python
def monitor_replication_slots(event, context):
    instances = json.loads(os.environ["ALLOYDB_INSTANCES"])
    password = get_secret(os.environ["DB_PASSWORD_SECRET"])
    monitoring_client = monitoring_v3.MetricServiceClient()

    for instance in instances:
        conn = connect_to_alloydb(instance, password)
        slots = conn.execute(MONITORING_SQL)

        for slot in slots:
            write_custom_metric(
                monitoring_client,
                metric_type="custom.googleapis.com/alloydb/replication_slot/lag_bytes",
                value=slot["lag_bytes"],
                labels={
                    "database": instance["database"],
                    "slot_name": slot["slot_name"],
                    "slot_type": slot["slot_type"],
                },
            )
            # ... publish other metrics

        conn.close()
```

### Networking

AlloyDB instances are on private IPs (e.g., `10.100.47.236`). The Cloud Function needs a **Serverless VPC Access connector** to reach them:

- Connector must be in the same VPC and region (`europe-west3`) as the AlloyDB instances
- Uses the existing VPC peering that Datastream already uses (`datastream-connectivity-wl5-t-t`)
- Alternatively, use the AlloyDB Auth Proxy or AlloyDB Connector library for IAM-based authentication (no password needed)

### Database User

Create a minimal read-only monitoring user on each AlloyDB instance:

```sql
CREATE USER repl_monitor WITH LOGIN PASSWORD 'xxx';
GRANT pg_monitor TO repl_monitor;
-- pg_monitor role grants read access to pg_replication_slots,
-- pg_stat_replication, and other monitoring views
```

### Cloud Scheduler

```bash
gcloud scheduler jobs create http replication-slot-monitor \
  --location=europe-west3 \
  --schedule="*/5 * * * *" \
  --uri="https://europe-west3-PROJECT.cloudfunctions.net/monitor-replication-slots" \
  --http-method=POST \
  --oidc-service-account-email=SCHEDULER_SA@PROJECT.iam.gserviceaccount.com
```

---

## 4. Multi-Database Rollout

Current AlloyDB instances with Datastream CDC:

| Database | Replication Slot | Datastream Stream | Status |
|----------|-----------------|-------------------|--------|
| `abn1034` | `sendung_slot_abn1034` | `new-dispo-cdc-datastream-sendung-abn1034` | Active (had 234 GB stall on June 8) |
| `abn2820` | `sendung_slot_uat2820` | `new-dispo-cdc-datastream-sendung-abn2820` | NOT_STARTED |

The Cloud Function should iterate over all configured instances in a single invocation. New databases are added by updating the `ALLOYDB_INSTANCES` environment variable.

As the rollout to production environments progresses, the same monitoring function covers all instances -- no per-database deployment needed.

---

## 5. Cost Estimate

| Component | Cost | Notes |
|-----------|------|-------|
| Cloud Scheduler | Free | 3 free jobs per account |
| Cloud Function | ~$0/month | 288 invocations/day x 512MB x 30s = well within free tier |
| Custom Metrics | ~$0.10/metric/month | 4 metrics x N slots, first 150 free |
| Alerting Policies | Free | Up to 500 per project |
| VPC Connector | ~$7/month | `e2-micro` minimum instance, shared across functions |

**Total: ~$7-10/month** (dominated by VPC connector, which may already exist for other Cloud Functions).

---

## 6. Recommendation: AlloyDB `max_slot_wal_keep_size` as Safety Net

### What It Does

Configure a WAL retention limit on AlloyDB to prevent replication slots from exhausting database disk:

```sql
ALTER SYSTEM SET max_slot_wal_keep_size = '100GB';
SELECT pg_reload_conf();
```

### Behavior When the Limit Is Reached

When a slot's retained WAL exceeds the configured limit, PostgreSQL acts **at the next checkpoint**:

1. **WAL segments are reclaimed** -- PostgreSQL deletes the WAL files the slot was holding, regardless of the consumer's position
2. **Slot is marked `wal_status = 'lost'`** -- the slot itself is not dropped, but it becomes invalid
3. **Consumer gets an error** -- Datastream receives `requested WAL segment has already been removed` on its next read attempt
4. **Full resync required** -- recovery requires dropping the slot, deleting and recreating the Datastream stream (triggers a full backfill/initial snapshot)

The `wal_status` transition path: `reserved` → `extended` → `unreserved` → **`lost`**

### Why This Is a Recommendation for Both Teams

**For the TMS Database team:** This is a database protection measure. Without it, a stalled Datastream consumer can accumulate hundreds of GB of WAL (234 GB on abn1034, 422 GB on uat2820 in past incidents), risking disk exhaustion and a full database outage affecting all applications -- not just CDC. Setting `max_slot_wal_keep_size` guarantees the database stays healthy regardless of what any CDC consumer does.

**For the New Dispo team:** A slot going `lost` is a clear, unambiguous signal that requires action -- unlike a silent stall where the stream reports RUNNING. It gives the team a defined recovery procedure:

1. Detect the `lost` status (via the monitoring from Section 2, or via Datastream error logs)
2. Identify the time window of lost CDC events (from the last confirmed flush LSN to the slot invalidation time)
3. Drop the invalidated slot and recreate the Datastream stream
4. Backfill the lost time window -- either via Datastream's initial snapshot (full table) or a targeted reconciliation query for the affected period
5. Resume normal CDC operation

This is a **bounded recovery problem** with a known time window, which is far better than the current situation where a silent stall can go undetected for days with an unbounded data gap.

### Suggested Threshold

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `max_slot_wal_keep_size` | `100GB` | Well above the 50 GB critical alert threshold (giving time to react), but well below disk capacity. At the observed WAL production rate of ~2.4 GB/hour (abn1034), this provides ~42 hours of buffer before the safety net triggers. |

### Trade-off

| | Without `max_slot_wal_keep_size` | With `max_slot_wal_keep_size = 100GB` |
|---|---|---|
| **Database risk** | Unbounded WAL growth, potential disk-full crash | Capped at 100 GB, database stays healthy |
| **CDC recovery** | Manual detection, unclear data gap | Automatic WAL reclaim, defined recovery procedure |
| **Data loss** | None (WAL preserved), but database may crash | CDC events in the overflow window must be reconciled |
| **Who acts** | TMS Database team (emergency disk cleanup) | New Dispo team (planned CDC recovery) |

This should be a safety net complementing the monitoring from Section 2 -- not a substitute for it. The monitoring catches issues early (10 GB warning); this prevents catastrophic outcomes if the monitoring or response fails.

---

## 7. Decision Summary

| Aspect | Decision |
|--------|----------|
| **Native monitoring sufficient?** | No -- AlloyDB and Datastream do not expose replication slot WAL lag as metrics |
| **Recommended approach** | Cloud Scheduler + Cloud Function publishing custom metrics to Cloud Monitoring |
| **Supplementary signal** | Datastream `total_latency` metric staleness detection |
| **Safety net** | `max_slot_wal_keep_size = 100GB` on AlloyDB |
| **Alerting thresholds** | 10 GB warning / 50 GB critical / 200 GB emergency |
| **Cost** | ~$7-10/month |
| **Effort to implement** | ~2-3 days (function + alerting policies + testing) |

---

## Related Incidents

| Date | Database | Slot | Peak Lag | Root Cause |
|------|----------|------|----------|------------|
| 2026-01-30 | uat2820 | `sendung_slot_uat2820` | 422 GB | Historical WAL backlog from replicating all tables before Nov 27 config fix |
| 2026-03-17 | -- | -- | -- | Replication slot outage (see `02_Explorations/2026-03-17_replication-slot-outage/`) |
| 2026-06-08 | abn1034 | `sendung_slot_abn1034` | 234 GB | Silent Datastream stall -- stream RUNNING, no errors, consumer frozen at 11:38 UTC |

All three incidents would have been detected earlier with the monitoring proposed in this document.

---

## 8. TMS Database Code Verification

Verified the recommendations from the [Gemini WAL/Replication Slots reference](../../00_Input/2026-06-10_Postgres-WAL-replication-slots-datastream-gemini.md) against the actual TMS database schema code (`Code/tms-alloydb-schema`).

### Publication Setup -- CORRECT

**Gemini recommends:** Strict `CREATE PUBLICATION ... FOR TABLE` (not `FOR ALL TABLES`).

**Code (`src/sql/scripts/misc/datastream_setup.sql:43`):**
```sql
EXECUTE FORMAT('CREATE PUBLICATION %s FOR TABLE %s',
    current_setting('myvars.publication'),
    current_setting('myvars.tablename'));
```

The script is parameterized and creates a **single-table publication**. No `FOR ALL TABLES` anywhere. Matches the recommendation.

### Replica Identity -- NOT EXPLICITLY SET (acceptable)

**Gemini recommends:** `ALTER TABLE target_table_name REPLICA IDENTITY FULL` for tables with UPDATEs/DELETEs.

**Code:** Zero `REPLICA IDENTITY` statements exist in the entire `tms-alloydb-schema` repo. However, `sendung` has a primary key:

```sql
-- src/sql/constraint/pk_uq/sendung_pk_uq.sql
ALTER TABLE ONLY sendung ADD CONSTRAINT sendungp1 PRIMARY KEY (sendung_tix);
```

PostgreSQL defaults to `REPLICA IDENTITY DEFAULT` when a PK exists, which uses the PK to identify rows in UPDATE/DELETE WAL records. This is **sufficient for Datastream** -- the PK-based default works correctly. `REPLICA IDENTITY FULL` would write the entire old row image for every UPDATE, generating significantly more WAL on a 197-column table. The Gemini recommendation is overly cautious here; it only applies to tables **without** a primary key.

### Table Count -- CONFIRMED

**Gemini says:** "1 out of 700 tables"

**Code:** **774 table files** in `src/sql/table/`. The WAL-filtering bottleneck described in the Gemini document (WAL Sender must parse all WAL to find the 1 relevant table) is real and matches all three observed incidents.

### Replication Slot Creation -- CONFIRMED (DBA-managed, idempotent)

**Gemini says:** DBAs create slots manually; Datastream references the slot name.

**Code (`src/sql/scripts/misc/datastream_setup.sql`):** The script:
1. Checks if slot already exists (idempotent)
2. Stops all `pg_cron` jobs before creation
3. Kills all other database connections (avoids open transactions blocking slot creation)
4. Creates the slot: `PG_CREATE_LOGICAL_REPLICATION_SLOT(slot_name, 'pgoutput')`
5. Re-enables all `pg_cron` jobs

This is a well-structured setup. The connection kill + job pause is a precaution against open transactions preventing slot creation -- suggests this was learned from experience.

### `max_slot_wal_keep_size` -- NOT CONFIGURED (gap)

No WAL retention safety net is configured anywhere in the schema repo. A stalled consumer can grow WAL indefinitely -- as observed: 234 GB on abn1034, 422 GB on uat2820.

This reinforces the need for monitoring (this document's proposal) **and** the safety net described in Section 6.

### Datastream User -- NOT IN SCHEMA REPO

The replication user (e.g., `tmsbr1034` for abn1034) is not defined in the schema codebase. All roles in `create_base_roles.sql` and `create_developer_roles.sql` explicitly use `NOREPLICATION`. The Datastream user is created outside this repo, likely manually per environment as documented in the [gcloud operations guide](../2026-06-09_gcloud-tooling/gcp-datastream-gcloud-operations-guide.md):

```sql
CREATE USER tmsbr1034 WITH REPLICATION LOGIN PASSWORD '...';
GRANT USAGE ON SCHEMA tms1034 TO tmsbr1034;
GRANT SELECT ON ALL TABLES IN SCHEMA tms1034 TO tmsbr1034;
```

### Verification Summary

| Check | Status | Notes |
|-------|--------|-------|
| Publication: strict `FOR TABLE` | OK | `datastream_setup.sql` uses parameterized single-table publication |
| Replica Identity | OK (implicit) | PK on `sendung_tix` provides default identity; `FULL` not needed and would increase WAL |
| Table count (~700) | Confirmed | 774 tables -- WAL filtering bottleneck is real |
| Slot creation | OK | Idempotent script with connection cleanup |
| `max_slot_wal_keep_size` | Missing | No safety net configured |
| Datastream user in code | Missing | Created manually per environment, not in schema repo |

---

## Open Items

- [ ] Confirm whether a Serverless VPC Access connector already exists in `europe-west3` for the project
- [ ] Decide on authentication method: password via Secret Manager vs AlloyDB Connector with IAM
- [ ] Validate whether `max_slot_wal_keep_size` is supported and configurable on AlloyDB (it's a PostgreSQL 13+ parameter; AlloyDB is PG-compatible but some parameters are managed)
- [ ] Determine notification channels: email to Nagel GCP team? Slack? PagerDuty?
- [ ] Decide if Oracle CDC (Datastream from Oracle) needs equivalent monitoring (different mechanism, but same stall risk)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
