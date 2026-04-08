---
name: stateless-stateful-classifier
description: Classify components as stateless or stateful, identify problematic stateful services
tools: [Read, Glob, Grep]
---

# Stateless/Stateful Classifier

Classify system components and identify problematic stateful patterns.

## Stateless vs Stateful

### Stateless Services
No state between requests:
- Request contains all needed information
- Any instance can handle any request
- Easy horizontal scaling
- Simple failure recovery

### Stateful Services
State maintained between requests:
- Sessions, caches, or data
- Requests may need specific instance
- Scaling requires coordination
- Recovery requires state preservation

## State Types

### Good Stateful (External State)
State externalized to dedicated store:
```
Application: Stateless
State: Redis, Database, S3
```
- Application scales freely
- State managed appropriately

### Problematic Stateful (Local State)
State kept in application process:
```
In-memory sessions
Local file storage
In-process caches (unshared)
Static mutable variables
```
- Cannot scale horizontally
- Lost on restart/failure

## Detection Patterns

### Stateless Indicators
```
- No session storage
- No local file writes
- External cache/database for all state
- Any instance handles any request
- No sticky sessions required
```

### Stateful Indicators
```
- In-memory session storage
- Local file system usage
- Static mutable fields
- "Singleton" patterns with state
- "Cache" in local memory only
- "State" stored in process
```

## Externalization Strategies

### Sessions
- Redis
- Database session store
- JWT (client-side state)

### Caches
- Redis/Memcached
- Distributed cache

### Files
- Object storage (S3, GCS)
- Shared file system

### Locks
- Distributed lock service
- Database locks

## Output Format

```markdown
## Stateless/Stateful Classification

### Component Classification

| Component | Classification | State Type | Scaling Impact |
|-----------|---------------|------------|----------------|
| [Component] | [Stateless/Stateful] | [None/External/Local] | [Scales/Limited] |

### Local State Inventory

| Component | State Type | Storage | Externalization Path |
|-----------|------------|---------|---------------------|
| [Component] | [Session/Cache/File/etc] | [Memory/Disk] | [How to externalize] |

### Session State

| Component | Session Storage | Location | Externalized? |
|-----------|-----------------|----------|---------------|
| [Component] | [How stored] | [Where] | [Yes/No] |

### Cache State

| Component | Cache Type | Scope | Shared Across Instances? |
|-----------|------------|-------|-------------------------|
| [Component] | [Type] | [Local/Distributed] | [Yes/No] |

### File System Usage

| Component | File Operations | Can Externalize? | To What? |
|-----------|-----------------|------------------|----------|
| [Component] | [What files] | [Yes/No] | [S3/GCS/etc] |

### Static/Singleton State

| Component | Static State | Mutable? | Risk |
|-----------|--------------|----------|------|
| [Component] | [What] | [Yes/No] | [Race condition/Inconsistency] |

### Instance Affinity Requirements

| Component | Requires Affinity? | Why | Can Remove? |
|-----------|-------------------|-----|-------------|
| [Component] | [Yes/No] | [Reason] | [Yes/No/How] |

### Scaling Assessment

| Component | Current Instances | Can Add More? | Blocker |
|-----------|-------------------|---------------|---------|
| [Component] | [Count] | [Yes/No] | [State issue] |

### Failure Impact

| Component | On Instance Failure | State Lost? | Recovery |
|-----------|---------------------|-------------|----------|
| [Component] | [Impact] | [Yes/No] | [How to recover] |

### Externalization Effort

| Local State | Target External Store | Effort | Priority |
|-------------|----------------------|--------|----------|
| [State] | [Store] | [Effort] | [High/Med/Low] |

### Recommendations
1. [Externalize session state for X]
2. [Use distributed cache for Y]
3. [Move files to object storage for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Local session state | CRITICAL (can't scale) |
| Mutable static state | HIGH |
| In-memory cache only | MEDIUM |
| All state externalized | POSITIVE |
