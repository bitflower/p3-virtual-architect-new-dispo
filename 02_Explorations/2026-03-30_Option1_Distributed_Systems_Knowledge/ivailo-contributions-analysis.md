# Ivailo's Contributions: Distributed Systems Analysis

**Source:** Meeting 2026-03-30 "New Dispo: Transactional Behaviour"
**Lens:** Option 1 Distributed Systems Patterns

---

## Executive Summary

Ivailo demonstrates deep practical understanding of distributed systems trade-offs. His contributions reveal a consistent philosophy: **minimize complexity by accepting explicit limitations** rather than building incomplete solutions that create false confidence.

---

## 1. Bounded Retry Window

### What Ivailo Said
> "First retry could be 100 millisecond and then second one maybe in one second... maybe we don't retry further because that would like impact user behavior. The user would be blocked for a lot of time and blocking the front end is usually a bad idea."
>
> "Let's try to keep that retry duration short, several seconds at most."

### Distributed Systems Pattern: **Fail-Fast with Bounded Wait**

| Aspect | Ivailo's Position | Theoretical Basis |
|--------|------------------|-------------------|
| Retry attempts | 2 (100ms, 1s) | Prevents retry storms |
| Total duration | "Several seconds" | Bounded blocking preserves UX |
| Beyond limit | Fail to user | Human becomes coordinator |

**Key Insight:** Ivailo implicitly applies **Little's Law** thinking - the number of in-flight requests (users waiting) multiplied by wait time equals system load. By bounding wait time, he prevents cascade overload during degraded conditions.

**Pattern Formalization:**
```
retry_budget = f(user_tolerance, system_capacity)
if elapsed > retry_budget:
    delegate_to_human()  # Rate-limited by human cognition
```

---

## 2. State-Convergent Idempotency

### What Ivailo Said
> "If there is a create operation with an existing record... we can just switch the operation to update rather than actually inserting any data."
>
> "If that's a delete and the record is missing, obviously we skip doing any changes."
>
> "I have a separate table on that regard to explain further this idempotency logic."

### Distributed Systems Pattern: **Operation Morphing / Declarative State Convergence**

Ivailo describes a complete idempotency decision matrix:

| Intended | State | Transformed | Outcome |
|----------|-------|-------------|---------|
| CREATE | Exists | UPDATE | Success |
| CREATE | Missing | CREATE | Success |
| DELETE | Missing | NO-OP | Success |
| DELETE | Exists | DELETE | Success |
| UPDATE | Exists | UPDATE | Success |
| UPDATE | Missing | CREATE (risky) | Context-dependent |

**Key Insight:** This is **CRDT-adjacent thinking** without using that terminology. The operation becomes "ensure state X" rather than "perform action Y" - the system converges regardless of execution order.

**Formal Property:**
```
For any operation sequence [O1, O2, ..., On] and permutation [Oσ(1), Oσ(2), ..., Oσ(n)]:
final_state(O1...On) ≈ final_state(Oσ(1)...Oσ(n))

Where ≈ means "equivalent from business perspective"
```

---

## 3. Database Reliability Hierarchy

### What Ivailo Said
> "We usually have the database much more reliable compared to any application layer that's proxying... such as the TMS bridge."
>
> "Someone could release a new version of TMS bridge and make it unavailable. But we actually rely much more on the database being available."

### Distributed Systems Pattern: **Failure Domain Prioritization**

Ivailo implicitly ranks failure domains by reliability:

```
Most Reliable ─────────────────────────► Least Reliable
     │                                        │
     ▼                                        ▼
  Database                              Application Layer
  (AlloyDB)                             (TMS Bridge)
     │                                        │
     ├── Managed service                      ├── Deployment risk
     ├── Automatic failover                   ├── Code bugs
     └── Google SLA                           └── Version mismatches
```

**Key Insight:** This informs the **Remote-First Write** decision. If TMS Bridge is less reliable than New Dispo DB, writing to TMS first means:
- If TMS fails → clean failure, no state change
- If local DB fails → TMS has data, but local DB almost never fails

**Probability Analysis:**
```
P(TMS fails) >> P(Local DB fails)
Therefore: P(TMS succeeds, Local fails) ≈ rare edge case
```

---

## 4. Complexity Budgeting

### What Ivailo Said
> "This would increase the complexity... we don't want to go with that like local intermediate changes that we somehow report... these are half-baked."
>
> "It's almost like half of the work for the outbox pattern, while with this approach we're rather reducing the effort to in my opinion to let's say 20% of the outbox pattern work."

### Distributed Systems Pattern: **Complexity-Value Trade-off Analysis**

Ivailo provides explicit effort estimates:

