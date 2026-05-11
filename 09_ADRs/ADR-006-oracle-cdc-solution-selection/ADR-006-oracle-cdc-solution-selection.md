# [ADR006] Oracle CDC Solution Selection for TMS Branch Databases

**Status:** Accepted
**Date:** 2026-04-15
**Decision Date:** 2026-04-28

## Context

The New Dispo system requires Change Data Capture (CDC) from on-premises Oracle TMS databases to enable real-time data synchronization for TMS branch operations. The existing CDC pipeline (ADR-001) uses Google Datastream for Postgres-based branches. With the strategic shift toward Oracle TMS at branches, a CDC solution is needed that supports Oracle as a source and delivers change events to GCP Cloud Storage.

**Stakeholders:** P3 (Matthias Max, Martin Dittmann), Nagel IT (Christian Lang, Matt Wilkinson, Ron Vervenne, Thomas Paulus)

**Go-Live Target:** June 2026

A parallel PoC was executed from March to April 2026, testing both Striim and Google Datastream against Oracle TMS1060.SENDUNG (UAT environment). The PoC scope ended at Cloud Storage — downstream processing was considered post-PoC.

#### Options Considered

* **Option A: Striim** — extend existing Nagel Striim deployment; self-managed VM-based platform hosted in GCP WL3. Sub-second latency proven.
* **Option B: Google Datastream** — GCP-native serverless CDC service; consistent with existing Postgres CDC pattern. Latency depends on Oracle redo log configuration and Datastream read mode:
    * **B1: Datastream + Oracle redo log tuning** (ARCHIVE_LAG_TARGET=900, 256MB logs) — expected 5-20 min latency, low effort
    * **B2: Datastream + Binary Log Reader** (Preview, not GA) — expected 1-5 min latency, no SLA
    * **B3: Datastream as-is** (current Oracle config) — 42-66 min latency, unacceptable

## Decision

**Option A: Striim** — accepted for Go-Live 1060 (June 2026).

Decided in the April 28, 2026 follow-up meeting. Striim is the CDC solution for the go-live timeline. The Datastream Binary Log Reader (Option B2) is being explored in parallel as a potential post-go-live optimization but is not blocking the go-live decision. The Datastream LogMiner approach (Option B3) was ruled out on April 21 due to unacceptable latency (~42-66 min).

**Rationale for Striim over waiting for Binary Log Reader:**
- Striim is production-proven (~2 years streaming Oracle to GCP at Nagel)
- Sub-second latency confirmed in PoC (vs. Binary Log Reader's unproven performance at scale)
- Striim license secured until October 2026 (borrowed Google license, extended by Matt Wilkinson)
- Binary Log Reader is in GCP Preview (not GA), requires excessive Oracle permissions beyond documentation, and has not been validated under production load
- Go-live deadline (June 2026) does not allow waiting for Binary Log Reader GA or further investigation

## Rationale

### PoC Results Summary

| Criterion | Striim | Datastream |
|-----------|--------|------------|
| **End-to-end latency** | **~100ms** (flat, no variance) | **~42-66 min** avg (P50). Initial reports of 16-20s were system processing latency only — 99.4% of total latency is read lag waiting for Oracle archived redo logs |
| **Completeness** | 99.98% (60,967 of 60,978 events) | **100%** (23,751 records, zero errors) |
| **Managed service** | No (self-managed VM) | Yes (serverless) |
| **GCP-native** | No | Yes |

Patrick Uschmann (PO) verbally confirmed on 2026-04-08 that **~10 seconds is acceptable; minutes would be problematic**. This tolerance is not yet formally documented and needs re-evaluation given the corrected latency numbers.

## Costs

| | Datastream | Striim (borrowed license)* | Striim (commercial 8-core min.)* |
|---|---|---|---|
| **Monthly (64 DBs)** | EUR 344 | EUR 2,771* | EUR 20,571* |
| **Annual (64 DBs)** | EUR 4,124 | EUR 33,248* | EUR 246,848* |
| **Ratio** | 1x | 8x | 60x |

*\* Striim is currently running on a borrowed Google license (confirmed unsustainable by Matt Wilkinson). If Nagel must pay independently, marketplace pricing starts at $19,200/month (8-core minimum tier). Actual Striim quote required.*

## Consequences

### If Striim is Selected

* **Positive**: Sub-second latency; 99.98% delivery rate; already deployed and operational; fastest path to go-live
* **Negative**: Unknown and potentially significant licensing costs ($19,200+/month); not GCP-native; self-managed VM infrastructure

### If Datastream is Selected (with Oracle tuning)

* **Positive**: GCP-native; serverless; transparent pricing (~EUR 344/month for 64 DBs); consistent with existing Postgres CDC pattern
* **Negative**: Higher latency (5-20 min even after tuning); requires Oracle DBA coordination; second PoC needed to validate

## Related ADRs

* [[ADR001] Data Exchange Between TMS and CALSuite's Cross-Dock](../ADR-001-data-exchange-tms-calsuite-cross-dock/ADR-001-data-exchange-tms-calsuite-cross-dock.md) — established Datastream as CDC solution for Postgres
* [[ADR007] Retain PSC Proxy for Datastream-to-AlloyDB Connectivity](../ADR-007-datastream-psc-proxy-retention/ADR-007-datastream-psc-proxy-retention.md) — proxy decision for Postgres Datastream

## References

* Detailed analysis: [Datastream CDC Analysis Report](../../02_Explorations/2026-04-15_Oracle-CDC-PoC-Analysis/consolidated_report.md)
* Project status: [Oracle CDC Project](../../02_Explorations/2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off/PROJECT-STATUS.md)


* Azure DevOps: [Feature 121925: TMS Pulse ORA Extension](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/121925)

## Document History

| Date | Author | Change |
|------|--------|--------|
| 2026-04-15 | Matthias Max | Initial ADR created from PoC results |
| 2026-05-11 | Matthias Max | ADR accepted: Striim selected (decided Apr 28 meeting). Decision rationale added. Binary Log Reader noted as parallel post-go-live track |
| 2026-04-17 | Matthias Max | Complete rewrite: incorporated deep analysis (CW 16), corrected latency from 16-20s to 42-66 min, slimmed format |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
