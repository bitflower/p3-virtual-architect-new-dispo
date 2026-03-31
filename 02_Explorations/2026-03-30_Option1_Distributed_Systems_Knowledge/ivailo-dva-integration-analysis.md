# Ivailo's DVA Integration Concept: Distributed Systems Analysis

**Sources:**
- `00_Meetings/2026-03-17_Cloud 4 Log I Weekly Status/concept-ivailo.md` (written concept)
- `00_Meetings/2026-03-17_Cloud 4 Log I Weekly Status/2026-03-17_Cloud 4 Log I Weekly Status.vtt` (verbal explanation)

**Lens:** Distributed Systems Patterns & Trade-offs

---

## Executive Summary

This document reveals Ivailo's **systematic approach to distributed systems design**. Unlike the transactional behavior meeting (reactive problem-solving), this is proactive architecture - pre-emptively addressing failure modes before implementation. The document demonstrates mastery of five key domains: **Performance, Reliability, Fault Isolation, Idempotency, and Testability**.

---

## 1. Performance Engineering

### 1.1 Batching Strategy

**What Ivailo Wrote:**
> "Reduce overheads (N+1 query complexity) - try to localize fetching of data from a single HTTP request or single SQL query"
>
> "Instead of fetching all data at once, batching as pagination or offset-based iteration should be used"
>
> "Numeric offset (page number, record offset) is usually not performing well, try to use sort and comparison on a field in conjunction with last record values from previous batch"

**Pattern: Cursor-Based Pagination over Offset Pagination**

| Approach | Ivailo's Recommendation | Reason |
|----------|------------------------|--------|
| `OFFSET N LIMIT M` | Avoid | O(N) skip cost, inconsistent with concurrent writes |
| `WHERE id > :last_id LIMIT M` | Preferred | O(1) seek, stable with concurrent writes |

**Formal Performance Analysis:**
```sql
-- Bad: Offset pagination
SELECT * FROM cartages ORDER BY id OFFSET 10000 LIMIT 100;
-- DB must scan and skip 10000 rows = O(N)

-- Good: Cursor pagination (Ivailo's recommendation)
SELECT * FROM cartages
WHERE date_created > :last_date
  AND id > :last_id
ORDER BY date_created ASC, id ASC
LIMIT 100;
-- DB seeks directly to cursor position = O(log N)
```

**Key Insight:** The compound cursor `(date_created, id)` handles the edge case where multiple records have the same `date_created` - the `id` breaks ties deterministically.

---

### 1.2 N+1 Query Prevention

**What Ivailo Wrote:**
> "Reduce overheads (N+1 query complexity) - try to localize fetching of data from a single HTTP request or single SQL query"

**Pattern: Batch Loading / DataLoader Pattern**

```
N+1 Problem:
for cartage in cartages:           # 1 query
    delivery_notes = get_notes(cartage.id)  # N queries
Total: N+1 queries

Batch Solution:
cartages = get_cartages()          # 1 query
notes = get_notes_for_cartages([c.id for c in cartages])  # 1 query
Total: 2 queries
```

**Applicable To:**
- TMS Bridge GraphQL requests
- DigiLiS DB queries
- Failed Cartages Retry Queue

---

### 1.3 Autoscaling with Data Partitioning

**What Ivailo Wrote:**
> "Ability to scale out when handling increased volumes"
> "Partition data on ranges"

**Pattern: Horizontal Scaling via Data Partitioning**

```
┌─────────────────────────────────────────────────────────┐
│                    Cloud Task Queue                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│  │Depot A  │ │Depot B  │ │Depot C  │ │Depot D  │        │
│  │00:00-   │ │00:00-   │ │00:00-   │ │00:00-   │        │
│  │06:00    │ │06:00    │ │06:00    │ │06:00    │        │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘        │
└───────┼──────────┼──────────┼──────────┼────────────────┘
        │          │          │          │
        ▼          ▼          ▼          ▼
   ┌─────────┐┌─────────┐┌─────────┐┌─────────┐
   │Worker 1 ││Worker 2 ││Worker 3 ││Worker 4 │  ← Autoscale
   └─────────┘└─────────┘└─────────┘└─────────┘
```

