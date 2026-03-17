# Document Separation Analysis - CDC Sync and Error Scenarios

**Date:** 2026-03-03
**Author:** Virtual Architect (Claude)
**Purpose:** Architectural analysis to separate the mega-document into focused, actionable documents

---

## Executive Summary

The current `cdc-sync-and-error-scenarios.md` document (569 lines) addresses multiple distinct architectural problems that should be separated into individual documents. This analysis identifies **three core problems**, evaluates their relationships, and proposes a clear document structure.

---

## Source Material Analysis

### Primary Sources

| Document | Type | Key Contributions |
|----------|------|-------------------|
| `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md` | Meeting Notes | Identified Problems 1 & 2 |
| `02_Explorations/2026-03-03_cdc-sync-and-error-scenarios/_archive/matthias-input.md` | Exploration Request | Identified Problem 3 (archived - no longer relevant) |
| `02_Explorations/2026-03-03_cdc-sync-and-error-scenarios/cdc-sync-and-error-scenarios.md` | Technical Analysis | 569-line combined analysis |
| `02_Explorations/2026-03-03_cdc-sync-and-error-scenarios/potential-solutions.md` | Solution Proposals | Remediation patterns |
| `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/` | Detailed Exploration | Problem 1 (Top-Down Sync) covered in depth |

---

## Identified Problems

From a distributed systems architecture perspective, there are **THREE DISTINCT PROBLEMS**:

### Problem 1: Distributed Transaction Failure (Top-Down Sync)

**Status:** ✅ **Covered in separate exploration:** `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders`

**Complexity:** High (Complex)
**Category:** Dual-Write Anti-Pattern

**Problem Statement:**
For every business logic flow for which we need to persist information both in New Dispo DB and TMS DB we are vulnerable to getting out of sync. For example if we assign a leg we first assign the Leg on TMS and if it succeeds we assign in New Dispo. If for some reason we're unable to assign it in New Dispo, we don't have logic to rollback on TMS.

**Direction:** New Dispo → TMS
**Trigger:** User action in New Dispo UI
**Root Cause:** Sequential writes to two databases without distributed transaction coordination

**Affected Flows:**
- Leg/lot assignment to transport order
- Leg/lot unassignment from transport order
- Create transport order from leg/lot
- Delete transport order
- Mark leg as stays loaded

**Failure Pattern:**
```
1. New Dispo calls TMS Bridge GraphQL mutation
2. TMS Bridge executes stored procedure → ✓ TMS DB modified
3. TMS Bridge returns success response
4. New Dispo updates AppDbContext entities
5. AppDbContext.SaveChangesAsync() fails → ✗ New Dispo DB not modified
6. No rollback mechanism → Systems permanently out of sync
```

**Why Rollback is Difficult:**
- Network dependency (HTTP call to TMS Bridge can fail)
- Stateless TMS Bridge (no transaction context)
- TMS stored procedures don't expose inverse operations
- Temporal gap allows other operations to occur

---

### Problem 2: CDC Event Processing Failure (Bottom-Up Sync)

**Complexity:** Medium (Less Complex)
**Category:** Event Loss After Consumption

**Problem Statement:**
We don't have a mechanism to guarantee that CDC events will be eventually processed if New Dispo fails the first time. The outcome is that New Dispo will not be able to retry processing the event and it will eventually get out of sync.

**Direction:** TMS → New Dispo (via CDC)
**Trigger:** Any change in TMS database (any source)
**Root Cause:** Premature message acknowledgment - HTTP 200 returned before successful processing

**CDC Pipeline:**
```
TMS Database (Sendung table)
  ↓ Google Datastream (CDC)
Google Cloud Storage
  ↓ Pub/Sub Notification
Google Pub/Sub (Push Subscription)
  ↓ HTTP POST /api/CDC/consume-event
New Dispo Backend (ConsumeEventCommandHandler)
```

**Failure Pattern:**
```
1. Pub/Sub delivers CDC event via HTTP POST
2. ConsumeEventCommandHandler receives event
3. Event deserialized and handler found
4. handler.Handle() executes
5. Processing fails (DB unavailable, mapping error, etc.)
6. Exception caught, logged, IsEventSuccess = false
7. HTTP 200 OK returned to Pub/Sub → ✓ Message acknowledged
8. Pub/Sub will NOT redeliver → Event lost forever
```

