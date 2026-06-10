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

## 6. Alternative: AlloyDB `max_slot_wal_keep_size` as Safety Net

Independent of monitoring, configure a WAL retention limit on AlloyDB as a last-resort safety net:

```sql
ALTER SYSTEM SET max_slot_wal_keep_size = '100GB';
SELECT pg_reload_conf();
```

This prevents any single replication slot from holding more than 100 GB of WAL. If the limit is exceeded, the slot's `wal_status` changes to `lost` and PostgreSQL reclaims the WAL. The consumer (Datastream) will then require a full resync.

**Trade-off:** Protects database disk from exhaustion, but forces a destructive recovery. This should be a safety net, not a substitute for monitoring.

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
