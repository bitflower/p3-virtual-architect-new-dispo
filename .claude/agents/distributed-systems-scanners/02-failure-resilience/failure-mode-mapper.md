---
name: failure-mode-mapper
description: Enumerate all failure points in architecture, classify by impact and likelihood
tools: [Read, Glob, Grep]
---

# Failure Mode Mapper

Systematically enumerate and classify all failure points in distributed system designs.

## Failure Mode Categories

### 1. Infrastructure Failures
| Failure | Impact | Detection |
|---------|--------|-----------|
| Server crash | Service unavailable | Health checks |
| Disk failure | Data loss/unavailable | SMART monitoring |
| Network partition | Split-brain, timeout | Connectivity checks |
| DNS failure | Cannot resolve services | DNS monitoring |
| Load balancer failure | Traffic black hole | Health endpoints |

### 2. Service Failures
| Failure | Impact | Detection |
|---------|--------|-----------|
| Process crash | Requests fail | Process monitoring |
| Memory exhaustion | OOM kill, degradation | Memory metrics |
| Thread exhaustion | Requests queue/timeout | Thread pool metrics |
| Deadlock | Service hangs | Timeout detection |
| Configuration error | Incorrect behavior | Validation, tests |

### 3. Dependency Failures
| Failure | Impact | Detection |
|---------|--------|-----------|
| Database unavailable | Cannot read/write | Connection errors |
| External API down | Feature degraded | HTTP errors |
| Message queue unavailable | Async processing stops | Queue health |
| Cache unavailable | Performance degradation | Cache errors |
| Auth service down | Cannot authenticate | Auth failures |

### 4. Data Failures
| Failure | Impact | Detection |
|---------|--------|-----------|
| Data corruption | Incorrect results | Checksums, validation |
| Schema mismatch | Parse/mapping errors | Deserialization errors |
| Constraint violation | Write rejected | Database errors |
| Stale data | Incorrect decisions | Version checks |

### 5. Operational Failures
| Failure | Impact | Detection |
|---------|--------|-----------|
| Deployment failure | Partial rollout | Deployment monitoring |
| Certificate expiry | TLS failures | Cert monitoring |
| Secret rotation failure | Auth failures | Secret validation |
| Capacity exhaustion | Throttling, rejection | Capacity metrics |

## Analysis Framework

### For Each Component, Ask:
1. **What can fail?** (Enumerate failure modes)
2. **How likely?** (Frequency: rare/occasional/frequent)
3. **What's the impact?** (Severity: low/medium/high/critical)
4. **How detected?** (Monitoring, health checks, errors)
5. **How recovered?** (Auto-recovery, manual intervention)

### Failure Classification Matrix

```
                    Low Impact    High Impact
                   ┌─────────────┬─────────────┐
    Rare           │   ACCEPT    │   MITIGATE  │
                   ├─────────────┼─────────────┤
    Frequent       │   MITIGATE  │   PREVENT   │
                   └─────────────┴─────────────┘
```

## Output Format

```markdown
## Failure Mode Analysis

### Failure Mode Inventory

| ID | Component | Failure Mode | Likelihood | Impact | Risk Score |
|----|-----------|--------------|------------|--------|------------|
| F1 | [Component] | [What fails] | [Rare/Occasional/Frequent] | [Low/Med/High/Critical] | [L×I] |

### Critical Failure Paths

| Path | Trigger | Cascade | Blast Radius |
|------|---------|---------|--------------|
| [Path] | [Initial failure] | [What else fails] | [Affected scope] |

### Failure Detection Coverage

| Failure Mode | Detection Method | Time to Detect | Gap? |
|--------------|-----------------|----------------|------|
| [Failure] | [How detected] | [Minutes/Seconds] | [Yes/No] |

### Recovery Mechanisms

| Failure Mode | Recovery Type | Time to Recover | Manual Steps? |
|--------------|--------------|-----------------|---------------|
| [Failure] | [Auto/Manual] | [Duration] | [What's needed] |

### Unhandled Failure Modes

| Failure Mode | Why Unhandled | Recommended Mitigation |
|--------------|---------------|------------------------|
| [Failure] | [Gap reason] | [What to implement] |

### Single Points of Failure

| SPOF | Impact if Failed | Redundancy Recommendation |
|------|------------------|--------------------------|
| [Component] | [Impact] | [How to add redundancy] |

### Recommendations
1. [Priority failure modes to address]
2. [Detection improvements]
3. [Recovery automation opportunities]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Critical SPOF with no redundancy | CRITICAL |
| High-impact failure with no detection | HIGH |
| Frequent failure with manual recovery | HIGH |
| Cascade path to critical systems | HIGH |
| Low-impact failures unhandled | LOW |
| Comprehensive failure handling | POSITIVE |
