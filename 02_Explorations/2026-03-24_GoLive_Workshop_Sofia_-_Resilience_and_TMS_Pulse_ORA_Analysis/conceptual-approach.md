# Transactional Resilience: Conceptual Approach

**Date:** 2026-03-25
**Status:** Draft for Review
**Target:** June 2026 Go-Live
**Focus:** High-level architectural approach

---

## Executive Summary

This document presents the **conceptual approach** for preventing data inconsistency between New Dispo and TMS databases. The approach adapts the **Transactional Outbox Pattern** using the **"Red Arrow"** principle from the workshop: **commit local intent before calling external systems**.

**For implementation details, see:** [`implementation-proposal.md`](./implementation-proposal.md)

---

## The Problem

### Scenario 2: Local DB Failure After TMS Success

**Current Flow (Vulnerable):**
```
User Request
    ↓
[1] Call TMS ──────────→ TMS Database (Execute SQL) ✅
    ↓                   Returns: transportOrderId=987654, legId=333
    ↓
[2] Create LotAssignment (transportOrderId=987654)
    Save to New Dispo DB ❌ FAILS (database unavailable)

❌ Result: TMS has transport order 987654
          New Dispo has NOTHING
          → DATA OUT OF SYNC (no recovery mechanism)
```

**Why This Happens:**
- Line 59 in `CreateTransportOrderFromLotCommandHandler.cs`: TMS call succeeds
- Line 99: `SaveChangesAsync()` fails (database unavailable, timeout, constraint violation)
- No rollback mechanism for TMS (distributed transaction not feasible)
- No record of user intent (cannot retry)

---

## TMS Function Contract

Understanding what must be preserved across the distributed transaction:

### Input Parameters: `pdis_transportorder.createtransportorderfromleg()`

| Parameter | Type | Example | Purpose |
|-----------|------|---------|---------|
| `company` | INT | `1` | Company ID |
| `branch` | INT | `100` | Branch ID |
| `performanceDate` | DATE | `2026-03-25` | User-selected date |
| `transportMode` | INT? | `60` or `NULL` | Transport type (60=pickup) |
| `shipmentId` | BIGINT | `12345678` | TMS shipment ID from leg |
| `legType` | VARCHAR | `"VL"` or `"HL"` | Leg type |

**Multi-leg operations:**
- First leg: `createtransportorderfromleg()` (creates TO + adds first leg)
- Additional legs: `createandaddleg()` (adds leg to existing TO)

### Return Values: TMS-Generated IDs

| Field | Type | Used In | Purpose |
|-------|------|---------|---------|
| `TransportOrderId` | BIGINT | `LotAssignmentEntity` | Links to TMS transport order |
| `PickupPointId` | BIGINT | `LotAssignmentEntity` | Links to TMS tour point |
| `DeliveryPointId` | BIGINT | `LotAssignmentEntity` | Links to TMS tour point |
| `LegId` | BIGINT | `LotAssignmentLegLinkEntity` | Links to TMS leg |

**The Challenge:** These IDs must be stored in New Dispo DB to maintain referential integrity. If the local save fails after TMS succeeds, we lose these IDs and cannot complete the operation.

---

## The Red Arrow Principle

### Workshop Insight

The workshop image shows a **red "Start Transaction" arrow** pointing to New Dispo DB **before** the TMS call:

```
┌──────────────────────────────────────────────────────────────┐
│ ⚡ Start Transaction (Red Arrow)                              │
│   ↓                                                           │
│ ┌─────────────────────────────────────────┐                  │
│ │ Commit to New Dispo DB FIRST            │ ← Atomic safety  │
│ └─────────────────────────────────────────┘                  │
│   ↓                                                           │
│ Synchronize to TMS (After local commit) → Safe to fail/retry │
└──────────────────────────────────────────────────────────────┘
```

### Core Principle

> **"Commit local intent atomically BEFORE calling external systems"**

