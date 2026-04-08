---
name: timeout-strategy-scanner
description: Find timeout configurations, detect inconsistent/missing timeouts across system boundaries
tools: [Read, Glob, Grep]
---

# Timeout Strategy Scanner

Analyze timeout configurations for completeness and consistency.

## Timeout Types

### Connection Timeout
Time to establish connection:
- TCP handshake
- TLS negotiation
- Typical: 1-10 seconds

### Read/Response Timeout
Time waiting for response after sending request:
- Server processing time
- Response transmission
- Typical: 5-60 seconds (operation dependent)

### Idle/Keep-Alive Timeout
Time connection can be idle before closing:
- Connection pool management
- Resource cleanup
- Typical: 30-300 seconds

### Total/Request Timeout
End-to-end time budget for entire operation:
- Includes all retries
- User-perceived latency
- Typical: Context-dependent

## Timeout Chain Rules

### Fundamental Rule
```
Caller timeout > Callee timeout + processing overhead
```

### Why This Matters
```
Bad: Caller=30s, Callee=30s
     Callee takes 29s → Caller times out at 30s
     Work wasted, unclear error

Good: Caller=35s, Callee=30s
      Callee times out first → clear error to caller
```

### Multi-Hop Chains
```
A (60s) → B (45s) → C (30s) → D (15s)
           │         │         │
           └─────────┴─────────┴── Each level has margin
```

## Detection Patterns

### Timeout Present
```
- "timeout"
- "Timeout"
- "RequestTimeout"
- "connectTimeout" / "readTimeout"
- TimeSpan, Duration in config
- "deadline"
```

### Missing Timeout Indicators
```
- HTTP client without explicit timeout
- Database connection without timeout
- "default timeout" (often infinite)
- No timeout mentioned for external calls
- Sync call without time budget
```

## Common Problems

### 1. No Timeout (Infinite Wait)
```
Problem: Request hangs forever
Fix: Always specify explicit timeout
```

### 2. Timeout Too Long
```
Problem: Resources held, poor UX
Fix: Match to actual SLA requirements
```

### 3. Timeout Too Short
```
Problem: Legitimate requests fail
Fix: Measure P99 latency, add margin
```

### 4. Timeout Chain Violation
```
Problem: Caller times out before callee
Fix: Ensure caller > callee + overhead
```

### 5. Missing Retry Timeout Budget
```
Problem: Retries extend total time unbounded
Fix: Total timeout budget across all retries
```

## Output Format

```markdown
## Timeout Strategy Analysis

### Timeout Inventory

| Component | Connection | Read | Total | Source |
|-----------|------------|------|-------|--------|
| [Component] | [Value/None] | [Value/None] | [Value/None] | [Config location] |

### Missing Timeouts

| Component | Call Type | Risk | Recommended |
|-----------|-----------|------|-------------|
| [Component] | [HTTP/DB/etc] | [Hang forever, resource exhaust] | [Suggested value] |

### Timeout Chain Validation

| Caller | Callee | Caller TO | Callee TO | Valid? | Fix |
|--------|--------|-----------|-----------|--------|-----|
| [Service] | [Service] | [Value] | [Value] | [Yes/No] | [Correction] |

### Timeout Consistency

| Service | Different Callers | Timeout Range | Consistent? |
|---------|-------------------|---------------|-------------|
| [Service] | [Callers] | [Min-Max] | [Yes/No] |

### Total Time Budget Analysis

| Operation | User Expectation | Timeout Sum | Retries | Actual Max | OK? |
|-----------|------------------|-------------|---------|------------|-----|
| [Operation] | [Expected] | [Sum of TOs] | [Count] | [Real max] | [Yes/No] |

### Default Timeout Risks

| Component | Default Used | Default Value | Risk |
|-----------|--------------|---------------|------|
| [Component] | [Yes/No] | [Value/Unknown] | [What could happen] |

### Idle Timeout Coordination

| Client | Server | Client Idle | Server Idle | Issue? |
|--------|--------|-------------|-------------|--------|
| [Client] | [Server] | [Value] | [Value] | [Server closes first?] |

### Recommendations
1. [Add missing timeouts]
2. [Fix chain violations]
3. [Adjust for actual latency]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| External call without timeout | CRITICAL |
| Timeout chain violation | HIGH |
| Default/unknown timeout used | HIGH |
| Timeout >> actual SLA | MEDIUM |
| All timeouts explicit and consistent | POSITIVE |
