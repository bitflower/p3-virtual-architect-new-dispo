# Workshop Prep: Architecture Topics

**GoLive:** June 1, 2026 (3 months)

**Patrick's Must-Haves:**
1. Grobavise integration (business/dev)
2. Change indicator for new/changed shipments (architecture)
3. CDC error flow & resilience (architecture)
4. Edit flow done (dev)

**My 3 Topics:**
1. CDC error handling & resilience
2. Change detection & UI notifications
3. Route calculation flow (New Dispo → TMS Bridge → TMS → TOP → xServer)

---

## Topic 1: CDC Error Handling & Resilience Strategy

### Current State Analysis

#### Architecture Overview
```
TMS Database (AlloyDB)
    ↓ CDC Stream (Google Datastream)
Google Cloud Storage Bucket
    ↓ Pub/Sub Notification
Google Pub/Sub Push Subscription
    ↓ HTTP POST (CloudEvent)
New Dispo Backend (/api/CDC/consume-event)
```

#### Critical Vulnerabilities Identified

**Bottom-Up Sync (TMS → New Dispo):**
- **Problem:** CDC events acknowledged immediately, even if processing fails
- **Location:** `ConsumeEventCommandHandler.cs:28-60`
- **Behavior:**
  - Exception caught → `IsEventSuccess = false` → HTTP 200 OK returned
  - Pub/Sub considers message delivered → No retry → Event lost forever
  - TMS change exists but New Dispo never sees it

**Top-Down Sync (New Dispo → TMS):**
- **Problem:** No distributed transaction coordination
- **Pattern:** Write to TMS first → Write to New Dispo second → No rollback
- **Behavior:**
  - If New Dispo SaveChanges fails after TMS write succeeds
  - TMS has the change, New Dispo doesn't
  - Systems permanently out of sync

#### Production Impact Evidence
- **2026-01-30 Incident:** UAT2820 replication 7 days behind (422 GB backlog)
- **Root Cause:** Long-running transactions blocking WAL progression
- **Resolution Time:** 8-48 hours to catch up after clearing hung transactions

### Workshop Discussion Points

#### For Business Stakeholders

1. **What is CDC and why does it matter?**
   - Change Data Capture = Real-time data synchronization
   - Keeps New Dispo UI updated when TMS database changes
   - Critical for GoLive requirement: "Change indicator for new/changed shipments"

2. **Current Risk Exposure**
   - Silent failures: Events lost without operator awareness
   - Data inconsistency: TMS and New Dispo can become permanently out of sync
   - No manual recovery: No tool to replay lost events

3. **Business Impact Scenarios**
   - Shipment created in TMS (via OMS) → CDC event fails → Disponent never sees shipment
   - Disponent assigns leg to transport order → New Dispo DB save fails → TMS shows assigned, UI shows unassigned
   - Result: Manual reconciliation required, potential operational delays

#### For Technical Team

1. **Architecture Decision: Error Handling Strategy**

   **Option A: Return HTTP 5xx on Processing Failure** (Recommended)
   - Pub/Sub retries failed messages automatically
   - Exponential backoff prevents overwhelming system
   - Requires idempotent event handlers
   - Dead Letter Queue after max retries

   **Option B: Implement Dead Letter Queue**
   - Acknowledge all messages immediately (current behavior)
   - Failed events sent to separate Pub/Sub topic
   - Manual replay process for failed events
   - Requires new infrastructure and tooling

   **Option C: Event Store + Background Processing**
   - Persist all CDC events to event store first
   - Process asynchronously with retry logic
   - Highest resilience, highest complexity
   - Significant development effort

2. **Architecture Decision: Distributed Transaction Strategy**

   **Option A: Saga Pattern (Recommended for GoLive)**
   - Write to TMS → On success, write to New Dispo
   - On New Dispo failure → Call TMS compensation API
   - Requires new TMS Bridge "undo" mutations
   - Medium development effort

   **Option B: Eventual Consistency + Reconciliation**
   - Accept temporary inconsistency
   - Background job compares TMS vs New Dispo
   - Auto-corrects discrepancies
   - Requires reconciliation service (not GoLive ready)

   **Option C: Two-Phase Commit**
   - Distributed transaction coordinator
   - High complexity, performance impact
   - Not recommended for microservices

