# Distributed Systems Knowledge: Option 1 Deep Analysis

## Manual User-Driven Retry + Idempotent Processing

This document extracts fine-grained distributed systems knowledge from the "Option 1" pattern, examining every design decision through the lens of distributed systems theory.

---

## 1. Fundamental Design Philosophy

### 1.1 Human-in-the-Loop as Consistency Mechanism

Option 1 delegates retry decisions to the human operator rather than automated systems.

**Theoretical Foundation:**
- In distributed systems, retry storms can amplify failures (thundering herd)
- Human operators provide natural rate limiting and intelligent decision-making
- Users can apply domain knowledge unavailable to automated systems

**Trade-off Analysis:**
| Aspect | Automated Retry | Human-Driven Retry |
|--------|-----------------|-------------------|
| Latency to recovery | Seconds | Minutes to hours |
| Cognitive load | None | User must understand failure |
| Retry intelligence | Rule-based | Context-aware |
| Cascade prevention | Requires circuit breaker | Natural backpressure |
| Operational cost | Infrastructure | Training |

**Pattern Name:** *Supervised Retry* or *Operator-Assisted Recovery*

---

### 1.2 Remote-First Write Strategy

Option 1 mandates: **TMS (remote) first, then Local DB second.**

```
1. Apply changes to TMS (external system)
2. Only on success: Apply changes to Local DB
```

**Why Remote-First?**

The critical insight is **who is the source of truth**. When TMS owns the canonical data:

1. **Write to master first** - ensures the authoritative system has the data
2. **Derive local state from master** - local DB is a projection/cache
3. **Failure at step 2 is recoverable** - master has the data, local can catch up

**Failure Mode Analysis:**

| Failure Point | Remote-First Outcome | Local-First Outcome |
|---------------|---------------------|---------------------|
| Step 1 fails | Clean failure, no state change anywhere | Local has data TMS doesn't (split-brain) |
| Step 2 fails | TMS has data, local needs sync | Depends on outbox reliability |
| Network partition during step 2 | Detectable inconsistency | Hidden inconsistency |

**Pattern Name:** *Master-First Write* or *Authoritative-Source-First*

---

## 2. Idempotency Patterns

### 2.1 Pre-Check Idempotency (GET-before-MUTATE)

Option 1's sequence:
```
1. GET record from TMS (check existence)
2. IF exists AND operation=CREATE → switch to UPDATE
3. IF not exists AND operation=DELETE → skip
4. ELSE → proceed with original operation
```

**This is "Natural Idempotency" via State Inspection**

Rather than using idempotency keys (tokens), the system derives idempotency from the current state of the target system.

**Formal Definition:**
```
f(x) is idempotent if f(f(x)) = f(x)

Option 1 achieves this by:
- CREATE: if exists(x) then update(x) else create(x)
- DELETE: if exists(x) then delete(x) else no-op
- UPDATE: always applies (last-write-wins)
```

**Advantages:**
- No idempotency key storage required
- Works with systems that don't support idempotency keys
- Self-healing: state converges regardless of retry count

**Disadvantages:**
- Requires read-before-write (extra network round-trip)
- Race conditions between check and write (TOCTOU vulnerability)
- Cannot distinguish "already processed" from "concurrent modification"

---

### 2.2 Operation Morphing

Option 1 introduces **operation type transformation** based on observed state:

| Intended Operation | Observed State | Transformed Operation |
|-------------------|----------------|----------------------|
| CREATE | Record exists | UPDATE |
| DELETE | Record missing | NO-OP |
| UPDATE | Record exists | UPDATE |
| UPDATE | Record missing | CREATE (risky) |

**This is a form of Conflict-Free Replicated Data Type (CRDT) thinking:**

The operation becomes "ensure this state exists" rather than "perform this action."

**Semantic Shift:**
- Imperative: "Create transport order X"
- Declarative: "Ensure transport order X exists with these properties"

**Pattern Name:** *State-Convergent Operations* or *Declarative Mutation*

---

### 2.3 The Idempotency Matrix

Option 1 includes a detailed idempotency decision matrix considering versioning:

```
| State \ Action | CREATE | UPDATE | DELETE |
|----------------|--------|--------|--------|
| Not exists     | Create | Create?| No-op  |
| Exists (v <= modified) | Update | Update | Delete |
| Exists (v > modified)  | Skip+Error | Skip+Error | Skip+Error |
```

**Version Comparison Logic:**