This is a fundamental distributed systems pattern:
1. **Local First:** Persist to your own database with ACID guarantees
2. **External Later:** Call external systems (which may fail) with retry capability
3. **Eventual Consistency:** External systems catch up via retry mechanism

### Risk Inversion

| Approach | Failure Scenario | Result |
|----------|------------------|--------|
| **Old Way** | TMS succeeds → Local DB fails | OUT OF SYNC ❌ |
| **Minimal Outbox** | Local DB succeeds → TMS fails | RECOVERABLE ✅ |

The key: If local state is committed first, we have a **persistent record of user intent** that survives any subsequent failure.

---

## What "Local DB Succeeds" Means

**CRITICAL CLARIFICATION:**

"Local DB succeeds" does NOT mean the full business logic (LotAssignment) is complete.

It means: **Outbox entry committed** = User intent is persisted

### Two-Transaction Pattern

```
[Transaction 1: RED ARROW - Store Intent]
  Create Outbox Entry
    - Payload: All TMS input parameters (company, branch, shipmentId, etc.)
    - Status: Pending
    - TmsResponse: NULL (not called yet)
  COMMIT ✅
  ↓
  User intent is now GUARANTEED SAFE
  ↓

[External Call]
  Call TMS → Get transportOrderId, legIds, tourPointIds
  ↓

[Transaction 2: Complete Business Logic]
  Create LotAssignment (with TMS IDs)
  Update Outbox
    - Status: Completed
    - TmsResponse: {transportOrderId, legIds, tourPointIds}
  COMMIT ✅
```

**What This Protects:**

| Failure Point | Old Way | Minimal Outbox |
|---------------|---------|----------------|
| Before any DB write | Fail fast ✅ | Fail fast ✅ |
| TMS call fails | No record ❌ | Outbox has Payload → Retry ✅ |
| TMS succeeds, local save fails | OUT OF SYNC ❌ | Outbox has TmsResponse → Retry ✅ |

---

## Solution Approaches

### Three Options Evaluated

#### Option 1: Status Flag on Business Entity

**Concept:** Add `TmsSyncStatus` column to `LotAssignmentEntity`

**Pros:**
- Simplest (just one column)
- Implements red arrow principle

**Cons:**
- No audit trail
- Can't retry (no stored operation parameters)
- Pollutes business entities with technical sync concerns

**Verdict:** ❌ Insufficient for transport order creation (complex, multi-step operation)

---

#### Option 2: Lightweight Sync Tracking Table

**Concept:** Separate table tracking sync status per entity

**Schema Concept:**
```
TmsSyncTracking:
  - EntityId (UUID)
  - EntityType (VARCHAR)
  - SyncStatus (VARCHAR)
  - TmsResponse (JSONB)
  - ErrorMessage (TEXT)
```

**Pros:**
- Cleaner separation
- Can query "all pending syncs"
- Stores TMS response for idempotency