### Proposed Solution for GoLive (June 1)

#### Minimum Viable Resilience (June 1 GoLive)

**1. CDC Error Handling**
```
Change: Return HTTP 503 (Service Unavailable) on processing failure
Result: Pub/Sub retries message automatically
Risk:   Low - well-established pattern
```

**2. Idempotent Event Handlers**
```
Change: Add deduplication check in event handlers
Logic:  Check if shipment/leg already processed before SaveChanges
Risk:   Medium - requires careful testing
```

**3. Dead Letter Queue**
```
Change: Configure Pub/Sub DLQ for messages exceeding retry limit
Result: Failed events preserved for manual replay
Risk:   Low - GCP managed service
```

**4. Monitoring & Alerting**
```
Change: Add metrics for CDC processing failures
Alert:  Notify operators when DLQ receives messages
Risk:   Low
```

#### Post-GoLive Improvements (After June 1)

**1. Saga Pattern for Top-Down Sync**
- Requires TMS Bridge compensation APIs (undo operations)
- Requires saga orchestration in New Dispo Backend
- Priority: High (prevents data inconsistency)

**2. Reconciliation Service**
- Background job comparing TMS vs New Dispo
- Auto-correction or operator notification
- Priority: Medium (safety net for missed events)

**3. Event Store**
- Persist all CDC events before processing
- Enables full audit trail and replay capability
- Priority: Low (nice-to-have)

### Workshop Materials Needed

**Architecture Diagrams:**
- [ ] Current CDC flow with failure points highlighted
- [ ] Proposed error handling flow (HTTP 5xx + retry)
- [ ] Top-down sync vulnerability pattern
- [ ] Saga pattern compensation flow

**Decision Framework:**
- [ ] Solution comparison table (Options A/B/C)
- [ ] Risk assessment for each approach

**Discussion Prompts:**
- [ ] Risk tolerance: What's acceptable data inconsistency level?
- [ ] Operational capability: Can team handle manual DLQ replay?

---

## Topic 2: Change Detection & UI Notification Pattern

### Current State Analysis

#### Architecture Options Explored

**SignalR Foundation** (Already documented - 2026-01-28)
- Real-time push from backend to frontend
- WebSocket-based bidirectional communication
- Angular service + .NET Hub
- Status: Not implemented yet

**Components Required:**
1. Backend SignalR Hub (`NotificationHub.cs`)
2. Frontend SignalR Service (`signalr.service.ts`)
3. CORS configuration (already exists)

#### Use Case for GoLive

**Requirement:** "Indicator on the page that new shipments / changed data exist"

**User Story:**
- When CDC event processed successfully → Notify connected users
- When new shipment arrives from OMS → Show indicator in UI
- When transport order updated in TMS → Refresh affected views

**Current Behavior:**
- UI polls backend periodically OR
- User manually refreshes page
- No real-time change detection

### Workshop Discussion Points

#### For Business Stakeholders

1. **User Experience Improvement**
   - Disponenten see changes immediately (no manual refresh)
   - Reduced risk of working with stale data
   - Better collaboration (multiple users see same updates)

2. **Scenarios**
   - OMS sends new shipment → Disponent sees notification instantly
   - Another disponent assigns leg → UI updates automatically
   - TMS update via old Uniface client → New Dispo shows change indicator

3. **Trade-offs**
   - Infrastructure cost: Minimal (SignalR built into .NET 8)
   - Alternative: Continue with polling (works but not ideal UX)

#### For Technical Team

1. **Implementation Decision: Push vs Poll**

   **Option A: SignalR Push (Recommended)**
   ```
   Pro:  Real-time, efficient, better UX
   Con:  Requires WebSocket support, stateful connections
   ```

   **Option B: Server-Sent Events (SSE)**
   ```
   Pro:  Simpler than SignalR, unidirectional push
   Con:  Less feature-rich, HTTP/1.1 limitations
   ```

   **Option C: Polling (Current)**
   ```
   Pro:  Already works, simple
   Con:  Inefficient, delayed updates, not real-time
   ```

