# Resilience - Transactional Behaviour

**Workshop Date:** 2026-03-19
**Analysis Date:** 2026-03-24

## Context & Background

Resilience has been a long-standing topic, with known gaps that were deprioritized last year due to pressure to deliver functional requirements. With the June go-live approaching, addressing these non-functional requirements is now critical and has been communicated to the client as high priority.

**Problem Statement:**
The New Dispo and TMS systems must maintain data synchronization across distributed transactions. When operations span both databases, failures can lead to inconsistent states.

## Three Failure Scenarios

> **📄 Detailed Analysis:** See [TMS Sync Failure Scenarios](../2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/tms-sync-failure-scenarios.md) for complete documentation with sequence diagrams and technical details.

### Scenario 1: Early Failure
- **Description:** Failure occurs before TMS database is touched (e.g., TMS Bridge fails)
- **Impact:** LOW - No sync issue as TMS was never modified
- **Recovery:** Simple restart/retry

### Scenario 2: Local DB Failure After TMS Success
- **Description:** TMS operation succeeds, but New Dispo database fails to commit the change
- **Impact:** HIGH - Systems are out of sync
- **Example:** Leg assignment works on TMS side, but TMS leg ID isn't stored locally
- **Diagram Reference:** See Miro "Scenario 2: Local DB Failure After TMS Success"

### Scenario 3: Feedback Loss from TMS Bridge
- **Description:** TMS database executes successfully, but feedback from TMS Bridge is lost
- **Impact:** HIGH - Systems are out of sync
- **Similar Result:** Same as Scenario 2

## Solution Approaches Evaluated

### ❌ Rejected: Full Outbox Pattern
- **Description:** Would provide automatic background retry with full transactional guarantees
- **Would resolve:** All three error scenarios

**Why Rejected - Original Voices:**

> *"We've asked the question last week already if this is feasible in terms of complexity, amount of work, architectural preparation to be done in the time range of literally two months. The answer was in concerns that it's not possible."*
> (00:19:31-00:19:47, Part 1)

> *"The outbox pattern will take probably months to be stabilised and tested carefully."*
> (00:32:16-00:32:20, Part 1)

> *"It's much better than outbox pattern considering the timelines."*
> (00:32:11, Part 1 - comparing manual recovery)

**Decision:** Descoped for June timeline, already discussed with Patrick (business stakeholder)

### ❌ Rejected: Complete Architecture Redesign
- **Reason:** Even more fundamental work than outbox pattern
- **Description:** Event-driven architecture rethinking entire New Dispo ↔ TMS synchronization
- **Not feasible for June timeline**

### ✅ Selected: Manual Recovery Mechanism

**Core Approach:**
1. **User-Initiated Retry** - When synchronization fails, user sees error with retry option
2. **Idempotency** - Operations must be safely rerunnable without creating duplicates
3. **State Checking** - Before retry, check TMS state to determine what needs to be done
4. **Logging** - Track failed operations for support intervention
5. **Support Escalation** - Unresolved issues go to L2/L3 support team (provided by P3)

**Key Characteristics:**
- Not automatic/self-healing
- Requires user awareness and action
- Builds foundation for future outbox pattern implementation
- Focuses on transient error recovery (network issues, temporary outages)

## Technical Requirements

### Idempotency Implementation
Two approaches discussed:
1. **TMS Database Level:** TMS procedures inherently handle re-execution (less feasible given TMS change velocity)
2. **New Dispo Application-Level:** Check TMS state before re-executing operations
   - Query TMS first: "Was this already done?"
   - Only execute if not already present
   - Use entity IDs and operation context

### Logging Requirements
Must log for failed operations:
- **Entity ID** - Which record failed
- **Operation Type** - What was being attempted
- **Timestamp** - When it failed
- **Context** - Additional information for support

### Limitations & Assumptions Identified

**Will NOT Cover:**
- Long-duration outages (>5-30 minutes) where user abandons retry
- Multiple concurrent user failures (limited visibility for other users)
- Complex multi-user scenarios (20+ users failing simultaneously)
- Permanent data quality issues requiring manual investigation

**Edge Cases Requiring Further Refinement:**
- How to show failure state to other users viewing same records
- Deduplication when same user retries multiple times
- Database outage affecting many operations simultaneously

## Saga Pattern - ❌ REJECTED
- **Description:** Compensating actions for certain failure cases (rollback TMS if New Dispo fails)
- **Example:** Delete TMS record if New Dispo save fails afterward
- **Scope:** Limited set of synchronized operations
- **Initial Suggestion (Part 1):** One team member suggested it could be implemented "in a day" for 3-4 synchronized operations
- **Final Decision (Part 2):** **REJECTED** - Another team member stated:
  - *"Saga pattern is the most complex distributive pattern that exists"*
  - *"I wouldn't go straight ahead with... not implementing the full Saga pattern"* (Timestamp: 00:53:21-00:53:31, Part 2)
- **Status:** **NOT pursuing** - Complexity outweighs benefit for June timeline

## Approach Documentation

**Detailed architectural approach:**
- **[Conceptual Approach](./conceptual-approach.md)** - High-level approach, red arrow principle, pattern comparison
- **[Implementation Proposal](./implementation-proposal.md)** - Code examples, schemas, API endpoints, testing

## Dependencies & Next Steps

**TMS Team (Joachim):**
- Confirm idempotency capabilities of TMS procedures
- Validate retry safety for all synchronized operations

**Development Team:**
- Go through each workflow where atomic operations span both databases
- Create concept for each workflow's failure handling
- Define minimal viable solution
- Document all assumptions and limitations

**Support Team:**
- Define process for checking failed operations log
- Document manual resolution procedures
- Establish escalation paths for complex cases

**Client Communication:**
- Prepare report with assumptions and limitations for approval
- Set expectations about manual intervention requirements
- Define acceptable recovery time for synchronization issues

## Open Questions & Assumptions

### Open Questions
1. Which TMS procedures are idempotent vs. require state checking?
2. What is acceptable recovery time for synchronization failures?
3. How should system handle 20+ concurrent user failures?
4. Should failures be visible to all users or only the originating user?
5. What level of logging detail does support need?
6. Can TMS procedures be safely retried without checking state first?

### Assumptions
1. **Transient errors are primary concern** - Not permanent data quality issues
2. **User will retry within reasonable time** - Not hours/days later
3. **Support team (L2/L3) available** - Can manually resolve complex cases
4. **Single-user isolation acceptable initially** - Multi-user visibility is phase 2
5. **Logging unsuccessful attempts is sufficient** - Don't need full event store
6. **Focus on leg assignment, transport order creation** - Limited synchronized operations

### Limitations Accepted for June
- No automatic background retry
- Limited multi-user failure visibility
- Manual support required for complex cases
- May not handle extended outages (>30 min)
- Edge cases deferred to post-go-live

## Miro Board Artifacts

📋 **[View Full Miro Board (SVG) →](./Miro%20New%20Dispo%202025%20(Internal)%20-%202026-03-19_Workshop-Sofia.svg)**

### Resilience Section
- **Transactional Behaviour Diagram:** Shows Scenario 2 (Local DB Failure After TMS Success)
  - User → New Dispo → New Dispo DB → TMS Bridge → TMS Database
  - Failure point: Database Unavailable after TMS success
  - Result: "TMS updated, New Dispo not updated" → DATA OUT OF SYNC

- **Solution Progression:**
  - Solutions by complexity of implementation
    - Service-desk supported resolving
    - User-retry based resolving
    - User intent handing (locally pending changes, resulting)
    - Full Outbox Pattern
