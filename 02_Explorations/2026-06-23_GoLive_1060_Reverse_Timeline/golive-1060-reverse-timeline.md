# GoLive 1060 Oracle -- Reverse Timeline

**Date:** 2026-06-23
**Status:** Active
**Source:** New Dispo Daily Sync 22.06.26 (2026-06-22)
**Companion:** [GoLive 1060 Oracle (main page)](../../02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/new-dispo-golive-1060-oracle.md) -- Section 9

---

## 1. Context

In the daily sync on 2026-06-22, the team discussed a **reverse-timeline** approach for the 1060 Oracle Go-Live: enumerate every technical step required before users can use the app in production, calculate backwards from that moment in days, and check whether the sequence fits the schedule. Each stakeholder was asked to contribute their steps.

This exploration captures the steps surfaced per person, constraints, dependencies, and gaps -- as input for refining Section 9 of the GoLive page.

---

## 2. Steps Surfaced Per Stakeholder

### 2.1 Matt Wilkinson (CAL Infra)

| # | Step | Est. Duration | Depends On | Notes |
|---|------|--------------|------------|-------|
| M1 | All GCP infrastructure up, running, tested, monitoring on | -- | -- | Precondition for any testing |
| M2 | Connectivity pipes verified (services talking to each other) | -- | M1 | Prod VPN, Cloud Run ↔ Oracle, Cloud Run ↔ TOP, ASB |
| M3 | Deploy latest patches (Oracle bug fixes + P3 code) into UAT | 1 day | ABN sign-off | "Monday after ABN week" |
| M4 | Deploy new TMS Bridge version to PROD | ~minutes outage | UAT sign-off | Impacts **EBV** -- outage coordination required |
| M5 | Alerting and monitoring setup for PROD | TBD | -- | **Open:** Who owns this? What tooling? |
| M6 | Run DB deployment checker script on PROD Oracle | <1 day | M4 | Verifies all objects visible to TMSBR1060 user |
| M7 | Coordinate with Nikolay on remaining infra tasks | TBD | -- | Nikolay likely has Keycloak/CDC items |

**Rough timeline proposed by Matt:**
- ABN done Friday June 27 → UAT deploy Monday June 30 → Patrick/Max Beisheim start UAT Tuesday July 1 → PROD deploy ~July 3–4

### 2.2 Joachim Schreiner (Oracle / Nagel)

| # | Step | Est. Duration | Depends On | Notes |
|---|------|--------------|------------|-------|
| J1 | Fix open ABN bugs (reproduction statements needed from P3) | This week | Boyan/P3 providing SQL statements | Blocker for everything downstream |
| J2 | All change sets pass QS tool | -- | J1 | Gatekeeper for environment promotion |
| J3 | Deploy patches to UAT (Oracle side) | Short | J2, ABN sign-off | **Constraint:** UAT is deployed *only immediately before PROD* |
| J4 | Final test on UAT | Short | J3 | Last gate before production |
| J5 | Deploy to PROD | Short | J4 | Pipeline: ENT → ABN → UAT → PROD (strict sequence) |

**Key constraint:** Joachim insists UAT must remain "patchable" -- if a critical bug appears outside KVN, they need an environment to create and test a patch. UAT should not be deployed early and then sit idle.

### 2.3 Maximilian Kehder (P3, Project Management)

| # | Step | Est. Duration | Depends On | Notes |
|---|------|--------------|------------|-------|
| K1 | ABN bugs resolved | Target: Thu June 26 | J1, Boyan/Joachim collaboration | Route calculation is the key blocker |
| K2 | ABN sign-off | After K1 | K1 | Gate to UAT |
| K3 | PROD deployment: same ownership as UAT | -- | -- | Assumption to confirm |

**Framing questions raised:**
1. What does "go-live" mean? (Definition)
2. What is expected to happen? (Scope)
3. What are the risks? (Risk assessment)

### 2.4 Christian Lang

| # | Step | Est. Duration | Depends On | Notes |
|---|------|--------------|------------|-------|
| C1 | **EBV impact assessment** on TMS Bridge PROD deployment | <1 day | -- | Check APM configuration: are EBV endpoints untouched? |
| C2a | *If EBV untouched:* Our call, no external coordination | -- | C1 → confirmed safe | -- |
| C2b | *If EBV impacted:* Full ABN cycle including external EBV testing party + communicated acceptance date | Days–weeks | C1 → impact found | Would significantly extend timeline |