**Key Issue:** The current code returns HTTP 200 OK even when processing fails. Pub/Sub interprets this as successful processing and will not retry.

**Code Location:** `ConsumeEventCommandHandler.cs:53-57`

---

### Problem 3: External TMS Modifications Invisible to New Dispo

**Status:** ⚠️ **Descoped** - This problem has been descoped and is no longer being actively addressed.

**Complexity:** Unknown (requires investigation)
**Category:** External Write Detection Gap

**Problem Statement:**
Whenever someone adds or modifies data in TMS Database directly (e.g., through the old Uniface fat client) we won't notice in New Dispo.

**Direction:** External System → TMS (New Dispo unaware)
**Trigger:** Direct TMS database modification (Uniface client, SQL tools, other systems)
**Root Cause:** CDC not configured for all tables, or modifications bypass CDC

**Potential Sources of External Modifications:**
1. **Uniface Fat Client** - Legacy TMS client still in production
2. **Direct SQL Access** - Database administrators, reporting tools
3. **Other Integrations** - Systems that write directly to TMS
4. **Batch Jobs** - Scheduled processes that modify TMS data

**Detection Gap:**
- New Dispo only receives CDC events for configured tables/operations
- Not all TMS tables may have CDC enabled
- Some operations may not trigger CDC events
- No reconciliation mechanism to detect drift

**Critical Questions:**
- Which TMS tables have CDC configured?
- Which operations trigger CDC events?
- What modifications are invisible to New Dispo?
- How often do external modifications occur?
- What business processes rely on direct TMS access?

---

## Problem Comparison Matrix

| Aspect | Problem 1 (Covered separately) | Problem 2 | Problem 3 (Descoped) |
|--------|-----------|-----------|-----------|
| **Name** | Distributed Transaction Failure | CDC Event Processing Failure | External TMS Modifications |
| **Direction** | New Dispo → TMS | TMS → New Dispo | External → TMS |
| **Trigger** | User action in New Dispo UI | TMS change (any source) | Direct TMS modification (bypass New Dispo) |
| **Root Cause** | Dual-write without atomicity | Premature message acknowledgment | CDC not configured / External writes |
| **Assessed Complexity** | High (Complex) | Medium (Less complex) | Unknown (requires investigation) |
| **Detection** | Silent failure | Silent failure | Not detected at all |
| **Current Handling** | None (no rollback) | Exception logged, event lost | No detection mechanism |
| **Business Impact** | TMS has change, New Dispo doesn't | TMS has change, New Dispo doesn't | TMS has change, New Dispo doesn't |
| **Recovery** | Manual SQL (difficult) | Impossible (event lost) | Unknown / Not detected |
| **Frequency** | On every write operation (high risk) | On CDC processing failure (medium risk) | Unknown frequency (unknown risk) |
| **Solution Complexity** | High (requires architectural patterns) | Medium (infrastructure configuration) | Medium-High (CDC audit + reconciliation) |

---

## Key Architectural Insights

### Common Outcome, Different Causes

**All three problems lead to the same symptom:**
- TMS database contains data
- New Dispo database missing or inconsistent data
- Users see incomplete information in New Dispo UI

**But they have fundamentally different root causes:**
1. **Problem 1:** Atomicity violation in dual-write scenario
2. **Problem 2:** Incorrect error handling in event processing
3. **Problem 3:** Missing event stream or detection mechanism

### Implications for Solutions

**Different root causes require different solutions:**
- Problem 1 → Distributed transaction patterns (Saga, Outbox)
- Problem 2 → Correct Pub/Sub error handling + retry infrastructure
- Problem 3 → CDC coverage audit + reconciliation jobs

**Solutions should not be mixed** - each problem needs independent remediation.

### Problem 3 is Potentially Most Critical

Reasons:
1. **Unknown scope** - CDC coverage needs audit
2. **Legacy system dependency** - Uniface client still in production
3. **No detection** - Problems 1 & 2 at least log errors; Problem 3 is completely silent
4. **Unknown frequency** - Could be causing significant data inconsistency
5. **May not be fully understood** - Requires comprehensive investigation

---

## Current Document Issues

