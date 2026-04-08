---
name: god-service-detector
description: Find services with too many responsibilities that should be split
tools: [Read, Glob, Grep]
---

# God Service Detector

Identify services with too many responsibilities that violate single responsibility principle.

## What is a God Service?

A service that:
- Does too many different things
- Has too many reasons to change
- Is too large to understand
- Is difficult to test
- Has many unrelated dependencies
- Is a bottleneck for multiple teams

## God Service Indicators

### Size Indicators
- Many endpoints (>20)
- Large codebase
- Many database tables
- Long startup time
- Many dependencies

### Responsibility Indicators
- Multiple business domains
- Unrelated features
- Mixed concerns
- Multiple bounded contexts

### Team Indicators
- Multiple teams touch same service
- Merge conflicts frequent
- Coordination overhead high
- Different release cycles needed

### Change Indicators
- Changes for unrelated reasons
- Shotgun surgery common
- Regression risk high
- Test suite very large

## Detection Patterns

### God Service Signs
```
- "This service handles users AND orders AND payments"
- 50+ API endpoints
- 30+ database tables
- 10+ external dependencies
- Multiple teams working on it
- "Do everything" naming
```

### Good Service Signs
```
- Single bounded context
- Cohesive API
- One team ownership
- Can describe purpose in one sentence
- Manageable test suite
```

## Splitting Strategies

### By Bounded Context
Group by business domain:
```
Before: UserService (handles users, auth, profiles, preferences)
After:
  - AuthService
  - ProfileService
  - PreferencesService
```

### By Lifecycle
Group by change frequency:
```
Before: OrderService (order CRUD + reporting + analytics)
After:
  - OrderService (CRUD, high change)
  - ReportingService (low change)
```

### By Scalability
Group by scaling needs:
```
Before: MediaService (upload + processing + serving)
After:
  - UploadService (bursty)
  - ProcessingService (CPU intensive)
  - ServingService (high throughput)
```

## Output Format

```markdown
## God Service Analysis

### Service Size Assessment

| Service | Endpoints | Tables | Dependencies | Lines of Code | Size |
|---------|-----------|--------|--------------|---------------|------|
| [Service] | [Count] | [Count] | [Count] | [LOC] | [Normal/Large/God] |

### Responsibility Analysis

| Service | Responsibilities | Domains | Cohesion |
|---------|------------------|---------|----------|
| [Service] | [List] | [Count] | [High/Low] |

### God Service Indicators

| Service | Many Endpoints | Many Tables | Multi-Domain | Multi-Team | Score |
|---------|---------------|-------------|--------------|------------|-------|
| [Service] | [Y/N] | [Y/N] | [Y/N] | [Y/N] | [/4] |

### Team Ownership

| Service | Teams Involved | Coordination Overhead | Conflicts |
|---------|----------------|----------------------|-----------|
| [Service] | [Teams] | [High/Med/Low] | [Frequency] |

### Change Reasons Analysis

| Service | Recent Change Reasons | Different Domains? |
|---------|----------------------|--------------------|
| [Service] | [List reasons] | [Yes/No] |

### Bounded Context Mapping

| Service | Contexts Inside | Should Be | Split Recommendation |
|---------|-----------------|-----------|---------------------|
| [Service] | [Contexts] | [Single] | [How to split] |

### Splitting Recommendations

| God Service | Split Into | Strategy | Effort |
|-------------|------------|----------|--------|
| [Service] | [New services] | [By domain/lifecycle/scale] | [Effort] |

### Dependency Analysis

| Service | Internal Deps | External Deps | Appropriate? |
|---------|---------------|---------------|--------------|
| [Service] | [Count] | [Count] | [Yes/No] |

### Database Table Distribution

| Service | Tables | Related Groups | Split Candidates |
|---------|--------|----------------|------------------|
| [Service] | [Tables] | [Groupings] | [How to split] |

### Test Suite Health

| Service | Test Count | Test Duration | Coverage | Manageable? |
|---------|------------|---------------|----------|-------------|
| [Service] | [Count] | [Duration] | [%] | [Yes/No] |

### Recommendations
1. [Split service X by bounded context]
2. [Extract feature Y to new service]
3. [Separate concerns in Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Service with 5+ domains | CRITICAL |
| Service with multiple team ownership | HIGH |
| 50+ endpoints in single service | HIGH |
| Single domain, cohesive service | POSITIVE |

## Size Guidelines

| Metric | Normal | Large | God |
|--------|--------|-------|-----|
| Endpoints | <15 | 15-30 | >30 |
| Tables | <10 | 10-20 | >20 |
| Dependencies | <10 | 10-20 | >20 |
| Teams | 1 | 2 | >2 |
| Domains | 1 | 1-2 | >2 |
