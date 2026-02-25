# AI Agent Architecture for Architectural Reviews
**Specialist Team Approach**

**Date**: 2026-02-23
**Purpose**: Define multi-agent architecture for automated architectural reviews

---

## Architecture Overview

```
                        ┌─────────────────────────────────┐
                        │   Orchestrator Agent (Sonnet)   │
                        │  - Analyzes codebase structure  │
                        │  - Routes to specialists        │
                        │  - Aggregates findings          │
                        │  - Generates final report       │
                        └────────────┬────────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
        ┌───────────▼────────┐  ┌───▼───────┐  ┌────▼──────────┐
        │ Specialist Agents  │  │ Specialist│  │  Specialist   │
        │  (Run in Parallel) │  │  Agents   │  │    Agents     │
        └────────────────────┘  └───────────┘  └───────────────┘
```

---

## Specialist Agents

### 1. **Scalability Specialist** (Haiku)
**Focus**: Trigger mechanisms, concurrency, capacity planning

**Checks**:
- ✅ Time-based vs. event-driven triggers
- ✅ Fixed concurrency bounds
- ✅ Hard limits (max instances, timeouts)
- ✅ Parallelization levels
- ✅ Load distribution (hot partitions)

**Input**:
- Workflow files (YAML)
- Cloud Function configs
- Scheduler jobs
- Infrastructure-as-code

**Output**:
```json
{
  "findings": [
    {
      "severity": "high",
      "category": "scalability",
      "pattern": "time-based-triggers",
      "evidence": "devops/azure-pipelines.yml:205",
      "impact": "Cannot adapt to load changes during peak hours",
      "recommendation": "Migrate to event-driven Pub/Sub architecture"
    }
  ],
  "scalability_score": 1.6,
  "target_score": 4.5
}
```

---

### 2. **Resilience Specialist** (Haiku)
**Focus**: Error handling, retries, circuit breakers, fault isolation

**Checks**:
- ✅ Circuit breaker patterns
- ✅ Cascading failure risks
- ✅ Retry logic (exponential backoff?)
- ✅ Error classification (retriable vs. permanent)
- ✅ Dead-letter queues
- ✅ Workflow error propagation

**Input**:
- Retry logic code
- Exception handling patterns
- Workflow error handling
- External service calls

**Output**:
```json
{
  "findings": [
    {
      "severity": "critical",
      "category": "resilience",
      "pattern": "cascading-failures",
      "evidence": "workflow-upload.yml:69 - raise: ${e}",
      "impact": "Single depot failure terminates all parallel processing",
      "recommendation": "Use fault isolation pattern with shared failure tracking"
    },
    {
      "severity": "high",
      "category": "resilience",
      "pattern": "no-circuit-breaker",
      "evidence": "RetryUtils.cs:14-26 - only retry policy, no circuit breaker",
      "impact": "Wasted retries during downstream outages",
      "recommendation": "Add circuit breaker with 10-failure threshold"
    }
  ]
}
```

---

### 3. **Performance Specialist** (Sonnet)
**Focus**: Database queries, caching, I/O optimization

**Checks**:
- ✅ N+1 query patterns
- ✅ Missing indexes
- ✅ Inefficient loops
- ✅ Unnecessary serialization
- ✅ Lack of caching
- ✅ Timeout risks

**Input**:
- Database query code
- ORM configurations
- Service layer code
- External API calls

**Output**:
```json
{
  "findings": [
    {
      "severity": "high",
      "category": "performance",
      "pattern": "n-plus-1-queries",
      "evidence": "DigiLiSService.cs:56-95",
      "calculation": "1 + N queries (N=100 → 101 total queries)",
      "impact": "50× slower than optimal (batch retrieval)",
      "recommendation": "Implement GetDeliveryNoteContentsBatch() method"
    }
  ],
  "performance_multiplier": 0.02,
  "optimization_potential": "50×"
}
```

---

### 4. **State Management Specialist** (Haiku)
**Focus**: Checkpointing, offset tracking, idempotency

**Checks**:
- ✅ Persistent state tracking
- ✅ Resume capability
- ✅ Checkpoint granularity
- ✅ Idempotency
- ✅ Duplicate detection

**Input**:
- State management code
- Database schemas
- Request handling logic
- Recovery procedures

**Output**:
```json
{
  "findings": [
    {
      "severity": "critical",
      "category": "state-management",
      "pattern": "no-checkpointing",
      "evidence": "workflow-upload.yml:18-27 - calculates offset from scratch",
      "impact": "Data loss on timeout, no resume capability",
      "recommendation": "Add Firestore checkpoint table with per-depot offsets"
    }
  ],
  "has_checkpointing": false,
  "has_idempotency": false
}
```

---

