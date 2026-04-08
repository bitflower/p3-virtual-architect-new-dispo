---
name: shared-database-antipattern-detector
description: Find services sharing databases inappropriately
tools: [Read, Glob, Grep]
---

# Shared Database Anti-Pattern Detector

Detect inappropriate database sharing between services.

## The Shared Database Anti-Pattern

### What is it?
Multiple services directly accessing the same database:
```
Service A ─────┐
               ├───▶ Shared Database
Service B ─────┘
```

### Why is it problematic?

**Tight Coupling:**
- Schema changes affect multiple services
- Must coordinate deployments
- Testing becomes complex

**Ownership Ambiguity:**
- Who owns which tables?
- Who can modify what?
- Conflicting migrations

**Scaling Challenges:**
- Can't scale database per service
- Connection pool exhaustion
- Query interference

**Independence Loss:**
- Services can't evolve independently
- Technology lock-in
- Single point of failure

## Acceptable Shared Database Scenarios

### Read Replicas
Services read from replica:
```
Service A (writes) ──▶ Primary DB
                           │ replication
Service B (reads)  ──▶ Replica
```

### Shared Reference Data
Static, rarely changing data:
```
Country codes, currencies, etc.
All services read, none write
```

### Legacy Migration
Temporary during transition:
```
Old monolith ──┐
               ├──▶ Shared DB (temporary)
New service ───┘
(With migration plan!)
```

## Detection Patterns

### Shared Database Indicators
```
- Same connection string in multiple services
- Same schema accessed by multiple services
- Shared database migrations
- "Other service uses this table"
- Connection pool issues across services
```

### Good Separation Indicators
```
- Each service has own database/schema
- Data shared via APIs
- Events for data propagation
- Clear data ownership
```

## Output Format

```markdown
## Shared Database Analysis

### Database Sharing Inventory

| Database | Services | Shared Tables | Problematic? |
|----------|----------|---------------|--------------|
| [Database] | [Services] | [Tables] | [Yes/No] |

### Service Database Ownership

| Service | Owns Database? | Owns Schema? | Shared With |
|---------|---------------|--------------|-------------|
| [Service] | [Yes/No] | [Yes/No] | [Other services] |

### Table Ownership Analysis

| Table | Primary Owner | Other Accessors | Access Type |
|-------|---------------|-----------------|-------------|
| [Table] | [Service] | [Services] | [Read/Write] |

### Write Conflicts

| Table | Writers | Conflict Risk | Resolution |
|-------|---------|---------------|------------|
| [Table] | [Services] | [High/Med/Low] | [How resolved] |

### Schema Change Impact

| Schema Change | Services Affected | Coordination Required |
|---------------|-------------------|----------------------|
| [Change] | [Services] | [Effort] |

### Migration Coordination

| Database | Migration Ownership | Multiple Migrators? | Risk |
|----------|--------------------|--------------------|------|
| [Database] | [Owner] | [Yes/No] | [Level] |

### Connection Pool Analysis

| Database | Total Connections | Per-Service | Exhaustion Risk |
|----------|-------------------|-------------|-----------------|
| [Database] | [Total] | [Breakdown] | [Risk] |

### Data Propagation Alternative

| Shared Data | Current Method | Alternative | Effort |
|-------------|---------------|-------------|--------|
| [Data] | [Direct DB access] | [API/Events] | [Effort] |

### Separation Roadmap

| Phase | Action | Services | Effort |
|-------|--------|----------|--------|
| 1 | [Action] | [Services] | [Effort] |
| 2 | [Action] | [Services] | [Effort] |

### Acceptable Sharing Assessment

| Shared Database | Reason | Acceptable? | Mitigation |
|-----------------|--------|-------------|------------|
| [Database] | [Why shared] | [Yes/No] | [If no, fix] |

### Recommendations
1. [Separate database for service X]
2. [Create API for shared data Y]
3. [Add event propagation for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Multiple services writing same tables | CRITICAL |
| Shared database, no separation plan | HIGH |
| Schema changes require multi-service deploy | HIGH |
| Read-only sharing of reference data | LOW |
| Each service owns its data | POSITIVE |
