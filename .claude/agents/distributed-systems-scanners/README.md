# Distributed Systems Architecture Scanner Suite

A comprehensive 360-degree agent toolkit for scanning cloud architecture designs from every possible angle.

## Overview

This suite contains **53 specialized agents** organized into **10 categories** for analyzing distributed systems architectures. Each agent focuses on a specific aspect of distributed systems design and provides structured output formats for consistent analysis.

## Quick Start

```
# Run a single scanner
Use agent: distributed-systems-scanners/01-consistency-data/cap-theorem-analyst

# Or reference in orchestration
Analyze architecture document using agents from:
- 01-consistency-data/
- 02-failure-resilience/
```

## Categories

### 01 - Consistency & Data Integrity (10 agents)
Evaluate data consistency patterns, CAP theorem positioning, and integrity mechanisms.

| Agent | Purpose |
|-------|---------|
| `cap-theorem-analyst` | Evaluate C/A/P trade-offs |
| `consistency-model-scanner` | Detect consistency patterns and mismatches |
| `idempotency-pattern-detector` | Find idempotency implementations and gaps |
| `race-condition-hunter` | Detect TOCTOU, lost updates, ABA problems |
| `concurrency-control-analyst` | Evaluate OCC vs PCC strategies |
| `ordering-guarantee-scanner` | Analyze causal dependencies |
| `crdt-opportunity-detector` | Identify CRDT opportunities |
| `soft-delete-necessity-scanner` | Find delete operations needing tombstones |
| `base-vs-acid-classifier` | Map ACID vs BASE boundaries |
| `data-sovereignty-scanner` | Identify source-of-truth ownership |

### 02 - Failure & Resilience (12 agents)
Analyze failure modes, recovery patterns, and resilience mechanisms.

| Agent | Purpose |
|-------|---------|
| `failure-mode-mapper` | Enumerate all failure points |
| `failure-domain-analyst` | Map failure domains and blast radius |
| `error-classification-auditor` | Validate error taxonomy |
| `retry-strategy-evaluator` | Analyze retry patterns |
| `circuit-breaker-detector` | Find missing circuit breakers |
| `cascade-failure-predictor` | Model failure amplification |
| `timeout-strategy-scanner` | Find timeout configurations |
| `backpressure-analyst` | Identify backpressure mechanisms |
| `recovery-pattern-evaluator` | Assess recovery strategies |
| `partial-failure-handler-scanner` | Find partial failure handling gaps |
| `degradation-mode-detector` | Identify graceful degradation |
| `blast-radius-calculator` | Calculate failure impact scope |

### 03 - Transaction & Write Patterns (8 agents)
Evaluate transaction boundaries, write patterns, and distributed transaction handling.

| Agent | Purpose |
|-------|---------|
| `transaction-boundary-mapper` | Map transaction scopes |
| `write-order-strategy-analyst` | Evaluate remote-first vs local-first |
| `two-phase-commit-detector` | Find 2PC usage and viability |
| `saga-pattern-evaluator` | Assess saga implementations |
| `outbox-pattern-scanner` | Evaluate outbox patterns |
| `event-sourcing-assessor` | Assess event sourcing fitness |
| `dual-write-detector` | Find dual-write anti-patterns |
| `atomic-operation-boundary-scanner` | Find atomicity gaps |

### 04 - Integration & Boundaries (7 agents)
Analyze system boundaries, integration patterns, and coupling.

| Agent | Purpose |
|-------|---------|
| `anti-corruption-layer-auditor` | Evaluate ACL quality |
| `system-boundary-mapper` | Map all integration points |
| `sync-vs-async-evaluator` | Assess sync/async pattern fitness |
| `api-contract-stability-scanner` | Find brittle API dependencies |
| `coupling-strength-analyzer` | Measure coupling strength |
| `integration-pattern-classifier` | Classify integration patterns |
| `external-dependency-risk-scorer` | Score dependency risk |

### 05 - Scalability & Performance (8 agents)
Predict bottlenecks, evaluate scaling readiness, and identify performance issues.

| Agent | Purpose |
|-------|---------|
| `bottleneck-predictor` | Identify likely bottlenecks |
| `scaling-pattern-evaluator` | Assess horizontal scaling readiness |
| `batching-opportunity-detector` | Find batching opportunities |
| `rate-limiting-scanner` | Find rate limiting gaps |
| `load-characteristic-profiler` | Profile load characteristics |
| `resource-exhaustion-predictor` | Predict resource exhaustion |
| `latency-amplification-detector` | Find N+1 and latency issues |
| `hot-spot-predictor` | Identify hot spots |

### 06 - Observability & Operations (6 agents)
Evaluate monitoring, debugging, and operational capabilities.

