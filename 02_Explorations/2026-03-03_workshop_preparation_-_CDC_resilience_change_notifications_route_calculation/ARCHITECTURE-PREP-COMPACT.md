# Workshop Architecture Prep

**GoLive:** June 1 (90 days)
**Patrick's Priorities:** Grobavise + Change indicator
**My Focus:** CDC resilience, Change notifications, Route calculation

---

## 1. CDC Error Handling & Resilience

### Facts

**Current Implementation:**
- File: `ConsumeEventCommandHandler.cs:28-60`
- Behavior: Exception caught → `IsEventSuccess = false` → HTTP 200 OK returned
- **Problem:** Pub/Sub gets HTTP 200 → message acknowledged → never redelivered
- **Result:** Event lost forever, TMS change invisible to New Dispo

**Code Evidence:**
```csharp
catch (Exception ex) {
    result.IsEventSuccess = false;
    _logger.LogError(ex, "Error processing message");
}
return result; // HTTP 200 OK - Pub/Sub won't retry
```

**Top-Down Sync Problem:**
- Pattern: Write TMS first → Write New Dispo second
- File: `AssignLegToTransportOrderCommandHandler.cs:47-130`
- **Problem:** If `SaveChangesAsync()` (line 130) fails after TMS write (line 47-51), no rollback
- **Result:** TMS has change, New Dispo doesn't - permanently out of sync

**Production Evidence:**
- Jan 30, 2026: UAT2820 CDC 7 days behind, 422 GB backlog
- Root cause: Long transactions blocking WAL
- Resolution: 8-48 hours to catch up

### Solutions

**Option A: Return HTTP 5xx on failure**
- Pub/Sub retries automatically (exponential backoff)
- Requires idempotent handlers (check if already processed)
- Requires DLQ for max retry exhaustion
- Risk: Duplicate processing if handlers not idempotent

**Option B: DLQ only**
- Keep HTTP 200, manually handle DLQ
- Requires manual replay tooling
- Risk: Manual mistakes, delayed recovery

**Option C: Do nothing**
- Accept silent failures
- Manual reconciliation when noticed
- Risk: Data inconsistency, operational issues

**My Recommendation:** Option A
- Automated retry better than manual
- Requires idempotency work anyway for Option B

**Top-Down Sync (Post-GoLive):**
- Saga pattern needs TMS Bridge "undo" mutations
- Alternative: Accept risk, add monitoring

### Questions for Workshop

1. **Risk tolerance:** Acceptable data loss rate? (current: unknown, no metrics)
2. **Operator capacity:** Can team manually replay DLQ events daily?
3. **Monitoring:** Who watches for sync failures?

---

## 2. Change Detection & UI Notifications

### Facts

**Current State:**
- UI polls backend OR user manually refreshes
- No real-time updates
- SignalR not implemented (foundation doc exists: `2026-01-28-signalr-foundation.md`)

**SignalR Implementation:**
- Backend: Add `NotificationHub.cs`
- Frontend: Add `signalr.service.ts`
- Integration: CDC handler calls hub after success
- UI: Show notification badge

**Flow:**
```
CDC event processed successfully
  → ConsumeEventCommandHandler line 51
  → hubContext.Clients.All.SendAsync("DataChanged")
  → Frontend receives notification
  → Show "New data available" badge
  → User clicks → refresh view
```

### Solutions

**Option A: SignalR coarse-grained**
- Notification = "New data exists, click to refresh"
- No entity details in message
- Works for GoLive

**Option B: SignalR fine-grained**
- Notification includes entity type + ID
- UI updates specific components
- More complex for GoLive

**Option C: Keep polling**
- Works but worse UX

**My Recommendation:** Option A
- 5 days fits GoLive timeline
- Meets Patrick's requirement: "indicator that new data exists"
- Can enhance post-GoLive

### Questions for Workshop

1. **Scope:** Coarse-grained enough? Or need entity details?
2. **Priority:** Must-have or nice-to-have for GoLive?
3. **Fallback:** If not ready, keep polling - acceptable?

---

## 3. Route Calculation Flow

### Facts

**Architecture:**
```
New Dispo Frontend
  → New Dispo Backend (RouteCalculationService)
  → TMS Bridge GraphQL (get PoolDTO)
  → TMS Database (pdis_transportorder.getxserverdto)
  → Returns PoolDTO JSON
  → New Dispo Backend
  → TOP Service (.NET 4.5, CAL project)
  → PTV xServer (10.32.3.102:30000, on-premise, VPN required)
  → Returns route
  → TOP Service
  → New Dispo Backend
  → TMS Bridge (set route)
  → TMS Database (pdis_transportorder.setxserverdto)
  → CDC event
  → New Dispo UI updates
```

**TOP Project:**
- CAL .NET 4.5 codebase
- Wraps PTV xServer
- All routing logic + PoolDTO mapping in TMS DB + TOP
- Location: `https://dev.azure.com/caldevops/Agile/_git/CALtms?path=/3GL/CALConsult.TOP`
- Test cases show usage: `CALConsult.TOP.Test.XServer.JS/Program.cs`

**PoolDTO:**
- Get: `SELECT FRK_TIX FROM FRK_UNT WHERE TA_TIX = ... AND LFD_N = 1` then `pdis_transportorder.getxserverdto(frk_tix, date)`
- Structure: Locations, Orders, Vehicles, Plans (see exploration doc for full JSON)
- Set: `pdis_transportorder.setxserverdto(...)` writes calculated route back

