# Distributed Systems Architecture Scanner Agents

A 360-degree agent/skill set for scanning cloud architecture designs from every angle.

---

## Agent Taxonomy (53 Specialized Agents)

### Category 1: Consistency & Data Integrity Scanners (10 agents)

| Agent | Purpose |
|-------|---------|
| `cap-theorem-analyst` | Evaluate C/A/P trade-offs, identify which guarantees are chosen/sacrificed |
| `consistency-model-scanner` | Detect strong/eventual/causal consistency patterns, flag mismatches |
| `idempotency-pattern-detector` | Find idempotency implementations (keys, state-inspection, natural), identify gaps |
| `race-condition-hunter` | Detect TOCTOU, lost updates, phantom deletes, ABA problems |
| `concurrency-control-analyst` | Evaluate OCC vs PCC, version vectors, conflict detection strategies |
| `ordering-guarantee-scanner` | Analyze causal dependencies, find operations requiring ordering |
| `crdt-opportunity-detector` | Identify where state-convergent/declarative mutations could help |
| `soft-delete-necessity-scanner` | Find delete operations that need tombstones for safety |
| `base-vs-acid-classifier` | Map which boundaries are ACID vs BASE, flag inconsistencies |
| `data-sovereignty-scanner` | Identify source-of-truth ownership, detect split-brain risks |

---

### Category 2: Failure & Resilience Scanners (12 agents)

| Agent | Purpose |
|-------|---------|
| `failure-mode-mapper` | Enumerate all failure points, classify by impact |
| `failure-domain-analyst` | Map failure domains, identify cross-domain vulnerabilities |
| `error-classification-auditor` | Validate error taxonomy (recoverable/unrecoverable), find misclassifications |
| `retry-strategy-evaluator` | Analyze retry patterns, detect thundering herd risks |
| `circuit-breaker-detector` | Find missing circuit breakers, evaluate existing ones |
| `cascade-failure-predictor` | Model failure amplification paths, predict cascades |
| `timeout-strategy-scanner` | Find timeout configurations, detect inconsistent/missing timeouts |
| `backpressure-analyst` | Identify backpressure mechanisms (or lack thereof) |
| `recovery-pattern-evaluator` | Assess recovery strategies (manual vs automated) |
| `partial-failure-handler-scanner` | Find operations that need partial failure handling |
| `degradation-mode-detector` | Identify graceful degradation strategies (or missing ones) |
| `blast-radius-calculator` | Estimate impact scope of each failure type |

---

### Category 3: Transaction & Write Pattern Scanners (8 agents)

| Agent | Purpose |
|-------|---------|
| `transaction-boundary-mapper` | Map transaction scopes, find boundary violations |
| `write-order-strategy-analyst` | Evaluate remote-first vs local-first patterns |
| `two-phase-commit-detector` | Find implicit/explicit 2PC usage, assess viability |
| `saga-pattern-evaluator` | Detect saga implementations, assess compensation completeness |
| `outbox-pattern-scanner` | Find outbox implementations, evaluate reliability |
| `event-sourcing-assessor` | Evaluate event sourcing applicability/implementation |
| `dual-write-detector` | Find dangerous dual-write patterns without safety mechanisms |
| `atomic-operation-boundary-scanner` | Identify operations that should be atomic but aren't |

---

### Category 4: Integration & Boundary Scanners (7 agents)

| Agent | Purpose |
|-------|---------|
| `anti-corruption-layer-auditor` | Evaluate domain translation quality at boundaries |
| `system-boundary-mapper` | Map all integration points, classify by coupling type |
| `sync-vs-async-evaluator` | Assess synchronous vs asynchronous pattern fitness |
| `api-contract-stability-scanner` | Find brittle API dependencies, version mismatches |
| `coupling-strength-analyzer` | Measure temporal/spatial coupling, find tight coupling |
| `integration-pattern-classifier` | Classify patterns (request-reply, publish-subscribe, etc.) |
| `external-dependency-risk-scorer` | Score each external dependency by reliability impact |

---

### Category 5: Scalability & Performance Scanners (8 agents)

| Agent | Purpose |
|-------|---------|
| `bottleneck-predictor` | Identify likely bottlenecks under load |
| `scaling-pattern-evaluator` | Assess horizontal vs vertical scaling readiness |
| `batching-opportunity-detector` | Find operations that could benefit from batching |
| `rate-limiting-scanner` | Find rate limiting (or missing rate limiting) |
| `load-characteristic-profiler` | Profile read/write ratios, access patterns |
| `resource-exhaustion-predictor` | Find connection pool, memory, thread exhaustion risks |
| `latency-amplification-detector` | Find N+1 problems, sequential call chains |
| `hot-spot-predictor` | Identify data/service hot spots under load |

---

### Category 6: Observability & Operations Scanners (6 agents)

| Agent | Purpose |
|-------|---------|
| `observability-gap-finder` | Find missing metrics, logs, traces |
| `reconciliation-strategy-auditor` | Evaluate consistency verification mechanisms |
| `drift-detection-evaluator` | Assess drift detection between systems |
| `alerting-completeness-scanner` | Find missing alerts for critical failure modes |
| `debugging-capability-assessor` | Evaluate ability to diagnose production issues |
| `audit-trail-scanner` | Find operations needing audit logging |

---

### Category 7: UX & Human Factors Scanners (5 agents)