2. **Notification Granularity**

   **Approach A: Coarse-Grained (Recommended for GoLive)**
   ```
   Notification: "New data available, please refresh"
   Data: None (just a signal)
   Behavior: User clicks refresh → full reload
   ```

   **Approach B: Fine-Grained**
   ```
   Notification: Includes changed entity details
   Data: { entityType: "Shipment", id: 12345, changeType: "Created" }
   Behavior: UI updates specific component automatically
   ```

   **Approach C: Delta Updates**
   ```
   Notification: Includes full changed entity
   Data: Complete shipment object
   Behavior: UI merges changes without refresh
   ```

### Proposed Solution for GoLive (June 1)

#### Minimum Viable Notification (June 1 GoLive)

**1. SignalR Foundation Setup**
```
Backend: NotificationHub with SendMessage method
Frontend: SignalR service with connection management
```

**2. CDC Integration Point**
```
Location: ConsumeEventCommandHandler after successful processing
Action:   await _hubContext.Clients.All.SendAsync("DataChanged")
```

**3. UI Notification Badge**
```
Component: Top navigation bar
Behavior:  Show "New data available" indicator
Action:    User clicks → Refresh current view
```

**4. Connection Management**
```
When:     User logs in
Action:   Establish SignalR connection
Cleanup:  Disconnect on logout
```

#### Post-GoLive Improvements (After June 1)

**1. Fine-Grained Notifications**
- Include entity type and ID in notifications
- UI updates specific components automatically
- Priority: Medium (better UX)

**2. User-Specific Notifications**
- Send notifications only to affected users
- Requires user group/role management
- Priority: Low (optimization)

**3. Notification History**
- Persist notifications in database
- Show notification log in UI
- Priority: Low (nice-to-have)

### Workshop Materials Needed

**Architecture Diagrams:**
- [ ] SignalR connection flow (login → establish connection)
- [ ] CDC event → SignalR notification → UI update flow
- [ ] Comparison: Polling vs Push architecture

**Prototypes/Mockups:**
- [ ] UI notification badge mockup
- [ ] Notification interaction flow (click → refresh)

**Decision Framework:**
- [ ] Notification granularity comparison
- [ ] GoLive scope vs Post-GoLive scope

---

## Topic 3: End-to-End Route Calculation Flow

### Current State Analysis

#### High-Level Architecture

```
New Dispo Frontend (Angular)
    ↓ GraphQL Mutation (User initiates route calculation)
New Dispo Backend (.NET 8)
    ↓ GraphQL Query (Get PoolDTO)
TMS Bridge (GraphQL API)
    ↓ Function Call: pdis_transportorder.getxserverdto()
TMS Database (AlloyDB)
    ↓ Returns PoolDTO (JSON)
TMS Bridge
    ↓ PoolDTO JSON
New Dispo Backend
    ↓ HTTP POST to TOP Service
TOP Service/API (.NET 4.5 - CAL Project)
    ↓ Call PTV xServer
PTV xServer (On-premise, VPN required)
    ↓ Route calculation result
TOP Service
    ↓ Mapped result
New Dispo Backend
    ↓ Store/Update route in TMS via TMS Bridge
TMS Bridge
    ↓ Function Call: pdis_transportorder.setxserverdto()
TMS Database (Updated with calculated route)
    ↓ CDC Event
New Dispo Backend (Updates UI via CDC)
```

#### Key Components

**1. TMS Database Functions**
- `pdis_transportorder.getxserverdto(frk_tix, planningdate)` → Returns PoolDTO
- `pdis_transportorder.setxserverdto(...)` → Accepts calculated route
- **PoolDTO:** Generic CAL entity for tour optimization (defined by CAL)
- **FRK_TIX:** Retrieved via `SELECT FRK_TIX FROM FRK_UNT WHERE TA_TIX = ... AND LFD_N = 1`

