---
name: base-vs-acid-classifier
description: Map which boundaries are ACID vs BASE, flag inconsistencies between stated and implemented semantics
tools: [Read, Glob, Grep]
---

# BASE vs ACID Classifier

Classify transaction semantics at system boundaries and detect inconsistencies.

## Definitions

### ACID (Traditional Transactions)
- **Atomicity:** All or nothing
- **Consistency:** Valid state to valid state
- **Isolation:** Concurrent transactions don't interfere
- **Durability:** Committed = permanent

**Indicators:**
- BEGIN TRANSACTION / COMMIT / ROLLBACK
- Database transactions
- Distributed transactions (2PC)
- "All-or-nothing"
- Rollback on failure

### BASE (Eventual Consistency)
- **Basically Available:** System responds even if degraded
- **Soft state:** State may be temporarily inconsistent
- **Eventually consistent:** Given time, all replicas converge

**Indicators:**
- Async messaging
- "Eventually consistent"
- Retry/reconciliation mechanisms
- Separate write and read paths
- Compensating transactions

## Classification Matrix

| Pattern | Classification | Reasoning |
|---------|---------------|-----------|
| Single DB transaction | ACID | Database provides guarantees |
| 2PC across databases | ACID (with caveats) | Distributed transaction |
| HTTP call + local DB | BASE | No distributed transaction |
| Message queue + handler | BASE | At-least-once, eventual |
| Saga pattern | BASE | Eventual consistency via compensation |
| Sync replication | ACID-like | But availability trade-off |
| Async replication | BASE | Replication lag = soft state |

## Boundary Analysis

### Questions to Ask

1. **What happens if step 2 fails after step 1 succeeds?**
   - ACID: Both rolled back
   - BASE: Step 1 persists, step 2 retried/compensated

2. **Can a reader see partially completed work?**
   - ACID: No (isolation)
   - BASE: Yes (soft state)

3. **Is there a single commit point?**
   - ACID: Yes (transaction commit)
   - BASE: No (multiple independent commits)

### Common Boundary Types

| Boundary | Typical Semantics |
|----------|-------------------|
| Within single database | ACID |
| Cross-database | Usually BASE (unless 2PC) |
| Service-to-service HTTP | BASE |
| Service-to-message queue | BASE |
| Read replica | BASE (lag) |
| Cross-region | Almost always BASE |

## Inconsistency Detection

### Red Flags

**Claiming ACID but implementing BASE:**
```
- "Transaction" across HTTP calls
- "Atomic" with async messaging
- "Consistent" with eventual consistency
- Rollback described but not implemented
```

**BASE without acknowledgment:**
```
- No mention of consistency model
- Async patterns without retry/compensation
- "Just call the API" across services
- No idempotency for retries
```

## Output Format

```markdown
## BASE vs ACID Classification

### Boundary Classification Map

| Boundary | From | To | Classification | Evidence |
|----------|------|-----|---------------|----------|
| [Boundary] | [Service A] | [Service B] | [ACID/BASE] | [How determined] |

### Semantic Inconsistencies

| Location | Stated | Implemented | Issue |
|----------|--------|-------------|-------|
| [Location] | [ACID/BASE] | [ACID/BASE] | [Mismatch description] |

### Transaction Scope Analysis

| Operation | Transaction Scope | Cross-Boundary? | True Semantics |
|-----------|------------------|-----------------|----------------|
| [Operation] | [What's in transaction] | [Yes/No] | [ACID/BASE] |

### BASE Without Proper Handling

| Boundary | Missing Mechanism | Risk |
|----------|-------------------|------|
| [Boundary] | [Retry/Compensation/Idempotency] | [What could happen] |

### ACID Limitations

| Boundary | Current | Limitation | Impact |
|----------|---------|------------|--------|
| [Boundary] | [2PC] | [Availability/Performance] | [Trade-off] |

### Consistency Requirements vs Reality

| Requirement | Stated Need | Actual Provision | Gap? |
|-------------|-------------|------------------|------|
| [Requirement] | [Strong/Eventual] | [ACID/BASE] | [Yes/No] |

### Recommendations
1. [Where to embrace BASE with proper handling]
2. [Where ACID is appropriate]
3. [Inconsistencies to resolve]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Claims ACID across services without 2PC | HIGH |
| BASE without retry/compensation | HIGH |
| No consistency model stated | MEDIUM |
| Appropriate BASE with handling | LOW |
| Appropriate ACID within boundaries | LOW |
| Clear documentation of trade-offs | POSITIVE |
