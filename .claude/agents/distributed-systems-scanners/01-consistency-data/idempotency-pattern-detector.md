---
name: idempotency-pattern-detector
description: Find idempotency implementations (keys, state-inspection, natural), identify gaps where idempotency is needed but missing
tools: [Read, Glob, Grep]
---

# Idempotency Pattern Detector

Analyze architecture documents for idempotency patterns and identify gaps.

## Idempotency Types

### 1. Natural Idempotency
Operations that are inherently idempotent:
- SET operations (overwrite with same value)
- DELETE operations (delete already-deleted = no-op)
- Absolute assignments (set balance to X, not add X)

### 2. Idempotency Keys
Client-generated unique keys to deduplicate:
```
POST /orders
X-Idempotency-Key: uuid-12345
```
- Requires server-side key storage
- TTL for key expiration
- Key collision handling

### 3. State-Inspection Idempotency (GET-before-MUTATE)
Check current state before operation:
```
1. GET record
2. IF exists AND creating → convert to UPDATE
3. IF not exists AND deleting → skip
4. ELSE → proceed
```
- No key storage required
- TOCTOU vulnerability
- Extra network round-trip

### 4. Version-Based Idempotency
Conditional writes with version checks:
```
UPDATE ... WHERE version = expected_version
```
- Optimistic concurrency control
- Prevents lost updates
- Requires version tracking

## Detection Patterns

### Idempotency Key Patterns
```
- "idempotency key"
- "X-Idempotency-Key"
- "request ID" + "deduplication"
- "unique request identifier"
- "idempotent token"
```

### State-Inspection Patterns
```
- "check if exists" + "before" + "create"
- "GET" + "before" + "POST/PUT/DELETE"
- "upsert"
- "CREATE → UPDATE conversion"
- "operation morphing"
```

### Version-Based Patterns
```
- "optimistic locking"
- "version check"
- "ETag"
- "If-Match"
- "conditional update"
```

## Gap Detection

### Operations Requiring Idempotency

| Operation Type | Why Idempotency Needed |
|----------------|------------------------|
| Cross-service writes | Network failures cause retries |
| Payment/financial | Double-charge prevention |
| External API calls | Timeout != failure |
| Async message handlers | At-least-once delivery |
| User-facing mutations | Accidental double-clicks |

### Red Flags (Missing Idempotency)

- POST to external service without idempotency handling
- "Fire and forget" to non-idempotent endpoints
- Retry logic without deduplication
- Message queue consumption without idempotent processing
- Financial operations without duplicate detection

## Output Format

```markdown
## Idempotency Pattern Analysis

### Detected Idempotency Implementations

| Operation | Pattern Type | Implementation | Completeness |
|-----------|--------------|----------------|--------------|
| [Operation] | [Key/State-Inspect/Version/Natural] | [How] | [Complete/Partial/Missing] |

### Idempotency Gaps

| Operation | Risk | Current Handling | Recommended Pattern |
|-----------|------|------------------|---------------------|
| [Operation] | [High/Med/Low] | [None/Partial] | [Recommended approach] |

### TOCTOU Vulnerabilities
- **Location:** [Where state-inspection is used]
- **Risk:** [What could happen between check and write]
- **Mitigation:** [How to fix]

### Retry Safety Assessment
| Retry Scenario | Idempotent? | Evidence |
|----------------|-------------|----------|
| [Scenario] | [Yes/No/Partial] | [Evidence] |

### Recommendations
1. [Prioritized list of idempotency improvements]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Financial/payment ops without idempotency | CRITICAL |
| Cross-service writes without deduplication | HIGH |
| State-inspection with race condition risk | MEDIUM |
| Natural idempotency not documented | LOW |
| Comprehensive idempotency with tests | POSITIVE |
