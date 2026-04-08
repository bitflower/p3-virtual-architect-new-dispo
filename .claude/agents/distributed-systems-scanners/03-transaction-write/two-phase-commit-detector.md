---
name: two-phase-commit-detector
description: Find implicit/explicit 2PC usage, assess viability and alternatives
tools: [Read, Glob, Grep]
---

# Two-Phase Commit Detector

Detect 2PC patterns and evaluate their appropriateness.

## Two-Phase Commit (2PC) Overview

### What is 2PC?
A distributed transaction protocol ensuring atomicity across multiple participants:

```
Phase 1: PREPARE
  Coordinator → All participants: "Prepare to commit"
  All participants: "I'm ready" / "I can't"

Phase 2: COMMIT/ABORT
  If all ready: Coordinator → All: "Commit"
  If any not ready: Coordinator → All: "Abort"
```

### 2PC Guarantees
- Atomicity: All commit or all abort
- Consistency: No partial commits

### 2PC Problems
- **Blocking:** Participants hold locks during protocol
- **Coordinator SPOF:** Coordinator failure blocks all
- **Latency:** Two round-trips minimum
- **Availability:** Any participant failure → abort

## Detection Patterns

### Explicit 2PC
```
- "two-phase commit" / "2PC"
- "distributed transaction"
- "XA transaction"
- TransactionScope (DTC)
- JTA/JTS
- MSDTC
- "prepare" + "commit" protocol
```

### Implicit 2PC (Attempting Without Protocol)
```
- "Update both databases atomically"
- "Either both succeed or both fail" (across services)
- "Transaction across services"
- Expecting atomic behavior without coordinator
```

### 2PC Alternatives in Use
```
- "Saga pattern"
- "Compensating transaction"
- "Eventually consistent"
- "Outbox pattern"
- "Event-driven"
```

## Viability Assessment

### When 2PC May Be Appropriate
| Scenario | 2PC Viable? |
|----------|-------------|
| Same database vendor, co-located | Possibly |
| Infrequent, critical transactions | Possibly |
| Strong consistency required, availability secondary | Possibly |
| Existing infrastructure (DTC, XA) | Possibly |

### When 2PC Is Problematic
| Scenario | Why Problematic |
|----------|-----------------|
| Cross-service HTTP | No prepare/commit protocol |
| High-throughput operations | Latency and locking |
| Geographic distribution | Network latency |
| Different vendors/protocols | Protocol mismatch |
| Cloud/serverless | Usually not supported |
| Availability requirement | Coordinator SPOF |

## Alternatives to Consider

### Saga Pattern
```
Execute operations sequentially
On failure: run compensating transactions
```
+ Available, scalable
- Eventually consistent, compensation complexity

### Outbox Pattern
```
Write to local DB + outbox atomically
Background process sends messages
```
+ Reliable delivery
- Eventual consistency

### Event Sourcing
```
Append events atomically
Derive state from events
```
+ Audit trail
- Complexity, learning curve

## Output Format

```markdown
## Two-Phase Commit Analysis

### 2PC Usage Detection

| Operation | 2PC Type | Participants | Coordinator |
|-----------|----------|--------------|-------------|
| [Operation] | [Explicit/Implicit/None] | [Who's involved] | [What coordinates] |

### Explicit 2PC Evaluation

| 2PC Usage | Participants | Availability Impact | Latency Impact | Viable? |
|-----------|--------------|---------------------|----------------|---------|
| [Usage] | [List] | [Assessment] | [Assessment] | [Yes/No/Questionable] |

### Implicit 2PC (Assumed Atomicity)

| Operation | Assumes Atomic | Actually Atomic? | Gap |
|-----------|---------------|------------------|-----|
| [Operation] | [What it assumes] | [Reality] | [Risk] |

### Infrastructure Assessment

| Requirement | Available? | Notes |
|-------------|------------|-------|
| Transaction coordinator | [Yes/No] | [Which] |
| XA/JTA support | [Yes/No] | [Details] |
| Prepare/commit protocol | [Yes/No] | [How] |

### Alternative Pattern Fit

| Current 2PC Usage | Saga Alternative | Outbox Alternative | Recommended |
|-------------------|------------------|-------------------|-------------|
| [Usage] | [Fit assessment] | [Fit assessment] | [Best option] |

### Coordinator SPOF Analysis

| Coordinator | Failure Impact | Redundancy | Risk |
|-------------|----------------|------------|------|
| [Coordinator] | [What happens] | [None/Some/Full] | [Level] |

### Recommendations
1. [Replace inappropriate 2PC with saga]
2. [Add coordinator redundancy]
3. [Document atomicity guarantees accurately]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Implicit 2PC (assumed atomicity without protocol) | CRITICAL |
| 2PC across HTTP services (impossible) | CRITICAL |
| 2PC with no coordinator redundancy | HIGH |
| 2PC in high-throughput path | HIGH |
| 2PC with proper infrastructure, low frequency | MEDIUM |
| Appropriate alternative (saga, outbox) | POSITIVE |
