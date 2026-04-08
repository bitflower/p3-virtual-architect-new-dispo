---
name: risk-score-aggregator
description: Aggregate findings from all scanners into unified risk scores and priorities
tools: [Read, Glob, Grep]
---

# Risk Score Aggregator

Aggregate findings from all distributed systems scanners into unified risk assessment.

## Risk Scoring Framework

### Severity Levels

| Level | Score | Description |
|-------|-------|-------------|
| CRITICAL | 10 | Immediate action required, system at risk |
| HIGH | 7 | Significant risk, address soon |
| MEDIUM | 4 | Moderate risk, plan to address |
| LOW | 2 | Minor risk, consider addressing |
| POSITIVE | 0 | Good practice identified |

### Category Weights

| Category | Weight | Rationale |
|----------|--------|-----------|
| Consistency & Data | 1.2 | Data integrity critical |
| Failure & Resilience | 1.3 | Direct availability impact |
| Transaction & Write | 1.2 | Data consistency risk |
| Integration & Boundary | 1.0 | Coupling concerns |
| Scalability & Performance | 1.0 | Growth concerns |
| Observability & Operations | 0.9 | Operational risk |
| UX & Human Factors | 0.8 | User impact |
| Portability & Infrastructure | 0.7 | Strategic concern |
| Anti-Patterns | 1.1 | Accumulated debt |

### Aggregate Risk Score
```
Total Risk = Σ (Finding Severity × Category Weight)
Normalized = Total Risk / Max Possible Score × 100
```

## Risk Categories

### Immediate Risk
Issues that could cause problems now:
- No error handling on critical paths
- Missing idempotency on financial ops
- No circuit breakers on external calls

### Latent Risk
Issues that will cause problems under stress:
- Missing backpressure
- Unbounded queues
- Inadequate timeout chains

### Technical Debt Risk
Issues that accumulate cost over time:
- Tight coupling
- Missing observability
- Poor error messages

### Strategic Risk
Issues affecting long-term viability:
- Vendor lock-in
- Scalability blockers
- Portability limitations

## Output Format

```markdown
## Risk Assessment Summary

### Overall Risk Score: [X/100]

| Risk Level | Finding Count | Weighted Score |
|------------|---------------|----------------|
| CRITICAL | [N] | [Score] |
| HIGH | [N] | [Score] |
| MEDIUM | [N] | [Score] |
| LOW | [N] | [Score] |
| POSITIVE | [N] | (reducing) |

### Risk by Category

| Category | Findings | Critical | High | Med | Low | Score |
|----------|----------|----------|------|-----|-----|-------|
| Consistency | [N] | [N] | [N] | [N] | [N] | [Score] |
| Resilience | [N] | [N] | [N] | [N] | [N] | [Score] |
| Transaction | [N] | [N] | [N] | [N] | [N] | [Score] |
| Integration | [N] | [N] | [N] | [N] | [N] | [Score] |
| Scalability | [N] | [N] | [N] | [N] | [N] | [Score] |
| Observability | [N] | [N] | [N] | [N] | [N] | [Score] |
| UX | [N] | [N] | [N] | [N] | [N] | [Score] |
| Portability | [N] | [N] | [N] | [N] | [N] | [Score] |
| Anti-Patterns | [N] | [N] | [N] | [N] | [N] | [Score] |

### Risk Trend
[Compare to previous assessment if available]

---

## Critical Findings (Immediate Action Required)

| ID | Finding | Category | Source Scanner | Impact |
|----|---------|----------|----------------|--------|
| C1 | [Finding] | [Category] | [Scanner] | [Impact] |
| C2 | [Finding] | [Category] | [Scanner] | [Impact] |

### C1: [Finding Title]

**Description:** [What was found]
**Impact:** [What could happen]
**Recommendation:** [How to fix]
**Effort:** [Estimate]

---

## High Priority Findings

| ID | Finding | Category | Source Scanner | Impact |
|----|---------|----------|----------------|--------|
| H1 | [Finding] | [Category] | [Scanner] | [Impact] |

---

## Medium Priority Findings

[Grouped summary with links to details]

---

## Low Priority Findings

[Grouped summary]

---

## Positive Findings (Good Practices)

| Finding | Category | Keep Doing |
|---------|----------|------------|
| [Finding] | [Category] | [Recommendation] |

---

## Prioritized Action Plan

### Immediate (This Week)
1. [ ] [Action] - Addresses: C1, C2
2. [ ] [Action] - Addresses: C3

### Short Term (This Month)
1. [ ] [Action] - Addresses: H1, H2
2. [ ] [Action] - Addresses: H3, H4

### Medium Term (This Quarter)
1. [ ] [Action] - Addresses: M1-M5
2. [ ] [Action] - Addresses: M6-M10

### Long Term (Backlog)
1. [ ] [Action] - Addresses: L1-L10

---

## Risk Reduction Projection

| Timeframe | Actions | Risk Reduction | Projected Score |
|-----------|---------|----------------|-----------------|
| After immediate | [Actions] | -[X] points | [Score] |
| After short term | [Actions] | -[X] points | [Score] |
| After medium term | [Actions] | -[X] points | [Score] |

---

## Scan Coverage

| Scanner | Ran? | Findings | Notes |
|---------|------|----------|-------|
| [Scanner] | [Yes/No] | [Count] | [Notes] |

---

## Methodology Notes

- Scan Date: [Date]
- Scanners Used: [List]
- Scope: [What was scanned]
- Limitations: [What wasn't covered]
```

## Aggregation Process

1. **Collect** findings from all scanner outputs
2. **Classify** each finding by severity
3. **Weight** by category
4. **Calculate** aggregate scores
5. **Prioritize** by impact and effort
6. **Generate** action plan
