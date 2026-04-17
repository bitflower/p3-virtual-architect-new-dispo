# Project: Oracle CDC Solution for TMS Branch Databases

**Status:** 🔄 In Progress - POC Results Received, ADR In Progress
**Author:** Virtual Architect
**Last Updated:** 2026-04-15
**Next Milestones:**
1. Resolve ADR-006 outstanding items (Striim license costs, Datastream WL5 retest, SE2 validation)
2. Close ADR-006 with final technology decision
3. Production readiness documentation

**Go-Live Target:** June 2026

---

## Quick Overview

**Problem:** Nagel branches use Oracle TMS, but current CDC solution only supports Postgres. Need Oracle CDC to enable real-time data synchronization for New Dispo.

**Solution Approach:** Evaluate two CDC options in parallel POCs:
- **Striim** (already deployed at Nagel, character set mapping capability)
- **Datastream** (native GCP, consistent with existing Postgres CDC)

**POC Scope:** Intentionally kept minimal - CDC replication ends at Cloud Storage (Object Store). Downstream Cloud SQL updates and event format harmonization (Oracle ↔ Postgres) are considered post-POC as preparation for business logic integration.

**Decision Timeline:** End of March 2026 (POC completion)

**Related Work Items:**
- [Feature 121925: TMS Pulse ORA Extension](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/121925)

---

## Current Status

### ✅ Completed (CW 11)
- [x] Workshop executed on March 16 (Technical walkthrough, POC kickoff)
- [x] Service account configured for Striim Cloud Storage access (wl5-cloudrun@prj-cal-w-wl5-t-6c00-53ad.iam.gserviceaccount.com)
- [x] UAT bucket created (oracle-striim-bucket-poc-1060uat) for order duplication testing
- [x] First CDC event successfully captured from Oracle TMS1034.SENDUNG table - [2026-03-18_first_striim_cdc_event.json]
- [x] Striim instance setup completed and configured
- [x] GCP storage buckets provisioned (oracle-striim-bucket-poc, oracle-datastream-bucket-poc)
- [x] Workshop scheduled for Monday, March 16, 14:30-15:00
- [x] Initial gap analysis completed - [Analysis](2026-03-13_meeting-coverage-analysis.md)
- [x] TMS1034 (ABN) Oracle connection ready for P3
- [x] UAT 1060 Oracle DB ready for order duplication
- [x] UAT 1034 Oracle DB ready for order duplication
- [x] Database selection confirmed (1034 ABN, 1060 UAT)

### ✅ Completed (CW 12)
- [x] Striim successfully streaming from Nuremberg test database to GCS bucket (confirmed March 20 meeting)
- [x] Order duplication into TMS1060 already in progress
- [x] Borrowed Google license for Striim confirmed by Matt Wilkinson (expiring end of March 2026)
- [x] U_TIME identified as latency measurement column (confirmed by Christian Lang)
- [x] P3 Oracle database access clarified: no direct access, Nagel-side only
- [x] GCS permission issue on UAT bucket identified and being resolved by Matt Wilkinson

### ✅ Completed (CW 13)
- [x] Striim load test executed against TMS1060 with production-like data (~60,978 events over 34h)
- [x] Datastream became active from March 30 (late start due to connectivity setup)
- [x] Both PoCs running in parallel against same Oracle source database

### ✅ Completed (CW 14-15)
- [x] PoC results data package received from Matt Wilkinson (2026-04-02)
- [x] Striim PoC: Sub-second latency (~100ms), 99.98% delivery (60,978 events), cross-workload WL3->WL5 confirmed
- [x] Datastream PoC: 16-20s median latency, active from Mar 30 only (~3 days)
- [x] Cost data received: Striim EUR 2,770.70/mo (shared WL3 platform), Datastream EUR 1.36/mo (inactive PoC)
- [x] Technical evaluation document drafted (Oracle_GCP_CDC_Technical_Evaluation.docx) - incomplete, many [TBC] entries
- [x] P3 comparison data package received (P3_CDC_Comparison_Data_Package.docx) - answers latency, completeness, cost questions
- [x] Patrick Uschmann confirmed ~10s latency acceptable; minutes would be problematic (April 8 meeting, verbal, not formally documented)
- [x] PoC execution stopped (confirmed safe to stop OMS order duplication, April 8)
- [x] Postgres Datastream baseline flagged: ABN 1034 Postgres also showing 10-15s latency (Matt Wilkinson, April 8)
- [x] ADR-006 drafted - [ADR-006: Oracle CDC Solution Selection](../../09_ADRs/ADR-006-oracle-cdc-solution-selection/ADR-006-oracle-cdc-solution-selection.md)