### The Mega-Document Problem

**Current:** `cdc-sync-and-error-scenarios.md` (569 lines)
- Mixes three distinct problems
- Combines problem analysis with solution proposals
- Hard to navigate and reference
- Difficult to assign ownership
- Cannot track progress on individual problems

**Content Breakdown:**
- Lines 1-70: Summary (covers all problems)
- Lines 71-145: Architecture overview (shared context)
- Lines 146-355: Problem 1 analysis (top-down sync)
- Lines 356-492: Problem 2 analysis (CDC event processing)
- Lines 493-541: Open questions
- Lines 542-569: Impact assessment

**Problem 3 mentioned but not analyzed:**
- Line 16: Brief mention of external modifications
- No detailed analysis
- No code evidence
- No impact assessment
- No solution proposals

---

## Proposed Document Structure

### Overview

```
02_Explorations/2026-03-03_cdc-sync-and-error-scenarios/
├── 00_overview.md                                    # Navigation & status
├── 01_problem-distributed-transactions.md            # Problem 1: Top-Down Sync
├── 02_problem-cdc-event-processing-failure.md        # Problem 2: Bottom-Up Sync
├── 03_problem-external-tms-modifications.md          # Problem 3: External Modifications
├── 04_architecture-current-state.md                  # Technical context
├── 05_impact-assessment.md                           # Consequences & risks
└── 06_solution-options.md                            # Remediation patterns
```

### Rationale for Structure

1. **Separation of Concerns** - Each problem gets dedicated analysis
2. **Clear Ownership** - Problems can be assigned to different teams/sprints
3. **Independent Progress** - Solutions can be implemented separately
4. **Shared Context** - Architecture doc supports all problems
5. **Stakeholder-Focused** - Different audiences read different docs
6. **Actionable** - Each doc maps to specific work streams

---

## Document Content Specifications

### Document 0: `00_overview.md`

**Purpose:** High-level navigation and status tracking

**Target Audience:** All stakeholders

**Contents:**
- Three synchronization problems summary (one paragraph each)
- Problem severity matrix
- Document navigation guide
- Status tracking table:
  - Problem identified? ✓
  - Analysis complete?
  - Solution proposed?
  - Implementation in progress?
  - Resolved?
- Quick reference: Which problem applies to which scenario

**Length:** ~2 pages

---

### Document 1: `01_problem-distributed-transactions.md`

**Title:** Problem 1 - Distributed Transaction Failure (Top-Down Sync)

**Purpose:** Detailed analysis of the dual-write anti-pattern

**Target Audience:** Architects, senior developers, technical decision-makers

**Contents:**

#### 1. Problem Statement
- Problem classification: Dual-write anti-pattern
- Complexity assessment: High (Complex)
- Clear description of the issue

#### 2. Affected Business Flows
- Leg/lot assignment to transport order
- Leg/lot unassignment from transport order
- Create transport order from leg/lot
- Delete transport order
- Mark leg as stays loaded
- Any other flows discovered

#### 3. Technical Architecture
- Component interaction diagram
- Sequential execution pattern
- Database contexts involved (AppDbContext, BranchDbContext)
- TMS Bridge GraphQL mutations
- TMS stored procedures

#### 4. Failure Scenario Analysis
- Step-by-step execution flow
- Failure injection points
- What happens when TMS succeeds but New Dispo fails
- Why rollback is difficult/impossible

#### 5. Code Evidence
- `AssignLegToTransportOrderCommandHandler.cs` analysis
- GraphQL request executor patterns
- TMS Bridge mutation implementations
- SaveChangesAsync() vulnerability

#### 6. Constraints That Prevent Rollback
- Network dependency (HTTP call can fail)
- Stateless TMS Bridge (no transaction context)
- Stored procedures don't expose inverse operations
- Temporal gap (time window for other operations)
- No compensation logic implemented

#### 7. Current Behavior
- No error detection
- No rollback attempts
- No retry mechanism
- Systems remain permanently inconsistent

#### 8. Related Files
- List of all relevant source files with line numbers

**Length:** ~5-7 pages

---

### Document 2: `02_problem-cdc-event-processing-failure.md`

**Title:** Problem 2 - CDC Event Processing Failure (Bottom-Up Sync)

