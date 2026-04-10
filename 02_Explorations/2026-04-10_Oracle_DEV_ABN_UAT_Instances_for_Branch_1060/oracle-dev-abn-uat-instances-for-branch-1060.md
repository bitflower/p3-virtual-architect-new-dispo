# Oracle Test Environments for Branch 1060 -- Why We Need Them Now

**Date:** 2026-04-10
**Status:** Proposal
**Audience:** Patrick Uschmann (Product Owner, New Dispo)
**Author:** Matthias Max (Virtual Architect)

---

<!-- <internal> -->
## Original User Input

> Prepare a document to convince the Product Owner of New Dispo to support the creation of proper DEV, ABN and UAT Oracle instances that contain (at least time-cut-off) data of branch 1060. Currently the TMS Database developers are working on their ENT1 instance and in the Azure repos.
<!-- </internal> -->

---

## TL;DR

The New Dispo Oracle migration is being developed and tested **blindly** -- on an empty ENT1 instance with no real branch data. Before any Oracle-connected branch can go live, we need Oracle DEV, ABN, and UAT environments with 1060 data. DEV needs at minimum a snapshot; ABN and UAT need **flowing production data** to enable TMS Pulse load testing and real business feature validation. Without them, we are **guaranteed to discover integration bugs in production**.

---

## The Problem

### Today's Postgres World (Working Well)

The New Dispo system has a proper environment pipeline for Postgres branches:

```
DEV (ENT*) --> TEST (ABN*) --> STAGING (UAT*) --> PROD (TMS*)
```

Where `*` is the branch indicator (e.g. 1034, 1060, 2820). Each stage has **real branch data**, allowing us to catch data-dependent bugs before they reach production.

### Today's Oracle World (Gap)

```
ENT1 (empty, no branch data) --> ??? --> PROD (Oracle branch, e.g. 1060)
```

The TMS Database team:
- Develops Oracle wrapper migrations in **ENT1** -- an independent test instance with **no connection to any live branch**
- Stores code in **Azure DevOps** (`CALtms` repo, `/SQL` folder)
- Deploys via **Change Sets** -- a manual process used for 30+ years
- Has **no environment pipeline** that mirrors the New Dispo Postgres setup

### What This Means

| Concern | Impact |
|---|---|
| **No real data to test against** | Wrapper procedures (e.g. `p05_TransportOrder.sp`) are tested against empty tables. Edge cases in 1060's actual data (NULLs, encoding, legacy records) will only surface in production. |
| **No integration testing possible** | The New Dispo Backend/Bridge cannot be pointed at an Oracle test instance with realistic data. The first real integration test happens in production. |
| **No ABN/UAT gate** | There is no acceptance or user-acceptance environment for Oracle. Stakeholders cannot validate before go-live. |
| **Character set issues undetectable** | Known UTF-8 vs. Oracle legacy charset problems (already causing corruption in Poland) cannot be tested without real data. |
| **TMS Pulse untestable** | TMS Pulse load testing requires realistic, flowing production data. Without it, performance and scalability issues will only surface in production. |

---

## The Proposal

### Create Three Oracle Instances for Branch 1060

| Instance | Purpose | Data Strategy |
|---|---|---|
| **ORA-DEV-1060** | Development & debugging | Time-cutoff snapshot of 1060 (refreshed periodically) |
| **ORA-ABN-1060** | Acceptance testing, TMS Pulse load testing | **Flowing PROD data** from 1060 |
| **ORA-UAT-1060** | User acceptance testing, business feature validation | Time-cutoff snapshot + potentially **PROD data flowing in for a defined period** (e.g. 1-2 weeks) |

### Key Design Decisions

**DEV: Isolated with snapshot data.** ORA-DEV-1060 does NOT participate in inter-branch data exchange. A time-cutoff snapshot provides a stable, reproducible baseline for development and debugging.

**ABN & UAT: Fed with production data.** ORA-ABN-1060 and ORA-UAT-1060 need **live production data flowing in** from branch 1060. This is essential for two reasons:

1. **TMS Pulse load testing** -- TMS Pulse can only be meaningfully load-tested against realistic, continuously changing production data volumes and patterns. Static snapshots cannot simulate real operational load.
2. **Business feature edge-case coverage** -- Production data contains the full spectrum of edge cases (encoding quirks, NULL patterns, legacy records, concurrent updates) that static snapshots miss over time. ABN and UAT must reflect current production reality to catch regressions.

```
                              +-- ORA-DEV-1060  (isolated, snapshot data)
                              |
1060 PROD  --snapshot---------+
           |
           +--flowing data----+-- ORA-ABN-1060  (PROD data feed, load testing)
                              |
                              +-- ORA-UAT-1060  (PROD data feed, UAT validation)
```

**Addressing Joachim's conflict concern:** ABN and UAT receive data **inbound only** (read-replica / one-way feed from PROD 1060). They do not write back or participate in inter-branch data exchange, so there is no conflict between PGS1060 and ORA1060.

---

## What We Gain

### 1. Proper Integration Testing

```
New Dispo Frontend
       |
New Dispo Backend
       |
TMS Bridge  ------>  ORA-ABN-1060   (instead of: ??? or ENT1 with no data)
```

The TMS Bridge wrapper procedures can be validated end-to-end with real data before any production deployment.

### 2. Validated Migration Path

