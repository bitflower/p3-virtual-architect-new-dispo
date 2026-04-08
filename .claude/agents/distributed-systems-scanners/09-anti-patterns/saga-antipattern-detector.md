---
name: saga-antipattern-detector
description: Find incomplete compensation, orphan sagas, and saga implementation issues
tools: [Read, Glob, Grep]
---

# Saga Anti-Pattern Detector

Detect problematic saga pattern implementations.

## Saga Anti-Patterns

### 1. Missing Compensation
Forward action exists, but no compensation:
```
Step 1: Reserve inventory ✓
Step 2: Charge payment ✓
Step 3: Ship order ✗ (fails)
Compensation for step 2: ??? (missing!)
// Customer charged but order not shipped
```

### 2. Non-Idempotent Compensation
Compensation fails on retry:
```
Compensation: Refund $100
Called twice: Refunds $200!
```

### 3. Orphan Saga
Saga started but never completed:
```
Saga started...
System crash
No recovery mechanism
Saga state: forever "in progress"
```

### 4. Semantic Impossible Compensation
Can't undo the action:
```
Action: Send email
Compensation: ??? (can't unsend)
// Should have been designed differently
```

### 5. Partial Compensation
Some steps compensated, others not:
```
Compensate step 3: ✓
Compensate step 2: ✓
Compensate step 1: ✗ (forgot)
// System in inconsistent state
```

### 6. Compensation That Can Fail Permanently
Compensation has unrecoverable failure:
```
Action: Create external record
Compensation: Delete external record
External API down permanently
// Can't complete compensation, stuck
```

### 7. Wrong Compensation Order
Compensation order incorrect:
```
Forward: A → B → C
Compensation should be: C → B → A
Actual: A → B → C (wrong!)
```

### 8. No Saga State Persistence
Saga state lost on failure:
```
Saga state in memory only
Process crashes
Can't resume or compensate
```

### 9. Timeout-less Saga
No timeout, saga runs forever:
```
Waiting for step that will never complete
No timeout defined
Saga stuck indefinitely
```

### 10. Business Logic in Compensation
Complex business logic in compensation path:
```
Compensation makes business decisions
If customer has X, then Y, else Z
// Too complex, error-prone
```

## Detection Patterns

### Missing Compensation
```
- Forward action without corresponding "undo"
- Saga step with no compensate function
- "TODO: add compensation"
- Asymmetric action/compensation count
```

### Saga State Issues
```
- In-memory saga state only
- No saga recovery on restart
- No saga timeout
- No saga monitoring
```

### Compensation Issues
```
- Compensation without idempotency check
- No retry in compensation
- Compensation throws exception
- Compensation has side effects
```

## Output Format

```markdown
## Saga Anti-Pattern Analysis

### Saga Inventory

| Saga | Steps | All Compensated? | State Persisted? | Timeout? |
|------|-------|------------------|------------------|----------|
| [Saga] | [Count] | [Yes/No] | [Yes/No] | [Yes/No] |

### Missing Compensation Detection

| Saga | Step | Forward Action | Compensation | Status |
|------|------|---------------|--------------|--------|
| [Saga] | [Step] | [Action] | [Comp/MISSING] | [Risk] |

### Non-Idempotent Compensation

| Saga | Compensation | Idempotent? | Risk if Retried |
|------|--------------|-------------|-----------------|
| [Saga] | [Comp] | [Yes/No] | [What happens] |

### Orphan Saga Risk

| Saga | State Storage | Recovery Mechanism | Orphan Risk |
|------|---------------|-------------------|-------------|
| [Saga] | [Where stored] | [How recovered] | [High/Med/Low] |

### Semantic Impossibility

| Saga | Action | Why Can't Compensate | Design Alternative |
|------|--------|---------------------|-------------------|
| [Saga] | [Action] | [Reason] | [Better design] |

### Compensation Order

| Saga | Forward Order | Compensation Order | Correct? |
|------|---------------|-------------------|----------|
| [Saga] | [A→B→C] | [Actual comp order] | [Yes/No] |

### Compensation Failure Handling

| Saga | Compensation | Can Fail? | Permanent Failure? | Handling |
|------|--------------|-----------|-------------------|----------|
| [Saga] | [Comp] | [Yes/No] | [Yes/No] | [Strategy] |

### Saga Timeout Assessment

| Saga | Has Timeout? | Value | Appropriate? |
|------|--------------|-------|--------------|
| [Saga] | [Yes/No] | [Duration] | [Yes/No] |

### Saga Monitoring

| Saga | Progress Tracked? | Stuck Detection? | Alerting? |
|------|-------------------|------------------|-----------|
| [Saga] | [Yes/No] | [Yes/No] | [Yes/No] |

### Business Logic in Compensation

| Saga | Compensation | Contains Logic? | Simplification |
|------|--------------|-----------------|----------------|
| [Saga] | [Comp] | [Yes/No] | [How to simplify] |

### Recommendations
1. [Add missing compensation for X]
2. [Make compensation Y idempotent]
3. [Add saga persistence for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Missing compensation for data-modifying step | CRITICAL |
| No saga state persistence | HIGH |
| Non-idempotent compensation | HIGH |
| No timeout | MEDIUM |
| Complete saga with monitoring | POSITIVE |
