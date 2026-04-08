---
name: outbox-pattern-scanner
description: Find outbox implementations, evaluate reliability and delivery guarantees
tools: [Read, Glob, Grep]
---

# Outbox Pattern Scanner

Detect and evaluate transactional outbox pattern implementations.

## Outbox Pattern Overview

### What is the Outbox Pattern?
A pattern ensuring reliable message publishing with local transactions:

```
BEGIN TRANSACTION
  1. Write business data
  2. Write message to outbox table (same DB)
COMMIT

Background process:
  3. Read from outbox
  4. Publish to message broker
  5. Mark as sent (or delete)
```

### Why Outbox?
- Database transaction guarantees atomicity of steps 1+2
- No dual-write problem
- At-least-once delivery guarantee
- Works with any message broker

## Outbox Components

### Outbox Table
```sql
CREATE TABLE outbox (
  id BIGINT PRIMARY KEY,
  aggregate_type VARCHAR(255),
  aggregate_id VARCHAR(255),
  event_type VARCHAR(255),
  payload JSONB,
  created_at TIMESTAMP,
  sent_at TIMESTAMP NULL,
  retries INT DEFAULT 0
)
```

### Publisher Process
- Polls outbox table (or uses CDC)
- Publishes messages to broker
- Marks messages as sent
- Handles retries

### Consumer Requirements
- Must be idempotent (at-least-once delivery)
- Should deduplicate if needed

## Implementation Variations

### Polling-Based
```
Every N seconds:
  SELECT * FROM outbox WHERE sent_at IS NULL
  For each: publish and update sent_at
```
+ Simple
- Latency (poll interval)
- Database load

### CDC-Based (Change Data Capture)
```
Debezium/similar captures outbox inserts
Streams directly to message broker
```
+ Low latency
+ No polling load
- Infrastructure complexity

### Delete vs Mark Sent
```
Delete after send: Simpler, no history
Mark as sent: Audit trail, replay capability
```

## Evaluation Criteria

### Reliability
- Is outbox write in same transaction as business data?
- Is publisher idempotent (handles duplicates)?
- Are failures retried?
- Is there a dead letter mechanism?

### Performance
- Poll interval appropriate?
- Outbox table indexed correctly?
- Cleanup mechanism for old messages?
- Batch publishing supported?

### Observability
- Metrics on outbox size?
- Alerting on stuck messages?
- Visibility into delivery lag?

## Detection Patterns

### Outbox Present
```
- "outbox" table/collection
- "TransactionalOutbox"
- "event_store" with publishing
- CDC setup (Debezium)
- "publish_events" in transaction
```

### Missing Outbox (Dual-Write Risk)
```
- Direct publish to queue in transaction
- "After save, send message"
- Two separate commits
- No atomic guarantee mentioned
```

## Output Format

```markdown
## Outbox Pattern Analysis

### Outbox Implementation Inventory

| Component | Outbox Present | Type | Publisher Mechanism |
|-----------|---------------|------|---------------------|
| [Component] | [Yes/No] | [Polling/CDC] | [How published] |

### Dual-Write Risks (Missing Outbox)

| Operation | Writes To | Publishes To | Atomic? | Risk |
|-----------|-----------|--------------|---------|------|
| [Operation] | [DB] | [Queue/Topic] | [Yes/No] | [What can go wrong] |

### Outbox Table Design

| Outbox | Schema | Indexes | Cleanup | Issues |
|--------|--------|---------|---------|--------|
| [Outbox] | [Columns] | [Indexes] | [How cleaned] | [Problems] |

### Publisher Reliability

| Publisher | Retry Logic | Max Retries | Dead Letter | Idempotent? |
|-----------|-------------|-------------|-------------|-------------|
| [Publisher] | [Strategy] | [Count] | [Yes/No] | [Yes/No] |

### Delivery Guarantees

| Outbox | Guarantee | Deduplication | Consumer Idempotent? |
|--------|-----------|---------------|---------------------|
| [Outbox] | [At-least-once/etc] | [How/None] | [Required/Implemented] |

### Performance Assessment

| Outbox | Poll Interval | Message Lag | Throughput | Bottleneck? |
|--------|---------------|-------------|------------|-------------|
| [Outbox] | [Interval] | [Typical lag] | [msgs/sec] | [Yes/No] |

### Observability

| Outbox | Size Metric | Lag Metric | Stuck Alert | Dashboard |
|--------|-------------|------------|-------------|-----------|
| [Outbox] | [Yes/No] | [Yes/No] | [Yes/No] | [Yes/No] |

### Recommendations
1. [Add outbox where missing]
2. [Improve publisher reliability]
3. [Add observability]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Dual-write without outbox | CRITICAL |
| Outbox without retry/dead-letter | HIGH |
| No cleanup (unbounded growth) | HIGH |
| No observability on outbox | MEDIUM |
| Complete outbox with monitoring | POSITIVE |