**Purpose:** Analysis of event loss due to premature acknowledgment

**Target Audience:** Backend developers, cloud architects, operations

**Contents:**

#### 1. Problem Statement
- Problem classification: Event loss after consumption
- Complexity assessment: Medium (Less complex)
- Clear description of the issue

#### 2. CDC Pipeline Architecture
- Component diagram: TMS DB → Datastream → GCS → Pub/Sub → New Dispo
- Google Cloud services involved
- Push subscription pattern
- CloudEvent format

#### 3. CDC Event Types
- NewShipmentCreated (INSERT on sendung table)
- ShipmentUpdated (UPDATE on sendung table)
- DeletedShipment (DELETE on sendung table)
- Event handlers for each type

#### 4. Event Processing Flow
- HTTP POST to `/api/CDC/consume-event`
- ConsumeEventCommandHandler execution
- Handler resolution
- Keycloak token acquisition
- Event handler execution

#### 5. Failure Scenario Analysis
- Step-by-step execution flow with failure points
- Database unavailability during SaveChanges
- Mapping errors
- Business logic exceptions
- Out of memory / timeout scenarios

#### 6. The Premature Acknowledgment Issue
- Exception caught and logged
- `IsEventSuccess = false` returned
- **HTTP 200 OK sent to Pub/Sub**
- Pub/Sub considers message delivered
- Message will NOT be redelivered
- Event lost forever

#### 7. Code Evidence
- `ConsumeEventCommandHandler.cs:28-60` analysis
- Event handler implementations
- Exception handling pattern
- Response DTO structure

#### 8. Why This Happens
- Misunderstanding of Pub/Sub acknowledgment semantics
- HTTP status code determines acknowledgment, not response body
- Should return HTTP 500/503 on processing failure

#### 9. Current Behavior
- Events consumed successfully (Pub/Sub works correctly)
- Internal processing failures are silent
- No retry mechanism
- No dead letter queue
- No event replay capability

#### 10. Related Files
- CDC controller and handlers
- Pub/Sub service setup
- Event DTO definitions

**Length:** ~4-6 pages

---

### Document 3: `03_problem-external-tms-modifications.md`

**Title:** Problem 3 - External TMS Modifications Invisible to New Dispo

**Purpose:** Analysis of detection gaps for direct TMS database writes

**Target Audience:** Architects, database administrators, operations, business analysts

**Contents:**

#### 1. Problem Statement
- Problem classification: External write detection gap
- Complexity assessment: Unknown (requires investigation)
- Clear description of the issue

#### 2. Sources of External Modifications
- Uniface fat client (legacy TMS client)
- Direct SQL access (DBAs, reporting tools)
- Other system integrations
- Batch jobs and scheduled processes
- Manual data fixes

#### 3. CDC Coverage Analysis (Requires Investigation)
- Which TMS tables have CDC configured?
  - sendung (Shipment) - Known to have CDC
  - Other tables - Status unknown
- Which columns trigger CDC events?
- Are all relevant operations captured?

#### 4. Detection Gap Scenarios
- User creates shipment in Uniface → Does New Dispo see it?
- User modifies transport order in Uniface → Does New Dispo see it?
- DBA runs SQL UPDATE on TMS tables → Does New Dispo see it?
- Batch job updates TMS data → Does New Dispo see it?

#### 5. Business Impact Analysis
- Which business processes use Uniface?
- How often do external modifications occur?
- What data becomes inconsistent?
- User experience implications

#### 6. Current State
- CDC configured only for specific tables/operations
- No reconciliation jobs to detect drift
- No alerting for inconsistencies
- No documentation of CDC coverage

#### 7. Investigation Tasks
- Audit TMS database CDC configuration
- Identify all tables modified by external systems
- Document which operations are visible vs. invisible
- Measure frequency of external modifications
- Interview business users about Uniface usage

#### 8. Questions for Stakeholders
- Is Uniface still in active use? By whom?
- Are there plans to decommission Uniface?
- What other systems write to TMS database?
- Are there business processes that require direct TMS access?

**Length:** ~3-5 pages

**Note:** This document may need significant expansion after investigation.

---

### Document 4: `04_architecture-current-state.md`

**Title:** Current System Architecture - Synchronization Components

