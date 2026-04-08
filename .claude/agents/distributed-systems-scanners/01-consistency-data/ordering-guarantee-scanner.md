---
name: ordering-guarantee-scanner
description: Analyze causal dependencies, find operations requiring ordering that lack guarantees
tools: [Read, Glob, Grep]
---

# Ordering Guarantee Scanner

Analyze ordering requirements and guarantees in distributed system designs.

## Ordering Types

### No Ordering
Operations can be applied in any order.
- Suitable for: Independent operations, commutative operations
- Risk: Causal violations if dependencies exist

### FIFO (First-In-First-Out) Ordering
Operations from same source maintain order.
- Suitable for: Single-client consistency
- Risk: Cross-client operations may reorder

### Causal Ordering
Causally related operations maintain order.
- A happened-before B → A delivered before B
- Concurrent operations: order undefined
- Requires: Causal tracking (vector clocks)

### Total Ordering
All operations have single global order.
- All nodes see same sequence
- Requires: Consensus protocol (Paxos, Raft)
- Most expensive, strongest guarantee

## Dependency Detection

### Explicit Dependencies
```
- "Create parent, then create child"
- "Order must exist before line items"
- "User must exist before creating profile"
- Foreign key relationships
```

### Implicit Dependencies
```
- "Update based on current value"
- "Delete after confirming empty"
- "Process in sequence"
- Derived/computed fields
```

### Semantic Dependencies
```
- Business rules requiring order
- Workflow state transitions
- Approval chains
- Event sequences
```

## Analysis Patterns

### Causal Dependency Indicators
```
- "after" / "before" / "then"
- "depends on"
- "requires X to exist"
- Parent-child relationships
- "derived from"
- "calculated based on"
```

### Ordering Violation Indicators
```
- "order not guaranteed"
- "may arrive out of order"
- "eventually consistent"
- Async/parallel processing
- Message queues without ordering
- Load balancers distributing requests
```

## Common Problem Scenarios

### 1. Create-Before-Reference
```
Problem: Child created before parent
Fix: Ensure parent creation completes first
```

### 2. Update-After-Delete
```
Problem: Update arrives after delete
Fix: Soft deletes with ordering, or reject stale updates
```

### 3. Out-of-Order Events
```
Problem: Event B processed before Event A
Fix: Event ordering or idempotent eventual processing
```

### 4. Concurrent Modifications
```
Problem: Two updates, order determines winner
Fix: Vector clocks or explicit conflict resolution
```

## Output Format

```markdown
## Ordering Guarantee Analysis

### Ordering Requirements Identified

| Operation Pair | Dependency Type | Required Order | Current Guarantee |
|---------------|-----------------|----------------|-------------------|
| [A → B] | [Causal/Explicit/Semantic] | [A before B] | [Guaranteed/Not Guaranteed/Unknown] |

### Ordering Gaps

| Operations | Required | Provided | Risk |
|------------|----------|----------|------|
| [Operations] | [Total/Causal/FIFO] | [None/Weaker] | [What could happen] |

### Causal Chain Analysis
```
[A] ──causes──▶ [B] ──causes──▶ [C]
     └── Ordering: [Guaranteed/Not]
                         └── Ordering: [Guaranteed/Not]
```

### Message/Event Ordering
| Channel | Ordering Guarantee | Ordering Needed | Match? |
|---------|-------------------|-----------------|--------|
| [Queue/Topic] | [FIFO/None/Partition] | [Required level] | [Yes/No] |

### Commutative Operation Analysis
| Operation | Commutative? | If No, Ordering Required? |
|-----------|--------------|---------------------------|
| [Operation] | [Yes/No] | [Has guarantee/Missing] |

### Recommendations
1. [How to add missing ordering guarantees]
2. [Where to make operations commutative instead]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Parent-child ordering not guaranteed | HIGH |
| Event sourcing without ordering | HIGH |
| Workflow state transitions unordered | HIGH |
| Independent operations correctly unordered | LOW |
| Commutative operations documented | POSITIVE |
| Causal ordering implemented | POSITIVE |
