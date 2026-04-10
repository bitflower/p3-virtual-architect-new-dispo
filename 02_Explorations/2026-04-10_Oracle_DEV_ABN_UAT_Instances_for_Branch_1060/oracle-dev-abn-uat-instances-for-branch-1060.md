# Oracle Test Environments for Branch 1060 -- Plugging New Dispo Into the Existing Pipeline

**Date:** 2026-04-10
**Status:** Updated -- gap assumption corrected
**Audience:** Patrick Uschmann (Product Owner, New Dispo)
**Author:** Matthias Max (Virtual Architect)

---

<!-- <internal> -->
## Original User Input

> Prepare a document to convince the Product Owner of New Dispo to support the creation of proper DEV, ABN and UAT Oracle instances that contain (at least time-cut-off) data of branch 1060. Currently the TMS Database developers are working on their ENT1 instance and in the Azure repos.

## Correction (2026-04-10, same day)

Joachim Schreiner's [feedback](../../00_Meetings/2026-04-10_Joachim_Prozess_Postgres-to-Oracle/joachim_addition.md) revealed that **the TMS Oracle side already has an environment pipeline (ENT → ABN → UAT) with a structured deployment process**. The original document assumed this pipeline did not exist. The document has been rewritten to reflect the corrected understanding.
<!-- </internal> -->

---

## TL;DR

~~We assumed Oracle had no environment pipeline for branch 1060. That was wrong.~~ Joachim confirmed that the TMS Oracle side **already operates an ENT → ABN → UAT pipeline** with a structured deployment process (QS tool + CLI-based rollout). ABN 1060 is **already being provisioned** with live production data (coordinated with Bernd Friedewald and Thomas Paulus). UAT 1060 follows after ABN acceptance.

**What remains:** connecting the New Dispo stack (Frontend → Backend → TMS Bridge) to these Oracle test instances so we get proper end-to-end integration testing before production go-live.

---

## What We Originally Assumed (Wrong)

Our initial assessment described a gap:

```
ENT1 (empty, no branch data) --> ??? --> PROD
```

We assumed the TMS Oracle side had no environment pipeline, no structured deployment, and no plan for branch-specific test instances. This led to a proposal to create three new Oracle instances from scratch.

**This assumption was incorrect.**

---

## What Actually Exists (Joachim's Feedback, 2026-04-10)

Joachim discussed the situation with Bernd Friedewald and Thomas Paulus and confirmed the following:

### The Oracle Environment Pipeline Already Exists

```
ENT (development & unit testing)
 |
 |  QS tool creates version + 2 CLI calls deploy to all ENT and ABN branches
 v
ABN (acceptance testing, live production data)
 |
 |  After sign-off
 v
UAT (customer acceptance testing)
 |
 |  After sign-off
 v
PROD
```

### Branch 1060 Is Already Being Set Up

| Environment | Status | Data | Who Tests |
|---|---|---|---|
| **ENT1** | Active | No branch-specific data (schema dev only) | Joachim |
| **ABN 1060** | **Being provisioned** | **Live production data from 1060** | Matthias, Max (P3) |
| **UAT 1060** | In pipeline | Production data | Max Beisheim, Patrick U. |

### The Deployment Process Is Structured

The process is **not** just manual Change Sets as we initially understood:

