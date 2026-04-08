---
name: soft-delete-necessity-scanner
description: Find delete operations that need tombstones for safety against resurrection and concurrent operations
tools: [Read, Glob, Grep]
---

# Soft Delete Necessity Scanner

Identify where hard deletes create risks and soft deletes (tombstones) are needed.

## Why Soft Deletes Matter

### Hard Delete Risks

**1. Resurrection Problem (ABA):**
```
T1: Delete record ID=5
T2: (didn't see delete) Update record ID=5
→ Record ID=5 recreated as "zombie"
```

**2. Concurrent Operation Confusion:**
```
T1: Check exists, prepare delete
T2: Delete record
T1: Delete record → Success? Or was it T2?
```

**3. Replication Race:**
```
Node A: Delete record
Node B: (hasn't received delete) Processes update
→ Update re-creates deleted record
```

**4. Audit Trail Loss:**
```
Record deleted → No trace it ever existed
→ Compliance/audit failures
```

### Soft Delete Benefits

- Prevents resurrection (version on tombstone)
- Maintains audit trail
- Enables "undo" capabilities
- Safe with eventual consistency
- Preserves referential information

## Detection Patterns

### Hard Delete Indicators
```
- DELETE FROM table
- .Remove() / .Delete()
- "permanently delete"
- No deleted_at / is_deleted fields
- No tombstone mechanism
```

### Soft Delete Indicators
```
- deleted_at timestamp
- is_deleted / is_active flag
- status = 'DELETED'
- tombstone records
- Archive tables
```

## Necessity Criteria

### High Necessity for Soft Delete

| Scenario | Why Soft Delete Needed |
|----------|----------------------|
| Concurrent modifications | Prevent resurrection |
| Eventual consistency | Tombstone syncs deletion |
| Audit requirements | Preserve history |
| Undo capability needed | Recover deleted items |
| Foreign key references | Maintain referential info |
| Replication across nodes | Coordinate deletion |
| Event sourcing | Delete is an event, not removal |

### Acceptable Hard Delete

| Scenario | Why Hard Delete OK |
|----------|-------------------|
| Single-writer, no concurrency | No race condition |
| Immediate consistency | No replication lag |
| No audit requirements | History not needed |
| Orphan cleanup | Truly disposable data |
| Privacy compliance (GDPR) | Must actually remove data |

## Analysis Checklist

1. **Delete Operations:** Where does system delete data?
2. **Concurrency:** Can multiple processes delete/update same record?
3. **Consistency Model:** Eventual or strong?
4. **Audit Needs:** Is deletion history required?
5. **Foreign Keys:** What references deleted records?
6. **Replication:** Is data replicated with lag?

## Output Format

```markdown
## Soft Delete Necessity Analysis

### Delete Operations Inventory

| Entity | Delete Type | Concurrent Risk | Audit Need | Soft Delete? |
|--------|-------------|-----------------|------------|--------------|
| [Entity] | [Hard/Soft] | [Yes/No] | [Required/Optional] | [Has/Needs/N/A] |

### High-Risk Hard Deletes

| Entity | Risk | Scenario | Impact |
|--------|------|----------|--------|
| [Entity] | [Resurrection/Audit/Ref] | [How it happens] | [What goes wrong] |

### Tombstone Design Recommendations

| Entity | Tombstone Fields | Version Strategy | Retention |
|--------|-----------------|------------------|-----------|
| [Entity] | [deleted_at, deleted_by, version] | [Increment on delete] | [Duration] |

### Foreign Key Impact

| Deleted Entity | Referencing Entities | Current Handling | Recommended |
|---------------|---------------------|------------------|-------------|
| [Entity] | [References] | [Cascade/Orphan/Error] | [Soft delete + filter] |

### Query Impact Analysis
- **Filter Needed:** [WHERE deleted_at IS NULL]
- **Performance:** [Index on deleted_at]
- **API Changes:** [Include deleted? parameter]

### GDPR/Privacy Considerations
| Data Type | Soft Delete OK? | Hard Delete Required? |
|-----------|----------------|----------------------|
| [Data] | [Yes/No] | [For compliance] |

### Recommendations
1. [Priority soft delete conversions]
2. [Tombstone implementation approach]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Hard delete with concurrent updates possible | HIGH |
| Hard delete in eventual consistency system | HIGH |
| Hard delete on audit-required data | HIGH |
| Missing tombstone in replication | MEDIUM |
| Soft delete without version | MEDIUM |
| Appropriate soft delete in place | LOW |
| Hard delete where appropriate | LOW |
