# Project: CDC Error Flow Solution Design

**Status:** 🟡 Solution Selection Pending
**Start Date:** 2026-03-17
**Target Completion:** TBD (pending solution selection)
**Last Updated:** 2026-03-17

---

## Overview

**Goal:** Implement reliable error handling and retry mechanism for CDC event processing to prevent data loss and ensure New Dispo stays synchronized with TMS database.

**Problem:** CDC events are currently consumed but lost forever if internal processing fails. The system returns HTTP 200 OK even on failures, causing Google Pub/Sub to acknowledge messages prematurely without retry.

**Impact:**
- Data loss: TMS changes invisible in New Dispo
- System out of sync
- No automatic recovery mechanism
- Silent failures without operator visibility

**Original Issue:** Identified by Yosif in meeting `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`

---

## Current Status

### Solution Selection Phase

Team refinement scheduled to select from four solution options:

| Option | Risk | Status |
|--------|------|--------|
| **A: Fix Push + Dead Letter Topic** ⭐ | Low | Recommended |
| **B: Pull Subscription** | Medium | Strategic alternative |
| **C: Idempotent Handlers** | Medium | Complementary |
| **D: Event Store** | Low | Alternative |

**Decision Point:** Team refinement required to select approach based on risk/benefit trade-off.

---

## Timeline

### Phase 1: Solution Selection & Design
- **Status:** In Progress
- Team refinement session (scheduled)
- Solution selection decision
- Technical design approval
- Infrastructure impact assessment

### Phase 2: Implementation (TBD based on solution)
- **Status:** Not Started
- Timeline depends on selected solution

### Phase 3: Testing & Validation (TBD)
- **Status:** Not Started
- Integration tests
- Failure scenario validation
- Monitoring setup

### Phase 4: Deployment & Monitoring (TBD)
- **Status:** Not Started
- Test environment deployment
- Production deployment
- 1-week monitoring period

---

## Solution Options

### Option A: Fix Push + Dead Letter Topic (Recommended)

**Approach:** Return HTTP 500/503 on failure + configure Pub/Sub retry policy

**Risk:** Low

**Implementation:**
- Modify `ConsumeEventCommandHandler.cs` to throw on failure
- Configure Pub/Sub subscription retry policy (max 5 attempts, exponential backoff)
- Create dead letter topic
- Implement dead letter queue consumer

**Pros:**
- Minimal code changes
- Uses GCP native features
- Quick win with high impact
- Solves 90% of transient failures