| Agent | Purpose |
|-------|---------|
| `observability-gap-finder` | Find missing metrics, logs, traces |
| `reconciliation-strategy-auditor` | Evaluate consistency verification |
| `drift-detection-evaluator` | Assess drift detection |
| `alerting-completeness-scanner` | Find missing alerts |
| `debugging-capability-assessor` | Evaluate debugging capability |
| `audit-trail-scanner` | Find audit logging gaps |

### 07 - UX & Human Factors (5 agents)
Analyze user experience around errors, retries, and operator cognitive load.

| Agent | Purpose |
|-------|---------|
| `user-feedback-loop-analyzer` | Evaluate feedback timing |
| `error-communication-auditor` | Assess error message quality |
| `cognitive-load-estimator` | Estimate operator burden |
| `human-in-loop-evaluator` | Assess human intervention points |
| `retry-ux-scanner` | Evaluate retry experience |

### 08 - Portability & Infrastructure (5 agents)
Assess deployment flexibility, lock-in risks, and cloud-native readiness.

| Agent | Purpose |
|-------|---------|
| `infrastructure-dependency-mapper` | Map infrastructure dependencies |
| `technology-lock-in-scanner` | Find lock-in risks |
| `deployment-flexibility-assessor` | Evaluate portability |
| `stateless-stateful-classifier` | Classify state handling |
| `cloud-native-readiness-scorer` | Score cloud-native readiness |

### 09 - Anti-Patterns (6 agents)
Detect common distributed systems anti-patterns.

| Agent | Purpose |
|-------|---------|
| `distributed-transaction-antipattern-detector` | Find 2PC misuse |
| `saga-antipattern-detector` | Find incomplete sagas |
| `microservice-antipattern-scanner` | Find distributed monolith |
| `shared-database-antipattern-detector` | Find inappropriate DB sharing |
| `synchronous-coupling-antipattern-scanner` | Find brittle sync chains |
| `god-service-detector` | Find oversized services |

### 10 - Synthesis & Reporting (6 agents)
Aggregate findings and generate actionable outputs.

| Agent | Purpose |
|-------|---------|
| `trade-off-matrix-generator` | Generate trade-off matrices |
| `pattern-catalog-mapper` | Map to known patterns |
| `implementation-checklist-generator` | Generate implementation checklists |
| `test-scenario-generator` | Generate failure test scenarios |
| `risk-score-aggregator` | Aggregate into risk scores |
| `architecture-decision-record-generator` | Generate ADRs from findings |

## Usage Model

```
                    ┌────────────────────────────────────────┐
                    │         Architecture Document          │
                    └─────────────────┬──────────────────────┘
                                      │
                    ┌─────────────────▼──────────────────────┐
                    │          Category Scanners              │
                    │  (Run in parallel per category)         │
                    └─────────────────┬──────────────────────┘
                                      │
    ┌───────────┬───────────┬────────┴────────┬───────────┬───────────┐
    ▼           ▼           ▼                 ▼           ▼           ▼
┌───────┐  ┌───────┐  ┌───────┐         ┌───────┐  ┌───────┐  ┌───────┐
│Cat 01 │  │Cat 02 │  │Cat 03 │   ...   │Cat 08 │  │Cat 09 │  │Cat 10 │
└───┬───┘  └───┬───┘  └───┬───┘         └───┬───┘  └───┬───┘  └───┬───┘
    │          │          │                 │          │          │
    └──────────┴──────────┴────────┬────────┴──────────┴──────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │       risk-score-aggregator          │
                    │   (Aggregate all findings)           │
                    └──────────────┬──────────────────────┘
                                   │
    ┌───────────────┬──────────────┼────────────────┬──────────────────┐
    ▼               ▼              ▼                ▼                  ▼
┌─────────┐  ┌───────────┐  ┌────────────┐  ┌───────────┐  ┌──────────────┐
│Trade-off│  │ Pattern   │  │   Test     │  │ Checklist │  │     ADR      │
│ Matrix  │  │ Catalog   │  │ Scenarios  │  │ Generator │  │  Generator   │
└─────────┘  └───────────┘  └────────────┘  └───────────┘  └──────────────┘
```

## Output Format

Each scanner produces structured markdown output with:
- **Findings table** - What was found
- **Risk scoring** - Severity classification
- **Recommendations** - Actionable next steps

## Derived From

This scanner suite was derived from distributed systems knowledge extracted from:
- `distributed-systems-patterns-option1.md` (source document)
- Enterprise Integration Patterns
- Microservices Patterns
- Site Reliability Engineering principles
- Cloud Design Patterns

## Implementation Priority

1. **Phase 1:** Core Scanners (Categories 1-3)
2. **Phase 2:** Deep Analysis (Categories 4-6)
3. **Phase 3:** Quality & UX (Categories 7-8)
4. **Phase 4:** Anti-Pattern & Synthesis (Categories 9-10)
