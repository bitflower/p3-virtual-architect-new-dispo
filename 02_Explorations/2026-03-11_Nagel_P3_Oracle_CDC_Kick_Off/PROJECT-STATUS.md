# Project: Oracle CDC Solution for TMS Branch Databases

**Status:** 🔄 In Progress - POC Phase
**Author:** Virtual Architect
**Last Updated:** 2026-03-13
**Next Milestone:** Workshop on 2026-03-16
**Go-Live Target:** June 2026

---

## Quick Overview

**Problem:** P3 branches use Oracle TMS, but current CDC solution only supports Postgres. Need Oracle CDC to enable real-time data synchronization for New Dispo.

**Solution Approach:** Evaluate two CDC options in parallel POCs:
- **Striim** (already deployed at Nagel, character set mapping capability)
- **Datastream** (native GCP, consistent with existing Postgres CDC)

**POC Scope:** Intentionally kept minimal - CDC replication ends at Cloud Storage (Object Store). Downstream Cloud SQL updates and event format harmonization (Oracle ↔ Postgres) are considered post-POC as preparation for business logic integration.

**Decision Timeline:** End of March 2026 (POC completion)

---

## Current Status

### ✅ Completed (CW 11)
- [x] GCP storage buckets provisioned (oracle-striim-bucket-poc, oracle-datastream-bucket-poc)
- [x] Workshop scheduled for Monday, March 16, 14:30-15:00
- [x] Initial gap analysis completed - [Analysis](2026-03-13_meeting-coverage-analysis.md)
- [x] TMS1034 (ABN) Oracle connection ready for P3
- [x] UAT 1060 Oracle DB ready for order duplication
- [x] UAT 1034 Oracle DB ready for order duplication
- [x] Database selection confirmed (1034 ABN, 1060 UAT)

### 🔄 In Progress
- [ ] Datastream setup in WL5 (P3 responsibility)
- [ ] Oracle prerequisites setup (ARCHIVELOG, LogMiner, CDC user)
- [ ] Character set compatibility investigation
- [ ] Manual insert trigger into sending table (post-datastream enablement)

### ⏳ Next Up
- Workshop execution (March 16)
- Parallel POC testing (Striim + Datastream)
- Load testing with OMS order duplication (1 week duration)

### Blockers
1. **Connection details handoff** - TMS1034 Oracle connection ready, need to identify P3 contact for receiving details
2. **Oracle prerequisites** - LogMiner setup and supplemental logging needed for Datastream

---

## Timeline

| Phase          | Period       | Status        | Key Activities                            |
| -------------- | ------------ | ------------- | ----------------------------------------- |
| Kick-Off       | March 11     | ✅ Complete    | Initial alignment, option presentation    |
| Preparation    | March 11-15  | 🔄 In Progress | GCP setup, Oracle prerequisites           |
| Workshop       | March 16     | ⏳ Scheduled   | Technical walkthrough, POC kickoff        |
| POC Execution  | March 16-20  | ⏳ Planned     | Manual validation, setup confirmation     |
| Load Testing   | March 23-30  | ⏳ Planned     | 1-week stress test with order duplication |
| Evaluation     | End of March | ⏳ Planned     | Option selection, cost analysis           |
| Decision       | Early April  | ⏳ Planned     | Final architecture decision               |
| Implementation | April-May    | ⏳ Planned     | Production rollout preparation            |
| Go-Live        | June 2026    | 🎯 Target      | P3 branches production deployment         |

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

### Upcoming Deliverables
- [ADR: Oracle CDC Solution Selection](../../../09_ADRs/ADR-Oracle-CDC-Solution.md) _(Pending - to be written post-POC)_
- **Rollout Plan: Oracle CDC Production Deployment** _(Pending)_
- **Setup Guide: Oracle CDC Configuration** _(To be documented during POC)_
- **Cost Analysis: Striim vs Datastream** _(To be completed during POC)_

---

## Communication

### Meeting History
- **2026-03-11:** Kick-Off Meeting (56 min) - [Teams Link](https://teams.microsoft.com/meet/39050326979606?p=6txN2RVcQCVGEmqpuZ)
- **2026-03-16:** Follow-up Workshop (30 min) - _Scheduled_

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
| 2026-03-13 | Project status synced to wiki, all updates from Matt's communication reflected                                                                                     | Virtual Architect      |
| 2026-03-13 | TMS1034 (ABN) Oracle connection ready, UAT databases (1034, 1060) ready for order duplication, Datastream setup assigned to WL5, Cloud SQL/Storage assigned to WL4 | Matt Wilkinson (Nagel) |
| 2026-03-13 | Project page created, pending items documented                                                                                                                     | Matthias               |
| 2026-03-13 | Workshop scheduled for March 16                                                                                                                                    | Martin                 |
| 2026-03-13 | GCP infrastructure provisioning completed                                                                                                                          | P3 DevOps Team         |
| 2026-03-11 | Kick-off meeting conducted, 7 action items assigned                                                                                                                | All                    |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub><br>
  <sub>Living document - updates automatically as project progresses</sub>
</div>