**2. TOP Project** (CAL .NET 4.5 Project)
- **Purpose:** Bridge between TMS and PTV xServer
- **Location:** `https://dev.azure.com/caldevops/Agile/_git/CALtms?path=/3GL/CALConsult.TOP`
- **Key Insight:** "All mapping and business logic resides in TMS Database and TOP project - will be re-used!"
- **Test Cases:** Show exact integration pattern (`CALConsult.TOP.Test.XServer.JS/Program.cs`)

**3. PTV xServer**
- **URL:** `http://10.32.3.102:30000` (requires Nagel VPN)
- **Version:** 2.26
- **OpenAPI:** Available at `/services/openapi/2.26/swagger.json`
- **Playground:** Raw Request Runner at `/dashboard/Content/Administration/RawRequestRunner.htm`

**4. Integration Options** (From 2025-07-28 Refinement)

**Option 1: New Cloud Component for TOP DLL**
- Pros: Clean separation, future-proof
- Cons: Highest effort, new infrastructure
- Status: Considered for iteration 1

**Option 2: Integrate TOP DLL into New Dispo Backend**
- Pros: Lowest integration effort
- Cons: Pollutes New Dispo backend, domain coupling
- Risk: .NET 4.5 DLL in .NET 8 project - deployment compatibility?

**Option 3: Re-use Existing REST Web Service from CAL**
- Component: `CALConsult.TOP.Service`
- Pros: Existing code, less effort than Option 1
- Cons: Legacy .NET, error-prone
- Status: Needs validation of `CalculateRoute` method exposure

### Workshop Discussion Points

#### For Business Stakeholders

1. **What is Route Calculation?**
   - Optimizes transport order stops (pickup/delivery sequence)
   - Considers: vehicle capacity, time windows, driving restrictions
   - Uses PTV xServer (industry-standard routing engine)
   - Critical for efficient tour planning

2. **Current Limitations to Discuss**
   - What can route calculation deliver by June 1 GoLive?
   - What cannot be achieved by June 1?
   - Dependencies: xServer licensing, TOP service availability

3. **Key Questions for Patrick/Stakeholders**
   - Master data quality: Are Verweildauern, opening hours, LKW profiles available?
   - PTV xServer: Cost model? License constraints? Future-proofing?
   - TMS integration: Who hosts/maintains TOP service?
   - Release process: How to deploy changes to TOP service?

#### For Technical Team

1. **Architecture Decision: TOP Integration**

   **Decision Required:** How to integrate TOP .NET 4.5 project?

   **Option A: Containerized TOP Service** (Recommended)
   ```
   Approach: Dockerize CALConsult.TOP.Service
   Deployment: GCP Cloud Run or GKE
   Ownership: P3 team (independent from CAL)
   Pros: Clean separation, P3 autonomy
   Cons: Need to containerize .NET 4.5 (Windows container?)
   ```

   **Option B: Call CAL-Hosted TOP Service**
   ```
   Approach: Use existing CAL service endpoint
   Deployment: CAL infrastructure
   Ownership: CAL team
   Pros: Faster path
   Cons: Dependency on CAL, release coupling
   ```

   **Option C: Rewrite TOP Logic in New Dispo Backend**
   ```
   Approach: Port TOP mapping logic to .NET 8
   Deployment: New Dispo Backend
   Ownership: P3 team
   Pros: Full control, modern stack
   Cons: Complex, risk of mapping errors
   ```

2. **PTV xServer Access**
   - Network: Requires VPN or internal network routing
   - Security: Firewall rules, authentication
   - GCP: Need Cloud VPN or Interconnect to on-prem xServer

3. **Error Handling**
   - xServer unavailable: Fallback behavior?
   - Calculation timeout: Retry strategy?
   - Invalid PoolDTO: Validation before calling xServer?
   - Partial failure: Route calculated but DB write fails?

### Proposed Solution for GoLive (June 1)

#### Minimum Viable Route Calculation (June 1 GoLive)

