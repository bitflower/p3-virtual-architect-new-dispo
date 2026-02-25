# Architectural Review Patterns & Methodology
**A Reusable Framework for System Analysis**

**Date**: 2026-02-23
**Author**: Architectural Review Team
**Purpose**: Extract reusable patterns, anti-patterns, and analysis methodologies from Cloud4Log review for application to other systems

---

## Table of Contents

1. [Analysis Methodology](#1-analysis-methodology)
2. [Common Architectural Anti-Patterns](#2-common-architectural-anti-patterns)
3. [Pain Point Detection Schemas](#3-pain-point-detection-schemas)
4. [Scalability Assessment Framework](#4-scalability-assessment-framework)
5. [Proposal Evaluation Criteria](#5-proposal-evaluation-criteria)
6. [Cost-Benefit Analysis Framework](#6-cost-benefit-analysis-framework)
7. [Migration Risk Assessment](#7-migration-risk-assessment)
8. [Reusable Solution Patterns](#8-reusable-solution-patterns)
9. [Decision Trees](#9-decision-trees)
10. [Checklists](#10-checklists)

---

## 1. Analysis Methodology

### 1.1 The Three-Phase Analysis Approach

**Phase 1: Stakeholder Claims Verification**

```
Input: Meeting notes, stakeholder concerns, architect feedback
Process:
  1. Extract specific technical claims
  2. Categorize claims by verifiability
  3. Search codebase for evidence
  4. Mark each claim: ✅ Confirmed | ❌ Refuted | ⚠️ Partially Confirmed
Output: Validated concerns list
```

**Phase 2: Bottleneck Discovery**

```
Input: Verified concerns + codebase
Process:
  1. Trace request flow end-to-end
  2. Measure theoretical vs. actual capacity
  3. Identify serialization points
  4. Calculate performance multipliers (e.g., N+1 queries)
  5. Find hard limits (timeouts, max instances)
Output: Quantified bottlenecks with impact metrics
```

**Phase 3: Solution Design & Prioritization**

```
Input: Bottlenecks + constraints
Process:
  1. Generate solution alternatives (3-5 per bottleneck)
  2. Evaluate effort, cost, risk, ROI
  3. Create migration paths
  4. Prioritize by: Critical > High ROI > Low Risk > Low Effort
Output: Phased implementation roadmap
```

### 1.2 Evidence-Based Verification Checklist

When verifying architectural claims:

- [ ] Locate exact code/config location (file path + line numbers)
- [ ] Extract verbatim code snippet (5-20 lines)
- [ ] Measure impact with concrete numbers (e.g., "101 queries instead of 2")
- [ ] Identify root cause (why does this exist?)
- [ ] Assess whether it's technical debt or intentional design
- [ ] Document consequences during peak load scenarios

**Example**:

```markdown
❌ Claim: "The system is synchronous"
✅ Evidence: BorderoUploadFunction.cs:41-54 shows `Task.WhenAll()` parallelization
⚖️ Verdict: REFUTED - System uses async patterns extensively
```

### 1.3 Key Questions to Ask

**Trigger Mechanism**:

- How is the system triggered? (Time-based, event-driven, request-driven)
- Can it adapt to load changes?
- What happens if trigger fires while previous execution is still running?

**State Management**:

- Is there persistent state tracking?
- Can the system resume after failure?
- How does it handle partial completion?

**Concurrency & Parallelism**:

- What determines maximum concurrency?
- Are there hard limits (config, infrastructure)?
- Can concurrency adapt to load?

**Error Handling**:

- Does one failure affect others?
- Is there fault isolation?
- Are errors classified (retriable vs. permanent)?

**External Dependencies**:

- How are failures handled (retries, circuit breakers)?
- What happens during cascading failures?
- Is there backpressure handling?

**Observability**:

- Can you measure lag, throughput, error rate?
- Are there alerts for degradation?
- Can you trace individual requests?

---

## 2. Common Architectural Anti-Patterns

### Anti-Pattern 1: **Time-Based Triggers for Load-Dependent Work**

**Symptoms**:

- CRON scheduler runs at fixed intervals
- Work volume varies (peak hours, seasonal spikes)
- No backlog visibility or adaptive scaling

**Why It Happens**:

- "Quick to implement" - CRON is simple
- Legacy migration from scheduled batch jobs
- Lack of event-driven infrastructure knowledge

**Detection Method**:

```
Search for: CRON expressions (*/N * * * *), Cloud Scheduler, scheduled triggers
Check: Does work volume vary? Is there peak/off-peak pattern?
Measure: Processing time vs. interval (if processing > interval → accumulation)
```

**Consequences**:

- Backlog accumulation during peaks
- Resource waste during off-peaks
- Cannot scale on-demand
- Fixed cost regardless of load

**Standard Solution**: Migrate to event-driven architecture (Pub/Sub, message queues)

**Quick Fix**: Lower interval + add checkpointing (temporary, not scalable)

---

### Anti-Pattern 2: **Stateless Processing Without Checkpointing**

**Symptoms**:

- Each run calculates "what to process" from scratch (e.g., `currentTime - offset`)
- No persistent tracking of last processed item
- Timeouts/failures result in data loss or duplication

**Why It Happens**:

- "Stateless is simpler" mindset
- Avoiding database writes for checkpoints
- Assumption: "Processing will always complete within timeout"

**Detection Method**:

```
Search for: startTime, offset, timestamp calculations in request handlers
Check: Is there a checkpoint/watermark table or state store?
Test: What happens if function times out at 50% completion?
```

**Consequences**:

- **Data loss**: Partial processing lost on timeout
- **Duplication**: Retry processes same records
- **No resume capability**: Must restart from beginning
- **Backlog invisibility**: Can't measure "how far behind" we are

**Standard Solution**: Add checkpoint table (Firestore, Cloud SQL, Redis) with last processed offset/timestamp/ID

**Quick Fix**: At minimum, track last successful run timestamp

---

### Anti-Pattern 3: **N+1 Query Problem**

**Symptoms**:

- Loop over collection, making database query per item
- Linear scaling: 100 items = 100 queries
- High database load and latency

**Why It Happens**:

- ORM misuse (lazy loading)
- Lack of batch API awareness
- "Works fine with 10 items in dev" syndrome

**Detection Method**:

```csharp
// Red flag pattern:
foreach (var item in items)
{
    var detail = await repository.GetDetail(item.Id); // ⚠️ N+1 query
}
```

**Consequences**:

- Database CPU/connection exhaustion
- Slow response times (10× to 100× slower)
- Timeout risk when processing large batches

**Standard Solution**: Batch retrieval with single query

```csharp
// Fixed:
var ids = items.Select(x => x.Id).ToList();
var details = await repository.GetDetailsBatch(ids); // 1 query
```

**Detection Tools**:

- ORM query logging (EF Core: `EnableSensitiveDataLogging`)
- Database profiler (count queries per request)
- APM tools (New Relic, Datadog)

---

### Anti-Pattern 4: **Cascading Failures in Parallel Processing**

**Symptoms**:

- Parallel tasks with `raise`/`throw` on error
- One failure terminates all parallel work
- All-or-nothing behavior for independent operations

**Why It Happens**:

- Default exception handling propagates errors
- Lack of fault isolation design
- "Fail fast" taken too literally

**Detection Method**:

```yaml
# Red flag in workflows:
parallel:
  for: item in items
    except:
      raise: ${e}  # ⚠️ Kills all parallel branches
```

```csharp
// Red flag in code:
var tasks = items.Select(async item => await ProcessItem(item));
await Task.WhenAll(tasks); // ⚠️ Throws on first failure, cancels others
```

**Consequences**:

- Partial unknown state (some succeeded before failure)
- Cannot retry only failed items
- Wasted work (successful items not persisted)

**Standard Solution**: Collect results, handle failures individually

```csharp
var tasks = items.Select(async item => {
    try {
        var result = await ProcessItem(item);
        return new { Success = true, Item = item, Result = result };
    } catch (Exception e) {
        logger.LogError(e, "Failed item {Id}", item.Id);
        return new { Success = false, Item = item, Error = e };
    }
});

var results = await Task.WhenAll(tasks);
var succeeded = results.Where(x => x.Success).ToList();
var failed = results.Where(x => !x.Success).ToList();
```

---

### Anti-Pattern 5: **No Circuit Breaker for External Services**

**Symptoms**:

- Retry logic without circuit breaker
- Cascading failures when downstream service is down
- Wasted retries during outages

**Why It Happens**:

- "Retry until success" mentality
- Unawareness of circuit breaker pattern
- Polly/Resilience4j not configured

**Detection Method**:

```
Search for: retry logic, exponential backoff, Polly policies
Check: Is there a circuit breaker policy? Or only retry?
```

**Consequences**:

- Function timeouts (retry × N attempts)
- Upstream service overload during recovery
- No fail-fast behavior

**Standard Solution**: Combine retry + circuit breaker

```csharp
var retryPolicy = Policy.Handle<Exception>().WaitAndRetryAsync(3, ...);
var circuitBreakerPolicy = Policy.Handle<Exception>()
    .CircuitBreakerAsync(10, TimeSpan.FromSeconds(30));
var resiliencePolicy = Policy.WrapAsync(retryPolicy, circuitBreakerPolicy);
```

---

### Anti-Pattern 6: **Fixed Concurrency Bound by Static Configuration**

**Symptoms**:

- Concurrency determined by static config (e.g., depot count, partition count)
- Cannot scale beyond this limit
- Load imbalance (one partition has 90% of data)

**Why It Happens**:

- Legacy migration (partition count = physical servers)
- Simplicity (easier to reason about)
- Unawareness of dynamic partitioning

**Detection Method**:

```
Search for: fixed lists, static configuration files, partition keys
Check: Is this list dynamic? Can it grow?
Measure: Data distribution (are partitions balanced?)
```

**Consequences**:

- Cannot scale beyond N partitions
- Load imbalance (hot partitions)
- Manual intervention required to add capacity

**Standard Solution**: Dynamic work distribution (Pub/Sub, Kafka, SQS)

---

### Anti-Pattern 7: **Lack of Observability**

**Symptoms**:

- No metrics for lag, throughput, error rate
- Cannot measure SLA compliance
- Troubleshooting requires log spelunking

**Why It Happens**:

- "Metrics are nice-to-have" mindset
- Time pressure (ship features over observability)
- Lack of monitoring culture

**Detection Method**:

```
Check: Are there custom metrics? Dashboards? Alerts?
Search for: MetricClient, statsd, Prometheus, CloudWatch
```

**Consequences**:

- Reactive troubleshooting (customers report issues first)
- Cannot capacity plan
- No SLA measurement

**Standard Solution**: Instrument key metrics (RED: Rate, Errors, Duration)

---

## 3. Pain Point Detection Schemas

### Schema 1: **Processing Capacity vs. Load**

**Formula**:

```
Peak Load (records/minute) vs. Processing Capacity (records/minute)

If Peak Load > Processing Capacity:
  → Backlog accumulation
  → Calculate accumulation rate: (Peak - Capacity) × duration
```

**Example Calculation**:

```
Normal load: 1000 records/minute
Peak load (Christmas): 5000 records/minute
Current capacity: 3000 records/minute

Deficit during peak: 2000 records/minute
If peak lasts 2 hours: 2000 × 120 = 240,000 records backlog
Time to clear backlog at normal capacity: 240 minutes (4 hours)
```

**Detection Questions**:

- What is peak load? (ask for historical data or estimate from seasonal patterns)
- What is current processing capacity? (measure in test environment or production logs)
- What is acceptable lag? (SLA requirement)

---

### Schema 2: **Timeout Risk Assessment**

**Formula**:

```
Function Timeout vs. Expected Processing Time

Processing Time = (DB Query Time + SMB Read Time + API Call Time) × Record Count + Retry Overhead

If Processing Time > 80% of Timeout:
  → High risk of timeout
```

**Example Calculation**:

```
Cloud Run timeout: 150 seconds
DB query: 0.5s per record
SMB read: 0.2s per record
API call: 0.3s per record
Record count: 100
Retry overhead: 5 attempts × 0.1s × 10% failure rate = 0.05s per record

Total = (0.5 + 0.2 + 0.3 + 0.05) × 100 = 105 seconds
Risk: 105/150 = 70% → MEDIUM RISK (approaching timeout)
```

**Mitigation Strategies**:

- Increase timeout
- Reduce batch size
- Optimize slow operations
- Add circuit breaker (fail fast)

---

### Schema 3: **Database Load Calculation**

**Formula**:

```
Queries per Request = Base Queries + (N+1 Queries × Record Count)

Database Load = Queries per Request × Requests per Minute
```

**Example**:

```
Current:
  1 query for delivery notes
  + 100 queries for delivery note contents
  = 101 queries per request

Requests per minute: 35 depots × 2 functions = 70 requests

Total DB load: 101 × 70 = 7,070 queries/minute

Optimized:
  2 queries per request (batch retrieval)

Total DB load: 2 × 70 = 140 queries/minute

Reduction: 7,070 → 140 (50× improvement)
```

---

### Schema 4: **Concurrency Bottleneck Identification**

**Formula**:

```
Max Theoretical Concurrency = Parallelization Level 1 × Level 2 × ... × Level N

Max Actual Concurrency = min(Max Theoretical, Infrastructure Limits)
```

**Example**:

```
Parallelization:
  - Depot level: 35 depots (parallel)
  - Function level: 2 functions per depot (sequential per depot)
  - Iteration level: 1 iteration per function (sequential)
  - Delivery note level: 100 notes (parallel within function)

Theoretical: 35 depots × 100 notes = 3,500 concurrent operations

Infrastructure limits:
  - Max Cloud Run instances: 50
  - Cloud Run concurrency: 1 request per instance

Actual: 50 instances → bottleneck
```

**Bottleneck**: Infrastructure limit (50 instances), not parallelization design

---

### Schema 5: **Cost Impact Assessment**

**Formula**:

```
Current Cost = Invocations × (Duration/100ms) × $0.0000004 + Memory Cost

Proposed Cost = (same formula with new parameters)

Cost Increase = (Proposed - Current) / Current × 100%
```

**Example**:

```
Current:
  - Invocations: 60/hour × 24 hours = 1,440/day = 43,200/month
  - Duration: 60 seconds avg
  - Memory: 4Gi

Cloud Run cost: ~$50/month

Proposed (20-second interval):
  - Invocations: 180/hour × 24 hours = 4,320/day = 129,600/month

Cloud Run cost: ~$150/month

Increase: +$100/month (+200%)
```

---

## 4. Scalability Assessment Framework

### 4.1 The Five Scalability Dimensions

**1. Trigger Scalability**

- Can the trigger mechanism adapt to load?
- Is there a backlog queue that can grow/shrink?

**Rating**:

- ⭐ Fixed CRON (worst)
- ⭐⭐ CRON + manual adjustment
- ⭐⭐⭐ CRON + auto-scaling workers
- ⭐⭐⭐⭐ Event-driven + fixed workers
- ⭐⭐⭐⭐⭐ Event-driven + auto-scaling (best)

**2. Processing Scalability**

- Can you add more workers on-demand?
- Are there hard limits (config, infrastructure)?

**Rating**:

- ⭐ Hard-coded worker count
- ⭐⭐ Configurable worker count (manual scaling)
- ⭐⭐⭐ Auto-scaling with max limit (e.g., max 50 instances)
- ⭐⭐⭐⭐ Auto-scaling with soft limit (increase via config)
- ⭐⭐⭐⭐⭐ Unlimited auto-scaling (cloud-native)

**3. State Scalability**

- Is state tracking per-partition or global?
- Can state grow without performance degradation?

**Rating**:

- ⭐ No state tracking
- ⭐⭐ Single global checkpoint (write contention)
- ⭐⭐⭐ Per-partition checkpoints
- ⭐⭐⭐⭐ Per-partition checkpoints + efficient storage
- ⭐⭐⭐⭐⭐ Distributed state (Kafka offsets, DynamoDB streams)

**4. Fault Isolation**

- Does one failure affect others?
- Can you retry individual failures?

**Rating**:

- ⭐ Single failure kills entire batch
- ⭐⭐ Partial failure tracking (manual retry)
- ⭐⭐⭐ Dead-letter queue (automatic retry)
- ⭐⭐⭐⭐ Per-item failure handling + DLQ
- ⭐⭐⭐⭐⭐ Isolated partitions + circuit breakers + DLQ

**5. Observability Scalability**

- Can you measure lag as system scales?
- Are metrics per-partition or aggregated?

**Rating**:

- ⭐ No metrics
- ⭐⭐ Aggregate metrics (total throughput)
- ⭐⭐⭐ Per-partition metrics
- ⭐⭐⭐⭐ Per-partition metrics + SLO tracking
- ⭐⭐⭐⭐⭐ Real-time lag metrics + auto-scaling triggers

### 4.2 Scalability Scorecard

| Dimension | Current Rating | Target Rating | Gap |
|-----------|----------------|---------------|-----|
| Trigger | ⭐ | ⭐⭐⭐⭐⭐ | 4 |
| Processing | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 2 |
| State | ⭐ | ⭐⭐⭐⭐ | 3 |
| Fault Isolation | ⭐⭐ | ⭐⭐⭐⭐ | 2 |
| Observability | ⭐⭐ | ⭐⭐⭐⭐ | 2 |
| **Overall** | **1.6** | **4.6** | **3.0** |

**Interpretation**:

- Score < 2.0: High risk of production issues
- Score 2.0-3.0: Acceptable for stable load, risky for growth
- Score 3.0-4.0: Good, but improvement opportunities
- Score > 4.0: Excellent, production-ready

---

## 5. Proposal Evaluation Criteria

### 5.1 The ROI Matrix

| Criterion | Weight | Measurement |
|-----------|--------|-------------|
| **Impact** | 30% | Performance gain (1-5 stars) |
| **Effort** | 25% | Time to implement (days/weeks) |
| **Cost** | 20% | Monthly operational cost change |
| **Risk** | 15% | Low/Medium/High |
| **Strategic Value** | 10% | Enables future capabilities? |

**Scoring Formula**:

```
ROI Score = (Impact × 30 + (5 - Effort_weeks) × 25 + (5 - Cost_tier) × 20 + (5 - Risk) × 15 + Strategic × 10) / 100

Where:
  Impact: 1-5 stars (1=minimal, 5=transformative)
  Effort_weeks: 0.25, 0.5, 1, 2, 4, 8+ weeks (convert to 1-5 scale inverse)
  Cost_tier: 1=high cost (+$100/mo), 5=cost savings
  Risk: 1=high, 3=medium, 5=low
  Strategic: 1-5 (1=tactical fix, 5=enables future growth)
```

**Example Calculation**:

```
Proposal: Add persistent checkpointing

Impact: 4/5 (prevents data loss, enables resume)
Effort: 1 week → 4/5
Cost: +$2/month → 5/5 (negligible)
Risk: Low → 5/5
Strategic: 4/5 (enables other features like lower interval)

ROI = (4×30 + 4×25 + 5×20 + 5×15 + 4×10) / 100 = 4.3/5 → VERY HIGH ROI
```

### 5.2 Priority Quadrants

```
        High Impact
            │
  Critical  │  Strategic
  Fixes     │  Investments
────────────┼────────────
  Quick     │  Deferred
  Wins      │
            │
        Low Impact
```

**Placement Logic**:

- **Critical Fixes**: High impact + High urgency (prevents outages, data loss)
- **Strategic Investments**: High impact + Low urgency (enables future growth)
- **Quick Wins**: Medium impact + Low effort (high ROI, morale boost)
- **Deferred**: Low impact or very high effort

**Prioritization Order**:

1. Critical Fixes (do first)
2. Quick Wins (parallel with Critical Fixes if possible)
3. Strategic Investments (after stabilization)
4. Deferred (only if free capacity)

---

## 6. Cost-Benefit Analysis Framework

### 6.1 Total Cost of Ownership (TCO) Calculation

**Formula**:

```
TCO = Initial Development Cost + (Monthly Operational Cost × 12 months) + Maintenance Cost

Where:
  Initial Development = Developer hours × hourly rate
  Operational Cost = Cloud services + third-party tools + support
  Maintenance = Bug fixes + updates (estimated 10-20% of initial development annually)
```

**Example**:

```
Proposal: Migrate to Pub/Sub architecture

Initial Development:
  - 3 developers × 4 weeks × 40 hours/week × $100/hour = $48,000

Operational Cost (annual):
  - Pub/Sub: $60/year
  - Firestore: $24/year
  - Additional Cloud Run invocations: $120/year
  - Total: $204/year

Maintenance:
  - 10% of development = $4,800/year

TCO (3 years) = $48,000 + ($204 × 3) + ($4,800 × 3) = $63,612
```

### 6.2 Cost Avoidance Calculation

**Formula**:

```
Cost Avoidance = (Downtime hours avoided × revenue per hour) + (Customer churn avoided × LTV)
```

**Example**:

```
Current system: 2 hours of downtime per month during peak season (4 months/year)

Revenue impact:
  - Revenue per hour: $10,000
  - Downtime hours avoided: 2 × 4 = 8 hours/year
  - Revenue saved: 8 × $10,000 = $80,000/year

Customer churn:
  - Current NPS drop during incidents: -20 points
  - Estimated churn: 2% of customers
  - Customer count: 1,000
  - LTV per customer: $50,000
  - Churn avoided: 1,000 × 2% × $50,000 = $1,000,000

Total Cost Avoidance: $1,080,000/year

ROI = ($1,080,000 - TCO) / TCO = 1,598% over 3 years
```

### 6.3 Break-Even Analysis

**Formula**:

```
Break-Even Point = Initial Investment / (Monthly Benefit - Monthly Cost)
```

**Example**:

```
Proposal: Optimize N+1 queries

Initial Investment: $4,000 (2 days × 2 developers × $100/hour × 8 hours)
Monthly Benefit: $100 (reduced database costs + faster processing)
Monthly Cost: $0

Break-Even = $4,000 / $100 = 40 months

If include cost avoidance (reduced timeout incidents):
Monthly Benefit: $100 + $500 (avoided downtime) = $600

Break-Even = $4,000 / $600 = 6.7 months ✅ Acceptable
```

---

## 7. Migration Risk Assessment

### 7.1 Risk Scoring Matrix

| Risk Factor | Low (1) | Medium (2) | High (3) |
|-------------|---------|------------|----------|
| **Code Changes** | < 100 lines | 100-500 lines | > 500 lines |
| **API Changes** | Internal only | Internal + external (backward compatible) | Breaking changes |
| **Infrastructure** | Config only | New services (managed) | New services (self-hosted) |
| **Data Migration** | None | Schema changes | Data transformation |
| **Reversibility** | Instant rollback | Rollback requires downtime | Irreversible |
| **Testing Effort** | Unit tests | Integration tests | Load tests + manual QA |

**Overall Risk Score**:

```
Risk Score = Σ(Factor Score) / Number of Factors

< 1.5: Low Risk
1.5-2.5: Medium Risk
> 2.5: High Risk
```

### 7.2 Mitigation Strategies by Risk Type

**Risk**: Data Loss/Corruption

**Mitigations**:

- Blue-green deployment (run old + new in parallel)
- Shadow mode (new system reads, doesn't write)
- Idempotency (safe to retry)
- Rollback procedure documented

**Risk**: Performance Degradation

**Mitigations**:

- Load testing before production
- Gradual rollout (1% → 10% → 50% → 100%)
- Performance monitoring dashboards
- Auto-rollback on SLO violation

**Risk**: Breaking External Integrations

**Mitigations**:

- Contract testing (Pact)
- Versioned APIs (v1, v2)
- Deprecation notices
- Backward compatibility layer

**Risk**: Cost Overrun

**Mitigations**:

- Budget alerts (Cloud Billing)
- Rate limiting
- Dry-run cost estimation
- Kill switch (disable feature if cost > threshold)

### 7.3 The Pre-Mortem Technique

**Process**:

1. Assume the migration has failed catastrophically
2. Brainstorm: "What went wrong?"
3. For each failure scenario, design mitigation
4. Update migration plan with mitigations

**Example Pre-Mortem**:

```
Scenario: "Pub/Sub migration caused data duplication"

Root Cause: Both old (CRON) and new (Pub/Sub) systems ran in parallel without deduplication

Mitigation:
  - Add unique request ID to all messages
  - Implement deduplication check in Cloud4Log API
  - Disable CRON trigger before enabling Pub/Sub
  - Monitor for duplicate delivery note IDs in logs
```

---

## 8. Reusable Solution Patterns

### Pattern 1: **CRON to Event-Driven Migration**

**Problem**: Fixed-interval CRON scheduling cannot adapt to load.

**Solution Architecture**:

```
Old:
  Cloud Scheduler (CRON) → Cloud Function → Process Records

New:
  Cloud Scheduler → Inventory Service → Pub/Sub Topic → Worker Functions (auto-scaling)
                    (publishes work)      (backlog)       (process)
```

**Components**:

1. **Inventory Service**: Scans for pending work, publishes messages
2. **Pub/Sub Topic**: Message queue with auto-scaling
3. **Worker Functions**: Event-driven processors
4. **Dead-Letter Queue**: Failed messages for retry

**Migration Path**:

```
Phase 1: Add inventory service + Pub/Sub (parallel with CRON)
Phase 2: Migrate one worker to Pub/Sub
Phase 3: Validate correctness (dual-write, compare outputs)
Phase 4: Switch traffic to Pub/Sub, disable CRON
Phase 5: Remove CRON infrastructure
```

---

### Pattern 2: **Stateless to Stateful Migration (Checkpointing)**

**Problem**: No resume capability after timeout/failure.

**Solution Architecture**:

```
Component 1: Checkpoint Table
  Schema: (partition_key, last_processed_offset, updated_at)

Component 2: Read Checkpoint at Start
  offset = checkpoint.last_processed_offset ?? defaultOffset

Component 3: Write Checkpoint after Success
  checkpoint.last_processed_offset = latestProcessedOffset
  checkpoint.updated_at = now()
```

**Storage Options**:

| Storage | Latency | Consistency | Cost | Use Case |
|---------|---------|-------------|------|----------|
| Firestore | 10ms | Strong | $ | Simple key-value, low volume |
| Cloud SQL | 20ms | Strong | $$ | Relational queries, complex state |
| Redis | 1ms | Eventual | $ | High throughput, cache-friendly |
| BigTable | 5ms | Eventual | $$$ | Massive scale (billions of checkpoints) |

**Implementation**:

```csharp
// Read checkpoint
var checkpoint = await checkpointService.GetCheckpoint(partitionKey);
var startOffset = checkpoint?.LastProcessedOffset ?? defaultOffset;

// Process records
var records = await dataSource.GetRecords(startOffset, batchSize);
foreach (var record in records)
{
    await ProcessRecord(record);
}

// Update checkpoint
await checkpointService.UpdateCheckpoint(new Checkpoint
{
    PartitionKey = partitionKey,
    LastProcessedOffset = records.Max(r => r.Offset),
    UpdatedAt = DateTime.UtcNow
});
```

---

### Pattern 3: **Retry + Circuit Breaker Combination**

**Problem**: Retries without circuit breaker waste resources during downstream outages.

**Solution** (using Polly):

```csharp
// Define retry policy
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt))
    );

// Define circuit breaker policy
var circuitBreakerPolicy = Policy
    .Handle<HttpRequestException>()
    .CircuitBreakerAsync(
        handledEventsAllowedBeforeBreaking: 10,
        durationOfBreak: TimeSpan.FromSeconds(30),
        onBreak: (exception, duration) => {
            logger.LogError("Circuit breaker opened for {Duration}s", duration.TotalSeconds);
        },
        onReset: () => {
            logger.LogInformation("Circuit breaker reset");
        }
    );

// Combine policies (circuit breaker wraps retry)
var resiliencePolicy = Policy.WrapAsync(circuitBreakerPolicy, retryPolicy);

// Usage
await resiliencePolicy.ExecuteAsync(async () => {
    return await httpClient.PostAsync(url, content);
});
```

**Behavior**:

1. First 10 failures: Retry 3 times each (30 total attempts)
2. After 10th failure: Circuit opens, fail fast for 30 seconds
3. After 30 seconds: Circuit half-opens, allows 1 test request
4. If test succeeds: Circuit closes
5. If test fails: Circuit re-opens for 30 seconds

---

### Pattern 4: **N+1 Query Elimination**

**Problem**: Loop with individual queries (1 + N queries).

**Solution**: Batch retrieval (1 + 1 queries).

**Before**:

```csharp
var items = await repository.GetItems();  // 1 query

foreach (var item in items)
{
    var detail = await repository.GetDetail(item.Id);  // N queries
    item.Detail = detail;
}
```

**After**:

```csharp
var items = await repository.GetItems();  // 1 query
var itemIds = items.Select(x => x.Id).ToList();
var details = await repository.GetDetailsBatch(itemIds);  // 1 query (with IN clause)

foreach (var item in items)
{
    item.Detail = details.FirstOrDefault(d => d.ItemId == item.Id);
}
```

**Entity Framework Core Example**:

```csharp
// Before (N+1):
var orders = await context.Orders.ToListAsync();  // Lazy loading triggers N queries

// After (Eager Loading):
var orders = await context.Orders
    .Include(o => o.OrderItems)  // Join in single query
    .Include(o => o.Customer)
    .ToListAsync();
```

---

### Pattern 5: **Fault Isolation in Parallel Processing**

**Problem**: One failure kills all parallel work.

**Solution**: Capture results, handle failures individually.

**Before**:

```csharp
var tasks = items.Select(async item => await ProcessItem(item));
await Task.WhenAll(tasks);  // ⚠️ Throws on first failure
```

**After**:

```csharp
var tasks = items.Select(async item => {
    try {
        var result = await ProcessItem(item);
        return new Result { Success = true, Item = item, Data = result };
    } catch (Exception e) {
        logger.LogError(e, "Failed to process {ItemId}", item.Id);
        return new Result { Success = false, Item = item, Error = e };
    }
});

var results = await Task.WhenAll(tasks);

// Handle results
var succeeded = results.Where(r => r.Success).ToList();
var failed = results.Where(r => !r.Success).ToList();

logger.LogInformation("Processed {Count} items: {Succeeded} succeeded, {Failed} failed",
    items.Count, succeeded.Count, failed.Count);

// Optionally: Publish failed items to DLQ for retry
foreach (var failure in failed)
{
    await deadLetterQueue.Publish(failure.Item);
}
```

---

### Pattern 6: **Observability: RED Metrics**

**RED**: Rate, Errors, Duration

**Implementation**:

```csharp
// Middleware or decorator
public async Task<T> InstrumentedExecute<T>(Func<Task<T>> operation, string operationName)
{
    var stopwatch = Stopwatch.StartNew();

    try
    {
        // Rate: Increment counter
        metricClient.IncrementCounter($"{operationName}.rate");

        var result = await operation();

        // Duration: Record latency
        stopwatch.Stop();
        metricClient.RecordDuration($"{operationName}.duration_ms", stopwatch.ElapsedMilliseconds);

        return result;
    }
    catch (Exception e)
    {
        // Errors: Increment error counter
        metricClient.IncrementCounter($"{operationName}.errors", new Dictionary<string, string> {
            { "error_type", e.GetType().Name }
        });

        throw;
    }
}

// Usage
var deliveryNote = await InstrumentedExecute(
    () => cloud4LogService.UploadDeliveryNote(note),
    "upload_delivery_note"
);
```

**Dashboard Queries**:

```
Rate: sum(rate(upload_delivery_note.rate[5m]))
Error Rate: sum(rate(upload_delivery_note.errors[5m])) / sum(rate(upload_delivery_note.rate[5m]))
Duration (p95): histogram_quantile(0.95, upload_delivery_note.duration_ms)
```

---

## 9. Decision Trees

### Decision Tree 1: **When to Use Event-Driven Architecture**

```
Is work triggered by external events? (HTTP requests, file uploads, etc.)
│
├─ YES → Use event-driven (API Gateway, Cloud Functions)
│
└─ NO → Is work scheduled?
    │
    ├─ YES → Does work volume vary significantly?
    │   │
    │   ├─ YES → Use event-driven with scheduled inventory service
    │   │         (CRON → Scan for work → Pub/Sub → Workers)
    │   │
    │   └─ NO → Can use CRON, but consider:
    │             - Is there risk of work exceeding interval?
    │             - Do you need fault tolerance?
    │             If YES to either: Use event-driven anyway
    │
    └─ NO → Not applicable (this is request-response architecture)
```

### Decision Tree 2: **Checkpointing Strategy Selection**

```
Do you need to resume after failure?
│
├─ NO → No checkpointing needed (e.g., idempotent operations with duplicate detection)
│
└─ YES → How often does state change?
    │
    ├─ Every record → Use per-record checkpointing (e.g., Kafka offsets)
    │
    ├─ Every batch → Use batch checkpointing (e.g., last processed timestamp)
    │
    └─ Every run → Use run-level checkpointing (e.g., last successful run time)

    Where to store?
    │
    ├─ < 1000 writes/second → Firestore (simple, managed)
    │
    ├─ 1000-10000 writes/second → Cloud SQL (relational, queryable)
    │
    └─ > 10000 writes/second → Redis (in-memory, cache-friendly)
```

### Decision Tree 3: **Optimization Priority**

```
Is the system currently failing? (errors, data loss, outages)
│
├─ YES → CRITICAL: Fix error handling, fault tolerance first
│         Priority: Workflow error handling, circuit breaker, checkpointing
│
└─ NO → Is the system slow? (timeouts, high latency, poor UX)
    │
    ├─ YES → PERFORMANCE: Optimize bottlenecks
    │         Priority: N+1 queries, database indexes, caching
    │
    └─ NO → Is the system expensive? (high cloud costs, resource waste)
        │
        ├─ YES → COST: Optimize resource usage
        │         Priority: Right-size instances, reduce invocations, cache
        │
        └─ NO → Is the system difficult to troubleshoot? (poor visibility)
            │
            ├─ YES → OBSERVABILITY: Add metrics, logs, tracing
            │
            └─ NO → Is the system difficult to scale? (manual intervention, capacity limits)
                │
                ├─ YES → SCALABILITY: Event-driven, auto-scaling, partitioning
                │
                └─ NO → System is healthy. Focus on:
                          - Technical debt reduction
                          - Developer experience
                          - Documentation
```

### Decision Tree 4: **Migration Strategy Selection**

```
Does the change affect external APIs or data formats?
│
├─ YES → Use versioned migration (v1 + v2 run in parallel)
│         - Deploy v2 alongside v1
│         - Gradually shift traffic (1% → 100%)
│         - Deprecate v1 after validation period
│
└─ NO → Is the change reversible?
    │
    ├─ YES → Use blue-green deployment
    │         - Deploy new version (green)
    │         - Switch traffic instantly
    │         - Keep old version (blue) for instant rollback
    │
    └─ NO → Is there data migration involved?
        │
        ├─ YES → Use shadow mode + validation
        │         - Run new system in read-only mode
        │         - Compare outputs with old system
        │         - After validation, switch writes
        │
        └─ NO → Use standard deployment
                  - Deploy to test environment
                  - Run integration tests
                  - Deploy to production
```

---

## 10. Checklists

### Checklist 1: **Pre-Architecture Review**

**Stakeholder Preparation**:

- [ ] Collect recent incident reports
- [ ] Review customer complaints about performance/reliability
- [ ] Identify seasonal patterns (peak hours, peak seasons)
- [ ] Document SLA requirements
- [ ] Gather cost data (current cloud spend)

**Code Exploration**:

- [ ] Identify main entry points (API endpoints, Cloud Functions)
- [ ] Trace end-to-end request flow
- [ ] List all external dependencies (databases, APIs, file systems)
- [ ] Find configuration files (timeouts, limits, intervals)
- [ ] Check for retry logic, error handling patterns

**Metrics Gathering**:

- [ ] Current throughput (requests/minute, records/minute)
- [ ] Peak throughput (historical data)
- [ ] P50, P95, P99 latency
- [ ] Error rate by error type
- [ ] Resource utilization (CPU, memory, connections)

---

### Checklist 2: **Architecture Review Process**

**Trigger Mechanism**:

- [ ] How is the system triggered? (CRON, HTTP, Pub/Sub)
- [ ] Can it adapt to load changes?
- [ ] What happens if next trigger fires before previous completes?
- [ ] Is there a backlog queue?

**State Management**:

- [ ] Is there persistent state tracking?
- [ ] Can the system resume after failure?
- [ ] What happens to partial progress?
- [ ] Is there idempotency / duplicate detection?

**Concurrency & Parallelism**:

- [ ] What determines maximum concurrency?
- [ ] Are there hard limits? (max instances, connection pools)
- [ ] Is work distributed evenly? (check for hot partitions)
- [ ] Are there serialization points? (global locks, single-threaded operations)

**Error Handling**:

- [ ] Does one failure affect others?
- [ ] Are errors classified (retriable vs. permanent)?
- [ ] Is there a dead-letter queue?
- [ ] Are there circuit breakers for external services?

**Performance**:

- [ ] Are there N+1 query patterns?
- [ ] Are expensive operations cached?
- [ ] Are there unnecessary serialization points?
- [ ] Is there timeout risk? (operation time vs. timeout limit)

**Observability**:

- [ ] Can you measure lag? (time since record created vs. processed)
- [ ] Are there metrics for throughput, error rate, latency?
- [ ] Are there alerts for SLO violations?
- [ ] Can you trace individual requests?

**Cost**:

- [ ] What are the main cost drivers? (compute, storage, data transfer)
- [ ] Are there resource leaks? (unused instances, orphaned storage)
- [ ] Can costs spike unexpectedly? (auto-scaling without limits)

---

### Checklist 3: **Proposal Development**

**For Each Bottleneck**:

- [ ] Generate 3-5 solution alternatives
- [ ] Estimate effort (days/weeks)
- [ ] Estimate cost impact ($/month)
- [ ] Assess risk (low/medium/high)
- [ ] Calculate ROI score
- [ ] Identify dependencies (what must be done first?)

**For Each Proposal**:

- [ ] Write concrete code examples (before/after)
- [ ] Create architecture diagrams
- [ ] Document migration path
- [ ] List pre-requisites
- [ ] Identify rollback procedure
- [ ] Define success metrics

**Prioritization**:

- [ ] Separate critical fixes from optimizations
- [ ] Identify quick wins (high ROI, low effort)
- [ ] Create phased roadmap (Phase 1: Critical, Phase 2: Performance, Phase 3: Strategic)
- [ ] Validate with stakeholders

---

### Checklist 4: **Pre-Implementation**

**Before Starting Work**:

- [ ] Test environment available and configured
- [ ] Success metrics defined (e.g., "reduce latency by 50%")
- [ ] Rollback procedure documented
- [ ] Team has reviewed and approved approach
- [ ] Budget approved (if cost increase)

**During Implementation**:

- [ ] Unit tests written (for new code)
- [ ] Integration tests written (for system interactions)
- [ ] Load tests written (for performance changes)
- [ ] Monitoring/dashboards created
- [ ] Documentation updated

**Before Production Deployment**:

- [ ] Code review completed
- [ ] Tests passing in CI/CD
- [ ] Load testing completed (simulate peak load)
- [ ] Rollback tested in staging environment
- [ ] On-call engineer identified for deployment window
- [ ] Stakeholders notified of deployment

---

### Checklist 5: **Post-Implementation Validation**

**Immediate (First 24 Hours)**:

- [ ] No critical errors in logs
- [ ] Metrics show expected improvement (e.g., latency reduced)
- [ ] No cost spikes
- [ ] No customer complaints
- [ ] Rollback procedure validated (if applicable)

**Short-Term (First Week)**:

- [ ] SLO compliance measured
- [ ] Performance improvement sustained
- [ ] No new error patterns
- [ ] Team feedback collected

**Long-Term (First Month)**:

- [ ] Cost analysis (compare actual vs. estimated)
- [ ] Capacity planning (can it handle peak load?)
- [ ] Lessons learned documented
- [ ] Refactoring opportunities identified

---

## 11. Case Study Template

Use this template to document future architectural reviews:

```markdown
# [System Name] Architectural Review

## 1. Executive Summary
- System purpose
- Key findings (3-5 bullet points)
- Recommended actions

## 2. Stakeholder Claims Verification
| Claim | Evidence | Verdict |
|-------|----------|---------|
| ... | ... | ✅/❌/⚠️ |

## 3. Quantified Bottlenecks
| Bottleneck | Impact | Evidence |
|------------|--------|----------|
| ... | ... | ... |

## 4. Scalability Scorecard
| Dimension | Current | Target | Gap |
|-----------|---------|--------|-----|
| Trigger | ⭐ | ⭐⭐⭐⭐⭐ | 4 |
| ... | ... | ... | ... |

## 5. Proposals
| # | Proposal | Effort | Cost | ROI | Priority |
|---|----------|--------|------|-----|----------|
| 1 | ... | ... | ... | ... | Critical |

## 6. Roadmap
- **Phase 1 (Week 1-2)**: Critical fixes
- **Phase 2 (Week 3-4)**: Performance optimization
- **Phase 3 (Week 5-8)**: Strategic investments

## 7. Cost-Benefit Analysis
- Initial investment: $X
- Annual operational cost: $Y
- Cost avoidance: $Z
- ROI: N%

## 8. Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ... | ... | ... | ... |

## 9. Success Metrics
- Metric 1: [baseline] → [target]
- Metric 2: [baseline] → [target]

## 10. Next Steps
1. Action item 1
2. Action item 2
```

---

## 12. Anti-Pattern Detection Automation

**Script to Find Common Anti-Patterns**:

```bash
#!/bin/bash
# architectural-linter.sh

echo "=== Architectural Anti-Pattern Detection ==="

echo "Checking for N+1 query patterns..."
grep -r "foreach.*await.*Get" --include="*.cs" --include="*.java" --include="*.py"

echo "Checking for missing circuit breakers..."
grep -r "WaitAndRetryAsync\|retryable" --include="*.cs" -L "CircuitBreakerAsync"

echo "Checking for CRON triggers..."
grep -r "schedule.*\*" --include="*.yml" --include="*.yaml"

echo "Checking for missing checkpointing..."
if ! grep -r "checkpoint\|offset\|watermark" --include="*.cs" --include="*.java" >/dev/null; then
    echo "⚠️ No checkpointing found"
fi

echo "Checking for workflow error handling..."
grep -r "except:" --include="*.yml" -A 3 | grep "raise:"

echo "Checking for parallel processing without fault isolation..."
grep -r "Task.WhenAll\|parallel" --include="*.cs" -B 5 -A 5 | grep -v "try.*catch"

echo "=== Detection Complete ==="
```

---

## 13. Key Takeaways

**For Architects**:

1. **Verify, don't assume**: Claims from stakeholders need code-level verification
2. **Quantify everything**: "Slow" is meaningless; "10× slower than necessary" is actionable
3. **Prioritize by ROI**: Not all bottlenecks matter; focus on high-impact, low-effort wins first
4. **Phase migrations**: Big-bang rewrites fail; incremental migrations succeed
5. **Measure success**: Define metrics before implementation, validate after

**For Developers**:

1. **Avoid premature optimization**: Optimize after measuring, not before
2. **Design for failure**: Assume external services will fail; add retries, circuit breakers
3. **Instrument from day one**: Add metrics, logs, tracing before production
4. **Test at scale**: Load testing in production-like environments prevents surprises
5. **Document decisions**: Future you (and teammates) will appreciate context

**For Engineering Managers**:

1. **Allocate time for tech debt**: 20% capacity for refactoring prevents emergencies
2. **Invest in observability**: You can't improve what you can't measure
3. **Celebrate quick wins**: High-ROI fixes boost team morale and demonstrate value
4. **Plan for peaks**: Seasonal traffic spikes require architectural headroom
5. **Balance speed vs. quality**: Fast delivery with poor architecture = slow rework

---

## 14. References & Further Reading

**Books**:

- *Designing Data-Intensive Applications* by Martin Kleppmann
- *Site Reliability Engineering* by Google
- *Release It!* by Michael Nygard
- *The Phoenix Project* by Gene Kim

**Patterns & Best Practices**:

- [Cloud Design Patterns (Microsoft)](https://learn.microsoft.com/en-us/azure/architecture/patterns/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Google Cloud Architecture Center](https://cloud.google.com/architecture)

**Tools**:

- **Polly** (C#): Resilience and transient-fault-handling library
- **Resilience4j** (Java): Fault tolerance library
- **Chaos Engineering**: Gremlin, Chaos Monkey
- **Observability**: Prometheus, Grafana, Datadog, New Relic

---

**Document Version**: 1.0
**Last Updated**: 2026-02-23
**Maintainer**: Architecture Team
**License**: Internal Use Only
