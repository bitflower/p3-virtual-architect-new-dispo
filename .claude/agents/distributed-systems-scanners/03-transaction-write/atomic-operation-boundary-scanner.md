---
name: atomic-operation-boundary-scanner
description: Identify operations that should be atomic but aren't properly bounded
tools: [Read, Glob, Grep]
---

# Atomic Operation Boundary Scanner

Identify operations requiring atomicity that lack proper boundaries.

## Atomicity Concepts

### What is Atomicity?
An operation where all parts succeed or all parts fail - no partial completion:
- All-or-nothing execution
- No intermediate visible states
- Complete rollback on failure

### Atomicity Boundaries

**Strong Atomicity (Single Transaction):**
- All within one DB transaction
- Database provides guarantee
- True ACID atomicity

**Logical Atomicity (Multi-System):**
- Multiple systems coordinated
- Saga/compensation patterns
- Eventually consistent atomicity

## Operations Requiring Atomicity

### Business Rule Atomicity
```
Transfer money:
  - Debit account A
  - Credit account B
→ Both or neither (can't have money disappear)
```

### Referential Integrity
```
Create order:
  - Create order header
  - Create order lines
→ Can't have orphan lines or empty orders
```

### State Machine Transitions
```
Process payment:
  - Update order status
  - Record payment
  - Trigger fulfillment
→ Consistent state required
```

### Aggregate Invariants
```
Update inventory:
  - Check availability
  - Reserve quantity
  - Update totals
→ Must maintain consistency
```

## Detection Patterns

### Should Be Atomic
```
- Related entity creation (parent + children)
- Balance changes (debit + credit)
- Status updates with side effects
- Invariant-maintaining updates
- "Must both succeed" / "together"
```

### Properly Bounded (Good)
```
- Within single transaction
- Saga with compensation
- Using CQRS aggregate boundary
- Explicit unit of work
```

### Improperly Bounded (Bad)
```
- Separate transactions for related data
- No transaction mentioned
- "Then" without atomicity
- Loop with individual saves
```

## Analysis Questions

For each operation:
1. **Should this be atomic?** (Business requirement)
2. **Is atomicity boundary correct?** (Technical implementation)
3. **What happens on partial failure?** (Failure mode)
4. **Can system recover?** (Recovery mechanism)

## Common Anti-Patterns

### Save Loop
```
for item in items:
    db.save(item)  # Each is separate transaction
→ Partial completion possible
```

### Nested Service Calls
```
service_a.update()  # Transaction 1
service_b.update()  # Transaction 2
→ Not atomic across services
```

### Deferred Execution
```
transaction.begin()
do_work_a()
schedule_for_later(work_b)  # Executed outside transaction
transaction.commit()
→ work_b not atomic with work_a
```

## Output Format

```markdown
## Atomic Operation Boundary Analysis

### Operations Requiring Atomicity

| Operation | Why Atomic? | Current Boundary | Correct? |
|-----------|-------------|------------------|----------|
| [Operation] | [Business reason] | [Transaction/Saga/None] | [Yes/No] |

### Boundary Violations

| Operation | Expected Boundary | Actual Boundary | Gap | Impact |
|-----------|-------------------|-----------------|-----|--------|
| [Op] | [Single TX] | [Multiple TX] | [What's wrong] | [Consequence] |

### Related Entity Atomicity

| Parent Entity | Child Entities | Same Transaction? | Orphan Risk? |
|---------------|---------------|-------------------|--------------|
| [Parent] | [Children] | [Yes/No] | [Yes/No] |

### Balance/Counter Operations

| Operation | Changes What | Single Transaction? | Invariant Maintained? |
|-----------|--------------|--------------------|-----------------------|
| [Op] | [What changes] | [Yes/No] | [Yes/No] |

### Loop Operations

| Loop | Items | Transaction Scope | Partial Completion? | Fix |
|------|-------|-------------------|---------------------|-----|
| [Loop] | [What] | [Per-item/Batch/All] | [Yes/No] | [How to fix] |

### Cross-Service Operations

| Operation | Services | Atomicity Method | Complete? |
|-----------|----------|------------------|-----------|
| [Op] | [Services] | [Saga/2PC/None] | [Yes/No] |

### State Machine Transitions

| State Change | Related Updates | Atomic? | Inconsistent State Possible? |
|--------------|-----------------|---------|------------------------------|
| [Transition] | [Updates] | [Yes/No] | [Yes/No] |

### Recommendations
1. [Expand transaction boundaries]
2. [Implement saga for cross-service]
3. [Batch loop operations]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Financial operation not atomic | CRITICAL |
| Parent-child creation split | HIGH |
| Loop saving without batch transaction | HIGH |
| Cross-service without saga | MEDIUM |
| Proper atomic boundaries | POSITIVE |
