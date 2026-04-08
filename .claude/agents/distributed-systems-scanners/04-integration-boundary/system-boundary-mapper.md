---
name: system-boundary-mapper
description: Map all integration points, classify by coupling type and communication pattern
tools: [Read, Glob, Grep]
---

# System Boundary Mapper

Map all system integration points and classify their characteristics.

## Boundary Types

### Internal Boundaries
Within your control:
- Service-to-service
- Module-to-module
- Layer boundaries

### External Boundaries
Outside your control:
- Third-party APIs
- Legacy systems
- Partner integrations
- Cloud services

## Communication Patterns

### Synchronous
```
Request → Response (wait for it)
```
| Characteristic | Value |
|---------------|-------|
| Latency | Additive |
| Availability | Dependent on callee |
| Coupling | Temporal |

### Asynchronous
```
Send message → Continue → Process later
```
| Characteristic | Value |
|---------------|-------|
| Latency | Decoupled |
| Availability | Independent |
| Coupling | Loose |

### Event-Driven
```
Publish event → Subscribers react
```
| Characteristic | Value |
|---------------|-------|
| Latency | Decoupled |
| Coupling | Very loose |
| Discovery | Implicit |

## Coupling Classification

### Tight Coupling
- Synchronous calls
- Shared database
- Shared types/contracts
- Direct dependencies

### Loose Coupling
- Async messaging
- Event-driven
- Published interfaces
- Separate data stores

## Boundary Characteristics

### Protocol
- HTTP/REST
- gRPC
- GraphQL
- Message queue (AMQP, Kafka)
- Database link

### Data Format
- JSON
- XML
- Protobuf
- Custom binary

### Contract Type
- OpenAPI/Swagger
- GraphQL schema
- Protobuf definitions
- Informal/undocumented

### Authentication
- API Key
- OAuth/JWT
- mTLS
- None/internal

## Output Format

```markdown
## System Boundary Map

### Boundary Inventory

| Boundary | From | To | Direction | Pattern |
|----------|------|-----|-----------|---------|
| [Name] | [System A] | [System B] | [→/←/↔] | [Sync/Async/Event] |

### Visual Boundary Map

```
┌─────────────────────────────────────┐
│         Your System                 │
│  ┌─────────┐      ┌─────────┐      │
│  │Service A│─────▶│Service B│      │
│  └────┬────┘      └────┬────┘      │
│       │                │           │
└───────┼────────────────┼───────────┘
        │ HTTP           │ Kafka
        ▼                ▼
  [External API]    [Event Bus]
```

### Communication Pattern Analysis

| Boundary | Protocol | Format | Contract | Auth |
|----------|----------|--------|----------|------|
| [Boundary] | [HTTP/gRPC/etc] | [JSON/etc] | [OpenAPI/None] | [Type] |

### Coupling Assessment

| Boundary | Coupling Type | Factors | Risk |
|----------|--------------|---------|------|
| [Boundary] | [Tight/Loose] | [Why] | [High/Med/Low] |

### Synchronous Dependencies

| Caller | Callee | Purpose | Fallback? | Risk |
|--------|--------|---------|-----------|------|
| [Caller] | [Callee] | [Why called] | [Yes/No] | [Availability impact] |

### Asynchronous Channels

| Channel | Publishers | Subscribers | Guarantee | Format |
|---------|------------|-------------|-----------|--------|
| [Channel] | [Publishers] | [Consumers] | [At-least-once/etc] | [Format] |

### External vs Internal

| Type | Count | Boundaries | Control Level |
|------|-------|------------|---------------|
| Internal | [N] | [List] | Full |
| External | [N] | [List] | Limited/None |

### Contract Documentation

| Boundary | Documented? | Location | Up to Date? |
|----------|-------------|----------|-------------|
| [Boundary] | [Yes/No] | [Where] | [Yes/No/Unknown] |

### Data Flow Summary

| Data Type | Source | Destinations | Path |
|-----------|--------|--------------|------|
| [Data] | [Origin] | [Where it goes] | [Boundaries crossed] |

### Recommendations
1. [Reduce tight coupling at boundary X]
2. [Document undocumented boundary Y]
3. [Add fallback for sync dependency Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Undocumented external boundary | HIGH |
| Sync dependency without fallback | HIGH |
| Tight coupling to external system | MEDIUM |
| Missing contract definition | MEDIUM |
| Well-documented, loosely coupled | POSITIVE |
