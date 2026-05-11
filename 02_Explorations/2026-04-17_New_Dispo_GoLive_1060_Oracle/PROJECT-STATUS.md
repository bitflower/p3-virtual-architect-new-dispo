# Project: GoLive 1060 (Oracle)

**Status:** 🔄 In Progress
**Author:** Matthias Max
**Last Updated:** 2026-05-11
**Next Milestone:** End-to-end integration test (ABN 1060) — Frontend -> Backend -> TMS Bridge -> ORA-ABN-1060
**Target Date:** June 2026

---

## Quick Overview

**Problem:** Branch 1060 needs to go live on Oracle TMS via the New Dispo platform. This requires infrastructure provisioning, Oracle database configuration, CDC pipeline setup (Striim), end-to-end testing, and sign-off across ABN, UAT, and PROD environments.

**Solution Approach:** Phased rollout — ABN testing first, then UAT sign-off, then production go-live. Striim for Oracle CDC (decided 2026-04-28). All GCP infrastructure (WL4/WL5) and Oracle environments must be provisioned and connected.

**Go-Live Gate:** ABN sign-off (Patrick U., Max K.) -> UAT sign-off (Max Beisheim, Patrick U.) -> Production

**Related Work Items:**
- [GoLive 1060 Documentation](new-dispo-golive-1060-oracle.md) (holistic architecture & environment reference)
- [Oracle Testing Project](../../WIKI/Nagel-CAL-Disposition.wiki/Projects/Active/Oracle-Testing.md)

---

## Current Status

### ✅ Completed

- [x] **ORA-ABN-1060 provisioned** — DB objects deployed by Eric (2026-05-01)
- [x] **ORA-ABN-1060 connection details obtained** — TMSBR1060 user provisioned by Eric (2026-05-01)
- [x] **Oracle deployment pipeline operational** — ENT -> ABN -> UAT -> PROD (Joachim, QS tool)
- [x] **TMSBR1060 secret created in WL5-T-T** — Secret Manager entry for Oracle connection (2026-05-01)
- [x] **Oracle view conversion completed** — Andrej submitted PR 2026-04-27, 30-char naming convention resolved
- [x] **Postgres view naming convention aligned** — Sonja implemented shortened names matching Oracle convention
- [x] **CDC target bucket provisioned** — `wl5-cdc-bucket-abn1060` created by Nikolay (2026-05-07)
- [x] **Striim CDC solution decided** — April 28 meeting: Striim for go-live, Binary Log Reader as parallel post-go-live track
- [x] **Striim license extended** — Until October 2026 (Matt Wilkinson, 2026-04-24)
- [x] **Keycloak connected to Enterprise ID** — Groups restrict access to dispositions; testers added to 1060 group
- [x] **LiquiBase licenses purchased** — Automated Oracle deployment pipeline setup starting (2026-05-07)
- [x] **Patrick test access** — Patrick Uschmann has access to test environment 1060 via DVM link (2026-05-07)
- [x] **Database user strategy decided** — Separate users for CDC (log mining) vs. application (TMS Bridge), per Eric Meijers. Branch-specific usernames required
- [x] **Packet loss GCP <-> Nagel on-prem** — Managed by Telekom/Arista, monitoring in place (resolved 2026-04-20)
- [x] **Network/VPN verification** — `oracle-user` tag grants access to 1060 from GCP (verified)
- [x] **Oracle CDC pipeline connected** — Striim connected to `wl5-cdc-bucket-abn1060`

### 🔄 In Progress