| Solution | Effort (% of Outbox) | Capabilities |
|----------|---------------------|--------------|
| Full Outbox | 100% | Automatic retry, background worker, state persistence |
| Intermediate (with table) | 50% | State persistence, but user-driven |
| **Option 1 (chosen)** | **20%** | In-memory retry, user-driven recovery |

**Key Insight:** The 80/20 rule applied to distributed systems - 20% of the effort delivers the core value (idempotent retry), the remaining 80% handles increasingly rare edge cases.

**Decision Framework:**
```
if (effort(feature) / value(feature)) > threshold:
    defer_to_backlog()
```

---

## 5. Saga Pattern Rejection

### What Ivailo Said
> "Yosef, Yosef, let's not overcomplicate that. I mean, again, I'm hearing saga."
>
> "This rollback operation is expensive. This needs to also be tested and it could also fail. So we also need to recognize that there would be additional cases around rollback being failing."

### Distributed Systems Pattern: **Compensating Transaction Hazards**

Ivailo identifies the **Saga Anti-Pattern** for this context:

| Saga Challenge | Ivailo's Concern |
|----------------|------------------|
| Compensation complexity | "Rollback is expensive" |
| Nested failures | "It could also fail" |
| State explosion | "Additional cases around rollback being failing" |
| Testing burden | "This needs to be carefully tested" |

**Key Insight:** Compensation creates a **recursive failure problem**:
```
try:
    create_transport_order()  # Might fail
except:
    rollback_transport_order()  # Also might fail!
        # Now what? Rollback the rollback?
```

**Formal Problem:**
```
For operation O with compensation C:
P(inconsistent state) = P(O fails) × P(C fails)

But C introduces new failure modes, so:
P(C fails) > 0, always

Therefore: Adding compensation ADDS failure scenarios, not removes them.
```

---

## 6. Error Classification Semantics

### What Ivailo Said
> "Usually 500 error codes they fall under [recoverable] category. But sometimes they do not like 501 Not Implemented, so obviously not recoverable."
>
> "We have some 400 errors that potentially might fall under recoverable. Like too many requests or request timeout."

### Distributed Systems Pattern: **Semantic Error Classification**

Ivailo's classification reveals nuanced understanding:

| HTTP Code | Default Category | Ivailo's Analysis | Reason |
|-----------|-----------------|-------------------|--------|
| 5xx | Recoverable | Mostly yes | Server-side transient |
| 501 | Recoverable | **NO** | "Not implemented" = permanent |
| 4xx | Unrecoverable | Mostly yes | Client error |
| 429 | Unrecoverable | **NO** | Rate limit = wait and retry |
| 408 | Unrecoverable | **NO** | Timeout = network transient |

**Key Insight:** Error classification is **semantic, not syntactic**. The HTTP status code is a hint, not a rule. What matters is:
- **Can this error resolve itself with time?** → Recoverable
- **Does this error require code/data change?** → Unrecoverable

**Decision Tree:**
```
if error.is_transient():
    retry_with_backoff()
elif error.requires_human():
    surface_to_user()
else:
    fail_fast_with_context()
```

---

## 7. Concurrency and Version Vectors

### What Ivailo Said
> "If different users are also trying to perform concurrent operations on the same data set, it's complicated enough. But when we also have multiple applications where we need to sync that data across, it's getting even more complex because user A might overwrite user B's change in system A."
>
> "If we have some like timestamps, potentially we can check these timestamps. Of course if we're sure that these are always automatically incremented."

### Distributed Systems Pattern: **Optimistic Concurrency Control (OCC)**

Ivailo identifies the **Lost Update Problem** in a distributed context:

```
Timeline:
T1: User A reads record (v=1)
T2: User B reads record (v=1)
T3: User A writes record (v=2)  ← Success
T4: User B writes record (v=2)  ← Overwrites A's changes!
```

**With Versioning:**
```
T1: User A reads record (v=1)
T2: User B reads record (v=1)
T3: User A writes record WHERE v=1, SET v=2  ← Success
T4: User B writes record WHERE v=1           ← FAILS (v=2 now)
```

**Key Insight:** Ivailo correctly identifies that **timestamps are unreliable** without guarantees:
- Clocks can skew between systems
- Manual timestamp setting bypasses protection
- Monotonic counters are safer than wall-clock time

**Formal Requirement:**
```
version.next() > version.current()  // Must be monotonic
version.source() = database         // Not application
```

---

## 8. "Half-Baked" State Visibility

### What Ivailo Said
> "We don't want to go with that like local intermediate changes that we somehow report, let's say visually to the end user that these are half-baked."
>
> "Otherwise we will need to change the flow... we first need to do a local change. Then we synchronize... If everything is fine, we just update the status."

