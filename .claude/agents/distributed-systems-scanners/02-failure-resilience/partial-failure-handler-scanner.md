---
name: partial-failure-handler-scanner
description: Find operations that need partial failure handling but lack it
tools: [Read, Glob, Grep]
---

# Partial Failure Handler Scanner

Identify operations that can partially succeed and evaluate their handling.

## What is Partial Failure?

When an operation involves multiple steps/components and some succeed while others fail:
- Batch processing: 90 of 100 items succeed
- Distributed transaction: Some services committed, others failed
- Multi-target writes: Some replicas updated, others not
- Aggregate operations: Some sub-operations complete

## Partial Failure Scenarios

### 1. Batch Operations
```
Process 100 items:
- 95 succeed
- 5 fail
Question: What's the response? What happens to the 5?
```

### 2. Multi-Service Operations
```
Create Order:
1. Create order record ✓
2. Reserve inventory ✓
3. Charge payment ✗
Question: What happens to step 1 and 2?
```

### 3. Distributed Writes
```
Write to 3 replicas:
- Replica A: ✓
- Replica B: ✓
- Replica C: ✗
Question: Is this success or failure?
```

### 4. Aggregate Queries
```
Query 5 services for dashboard:
- Service A: responds
- Service B: responds
- Service C: timeout
Question: Show partial data or error?
```

## Handling Strategies

### All-or-Nothing
```
Any failure → rollback all
+ Simple semantics
- May waste successful work
- Requires distributed transaction
```

### Best Effort
```
Do as much as possible
Report what failed
+ No wasted work
- Complex error handling
- Client must handle partial
```

### Compensating Actions
```
On failure → undo completed steps
+ Eventual consistency
- Compensation may fail
- Complex to implement
```

### Partial Result
```
Return what succeeded
Mark what failed
+ Transparency
- Client complexity
- Retry logic needed
```

## Detection Patterns

### Needs Partial Failure Handling
```
- Batch/bulk operations
- "for each" / "foreach" loops over external calls
- Multi-service orchestration
- Aggregate data from multiple sources
- "Process all"
- Parallel execution
```

### Proper Handling Indicators
```
- "partial success"
- "failed items"
- "success count / failure count"
- Compensation logic
- Batch result with per-item status
- "best effort"
```

### Missing Handling Indicators
```
- Single success/failure for batch
- Throw on first error
- No per-item status
- "All or nothing" without transaction
- Ignoring some failures
```

## Output Format

```markdown
## Partial Failure Analysis

### Operations with Partial Failure Risk

| Operation | Type | Components | Partial Possible? | Handling |
|-----------|------|------------|-------------------|----------|
| [Operation] | [Batch/Multi-service/etc] | [What's involved] | [Yes/No] | [Strategy/None] |

### Batch Operation Assessment

| Batch Op | Item Count | Per-Item Status? | Failure Response | Retry Support |
|----------|------------|------------------|------------------|---------------|
| [Op] | [Count/Variable] | [Yes/No] | [What happens] | [Yes/No] |

### Multi-Service Operation Assessment

| Operation | Services | Atomicity | Compensation | Gap |
|-----------|----------|-----------|--------------|-----|
| [Op] | [Services] | [Required?] | [Implemented?] | [Yes/No] |

### Partial Success Semantics

| Operation | Success Definition | Partial = Success? | Documented? |
|-----------|-------------------|-------------------|-------------|
| [Op] | [What is success] | [Yes/No/Configurable] | [Yes/No] |

### Error Aggregation

| Operation | Multiple Errors Possible? | How Reported | Actionable? |
|-----------|--------------------------|--------------|-------------|
| [Op] | [Yes/No] | [First only/All/Summary] | [Yes/No] |

### Client Handling Requirements

| Operation | Client Must Handle | Documented? | Example Provided? |
|-----------|-------------------|-------------|-------------------|
| [Op] | [Partial result/Retry/etc] | [Yes/No] | [Yes/No] |

### Recommendations
1. [Add per-item status to batches]
2. [Implement compensation for multi-service]
3. [Document partial success semantics]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Multi-service op with no compensation | HIGH |
| Batch loses failed items silently | HIGH |
| Partial failure possible but undocumented | MEDIUM |
| First-error-only hides other failures | MEDIUM |
| Clear partial success handling | POSITIVE |
