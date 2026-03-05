# Workshop Preparation - CDC Resilience, Change Notifications, Route Calculation

**Date:** 2026-03-03
**Workshop:** Fernverkehr Workshop Nuremberg (2 Days, March 5-6)
**GoLive:** June 1, 2026

---

## Original User Input

Preparation for business stakeholder workshop in Nuremberg. Focus on 3 architecture topics:
1. CDC error handling & resilience strategy
2. Change detection & UI notification pattern
3. End-to-end route calculation flow (New Dispo → TMS Bridge → TMS → TOP → xServer)

Patrick's GoLive must-haves:
- Grobavise integration
- Change indicator on UI
- CDC error flow & system resilience
- Edit flow completion

---

## Documents in This Exploration

### Quick Reference
- **ONE-PAGER.md** - Single page cheat sheet for the workshop (2 minutes to read)

### Detailed Prep
- **ARCHITECTURE-PREP-COMPACT.md** - Full preparation document with facts, options (10K, ~30 min read)

### Visual Materials
- **DIAGRAMS-CURRENT-STATE.md** - Current state diagrams (Mermaid, presentation ready)
  - CDC error handling (current broken state)
  - Top-down sync vulnerability
  - Change notifications (current polling)
  - Route calculation end-to-end flow
  - Network topology (GCP ↔ On-Prem)
  - PoolDTO structure example

- **DIAGRAMS-PROPOSALS.md** - Proposed solutions with diagrams
  - CDC error fix (HTTP 503 + retry)
  - SignalR notifications implementation

- **DECISION-FRAMEWORK.md** - Decision matrix, risks
  - Options comparison table
  - Risk assessment matrix

### Reference
- **WORKSHOP-PREPARATION.md** - Initial detailed version (24K, reference only)

---

## Key Facts

### CDC Error Handling
- **Bug:** `ConsumeEventCommandHandler.cs:53-57` returns HTTP 200 even on failure
- **Impact:** Pub/Sub acknowledges → message lost forever → data inconsistency
- **Fix:** Return HTTP 503 on failure → automatic retry → DLQ

### Change Notifications
- **Current:** UI polls or manual refresh
- **Proposed:** SignalR push notifications
- **Implementation:** Backend hub + Frontend service + CDC integration

### Route Calculation
- **Flow:** New Dispo → TMS Bridge → TMS DB → TOP Service → xServer → back
- **Blockers:**
  - Network: GCP → VPN → xServer (not configured)
  - TOP Service: CAL endpoint unknown
  - PTV License: Status unknown
  - Master Data: Quality unknown
- **Risk:** HIGH - too many unknowns

---

## Decisions Needed

1. **CDC:** Implement HTTP 5xx retry pattern - yes/no?
2. **Notifications:** SignalR in scope for GoLive - yes/no?
3. **Route Calc:** Realistic or defer with manual routing fallback?
4. **Dependencies:** Who owns network setup, CAL coordination, license clarification?

---

## Workshop Agenda Mapping

**Day 1 (Wednesday):**
- Performance (Sync) → Present CDC + Notifications
- Tourberechnung → Present Route Calc + blockers
- Stammdaten → Connect to route calc master data needs

**Day 2 (Thursday):**
- Update → Present Day 1 outcomes
- Mercareon Zeitfenster → Related to route calc time windows

---

## Related Files

**Meeting Context:**
- `00_Meetings/2026-03-03_workshop-nuernberg-themen/Onsite Fernverkehr WS Prep.docx`
- `00_Meetings/2026-03-03_workshop-nuernberg-themen/comments-product-owner.max.md`

**Background Explorations:**
- `02_Explorations/2026-03-03_cdc-sync-and-error-scenarios/` - CDC analysis
- `02_Explorations/2026-01-28-signalr-foundation.md` - SignalR setup guide
- `02_Explorations/2025-07-28_TOP_xServer_integration_refinement.md` - Route calc background
- `02_Explorations/2026-01-30-replication-slot-size/` - CDC production incident

**Code References:**
- CDC: `Code/Disposition-Backend/.../CDC/Requests/ConsumeEvent/ConsumeEventCommandHandler.cs:28-60`
- Top-Down Sync: `Code/Disposition-Backend/.../TransportOrderPlanning/Requests/AssignLegToTransportOrder/AssignLegToTransportOrderCommandHandler.cs:47-130`
- TMS DB: `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql`

---

## Recommendations

| Topic | Action | Reason |
|-------|--------|--------|
| CDC Error Handling | Fix it (8 days) | Data loss unacceptable for production |
| Change Notifications | Do it (5 days) | Meets Patrick's requirement, low risk, good UX |
| Route Calculation | Clarify dependencies this week | Too many unknowns - need fallback plan |

**Critical Path:** Route calc dependencies must clear by March 17 (Week 2) to make June 1 GoLive.

---

## Next Steps

**Before Workshop (March 4):**
- [ ] Skim ONE-PAGER.md
- [ ] Review DIAGRAMS.md
- [ ] Try to answer unknowns: VPN status? PTV license? CAL endpoint?

**During Workshop:**
- [ ] Present CDC + Notifications on "Performance" topic
- [ ] Present Route Calc on "Tourberechnung" topic
- [ ] Push for decisions on all 3 topics
- [ ] Get owners assigned for route calc blockers

**After Workshop:**
- [ ] Write ADRs for decisions made
- [ ] Create user stories for approved work
- [ ] Update risk register
- [ ] Schedule follow-up meetings for dependencies
