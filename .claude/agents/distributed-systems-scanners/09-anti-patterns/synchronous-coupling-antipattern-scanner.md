---
name: synchronous-coupling-antipattern-scanner
description: Find brittle synchronous dependency chains that affect availability
tools: [Read, Glob, Grep]
---

# Synchronous Coupling Anti-Pattern Scanner

Detect problematic synchronous dependency chains.

## Synchronous Coupling Problems

### Availability Multiplication
Each sync dependency reduces availability:
```
Service A (99.9%) → Service B (99.9%) → Service C (99.9%)
Chain availability = 0.999 × 0.999 × 0.999 = 99.7%
```
More hops = worse availability

### Latency Addition
Each sync call adds latency:
```
A: 50ms → B: 100ms → C: 50ms
Total: 200ms minimum
(Plus network overhead)
```

### Failure Cascading
One failure breaks the chain:
```
C fails → B fails → A fails → User sees error
```

### Resource Binding
Threads/connections held waiting:
```
A calls B synchronously
A's thread waits
A's connection pool tied up
```

## Problematic Patterns

### Deep Sync Chains
```
A → B → C → D → E (5 hops sync)
```
**Problem:** Low availability, high latency

### Sync for Fire-and-Forget
```
User action → sync call to notification service
User waits for email to send
```
**Problem:** User waits unnecessarily

### Sync Call in Loop
```
for item in items:
    sync_call(item)
// N serial calls
```
**Problem:** N × latency

### No Timeout/No Fallback
```
sync_call(service_b)
// No timeout: waits forever
// No fallback: fails if B fails
```
**Problem:** Stuck requests, no graceful degradation

### Critical Path Sync
```
User request requires sync calls to:
- Auth service
- Data service
- Feature service
- External API
// All must succeed for request
```
**Problem:** Any failure blocks user

## Better Alternatives

### Async Messaging
```
A publishes event → B consumes later
A doesn't wait for B
```

### Parallel Calls
```
Results = await all([call_B(), call_C(), call_D()])
// Parallel instead of sequential
```

### Caching
```
If cached: return cache
Else: sync call, cache result
```

### Circuit Breaker + Fallback
```
try: sync call with circuit breaker
fallback: degraded response
```

## Output Format

```markdown
## Synchronous Coupling Analysis

### Sync Chain Inventory

| Chain | Depth | Critical Path? | Availability Impact |
|-------|-------|----------------|---------------------|
| [Chain] | [Hops] | [Yes/No] | [Calculated %] |

### Availability Calculation

| Chain | Individual Availability | Chain Availability | Target | Gap |
|-------|------------------------|-------------------|--------|-----|
| [Chain] | [Each service %] | [Product] | [SLA] | [Difference] |

### Latency Analysis

| Chain | Per-Hop Latency | Total Latency | Target | Gap |
|-------|-----------------|---------------|--------|-----|
| [Chain] | [Breakdown] | [Sum] | [Target] | [Over?] |

### Unnecessary Sync Calls

| Operation | Current | Could Be Async? | Benefit |
|-----------|---------|-----------------|---------|
| [Operation] | [Sync] | [Yes/No] | [Latency saved] |

### Sync Calls in Loops

| Location | Loop Size | Current | Parallelizable? | Batch-able? |
|----------|-----------|---------|-----------------|-------------|
| [Location] | [Size] | [Serial sync] | [Yes/No] | [Yes/No] |

### Timeout Analysis

| Sync Call | Has Timeout? | Value | Appropriate? |
|-----------|--------------|-------|--------------|
| [Call] | [Yes/No] | [Value] | [Yes/No] |

### Fallback Analysis

| Sync Call | Has Fallback? | Fallback Type | Quality |
|-----------|---------------|---------------|---------|
| [Call] | [Yes/No] | [Type] | [Good/Poor] |

### Circuit Breaker Coverage

| Sync Call | Has CB? | Config | Appropriate? |
|-----------|---------|--------|--------------|
| [Call] | [Yes/No] | [Config] | [Yes/No] |

### Parallelization Opportunities

| Current Serial | Can Parallelize | Savings |
|----------------|-----------------|---------|
| [A→B→C] | [A, B, C parallel] | [Time] |

### Async Conversion Opportunities

| Sync Operation | Async Alternative | Effort | Benefit |
|----------------|-------------------|--------|---------|
| [Operation] | [Event/Queue] | [Effort] | [Benefit] |

### Recommendations
1. [Add fallback for critical sync X]
2. [Convert Y to async]
3. [Parallelize calls in Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Sync chain > 3 hops in critical path | CRITICAL |
| Sync call without timeout | HIGH |
| Sync chain without fallback | HIGH |
| Unnecessary sync for async operation | MEDIUM |
| Short sync chains with fallbacks | POSITIVE |