**Definition:** "Go live means we are ready for productive users. That has to be the goal. Anything else is not a goal."

### 2.5 Boyan Valchev (P3, Developer)

| # | Step | Est. Duration | Depends On | Notes |
|---|------|--------------|------------|-------|
| B1 | CDC/Striim pipeline confirmed working for Oracle 1060 | Done | -- | ABN events caught and applied to UAT |
| B2 | CDC latency investigation (Datastream: ~2 min per event) | TBD | -- | Matt to look at Striim tuning |
| B3 | **P3 QA re-verification on UAT** (same test suite as ABN) | 2–3 days | UAT deployed, J3 | Before Patrick/Max Beisheim start business testing |
| B4 | QA confirms UAT = ABN (DB + code) | -- | B3 | Green light for business testing |

### 2.6 Patrick Uschmann (Nagel, Business)

| # | Step | Est. Duration | Depends On | Notes |
|---|------|--------------|------------|-------|
| P1 | Max Beisheim + Patrick deep check on UAT | TBD | B4 (QA green light) | First business users on UAT |
| P2 | If satisfied, open to ~7 users | -- | P1 | Initial user group for branch 1060 |
| P3 | Check Max Beisheim calendar for early July availability | -- | -- | Originally planned "next week" (now pushed) |

No preferred day for PROD deployment.

### 2.7 Nikolay Hristov / Ron Vervenne

| # | Step | Est. Duration | Depends On | Notes |
|---|------|--------------|------------|-------|
| N1 | Entra ID redirect URL for UAT Keycloak | Done (in-call) | Ron's fix | Was missing, Ron fixed it live |
| N2 | PROD Entra ID verification | Done | -- | Confirmed working |
| N3 | Debug "something wrong with UAT" | TBD | -- | Found at end of call, to investigate |
| N4 | Remaining Keycloak / CDC infra tasks | TBD | -- | Matt flagged Nikolay likely has items |

---

## 3. Dependency Graph (Simplified)

```
                        ABN Bug Fixes (J1, K1)
                              |
                        QS Approval (J2)
                              |
                        ABN Sign-Off (K2)
                       /              \
                      /                \
          Oracle Deploy to         GCP Deploy to
            UAT (J3)                 UAT (M3)
                      \                /
                       \              /
                    P3 QA on UAT (B3)
                           |
                    QA Green Light (B4)
                           |
                  Business Testing (P1)
                           |
                    UAT Sign-Off
                           |
              EBV Impact Assessment (C1)
                    /            \
            C2a: Safe         C2b: EBV Cycle
                 |                  |
          TMS Bridge PROD      External Testing
           Deploy (M4)          (adds weeks)
                 |                  |
          Oracle PROD              ...
           Deploy (J5)
                 |
         DB Checker (M6)
                 |
         Monitoring (M5)
                 |
         *** USERS START ***
```

---

## 4. Proposed Reverse Timeline

Working backwards from "Users start using New Dispo on PROD":

| Day | Calendar (est.) | Step | Owner | Risk |
|-----|----------------|------|-------|------|
| **D-0** | ~July 7 (Mon) | Users start using New Dispo (1060 PROD) | Patrick, Max Beisheim | -- |
| D-1 | July 4 (Fri) | Monitoring & alerting confirmed operational | Matt W., P3 | Low |
| D-1 | July 4 (Fri) | DB deployment checker script passes on PROD | Matt W. | Low |
| D-2 | July 3 (Thu) | Oracle deploy to PROD (J5) | Joachim | High: Classic Dispo potentially broken |
| D-2 | July 3 (Thu) | TMS Bridge deploy to PROD (M4) + outage coordination | Matt W., P3 | Medium: EBV outage |
| D-2 | July 3 (Thu) | GCP deploy to PROD (Frontend, Backend) | P3 | Low |
| **Gate** | | **EBV Impact Assessment (C1)** -- must be done before D-2 | Christian, Matthias | **Critical fork:** if EBV impacted, timeline extends significantly |
| **Gate** | | **UAT Sign-Off** | Patrick, Max Beisheim | -- |
| D-5 to D-3 | June 30 – July 2 | Business testing on UAT (P1) | Patrick, Max Beisheim | Low |
| D-7 to D-5 | June 28 – 30 | P3 QA re-verification on UAT (B3) | Boyan, Max K. | Low: verifying deploy correctness |
| D-8 | June 27 (Fri) | Oracle deploy to UAT (J3) + GCP deploy to UAT (M3) | Joachim, P3 | Low |
| **Gate** | | **ABN Sign-Off** (K2) | Patrick, Max K. | -- |
| D-12 to D-8 | June 23–27 | ABN bug fixes + retesting (J1, K1) | Joachim, Boyan | Medium: route calc is key blocker |

