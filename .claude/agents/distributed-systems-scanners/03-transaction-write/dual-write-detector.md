---
name: dual-write-detector
description: Find dangerous dual-write patterns without safety mechanisms
tools: [Read, Glob, Grep]
---

# Dual-Write Detector

Detect dual-write anti-patterns and evaluate safety mechanisms.

## What is the Dual-Write Problem?

Writing to two systems without atomic guarantee:

```
1. Write to Database A  ✓
2. Write to Database B  ✗ (fails)
→ A has data, B doesn't = inconsistent state
```

Or:
```
1. Write to Database A  ✓
   (crash here)
2. Write to Database B  (never executes)
→ A has data, B doesn't = inconsistent state
```

## Dual-Write Scenarios

### Database + Message Queue
```
Save to DB
Publish to Kafka
→ If publish fails: DB has data, no message
→ If crash between: DB has data, no message
```

### Database + External API
```
Save to DB
Call external service
→ External call fails: DB has data, external doesn't
```

### Database + Cache
```
Update DB
Update Cache
→ Cache update fails: stale cache
```

### Multiple Databases
```
Update DB A
Update DB B
→ DB B fails: inconsistent
```

## Safe Alternatives

### Transactional Outbox
```
BEGIN TRANSACTION
  Save to DB
  Save message to outbox table
COMMIT
Background: Read outbox, publish to queue
```
✓ Atomic local transaction
✓ Guaranteed eventual delivery

### Change Data Capture (CDC)
```
Write to DB
CDC captures change
CDC publishes to queue
```
✓ Single write
✓ Reliable capture

### Saga Pattern
```
Write to System A
If success: Write to System B
If B fails: Compensate in A
```
✓ Eventual consistency
✓ Handles failures

### Listen to Yourself
```
Publish event
Consumer (including self) processes
Writes to DB
```
✓ Single source
✓ Idempotent processing

## Detection Patterns

### Dual-Write Present (Dangerous)
```
- db.save() followed by queue.publish()
- "Update X then update Y"
- Two non-transactional writes in sequence
- HTTP call + DB write in same method
- "Sync to external system after save"
```

### Safe Patterns Present
```
- "outbox"
- "transactional outbox"
- CDC/Debezium
- "event store"
- "single writer"
- "listen to yourself"
```

## Analysis Questions

For each potential dual-write:
1. **What happens if second write fails?**
2. **What happens if process crashes between writes?**
3. **Is there retry logic?**
4. **Is there a compensating action?**
5. **Is eventual consistency acceptable?**

## Output Format

```markdown
## Dual-Write Analysis

### Dual-Write Inventory

| Location | Write 1 | Write 2 | Atomic? | Safety Mechanism |
|----------|---------|---------|---------|------------------|
| [Location] | [System A] | [System B] | [Yes/No] | [Outbox/CDC/None] |

### Dangerous Dual-Writes (No Safety)

| Location | Writes | Failure Scenario | Impact | Recommended Fix |
|----------|--------|------------------|--------|-----------------|
| [Location] | [What writes] | [What can go wrong] | [Consequence] | [Safe alternative] |

### Failure Scenario Analysis

| Dual-Write | Step 1 Succeeds, Step 2 Fails | Crash Between | Recovery |
|------------|------------------------------|---------------|----------|
| [Location] | [Outcome] | [Outcome] | [How to recover] |

### Safety Mechanism Evaluation

| Mechanism | Location | Implemented Correctly? | Gaps |
|-----------|----------|----------------------|------|
| [Outbox/CDC] | [Where] | [Yes/Partial/No] | [Issues] |

### Database + Queue Patterns

| Operation | DB Write | Queue Publish | Pattern | Safe? |
|-----------|----------|---------------|---------|-------|
| [Op] | [How] | [How] | [Direct/Outbox/CDC] | [Yes/No] |

### Database + API Patterns

| Operation | DB Write | API Call | Failure Handling | Safe? |
|-----------|----------|----------|------------------|-------|
| [Op] | [How] | [How] | [Strategy] | [Yes/No] |

### Cache Consistency Patterns

| Cache | Write Strategy | Invalidation | Consistency |
|-------|----------------|--------------|-------------|
| [Cache] | [Write-through/behind/aside] | [How] | [Strong/Eventual/Weak] |

### Recommendations
1. [Replace dual-writes with outbox]
2. [Add CDC for event publishing]
3. [Implement compensating actions]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| DB + External API without compensation | CRITICAL |
| DB + Queue without outbox/CDC | CRITICAL |
| Multiple DB writes without 2PC/saga | HIGH |
| Cache update without invalidation strategy | MEDIUM |
| Proper outbox/CDC implementation | POSITIVE |