### 🔄 In Progress
- [ ] ADR-006 outstanding items resolution (8 items, see ADR)
- [ ] Request for Dominik support raised with Christian Lang by Martin Dittmann
- [ ] Striim licensing extension request submitted to Google by Matt Wilkinson

### 🚫 Blocked
- [ ] **Striim license cost data** - required for fair cost comparison (Owner: Matt Wilkinson / Christian Lang)
- [ ] **Datastream delivery rate / completeness** - PoC data only contains event counts and latencies from Datastream side; no source-vs-target comparison exists to calculate delivery rate (Striim has 99.98%). Requires retest with minimum 1 week duration and event count reconciliation against Oracle source. (Owner: Matt Wilkinson)
- [ ] **Datastream WL5 network deployment** - required for like-for-like comparison (Owner: Ron Vervenne)
- [ ] **Datastream Oracle SE2 validation** - required to confirm viability at branch sites

### ⏳ Next Up
- Define latency requirement for New Dispo use case (is 20s acceptable or must it be sub-second?)
- Re-run Datastream PoC with WL5 connectivity (minimum 1 week duration)
- Complete [TBC] entries in technical evaluation document
- Close ADR-006 with final decision

---

## Timeline

| Phase          | Period       | Status        | Key Activities                            |
| -------------- | ------------ | ------------- | ----------------------------------------- |
| Kick-Off       | March 11     | ✅ Complete    | Initial alignment, option presentation    |
| Preparation    | March 11-15  | ✅ Complete    | GCP setup, Oracle prerequisites           |
| Workshop       | March 16     | ✅ Complete    | Technical walkthrough, POC kickoff        |
| POC Execution  | March 16 - April 2 | ✅ Complete | Striim + Datastream tested against TMS1060.SENDUNG |
| POC Results    | April 2      | ✅ Complete    | Data package received from Matt Wilkinson |
| Evaluation     | April 15     | 🔄 In Progress | ADR-006 drafted, outstanding items identified |
| Decision       | April 2026   | ⏳ Planned     | Pending: Striim costs, Datastream WL5 retest, SE2 validation |
| Production-Readiness | May 2026     | ⏳ Planned     | Rollout document creation, go-live prep   |
| Go-Live        | June 2026    | 🎯 Target      | Nagel branches production deployment      |

---

## Team & Stakeholders

### P3/CAL Team
- **Matthias Max** - Enterprise Architect, Technical Lead, GCP Infrastructure, POC Coordination
- **Martin Dittmann** - Project Manager, Project Coordination, Workshop Facilitation
- **Maximilian Kehder** - Product Owner
- **Nikolay Hristov** - DevOps Engineer, GCP Infrastructure Setup
- **Yosif Mihaylov** - Lead Developer (Backend), Development Support
- **Boyan Valchev** - Lead Developer (Frontend), Development Support

### Nagel Team
- **Christian Lang** - CEO Nagel IT, Decision Authority
- **Patrick Uschmann** - Product Owner
- **Matt Wilkinson** - Infrastructure Lead, Striim Setup
- **Ron Vervenne** - Cloud Engineer, Infrastructure Platform
- **Thomas Paulus** - TMS Database Developer, Oracle Configuration
- **Eric Meijers** - Cloud Engineer, DBA Support
- **Steve** - Additional Infrastructure Support

---

## Related Documentation

### Existing Architecture
- [Shipment Data Flow Architecture](../../../WIKI/Nagel-CAL-Disposition.wiki/Technical-Documentation/Process-Flows/Shipment-Data-Flow-Architecture.md) _(Shown in kick-off meeting)_
- [TMS Bridge Documentation](../../../WIKI/Nagel-CAL-Disposition.wiki/EBV-%2D-TMS-Bridge/TMS-Bridge-Overview.md)
- [Deployment Mapping](../../../WIKI/Nagel-CAL-Disposition.wiki/Technical-Documentation/Infrastructure/Deployment-Mapping.md) _(TEST environment, WL5 workload)_

