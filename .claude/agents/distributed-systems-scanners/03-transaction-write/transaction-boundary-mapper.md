---
name: transaction-boundary-mapper
description: Map transaction scopes, find boundary violations where transactions span inappropriate boundaries
tools: [Read, Glob, Grep]
---

# Transaction Boundary Mapper

Map transaction boundaries and identify violations in distributed systems.

## Transaction Boundary Concepts

### What is a Transaction Boundary?
The scope within which ACID guarantees apply:
- All operations commit or rollback together
- Isolation from other transactions
- Durability on commit

### Boundary Types

| Boundary Type | Scope | ACID Guaranteed? |
|---------------|-------|------------------|
| Single DB transaction | One database | Yes |
| Distributed transaction (2PC) | Multiple databases | Yes (with caveats) |
| Application transaction | Application logic | Depends on implementation |
| Business transaction | Business operation | Usually eventual consistency |

## Valid Transaction Boundaries

### ✅ Single Database
```
BEGIN TRANSACTION
  UPDATE orders SET status = 'confirmed'
  INSERT INTO order_history ...
  UPDATE inventory SET quantity = quantity - 1
COMMIT
```
All in same database = valid ACID transaction

### ✅ Distributed Transaction with 2PC
```
BEGIN DISTRIBUTED TRANSACTION
  Database A: UPDATE ...
  Database B: UPDATE ...
PREPARE (both)
COMMIT (both)
```
Coordinated = valid (but availability trade-offs)

## Invalid Transaction Boundaries (Anti-Patterns)

### ❌ HTTP Call Inside Transaction
```
BEGIN TRANSACTION
  UPDATE local_db
  HTTP POST to external service  ← DANGER!
  UPDATE local_db
COMMIT
```
Problems:
- Can't rollback HTTP call
- Long-running transaction (holds locks)
- External service failure = stuck transaction

### ❌ Assumed Atomicity Across Services
```
Service A: Update order
Service B: Update inventory
Assuming both succeed or both fail  ← Wrong!
```
No transaction coordinator = no atomicity

### ❌ Transaction Spanning Message Queue
```
BEGIN TRANSACTION
  UPDATE database
  PUBLISH to queue  ← May not be transactional
COMMIT
```
Unless using transactional outbox pattern

## Detection Patterns

### Transaction Boundary Indicators
```
- BEGIN TRANSACTION / COMMIT
- @Transactional annotation
- TransactionScope
- Unit of Work
- "within transaction"
```

### Boundary Violation Indicators
```
- HTTP/API call inside transaction block
- "Call service then update database"
- Multiple services updated "atomically"
- Queue publish in transaction
- Long-running operations in transaction
```

## Output Format

```markdown
## Transaction Boundary Analysis

### Transaction Boundary Map

| Component | Transaction Scope | Boundary Type | Coordinator |
|-----------|------------------|---------------|-------------|
| [Component] | [What's included] | [Single DB/Distributed/App] | [What manages it] |

### Operations Within Transactions

| Transaction | Operations | All Local? | Violations |
|-------------|------------|------------|------------|
| [Transaction] | [What it does] | [Yes/No] | [What crosses boundary] |

### Boundary Violations

| Location | Transaction | Violation | Risk | Fix |
|----------|-------------|-----------|------|-----|
| [Location] | [Transaction scope] | [What crosses] | [What can happen] | [How to fix] |

### External Calls in Transactions

| Transaction | External Call | Lock Duration | Impact |
|-------------|---------------|---------------|--------|
| [Transaction] | [Call] | [How long held] | [Contention/deadlock] |

### Atomicity Assumptions

| Operation | Assumed Atomic? | Actually Atomic? | Gap |
|-----------|-----------------|------------------|-----|
| [Operation] | [Yes/No] | [Yes/No] | [Mismatch] |

### Transaction Duration Analysis

| Transaction | Expected Duration | External Calls | Risk |
|-------------|------------------|----------------|------|
| [Transaction] | [Duration] | [Count/None] | [Lock contention] |

### 2PC Usage Assessment

| Distributed TX | Participants | Availability Impact | Justified? |
|----------------|--------------|---------------------|------------|
| [Transaction] | [Databases] | [What happens if coordinator fails] | [Yes/No] |

### Recommendations
1. [Move external calls outside transactions]
2. [Use outbox pattern for queue publishes]
3. [Reduce transaction scope]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| HTTP call inside database transaction | CRITICAL |
| Assumed atomicity across services | HIGH |
| Queue publish in transaction without outbox | HIGH |
| Long-running transaction with locks | MEDIUM |
| Clear transaction boundaries documented | POSITIVE |
