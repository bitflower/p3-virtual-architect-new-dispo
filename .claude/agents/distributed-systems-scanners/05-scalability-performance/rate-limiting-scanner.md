---
name: rate-limiting-scanner
description: Find rate limiting implementations (or missing ones) for protection and fairness
tools: [Read, Glob, Grep]
---

# Rate Limiting Scanner

Identify rate limiting implementations and gaps for system protection.

## Rate Limiting Purposes

### Protection
- Prevent system overload
- Protect downstream dependencies
- Mitigate DoS attacks
- Control resource usage

### Fairness
- Prevent single client monopolization
- Ensure equitable access
- Multi-tenant isolation

### Cost Control
- Limit expensive operations
- Control external API costs
- Budget enforcement

## Rate Limiting Strategies

### Fixed Window
```
100 requests per minute (resets on minute boundary)
```
+ Simple
- Burst at window edges

### Sliding Window
```
100 requests in last 60 seconds (rolling)
```
+ Smoother
- More complex tracking

### Token Bucket
```
Bucket holds 100 tokens, refills at 10/sec
Each request takes 1 token
```
+ Allows bursts up to bucket size
+ Smooth average rate

### Leaky Bucket
```
Requests queue, processed at fixed rate
```
+ Very smooth output
- Latency for queued requests

### Adaptive
```
Rate adjusts based on system health
```
+ Responds to conditions
- Complex to tune

## Where Rate Limiting is Needed

### High Priority
| Location | Why |
|----------|-----|
| Public API endpoints | Prevent abuse |
| External API calls | Respect limits, cost control |
| Database writes | Prevent overload |
| Expensive operations | Resource protection |

### Medium Priority
| Location | Why |
|----------|-----|
| Internal API endpoints | Multi-tenant fairness |
| Background jobs | Resource fairness |
| Event publishing | Downstream protection |

## Detection Patterns

### Rate Limiting Present
```
- "rate limit" / "rateLimit"
- "throttle"
- "requests per second/minute"
- 429 Too Many Requests handling
- Token bucket / leaky bucket
- "quota"
```

### Missing Rate Limiting
```
- Public endpoint without limits
- "Call external API" without throttling
- No 429 response handling
- Unbounded processing
- No mention of limits
```

## Output Format

```markdown
## Rate Limiting Analysis

### Rate Limit Inventory

| Endpoint/Operation | Rate Limited? | Strategy | Limit | Scope |
|--------------------|---------------|----------|-------|-------|
| [Endpoint] | [Yes/No] | [Fixed/Sliding/Token] | [Value] | [Per user/Global] |

### Public Endpoints Without Limits

| Endpoint | Risk | Recommendation |
|----------|------|----------------|
| [Endpoint] | [Abuse potential] | [Suggested limit] |

### External API Calls

| External API | Their Limit | Our Implementation | Gap |
|--------------|-------------|-------------------|-----|
| [API] | [Their limit] | [How we handle] | [Risk] |

### Rate Limit Configuration

| Limit | Value | Basis | Appropriate? |
|-------|-------|-------|--------------|
| [Limit] | [Value] | [How determined] | [Yes/No] |

### Limit Scope Analysis

| Rate Limit | Scope | Fairness | Recommendation |
|------------|-------|----------|----------------|
| [Limit] | [Global/Per-user/Per-tenant] | [Fair?] | [Change?] |

### 429 Response Handling

| Client | 429 Handling | Retry-After Respected? | Backoff |
|--------|--------------|----------------------|---------|
| [Client] | [How handled] | [Yes/No] | [Strategy] |

### Expensive Operation Protection

| Operation | Cost | Rate Limited? | Recommendation |
|-----------|------|---------------|----------------|
| [Op] | [Resource cost] | [Yes/No] | [Suggested limit] |

### Multi-Tenant Fairness

| Resource | Tenant Isolation | Limit Per Tenant | Fair? |
|----------|------------------|------------------|-------|
| [Resource] | [Yes/No] | [Limit] | [Yes/No] |

### Rate Limit Observability

| Rate Limit | Metrics? | Alerting? | Dashboard? |
|------------|----------|-----------|------------|
| [Limit] | [Yes/No] | [Yes/No] | [Yes/No] |

### Recommendations
1. [Add rate limiting to endpoint X]
2. [Implement 429 handling for external Y]
3. [Add per-tenant limits for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Public API without rate limiting | CRITICAL |
| External API calls without respecting limits | HIGH |
| No rate limiting on expensive operations | HIGH |
| Global limits without per-tenant fairness | MEDIUM |
| Comprehensive rate limiting strategy | POSITIVE |