**Key Insight:** Partitioning by `(depot, time_range)` enables:
- Independent processing (no cross-partition dependencies)
- Proportional scaling (more depots = more workers)
- Failure isolation (one depot's failure doesn't block others)

---

### 1.4 Throttling / Backpressure

**What Ivailo Wrote:**
> "Limiting the max concurrency to prevent saturating underlying resources and degrade further the performance and reliability"
> "Configure max concurrency on Cloud Task Queues"

**Pattern: Controlled Concurrency / Backpressure**

```
Without Throttling:
Load Spike → All workers active → External API saturated → Cascading failures

With Throttling:
Load Spike → Queue absorbs excess → Workers process at safe rate → Graceful degradation
```

**NFR-02-07 Implementation:**
> "The system should prevent saturating external systems in the scenario of big processing spikes (especially after recovering from longer downtime)."

**Key Insight:** After downtime, the backlog can be massive. Without throttling, the system would hammer external APIs trying to catch up, causing secondary failures.

---

### 1.5 Cloud Task Queue Selection Rationale

**What Ivailo Said (Meeting):**
> "We actually decided to switch the overall messaging approach to Cloud Task Queue. The idea is that it would also provide better guarantees around this reliability concerns and the ability for us to delay some messages at some point of future in time when we know that we need to retry with the backoff instead of trying to immediately reprocess the message or holding it in memory. It's just more efficient from resource perspective."
>
> "There is another capability supported here, the deduplication of tasks. So when we have multiple retries or potentially some overlapping invocations of the cron scheduler... that wouldn't lead to trying to duplicate the work."

**Pattern: Managed Service Selection Criteria**

| Capability | In-Memory | Pub/Sub | Cloud Task Queue |
|------------|-----------|---------|------------------|
| Delayed delivery | No | No | Yes |
| Task deduplication | Manual | No | Built-in |
| Retry with backoff | Manual | Manual | Built-in |
| Resource efficiency | Low (holds in memory) | Medium | High |

**Key Insight:** Cloud Task Queue was chosen specifically for:
1. **Delayed retry** - schedule retry for future without holding resources
2. **Deduplication** - prevent duplicate processing from overlapping cron invocations
3. **Offloading complexity** - less custom code to maintain

---

### 1.6 Polling Interval Trade-off

**What Ivailo Wrote:**
> "The polling interval should balance between fetching too little data at once (throughput) and fetching data with delay (latency)"

**Pattern: Throughput vs. Latency Trade-off**

| Polling Interval | Throughput | Latency | Cost |
|-----------------|------------|---------|------|
| Very frequent (1s) | Low per poll | Low | High (API calls) |
| Infrequent (10m) | High per poll | High | Low |
| Balanced (1-2m) | Medium | Medium | Medium |

**Formal Trade-off:**
```
Total Cost = (API calls/hour) × (cost per call) + (latency penalty)

Where:
- API calls/hour = 60 / polling_interval_minutes
- Latency penalty = f(SLA violation probability)
```

---

### 1.6 Streaming vs. Buffering

**What Ivailo Wrote:**
> "Buffer uploads/download with in-memory buffer if possible with underlying APIs instead of fetching whole files in memory"
> "Write chunks into sockets being part of the same request or use APIs that allow assembling chunks over multiple requests"

**Pattern: Streaming I/O for Large Files**

```
Buffered (Bad for large files):
1. Read entire 10MB PDF into memory
2. Hold in memory
3. Write entire 10MB to destination
Peak Memory: 10MB per file × concurrent files

Streaming (Good):
1. Read 64KB chunk
2. Write 64KB chunk
3. Repeat until done
Peak Memory: 64KB per file × concurrent files
```

**NFR-01-06 Context:**
> "The system should support delivery notes upload and good receipts download of size 3MB on average and less than 10MB as upper boundary."

**Key Insight:** With 70 depots processing concurrently, buffering 10MB files could consume 700MB+ memory. Streaming keeps memory bounded.

---

## 2. Reliability Engineering

### 2.1 Retry Classification

