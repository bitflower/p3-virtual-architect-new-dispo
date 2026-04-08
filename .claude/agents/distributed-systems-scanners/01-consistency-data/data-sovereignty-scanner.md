---
name: data-sovereignty-scanner
description: Identify source-of-truth ownership, detect split-brain risks, validate master-replica patterns
tools: [Read, Glob, Grep]
---

# Data Sovereignty Scanner

Analyze data ownership patterns and detect split-brain risks.

## Data Sovereignty Concepts

### Source of Truth
The authoritative location for data:
- Where writes should go first
- What other systems derive from
- The "master" in master-replica patterns

### Split-Brain Risk
When multiple systems believe they are the source of truth:
- Conflicting updates accepted
- No clear winner
- Data divergence without detection

### Derived Data
Data computed or replicated from source of truth:
- Caches
- Read replicas
- Materialized views
- Denormalized copies

## Detection Patterns

### Source of Truth Indicators
```
- "System of record"
- "Master database"
- "Primary" / "authoritative"
- "Single source of truth"
- "Write to X first"
```

### Split-Brain Indicators
```
- Multiple systems accepting writes independently
- No clear write ordering
- "Both systems can update"
- Bidirectional sync
- Conflict resolution needed
```

### Derived Data Indicators
```
- "Cache" / "replica" / "copy"
- "Sync from"
- "Derived from"
- "Materialized view"
- "Eventually updated from"
```

## Ownership Patterns

### Clear Ownership (Good)
```
[Source of Truth: System A]
       │
       ├──▶ [Replica: System B] (read-only)
       │
       └──▶ [Cache: System C] (read-only)
```

### Unclear Ownership (Risk)
```
[System A] ◀──?──▶ [System B]
    │                   │
    └── Both accept ────┘
        writes
```

### Partitioned Ownership (Complex but OK)
```
[System A: owns Entity X]
[System B: owns Entity Y]
[System C: owns Entity Z]
- Clear boundaries per entity type
```

## Analysis Checklist

1. **For each entity type:** Who is the source of truth?
2. **Write paths:** Where do writes go first?
3. **Replication:** How does data flow to other systems?
4. **Conflict potential:** Can two systems accept conflicting writes?
5. **Recovery:** If systems diverge, how to reconcile?

## Output Format

```markdown
## Data Sovereignty Analysis

### Entity Ownership Map

| Entity Type | Source of Truth | Replicas/Caches | Write Path |
|-------------|-----------------|-----------------|------------|
| [Entity] | [System] | [Systems] | [How writes flow] |

### Split-Brain Risks

| Entity | Systems | Can Both Write? | Conflict Resolution |
|--------|---------|-----------------|---------------------|
| [Entity] | [A, B] | [Yes/No] | [How resolved / None] |

### Master-First Write Validation

| Operation | Expected Path | Actual Path | Compliant? |
|-----------|--------------|-------------|------------|
| [Operation] | [Write master → sync replicas] | [Actual flow] | [Yes/No] |

### Derived Data Mapping

| Derived Data | Source | Sync Mechanism | Staleness Window |
|--------------|--------|----------------|------------------|
| [Data] | [Source system] | [How synced] | [How stale it can be] |

### Ownership Ambiguities

| Entity | Ambiguity | Risk | Resolution Needed |
|--------|-----------|------|-------------------|
| [Entity] | [What's unclear] | [Split-brain/divergence] | [How to clarify] |

### Network Partition Behavior

| Partition Scenario | Source of Truth Behavior | Other Systems | Reconvergence |
|-------------------|-------------------------|---------------|---------------|
| [Scenario] | [What happens] | [What happens] | [How to recover] |

### Recommendations
1. [Clear ownership assignments needed]
2. [Write path corrections]
3. [Replication improvements]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Multiple systems accept writes for same entity | CRITICAL |
| No defined source of truth | HIGH |
| Bidirectional sync without conflict resolution | HIGH |
| Writes to replica before master | MEDIUM |
| Unclear ownership but low write volume | MEDIUM |
| Clear ownership documented | LOW |
| Master-first write pattern implemented | POSITIVE |

## Common Anti-Patterns

### 1. Dual Master Without Coordination
```
Problem: Both systems think they're master
Fix: Designate single master or implement CRDT
```

### 2. Local-First Without Sync Strategy
```
Problem: Write locally, hope it syncs
Fix: Explicit sync mechanism with conflict handling
```

### 3. Cache as Source
```
Problem: Reading from cache, writing to cache
Fix: Write-through to source of truth
```

### 4. Implicit Ownership
```
Problem: "Everyone knows System A owns this"
Fix: Document ownership explicitly
```