- [ ] **Oracle ENT1 schema development** — Wrapper procedures for 1060 (Owner: Joachim Schreiner)
- [ ] **TMS Bridge config for ORA-ABN-1060** — Secret created in WL5-T-T; WL4-T-T TBC (Owner: P3, Matthias/Max K.)
- [ ] **Backend TEST env config for Oracle** — Blocked by TMS Bridge config (Owner: P3, Matthias/Max K.)
- [ ] **GCP Secret Manager: WL4-T-T Oracle secrets** — WL5-T-T done, WL4-T-T still pending (Owner: P3 / CAL Infra)
- [ ] **DB user permissions: TMSBR with write privileges** — QM user is read-only, need TMSBR user for New Dispo write operations. Secret name prefixing solution decided (2026-05-07) (Owner: P3)
- [ ] **LiquiBase infrastructure setup** — Setup this week, deployment process starting next week (Owner: Matt Wilkinson / Nagel)
- [ ] **Striim event format mapping** — Assess Striim output format vs. Datastream for TMS Pulse integration (Owner: Matthias Max)
- [ ] **Striim stream user configuration documentation** — Matt Wilkinson to document stream user config (differs from Datastream setup) (Owner: Matt Wilkinson)
- [ ] **Infrastructure skeleton check** — Verify all GCP infra (Cloud Run, buckets, pipelines) exists for all environments. Fill gaps (Owner: Nikolay / P3 team)
- [ ] **Keycloak authentication documentation** — Ron set up Enterprise ID integration; documentation needed for security reviews (Owner: Ron / Matt Wilkinson)

### ⏳ Next Up

- End-to-end integration test (ABN 1060): Frontend -> Backend -> TMS Bridge -> ORA-ABN-1060
- Dispo Filter function instance for 1060 CDC
- Pub/Sub topic `WL5_CDC_TOPIC_1060`
- TMS Pulse load test against ABN 1060
- ABN sign-off (Patrick U., Max K.) — gate to UAT
- Provision ORA-UAT-1060 (after ABN sign-off)
- UAT sign-off (Max Beisheim, Patrick U.) — gate to PROD
- Keycloak and user access design documentation (Nagel waiting for P3)
- Pipeline testing to Production WL4 (verify CI/CD deploys to Prod)
- Clarify application access methods per environment (Citrix for UAT, Cameyo for ABN, direct in Nuremberg)

### 🔴 Blockers

1. **ABN1060 Oracle database gaps** — Packages deployed but gaps identified: missing objects, column mismatches, queue infrastructure issues. See [ABN1060 Database Review](../2026-05-11_ABN1060_Oracle_TMS_Database_Review_-_First_Batch_Analysis/abn1060-oracle-tms-database-review---first-batch-analysis.md)

---

## Timeline

| Phase | Period | Status | Key Activities |
|-------|--------|--------|----------------|
| Infrastructure Provisioning | April 2026 | ✅ Complete | ABN1060 provisioned, connection details, secrets |
| Oracle Conversion | March - April 2026 | ✅ Complete | Wrapper procedures, view conversion, 30-char naming |
| CDC Decision | March - April 2026 | ✅ Complete | Striim selected (Apr 28), Binary Log Reader parallel track |
| ABN Configuration | May 2026 | 🔄 In Progress | TMS Bridge config, secrets, network verification, DB users |
| E2E Integration Testing | May 2026 | ⏳ Planned | Full stack testing against ORA-ABN-1060 |
| ABN Sign-Off | May/June 2026 | ⏳ Planned | Patrick U., Max K. (P3) |
| UAT Provisioning & Testing | June 2026 | ⏳ Planned | ORA-UAT-1060 provisioning, TMS Pulse load test |
| UAT Sign-Off | June 2026 | ⏳ Planned | Max Beisheim, Patrick U. (Nagel) |
| Go-Live 1060 | June 2026 | 🎯 Target | Production deployment |

---

## Team & Stakeholders

### P3 Team
- **Matthias Max** - Enterprise Architect, Technical Lead, GCP Infrastructure
- **Martin Dittmann** - Project Manager, Coordination
- **Maximilian Kehder** - Product Owner
- **Nikolay Hristov** - DevOps Engineer, GCP Infrastructure
- **Yosif Mihaylov** - Lead Developer (Backend)
- **Boyan Valchev** - Lead Developer (Frontend)
- **Sonja Petkovic** - Postgres Developer

