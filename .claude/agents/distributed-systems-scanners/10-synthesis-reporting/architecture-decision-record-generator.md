---
name: architecture-decision-record-generator
description: Generate ADRs from architecture analysis findings and decisions
tools: [Read, Glob, Grep]
---

# Architecture Decision Record Generator

Generate ADRs from architecture analysis findings and decisions.

## ADR Template

```markdown
# ADR-[NUMBER]: [TITLE]

## Status
[Proposed | Accepted | Deprecated | Superseded]

## Context
[What is the issue we're seeing that motivates this decision?]

## Decision
[What is the change we're proposing/making?]

## Consequences

### Positive
- [Benefit 1]
- [Benefit 2]

### Negative
- [Drawback 1]
- [Drawback 2]

### Neutral
- [Side effect 1]

## Alternatives Considered
[What other options were evaluated?]

## References
- [Link to analysis]
- [Link to discussion]
```

## ADR Categories

### From Risk Findings
Convert critical/high findings to ADRs:
- Document the problem
- Record the decision
- Track consequences

### From Pattern Choices
Document pattern adoptions:
- Why this pattern?
- What alternatives?
- What trade-offs?

### From Trade-offs
Document significant trade-offs:
- What was chosen
- What was sacrificed
- When to revisit

### From Anti-Pattern Fixes
Document anti-pattern remediation:
- What was wrong
- What we're doing
- Expected outcomes

## Output Format

```markdown
## Generated Architecture Decision Records

### ADR Summary

| ADR | Title | Status | Category | Priority |
|-----|-------|--------|----------|----------|
| ADR-001 | [Title] | Proposed | [Category] | [P0-P3] |
| ADR-002 | [Title] | Proposed | [Category] | [P0-P3] |

---

# ADR-001: [Title Based on Finding]

## Status
Proposed

## Context

[Generated from scanner findings]

The architecture analysis identified:
- **Finding:** [What was found]
- **Risk Level:** [CRITICAL/HIGH/MEDIUM]
- **Scanner:** [Which scanner found it]

This impacts:
- [Impact 1]
- [Impact 2]

## Decision

We will [decision based on recommendation]:

[Specific actions to take]

### Implementation Approach
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Consequences

### Positive
- Addresses [risk/finding]
- Improves [quality attribute]
- Enables [capability]

### Negative
- Requires [effort/change]
- May impact [area]
- Increases [complexity/cost]

### Neutral
- Changes [behavior]

## Alternatives Considered

### Alternative 1: [Name]
- **Description:** [What]
- **Why Not:** [Reason rejected]

### Alternative 2: [Name]
- **Description:** [What]
- **Why Not:** [Reason rejected]

## References
- Scanner Finding: [Reference]
- Related ADRs: [ADR-XXX]

---

# ADR-002: [Pattern Adoption]

## Status
Proposed

## Context

To address [need identified in analysis], we need to adopt a consistent pattern for [area].

Current state:
- [Current approach]
- [Problems with it]

## Decision

We will adopt the **[Pattern Name]** pattern:

[Pattern description and our specific implementation]

## Consequences

### Positive
- [Pattern benefit 1]
- [Pattern benefit 2]

### Negative
- [Pattern drawback 1]
- Implementation effort: [Estimate]

## Alternatives Considered

### [Alternative Pattern]
- **Why Not:** [Reason]

## References
- Pattern documentation: [Link]
- Industry examples: [Examples]

---

# ADR-003: [Trade-off Decision]

## Status
Proposed

## Context

The architecture faces a trade-off between:
- **[Option A]:** [Description]
- **[Option B]:** [Description]

Based on [requirements/constraints], we must choose.

## Decision

We choose **[Chosen option]** because:
- [Reason 1]
- [Reason 2]

This means accepting:
- [Consequence 1]
- [Consequence 2]

## Consequences

### What We Gain
- [Benefit]

### What We Sacrifice
- [Drawback]

### Conditions for Revisiting
- If [condition], reconsider this decision
- Review in [timeframe]

## Alternatives Considered

### [Not chosen option]
- **Trade-off:** [What we'd gain/lose]
- **Why Not:** [Reason]

---

## ADR Backlog

Generated but not yet reviewed:

| ADR | Title | Source Finding | Review By |
|-----|-------|---------------|-----------|
| ADR-XXX | [Title] | [Finding] | [Date] |
```

## ADR Generation Rules

1. **CRITICAL Finding** → Generate ADR immediately
2. **HIGH Finding** → Generate ADR for review
3. **Pattern Adoption** → Document as ADR
4. **Significant Trade-off** → Document reasoning
5. **Anti-Pattern Fix** → Document before/after
6. **Major Change** → Always ADR

## ADR Lifecycle

```
Scanner Finding → ADR Proposed → Review → Accepted → Implementation → Verify
                     ↓
            (Rejected with rationale)
```
