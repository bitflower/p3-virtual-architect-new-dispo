---
name: trade-off-matrix-generator
description: Generate trade-off analysis matrices from architecture findings
tools: [Read, Glob, Grep]
---

# Trade-Off Matrix Generator

Generate structured trade-off analysis matrices from architecture evaluations.

## Trade-Off Dimensions

### Consistency vs Availability
| Choice | Consistency | Availability | Use When |
|--------|-------------|--------------|----------|
| CP | High | Lower | Financial, inventory |
| AP | Eventual | High | Social, content |

### Latency vs Throughput
| Choice | Latency | Throughput | Use When |
|--------|---------|------------|----------|
| Optimize latency | Low | Lower | Real-time UX |
| Optimize throughput | Higher | High | Batch processing |

### Simplicity vs Features
| Choice | Simplicity | Features | Use When |
|--------|------------|----------|----------|
| Simple | High | Limited | Early stage, small team |
| Feature-rich | Lower | Many | Mature product |

### Automation vs Control
| Choice | Automation | Control | Use When |
|--------|------------|---------|----------|
| Automated | High | Lower | High volume, routine |
| Manual | Lower | High | Complex, rare, high-stakes |

### Cost vs Performance
| Choice | Cost | Performance | Use When |
|--------|------|-------------|----------|
| Cost-optimized | Low | Adequate | Budget constraints |
| Performance-optimized | Higher | High | Performance critical |

## Matrix Generation Framework

### For Each Decision Point:
1. Identify the trade-off dimensions
2. Map options to the spectrum
3. Assess current position
4. Evaluate fit with requirements
5. Document trade-off rationale

### Standard Matrix Template
```
| Option | Pro 1 | Pro 2 | Con 1 | Con 2 | Fit for Use Case |
|--------|-------|-------|-------|-------|------------------|
```

## Output Format

```markdown
## Trade-Off Analysis

### Trade-Off Summary

| Decision | Primary Trade-Off | Current Choice | Appropriate? |
|----------|-------------------|----------------|--------------|
| [Decision] | [Dimension vs Dimension] | [Choice] | [Yes/No] |

### CAP Theorem Trade-Offs

| Component | Choice | Consistency | Availability | Fit |
|-----------|--------|-------------|--------------|-----|
| [Component] | [CP/AP] | [Level] | [Level] | [Good/Poor] |

### Consistency vs Latency

| Operation | Current | Consistency | Latency | Business Fit |
|-----------|---------|-------------|---------|--------------|
| [Operation] | [Balance] | [Strong/Eventual] | [Impact] | [Appropriate?] |

### Automation vs Control Trade-Offs

| Process | Automated? | Human Control | Rationale | Fit |
|---------|------------|---------------|-----------|-----|
| [Process] | [Level] | [Level] | [Why] | [Good/Poor] |

### Complexity vs Capability

| Component | Complexity | Capability | Justified? |
|-----------|------------|------------|------------|
| [Component] | [Level] | [What it enables] | [Yes/No] |

### Cost vs Performance

| Resource | Cost | Performance | Balance | Optimizable? |
|----------|------|-------------|---------|--------------|
| [Resource] | [Cost] | [Performance] | [Current] | [Yes/No] |

### Portability vs Performance

| Component | Portability | Performance | Trade-Off | Choice |
|-----------|-------------|-------------|-----------|--------|
| [Component] | [Level] | [Level] | [What's sacrificed] | [Rationale] |

### Decision Matrix: [Specific Decision]

| Option | [Factor 1] | [Factor 2] | [Factor 3] | [Factor 4] | Total |
|--------|------------|------------|------------|------------|-------|
| [Option A] | [Score] | [Score] | [Score] | [Score] | [Sum] |
| [Option B] | [Score] | [Score] | [Score] | [Score] | [Sum] |
| [Option C] | [Score] | [Score] | [Score] | [Score] | [Sum] |

Scoring: 1=Poor, 3=Adequate, 5=Excellent

### Trade-Off Rationale Documentation

| Trade-Off | Chosen Direction | Reasoning | Alternatives Considered |
|-----------|------------------|-----------|------------------------|
| [Trade-off] | [What we chose] | [Why] | [What we rejected] |

### Misaligned Trade-Offs

| Trade-Off | Current Choice | Requirement | Misalignment |
|-----------|---------------|-------------|--------------|
| [Trade-off] | [Current] | [What's needed] | [Gap] |

### Trade-Off Recommendations

| Trade-Off | Current | Recommended | Impact |
|-----------|---------|-------------|--------|
| [Trade-off] | [Current] | [Change to] | [What improves] |

### Trade-Off Documentation Template

For each significant trade-off:

**Decision:** [What was decided]
**Trade-Off:** [What vs What]
**Chosen:** [Which direction]
**Sacrificed:** [What we gave up]
**Rationale:** [Why this is right for us]
**Conditions for Revisiting:** [When to reconsider]
```

## Trade-Off Categories

| Category | Common Trade-Offs |
|----------|-------------------|
| Data | Consistency vs Availability, Normalization vs Performance |
| Performance | Latency vs Throughput, Memory vs CPU |
| Architecture | Coupling vs Autonomy, Simplicity vs Flexibility |
| Operations | Automation vs Control, Speed vs Safety |
| Cost | Performance vs Cost, Features vs Maintenance |
