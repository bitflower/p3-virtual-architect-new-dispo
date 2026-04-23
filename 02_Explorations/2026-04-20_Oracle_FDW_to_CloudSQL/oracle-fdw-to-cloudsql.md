# Oracle Foreign Data Wrapper (FDW) to GCP CloudSQL / AlloyDB

**Date:** 2026-04-20
**Status:** Exploration

---

## Original User Input

> Can you use a foreign data wrapper to push data from an on-prem Oracle database to a GCP CloudSQL database?

---

## Summary

**Short answer: No, not as a "push" mechanism.** FDW is a **pull** technology -- the PostgreSQL side (CloudSQL/AlloyDB) initiates queries against Oracle. Oracle has no knowledge of the FDW and cannot push data. However, `oracle_fdw` **is supported** on both CloudSQL for PostgreSQL and AlloyDB, enabling on-demand querying and periodic materialized view refreshes.

For true continuous push/CDC replication from Oracle to CloudSQL/AlloyDB, the existing project solutions (Striim, Datastream) remain the appropriate tools. See [ADR-006: Oracle CDC Solution Selection](../../09_ADRs/ADR-006-oracle-cdc-solution-selection/ADR-006-oracle-cdc-solution-selection.md).

---

## Analysis

### 1. What is oracle_fdw?

