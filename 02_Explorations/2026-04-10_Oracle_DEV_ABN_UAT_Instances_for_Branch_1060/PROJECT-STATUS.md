# Project: Oracle Testing

**Status:** 🔄 In Progress
**Author:** Matthias Max
**Last Updated:** 2026-04-10
**Next Milestone:** Connect New Dispo stack to ORA-ABN-1060
**Target Date:** TBD (dependent on ORA-ABN-1060 availability)

---

## Quick Overview

**Problem:** ~~We assumed Oracle had no environment pipeline for branch 1060.~~ **Corrected:** The TMS Oracle side already operates an ENT → ABN → UAT pipeline with a structured deployment process (QS tool + CLI-based rollout). ABN 1060 is already being provisioned with live production data.

**Solution Approach:** Connect the New Dispo stack (Frontend → Backend → TMS Bridge) to the existing Oracle test environments to enable end-to-end integration testing, TMS Pulse load testing, and business feature validation before production go-live.

**Decision Timeline:** No PO provisioning decision needed -- environments are being set up by Nagel/CAL. Next action is coordinating connection details with Joachim.

---

## Current Status

### ✅ Completed
- [x] Initial assessment and environment gap analysis - [Assessment](oracle-dev-abn-uat-instances-for-branch-1060.md)
- [x] Chat with Joachim Schreiner on current TMS DB migration process (2026-04-10)
- [x] Joachim's feedback on Oracle pipeline and ABN 1060 provisioning (2026-04-10) - [Feedback](../../00_Meetings/2026-04-10_Joachim_Prozess_Postgres-to-Oracle/joachim_addition.md)
- [x] Corrected gap assumption -- Oracle pipeline already exists (ENT → ABN → UAT)
- [x] Updated exploration document to reflect corrected understanding

### 🔄 In Progress
- [ ] ORA-ABN-1060 being provisioned by Nagel/CAL (Joachim, Bernd Friedewald, Thomas Paulus)

### ⏳ Next Up
- Obtain ORA-ABN-1060 connection details (host, port, credentials, network)
- Configure TMS Bridge to connect to ORA-ABN-1060
- Configure New Dispo Backend TEST environment for Oracle
- Run first end-to-end integration test (Frontend → Backend → TMS Bridge → ORA-ABN-1060)
- Define sign-off criteria for ABN and UAT on the New Dispo side
- TMS Pulse load test against ORA-ABN-1060
- Test character encoding (UTF-8 vs. Oracle legacy charset) with real 1060 data

### 🔴 Blockers
- None -- previous blockers resolved by Joachim's feedback

---

## Project Steps

Each step is documented as a sub-page:

| Step | Title | Status | Document |
|------|-------|--------|----------|
| 1 | Environment Assessment (corrected by Joachim's feedback) | ✅ Complete | [Assessment](oracle-dev-abn-uat-instances-for-branch-1060.md), [Joachim's Feedback](../../00_Meetings/2026-04-10_Joachim_Prozess_Postgres-to-Oracle/joachim_addition.md) |
| 2 | Connect New Dispo to ORA-ABN-1060 | ⏳ Pending | TBD |
| 3 | End-to-End Integration Validation | ⏳ Pending | TBD |
| 4 | TMS Pulse Load Test & Sign-Off Criteria | ⏳ Pending | TBD |

---

## Timeline

| Phase | Period | Status | Key Activities |
|-------|--------|--------|----------------|
| Assessment | 2026-04-10 | ✅ | Gap analysis, Joachim consultation, gap assumption corrected |
| Provisioning | 2026-04-10 (started) | 🔄 | Nagel/CAL provisioning ORA-ABN-1060 (already in progress) |
| Configuration | TBD | ⏳ | TMS Bridge + Backend config for ORA-ABN-1060 |
| Validation | TBD | ⏳ | End-to-end integration test, TMS Pulse load test |
| Sign-Off | TBD | ⏳ | ABN: Patrick & Max → UAT: Max Beisheim & Patrick U. |

---

## Team & Stakeholders

### Nagel / CAL
- **Joachim Schreiner** - TMS Database Lead, Oracle wrapper migration, ENT1 development
- **Bernd Friedewald** - Involved in ABN 1060 provisioning decision
- **Thomas Paulus** - Involved in ABN 1060 provisioning decision
- **Patrick Uschmann** - Product Owner (New Dispo), ABN + UAT sign-off
- **Max Beisheim** - UAT sign-off

### P3
- **Matthias Max** - Architect
- **Maximilian Kehder** - Techn. Product Owner

---

## Related Documentation

### Project Steps
- [Step 1: Environment Assessment (corrected by Joachim's feedback)](oracle-dev-abn-uat-instances-for-branch-1060.md)

### External References
- [Azure DevOps CALtms Repo](https://dev.azure.com/caldevops/Agile/_git/CALtms) - TMS Database code (Oracle wrappers)
- [Azure DevOps Work Item #172451](https://dev.azure.com/caldevops/Agile) - NewDispo: Wrapper-Migration from PGS to ORA

### Related Projects
- [Oracle CDC Solution for TMS Branch Databases](../2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off/PROJECT-STATUS.md)

---

## Communication

### Meeting History
- **2026-04-10:** Chat with Joachim Schreiner - TMS DB migration process, ENT1 limitations, central DB conflict concern
- **2026-04-10:** Joachim's written feedback - Oracle pipeline confirmed (ENT → ABN → UAT), ABN 1060 provisioning initiated with Bernd Friedewald and Thomas Paulus

---

## Context & Dependencies

### Business Context
- P3 branches are transitioning from Postgres to Oracle TMS
- June 2026 target for Oracle CDC go-live
- TMS Pulse requires realistic load testing before Oracle branches go live

### Technical Dependencies
- ORA-ABN-1060 availability (being provisioned by Nagel/CAL)
- Connection details for TMS Bridge configuration
- TMS Oracle deployment pipeline (QS tool + CLI) for wrapper procedure rollout

### Risk Areas
- **Character encoding:** Known UTF-8 vs. Oracle legacy charset issues (Poland corruption incident) -- now testable in ABN 1060
- **Wrapper edge cases:** Real 1060 data patterns may reveal issues not caught in ENT1 -- ABN 1060 mitigates this
- **New Dispo ↔ Oracle integration gaps:** First end-to-end test will reveal these -- schedule early

---

## Project Health Indicators

| Indicator | Status | Notes |
|-----------|--------|-------|
| **Schedule** | 🟢 | ABN 1060 provisioning already started |
| **Scope** | 🟢 | Shifted from "propose new instances" to "connect to existing pipeline" |
| **Resources** | 🟢 | Nagel/CAL handling provisioning; P3 handles config |
| **Risks** | 🟡 | Character encoding and wrapper edge cases -- testable once ABN 1060 is available |
| **Blockers** | 🟢 | None -- previous blockers resolved |

**Legend:** 🟢 Good | 🟡 Attention Needed | 🔴 Critical

---

## Change Log

| Date | Update | Updated By |
|------|--------|------------|
| 2026-04-10 | Project created, Step 1 (Assessment) completed | Matthias Max |
| 2026-04-10 | Gap assumption corrected: Oracle pipeline already exists. Joachim confirmed ABN 1060 being provisioned with live data. Document rewritten. Blockers cleared. Next steps shifted to New Dispo integration. | Matthias Max |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub><br>
  <sub>Living document - updates automatically as project progresses</sub>
</div>