**1. Network Connectivity**
```
Setup: GCP Cloud VPN to Nagel on-premise network
Target: PTV xServer at 10.32.3.102:30000
Owner: DevOps + network team
Risk: Medium (firewall rules, VPN stability)
```

**2. TOP Service Integration**
```
Approach: Option B - Call CAL-hosted TOP service
Reason: Fastest path to GoLive
Endpoint: TBD with CAL team
```

**3. New Dispo Backend Integration**
```
Component: RouteCalculationService
Flow:
  1. Get PoolDTO from TMS (via TMS Bridge)
  2. Call TOP service with PoolDTO
  3. Receive calculated route
  4. Update TMS with result (via TMS Bridge)
```

**4. Error Handling & Logging**
```
Cases:
  - xServer timeout → Return error to user
  - TOP service unavailable → Show "Route calculation unavailable"
  - Invalid response → Log and notify operators
```

**5. UI Integration**
```
Component: Transport Order detail view
Action: "Calculate Route" button
Behavior: Shows loading state → Displays result or error
```

**Critical Dependencies:**
- [ ] CAL provides TOP service endpoint (or approval to host our own)
- [ ] Network team sets up VPN to xServer
- [ ] PTV xServer license confirmed for New Dispo usage
- [ ] Master data (Verweildauern, opening hours) available in TMS

#### Post-GoLive Improvements (After June 1)

**1. Hosted TOP Service (P3 Owned)**
- Containerize TOP service
- Deploy to GCP Cloud Run
- Independent from CAL release cycles
- Priority: High (independence)

**2. Retry & Queue Mechanism**
- Long-running calculations moved to async processing
- Queue-based architecture (Cloud Tasks)
- User notified when calculation completes
- Priority: Medium (better UX for large tours)

**3. Route Calculation History**
- Store all calculation requests and results
- Audit trail for debugging
- Priority: Low (nice-to-have)

### Workshop Materials Needed

**Architecture Diagrams:**
- [ ] End-to-end sequence diagram (Frontend → Backend → TOP → xServer → TMS)
- [ ] Network topology (GCP → VPN → On-premise xServer)
- [ ] Error handling flow (what happens when xServer fails)
- [ ] PoolDTO structure example (visual representation)

**Decision Framework:**
- [ ] TOP integration options comparison (A/B/C)
- [ ] Risk matrix (network, licensing, dependencies)

**Demo/Prototype:**
- [ ] Working example: Fetch PoolDTO from TMS 1034 database
- [ ] Sample xServer request/response (using playground)
- [ ] Show TOP test case code as reference

**Discussion Prompts:**
- [ ] Licensing: PTV xServer authorization?
- [ ] Master data: What's missing? Who provides it? When?
- [ ] Fallback: What if route calculation unavailable at GoLive?
- [ ] Scope: What calculations are in scope? (VL/HL/NL support?)

---

## Workshop Agenda Mapping

### Day 1 - Wednesday Topics

**Performance (Sync der Daten zwischen TMS und New Dispo)**
→ **Your Topics: CDC error handling + Change detection**

**Test Environment (S20, automated deploys, test data)**
→ Not your focus (DevOps)

**Abrechnung von Abholungen**
→ Not your focus (Business logic)

**Auftragsdaten (Avis, Vorläufige, Endgültige)**
→ Not your focus (TMS integration - Grobavise is business/dev focus)

**Tourberechnung & Optimierungslogik**
→ **Your Topic: Route calculation flow**

**Stammdaten Integration**
→ **Related to your route calculation topic** (master data for xServer)

**Übersicht & UI/UX Optimierung**
→ **Related to change detection topic** (UI indicators)

**Rückfragen & Diskussion (Remaining Topics)**
→ Be prepared to contribute architecture perspective

### Day 2 - Thursday Topics

**Primär Update, Intro an P3**
→ Your chance to present Day 1 outcomes

**Fernverkehr Planung (Tourpunkte erweitern)**
→ Listen for route calculation implications

**TradePilot Integration**
→ Not your focus (new integration)

**Frachtabrechnung**
→ Not your focus (billing logic)

**Zeitfenster - Mercareon**
→ **Related to route calculation** (time windows for xServer)