### Technical References
- [Google Datastream: Configure Oracle Self-Managed Database](https://docs.cloud.google.com/datastream/docs/configure-self-managed-oracle) _(Official setup guide - confirmed by P3 on 2026-03-13)_

### Deliverables
- [ADR-006: Oracle CDC Solution Selection](../../09_ADRs/ADR-006-oracle-cdc-solution-selection/ADR-006-oracle-cdc-solution-selection.md) _(Proposed - 8 outstanding items before closure)_
- [PoC Results Data Package](../../00_Meetings/2026-04-13-Oracle%20POC%20Results%20from%20Matt%20Wilkinson/) _(Received 2026-04-02)_
- **Rollout Plan: Oracle CDC Production Deployment** _(Pending - post-ADR closure)_
- **Setup Guide: Oracle CDC Configuration** _(Partially documented in Technical Evaluation - needs [TBC] completion)_
- **Cost Analysis: Striim vs Datastream** _(Partial - Striim license costs still unknown)_

---

## Communication

### Meeting History
- **2026-03-11:** Kick-Off Meeting (56 min) - [Teams Link](https://teams.microsoft.com/meet/39050326979606?p=6txN2RVcQCVGEmqpuZ)
- **2026-03-16:** Follow-up Workshop (30 min) - _Completed_
- **2026-03-20:** Workshop (14:30) - _Scheduled_

### Discussion Channels
- **Teams Chat:** [Oracle CDC POC Discussion](https://teams.microsoft.com/l/chat/19:c11215f85805443396007013fbbbff97@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D)

**Have questions?** Contact Matthias or comment in the Teams chat.

---

## Success Criteria

_To be defined in workshop - pending alignment with stakeholders_

**Proposed Metrics:**
- Throughput: TBD events/sec or rows/min
- Latency: Max acceptable end-to-end delay TBD
- Volume: POC must demonstrate TBD transaction volume
- Stability: Solution must run for TBD hours/days without issues

---

## Context & Dependencies

### Business Context
- TMS Branches currently use Oracle TMS (strategic shift from Postgres)
- June 2026 Go-Live deadline for TMS branch support
- Feature parity requirement with existing Postgres CDC

### Technical Dependencies
- Oracle database versions and editions (11.2, 12c, 18+?)
- Network connectivity: GCP ↔ On-premise Oracle
- Character set compatibility (UTF-8 vs Oracle legacy)
- Infrastructure constraints (disk space for log retention)

### Risk Areas
- **Log File Cycling:** Potential data loss if CDC disconnects during rapid redo log cycling
- **Character Set Issues:** Poland experiencing real-world character corruption
- **Network Stability:** Connection interruptions can corrupt replication slots
- **Infrastructure Capacity:** Limited disk space affects log retention

---

## Change Log

| Date       | Update                                                                                                                                                             | Updated By             |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------- |
| 2026-04-15 | ADR-006 drafted from PoC results; project status updated with findings; 8 outstanding items identified | Virtual Architect |
| 2026-04-15 | PoC results received from Matt Wilkinson (2026-04-02): Striim ~100ms latency/99.98% delivery; Datastream ~16-20s latency/completeness TBD | Virtual Architect |
| 2026-03-20 | Added item to completed: Workshop executed on March 16 (Technical walkthrough, POC kickoff) | Matthias |
| 2026-03-20 | Added item to in-progress: Request for Dominik support raised with Christian Lang | Matthias |
| 2026-03-20 | Added item to in-progress: Striim licensing extension request submitted to Google | Matthias |
| 2026-03-20 | Status updated to: In Progress - POC Active | Matthias |
| 2026-03-20 | Added item to completed: Service account configured for Striim Cloud Storage access (wl5-cloudrun@prj-cal-w-wl5-t-6c00-53ad.iam.gserviceaccount.com) | Matthias |
| 2026-03-20 | Added item to completed: UAT bucket created (oracle-striim-bucket-poc-1060uat) for order duplication testing | Matthias |
| 2026-03-20 | Added item to completed: First CDC event successfully captured from Oracle TMS1034.SENDUNG table | Matthias |
| 2026-03-20 | Added item to completed: Striim instance setup completed and configured | Matthias |
| 2026-03-13 | POC scope clarified - intentionally ends at Cloud Storage, Cloud SQL harmonization post-POC                                                                       | Virtual Architect      |
| 2026-03-13 | Project status synced to wiki, all updates from Matt's communication reflected                                                                                     | Virtual Architect      |
| 2026-03-13 | TMS1034 (ABN) Oracle connection ready, UAT databases (1034, 1060) ready for order duplication, Datastream setup assigned to WL5, Cloud SQL/Storage assigned to WL4 | Virtual Architect      |
| 2026-03-13 | Project page created, pending items documented                                                                                                                     | Virtual Architect      |
| 2026-03-13 | Workshop scheduled for March 16                                                                                                                                    | Virtual Architect      |
| 2026-03-13 | GCP infrastructure provisioning completed                                                                                                                          | Virtual Architect      |
| 2026-03-11 | Kick-off meeting conducted, 7 action items assigned                                                                                                                | Virtual Architect      |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub><br>
  <sub>Living document - updates automatically as project progresses</sub>
</div>