- `current_version <= modified_version`: Our change is newer or same, apply it
- `current_version > modified_version`: Someone else made a newer change, we're stale

**This implements Optimistic Concurrency Control (OCC) with version vectors.**

**Edge Case - Update on Non-Existent:**
> "This is prone to concurrency issues, soft deletes may be enabled"

The document acknowledges the **ABA problem**:
1. Record exists with version 1
2. Process A reads version 1, prepares update
3. Process B deletes record
4. Process A's update now creates a "zombie" record

**Mitigation:** Soft deletes (tombstones) preserve version history, preventing resurrection of deleted records.

---

## 3. Consistency Models

### 3.1 No Guaranteed Relative Ordering

Option 1 explicitly states: **"Relative Ordering: Not Guaranteed"**

**What This Means:**

If user performs operations A, B, C in sequence, after retries the final state might reflect order A, C, B or any permutation.

**When This Is Acceptable:**
- Operations are on independent entities (no causal relationship)
- Last-write-wins semantics are acceptable
- Operations are commutative (order doesn't matter)

**When This Is Dangerous:**
- Causal dependencies: "Add leg to transport order" requires transport order to exist
- Business invariants: "Delete transport order" should fail if legs exist
- Audit requirements: "Show me exactly what happened in order"

**Pattern Name:** *Unordered Convergence* or *Commutative Eventual Consistency*

---

### 3.2 Eventual Consistency with Manual Intervention

Option 1 achieves eventual consistency through:

1. **Detection:** User observes inconsistency (error message, missing data)
2. **Decision:** User decides to retry
3. **Convergence:** Idempotent retry brings systems into alignment

**Consistency Window = Human Reaction Time**

Unlike automated systems where consistency windows are measured in milliseconds, Option 1's consistency window includes:
- Error comprehension time
- Decision time
- Retry action time

**Total: Seconds to Hours**

**This is acceptable when:**
- Operations are infrequent (dispatcher drag-and-drop, not high-frequency trading)
- Business can tolerate temporary inconsistency
- Strong consistency is technically infeasible (no 2PC available)

---

### 3.3 Race Condition Acknowledgment

Option 1 explicitly states: **"Eliminate Race Conditions: No, requires versioning and soft deletes"**

**Identified Race Conditions:**

1. **Lost Update:**
   ```
   T1: GET record (version=1)
   T2: GET record (version=1)
   T1: UPDATE record (version=2)
   T2: UPDATE record (version=2) ← Overwrites T1's changes
   ```

2. **TOCTOU (Time-of-Check to Time-of-Use):**
   ```
   T1: Check record not exists
   T2: Create record
   T1: Create record ← Duplicate!
   ```

3. **Phantom Delete:**
   ```
   T1: Check record exists, prepare delete
   T2: Delete record
   T1: Delete record ← No-op, but was it T1's delete or T2's?
   ```

**Mitigation Strategies Mentioned:**
- Versioning (optimistic locking)
- Soft deletes (tombstones with version history)
- NOT mentioned: Distributed locks, consensus protocols

---

## 4. Error Handling Philosophy

### 4.1 Error Classification Framework

Option 1 provides a systematic error taxonomy:

| Category | Examples | Behavior |
|----------|----------|----------|
| **Success** | HTTP 200, 201 | Return success |
| **Recoverable** | 5xx, 408, 429, socket disconnect | Retry |
| **Recoverable + Max Retries** | Same as above, exhausted | Return error, reload frontend |
| **Unrecoverable** | 4xx (400, 403, 409, 501), malformed response | Return error, reload frontend |

**Key Insight: Error Classification Drives System Behavior**

The distinction between recoverable and unrecoverable determines:
- Whether to retry or fail fast
- Whether to preserve operation for later or discard it
- User experience (wait vs. retry vs. give up)

**Pattern Name:** *Semantic Error Classification* or *Actionable Error Taxonomy*

---

### 4.2 Fail-Fast vs. Retry Spectrum

```
Unrecoverable ←────────────────────────→ Recoverable
     │                                        │
     ▼                                        ▼
 Fail Fast                              Retry with Backoff
 (No point retrying,                    (Transient failure,
  problem is permanent)                  might succeed later)
```

**Classification Heuristics:**

- **4xx = Client Error = Unrecoverable**: The request itself is wrong
- **5xx = Server Error = Recoverable**: The server is temporarily broken
- **429 = Rate Limited = Recoverable**: We're too fast, slow down
- **Timeout = Recoverable**: Network hiccup, try again

**Exception: 409 Conflict**

409 is marked unrecoverable, but this is nuanced:
- 409 due to duplicate = might be recoverable (our previous attempt succeeded)
- 409 due to version mismatch = unrecoverable (someone else changed it)

---

## 5. System Boundary Design

### 5.1 TMS Bridge as Integration Boundary

The diagram shows TMS as "External Dependency" with clean request/response semantics.

**Boundary Characteristics:**
- Synchronous HTTP-based communication
- No shared transactions (no 2PC)
- No guaranteed delivery (at-most-once by default)
- Opaque error messages (must be interpreted)

**Pattern Name:** *Anti-Corruption Layer* (Domain-Driven Design)

The TMS Bridge serves as a translation layer between:
- New Dispo's domain model (lots, legs, lot assignments)
- TMS's domain model (transport orders, tour points, shipments)

---

### 5.2 Transaction Boundary Isolation

Option 1's flow shows explicit transaction demarcation:

```
[TMS Operations - No Transaction]
   │
   ▼ Success
[Create Transaction]
   │
[Apply Local Changes]
   │
[Commit Transaction]
```

**Critical Design Decision: TMS calls are OUTSIDE the local transaction**

**Why?**
1. **No 2PC**: Cannot coordinate commit across TMS Bridge
2. **Timeout Risk**: Long-running transactions holding locks
3. **Resource Exhaustion**: Connection pool depletion waiting for TMS

**Implication:**
The "transaction" in Option 1 is purely local. TMS operations are fire-and-forget from a transactional perspective (though idempotency provides semantic guarantees).

---

## 6. Portability Considerations

### 6.1 Infrastructure Independence

Option 1 is rated **"High Portability"** because:

- No message queue dependency
- No background worker infrastructure
- No additional database tables
- Standard HTTP request/response patterns
- Runs in any stateless application server

**Deployment Flexibility:**
- Single instance: Works
- Multiple instances: Works (stateless)
- Serverless (Cloud Functions): Works
- Container orchestration: Works

**Contrast with Outbox Pattern:**
- Requires database table (PostgreSQL, AlloyDB)
- May require background worker (Kubernetes CronJob, Cloud Scheduler)
- Requires polling or change data capture infrastructure

---

### 6.2 Technology Stack Agnosticism

Option 1 uses only:
- HTTP client (any language)
- Database transactions (any RDBMS)
- Basic control flow (if/else)

**No dependencies on:**
- Message brokers (Kafka, RabbitMQ, Pub/Sub)
- Workflow engines (Temporal, Camunda)
- Distributed coordination (ZooKeeper, etcd)
- Event sourcing infrastructure

---

## 7. UX Implications

### 7.1 Synchronous User Experience

Option 1 provides **immediate feedback**:

```
User Action → Loading → Success/Failure (within seconds)
```

**User Mental Model:**
- "I clicked, I wait, I see result"
- No "pending" states to track
- No need to check back later

**Contrast with Asynchronous:**
- "I clicked, I see pending, I check back, it's done"
- Requires status tracking UI
- Cognitive overhead: "Did my operation complete?"

---

### 7.2 Error Communication

Option 1 requires errors to be:
1. **Classifiable by the user**: "Can I retry this?"
2. **Actionable**: "Click retry" vs. "Contact support"
3. **Understandable**: Why did it fail?

**Error Message Design:**
```
Recoverable: "Could not reach TMS. Click retry to try again."
Unrecoverable: "Invalid transport order configuration. Please check your inputs."
```

---

## 8. Scaling Characteristics

### 8.1 Load Characteristics

Option 1 scales with:
- Number of concurrent users
- TMS response latency
- Local DB transaction throughput

**Bottlenecks:**
1. **TMS throughput**: Every operation calls TMS twice (GET + MUTATE)
2. **User patience**: Long TMS latency = user retries = more load
3. **No batching**: Each operation is independent

### 8.2 Failure Amplification

Under TMS degradation:
```
TMS Slow → Users see timeout → Users retry → More TMS load → TMS slower
```

**Missing:** Circuit breaker pattern to prevent cascade

**Mitigation in Option 1:**
- Human rate limiting (users give up eventually)
- Error messages discourage immediate retry
- "Configurable amount" of manual retries mentioned

---

## 9. Observability Requirements

### 9.1 Implicit Observability Needs

Although not explicit, Option 1 requires:

| Metric | Purpose |
|--------|---------|
| TMS call latency | Detect degradation |
| TMS error rate | Detect outages |
| Retry frequency | Measure user frustration |
| Success rate | Overall health |
| Inconsistency detection | Data quality |

### 9.2 Missing: Reconciliation Mechanism

Option 1 doesn't describe how to detect drift between TMS and Local DB.

**Required but not specified:**
- Periodic consistency checks
- Reconciliation reports
- Drift alerting

---

## 10. Theoretical Foundations

### 10.1 CAP Theorem Positioning

Option 1 chooses: **AP (Availability + Partition Tolerance)**

- **Availability**: System accepts writes even during partial failure
- **Partition Tolerance**: TMS/Local DB can be temporarily disconnected
- **NOT Consistency**: Temporary inconsistency is accepted

**Consistency is achieved via:**
- User-driven convergence
- Idempotent retry
- Eventually (not immediately)

---

### 10.2 BASE vs. ACID

Option 1 implements **BASE** semantics:

| Principle | Option 1 Implementation |
|-----------|------------------------|
| **B**asically **A**vailable | User can always submit operations |
| **S**oft state | Local DB may be temporarily stale |
| **E**ventually consistent | Retry converges state |

**ACID is local only:**
- Local transaction is ACID
- Cross-system is BASE

---

### 10.3 Failure Domains

Option 1 implicitly defines failure domains:

```
┌─────────────────────────────────────┐
│ Failure Domain 1: New Dispo        │
│ ┌─────────────┐  ┌───────────────┐ │
│ │ Backend     │──│ Local DB      │ │
│ └─────────────┘  └───────────────┘ │
└─────────────────────────────────────┘
         │
    [Network - Failure Domain 2]
         │
┌─────────────────────────────────────┐
│ Failure Domain 3: TMS              │
│ ┌─────────────┐  ┌───────────────┐ │
│ │ TMS Bridge  │──│ TMS Database  │ │
│ └─────────────┘  └───────────────┘ │
└─────────────────────────────────────┘
```

**Cross-domain failures** (network between domains) are the most challenging - Option 1 handles these via idempotent retry.

---

## 11. Anti-Patterns Avoided

### 11.1 Distributed Transaction (2PC)

**Why not 2PC?**
- TMS Bridge doesn't support transaction enlistment
- 2PC has availability problems (coordinator failure blocks all participants)
- Latency overhead unacceptable for user-facing operations

### 11.2 Saga with Compensation

**Why not Saga?**
- TMS operations may not be reversible
- Compensation logic complex (what does "un-create transport order" mean?)
- Partial compensation leaves system in undefined state

### 11.3 Event Sourcing

**Why not Event Sourcing?**
- Requires rebuild of entire architecture
- TMS is not event-sourced
- Complexity far exceeds value for this use case

---

## 12. Implementation Checklist

Based on Option 1, implementers must:

- [ ] Implement GET-before-MUTATE for idempotency
- [ ] Implement operation morphing (CREATE → UPDATE when exists)
- [ ] Implement version comparison for conflict detection
- [ ] Classify all TMS error responses (recoverable vs. unrecoverable)
- [ ] Implement retry loop with configurable max attempts
- [ ] Design user-facing error messages for each error class
- [ ] Implement soft deletes if concurrent delete risk exists
- [ ] Add observability for TMS call metrics
- [ ] Design reconciliation strategy (out of scope but needed)
- [ ] Test all failure scenarios (TMS down, Local DB down, network partition)

---

## 13. Summary: Option 1's Core Insights

1. **Humans are excellent distributed systems coordinators** - when frequency is low
2. **Remote-first writes to master** - local state is derivable
3. **Idempotency via state inspection** - no special infrastructure needed
4. **Accept eventual consistency** - when business allows
5. **Classify errors semantically** - drives retry behavior
6. **Keep transaction boundaries local** - don't try to span systems
7. **Portability over features** - simple wins for June go-live

---

## Appendix: Pattern Catalog

| Pattern Name | Option 1 Usage |
|--------------|----------------|
| Supervised Retry | User-driven retry instead of automated |
| Master-First Write | TMS before Local DB |
| State-Convergent Operations | CREATE → UPDATE morphing |
| Optimistic Concurrency Control | Version comparison |
| Semantic Error Classification | 4xx vs 5xx handling |
| Anti-Corruption Layer | TMS Bridge |
| BASE Consistency | Eventual consistency via retry |
| Soft Deletes | Tombstones for concurrent delete safety |

