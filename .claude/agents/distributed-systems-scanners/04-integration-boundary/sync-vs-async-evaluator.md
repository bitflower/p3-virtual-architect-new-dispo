---
name: sync-vs-async-evaluator
description: Assess synchronous vs asynchronous pattern fitness for each integration
tools: [Read, Glob, Grep]
---

# Synchronous vs Asynchronous Evaluator

Evaluate whether synchronous or asynchronous patterns are appropriate for each integration.

## Pattern Characteristics

### Synchronous Communication
```
Client ──request──▶ Server
Client ◀──response── Server
(Client waits)
```

**Characteristics:**
- Immediate response
- Simple programming model
- Temporal coupling
- Availability coupling

### Asynchronous Communication
```
Sender ──message──▶ Queue ──message──▶ Receiver
(Sender continues immediately)
```

**Characteristics:**
- Decoupled timing
- Higher availability
- Complex flow
- Eventual consistency

## Selection Criteria

### Use Synchronous When:

| Criterion | Example |
|-----------|---------|
| Immediate response required | User waiting for result |
| Request-response semantics | Query for data |
| Strong consistency needed | Check before action |
| Simple operations | Get user profile |
| Low latency requirement | Real-time UX |

### Use Asynchronous When:

| Criterion | Example |
|-----------|---------|
| Long-running operation | Process video |
| Fire-and-forget acceptable | Send notification |
| Spiky load | Buffer for processing |
| Eventual consistency OK | Update recommendations |
| High availability needed | Accept orders even if fulfillment slow |
| Cross-service workflows | Order → Inventory → Shipping |

## Misfit Patterns

### Sync Where Async Better
```
Problem: User clicks "Process Report"
Current: Sync call waits 30 seconds
Better: Async with status polling/callback
```
Signs:
- Long timeouts
- User waiting
- Retry on timeout
- Connection exhaustion

### Async Where Sync Better
```
Problem: Check inventory before purchase
Current: Async message, wait for response
Better: Sync call with cache
```
Signs:
- Sync wrapper around async
- Waiting for message reply
- Complex correlation
- Simple request-response forced into events

## Evaluation Questions

For each integration:
1. **Does caller need immediate response?**
2. **Can caller continue without response?**
3. **How long does operation take?**
4. **What's the availability requirement?**
5. **What consistency model is acceptable?**

## Output Format

```markdown
## Sync vs Async Analysis

### Integration Pattern Inventory

| Integration | Current Pattern | Latency | Consistency | Availability |
|-------------|-----------------|---------|-------------|--------------|
| [Integration] | [Sync/Async] | [Expected] | [Required] | [Required] |

### Pattern Fitness Assessment

| Integration | Current | Response Need | Duration | Recommended | Match? |
|-------------|---------|---------------|----------|-------------|--------|
| [Integration] | [Sync/Async] | [Immediate/Eventual] | [Short/Long] | [Sync/Async] | [Yes/No] |

### Synchronous Pattern Issues

| Integration | Issue | Impact | Alternative |
|-------------|-------|--------|-------------|
| [Integration] | [Long wait/Availability coupling/etc] | [What happens] | [Async approach] |

### Asynchronous Pattern Issues

| Integration | Issue | Impact | Alternative |
|-------------|-------|--------|-------------|
| [Integration] | [Unnecessary complexity/Sync-over-async/etc] | [What happens] | [Sync approach] |

### User Experience Impact

| Operation | Current UX | With Current Pattern | With Alternative |
|-----------|------------|---------------------|------------------|
| [Operation] | [Experience] | [Impact] | [Better/Worse] |

### Availability Analysis

| Integration | Current | If Callee Down | Decoupled Alternative |
|-------------|---------|----------------|----------------------|
| [Integration] | [Sync/Async] | [Impact] | [Can use async?] |

### Consistency Tradeoffs

| Integration | Current Consistency | Business Requirement | Match? |
|-------------|--------------------|--------------------|--------|
| [Integration] | [Strong/Eventual] | [Needed] | [Yes/Over/Under] |

### Long-Running Operations

| Operation | Duration | Current Pattern | User Feedback | Recommendation |
|-----------|----------|-----------------|---------------|----------------|
| [Op] | [Time] | [Sync/Async] | [How user knows status] | [Keep/Change] |

### Recommendations
1. [Convert to async for long-running X]
2. [Simplify to sync for simple Y]
3. [Add polling/webhook for operation Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Sync with 30s+ timeout | HIGH |
| User waiting on sync long-running op | HIGH |
| Sync-over-async anti-pattern | MEDIUM |
| Unnecessary async complexity | MEDIUM |
| Pattern matches requirements | POSITIVE |