**Total estimated duration:** ~12 working days from today (June 23) to users on PROD (~July 7).

---

## 5. Gaps in Section 9 of the GoLive Document

The current Section 9 has 6 high-level steps. The following are **missing** based on the meeting discussion:

| # | Missing Step | Raised By | Why It Matters |
|---|-------------|-----------|----------------|
| G1 | EBV impact assessment before TMS Bridge PROD deployment | Christian Lang | **Critical fork:** if EBV is impacted, need full external ABN cycle, adding weeks |
| G2 | P3 QA re-verification on UAT before business testing | Boyan Valchev | Catches deployment errors before involving Patrick/Max Beisheim |
| G3 | Entra ID / Keycloak verification per environment | Nikolay (UAT issue) | UAT was broken until Ron fixed it live -- needs an explicit checklist step |
| G4 | Oracle "UAT only immediately before PROD" constraint | Joachim Schreiner | Changes the sequencing -- UAT is not a long-lived staging env |
| G5 | Alerting & monitoring setup for PROD | Matt Wilkinson | No owner, no tooling decision yet |
| G6 | Outage coordination with EBV consumers for TMS Bridge PROD | Matthias Max, Christian | EBV + Cloud4Log depend on production TMS Bridge |
| G7 | Max Beisheim calendar availability for early July | Patrick Uschmann | If Max Beisheim is unavailable, UAT sign-off is blocked |

---

## 6. Action Items (from the meeting)

| # | Action | Owner | Due |
|---|--------|-------|-----|
| A1 | Everyone adds their steps to Section 9 on the wiki | All | Before tomorrow's daily (June 23) |
| A2 | Discuss and finalize reverse timeline in tomorrow's daily | All | June 23 |
| A3 | Boyan + Joachim resolve open ABN bugs (route calc, VSP/weight) | Boyan, Joachim | Thu June 26 (target) |
| A4 | Ron: check Entra ID for PROD readiness | Ron | This week |
| A5 | Matt: raise bug for CDC/Datastream latency (~2 min) | Matt W. | Today |
| A6 | Patrick: check Max Beisheim's calendar for early July | Patrick | This week |
| A7 | Matthias: check APM configuration for EBV endpoint impact | Matthias | Before PROD deploy decision |
| A8 | Matt: set up call with Joachim + Thomas re: Oracle deployment scripts for UAT/PROD | Matt W. | Wednesday June 25 |

---

## 7. Open Questions

1. **Alerting & monitoring:** What tooling and who configures it for PROD?
2. **EBV impact:** Has anyone checked the APM configuration diff yet? This is the critical fork in the timeline.
3. **CDC latency:** Is 2 minutes acceptable for production, or does Striim need tuning first?
4. **Oracle UAT timing:** Can Joachim's "deploy UAT only immediately before PROD" constraint coexist with Boyan's "2–3 day QA on UAT" proposal?
5. **Pascal ownership:** Pascal was mentioned as owning TMS Bridge PROD deployment -- is he available/aligned?
6. **Max Beisheim availability:** Is early July confirmed or does the timeline shift?

---

## 8. Related Resources

| Resource | Location |
|----------|----------|
| GoLive 1060 Oracle (main page) | `02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/new-dispo-golive-1060-oracle.md` |
| Meeting transcript | `00_Meetings/2026-06-22_New Dispo Daily Sync 22.06.26.vtt` |
| TMS Bridge DB Permission Scope | `02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md` |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
