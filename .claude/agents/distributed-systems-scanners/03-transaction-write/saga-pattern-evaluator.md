---
name: saga-pattern-evaluator
description: Detect saga implementations, assess compensation completeness and failure handling
tools: [Read, Glob, Grep]
---

# Saga Pattern Evaluator

Evaluate saga pattern implementations for completeness and correctness.

## Saga Pattern Overview

### What is a Saga?
A sequence of local transactions where:
- Each step has a compensating action
- If a step fails, previous steps are compensated
- Achieves eventual consistency without 2PC

### Saga Types

**Choreography:**
```
Each service listens for events and acts
No central coordinator
Services know their compensations
```

**Orchestration:**
```
Central orchestrator directs flow
Explicit state machine
Orchestrator triggers compensations
```

## Saga Components

### Forward Actions
The actual business operations:
```
1. Create order
2. Reserve inventory
3. Charge payment
4. Ship order
```

### Compensating Actions
Undo previous steps on failure:
```
1. Cancel order
2. Release inventory
3. Refund payment
4. Cancel shipment
```

### Compensation Rules
- Compensations execute in reverse order
- Compensations must be idempotent
- Compensations must eventually succeed
- Compensations may have their own retries

## Completeness Checklist

### For Each Step:
- [ ] Forward action defined
- [ ] Compensation action defined
- [ ] Compensation is idempotent
- [ ] Compensation handles "nothing to compensate"
- [ ] Compensation has retry logic
- [ ] Step failure triggers compensation chain

### For the Saga:
- [ ] All steps have compensations
- [ ] Compensation order is correct (reverse)
- [ ] Intermediate state is valid
- [ ] Timeout handling exists
- [ ] State is persisted for recovery

## Common Problems

### 1. Missing Compensation
```
Step 3 fails
Compensation for step 2: ✓
Compensation for step 1: ✗ MISSING
→ Partial state remains
```

### 2. Non-Idempotent Compensation
```
Compensation runs twice (retry)
Second run has unexpected effect
→ Over-compensation
```

### 3. Compensation Fails
```
Step 3 fails
Compensation for step 2 fails
→ Stuck in inconsistent state
```

### 4. Semantic Impossibility
```
Action: Send email
Compensation: ??? (Can't unsend)
→ Must design around it
```

## Detection Patterns

### Saga Present
```
- "saga"
- "compensation" / "compensating"
- "rollback" in distributed context
- Orchestrator service
- State machine for business process
- "undo" actions
```

### Incomplete Saga
```
- Forward actions without compensations
- "TODO: add compensation"
- Some steps compensated, others not
- No handling for compensation failure
```

## Output Format

```markdown
## Saga Pattern Analysis

### Saga Inventory

| Saga | Type | Steps | Trigger | State Storage |
|------|------|-------|---------|---------------|
| [Saga name] | [Choreography/Orchestration] | [Count] | [What starts it] | [Where state stored] |

### Step Completeness Matrix

| Saga | Step | Forward Action | Compensation | Idempotent? | Tested? |
|------|------|---------------|--------------|-------------|---------|
| [Saga] | [Step] | [Action] | [Compensation/MISSING] | [Yes/No] | [Yes/No] |

### Compensation Gaps

| Saga | Step | Missing | Risk | Recommended Compensation |
|------|------|---------|------|-------------------------|
| [Saga] | [Step] | [What's missing] | [Impact] | [What to implement] |

### Non-Compensatable Actions

| Saga | Action | Why Non-Compensatable | Mitigation |
|------|--------|----------------------|------------|
| [Saga] | [Action] | [Reason] | [How handled] |

### Compensation Failure Handling

| Saga | Compensation Fails | Current Handling | Adequate? |
|------|-------------------|------------------|-----------|
| [Saga] | [Which comp] | [What happens] | [Yes/No] |

### Saga State Management

| Saga | State Persisted? | Recovery on Restart? | Timeout? |
|------|------------------|---------------------|----------|
| [Saga] | [Yes/No] | [Yes/No] | [Duration/None] |

### Choreography vs Orchestration Assessment

| Saga | Current Type | Complexity | Visibility | Recommended |
|------|--------------|------------|------------|-------------|
| [Saga] | [Type] | [Assessment] | [Assessment] | [Same/Change] |

### Recommendations
1. [Add missing compensations]
2. [Make compensations idempotent]
3. [Add compensation failure handling]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Saga step without compensation | CRITICAL |
| Compensation that can permanently fail | HIGH |
| Non-idempotent compensation | HIGH |
| No saga state persistence | MEDIUM |
| Complete saga with testing | POSITIVE |