**PTV xServer:**
- URL: `http://10.32.3.102:30000` (Nagel internal)
- Version: 2.26
- OpenAPI: `/services/openapi/2.26/swagger.json`
- Requires: VPN or Cloud Interconnect from GCP

### Integration Options

**Option A: Call CAL-hosted TOP Service**
- Use existing CAL REST endpoint
- Risk: Dependency on CAL, release coupling, debugging access?
- Status: Need CAL to provide endpoint URL

**Option B: Host TOP Service ourselves (Docker)**
- Containerize CAL TOP Service
- Deploy to GCP Cloud Run
- Risk: .NET 4.5 Dockerization (Windows container?), untested

**Option C: Rewrite TOP in .NET 8**
- Port logic to New Dispo Backend
- Risk: High, complex mapping logic, testing burden

**My Recommendation:** Option A for GoLive, Option B post-GoLive
- Need CAL endpoint ASAP
- Plan migration to own hosting after June 1

### Critical Dependencies

**Blockers:**
1. **Network:** GCP → VPN → xServer (10.32.3.102:30000)
   - Need: Cloud VPN or Interconnect setup
   - Owner: DevOps/Network team
   - Status: Not started

2. **PTV License:**
   - Question: Authorization model?
   - Question: New Dispo authorized to use?
   - Owner: TBD
   - Status: Unknown

3. **TOP Service Endpoint:**
   - Question: Does CAL expose REST endpoint?
   - Question: Is `CalculateRoute` method available?
   - Owner: CAL team
   - Status: Unknown

4. **Master Data:**
   - Needed: Verweildauern, opening hours, LKW profiles
   - Location: TMS database (exists?) or needs import?
   - Quality: Good enough for xServer?
   - Owner: TBD
   - Status: Unknown

**Fallback:** Manual route planning acceptable for initial GoLive?

### Questions for Workshop

1. **Licensing:** PTV xServer - authorization? negotiation needed?
2. **CAL Coordination:** Who contacts CAL? When? What do we need from them?
3. **Master Data:** What's missing? Who provides? When?
4. **Fallback Plan:** If not ready June 1 - defer route calculation? Accept manual routing?
5. **Scope:** VL/HL/NL support needed June 1? Or basic tours only?

---

## Workshop Day 1 Agenda Mapping

| Topic | My Involvement |
|-------|----------------|
| Performance (Sync der Daten) | **CDC error handling + Change detection** |
| Test Environment | Not my focus (DevOps) |
| Abrechnung von Abholungen | Not my focus |
| Auftragsdaten (Avis) | Listen (Grobavise = Patrick's priority) |
| Tourberechnung & Optimierung | **Route calculation flow** |
| Stammdaten Integration | **Related: Master data for xServer** |
| Übersicht & UI/UX | **Related: Change indicator UI** |

---

## Workshop Day 2 Agenda Mapping

| Topic | My Involvement |
|-------|----------------|
| Update + Intro P3 | Present Day 1 outcomes |
| Fernverkehr Planung | Listen (route calc implications) |
| TradePilot | Not my focus |
| Frachtabrechnung | Not my focus |
| Zeitfenster - Mercareon | **Related: xServer time windows** |
| Kann/Muss Verladung | Not my focus |

---

## Pre-Workshop Actions

**Must Do:**
- [ ] Validate CDC endpoint returns HTTP 200 on failure (confirm bug)
- [ ] Check if SignalR CORS already configured in Startup.cs
- [ ] Test PoolDTO retrieval from TMS 1034: `SELECT pdis_transportorder.getxserverdto(...)`
- [ ] Confirm VPN access to xServer: `curl http://10.32.3.102:30000`
- [ ] Draw 3 architecture diagrams (CDC, Notifications, Route Calc)

**Should Do:**
- [ ] List open questions for each topic
- [ ] Prepare code references (file paths + line numbers)
- [ ] Check incident logs for sync failure frequency

**Nice to Have:**
- [ ] Live demo of PoolDTO retrieval
- [ ] xServer playground access during workshop

---

## Key Messages

**CDC:** "We lose events silently. Fix = 8 days. Defer = accept data loss."

**Notifications:** "5 days for basic badge. Meets Patrick's requirement."

**Route Calc:** "Doable but tight. Blockers: network, licensing, CAL endpoint. Fallback = manual routing."

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| CDC fix takes longer than 8 days | Data loss continues post-GoLive | Start immediately, timebox to 10 days max |
| xServer network not ready | No route calculation GoLive | Manual routing fallback |
| PTV license issue | Cannot use xServer | Alternative routing engine? |
| CAL TOP endpoint unavailable | Cannot calculate routes | Build own service |
| Master data quality poor | Bad route calculations | Data quality sprint needed |

---

## Decisions Needed

1. **CDC:** Option A (HTTP 5xx + retry) vs Option B (DLQ + manual) vs Option C (do nothing)?
2. **Notifications:** SignalR coarse-grained vs defer to post-GoLive?
3. **Route Calc:** Use CAL endpoint vs build our own vs defer?
4. **Fallback:** If route calc not ready - acceptable to GoLive without it?
5. **Scope:** What route calculation features must work June 1?

---

## Post-Workshop Deliverables

- Architecture Decision Records (ADRs) for each decision
- User stories for approved work (acceptance criteria)
- Risk register with owners + mitigation plans
- Dependencies flagged
- Follow-up meeting list (CAL coordination, network team, etc.)
