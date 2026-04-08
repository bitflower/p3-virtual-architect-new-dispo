---
name: microservice-antipattern-scanner
description: Find distributed monolith, chatty services, and other microservice anti-patterns
tools: [Read, Glob, Grep]
---

# Microservice Anti-Pattern Scanner

Detect common microservice architecture anti-patterns.

## Microservice Anti-Patterns

### 1. Distributed Monolith
Microservices that must deploy together:
```
Service A change → Must also deploy B and C
Tight coupling disguised as microservices
Worst of both worlds
```
**Signs:** Shared deployments, lock-step releases

### 2. Chatty Services
Too many calls between services:
```
Get user: call Service A
Get preferences: call Service B
Get settings: call Service C
Get permissions: call Service D
// 4 network calls for one operation
```
**Signs:** Many small synchronous calls, high latency

### 3. Shared Database
Multiple services accessing same database:
```
Service A → Database ← Service B
Schema changes break both services
```
**Signs:** Same connection string, same tables

### 4. God Service
One service does everything:
```
UserService: creates users, sends emails,
processes payments, generates reports,
manages inventory, handles support tickets...
```
**Signs:** Huge service, many responsibilities

### 5. Nano Services
Services too small to be useful:
```
AddService: adds two numbers
MultiplyService: multiplies two numbers
// Excessive overhead for tiny operations
```
**Signs:** Services with single operations

### 6. Synchronous Dependency Chain
Long chains of sync calls:
```
A → B → C → D → E
Latency = sum of all
Availability = product of all
```
**Signs:** Deep call stacks, cascading failures

### 7. Data Ownership Violation
Services modifying data they don't own:
```
Service A owns User data
Service B directly writes to User table
// Who is the source of truth?
```
**Signs:** Multiple writers, inconsistency

### 8. Missing API Gateway
Direct client-to-service calls:
```
Client knows about all services
Client makes multiple calls
No cross-cutting concerns
```
**Signs:** Client complexity, no aggregation

### 9. Circular Dependencies
Services depending on each other:
```
A depends on B
B depends on C
C depends on A (cycle!)
```
**Signs:** Startup order issues, tight coupling

### 10. Inappropriate Service Boundaries
Technical rather than business boundaries:
```
DatabaseService, CacheService, EmailService
vs
OrderService, UserService, PaymentService
```
**Signs:** Services around technology, not capability

## Output Format

```markdown
## Microservice Anti-Pattern Analysis

### Anti-Pattern Detection Summary

| Anti-Pattern | Present? | Severity | Location |
|--------------|----------|----------|----------|
| Distributed Monolith | [Yes/No] | [Severity] | [Where] |
| Chatty Services | [Yes/No] | [Severity] | [Where] |
| Shared Database | [Yes/No] | [Severity] | [Where] |
| God Service | [Yes/No] | [Severity] | [Where] |
| Nano Services | [Yes/No] | [Severity] | [Where] |
| Sync Chain | [Yes/No] | [Severity] | [Where] |
| Data Ownership | [Yes/No] | [Severity] | [Where] |
| Missing Gateway | [Yes/No] | [Severity] | [Where] |
| Circular Deps | [Yes/No] | [Severity] | [Where] |
| Bad Boundaries | [Yes/No] | [Severity] | [Where] |

### Distributed Monolith Analysis

| Service | Independent Deploy? | Lock-Step Dependencies |
|---------|--------------------|-----------------------|
| [Service] | [Yes/No] | [Dependencies] |

### Chatty Service Analysis

| Operation | Services Called | Calls Made | Could Aggregate? |
|-----------|-----------------|------------|------------------|
| [Operation] | [Services] | [Count] | [Yes/No] |

### Shared Database Detection

| Database | Services Accessing | Tables Shared | Risk |
|----------|-------------------|---------------|------|
| [Database] | [Services] | [Tables] | [Level] |

### Service Size Analysis

| Service | Responsibilities | Size Assessment |
|---------|------------------|-----------------|
| [Service] | [Count/List] | [God/Right/Nano] |

### Synchronous Chain Analysis

| Chain | Depth | Total Latency | Availability |
|-------|-------|---------------|--------------|
| [Chain] | [Depth] | [Latency] | [Calculated] |

### Data Ownership Violations

| Data | Official Owner | Other Writers | Violation |
|------|----------------|---------------|-----------|
| [Data] | [Service] | [Services] | [Yes/No] |

### Circular Dependency Detection

| Cycle | Services Involved | Breaking Point |
|-------|-------------------|----------------|
| [Cycle] | [Services] | [How to break] |

### Service Boundary Assessment

| Service | Boundary Type | Business Capability? | Recommendation |
|---------|---------------|---------------------|----------------|
| [Service] | [Technical/Business] | [Yes/No] | [Keep/Merge/Split] |

### Recommendations
1. [Break distributed monolith X]
2. [Reduce chattiness for Y]
3. [Separate database for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Shared database between services | CRITICAL |
| Distributed monolith | HIGH |
| Circular dependencies | HIGH |
| Chatty services > 5 calls/operation | MEDIUM |
| Clear bounded contexts | POSITIVE |