`oracle_fdw` is an open-source PostgreSQL extension ([GitHub](https://github.com/laurenz/oracle_fdw)) that implements the SQL/MED Foreign Data Wrapper standard. It uses Oracle Call Interface (OCI) to communicate with Oracle databases.

On **managed services** (CloudSQL, AlloyDB), Google bundles the Oracle Instant Client libraries internally -- no manual installation required. You simply run:

```sql
CREATE EXTENSION oracle_fdw;
```

### 2. FDW Directionality

| Direction | Operation | How It Works |
|---|---|---|
| **Pull** (Oracle -> PG) | `SELECT` on foreign table | CloudSQL queries Oracle; data flows from Oracle to CloudSQL |
| **Push** (PG -> Oracle) | `INSERT`/`UPDATE`/`DELETE` on foreign table | CloudSQL writes **to Oracle** through the foreign table |
| **Pushdown** | `WHERE`, `ORDER BY`, `JOIN` | Conditions sent to Oracle for remote execution |

**The FDW always runs on the PostgreSQL side.** Oracle sees only incoming SQL*Net connections. There is no mechanism for Oracle to initiate data transfer to CloudSQL via FDW.

### 3. Supported Extensions

Both CloudSQL for PostgreSQL and AlloyDB confirm `oracle_fdw` support:

| Extension | CloudSQL | AlloyDB |
|---|---|---|
| oracle_fdw (v1.2) | Yes | Yes |
| postgres_fdw | Yes | Yes |
| tds_fdw (SQL Server) | Yes | Yes |

### 4. Networking Requirements

Connecting CloudSQL/AlloyDB to an on-prem Oracle requires:

| Option | Latency | Bandwidth | Complexity |
|---|---|---|---|
| **Cloud VPN** + Private Services Access | 10-30ms | Up to 3 Gbps | Medium |
| **Cloud Interconnect** + Private Services Access | 1-5ms | 10-200 Gbps | High |
| **Private Service Connect (PSC)** | Varies | Varies | High (must enable PSC outbound) |

Key requirements:
- Configure Cloud Router BGP custom route advertisements for allocated CloudSQL IP ranges
- Export custom routes from VPC peering so CloudSQL can route to on-prem
- Open firewall for Oracle port 1521
- If using PSC: explicitly enable **PSC outbound connectivity** (required for oracle_fdw)

### 5. Performance Over WAN -- The Critical Risk

This is the **biggest concern** for FDW with on-premises Oracle:

- Documented case: cross-region FDW (US to Europe, ~10-12ms latency) caused **5-10x performance degradation**
- Every `SELECT` on a foreign table is a real-time query to Oracle over the network
- No built-in caching -- every access hits Oracle
- Large result sets (200M+ rows) can cause queries to "run forever"
- Cross-server joins between local and foreign tables are especially problematic

**Mitigations:**
- Use **materialized views** to cache Oracle data locally (periodic refresh)
- Increase `prefetch` option in oracle_fdw to reduce round trips
- Run `ANALYZE` on foreign tables for better query plans
- Enable `use_remote_estimate` for accurate cost estimation
- Avoid joining large foreign tables with local tables

### 6. Data Type Mapping Issues

| Oracle Type | Problem |
|---|---|
| `NUMBER` (no precision) | No direct PG equivalent; must map to `numeric`, `integer`, or `bigint` |
| `NCLOB` | **Not supported** by oracle_fdw |
| `VARCHAR2(n BYTE)` vs `CHAR` | Oracle byte-length vs. PG character-length |
| `DATE` | Oracle DATE includes time; PG DATE does not |
| `TIMESTAMP WITH LOCAL TIME ZONE` | Requires `set_timezone` option |

### 7. Transaction Consistency Limitations

- oracle_fdw uses **SERIALIZABLE** isolation on Oracle side (= PG REPEATABLE READ)
- **No two-phase commit** (PREPARE TRANSACTION not supported)
- **No distributed transaction guarantee** between CloudSQL and Oracle
- Concurrent updates to foreign tables can cause serialization failures

---

## Comparison: FDW vs. Existing CDC Solutions

| Criterion | oracle_fdw | Datastream + Dataflow | Striim |
|---|---|---|---|
| **Direction** | Pull (on-demand) | Push (CDC) | Push (CDC) |
| **Latency** | Per-query (WAN dependent) | 5-66 min (current config) | Sub-second |
| **Managed** | Yes (on CloudSQL/AlloyDB) | Yes | No (self-managed) |
| **Schema Conversion** | No | No | Partial |
| **Continuous Replication** | No (query-time only) | Yes | Yes |
| **Cost** | Extension only (no extra) | ~$344/mo (current estimate) | ~$2,771/mo |
| **Use Case** | Ad-hoc queries, mat. views | Batch/near-real-time sync | Real-time sync |

---

## Findings

1. **oracle_fdw IS available** on both CloudSQL and AlloyDB -- Google bundles Oracle client libraries internally
2. **FDW cannot "push"** -- it is always initiated from the PostgreSQL side
3. **Performance over WAN is a significant risk** -- not suitable for high-frequency or large-volume real-time queries against on-prem Oracle
4. **Materialized views** are the practical pattern: create foreign tables, then `REFRESH MATERIALIZED VIEW` on a schedule
5. **FDW complements CDC, it does not replace it** -- use FDW for ad-hoc querying; use Striim/Datastream for continuous replication
6. **AlloyDB has better FDW ergonomics** than CloudSQL due to its columnar engine and intelligent caching (beneficial for materialized view patterns)
7. **Networking is solvable** -- Cloud VPN or Interconnect with Private Services Access; PSC requires explicit outbound enablement

---

## Recommendation for New Dispo Context

Given the existing architecture:
- **AlloyDB** is already the target database (tms-alloydb-schema)
- **Striim and Datastream** are already evaluated for Oracle CDC ([ADR-006](../../09_ADRs/ADR-006-oracle-cdc-solution-selection/ADR-006-oracle-cdc-solution-selection.md))

**oracle_fdw could serve as a complementary tool** for:
- Ad-hoc querying of Oracle reference data that doesn't need CDC
- Development/debugging scenarios where you need to inspect Oracle data from AlloyDB
- One-time data migration for static lookup tables

**It should NOT replace the CDC pipeline** for operational data that requires continuous synchronization.

---

## Questions/Open Items

- [ ] Is there a specific use case driving this question? (e.g., a table that doesn't need CDC but needs occasional access?)
- [ ] Would materialized views with scheduled refresh (e.g., every 15 min) meet the latency requirement for any specific data?
- [ ] Is VPN connectivity between GCP and the on-prem Oracle environment already established? (Likely yes, given Striim/Datastream PoC)

---

## Related Files

- [ADR-006: Oracle CDC Solution Selection](../../09_ADRs/ADR-006-oracle-cdc-solution-selection/ADR-006-oracle-cdc-solution-selection.md)
- [ADR-007: Datastream PSC Proxy Retention](../../09_ADRs/ADR-007-datastream-psc-proxy-retention/ADR-007-datastream-psc-proxy-retention.md)
- [Oracle CDC PoC Analysis](../2026-04-15_Oracle-CDC-PoC-Analysis/)
- [Oracle CDC Kick-Off](../2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off/)

---

## Sources

- [Cloud SQL PostgreSQL Extensions (official)](https://docs.cloud.google.com/sql/docs/postgres/extensions)
- [AlloyDB Supported Extensions (official)](https://docs.cloud.google.com/alloydb/docs/reference/extensions)
- [Google Codelab: AlloyDB Oracle FDW via VPN](https://codelabs.developers.google.com/codelabs/alloydb-oracle-fdw-vpn)
- [GitHub: laurenz/oracle_fdw](https://github.com/laurenz/oracle_fdw)
- [Datastream Overview (official)](https://docs.cloud.google.com/datastream/docs/overview)
- [Database Migration Service: Oracle to PostgreSQL (official)](https://cloud.google.com/database-migration/docs/oracle-to-postgresql/scenario-overview)
