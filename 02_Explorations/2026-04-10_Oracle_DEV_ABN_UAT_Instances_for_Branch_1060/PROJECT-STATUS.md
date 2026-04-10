# Project: Oracle Testing

**Status:** 🔄 In Progress
**Author:** Matthias Max
**Last Updated:** 2026-04-10
**Next Milestone:** PO approval for Oracle test environment provisioning
**Target Date:** TBD (dependent on PO decision and Nagel/CAL infrastructure)

---

## Quick Overview

**Problem:** The New Dispo Oracle migration is being developed and tested on an empty ENT1 instance with no real branch data. There are no DEV, ABN, or UAT Oracle environments with 1060 data. The Postgres world has a full environment pipeline (ENT* -> ABN* -> UAT* -> TMS*) -- Oracle has none.

**Solution Approach:** Establish Oracle test environments (ORA-DEV-1060, ORA-ABN-1060, ORA-UAT-1060) with real branch 1060 data to enable proper integration testing, TMS Pulse load testing, and business feature validation before production go-live.

**Decision Timeline:** Awaiting PO approval and Joachim's feedback on central DB link impact.

---

## Current Status

### ✅ Completed
- [x] Initial assessment and environment gap analysis - [Assessment](oracle-dev-abn-uat-instances-for-branch-1060.md)
- [x] Chat with Joachim Schreiner on current TMS DB migration process (2026-04-10)

### 🔄 In Progress
- [ ] Awaiting Joachim's feedback on impact of missing central DB link on testing quality

### ⏳ Next Up
- PO decision on provisioning Oracle test environments
- Define data strategy per environment (snapshot vs. flowing PROD data)
- Coordinate with Nagel/CAL Infrastructure for provisioning
- Configure New Dispo test environments to point at Oracle instances
- First end-to-end integration test with real Oracle 1060 data
- TMS Pulse load test on ORA-ABN-1060

### 🔴 Blockers
1. **Joachim's feedback pending** - Impact assessment of missing central DB link on testing possibilities and quality. May change the data strategy for ABN/UAT.
2. **PO approval required** - Cannot proceed with provisioning without Product Owner sign-off.

---

## Project Steps

Each step is documented as a sub-page:

| Step | Title | Status | Document |
|------|-------|--------|----------|
| 1 | Environment Gap Assessment & Proposal | ✅ Complete | [Assessment](oracle-dev-abn-uat-instances-for-branch-1060.md) |
| 2 | Joachim Feedback: Central DB Link Impact | ⏳ Pending | TBD |
| 3 | PO Decision & Provisioning Kick-Off | ⏳ Pending | TBD |

---

## Timeline

| Phase | Period | Status | Key Activities |
|-------|--------|--------|----------------|
| Assessment | 2026-04-10 | ✅ | Gap analysis, proposal document, Joachim consultation |
| Decision | TBD | ⏳ | Joachim feedback, PO approval |
| Provisioning | TBD | ⏳ | Nagel/CAL provisions ORA-DEV/ABN/UAT-1060 |
| Data Setup | TBD | ⏳ | Snapshot for DEV, PROD data feed for ABN, snapshot + temp feed for UAT |
| Validation | TBD | ⏳ | End-to-end integration test, TMS Pulse load test |

---

## Team & Stakeholders

### Nagel / CAL
- **Joachim Schreiner** - TMS Database Lead, Oracle wrapper migration, ENT1 development
- **Patrick Uschmann** - Product Owner (New Dispo), approval authority for environment provisioning

### P3
- **Matthias Max** - Architect
- **Maximilian Kehder** - Techn. Product Owner

---

## Related Documentation

### Project Steps
- [Step 1: Environment Gap Assessment & Proposal](oracle-dev-abn-uat-instances-for-branch-1060.md)

### External References
- [Azure DevOps CALtms Repo](https://dev.azure.com/caldevops/Agile/_git/CALtms) - TMS Database code (Oracle wrappers)
- [Azure DevOps Work Item #172451](https://dev.azure.com/caldevops/Agile) - NewDispo: Wrapper-Migration from PGS to ORA

### Related Projects
- [Oracle CDC Solution for TMS Branch Databases](../2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off/PROJECT-STATUS.md)

---

## Communication

### Meeting History
- **2026-04-10:** Chat with Joachim Schreiner - TMS DB migration process, ENT1 limitations, central DB conflict concern

---

## Context & Dependencies

### Business Context
- P3 branches are transitioning from Postgres to Oracle TMS
- June 2026 target for Oracle CDC go-live
- TMS Pulse requires realistic load testing before Oracle branches go live

### Technical Dependencies
- Nagel/CAL Infrastructure for Oracle instance provisioning
- Joachim's team for 1060 data snapshot export
- PROD data replication mechanism for ABN (and potentially UAT)

### Risk Areas
- **Blind production deployment:** Without test environments, first real Oracle data contact happens in production
- **Character encoding:** Known UTF-8 vs. Oracle legacy charset issues (Poland corruption incident)
- **Wrapper migration quality:** Stored procedures tested against empty tables only

---

## Project Health Indicators

| Indicator | Status | Notes |
|-----------|--------|-------|
| **Schedule** | 🟡 | No timeline set yet -- dependent on PO decision |
| **Scope** | 🟢 | Clear: three Oracle instances for branch 1060 |
| **Resources** | 🟡 | Nagel/CAL infrastructure availability unknown |
| **Risks** | 🔴 | Currently testing blind on ENT1 with no real data |
| **Blockers** | 🟡 | Awaiting Joachim feedback and PO approval |

**Legend:** 🟢 Good | 🟡 Attention Needed | 🔴 Critical

---

## Change Log

| Date | Update | Updated By |
|------|--------|------------|
| 2026-04-10 | Project created, Step 1 (Assessment) completed | Matthias Max |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub><br>
  <sub>Living document - updates automatically as project progresses</sub>
</div>