### 5. **Observability Specialist** (Haiku)
**Focus**: Metrics, logging, tracing, alerting

**Checks**:
- ✅ RED metrics (Rate, Errors, Duration)
- ✅ Custom business metrics (lag, backlog)
- ✅ Structured logging
- ✅ Distributed tracing
- ✅ Alerting policies
- ✅ Dashboards

**Input**:
- Logging code
- Metric instrumentation
- Monitoring configs
- Alert definitions

**Output**:
```json
{
  "findings": [
    {
      "severity": "medium",
      "category": "observability",
      "pattern": "missing-lag-metrics",
      "evidence": "No custom metrics found for processing lag",
      "impact": "Cannot measure SLA compliance or detect backlog accumulation",
      "recommendation": "Instrument processing_lag_seconds metric"
    }
  ],
  "has_metrics": false,
  "has_tracing": false,
  "has_dashboards": false
}
```

---

### 6. **Cost Optimization Specialist** (Haiku)
**Focus**: Resource efficiency, waste detection

**Checks**:
- ✅ Over-provisioned resources
- ✅ Inefficient polling intervals
- ✅ Unnecessary data transfer
- ✅ Missed caching opportunities
- ✅ Zombie resources

**Input**:
- Infrastructure configs
- Cloud billing data
- Resource utilization metrics
- Invocation patterns

**Output**:
```json
{
  "findings": [
    {
      "severity": "low",
      "category": "cost",
      "pattern": "high-frequency-polling",
      "evidence": "Scheduler runs every minute (1440/day)",
      "current_cost": "$50/month",
      "optimization": "Reduce to every 2 minutes during off-peak hours",
      "savings": "$15/month (30% reduction)"
    }
  ],
  "total_monthly_cost": 50,
  "savings_potential": 15
}
```

---

### 7. **Security & Compliance Specialist** (Sonnet)
**Focus**: Secrets management, access control, data protection

**Checks**:
- ✅ Hardcoded secrets
- ✅ Proper secret management
- ✅ IAM roles/permissions
- ✅ Data encryption
- ✅ Audit logging
- ✅ Compliance requirements

**Input**:
- Secret management code
- IAM configurations
- Deployment scripts
- Data access patterns

**Output**:
```json
{
  "findings": [
    {
      "severity": "high",
      "category": "security",
      "pattern": "missing-encryption-at-rest",
      "evidence": "DigiLiS delivery notes stored in GCS without encryption",
      "compliance_impact": "GDPR/HIPAA violation risk",
      "recommendation": "Enable customer-managed encryption keys (CMEK)"
    }
  ]
}
```

---

## Orchestrator Agent (Sonnet)

**Responsibilities**:

1. **Codebase Analysis**
   - Identify technology stack
   - Map service architecture
   - Locate configuration files
   - Determine review scope

2. **Agent Routing**
   - Determine which specialists to invoke
   - Prepare specialized context per agent
   - Run agents in parallel

3. **Result Aggregation**
   - Collect specialist findings
   - Identify cross-cutting issues
   - Prioritize by severity
   - Calculate ROI scores

4. **Report Generation**
   - Synthesize findings into coherent narrative
   - Create phased roadmap
   - Generate decision matrices
   - Produce executive summary

**Orchestration Logic**:

```python
async def orchestrate_review(codebase_path: str) -> ArchitectureReport:
    # Phase 1: Analyze codebase structure
    structure = await analyze_codebase_structure(codebase_path)

    # Phase 2: Determine applicable specialists
    specialists = select_specialists(structure)
    # Example: If no database code found, skip Performance Specialist

    # Phase 3: Run specialists in parallel
    specialist_tasks = [
        run_specialist(ScalabilitySpecialist, codebase_path),
        run_specialist(ResilienceSpecialist, codebase_path),
        run_specialist(PerformanceSpecialist, codebase_path),
        run_specialist(StateManagementSpecialist, codebase_path),
        run_specialist(ObservabilitySpecialist, codebase_path),
        run_specialist(CostOptimizationSpecialist, codebase_path),
        run_specialist(SecuritySpecialist, codebase_path),
    ]

    specialist_results = await asyncio.gather(*specialist_tasks)

    # Phase 4: Aggregate findings
    all_findings = []
    for result in specialist_results:
        all_findings.extend(result.findings)

    # Phase 5: Identify cross-cutting issues
    cross_cutting_issues = detect_cross_cutting_issues(all_findings)
    # Example: "No checkpointing AND no circuit breaker = high data loss risk"

    # Phase 6: Generate proposals
    proposals = generate_proposals(all_findings, cross_cutting_issues)

    # Phase 7: Prioritize and create roadmap
    roadmap = create_phased_roadmap(proposals)

    # Phase 8: Generate final report
    report = generate_comprehensive_report(
        findings=all_findings,
        cross_cutting_issues=cross_cutting_issues,
        proposals=proposals,
        roadmap=roadmap
    )

    return report
```