**Purpose:** Technical reference documentation supporting all problem analyses

**Target Audience:** Developers, architects

**Contents:**

#### 1. Overall Synchronization Architecture
- High-level diagram showing all sync paths
- Top-down flow (New Dispo → TMS)
- Bottom-up flow (TMS → New Dispo)
- External modification flow (External → TMS)

#### 2. Component Overview
- New Dispo Backend (C# / .NET 8 / Entity Framework)
- TMS Bridge (C# / .NET 8 / GraphQL / HotChocolate)
- TMS Database (PostgreSQL / AlloyDB)
- Google Cloud CDC Pipeline (Datastream, GCS, Pub/Sub)

#### 3. Database Contexts
- AppDbContext (New Dispo database)
- BranchDbContext (TMS database via TMS Bridge)
- Separate database instances
- No distributed transaction support

#### 4. TMS Bridge GraphQL API
- Mutation definitions
- Stored procedure mappings
- Request/response patterns
- Error handling approach

#### 5. TMS Database Interfaces
- Stored procedure packages (pDIS_*)
- CreateTransportOrderFromLeg
- AddLeg / AddShipment
- Delete
- StaysLoaded
- Input/output parameters

#### 6. CDC Pipeline Architecture
- Google Datastream configuration
- Cloud Storage bucket
- Pub/Sub topic and push subscription
- CloudEvent message format
- Endpoint authentication

#### 7. Technology Stack
- Language: C# / .NET 8
- Database: PostgreSQL / AlloyDB
- API: GraphQL (HotChocolate)
- ORM: Entity Framework Core
- Cloud: Google Cloud Platform
- CDC: Google Datastream
- Messaging: Google Pub/Sub

#### 8. Related File Reference
- Complete list of relevant files organized by component
- Line number references for key code sections

**Length:** ~4-6 pages

---

### Document 5: `05_impact-assessment.md`

**Title:** Impact Assessment - Consequences of Synchronization Failures

**Purpose:** Business and operational consequences of the three problems

**Target Audience:** Product owners, operations, management, architects

**Contents:**

#### 1. Impact Matrix

| Problem | Data Inconsistency | User Impact | Operational Impact | Business Risk |
|---------|-------------------|-------------|-------------------|---------------|
| Problem 1 | TMS has assignment, New Dispo doesn't | Users see incomplete transport orders | Manual SQL fixes required | Medium-High |
| Problem 2 | TMS has shipment, New Dispo doesn't | Shipments invisible in New Dispo | Event lost forever, cannot replay | High |
| Problem 3 | TMS modified externally, New Dispo unaware | Data appears stale/incorrect | Unknown scope, undetected | Unknown (High?) |

#### 2. Problem 1: Distributed Transaction Failure Impact
- TMS database contains the change
- New Dispo database missing corresponding entities
- Foreign key references point to non-existent New Dispo records
- TMS shows leg assigned, New Dispo shows unassigned
- Users cannot see accurate transport order state
- Planning decisions based on incomplete data
- Manual recovery requires database expertise
- No automatic detection or alerting

#### 3. Problem 2: CDC Event Loss Impact
- TMS shipment exists but invisible to New Dispo users
- Legs and lots never created in New Dispo
- Planning cannot include these shipments
- Event permanently lost (cannot replay)
- Silent failure (operators unaware)
- Accumulates over time (drift increases)
- No recovery procedure exists

#### 4. Problem 3: External Modification Impact
- Scope unknown (requires investigation)
- Potentially largest source of inconsistency
- Business processes may depend on Uniface
- Users working in two systems simultaneously
- Confusion about source of truth
- Data staleness unknown
- Cannot quantify risk without CDC audit

#### 5. Common Characteristics
- **Silent Failures:** No user-facing errors
- **No Detection:** No monitoring or alerting
- **No Recovery:** No automated fix mechanisms
- **Data Drift:** Inconsistency accumulates over time
- **Operational Burden:** Manual fixes require deep system knowledge

#### 6. User Experience Impact
- Incomplete information displayed
- Actions may fail unexpectedly
- Trust in system accuracy eroded
- Need to verify data in multiple systems
- Frustration with system reliability

#### 7. Operational Impact
- No runbooks for recovery
- Manual SQL required (error-prone)
- Support tickets difficult to diagnose
- No tools to detect inconsistencies
- Incident resolution time high

#### 8. Business Risk Assessment
- Data integrity compromised
- Planning accuracy reduced
- Customer service impact
- Potential compliance issues (audit trail incomplete)
- Technical debt accumulation

#### 9. Questions for Operations
- How often do these failures actually occur in production?
- What is the current incident rate?
- Is there a manual recovery process?
- Where are errors currently logged?
- Is there centralized error tracking?
- Are operators aware of these issues?
- What monitoring exists today?

**Length:** ~3-4 pages

---

### Document 6: `06_solution-options.md`

**Title:** Solution Options - Architectural Remediation Patterns

**Purpose:** Evaluated solution approaches for all three problems

**Target Audience:** Architects, technical leads, decision-makers

**Contents:**

#### 1. Solution Strategy Overview
- Short-term (Quick wins, <= 1 sprint)
- Medium-term (Significant implementation, 2-4 sprints)
- Long-term (Architectural changes, > 4 sprints)
- Independent vs. coordinated solutions

#### 2. Problem 1 Solutions: Distributed Transaction Patterns

**Option A: Saga Pattern (Orchestration)**
- Description: Explicit compensation logic
- Implementation approach
- Pros: Clear audit trail, centralized coordination
- Cons: Complex, requires saga state persistence
- Effort: High
- Risk: Medium

**Option B: Outbox Pattern**
- Description: Local outbox table for TMS operations
- Implementation approach
- Pros: Leverages local transactions, reliable delivery
- Cons: Eventual consistency, background worker needed
- Effort: Medium
- Risk: Low

**Option C: Event Sourcing**
- Description: Store all operations as events
- Implementation approach
- Pros: Complete audit trail, replay capability
- Cons: Significant architectural change
- Effort: Very High
- Risk: High

**Option D: Two-Phase Commit (2PC)**
- Verdict: Not recommended
- Reasons: Blocking protocol, not supported in architecture

**Recommendation:** Start with Outbox Pattern (Option B)

#### 3. Problem 2 Solutions: CDC Event Processing Reliability

**Option A: Pub/Sub Retry + Dead Letter Topic (RECOMMENDED)**
- Description: Proper HTTP error codes + GCP retry infrastructure
- Implementation:
  - Return HTTP 500/503 on processing failure
  - Configure Pub/Sub retry policy with exponential backoff
  - Set up dead letter topic
  - Create dead letter consumer for manual review
- Code changes required: Minimal (throw exception instead of catching)
- Effort: Low
- Risk: Low
- Timeline: 1 sprint

**Option B: Event Store Pattern**
- Description: Persist all CDC events before processing
- Implementation approach
- Pros: Complete event history, replay capability
- Cons: Additional storage, background retry job
- Effort: Medium
- Risk: Low

**Option C: Idempotent Handlers + Deduplication**
- Description: Store processed event IDs
- Implementation approach
- Pros: Safe retries, prevents duplicates
- Cons: All handlers must be idempotent
- Effort: Medium
- Risk: Medium

**Recommendation:** Implement Option A immediately, then add Option B and C incrementally

#### 4. Problem 3 Solutions: External Modification Detection

**Phase 1: Investigation (1 sprint)**
- Audit TMS database CDC configuration
- Document all tables with/without CDC
- Identify external write sources
- Measure modification frequency
- Interview business users

**Option A: Expand CDC Coverage**
- Enable CDC on additional TMS tables
- Configure events for all relevant operations
- Effort: Low-Medium (depends on findings)
- Risk: Low

**Option B: Periodic Reconciliation Jobs**
- Background job compares TMS vs. New Dispo
- Detect and alert on inconsistencies
- Optional: Automatic sync repair
- Effort: Medium
- Risk: Low

**Option C: Read-Through Cache Pattern**
- New Dispo queries TMS for missing data on-demand
- Cache results locally
- Effort: Medium-High
- Risk: Medium

**Option D: Restrict Direct TMS Access**
- Force all modifications through New Dispo/TMS Bridge
- Decommission Uniface (if possible)
- Effort: Depends on business process changes
- Risk: High (business disruption)

**Recommendation:** Phase 1 investigation first, then decide based on findings

#### 5. Cross-Cutting Solutions: Monitoring & Observability

**Metrics to Track:**
- CDC event processing success/failure rate
- TMS Bridge call success/failure rate
- AppDbContext SaveChanges failure rate
- Average sync latency
- Inconsistency detection counts

**Alerting Strategy:**
- Alert on error rate thresholds
- Alert on sync latency increase
- Alert on inconsistency detection
- PagerDuty integration for critical issues

**Structured Logging:**
- Correlation IDs across TMS Bridge + New Dispo operations
- Log all sync operations with status
- Include relevant entity IDs for troubleshooting
- Centralized log aggregation (Stackdriver)

**Health Checks:**
- Periodic reconciliation jobs
- Compare TMS vs. New Dispo counts
- Checksum validation
- Alert on discrepancies

**Dashboards:**
- Real-time sync health overview
- Error rate trends
- Latency metrics
- Inconsistency counts

**Effort:** Medium
**Risk:** Low
**Timeline:** 2 sprints
**Priority:** High (should implement alongside other solutions)

#### 6. Implementation Roadmap

**Sprint 1-2: Quick Wins**
- Fix CDC error handling (Problem 2, Option A)
- Implement basic monitoring and alerting
- Conduct Problem 3 investigation

**Sprint 3-5: Medium-Term Solutions**
- Implement Outbox Pattern for critical flows (Problem 1)
- Set up CDC event store (Problem 2, Option B)
- Expand CDC coverage based on audit (Problem 3)

**Sprint 6-8: Long-Term Solutions**
- Complete Outbox Pattern for all flows
- Implement idempotent event handlers
- Build reconciliation jobs
- Enhanced monitoring and dashboards

**Sprint 9+: Architectural Evolution**
- Consider Event Sourcing migration
- Evaluate Uniface decommissioning
- Continuous improvement

#### 7. Decision Matrix

| Solution | Problem | Effort | Risk | Impact | Priority |
|----------|---------|--------|------|--------|----------|
| Pub/Sub Retry + DLQ | 2 | Low | Low | High | **P0 (Immediate)** |
| Monitoring & Alerting | All | Medium | Low | High | **P0 (Immediate)** |
| CDC Coverage Audit | 3 | Low | Low | Medium | **P1 (Sprint 1)** |
| Outbox Pattern | 1 | Medium | Low | High | **P1 (Sprint 2-3)** |
| Event Store | 2 | Medium | Low | Medium | **P2 (Sprint 4)** |
| Reconciliation Jobs | 3 | Medium | Low | Medium | **P2 (Sprint 5)** |
| Idempotent Handlers | 2 | Medium | Medium | Medium | **P3 (Sprint 6+)** |
| Event Sourcing | 1 | Very High | High | High | **P4 (Long-term)** |

#### 8. Testing Strategy
- Integration tests simulating failure scenarios
- Compensation logic testing
- Retry mechanism validation
- Idempotency verification
- Load testing with failures
- Chaos engineering for resilience testing

**Length:** ~8-10 pages

---

## Implementation Plan for Document Separation

### Phase 1: Create Document Structure (1 day)
1. Create 7 markdown files in exploration folder
2. Set up templates with headers and TOC placeholders
3. Add cross-references between documents

### Phase 2: Extract and Refactor Content (2-3 days)
1. **Extract to Document 0:** Create overview with problem summaries
2. **Extract to Document 1:** Move lines 146-355 (top-down sync analysis)
3. **Extract to Document 2:** Move lines 356-492 (CDC event analysis)
4. **Extract to Document 3:** Create new content based on exploration request + investigation notes
5. **Extract to Document 4:** Move lines 71-145 (architecture) + expand
6. **Extract to Document 5:** Move lines 542-569 (impact) + expand
7. **Extract to Document 6:** Move content from `potential-solutions.md` + expand

### Phase 3: Review and Validate (1 day)
1. Ensure no content duplication
2. Validate cross-references
3. Check that each document is self-contained
4. Verify technical accuracy
5. Get stakeholder review

### Phase 4: Archive Original Document
1. Rename `cdc-sync-and-error-scenarios.md` to `_archived_original_analysis.md`
2. Add note at top pointing to new document structure
3. Update any external references

### Total Effort: ~4-5 days

---

## Benefits of Document Separation

### For Developers
- Find relevant information quickly
- Understand specific problems without distraction
- Clear code references for each issue
- Know which problem to fix first

### For Architects
- Evaluate solutions independently
- Assess architectural trade-offs
- Plan incremental improvements
- Make data-driven decisions

### For Operations
- Understand impact of each problem
- Know what to monitor
- Have clear escalation paths
- Execute recovery procedures

### For Management
- Track progress on individual problems
- Allocate resources effectively
- Understand business risk
- Make prioritization decisions

### For Quality
- Each problem has clear acceptance criteria
- Solutions can be tested independently
- Regression testing is focused
- Documentation matches implementation

---

## Success Criteria

### Document Quality
- [ ] Each document is self-contained
- [ ] Cross-references work correctly
- [ ] No duplicate content
- [ ] Technical accuracy verified
- [ ] Code references are correct
- [ ] Diagrams are clear

### Completeness
- [ ] All three problems documented
- [ ] Current state analysis complete
- [ ] Impact assessment comprehensive
- [ ] Solution options evaluated
- [ ] Implementation plan exists

### Usability
- [ ] Developers can find information quickly
- [ ] Each document has clear purpose
- [ ] Navigation is intuitive
- [ ] Stakeholders approve structure
- [ ] Team adopts new structure

### Actionability
- [ ] Problems can be assigned to teams
- [ ] Solutions can be prioritized
- [ ] Progress can be tracked
- [ ] Success can be measured
- [ ] Decisions can be documented

---

## Next Steps

1. **Get Approval:** Review this analysis with stakeholders
2. **Prioritize Problem 3 Investigation:** Unknown scope is a risk
3. **Create Document Structure:** Set up the 7 files
4. **Extract Content:** Move content from mega-document
5. **Expand Problem 3:** Conduct CDC coverage audit
6. **Review and Publish:** Get team sign-off
7. **Begin Implementation:** Start with P0 solutions (CDC error handling + monitoring)

---

## Appendix: Document Cross-Reference Map

### Reading Order by Audience

**Executive / Management:**
1. `00_overview.md` - Understand the three problems
2. `05_impact-assessment.md` - Business consequences
3. `06_solution-options.md` - Implementation roadmap section

**Architects:**
1. `00_overview.md` - Problem summary
2. `04_architecture-current-state.md` - Technical context
3. `01_problem-distributed-transactions.md` - Problem 1 deep dive
4. `02_problem-cdc-event-processing-failure.md` - Problem 2 deep dive
5. `03_problem-external-tms-modifications.md` - Problem 3 deep dive
6. `06_solution-options.md` - Solution evaluation

**Developers (Problem 1 - Distributed Transactions):**
1. `01_problem-distributed-transactions.md` - Problem analysis
2. `04_architecture-current-state.md` - Reference architecture
3. `06_solution-options.md` - Section: Problem 1 Solutions

**Developers (Problem 2 - CDC Events):**
1. `02_problem-cdc-event-processing-failure.md` - Problem analysis
2. `04_architecture-current-state.md` - CDC pipeline architecture
3. `06_solution-options.md` - Section: Problem 2 Solutions

**Operations:**
1. `00_overview.md` - What are we dealing with?
2. `05_impact-assessment.md` - What happens when things break?
3. `06_solution-options.md` - Section: Monitoring & Observability

**QA / Testing:**
1. `01_problem-distributed-transactions.md` - What to test
2. `02_problem-cdc-event-processing-failure.md` - What to test
3. `06_solution-options.md` - Section: Testing Strategy

---

## Conclusion

The current mega-document combines three distinct architectural problems that should be separated for clarity, actionability, and independent progress tracking. The proposed 7-document structure provides:

1. **Clear problem definition** - Each problem documented independently
2. **Shared technical context** - Architecture document supports all problems
3. **Comprehensive impact analysis** - Business consequences understood
4. **Evaluated solutions** - Options with pros/cons/effort/risk
5. **Actionable roadmap** - Prioritized implementation plan

**Recommendation:** Proceed with document separation and prioritize Problem 3 investigation (CDC coverage audit) as the scope and severity are currently unknown.

---

**End of Analysis**