**What Ivailo Wrote:**
> "Classification of transient errors is critical:
> - false positive transient error leads to occupying resources for endless retries
> - false positive non-transient error leads to discarding data from processing"

**Pattern: Error Classification Matrix**

| Classification | Actual Transient | Actual Permanent |
|---------------|------------------|------------------|
| **Classified Transient** | Correct: Retry succeeds | False Positive: Endless retries |
| **Classified Permanent** | False Negative: Data lost | Correct: Fail fast |

**Key Insight:** Both classification errors are costly, but in different ways:
- False positive transient → Resource exhaustion
- False negative transient → Data loss

**Ivailo's Mitigation:** Bounded retries (NFR-02-06: "at least 3 times") prevent endless retry loops.

---

### 2.2 In-Memory vs. Persistent Retries

**What Ivailo Wrote:**
> "In memory vs persistent - in-memory for retries < 3 seconds of cumulative retry time and persistent in Cloud Task Queues for all the rest"

**Pattern: Tiered Retry Strategy**

```
┌─────────────────────────────────────────────────────────┐
│                    Retry Decision Tree                   │
└─────────────────────────────────────────────────────────┘

          Error Occurs
               │
               ▼
    ┌──────────────────────┐
    │ Cumulative retry     │
    │ time < 3 seconds?    │
    └──────────┬───────────┘
               │
       Yes ────┼──── No
               │          │
               ▼          ▼
    ┌──────────────┐  ┌──────────────────┐
    │ In-Memory    │  │ Persist to       │
    │ Retry        │  │ Cloud Task Queue │
    │ (100ms, 1s)  │  │ (exponential)    │
    └──────────────┘  └──────────────────┘
```

**Rationale:**
- In-memory: Fast, no I/O overhead, handles network blips
- Persistent: Survives process restarts, handles extended outages

**Key Insight:** The 3-second threshold is a **process lifecycle boundary** - if the service restarts within 3 seconds, in-memory state is lost but that's acceptable for short operations.

---

### 2.3 Workflow Reliability via Frequent Trigger

**What Ivailo Said (Meeting):**
> "What's changing is actually the way how we trigger these tasks because in theory also the workflow could fail sporadically. Nothing is 100% available. From that perspective, we've taken care that this kind of scheduling of the items here would be performed in a reliable manner by preserving this offset, but actually changing the trigger to invoke the workflow."
>
> "Let's say every few seconds and from that on we'll be just checking if time elapsed to schedule a new task, maybe then we'll have another interval, let's say 30 seconds. So we can also cover this kind of high throughput scenarios without overly introducing overhead of frequent polling to the underlying internal Nagel applications."

**Pattern: Heartbeat-Based Coordination**

```
Traditional: Single scheduled trigger
┌─────────┐         ┌──────────┐
│ Cron    │────────▶│ Workflow │  ← If workflow fails, wait for next cron
│ (5 min) │         └──────────┘
└─────────┘

Ivailo's approach: Frequent lightweight check
┌─────────┐         ┌──────────────┐         ┌──────────┐
│ Cron    │────────▶│ Check offset │────────▶│ Workflow │
│ (few s) │         │ + elapsed    │         └──────────┘
└─────────┘         └──────────────┘
                         │
                         ▼
              If offset stale → trigger workflow
              If recent → no-op (cheap)
```

**Key Insight:** By decoupling the trigger frequency from the work frequency, the system:
- **Recovers faster** from workflow failures (detected within seconds)
- **Avoids overhead** (only triggers work when time threshold exceeded)
- **Handles varying load** (high throughput = more frequent, low throughput = less)

---

### 2.4 Checkpointing

**What Ivailo Wrote:**
> "Checkpointing:
> - storing an offset when generating tasks so that the next iteration will yield the same
> - storing failed records only in dedicated task queue"

**Pattern: Checkpoint-Based Recovery**

```
Without Checkpointing:
Process fails at record 500 of 1000
Restart: Process all 1000 again (500 duplicates)

With Checkpointing:
Process fails at record 500 of 1000
Checkpoint saved: last_processed = 500
Restart: Resume from 501 (no duplicates)
```

