# Removed Sections from Transactional Resilience Concept

**Note:** These sections were removed from the main concept document for review and potential re-inclusion later.

---

## Removed NFRs

### Performance / Scalability (Removed)

* (NFR-01-01) The system should create transport orders in <5 seconds on average including TMS call and local DB persistence.
* (NFR-01-02) The system should support 100 concurrent transport order creation operations without degradation.

### Reliability (Removed)

* (NFR-02-06) The system should retry TMS query for existing transport order at least 3 times with exponential backoff (1s, 2s, 4s) before failing.

### Constraints (Removed)

* (NFR-08-03) The system must not exceed 2 additional database round-trips compared to current implementation.

---

## Implementation Phases (Removed Section)

### Phase 1: Foundation (Weeks 1-2)

* Database schema migration (`TmsSyncOutbox` table)
* EF Core entity and configuration
* Outbox creation in `CreateTransportOrderFromLotCommandHandler`
* Basic inline processor (synchronous for v1)

### Phase 2: Idempotency (Weeks 3-4)

* Application-level state checking (query TMS for existing transport order)
* Retry logic with TmsResponse preservation
* Duplicate prevention tests

### Phase 3: User Experience (Weeks 5-6)

* Frontend retry button and error dialog
* Status polling endpoint
* Success/failure messaging

### Phase 4: Support & Monitoring (Weeks 7-8)

* Admin dashboard for failed entries
* Support team training and runbook
* Manual intervention endpoint

---

## Deployment Strategy (Removed Section)

* Database migration deployed first (no code changes, table created)
* Backend code deployed with feature flag `TransactionalOutbox=false`
* Gradual rollout:
  1. Enable for 1 test depot
  2. Monitor for 1 week
  3. Enable for 10% of depots
  4. Monitor for 1 week
  5. Enable for all depots

---

## Risk Assessment & Mitigation (Removed Section)

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Outbox table grows indefinitely | Medium | High | Implement cleanup job (delete completed >30 days) |
| TMS query for idempotency inaccurate | Medium | High | Add validation query before final commit, extensive testing |
| User abandons retry | Low | Medium | Support dashboard shows all failed entries, proactive monitoring |
| Concurrent retries cause race condition | Low | Medium | Lock outbox entry with Status='Processing', unit tests |
| TMS Bridge timeout without clear error | Medium | Medium | Implement timeout detection (>30s), mark as "Failed" for retry |
| Migration from synchronous to async breaks existing assumptions | Low | High | Feature flag rollout, comprehensive integration testing |

---

## References (Removed Section)

**Workshop Documentation:**
- Workshop Meeting Notes: `00_Meetings/2026-03-19_GoLive Workshop - Sofia - New Dispo/`
- Resilience Analysis: `02_Explorations/2026-03-24_GoLive_Workshop_Sofia_-_Resilience_and_TMS_Pulse_ORA_Analysis/resilience-transactional-behaviour.md`

**Detailed Design:**
- Conceptual Approach: `02_Explorations/2026-03-24_GoLive_Workshop_Sofia_-_Resilience_and_TMS_Pulse_ORA_Analysis/conceptual-approach.md`
- Implementation Proposal: `02_Explorations/2026-03-24_GoLive_Workshop_Sofia_-_Resilience_and_TMS_Pulse_ORA_Analysis/implementation-proposal.md`
- Visual Flow Diagram: `02_Explorations/2026-03-24_GoLive_Workshop_Sofia_-_Resilience_and_TMS_Pulse_ORA_Analysis/minimal-outbox-solution-diagram.md`

**Current Flow:**
- Transport Order Creation Flow: `07_Diagrams/Architecture/transport-order-creation-flow.md`
- TMS Sync Failure Scenarios: `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/tms-sync-failure-scenarios.md`

**Community Best Practices:**
- [Martin Fowler - Transactional Outbox](https://martinfowler.com/articles/patterns-of-distributed-systems/transactional-outbox.html)
- [Chris Richardson - Microservices.io Saga](https://microservices.io/patterns/data/saga.html)
- [Stripe API - Idempotency](https://stripe.com/docs/api/idempotent_requests)
- [AWS - Idempotent APIs](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/)

---

## Removed Scope Items

### Non-goals (Removed)

* TMS-level idempotency keys (requires TMS Database schema changes)

### Modifiability / Extensibility (Removed)

* (NFR-04-03) The system should enable migration to TMS-level idempotency keys within 2 weeks once TMS Bridge supports it.

### Interface Contracts (Removed)

**Backend → TMS Bridge:**
- Optional enhancement: Add `idempotencyKey` parameter to GraphQL mutations (TBD with Joachim)

---

## Document Metadata (Removed)

**Document Owner:** Matthias (Virtual Architect)
**Last Updated:** 2026-03-25
**Status:** Draft for Review
**Next Review:** Team alignment meeting (TBD)