**Kann/Muss - Verladung**
→ Not your focus (loading logic)

---

## Preparation Checklist

### Documents to Create
- [ ] Architecture diagrams for all 3 topics (tool: draw.io, Miro, or Mermaid)
- [ ] Decision framework matrices (effort/value/risk)
- [ ] GoLive scope definition (what's in, what's out)
- [ ] Timeline visualization (what can be achieved by June 1)

### Code/System Validation
- [ ] Verify CDC endpoint behavior (test failing event)
- [ ] Confirm SignalR CORS configuration exists
- [ ] Test TMS database PoolDTO retrieval (1034 test environment)
- [ ] Validate PTV xServer access (VPN connectivity)

### Stakeholder Alignment
- [ ] Confirm with product owner: Are these the right 3 topics?
- [ ] Check with lead devs: Any additional context needed?
- [ ] Verify with Patrick: GoLive expectations for each topic

### Presentation Materials
- [ ] Laptop with VPN access (for live demos if needed)
- [ ] Backup slides (in case diagrams need to be presented)
- [ ] Code snippets prepared (key locations to show if asked)
- [ ] Incident examples (2026-01-30 replication lag as case study)

### Discussion Preparation
- [ ] List of open questions for each topic
- [ ] Risk assessment for each proposed solution
- [ ] Effort estimates validated with development team
- [ ] Alternative approaches prepared (if primary solution rejected)

---

## Key Messages for Stakeholders

### CDC Error Handling
**Message:** "We have vulnerabilities in our sync mechanisms that can cause permanent data inconsistency. We need ~2 weeks to implement minimum resilience before GoLive."

**Ask:** "What's our risk tolerance? Should we delay GoLive if resilience isn't ready?"

### Change Detection & Notifications
**Message:** "Real-time notifications are achievable before GoLive with ~1 week effort. It significantly improves user experience."

**Ask:** "Is this a must-have or nice-to-have for GoLive? Can we scope it down to coarse-grained notifications?"

### Route Calculation Flow
**Message:** "Integration is achievable but has critical dependencies (network, licensing, CAL coordination). Timeline is tight."

**Ask:** "What's the fallback if route calculation isn't ready by June 1? Manual routing acceptable temporarily?"

---

## Success Criteria for Workshop

### Day 1 Outcomes
- [ ] Stakeholders understand current sync vulnerabilities
- [ ] Agreement on CDC error handling approach (HTTP 5xx + retry)
- [ ] Decision on notification implementation (SignalR yes/no)
- [ ] Backlog updated with GoLive-tagged user stories

### Day 2 Outcomes
- [ ] Agreement on TOP integration approach (Option A/B/C)
- [ ] Network connectivity plan confirmed
- [ ] PTV xServer licensing clarity
- [ ] Critical dependencies assigned to owners with due dates

### Post-Workshop Actions
- [ ] Architecture Decision Records (ADRs) written for each decision
- [ ] User stories created for approved work
- [ ] Risk register updated with identified issues
- [ ] Follow-up meetings scheduled for open items

---

## Emergency Backup Plans

### If Network to xServer Not Ready
- Route calculation deferred to post-GoLive
- Manual route planning acceptable for June 1
- Focus on CDC resilience instead

### If CDC Resilience Takes Longer
- Deploy with current implementation
- Increase monitoring and manual reconciliation
- Plan hotfix deployment 1 week after GoLive

### If Change Notifications Not Ready
- Keep current polling mechanism
- Defer to post-GoLive improvement
- Not a blocker for GoLive

---

## Notes & Observations
- Edit flow is mentioned as "must be done" but not in your 3 topics - monitor if it comes up
- Grobavise is Patrick's #1 priority - be ready to discuss architecture implications
- Master data quality (Verweildauern, opening hours) repeatedly mentioned - route calculation blocker if missing
- TradePilot integration on Day 2 - might have sync/notification implications

---

**Prepared by:** Enterprise Solution Architect
**Last Updated:** 2026-03-03
**Review Status:** Ready for workshop