---

## Model Selection Strategy

| Agent | Model | Rationale |
|-------|-------|-----------|
| **Orchestrator** | Sonnet 4.5 | Needs holistic understanding, complex reasoning |
| **Scalability** | Haiku | Pattern matching, config file analysis |
| **Resilience** | Haiku | Error handling detection is straightforward |
| **Performance** | Sonnet | Requires deep code analysis, query optimization |
| **State Management** | Haiku | Checkpoint detection is pattern-based |
| **Observability** | Haiku | Metric/logging detection is simple |
| **Cost Optimization** | Haiku | Resource analysis is formulaic |
| **Security** | Sonnet | Requires nuanced threat modeling |

**Cost Comparison**:

```
Generalist approach:
  - 1 Sonnet call with all rules
  - Tokens: ~50K input + 20K output
  - Cost: ~$1.00 per review

Specialist approach:
  - 1 Sonnet (orchestrator) + 2 Sonnet (specialists) + 5 Haiku
  - Tokens: ~30K input + 15K output (distributed)
  - Cost: ~$0.60 per review (40% savings)
  - Speed: 3-5× faster (parallel execution)
```

---

## Agent Prompt Templates

### Scalability Specialist Prompt

```markdown
You are a **Scalability Specialist** AI agent. Your job is to analyze system architecture
for scalability bottlenecks and capacity limitations.

**Your Expertise:**
- Trigger mechanisms (CRON vs. event-driven)
- Concurrency patterns
- Hard limits (max instances, timeouts)
- Load distribution
- Auto-scaling configurations

**Your Task:**
Analyze the provided codebase files and identify scalability issues.

**Files to Review:**
{file_list}

**Codebase Context:**
{codebase_summary}

**Output Format:**
Return a JSON object with this structure:
{
  "findings": [
    {
      "severity": "critical|high|medium|low",
      "category": "scalability",
      "pattern": "pattern-name",
      "evidence": "file:line",
      "impact": "description of impact",
      "recommendation": "concrete fix"
    }
  ],
  "scalability_score": 1-5,
  "summary": "2-3 sentence summary"
}

**Anti-Patterns to Detect:**
1. Time-based triggers for load-dependent work
2. Fixed concurrency bounds
3. Static partition keys
4. Hard-coded limits without auto-scaling
5. No backlog visibility

**Detection Method:**
- Search for CRON expressions, Cloud Scheduler configs
- Check max instances, timeout settings
- Analyze parallelization patterns
- Look for static configuration files

**Example Finding:**
{
  "severity": "high",
  "category": "scalability",
  "pattern": "time-based-triggers",
  "evidence": "devops/workflow.yml:10",
  "impact": "Cannot adapt to 5× peak load during seasonal spikes",
  "recommendation": "Migrate to Pub/Sub with auto-scaling workers"
}
```

### Performance Specialist Prompt

```markdown
You are a **Performance Specialist** AI agent. Your job is to identify performance
bottlenecks in database queries, I/O operations, and algorithmic complexity.

**Your Expertise:**
- N+1 query detection
- Database optimization
- Caching strategies
- I/O bottlenecks
- Algorithm complexity analysis

**Your Task:**
Analyze code for performance anti-patterns and calculate optimization potential.

**Files to Review:**
{file_list}

**Output Format:**
{
  "findings": [...],
  "performance_multiplier": 0.02,  // Current is 2% of optimal
  "optimization_potential": "50×"  // Could be 50× faster
}

**Anti-Patterns to Detect:**
1. N+1 queries (foreach with await inside)
2. Missing database indexes
3. Unnecessary loops
4. Blocking I/O in async code
5. No caching for repeated queries

**Detection Method:**
- Search for: foreach.*await.*Get, for.*query
- Check Entity Framework configurations
- Analyze repository patterns
- Look for caching middleware

**Calculation Example:**
If N+1 pattern found with N=100:
- Current: 1 + 100 = 101 queries
- Optimal: 2 queries (batch)
- Performance multiplier: 2/101 = 0.02 (2% of optimal)
- Optimization potential: 50×
```

---

## Cross-Cutting Issue Detection

**Orchestrator's Role:**

After collecting specialist findings, detect combinations that amplify risk:

