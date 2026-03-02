# [ADR{NNN}] {Short Descriptive Title}

**Status:** {Draft | Closed}
**Date:** {YYYY-MM-DD}

## Context

{Describe the problem space and the forces at play. Explain the business or technical situation that motivates this decision. Include:}

- {The systems, components, or stakeholders involved and their relevant characteristics (tech stack, hosting, protocols, etc.)}
- {The constraints or boundary conditions (e.g. cloud provider, compliance, team capabilities)}

{List the key requirements that the decision must address:}

1. {Requirement 1}
2. {Requirement 2}
3. {Requirement N}

{State any overarching constraints or goals that shape the solution space.}

#### Options Considered

{For each requirement or group of related requirements, list the options that were evaluated:}

1. **{Requirement or concern}:**
    * **Option A: {Name}** - {Brief description}
    * **Option B: {Name}** - {Brief description}
    * **Option C: {Name}** - {Brief description}

## Decision

{For each requirement or group of related requirements, state the chosen option. If a decision is still pending, state so explicitly and explain why.}

1. **{Requirement or concern}:**
    * **Decision:** {Chosen option}
        * {Brief justification or note}

## Rationale

{For each option considered, explain why it was chosen or rejected. Provide technical reasoning, trade-off analysis, and any evidence (e.g. PoC results, benchmarks) that informed the decision.}

* **{Chosen Option}**: {Why it was selected -- strengths, fit with ecosystem, managed service benefits, etc.}
* **{Rejected Option A}**: {Why it was rejected -- overhead, complexity, risk, etc.}
* **{Rejected Option B}**: {Why it was rejected}

## Costs

{Provide a cost breakdown for the considered options. State assumptions clearly (data volumes, number of instances, pricing region, calculation period, etc.).}

**{Option 1} Costs:**
* **{Service/Resource}:**
    * **Monthly Cost**: ${amount}
    * **Annual Cost**: ${amount}
    * {Assumptions}

**{Option 2} Costs:**
* **{Service/Resource}:**
    * **Monthly Cost**: ${amount}
    * **Annual Cost**: ${amount}
    * {Assumptions}

## Consequences

{Describe the expected outcomes of the decision, both positive and negative.}

* **Positive**: {Benefits, alignment with strategy, scalability, maintainability, etc.}
* **Negative**: {Trade-offs, risks, added complexity, operational burden, etc.}

## Related ADRs

{Link to ADRs that are related to, superseded by, or revised by this decision.}

* [{ADR identifier and description}]({link})

## References

{Link to supporting materials: PoC results, documentation, design documents, external resources.}

* {Description}: [{Link text}]({URL})

**Conducted PoCs:**
* **{Work Item ID}**: {PoC title} ({Status})

**Results from PoCs:**
* {Summary of PoC result}

## Architecture Diagram

{Include or reference architecture diagrams that visualize the decided solution.}

![{Diagram description}]({path-to-image})