### Nagel/CAL Team
- **Christian Lang** - CEO Nagel IT, Decision Authority
- **Patrick Uschmann** - Product Owner
- **Max Beisheim** - UAT Sign-Off Authority
- **Matt Wilkinson** - Infrastructure Lead, Striim, Google Escalation
- **Ron Vervenne** - Cloud Engineer, Infrastructure Platform, VDI Access
- **Joachim Schreiner** - Oracle/Postgres Developer, ENT1 Schema
- **Bernd Friedewald** - Oracle Instance Provisioning
- **Thomas Paulus** - TMS Database Developer
- **Eric Meijers** - Cloud Engineer, DBA Support, User Permissions
- **Andrej Chernov** - Oracle Developer, View/Package Conversion
- **Robert Zanter** - Oracle DBA

---

## Related Documentation

### Architecture & Infrastructure
- [GoLive 1060 Documentation](new-dispo-golive-1060-oracle.md) — Holistic architecture, environment mapping, ownership matrix
- [TMS Bridge Database Objects](../2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md)
- [Oracle Environment Assessment](../2026-04-10_Oracle_DEV_ABN_UAT_Instances_for_Branch_1060/)

### Decisions
- [ADR-006: Oracle CDC Solution Selection](../../09_ADRs/ADR-006-oracle-cdc-solution-selection/ADR-006-oracle-cdc-solution-selection.md) — Striim accepted
- [ADR-004: DB Identifier Convention](../../09_ADRs/ADR-004-tms-bridge-database-identifier/)
- [ADR-008: WL4-T-T for Development](../../09_ADRs/ADR-008-wl4-dev-unavailable-use-wl4-tt/)

### External
- [Oracle Migration Tracker (SharePoint)](https://nagelgroup-my.sharepoint.com/:x:/r/personal/x_matt_wilkinson_nagel-group_com/Documents/Anlagen/Dispo_POSTGRES_Oracle_Tracker%201.xlsx?d=weae5c4954eab449a8cff3bc20eee1b26&csf=1&web=1&e=v4o4Cx)

---

## Communication

### Meeting History
- **2026-05-07:** Follow-Up Oracle CDC — CDC bucket provisioned, LiquiBase purchased, data desync issue discovered, DB user write privileges needed
- **2026-05-05:** Follow-Up Oracle CDC — TMSBR_1060 secret created, May 19 deadline discussed, proposal to rename meeting to "GoLive 1060"
- **2026-04-28:** Follow-Up Oracle CDC — Striim decided for go-live, Oracle conversion completed, Keycloak confirmed connected
- **2026-04-24:** Go-Live 1060 Status Email (Matt Wilkinson) — Binary Log Reader set up, Striim license extended, 30-char naming fix

### Discussion Channels
- **Weekly Sync:** Recurring meeting established (Patrick Uschmann)

**Have questions?** Contact Matthias or Martin.

---

## Project Health Indicators

| Indicator | Status | Notes |
|-----------|--------|-------|
| **Schedule** | 🟡 | June go-live target; many in-progress items |
| **Scope** | 🟡 | WL4-T-T secrets/config still pending; TMSBR write access unresolved; Dispo Filter + Pub/Sub for CDC not provisioned; CI/CD to Prod WL4 unverified; Keycloak user access design undefined; ABN1060 DB gaps under review |
| **Resources** | 🟢 | Teams assigned across P3 and Nagel |
| **Risks** | 🟡 | ABN1060 DB gaps blocking E2E testing; Striim event format compatibility untested |
| **Blockers** | 🟡 | ABN1060 DB gaps (missing objects, column mismatches, queue infrastructure) |

**Legend:** 🟢 Good | 🟡 Attention Needed | 🔴 Critical

---

## Change Log

| Date | Update | Updated By |
|------|--------|------------|
| 2026-05-11 | Project created. Consolidated from GoLive 1060 exploration doc and GoLive-related items migrated from Oracle CDC project (which is now closed — Striim decided). Status seeded from meetings Apr 28, May 5, May 7 | Matthias Max |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub><br>
  <sub>Living document - updates automatically as project progresses</sub>
</div>