**Formal Guarantee:**
```
checkpoint(state) + idempotent(processing) = exactly-once semantics
```

---

### 2.4 Fault Isolation

**What Ivailo Wrote:**
> "Partition tasks per platform and per date range (instead of having big date ranges tasks on both Markant DVA and C4L)"
> "Concurrent message processing; since messages are not related even if there are data quality issues with some of the cartages the rest of the cartages are processed independently"

**Pattern: Bulkhead Pattern**

```
Without Bulkheads:
┌─────────────────────────────────┐
│ Single Processing Pipeline      │
│ Depot A, B, C, D all together  │
│ One failure → All blocked      │
└─────────────────────────────────┘

With Bulkheads (Ivailo's approach):
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Depot A  │ │ Depot B  │ │ Depot C  │ │ Depot D  │
│ Isolated │ │ Isolated │ │ Isolated │ │ Isolated │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
     │            │            │            │
     ▼            ▼            ▼            ▼
  Failure      Success      Success      Success
```

**Key Insight:** NFR-02-02 explicitly requires this:
> "In case of data quality issues in the delivery notes or consignees the system should synchronize the rest of the valid data with 99.999999999% success ratio."

---

### 2.5 Concurrency Isolation

**What Ivailo Wrote:**
> "Preventing multiple processing of bordero / rollkarte batches on same (depot, offset) tuple"

**Pattern: Distributed Locking via Unique Task ID**

```
Task Queue guarantees:
- Task ID = hash(depot, start_date, end_date)
- Duplicate task IDs are rejected
- Only one worker processes a given (depot, time_range) at a time
```

**Race Condition Prevented:**
```
Without unique task ID:
T1: Cron fires, creates task for Depot A, 00:00-06:00
T2: Task starts processing
T3: Cron fires again, creates another task for Depot A, 00:00-06:00
T4: Two workers process same data → Duplicates!

With unique task ID:
T1: Cron fires, creates task ID "depot-a-0000-0600"
T2: Task starts processing
T3: Cron fires, tries to create "depot-a-0000-0600" → REJECTED (duplicate)
```

---

### 2.6 At-Least-Once Delivery

**What Ivailo Wrote:**
> "At least-once-delivery - awaiting submission first before marking data as processed (confirming message, updating offsets) and potential retry on the same data"

**Pattern: Ack-After-Commit**

```
Wrong Order (At-Most-Once, may lose data):
1. Mark message as processed
2. Process message ← If this fails, message is lost

Correct Order (At-Least-Once):
1. Process message
2. Mark message as processed ← If this fails, message is redelivered
```

**Guarantee Chain:**
```
At-Least-Once + Idempotent = Effectively Exactly-Once
```

---

## 3. Idempotency Engineering

### 3.1 Multi-Layer Idempotency

**What Ivailo Wrote:**
> "Critical for preventing duplicates on the destination platforms"
> "Prefer native support (unique constraints, upsert (insert or update), deduplication)"
> "Fallback to query and update"

**Pattern: Defense-in-Depth Idempotency**

| Layer | Mechanism | Where Applied |
|-------|-----------|---------------|
| Queue | Task deduplication | Cloud Task Queues |
| Database | Unique constraints | DigiLiS, POD Storage |
| API | Upsert semantics | C4L, Markant DVA |
| Application | Query-before-write | Fallback |

**Key Insight:** Each layer provides independent protection. Even if one layer fails, others catch duplicates.

---

### 3.2 Upsert vs. Query-then-Write

**What Ivailo Wrote:**
> "Prefer native support (unique constraints, upsert)"
> "Fallback to query and update"

**Pattern Comparison:**

```sql
-- Upsert (Preferred): Atomic, no race condition
INSERT INTO delivery_notes (id, data)
VALUES (:id, :data)
ON CONFLICT (id) DO UPDATE SET data = :data;

-- Query-then-Write (Fallback): Race condition possible
SELECT * FROM delivery_notes WHERE id = :id;
IF exists:
    UPDATE delivery_notes SET data = :data WHERE id = :id;
ELSE:
    INSERT INTO delivery_notes (id, data) VALUES (:id, :data);
```