**Cons:**
- No operation payload (can't recreate TMS call)
- Updates overwrite state (no history)
- Hard to retry without original parameters

**Verdict:** ⚠️ Better than Option 1, but incomplete (needs payload for retry)

---

#### Option 3: Transactional Outbox Pattern (Simplified)

**Concept:** Store operation intent + TMS response in dedicated outbox table

**Schema Concept:**
```
TmsSyncOutbox:
  - Id (UUID)
  - OperationType (VARCHAR) ← "CreateTransportOrder"
  - Payload (JSONB) ← TMS input parameters
  - TmsResponse (JSONB) ← TMS output IDs
  - Status (VARCHAR)
  - ErrorMessage (TEXT)
  - AttemptCount (INT)
  - Timestamps
```

**Pros:**
- ✅ Implements red arrow (commit payload first)
- ✅ Stores full operation context (Payload = TMS inputs)
- ✅ Enables idempotent retry (TmsResponse = TMS outputs)
- ✅ Full audit trail (append-only)
- ✅ Support-friendly (can see exactly what happened)
- ✅ Foundation for future automation

**Cons:**
- More complex than Options 1-2
- Requires careful design

**Verdict:** ✅ **Recommended** - Only option that fully solves the problem

---

## Outbox Pattern: What It Provides

### 1. Persistent User Intent (Payload)

**Before TMS call**, commit:
```json
{
  "lotId": "uuid",
  "performanceDate": "2026-03-25",
  "transportMode": 60,
  "legs": [
    {
      "company": 1,
      "branch": 100,
      "shipmentId": 12345678,
      "legType": "VL"
      // ... all fields needed for createtransportorderfromleg()
    }
  ]
}
```

**Purpose:** If TMS call fails, we can recreate it from payload

### 2. Persistent TMS Response (TmsResponse)

**After TMS call succeeds**, store:
```json
{
  "transportOrderId": 987654,
  "pickupPointId": 111,
  "deliveryPointId": 222,
  "legs": [
    {"legId": 333, "shipmentId": 12345678}
  ]
}
```

**Purpose:** If local save fails, we can complete it using these IDs (no TMS call needed)

### 3. Idempotent Retry

**Retry Logic:**
```
IF TmsResponse exists in outbox:
  → Use existing IDs (TMS already succeeded)
  → Create LotAssignment with stored IDs
  → No duplicate transport order ✅
ELSE:
  → Query TMS: Does transport order exist for this lot/date?
  → IF exists: Use existing IDs
  → IF not exists: Create new (idempotent)
```

---

## Why Outbox vs. Manual Recovery

### Workshop Decision: Manual Recovery

**Original Characteristics:**
- User-initiated retry
- Idempotency
- State checking
- Logging
- Support escalation

**Our Enhancement:**
- ✅ All of the above
- **PLUS:** Persistent outbox table (audit trail + retry capability)
- **PLUS:** Structured state machine (Pending/Processing/Completed/Failed)
- **PLUS:** Foundation for future automation

### What We're NOT Doing (Rejected at Workshop)

**Full Outbox Pattern (Automatic):**
- ❌ Background worker with infinite retries
- ❌ Exponential backoff
- ❌ Dead letter queue
- **Reason:** 3-4 months work, June timeline constraint

**Saga Pattern (Compensating Transactions):**
- ❌ Rollback TMS if local DB fails
- **Reason:** "Most complex distributive pattern", risky to delete from TMS

**Distributed Transaction (2PC):**
- ❌ Not feasible across TMS Bridge API boundary

---

## Solution Progression (Workshop Image Mapping)

Your workshop image shows:

```
┌──────────────────────────────────────────────────────────────┐
│ Solutions by complexity of implementation                    │
├──────────────────────────────────────────────────────────────┤
│ 1. Service-desk supported resolving                          │
│ 2. User-retry based resolving                                │
│ 3. User-retry based, on locally pending changes, resolving   │ ← WE ARE HERE
│ 4. Full Outbox Pattern                                       │
└──────────────────────────────────────────────────────────────┘
```

**Our Solution = Level 3:**
- ✅ **"Locally pending changes"** = Outbox entries with Status='Pending'
- ✅ **Red arrow** = Changes committed locally BEFORE calling TMS
- ✅ **User-retry** = User-initiated recovery from persistent state
- 🔮 **Level 4** = Post-go-live enhancement (background processor)

---

## Community Best Practices

### 1. Transactional Outbox Pattern

**Source:** Martin Fowler, Microservices.io (Chris Richardson)

**Definition:**
> "A service that uses a relational database inserts messages/events into an outbox table as part of the local transaction. A separate process publishes the events."

**Our Adaptation:**
- ✅ Outbox table in same database (transactional guarantee)
- ✅ Payload stored in JSONB (flexibility)
- ⚠️ **Simplified:** Synchronous processing for v1 (not separate process)
- ⚠️ **Simplified:** Single retry (not infinite with backoff)

**Why Simplified:** June timeline, limited operation types, support team available

### 2. Idempotency

**Source:** Stripe API, AWS Best Practices

**Principle:**
> "Ensure operations can be safely retried without side effects. Use idempotency keys to deduplicate requests."

**Our Implementation:**
- Outbox ID as idempotency key
- State checking before retry (query TMS first)
- Immutable outbox records (status updates only)

### 3. Red Arrow = Event Sourcing Lite

**Principle:**
> "Store the intent to perform an action, not just the result"

**Traditional Event Sourcing:** Store every state change as immutable event
**Our Simplified Version:** Store operation intent in outbox, execute, update status

---

## Success Criteria

### For June Go-Live

- ✅ Zero data inconsistencies (validated by reconciliation script)
- ✅ <5% operations require user retry (normal network conditions)
- ✅ <1% operations require support intervention
- ✅ Support team can resolve failures within 15 minutes
- ✅ No frontend UX confusion

### Post-Go-Live Evolution (Q3 2026)

- Background outbox processor (automatic retry)
- Exponential backoff with max 5 retries
- Dead letter queue for persistent failures
- TMS-level idempotency keys
- Circuit breaker for TMS Bridge failures
- Real-time sync status (WebSocket)

---

## Open Questions for Team

### Technical Decisions

1. **TMS Bridge Idempotency:**
   - Can Joachim's team add `idempotency_key` column to TMS database?
   - Timeline for TMS Bridge changes?
   - Fallback: Application-level state checking (query-based)?

2. **Retry Policy:**
   - How many retries before "Contact Support"? (Recommendation: 1)
   - Automatic or user-initiated? (Recommendation: user-initiated for v1)

3. **Multi-User Visibility:**
   - Should other users see "pending" transport orders?
   - Recommendation: Show only after completion (avoid confusion)

### Assumptions to Validate

- ✅ TMS Bridge latency <5s (validated in existing flows)
- ⚠️ New Dispo DB failures are transient (need confirmation)
- ⚠️ Support team can manually create `LotAssignmentEntity` (need training)
- ✅ Users willing to wait 2-5 seconds (acceptable UX)

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Outbox table grows indefinitely | High | Background cleanup (delete completed >30 days) |
| User abandons retry | Medium | Support dashboard shows all failed entries |
| TMS query inaccurate | High | Validation query before final commit |
| Concurrent retries | Medium | Lock outbox entry during processing |
| Database failure during outbox creation | Low | Fail fast, no side effects |

---

## Next Steps

1. **Team Review (This Week):**
   - Review conceptual approach with Sofia team
   - Confirm alignment with workshop consensus
   - Get sign-off from Patrick (business stakeholder)

2. **Technical Spike (Week 1):**
   - Validate approach with prototype
   - See [`implementation-proposal.md`](./implementation-proposal.md) for details

3. **TMS Team Coordination (Week 1-2):**
   - Meet with Joachim about idempotency options
   - Clarify TMS query capabilities

---

## References

**Community Patterns:**
- [Martin Fowler - Transactional Outbox](https://martinfowler.com/articles/patterns-of-distributed-systems/transactional-outbox.html)
- [Chris Richardson - Microservices.io Saga](https://microservices.io/patterns/data/saga.html)
- [Stripe API - Idempotency](https://stripe.com/docs/api/idempotent_requests)
- [AWS - Idempotent APIs](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/)

**Project Documentation:**
- Workshop Meeting Notes: `00_Meetings/2026-03-19_GoLive Workshop - Sofia - New Dispo/`
- Current Flow: `07_Diagrams/Architecture/transport-order-creation-flow.md`
- Failure Scenarios: `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/tms-sync-failure-scenarios.md`
- Resilience Analysis: [`resilience-transactional-behaviour.md`](./resilience-transactional-behaviour.md)

---

**Document Owner:** Matthias (Virtual Architect)
**Last Updated:** 2026-03-25
**Next Review:** After team discussion (TBD)
