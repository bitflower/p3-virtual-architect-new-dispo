---
name: latency-amplification-detector
description: Find N+1 problems, sequential call chains, and other latency amplification patterns
tools: [Read, Glob, Grep]
---

# Latency Amplification Detector

Identify patterns that multiply latency beyond necessary levels.

## Latency Amplification Patterns

### N+1 Query Problem
```
1 query: Get all orders
N queries: Get items for each order (one per order)
Total: 1 + N queries
```
**Fix:** JOIN or batch query

### Sequential HTTP Calls
```
Call A: 100ms
Call B: 100ms (waits for A)
Call C: 100ms (waits for B)
Total: 300ms
```
**Fix:** Parallelize independent calls

### Chatty APIs
```
Get user: 50ms
Get preferences: 50ms
Get settings: 50ms
Get permissions: 50ms
Total: 200ms for one "user" concept
```
**Fix:** Aggregate endpoint, GraphQL

### Synchronous Chains
```
Service A → Service B → Service C → Service D
Latency: Sum of all hops
Any slow hop delays all
```
**Fix:** Reduce hops, async where possible

### Request Amplification
```
1 user request → 10 internal requests
10 internal → 100 downstream
Latency depends on slowest path
```
**Fix:** Caching, batching, reduce fan-out

## Detection Patterns

### N+1 Indicators
```
- Loop with query inside
- "For each X, get Y"
- LazyLoading in loops
- Multiple similar queries in logs
```

### Sequential Chain Indicators
```
- await/then chains with independent calls
- Step-by-step external calls
- "After A, call B"
- Waterfall pattern
```

### Chatty API Indicators
```
- Multiple calls for one logical operation
- Fine-grained REST endpoints
- "Get X, then get Y, then get Z"
```

## Latency Analysis

### Critical Path
The longest sequential dependency chain
- Parallel operations: max(latencies)
- Sequential operations: sum(latencies)

### Latency Budget
Allocate latency across operations:
```
Total budget: 200ms
Database: 50ms
Cache: 5ms
External API: 100ms
Processing: 45ms
```

## Output Format

```markdown
## Latency Amplification Analysis

### Latency Amplification Inventory

| Pattern | Location | Multiplier | Impact | Fix |
|---------|----------|------------|--------|-----|
| [Pattern] | [Where] | [N factor] | [Added latency] | [How to fix] |

### N+1 Query Detection

| Loop | Inner Query | Est. N | Total Queries | Fix |
|------|-------------|--------|---------------|-----|
| [Loop] | [Query] | [Est. N] | [1 + N] | [Batch/Join] |

### Sequential Call Chains

| Chain | Calls | Could Parallelize? | Potential Savings |
|-------|-------|-------------------|-------------------|
| [A→B→C] | [Details] | [Which ones] | [Time saved] |

### Chatty API Patterns

| Operation | API Calls | Could Aggregate? | Proposed |
|-----------|-----------|------------------|----------|
| [Operation] | [List of calls] | [Yes/No] | [Single call] |

### Critical Path Analysis

```
[Start]
   │
   ├──[Op A: 50ms]──┐
   │                ├──[Op C: 30ms]──[End]
   └──[Op B: 100ms]─┘

Critical Path: B + C = 130ms
```

### Request Fan-Out

| Request | Fan-Out | Downstream Calls | Amplification |
|---------|---------|------------------|---------------|
| [Request] | [Width] | [What called] | [Factor] |

### Latency Budget Analysis

| Operation | Budget | Actual/Est. | Over Budget? |
|-----------|--------|-------------|--------------|
| [Op] | [Target] | [Actual] | [Yes/No] |

### Caching Opportunities

| Data | Access Frequency | Cache Benefit | TTL |
|------|------------------|---------------|-----|
| [Data] | [Frequency] | [Latency saved] | [Duration] |

### Parallelization Opportunities

| Current Sequential | Can Parallelize | Savings |
|--------------------|-----------------|---------|
| [A then B then C] | [A, B in parallel] | [Time] |

### Recommendations
1. [Fix N+1 in X with batch query]
2. [Parallelize calls in Y]
3. [Create aggregate endpoint for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| N+1 in hot path with large N | CRITICAL |
| Sequential calls that could parallelize | HIGH |
| Chatty API for common operation | HIGH |
| Deep synchronous chain | MEDIUM |
| Well-optimized call patterns | POSITIVE |