**Documentation:** [problem-2-solutions.md](problem-2-solutions.md#option-a-pubsub-dead-letter-topic--retry-logic)

---

### Option B: Switch to Pull Subscription

**Approach:** Backend pulls messages from Pub/Sub with explicit acknowledgment control

**Risk:** Medium

**Implementation:**
- Convert Pub/Sub subscription from push to pull
- Implement background pull worker service (`CdcPullWorkerService`)
- Deploy as Cloud Run Job or GKE deployment
- Explicit Ack/Nack on success/failure

**When to Choose:**
- Need explicit backpressure control
- Moving to GKE/always-on infrastructure
- Strategic reasons beyond solving Problem 2

**Documentation:** [problem-2-solutions.md](problem-2-solutions.md#option-d-switch-from-push-to-pull-subscription)

---

### Option C: Idempotent Event Handlers + Deduplication

**Approach:** Make handlers idempotent and store processed event IDs

**Risk:** Medium

**Implementation:**
- Audit all event handlers for idempotency
- Design `ProcessedEvents` schema
- Implement deduplication logic
- Extract unique event IDs from CDC metadata

**Note:** Complements Option A or B (enables safe retries)

**Documentation:** [problem-2-solutions.md](problem-2-solutions.md#option-c-idempotent-event-handlers--event-deduplication)

---

### Option D: Event Store for CDC Events

**Approach:** Persist all CDC events before processing

**Risk:** Low

**Implementation:**
- Design `CdcEventLog` schema
- Store raw CDC event before processing
- Mark as Pending/Processed/Failed
- Background job retries failed events
- Manual replay tool

**Pros:**
- Complete CDC event history
- Audit trail
- Manual recovery possible

**Documentation:** [problem-2-solutions.md](problem-2-solutions.md#option-b-event-store-for-cdc-events)

---

## Team

**Decision Makers:**
- Product Owner: TBD
- Technical Lead: TBD

**Engineering:**
- Backend Team: Implementation
- DevOps/Platform: Infrastructure configuration (Pub/Sub, monitoring)

**Stakeholders:**
- Operations: Dead letter queue handling procedures
- QA: Failure scenario testing

---

## Documentation

### Analysis Documents
- [Problem Analysis](problem-2-cdc-event-processing-failure.md) - Technical deep dive into the issue
- [Solution Options](problem-2-solutions.md) - Four solution approaches with trade-offs
- [User Story](Backlog/refined-story.md) - Technical user story for team refinement

### Related Projects
- [Transactional Behaviour Project](../2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/) - Problem 1 (Top-down sync)

---

## Completed

- ✅ Problem analysis documented
- ✅ Four solution options evaluated
- ✅ Technical user story created
- ✅ Documentation prepared for team refinement
- ✅ Effort estimates completed
- ✅ Risk assessment completed

---

## In Progress

- 🔄 Team refinement session (solution selection pending)
- 🔄 Stakeholder alignment on approach
- 🔄 Infrastructure impact assessment

---

## Next Up

**Immediate (Pending Solution Selection):**
- Schedule team refinement session
- Review solution options with team
- Select solution approach (A, B, C, or D)
- Approve technical design
- Define DoR/DoD criteria

**After Solution Selection:**
- Create implementation plan
- Set up monitoring infrastructure
- Configure Pub/Sub subscription (if Option A)
- Design database schema (if Option D)
- Plan deployment strategy

---

## Blockers

- ⏳ **Solution Selection:** Team refinement required to choose approach
- ⏳ **Timeline Commitment:** Cannot commit timeline until solution selected

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Solution selection delayed | Timeline slip | Pre-documented all options with recommendations |
| Retries cause duplicate processing | Data corruption | Consider Option C (idempotency) in follow-up |
| Dead letter queue requires manual work | Operational overhead | Document procedures, set up alerting |
| Increased Pub/Sub costs | Budget impact | Monitor costs, set reasonable retry limits |
| Pull model complexity (if Option B) | Implementation delay | Only choose if strategic reasons exist |

---

## Success Criteria

- ✅ CDC events automatically retry on transient failures
- ✅ Failed events moved to dead letter queue (not lost)
- ✅ Comprehensive error logging with all required fields
- ✅ Monitoring dashboard shows CDC health metrics
- ✅ Alerts configured for error rates and DLQ depth
- ✅ No data loss during CDC processing failures
- ✅ Operator procedures documented for manual recovery

---

## Metrics

**Target Metrics (Post-Implementation):**
- CDC event success rate: >99%
- Event processing latency: <5 seconds average
- Dead letter queue depth: <10 messages
- Time to recovery (manual): <1 hour

**Monitoring:**
- CDC event processing success/failure rates
- Average event processing latency
- Dead letter queue depth
- Retry count distribution
- Error rate by error type

---

## Notes

- **Recommended Approach:** Option A (Fix Push + Dead Letter Topic) - solves core problem
- **Pull Model:** Option B - Only pursue if strategic infrastructure reasons exist beyond solving Problem 2
- **Complementary Solutions:** Option C (Idempotency) works well with A or B to enable safe retries
- **Long-term Evolution:** Can add Option D (Event Store) and Option C (Idempotency) incrementally

---

## Change Log

- **2026-03-17:** Project created, solution selection phase initiated