The active Azure DevOps work item **#172451 "NewDispo: Wrapper-Migration from PGS to ORA"** includes migrations for:
- `p05_TransportOrder.sp`
- `p05_TransportOrderItem.sp`
- `p05_Shipment.sp`
- `p05_Driver.sp`
- ... and more

Each of these wrappers translates between New Dispo's expectations and Oracle's schema. Testing them against empty tables proves nothing -- we need 1060's actual data.

### 3. Environment Parity with Postgres

| Stage | Postgres (today) | Oracle (proposed) |
|---|---|---|
| DEV | ENT1060 | ORA-DEV-1060 |
| TEST | ABN1060 | ORA-ABN-1060 |
| STAGING | UAT1060 | ORA-UAT-1060 |

### 4. Oracle CDC Validation

The Oracle CDC POC (Striim/Datastream) has already used 1060 for testing. Having dedicated Oracle test instances means the CDC pipeline can be validated end-to-end in a non-production environment.

---

## Addressing Concerns

### "Isn't ENT1 enough?"

No. ENT1 is valuable for **schema development**, but it has:
- No branch-specific data or configuration
- No representative data volumes
- No connection to the New Dispo test pipeline

ENT1 answers: "Does the SQL compile?" The proposed environments answer: "Does the system work with real data?"

### "Won't this conflict with existing branches?"

No. DEV is completely isolated. ABN and UAT receive a **one-way data feed** from PROD 1060 -- they do not write back or participate in inter-branch data exchange. No conflict between PGS1060 and ORA1060.

### "Why not just snapshots for all three?"

A snapshot is sufficient for **DEV** (stable baseline for development). But ABN and UAT serve different purposes:

- **TMS Pulse load testing** requires realistic, continuously flowing production data -- a static snapshot cannot simulate real operational load patterns.
- **Business feature validation** must cover the full spectrum of production edge cases. Data patterns evolve over time; a stale snapshot misses new edge cases that emerge in production.

The two-tier model (snapshot for DEV, flowing data for ABN/UAT) balances cost against test fidelity.

### "What's the effort?"

| Step | Owner | Effort |
|---|---|---|
| Provision 3 Oracle instances | Nagel / CAL Infrastructure | Standard provisioning |
| Export 1060 snapshot for DEV | DBA / Joachim's team | One-time, low effort |
| Set up PROD data feed for ABN & UAT | DBA / Nagel Infrastructure | Replication / data pump setup |
| Configure New Dispo TEST to point at ORA-ABN-1060 | New Dispo team | Config change |
| Refresh DEV snapshot periodically | DBA | Low effort, as needed |

The provisioning effort is **manageable**. The PROD data feed for ABN/UAT adds some setup complexity but is essential -- the risk of NOT doing it is **large and ongoing**.

---

## Risk Without These Environments

```
Without:   DEV -----> PROD  (hope for the best)
                      ^^^^
                      First time real Oracle data meets New Dispo code

With:      DEV -> ABN -> UAT -> PROD  (validated at every stage)
```

**Concrete risks if we skip this:**
1. Wrapper procedures fail on production data patterns not present in ENT1
2. Character encoding issues (already seen in Poland) crash or corrupt data
3. Performance problems with real data volumes only discovered under production load
4. No stakeholder sign-off possible before go-live -- pure trust-based deployment
5. Production rollback required, impacting branch 1060 operations

---

## Recommended Next Steps

1. **PO Decision**: Approve provisioning of three Oracle 1060 instances
2. **Infrastructure**: Nagel/CAL provisions ORA-DEV-1060, ORA-ABN-1060, ORA-UAT-1060
3. **DEV Setup**: Coordinate with Joachim for 1060 snapshot export into ORA-DEV-1060
4. **ABN/UAT Data Feed**: Set up one-way PROD data replication into ORA-ABN-1060 and ORA-UAT-1060
5. **Configure**: Point New Dispo test environments at the new Oracle instances
6. **Validate**: Run first end-to-end integration test + TMS Pulse load test with real Oracle 1060 data

---

## Pending Feedback

- [ ] **Impact of missing central DB link (awaiting Joachim):** The proposed test instances would not be connected to the central database. Joachim's assessment on how this affects testing possibilities and quality is outstanding. His feedback may change the data strategy for ABN/UAT or require additional measures to compensate for the missing inter-branch data exchange.

---

## Open Questions

- [ ] **TMS Dev merge process**: How exactly do Change Sets from Azure DevOps (`CALtms/SQL`) get deployed to target Oracle instances? Is there a CI/CD pipeline or is it manual?
- [x] **Instance provisioning ownership**: Nagel/CAL responsibility (not P3)
- [ ] **DEV snapshot refresh cadence**: How often should the DEV snapshot be refreshed? (Recommendation: quarterly or before major releases)
- [ ] **PROD data feed mechanism**: What replication mechanism for ABN/UAT? (Oracle Data Guard, GoldenGate, Data Pump scheduled exports, or other?)
- [ ] **Oracle CDC test integration**: Should the CDC pipeline (Striim/Datastream) also be connected to these test instances?

---

## Related Files

- [Chat with Joachim (2026-04-10)](../../00_Meetings/2026-04-10_Joachim_Prozess_Postgres-to-Oracle/chat.md)
- [Azure DevOps CALtms Repo](https://dev.azure.com/caldevops/Agile/_git/CALtms)
- [Oracle CDC POC Status](../../02_Explorations/2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off/PROJECT-STATUS.md)
- [Environments Wiki](../../WIKI/Nagel-CAL-Disposition.wiki/Devops/Environments.md)
