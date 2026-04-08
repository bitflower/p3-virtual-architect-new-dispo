---
name: batching-opportunity-detector
description: Find operations that could benefit from batching to reduce overhead
tools: [Read, Glob, Grep]
---

# Batching Opportunity Detector

Identify operations that could benefit from batching to reduce overhead and improve efficiency.

## Batching Concepts

### Why Batch?
Reduce per-operation overhead:
- Network round-trips
- Database query overhead
- API rate limits
- Transaction costs

### Batching Types

**Request Batching:**
```
Before: 100 HTTP calls
After:  1 HTTP call with 100 items
```

**Query Batching:**
```
Before: SELECT ... WHERE id = 1
        SELECT ... WHERE id = 2
        (100 queries)
After:  SELECT ... WHERE id IN (1,2,...,100)
```

**Write Batching:**
```
Before: 100 INSERT statements
After:  1 INSERT with 100 rows
```

**Event Batching:**
```
Before: Publish 100 events individually
After:  Publish batch of 100 events
```

## Batching Opportunities

### N+1 Query Pattern
```
for order in orders:
    items = query("SELECT * FROM items WHERE order_id = ?", order.id)
```
**Opportunity:** Batch query for all order_ids at once

### Loop HTTP Calls
```
for item in items:
    response = http.post("/api/process", item)
```
**Opportunity:** Batch API endpoint

### Individual Inserts
```
for record in records:
    db.insert(record)
```
**Opportunity:** Bulk insert

### Sequential Event Publishing
```
for event in events:
    queue.publish(event)
```
**Opportunity:** Batch publish

## Detection Patterns

### Batching Candidates
```
- "for each" + database query inside
- "for each" + HTTP call inside
- "for each" + insert/update inside
- "for each" + publish inside
- Loop with individual operations
- Sequential API calls for list
```

### Already Batched
```
- WHERE IN (...)
- Bulk insert/update
- Batch API endpoints
- DataLoader pattern
- Batch message publishing
```

## Batching Considerations

### When to Batch
| Scenario | Benefit |
|----------|---------|
| Many small items | High (overhead dominates) |
| Network-bound | High (reduce round-trips) |
| Rate-limited API | High (fit in limits) |
| Transactional writes | High (one commit) |

### When Not to Batch
| Scenario | Reason |
|----------|--------|
| Interactive operations | Latency for early results |
| Memory constraints | Batch too large |
| Partial failure complex | Need per-item handling |
| Real-time requirements | Can't wait to batch |

### Optimal Batch Size
- Too small: Still too much overhead
- Too large: Memory issues, timeout risk
- Typical: 100-1000 items per batch

## Output Format

```markdown
## Batching Opportunity Analysis

### Batching Opportunities Identified

| Location | Operation | Current | Items | Overhead | Potential Gain |
|----------|-----------|---------|-------|----------|----------------|
| [Location] | [What] | [Individual] | [Est. count] | [Per-item cost] | [Reduction] |

### N+1 Query Patterns

| Query | Loop | Parent Entity | Fix |
|-------|------|---------------|-----|
| [Query] | [Where looped] | [Parent] | [How to batch] |

### Loop HTTP Calls

| Endpoint | Loop | Items | Batch Alternative |
|----------|------|-------|-------------------|
| [Endpoint] | [Where] | [Count] | [Batch endpoint?] |

### Individual Write Operations

| Operation | Table | Loop | Batch Method |
|-----------|-------|------|--------------|
| [Insert/Update] | [Table] | [Where] | [How to batch] |

### Event Publishing

| Publisher | Topic | Loop | Batch Support |
|-----------|-------|------|---------------|
| [Publisher] | [Topic] | [Where] | [Yes/No/Needed] |

### Batch Size Recommendations

| Operation | Current | Recommended | Reasoning |
|-----------|---------|-------------|-----------|
| [Op] | [Size/None] | [Recommended] | [Why] |

### API Batch Endpoints Needed

| Current Endpoint | Batch Version | Priority |
|------------------|---------------|----------|
| [Endpoint] | [Proposed batch] | [High/Med/Low] |

### DataLoader Opportunities

| Entity | Access Pattern | DataLoader Benefit |
|--------|---------------|-------------------|
| [Entity] | [How accessed] | [Yes/No] |

### Impact Estimation

| Batching Change | Current Cost | After Batching | Savings |
|-----------------|--------------|----------------|---------|
| [Change] | [Time/Calls] | [Time/Calls] | [Reduction] |

### Recommendations
1. [Add batch query for X]
2. [Create batch endpoint for Y]
3. [Use bulk insert for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| N+1 queries in hot path | HIGH |
| Loop HTTP calls with 100+ items | HIGH |
| Individual inserts for bulk data | MEDIUM |
| Already using appropriate batching | POSITIVE |
