---
name: coupling-strength-analyzer
description: Measure temporal/spatial coupling between services, find tight coupling risks
tools: [Read, Glob, Grep]
---

# Coupling Strength Analyzer

Measure and analyze coupling between distributed system components.

## Coupling Dimensions

### Temporal Coupling
Must be available at the same time:
```
Strong: Sync call (A must wait for B)
Weak: Async message (A continues, B processes later)
None: No direct communication
```

### Spatial Coupling
Must know each other's location:
```
Strong: Hardcoded URLs/addresses
Medium: Service discovery
Weak: Event bus (publish without knowing consumers)
```

### Data Coupling
Share data structures:
```
Strong: Shared database
Medium: Shared DTOs/schemas
Weak: Events with independent schemas
```

### Implementation Coupling
Depend on implementation details:
```
Strong: Shared libraries with internal types
Medium: Versioned API contracts
Weak: Standard protocols only
```

## Coupling Types

### Appropriate Coupling
Some coupling is necessary and good:
- API contracts between service and consumers
- Shared domain language
- Coordinated deployments for dependent features

### Problematic Coupling
Coupling that causes issues:
- Tight coupling to implementation details
- Coupling that prevents independent deployment
- Coupling that creates availability dependencies
- Coupling to unstable interfaces

## Measurement Criteria

### Temporal Coupling Indicators
| Level | Pattern |
|-------|---------|
| High | Sync HTTP, blocking calls |
| Medium | Request-reply over message queue |
| Low | Fire-and-forget events |

### Spatial Coupling Indicators
| Level | Pattern |
|-------|---------|
| High | Hardcoded endpoints |
| Medium | Config-based, service discovery |
| Low | Message broker, event bus |

### Data Coupling Indicators
| Level | Pattern |
|-------|---------|
| High | Shared database |
| Medium | Shared schema/library |
| Low | Independent schemas, translation |

## Detection Patterns

### Tight Coupling Signs
```
- "Must be deployed together"
- "If X is down, Y fails"
- Shared database access
- Circular dependencies
- "When X changes, Y must change"
- Cascading changes across services
```

### Loose Coupling Signs
```
- "Can deploy independently"
- "Continues working if X slow"
- Own data store
- Clear API boundaries
- Stable contracts
```

## Output Format

```markdown
## Coupling Strength Analysis

### Service Coupling Matrix

| From \ To | Service A | Service B | Service C | External |
|-----------|-----------|-----------|-----------|----------|
| Service A | - | [T:H,S:M,D:L] | [T:L,S:L,D:L] | [T:H,S:H,D:M] |
| Service B | [T:M,S:M,D:L] | - | ... | ... |

Legend: T=Temporal, S=Spatial, D=Data, H=High, M=Medium, L=Low

### Coupling Detail

| From | To | Temporal | Spatial | Data | Overall | Issues |
|------|-----|----------|---------|------|---------|--------|
| [A] | [B] | [High/Med/Low] | [H/M/L] | [H/M/L] | [Tight/Moderate/Loose] | [Problems] |

### Temporal Coupling Analysis

| Dependency | Type | If Callee Unavailable | Acceptable? |
|------------|------|----------------------|-------------|
| [A→B] | [Sync/Async] | [A fails/A continues] | [Yes/No] |

### Shared Database Coupling

| Database | Accessing Services | Coupling Issues |
|----------|-------------------|-----------------|
| [DB] | [Services] | [Schema coupling, deployment coupling, etc] |

### Deployment Coupling

| Services | Must Deploy Together? | Why | Can Decouple? |
|----------|----------------------|-----|---------------|
| [Services] | [Yes/No] | [Reason] | [How] |

### Change Impact Analysis

| If Change | Affects | Coupling Cause | Severity |
|-----------|---------|----------------|----------|
| [Change in X] | [What breaks] | [Type of coupling] | [High/Med/Low] |

### Circular Dependencies

| Cycle | Services Involved | Breaking Point |
|-------|-------------------|----------------|
| [Cycle] | [A→B→C→A] | [Where to break] |

### Independence Assessment

| Service | Can Deploy Alone? | Can Run Alone? | Limiting Factors |
|---------|-------------------|----------------|------------------|
| [Service] | [Yes/No] | [Yes/Degraded/No] | [Dependencies] |

### Recommendations
1. [Break temporal coupling with async]
2. [Remove shared database access]
3. [Add API versioning for data coupling]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Shared database between services | HIGH |
| Circular dependency | HIGH |
| Must deploy together | MEDIUM |
| Sync coupling without fallback | MEDIUM |
| Loose coupling with clear contracts | POSITIVE |
