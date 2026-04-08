---
name: write-order-strategy-analyst
description: Evaluate remote-first vs local-first write patterns and their implications
tools: [Read, Glob, Grep]
---

# Write Order Strategy Analyst

Evaluate write ordering strategies in distributed systems with multiple data stores.

## Write Order Strategies

### Remote-First (Master-First)
```
1. Write to remote/master system
2. Only on success: Write to local system
```

**Rationale:**
- Master has authoritative data
- Local is derived/cache
- Failure at step 2 is recoverable (master has data)

**Trade-offs:**
| Pro | Con |
|-----|-----|
| Master always consistent | Higher latency |
| Local failures recoverable | Remote dependency |
| Clear source of truth | Sync complexity on local failure |

### Local-First
```
1. Write to local system
2. Then: Write to remote system (sync or async)
```

**Rationale:**
- Lower latency for user
- Works offline
- Local always available

**Trade-offs:**
| Pro | Con |
|-----|-----|
| Low latency | Split-brain risk |
| Offline capable | Conflict resolution needed |
| High availability | Complex sync |

### Parallel Write
```
1. Write to both simultaneously
2. Handle partial success
```

**Trade-offs:**
- Fastest success path
- Complex failure handling
- Consistency challenges

## Failure Mode Analysis

### Remote-First Failures

| Failure Point | Outcome | Recovery |
|---------------|---------|----------|
| Step 1 fails | Clean failure, no state change | Retry remote |
| Step 2 fails | Remote has data, local needs sync | Sync from remote |
| Network after step 1 | Remote has data, unknown locally | Detect and sync |

### Local-First Failures

| Failure Point | Outcome | Recovery |
|---------------|---------|----------|
| Step 1 fails | Clean failure | Retry local |
| Step 2 fails | Local has data remote doesn't | Retry sync, conflict possible |
| Network after step 1 | Local has data, remote behind | Eventual sync, conflicts |

## Strategy Selection Criteria

| Criterion | Remote-First | Local-First |
|-----------|--------------|-------------|
| Consistency priority | ✓ Best | Risk |
| Latency priority | Higher | ✓ Best |
| Offline requirement | ✗ No | ✓ Yes |
| Simple recovery | ✓ Yes | Complex |
| Conflict tolerance | ✓ Low | High needed |

## Detection Patterns

### Remote-First Indicators
```
- "Write to TMS first"
- "Update master then local"
- "Sync from remote on failure"
- Remote call before local transaction
```

### Local-First Indicators
```
- "Write locally then sync"
- "Outbox pattern"
- "Offline capable"
- Local transaction before remote call
```

### Unclear/Mixed Indicators
```
- Sometimes remote first, sometimes local
- No explicit strategy
- "Update both"
```

## Output Format

```markdown
## Write Order Strategy Analysis

### Strategy Inventory

| Data Flow | Current Strategy | Appropriate? | Source of Truth |
|-----------|------------------|--------------|-----------------|
| [Flow] | [Remote-First/Local-First/Mixed] | [Yes/No] | [Which system] |

### Strategy Consistency

| Operation Type | Strategy | Consistent with Others? |
|----------------|----------|------------------------|
| [Type] | [Strategy] | [Yes/No/Mixed] |

### Failure Recovery Assessment

| Strategy | Step 1 Failure | Step 2 Failure | Recovery Complexity |
|----------|---------------|----------------|---------------------|
| [Strategy] | [Outcome] | [Outcome] | [Simple/Complex] |

### Source of Truth Alignment

| Data | Declared Source | Write Strategy | Aligned? |
|------|-----------------|----------------|----------|
| [Data] | [System] | [Writes to first] | [Yes/No] |

### Local-First Conflict Handling

| Data Flow | Conflict Possible? | Resolution Strategy | Implemented? |
|-----------|-------------------|--------------------|--------------|
| [Flow] | [Yes/No] | [Strategy] | [Yes/No] |

### Sync Failure Handling

| Flow | Sync Failure Handling | Retry? | Alerting? |
|------|----------------------|--------|-----------|
| [Flow] | [What happens] | [Yes/No] | [Yes/No] |

### Offline Capability

| Operation | Works Offline? | Sync Strategy | Conflict Resolution |
|-----------|---------------|---------------|---------------------|
| [Operation] | [Yes/No] | [How syncs] | [How resolved] |

### Recommendations
1. [Standardize on appropriate strategy]
2. [Add sync failure handling]
3. [Implement conflict resolution for local-first]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Local-first without conflict resolution | HIGH |
| Mixed strategies without clear rationale | HIGH |
| Write to cache/replica first, master second | HIGH |
| Remote-first with no local sync recovery | MEDIUM |
| Clear strategy aligned with source of truth | POSITIVE |