**Race Condition in Query-then-Write:**
```
T1: Query → not exists
T2: Query → not exists
T1: Insert → success
T2: Insert → DUPLICATE KEY ERROR (or worse: succeeds!)
```

---

## 4. NFR Analysis: Hidden Distributed Systems Constraints

### 4.1 The "11 Nines" Reliability Target

**NFR-02-01:**
> "The system should synchronize data with 99.999999999% (11 9's) success ratio"

**Reality Check:**
```
99.999999999% = 1 failure per 100 billion operations
Annual volume ≈ 2 cartages × 70 depots × 60 min × 24h × 365 days
            ≈ 73.5 million cartages/year

At 11 nines: Expected failures = 0.000735 per year
           ≈ 1 failure every 1,361 years
```

**Key Insight:** This is aspirational, not achievable. However, it signals intent: **data loss is unacceptable**. The architecture (retries, checkpointing, idempotency) aims for this asymptotically.

---

### 4.2 Recovery Prioritization

**NFR-02-08:**
> "The system should prioritize latest records when recovering from downtimes to limit as much as possible using a non-software business continuity paper-based solution."

**Pattern: Recency-Biased Recovery**

```
Standard Recovery: Process backlog in order
[Day 1] [Day 2] [Day 3] [Day 4] [Today]
   ▲──────────────────────────────────
   Start here (oldest first)

Ivailo's Recovery: Process newest first
[Day 1] [Day 2] [Day 3] [Day 4] [Today]
                                    ▲
                         Start here (newest first)
```

**Business Rationale:** Drivers on the road TODAY need digital delivery notes. Yesterday's deliveries can fall back to paper temporarily.

**What Ivailo Said (Meeting):**
> "Once trucks are being loaded, they would be waiting for some particular amount of time, let's say several minutes if something goes wrong. They will need to fall back to a paper-based approach. Let's say Cloud4Log or Markant is down."
>
> "From that perspective, this means some of these trucks would already be switching to a paper-based approach because obviously the system is not available, this QR scanning is not available."
>
> "What would happen next from our perspective is we're accumulating some backlog of items to be synchronized. Now we don't really want to prioritize back-filling the historical data because once Markant or Cloud comes back up, we will need to actually switch immediately for the trucks that still need to be loaded with the necessary documents."

**Pattern: Priority Queue with Backlog Isolation**

```
┌─────────────────────────────────────────────────────────────┐
│                    Two-Queue Architecture                    │
└─────────────────────────────────────────────────────────────┘

                 System Recovers
                       │
                       ▼
    ┌──────────────────────────────────────┐
    │           New Items Queue            │  ← Priority: Process FIRST
    │  (trucks currently being loaded)     │
    └──────────────────┬───────────────────┘
                       │
                       ▼
              Workers process
              immediately
                       │
                       ▼
    ┌──────────────────────────────────────┐
    │          Retry/Backlog Queue         │  ← Process when new queue empty
    │  (historical items from downtime)    │
    └──────────────────────────────────────┘
```

**What Ivailo Said (Meeting):**
> "We actually want to prioritize newest items first and that approach actually manages that because we actually put all the rest of the work in a separate queue and that's still pending while the new ones is kind of freed. And can could be taken immediately concurrently to the ones to the items that we need to retry."

**Key Insight:** The two-queue architecture ensures that **recovery doesn't block current operations**. New trucks get their digital delivery notes immediately, while the backlog is processed in parallel at lower priority.

---

### 4.3 Seasonal Peak Handling

**NFR-01-03 & NFR-01-04:**
> "5 times increase during seasonal peaks (pre-Christmas, Easter)"
> "3 times increase during rush hours (05:00-09:00, 17:00-22:00)"

**Combined Peak:**
```
Base load: 2 cartages/depot/minute × 70 depots = 140 cartages/minute

Peak multiplier: 5 (seasonal) × 3 (rush hour) = 15x

Peak load: 140 × 15 = 2,100 cartages/minute = 35 cartages/second
```

**Key Insight:** The throttling and autoscaling mechanisms must handle this 15x swing gracefully.

---

## 5. Testability Engineering