```python
def detect_cross_cutting_issues(findings: List[Finding]) -> List[CrossCuttingIssue]:
    issues = []

    # Pattern 1: No checkpointing + No circuit breaker
    has_no_checkpointing = any(f.pattern == "no-checkpointing" for f in findings)
    has_no_circuit_breaker = any(f.pattern == "no-circuit-breaker" for f in findings)

    if has_no_checkpointing and has_no_circuit_breaker:
        issues.append(CrossCuttingIssue(
            severity="critical",
            title="Compounding Data Loss Risk",
            description="System lacks both checkpointing AND circuit breaker. "
                        "During downstream outages, retries will timeout without "
                        "saving progress, resulting in total data loss.",
            affected_areas=["state-management", "resilience"],
            amplification_factor="10×",
            recommendation="Implement checkpointing first (enables retry), "
                           "then add circuit breaker (prevents wasted retries)"
        ))

    # Pattern 2: High frequency + No observability
    high_frequency_trigger = any(f.pattern == "high-frequency-polling" for f in findings)
    no_metrics = any(f.pattern == "missing-metrics" for f in findings)

    if high_frequency_trigger and no_metrics:
        issues.append(CrossCuttingIssue(
            severity="high",
            title="Cost Blind Spot",
            description="System runs frequently but lacks cost metrics. "
                        "Cannot detect cost overruns or optimize intervals.",
            affected_areas=["cost", "observability"],
            recommendation="Add invocation cost metrics + alerting before "
                           "increasing frequency"
        ))

    return issues
```

---

## Agent Communication Protocol

**Message Format:**

```json
{
  "agent_id": "scalability-specialist-001",
  "agent_type": "scalability",
  "status": "completed",
  "execution_time_ms": 4500,
  "model_used": "claude-3-5-haiku",
  "tokens_used": 15000,
  "findings_count": 3,
  "findings": [...],
  "metadata": {
    "files_analyzed": 12,
    "patterns_checked": 5,
    "confidence_score": 0.92
  }
}
```

---

## Incremental Review Mode

**Use Case**: Don't re-analyze entire codebase on every PR.

**Approach**: Git diff-based incremental review

```python
async def incremental_review(base_commit: str, head_commit: str):
    # Get changed files
    changed_files = git_diff_files(base_commit, head_commit)

    # Determine affected specialists
    affected_specialists = []

    if any(f.endswith('.yml') for f in changed_files):
        affected_specialists.append(ScalabilitySpecialist)

    if any('Service.cs' in f for f in changed_files):
        affected_specialists.append(PerformanceSpecialist)
        affected_specialists.append(ResilienceSpecialist)

    # Run only affected specialists
    results = await run_specialists(affected_specialists, changed_files)

    # Compare with baseline
    new_issues = compare_with_baseline(results, baseline_report)

    return IncrementalReport(new_issues=new_issues)
```

---

## Implementation Recommendation

### Phase 1: Build Orchestrator (Week 1)
- Codebase structure analyzer
- Specialist routing logic
- Result aggregation framework

### Phase 2: Implement Core Specialists (Week 2-3)
- Scalability (most impactful)
- Resilience (critical for production)
- Performance (high ROI)

### Phase 3: Add Supporting Specialists (Week 4)
- State Management
- Observability
- Cost Optimization

### Phase 4: Advanced Features (Week 5+)
- Cross-cutting issue detection
- Incremental review mode
- Custom rule definitions

---

## Comparison: Generalist vs. Specialist

| Aspect | Single Generalist | Specialist Team |
|--------|-------------------|-----------------|
| **Speed** | Slow (sequential) | Fast (5× faster, parallel) |
| **Cost** | $1.00/review | $0.60/review (40% savings) |
| **Accuracy** | Good (holistic) | Excellent (deep expertise) |
| **Maintenance** | Hard (one big prompt) | Easy (update individual specialists) |
| **Extensibility** | Hard (add more rules) | Easy (add new specialist) |
| **Focus** | May miss details | Deep dive per domain |
| **Cross-cutting** | Natural | Requires orchestrator |
| **Model Optimization** | One size fits all | Right model per task |

---

## Recommendation: **Specialist Team with Orchestrator**

**Why?**
1. ✅ **5× faster** (parallel execution)
2. ✅ **40% cheaper** (Haiku for simple tasks)
3. ✅ **Higher quality** (focused expertise)
4. ✅ **Easier to maintain** (update one specialist)
5. ✅ **Better extensibility** (add specialists as needed)

**Trade-off**: Requires orchestration layer (worth the complexity)

---

## Next Steps

1. **Prototype Orchestrator** - Build basic routing and aggregation
2. **Implement Top 3 Specialists** - Scalability, Resilience, Performance
3. **Test on Cloud4Log** - Validate accuracy vs. manual analysis
4. **Iterate** - Add remaining specialists based on value
5. **Productionize** - CI/CD integration, incremental mode

---

**Document Version**: 1.0
**Author**: Architecture Team
**Status**: Recommendation - Pending Approval