### Distributed Systems Pattern: **Provisional State Anti-Pattern**

Ivailo warns against exposing **uncommitted state** to users:

| Approach | User Experience | System Complexity |
|----------|-----------------|-------------------|
| Show "pending" records | Confusing: "Is this real?" | High: status management |
| Hide until confirmed | Clear: success/failure | Low: binary outcome |

**Key Insight:** Provisional visibility creates a **UX consistency problem**:
- User sees "pending" transport order
- User makes decisions based on it
- Sync fails → Transport order disappears
- User's mental model is now inconsistent with reality

**Pattern:** This is why **eventual consistency is acceptable for backend systems but problematic for user-facing state**. Users expect ACID semantics even when the system provides BASE.

---

## 9. Testing Unknown Error Codes

### What Ivailo Said
> "We don't know what kind of codes TMS would be actually throwing. We first need to capture this and then put it as part of tests."
>
> "The more cases we start accumulating, the more complex it gets."

### Distributed Systems Pattern: **Error Discovery via Production Telemetry**

Ivailo acknowledges a fundamental distributed systems challenge: **you cannot enumerate all failure modes in advance**.

**Strategy:**
```
Phase 1: Deploy with broad error categories
Phase 2: Monitor for unexpected error codes
Phase 3: Classify new errors based on observed behavior
Phase 4: Add specific handling + tests
```

**Key Insight:** This is **failure-driven development** - let production teach you what can fail, rather than imagining all possibilities.

**Testing Limitation:**
```
TestCoverage(all_error_codes) ≈ ∞  // Impractical
TestCoverage(observed_errors) = Finite + Grows over time
```

---

## 10. Rollback Frequency vs. Complexity

### What Ivailo Said
> "How frequent this kind of rollback would happen. This would be very infrequent. So in that regard, testing it would be also very, very complicated."

### Distributed Systems Pattern: **Edge Case ROI Analysis**

Ivailo applies a pragmatic cost-benefit:

| Factor | Rollback Feature |
|--------|-----------------|
| Implementation cost | High |
| Testing cost | Very high (rare scenario) |
| Usage frequency | Very low |
| Value when used | Moderate (user retries anyway) |

**Key Insight:** Features that handle rare cases but add significant complexity are **technical debt that provides negative ROI**:
- High maintenance burden
- Rarely exercised code paths become brittle
- False confidence ("we handle this") when the handling is untested

**Decision Rule:**
```
if (P(scenario) × cost(scenario)) < cost(implementation + testing + maintenance):
    accept_manual_intervention()
```

---

## Summary: Ivailo's Design Philosophy

### Core Principles Extracted

1. **Bounded Uncertainty**: Cap wait times, retry counts, and complexity at known limits
2. **Explicit Limitations**: Better to clearly fail than partially succeed
3. **Reliability Hierarchy**: Trust databases over application code
4. **Incremental Capability**: 20% effort for 80% value, defer the rest
5. **Semantic Classification**: Understand what errors mean, not just their codes
6. **Production-Driven Testing**: Learn from reality, not imagination
7. **UX Consistency**: Users need clear success/failure, not "maybe"

### Pattern Catalog from Ivailo's Contributions

| Pattern Name | Ivailo's Application |
|--------------|---------------------|
| Fail-Fast with Bounded Wait | 2 retries, seconds max |
| Operation Morphing | CREATE→UPDATE on exists |
| Failure Domain Prioritization | DB > Application Layer |
| Complexity Budgeting | 20% effort target |
| Saga Rejection | Compensation = more failure modes |
| Semantic Error Classification | 501 ≠ 500, 429 ≠ 400 |
| Optimistic Concurrency | Version/timestamp checking |
| Provisional State Avoidance | No "half-baked" visibility |
| Production Telemetry | Discover errors from reality |
| Edge Case ROI | Rare + complex = defer |

---

## Actionable Takeaways

### For Implementation
- [ ] Configure retry policy: 100ms → 1s → fail to user
- [ ] Implement idempotency matrix as documented
- [ ] Create error classification whitelist (not blacklist)
- [ ] Add version checking where TMS provides timestamps
- [ ] Log all unexpected error codes for future classification

### For Architecture Decisions
- [ ] Defer automatic retry to post-June if needed
- [ ] Defer "pending" state UI to post-June if needed
- [ ] Plan TMS error monitoring from day 1
- [ ] Accept that first go-live will reveal new failure modes

### For Team Communication
- [ ] Align on "20% of outbox" complexity target
- [ ] Document explicit limitations (no state persistence)
- [ ] Create runbook for "unrecoverable error" user guidance