### 5.1 Component Testing Philosophy

**What Ivailo Wrote:**
> "Component tests - simulating the components behavior in isolation, treating them as black boxes and working with their interfaces"

**What Ivailo Said (Meeting):**
> "Reliability testing is really hard to achieve with manual testing and our idea is actually to simulate this with fully automated tests. We'll be covering this. Most of the logic would be around this service here, so we'll be covering this completely with component integration tests, meaning that all of these external systems they will be stubbed. They will be made as dummy servers as part of component integration tests and this one will be tested as a black box."
>
> "We'll be just validating the end result, so we'll be providing some task. We would specify what kind of data is returned by corresponding internal Nagel systems and we'll be checking the outcome, what kind of data has been synchronized and we will be simulating all these various scenarios, including recovery, including idempotent handling."
>
> "Bringing this up as a framework would probably be the most significant amount of time to provide these capabilities of stubbing all of these dependencies and orchestrating the entire flow."

**Key Insight:** The testing framework itself is the **largest investment**. Once built, adding new test scenarios is incremental. This is why Ivailo prioritizes it - the framework provides regression confidence during refactoring.

**Pattern: Port and Adapter Testing**

```
┌─────────────────────────────────────────────────────────┐
│                    Component Under Test                  │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Business Logic                       │   │
│  └─────────────────────────────────────────────────┘   │
│        │                              │                  │
│  ┌─────▼─────┐                 ┌─────▼─────┐           │
│  │ Port: DB  │                 │ Port: API │           │
│  └─────┬─────┘                 └─────┬─────┘           │
└────────┼───────────────────────────────┼────────────────┘
         │                               │
   ┌─────▼─────┐                   ┌─────▼─────┐
   │ Test      │                   │ WireMock  │
   │ Container │                   │ Stub      │
   └───────────┘                   └───────────┘
```

---

### 5.2 Failure Scenario Coverage

**What Ivailo Wrote:**
> "Covering not only the positive scenarios but various failure scenarios"

**Pattern: Chaos Engineering Lite**

| Failure Scenario | Test Mechanism |
|------------------|----------------|
| External API down | WireMock returns 503 |
| Database timeout | TestContainers with network delay |
| Partial failure | Stub returns success for some, error for others |
| Duplicate delivery | Assert idempotency (same result on retry) |

---

## 6. Modifiability Engineering

### 6.1 Adapter Pattern for Multi-Platform

**What Ivailo Wrote:**
> "Adapter pattern - Upload Service to include common interface for upload and separate classes as implementation for different platforms"

**Pattern: Strategy with Platform Adapters**