| Agent | Purpose |
|-------|---------|
| `user-feedback-loop-analyzer` | Evaluate feedback timing (sync vs async UX) |
| `error-communication-auditor` | Assess error message actionability and clarity |
| `cognitive-load-estimator` | Estimate operator cognitive burden |
| `human-in-loop-evaluator` | Assess where humans are in the loop, fitness thereof |
| `retry-ux-scanner` | Evaluate user retry experience, frustration potential |

---

### Category 8: Portability & Infrastructure Scanners (5 agents)

| Agent | Purpose |
|-------|---------|
| `infrastructure-dependency-mapper` | Map all infrastructure dependencies |
| `technology-lock-in-scanner` | Find vendor/technology lock-in risks |
| `deployment-flexibility-assessor` | Evaluate portability across deployment models |
| `stateless-stateful-classifier` | Classify components, find problematic stateful services |
| `cloud-native-readiness-scorer` | Score readiness for cloud-native deployment |

---

### Category 9: Anti-Pattern Detectors (6 agents)

| Agent | Purpose |
|-------|---------|
| `distributed-transaction-antipattern-detector` | Find problematic 2PC usage patterns |
| `saga-antipattern-detector` | Find incomplete compensation, orphan sagas |
| `microservice-antipattern-scanner` | Find distributed monolith, chatty services |
| `shared-database-antipattern-detector` | Find services sharing databases inappropriately |
| `synchronous-coupling-antipattern-scanner` | Find brittle synchronous dependency chains |
| `god-service-detector` | Find services with too many responsibilities |

---

### Category 10: Synthesis & Reporting Agents (6 agents)

| Agent | Purpose |
|-------|---------|
| `trade-off-matrix-generator` | Generate trade-off analysis matrices |
| `pattern-catalog-mapper` | Map design to known pattern catalog |
| `implementation-checklist-generator` | Generate implementation checklists per pattern |
| `test-scenario-generator` | Generate failure test scenarios |
| `risk-score-aggregator` | Aggregate findings into risk scores |
| `architecture-decision-record-generator` | Generate ADRs from findings |

---

## Usage Model

```
┌────────────────────────────────────────────────────────────────┐
│                    architecture-scanner                         │
│                    (orchestrator agent)                         │
└─────────────────────────┬──────────────────────────────────────┘
                          │
    ┌─────────────────────┼─────────────────────┐
    │                     │                     │
    ▼                     ▼                     ▼
┌────────┐          ┌────────┐           ┌────────┐
│Category│          │Category│           │Category│
│Scanners│ ... x10  │Scanners│  ... x10  │Scanners│
└────────┘          └────────┘           └────────┘
    │                     │                     │
    └─────────────────────┼─────────────────────┘
                          ▼
              ┌────────────────────┐
              │ risk-score-aggregator │
              │ trade-off-matrix-gen  │
              │ adr-generator         │
              └────────────────────┘
```

---

## Derived From

This agent taxonomy was derived from the distributed systems knowledge extracted from Option 1 analysis:

- [distributed-systems-patterns-option1.md](./distributed-systems-patterns-option1.md)

### Key Knowledge Sources Used

| Section | Agents Derived |
|---------|----------------|
| CAP Theorem Positioning | `cap-theorem-analyst`, `base-vs-acid-classifier` |
| Idempotency Patterns | `idempotency-pattern-detector`, `race-condition-hunter` |
| Error Classification Framework | `error-classification-auditor`, `retry-strategy-evaluator` |
| Transaction Boundary Isolation | `transaction-boundary-mapper`, `dual-write-detector` |
| Failure Mode Analysis | `failure-mode-mapper`, `blast-radius-calculator` |
| System Boundary Design | `anti-corruption-layer-auditor`, `system-boundary-mapper` |
| Scaling Characteristics | `bottleneck-predictor`, `cascade-failure-predictor` |
| Observability Requirements | `observability-gap-finder`, `reconciliation-strategy-auditor` |
| UX Implications | `user-feedback-loop-analyzer`, `error-communication-auditor` |
| Anti-Patterns Avoided | All Category 9 agents |

---

## Implementation Priority

### Phase 1: Core Scanners (High Impact)
1. `failure-mode-mapper` - Most critical for risk assessment
2. `consistency-model-scanner` - Foundational for correctness
3. `transaction-boundary-mapper` - Common source of bugs
4. `error-classification-auditor` - Drives resilience behavior
5. `risk-score-aggregator` - Synthesis for decision-making

### Phase 2: Deep Analysis
6-15. Remaining Category 1-3 agents

### Phase 3: Operational Readiness
16-25. Categories 4-6 agents

### Phase 4: Polish & UX
26-35. Categories 7-8 agents

### Phase 5: Anti-Pattern & Synthesis
36-53. Categories 9-10 agents

---

## Implementation Status

**COMPLETED:** All 53 agents have been implemented and are available at:
```
.claude/agents/distributed-systems-scanners/
├── 01-consistency-data/       (10 agents)
├── 02-failure-resilience/     (12 agents)
├── 03-transaction-write/      (8 agents)
├── 04-integration-boundary/   (7 agents)
├── 05-scalability-performance/ (8 agents)
├── 06-observability-operations/ (6 agents)
├── 07-ux-human-factors/       (5 agents)
├── 08-portability-infrastructure/ (5 agents)
├── 09-anti-patterns/          (6 agents)
├── 10-synthesis-reporting/    (6 agents)
└── README.md                  (documentation)
```

## Next Steps

1. ~~Define agent prompt templates with specific evaluation criteria~~ ✅ Done
2. Create the orchestrator that runs agents in parallel
3. ~~Build synthesis agents for actionable output~~ ✅ Done
4. Test against known architecture documents
