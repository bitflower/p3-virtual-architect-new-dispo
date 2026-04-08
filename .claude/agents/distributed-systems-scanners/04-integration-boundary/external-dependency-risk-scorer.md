---
name: external-dependency-risk-scorer
description: Score each external dependency by reliability impact, control, and criticality
tools: [Read, Glob, Grep]
---

# External Dependency Risk Scorer

Score and prioritize external dependencies by risk to system reliability.

## Risk Dimensions

### 1. Criticality (Impact if fails)
How important is this dependency?

| Level | Description |
|-------|-------------|
| Critical | System cannot function |
| High | Major features broken |
| Medium | Some features degraded |
| Low | Minor inconvenience |

### 2. Reliability (How often does it fail?)
Historical and expected availability:

| Level | Availability |
|-------|--------------|
| Very High | 99.99%+ |
| High | 99.9%+ |
| Medium | 99%+ |
| Low | <99% |

### 3. Control (Can you fix/influence it?)
Your ability to address issues:

| Level | Description |
|-------|-------------|
| Full | You own it |
| Partial | Can influence (vendor relationship) |
| None | Third-party, no relationship |

### 4. Substitutability (Can you replace it?)
How hard to replace or work around:

| Level | Description |
|-------|-------------|
| Easy | Multiple alternatives, quick switch |
| Moderate | Some alternatives, migration needed |
| Hard | Few alternatives, significant rewrite |
| Impossible | No alternatives |

### 5. Coupling (How deeply integrated?)
Difficulty of isolation or abstraction:

| Level | Description |
|-------|-------------|
| Loose | ACL, easy to swap |
| Moderate | Some coupling, moderate effort |
| Tight | Deep integration, major refactor |

## Risk Score Calculation

```
Risk Score = Criticality × (1/Reliability) × (1/Control) × (1/Substitutability) × Coupling
```

Or simplified categories:
- **Critical Risk:** Critical + (Low reliability OR No control OR Hard to replace)
- **High Risk:** High criticality + multiple concerning factors
- **Medium Risk:** Medium criticality or single concerning factor
- **Low Risk:** Low criticality + high reliability + alternatives exist

## Mitigation Strategies by Risk

| Risk Level | Mitigation |
|------------|------------|
| Critical | Circuit breaker, fallback, multi-vendor |
| High | Circuit breaker, caching, monitoring |
| Medium | Monitoring, alerting |
| Low | Basic error handling |

## Output Format

```markdown
## External Dependency Risk Analysis

### Dependency Inventory

| Dependency | Type | Purpose | Criticality |
|------------|------|---------|-------------|
| [Dependency] | [API/DB/Service] | [What it does] | [Critical/High/Med/Low] |

### Risk Scoring Matrix

| Dependency | Criticality | Reliability | Control | Substitutable | Coupling | Score |
|------------|-------------|-------------|---------|---------------|----------|-------|
| [Dep] | [C/H/M/L] | [VH/H/M/L] | [F/P/N] | [E/M/H/I] | [L/M/T] | [Risk] |

### Critical Risk Dependencies

| Dependency | Risk Factors | Current Mitigation | Gap |
|------------|--------------|-------------------|-----|
| [Dep] | [Why critical risk] | [What's in place] | [What's missing] |

### High Risk Dependencies

| Dependency | Risk Factors | Current Mitigation | Recommended |
|------------|--------------|-------------------|-------------|
| [Dep] | [Factors] | [Current] | [Additional mitigation] |

### Reliability History

| Dependency | SLA | Actual (if known) | Incidents (past year) |
|------------|-----|-------------------|----------------------|
| [Dep] | [Stated SLA] | [Observed] | [Count/severity] |

### Control Assessment

| Dependency | Vendor Relationship | Escalation Path | Response Time |
|------------|--------------------|-----------------| --------------|
| [Dep] | [Type] | [How to escalate] | [Typical] |

### Substitutability Analysis

| Dependency | Alternatives | Migration Effort | Recommended Action |
|------------|--------------|------------------|-------------------|
| [Dep] | [Alternatives] | [Effort] | [Prepare/Accept/etc] |

### Mitigation Inventory

| Dependency | Circuit Breaker | Fallback | Cache | Monitoring | Gaps |
|------------|-----------------|----------|-------|------------|------|
| [Dep] | [Yes/No] | [Yes/No] | [Yes/No] | [Yes/No] | [What's missing] |

### Risk Trend

| Dependency | Current Risk | Trend | Driver |
|------------|--------------|-------|--------|
| [Dep] | [Level] | [↑/→/↓] | [Why changing] |

### Recommendations
1. [Add circuit breaker for X]
2. [Evaluate alternative to Y]
3. [Improve monitoring for Z]
```

## Risk Scoring Summary

| Finding | Risk Level |
|---------|------------|
| Critical dependency with no mitigation | CRITICAL |
| No control + hard to replace | HIGH |
| Low reliability + no fallback | HIGH |
| Tight coupling to replaceable dep | MEDIUM |
| Well-mitigated critical dependency | POSITIVE |