```
┌─────────────────────────────────────────────────────────┐
│                    Upload Service                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │         IPlatformAdapter (Interface)             │   │
│  │  + uploadDeliveryNote(cartage): Result           │   │
│  │  + authenticate(): Token                          │   │
│  └─────────────────────────────────────────────────┘   │
│              ▲                        ▲                  │
│              │                        │                  │
│  ┌───────────┴──────────┐  ┌─────────┴────────────┐    │
│  │ Cloud4LogAdapter     │  │ MarkantDVAAdapter    │    │
│  │ - API Key auth       │  │ - OAuth 2.0 auth     │    │
│  │ - Bundle model       │  │ - Transport model    │    │
│  └──────────────────────┘  └──────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**NFR-04-01:**
> "The system should enable onboarding one similar platform to Markant DVA within 1 month."

**Key Insight:** The adapter pattern makes this achievable - new platform = new adapter class, not rewrite.

---

### 6.2 Domain Model Unification

**What Ivailo Wrote:**
> "Bordero and Rollkarte processing unification - working with unified domain model of cartages. Common codebase for NFRs concerns."

**Pattern: Canonical Data Model**

```
External Models (Platform-Specific):
┌──────────────────┐     ┌──────────────────┐
│ Cloud4Log Model  │     │ DVA Model        │
│ - Bundle         │     │ - Transport      │
│ - Tour           │     │ - Consignment    │
│ - Checkout       │     │ - DeliveryNote   │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────────┐
│           Canonical Model (Cartage)          │
│ - Unified representation                     │
│ - Platform-agnostic                          │
│ - All NFR logic applies here                 │
└─────────────────────────────────────────────┘
```

**Key Insight:** NFR logic (retries, logging, metrics) is written once against the canonical model, not duplicated per platform.

---

### 6.3 Simplification Through Managed Services

**What Ivailo Said (Meeting):**
> "We are introducing less components that need to be hosted and we are offloading more of these capabilities to the Cloud Tasks Queues. That's the overall improvement."
>
> "For this upload process, the download is also simpler. We don't need another storage, we don't need some locking mechanisms. Again, we are using the same Cloud Task Queue approach. And then potentially retrying the task indefinitely until the download completes."

**Pattern: Build vs. Buy for Infrastructure**

| Capability | Self-Hosted | Cloud Task Queue |
|------------|-------------|------------------|
| Retry with backoff | Custom code | Configuration |
| Deduplication | Custom + storage | Built-in |
| Delay scheduling | Custom + timer | Built-in |
| Locking | Custom + Redis/DB | Not needed |
| Hosting | Yes | No |
| Monitoring | Custom | Built-in |

**Key Insight:** Every component you don't host is a component you don't:
- Deploy
- Monitor
- Scale
- Debug at 3 AM

This is **operational complexity reduction**, not just development complexity.

---

## 7. Summary: Ivailo's Architecture Philosophy

### Design Principles Extracted

| Principle | Implementation |
|-----------|----------------|
| **Bounded Resources** | Throttling, streaming, cursor pagination |
| **Fault Isolation** | Bulkheads per depot, independent task processing |
| **Tiered Reliability** | In-memory retry → Persistent queue → Manual intervention |
| **Defense-in-Depth Idempotency** | Queue dedup + DB constraints + Upsert + Query fallback |
| **Recency-Biased Recovery** | Newest data first after downtime |
| **Interface-First Design** | Adapter pattern for platforms, canonical model for logic |
| **Failure-First Testing** | WireMock stubs, TestContainers, chaos scenarios |

---

### Pattern Catalog

| Pattern | Ivailo's Application | Section |
|---------|---------------------|---------|
| Cursor-Based Pagination | `WHERE date > :last AND id > :last_id` | 1.1 |
| Batch Loading | N+1 prevention in GraphQL/SQL | 1.2 |
| Horizontal Partitioning | (depot, time_range) tasks | 1.3 |
| Backpressure | Cloud Task Queue max concurrency | 1.4 |
| Managed Service Selection | Cloud Task Queue for delay + dedup | 1.5 |
| Heartbeat-Based Coordination | Frequent trigger, conditional work | 2.3 |
| Tiered Retry | In-memory < 3s, persistent otherwise | 2.2 |
| Checkpointing | Offset storage for restart recovery | 2.4 |
| Bulkhead | Per-depot isolation | 2.5 |
| Distributed Lock | Unique task ID deduplication | 2.6 |
| Ack-After-Commit | At-least-once delivery | 2.7 |
| Priority Queue with Backlog Isolation | New items queue + retry queue | 4.2 |
| Upsert Idempotency | Native DB/API support preferred | 3.2 |
| Adapter Pattern | Multi-platform abstraction | 6.1 |
| Canonical Model | Unified cartage representation | 6.2 |
| Build vs. Buy | Offload to managed services | 6.3 |

---

### Comparison: Transactional Behavior vs. DVA Integration

| Aspect | Transactional Behavior (Reactive) | DVA Integration (Proactive) |
|--------|----------------------------------|----------------------------|
| **Context** | Existing problem to solve | Greenfield design |
| **Scope** | Single operation (transport order) | Entire data pipeline |
| **Retry Model** | User-driven | System-driven with fallback |
| **State Persistence** | None (Option 1) | Full checkpointing |
| **Idempotency** | Application-level query | Multi-layer (queue + DB + API) |
| **Fault Isolation** | Not addressed | Explicit bulkheads |

**Key Insight:** Ivailo applies **the same principles** but with different trade-offs based on context:
- Transactional: Minimize complexity for June go-live
- DVA: Full reliability engineering for production pipeline

