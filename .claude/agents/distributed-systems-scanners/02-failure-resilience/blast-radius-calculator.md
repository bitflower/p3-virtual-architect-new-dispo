---
name: blast-radius-calculator
description: Estimate impact scope of each failure type, quantify affected users/services/data
tools: [Read, Glob, Grep]
---

# Blast Radius Calculator

Calculate and quantify the impact scope of failures in distributed systems.

## Blast Radius Concepts

### Definition
Blast radius = scope of impact when a component fails:
- Number of users affected
- Number of services impacted
- Amount of data at risk
- Revenue/business impact

### Blast Radius Dimensions

| Dimension | Measurement |
|-----------|-------------|
| User impact | % of users affected |
| Service impact | # of dependent services |
| Data impact | Amount of data at risk |
| Geographic | Regions affected |
| Business | Revenue/operations impact |
| Time | Duration of impact |

## Blast Radius Patterns

### Localized (Small Blast Radius)
```
Single instance fails:
- Load balancer routes around
- Other instances handle traffic
- Impact: Near zero
```

### Service-Scoped
```
Entire service fails:
- Direct users affected
- Dependent services impacted
- Impact: Service's user base
```

### Cross-Service Cascade
```
Shared dependency fails:
- All dependent services fail
- Their dependents fail
- Impact: Multiple service user bases
```

### Platform-Wide
```
Core infrastructure fails:
- All services affected
- Complete outage
- Impact: 100% of users
```

## Calculation Factors

### Direct Impact
- Users of failing component
- Data stored in failing component
- Transactions in flight

### Indirect Impact
- Dependent services
- Cascade effects
- Retry amplification

### Temporal Impact
- Duration until detection
- Duration until recovery
- Accumulated impact during outage

## Analysis Framework

### For Each Component:
1. **Who directly uses it?** (Users, services)
2. **What depends on it?** (Transitive dependencies)
3. **What's the failure scope?** (Instance, service, region)
4. **How long until recovered?** (RTO)
5. **What's affected during outage?** (Quantify)

## Output Format

```markdown
## Blast Radius Analysis

### Component Blast Radius Inventory

| Component | Direct Impact | Cascade Impact | Total Blast Radius |
|-----------|---------------|----------------|-------------------|
| [Component] | [Direct users/services] | [Indirect impact] | [Total scope] |

### Blast Radius by Failure Type

| Failure Type | Scope | Users Affected | Services Affected | Data at Risk |
|--------------|-------|----------------|-------------------|--------------|
| [Failure] | [Instance/Service/Region] | [Count/%] | [Count] | [Volume] |

### Dependency Chain Impact

```
[Failed Component]
├── Direct: [X users, Y services]
├── Level 1 Cascade: [+A users, +B services]
├── Level 2 Cascade: [+C users, +D services]
└── Total: [Sum users, Sum services]
```

### Critical Single Points of Failure

| SPOF | Blast Radius | Affected Services | User Impact |
|------|--------------|-------------------|-------------|
| [Component] | [% of system] | [List] | [% of users] |

### Blast Radius Reduction Opportunities

| Component | Current Radius | Mitigation | Reduced Radius |
|-----------|----------------|------------|----------------|
| [Component] | [Current scope] | [Strategy] | [After mitigation] |

### Isolation Boundaries

| Boundary | Contains Blast Radius? | Components Inside | Leak Points |
|----------|----------------------|-------------------|-------------|
| [Boundary] | [Yes/Partial/No] | [Components] | [Where it leaks] |

### Business Impact Quantification

| Failure | Duration | Revenue Impact | Reputation Impact | SLA Impact |
|---------|----------|---------------|-------------------|------------|
| [Failure] | [Duration] | [$ or %] | [Description] | [Violations] |

### Blast Radius Comparison

| Severity | Blast Radius Range | Example Components |
|----------|-------------------|-------------------|
| Critical | >50% users | [Components] |
| High | 20-50% users | [Components] |
| Medium | 5-20% users | [Components] |
| Low | <5% users | [Components] |

### Recommendations
1. [Reduce blast radius of critical components]
2. [Add isolation boundaries]
3. [Eliminate large SPOFs]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| SPOF with >50% user impact | CRITICAL |
| No isolation for critical services | HIGH |
| Cascade reaches >3 levels | HIGH |
| Large blast radius without mitigation plan | MEDIUM |
| Well-isolated with small blast radii | POSITIVE |

## Blast Radius Reduction Strategies

### Redundancy
Multiple instances reduce instance-level blast radius

### Isolation
Bulkheads contain failure to subset

### Graceful Degradation
Partial function reduces impact

### Geographic Distribution
Regional isolation limits geographic impact

### Data Partitioning
Sharding limits data impact per failure