1. Developers develop and test in an ENT branch (currently ENT1)
2. Changes are checked into the [Azure DevOps repo](https://dev.azure.com/caldevops/Agile/_git/CALtms) (`CALtms/SQL`)
3. A **QS tool** creates a versioned release with a list of changed DB objects
4. **Two CLI calls** deploy that version to all other ENT branches and all ABN branches
5. After P3 sign-off in ABN, the version is deployed to UAT
6. After PO sign-off in UAT, the version goes to PROD

This is a proper, traceable deployment pipeline -- not the ad-hoc process we assumed.

---

## What Was Wrong in Our Original Assessment

| Original claim | Corrected reality |
|---|---|
| "No environment pipeline for Oracle" | Pipeline exists: ENT → ABN → UAT → PROD |
| "Need to propose creating 3 new instances" | ABN 1060 already being provisioned; UAT 1060 follows |
| "Deploys via Change Sets -- manual, 30 years old" | QS tool + 2 CLI calls; structured, versioned, traceable |
| "No real data to test against" | ABN 1060 will have live production data |
| "First real integration test happens in production" | ABN provides pre-production testing with real data |
| "No stakeholder sign-off possible before go-live" | UAT is exactly that sign-off stage (Patrick U., Max Beisheim) |

---

## What the Pipeline Looks Like for New Dispo

With ABN 1060 and UAT 1060 in place, the full integration test path becomes:

```
New Dispo Frontend
       |
New Dispo Backend
       |
TMS Bridge  ------>  ORA-ABN-1060   (live 1060 data, wrapper validation)
                         |
                     Sign-off by Patrick & Max
                         |
                     ORA-UAT-1060   (customer acceptance)
                         |
                     Sign-off by Max Beisheim & Patrick U.
                         |
                     PROD
```

This mirrors the Postgres pipeline:

| Stage | Postgres | Oracle |
|---|---|---|
| DEV | ENT1060 | ENT1 (shared, schema dev) |
| TEST / Acceptance | ABN1060 | ABN 1060 (live data, **being provisioned**) |
| Staging / UAT | UAT1060 | UAT 1060 (after ABN sign-off) |

> **Note:** ENT is not branch-specific on the Oracle side -- Joachim uses ENT1 for all schema development. This is a minor difference from Postgres but acceptable since ENT is for compilation/unit testing, not data validation.

---

## Remaining Work -- What P3 / New Dispo Needs to Do

The TMS Oracle side is handling environment provisioning and the deployment pipeline. What remains is **connecting the New Dispo stack** to these environments:

### 1. Configure New Dispo Backend/Bridge to Point at ORA-ABN-1060

The TMS Bridge needs a connection configuration for ORA-ABN-1060. This is a config change on the New Dispo side (connection string, credentials, environment routing).

| Action | Owner | Effort |
|---|---|---|
| Obtain ORA-ABN-1060 connection details | Joachim / Nagel Infrastructure | Coordination |
| Configure TMS Bridge for ORA-ABN-1060 | New Dispo team (P3) | Config change |
| Configure New Dispo Backend TEST environment | New Dispo team (P3) | Config change |

### 2. Validate Wrapper Procedures End-to-End

Once connected, run the first end-to-end test through the New Dispo stack against ORA-ABN-1060:

- Frontend → Backend → TMS Bridge → ORA-ABN-1060
- Validate wrapper procedures (`p05_TransportOrder.sp`, `p05_TransportOrderItem.sp`, etc.) with real 1060 data
- Verify character encoding (UTF-8 vs. Oracle legacy charset -- the Poland issue)

### 3. TMS Pulse Load Testing

ABN 1060 with live production data enables meaningful TMS Pulse load testing. This was a key concern and is now addressed by the existing pipeline.

### 4. Establish Sign-Off Process

Joachim's process already includes sign-off gates:

- **ABN 1060:** Patrick and Max validate → give OK
- **UAT 1060:** Max Beisheim and Patrick U. validate → give OK for PROD

P3 needs to define what "OK" means for the New Dispo side -- what tests must pass, what scenarios must be validated.

---

## Remaining Risks

The pipeline existence resolves the biggest risks. What remains:

| Risk | Mitigation |
|---|---|
| **Character encoding issues** (UTF-8 vs. Oracle legacy charset) | Test explicitly in ABN 1060 with Polish/special-char data. Now possible with real data. |
| **Wrapper edge cases** on real data patterns | ABN 1060 has live production data -- edge cases will surface here, not in PROD. |
| **New Dispo ↔ Oracle integration gaps** | First end-to-end test in ABN 1060 will reveal these. Schedule this early. |
| **ENT1 has no branch-specific data** | Acceptable -- ENT is for schema/compilation. Data validation happens in ABN. |

---

## Recommended Next Steps

1. **Coordinate with Joachim** on ORA-ABN-1060 availability timeline and connection details
2. **Configure TMS Bridge** to connect to ORA-ABN-1060 in the New Dispo TEST environment
3. **Run first end-to-end integration test** through Frontend → Backend → TMS Bridge → ORA-ABN-1060
4. **Define sign-off criteria** for ABN and UAT on the New Dispo side
5. **Schedule TMS Pulse load test** against ORA-ABN-1060 once connection is established
6. **Test character encoding** explicitly with Polish/special-character data in ABN 1060

---

## Open Questions

- [x] ~~**TMS Dev merge process**: How exactly do Change Sets get deployed?~~ → QS tool + 2 CLI calls, versioned, traceable
- [x] **Instance provisioning ownership**: Nagel/CAL responsibility (confirmed)
- [x] ~~**Does Oracle have an environment pipeline?**~~ → Yes: ENT → ABN → UAT → PROD
- [x] ~~**Impact of missing central DB link**~~ → ABN 1060 receives live production data; no central DB link issue
- [ ] **ORA-ABN-1060 availability date**: When will the instance be ready for New Dispo integration testing?
- [ ] **Connection details for ORA-ABN-1060**: Host, port, credentials, VPN/network requirements for TMS Bridge
- [ ] **Sign-off criteria**: What must pass in ABN/UAT before PROD deployment?
- [ ] **Oracle CDC test integration**: Should the CDC pipeline (Striim/Datastream) also be connected to ABN/UAT?

---

## Related Files

- [Chat with Joachim (2026-04-10)](../../00_Meetings/2026-04-10_Joachim_Prozess_Postgres-to-Oracle/chat.md)
- [Joachim's Feedback (2026-04-10)](../../00_Meetings/2026-04-10_Joachim_Prozess_Postgres-to-Oracle/joachim_addition.md)
- [Azure DevOps CALtms Repo](https://dev.azure.com/caldevops/Agile/_git/CALtms)
- [Oracle CDC POC Status](../../02_Explorations/2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off/PROJECT-STATUS.md)
- [Environments Wiki](../../WIKI/Nagel-CAL-Disposition.wiki/Devops/Environments.md)
