---
name: distributed-transaction-antipattern-detector
description: Find problematic distributed transaction usage patterns
tools: [Read, Glob, Grep]
---

# Distributed Transaction Anti-Pattern Detector

Detect problematic distributed transaction patterns and misuse.

## Distributed Transaction Anti-Patterns

### 1. Implicit 2PC
Assuming atomicity without protocol:
```
Update Service A
Update Service B
// Assumes both succeed or both fail
// But there's no transaction coordinator!
```
**Problem:** No actual atomicity guarantee

### 2. 2PC Over HTTP
Trying to do 2PC with HTTP services:
```
Prepare A (HTTP)
Prepare B (HTTP)
Commit A (HTTP)
Commit B (HTTP)
// HTTP doesn't support prepare/commit!
```
**Problem:** HTTP is not a transactional protocol

### 3. Long-Running 2PC
2PC holding locks for extended periods:
```
Begin Transaction
Call slow external service (30 seconds)
More work
Commit
// Locks held for 30+ seconds!
```
**Problem:** Resource contention, timeouts, deadlocks

### 4. 2PC with Unreliable Participants
Including unreliable services in 2PC:
```
Transaction includes:
- Local DB (reliable)
- Third-party API (unpredictable)
// If API is flaky, transaction blocked
```
**Problem:** Availability suffers

### 5. Nested 2PC
2PC within 2PC:
```
Outer Transaction:
  Service A (starts its own transaction)
  Service B (starts its own transaction)
// Cascading locks, complex failure
```
**Problem:** Exponential complexity

### 6. Fire-and-Hope
Hoping async is transactional:
```
Save to database
Send message to queue
// Hope they're atomic
// But if message send fails, DB has data
```
**Problem:** Dual-write without outbox

### 7. Transaction Timeout Mismatch
Different timeouts in chain:
```
Service A: timeout 60s
Service B: timeout 30s
// A waiting, B times out, chaos
```
**Problem:** Inconsistent state

## Detection Patterns

### Anti-Pattern Indicators
```
- "Transaction" across HTTP services
- "Atomic" + multiple service calls
- External API inside DB transaction
- No rollback mechanism across services
- "Distributed transaction" + HTTP/REST
- Long operations in transaction blocks
```

### Proper Patterns
```
- Saga with compensation
- Outbox pattern
- Event-driven eventual consistency
- 2PC only with XA-capable resources
- Local transactions + idempotent retries
```

## Output Format

```markdown
## Distributed Transaction Anti-Pattern Analysis

### Anti-Pattern Detection

| Anti-Pattern | Location | Severity | Evidence |
|--------------|----------|----------|----------|
| [Pattern] | [Where] | [Critical/High/Med] | [How detected] |

### Implicit 2PC Detection

| Operation | Services Involved | Assumed Atomic? | Actually Atomic? |
|-----------|-------------------|-----------------|------------------|
| [Operation] | [Services] | [Yes/No] | [No - why] |

### 2PC Over HTTP

| Transaction | Participants | Protocol | Issue |
|-------------|--------------|----------|-------|
| [Transaction] | [Services] | [HTTP] | [Can't do 2PC] |

### Long-Running Transaction Detection

| Transaction | Duration | External Calls | Lock Risk |
|-------------|----------|----------------|-----------|
| [Transaction] | [Duration] | [What calls] | [High/Med/Low] |

### Fire-and-Hope Patterns

| Operation | Database Op | Message Op | Atomic? | Fix |
|-----------|-------------|------------|---------|-----|
| [Operation] | [What] | [What] | [No] | [Outbox] |

### Transaction Timeout Analysis

| Chain | Service A TO | Service B TO | Mismatch? |
|-------|--------------|--------------|-----------|
| [Chain] | [Timeout] | [Timeout] | [Yes/No] |

### Unreliable Participants

| Transaction | Reliable Parts | Unreliable Parts | Risk |
|-------------|---------------|------------------|------|
| [Transaction] | [Parts] | [Parts] | [Availability impact] |

### Compensating Action Gaps

| Operation | Has Compensation? | All Steps Covered? | Gap |
|-----------|-------------------|-------------------|-----|
| [Operation] | [Yes/No] | [Yes/No] | [Missing] |

### Recommended Patterns

| Current Anti-Pattern | Recommended Pattern | Migration Effort |
|---------------------|---------------------|------------------|
| [Anti-pattern] | [Better pattern] | [Effort] |

### Recommendations
1. [Replace implicit 2PC with saga for X]
2. [Use outbox pattern for Y]
3. [Remove external call from transaction Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| 2PC over HTTP (impossible) | CRITICAL |
| Implicit 2PC with no guarantee | CRITICAL |
| Fire-and-hope dual write | HIGH |
| Long transaction with locks | HIGH |
| Proper saga/outbox pattern | POSITIVE |
