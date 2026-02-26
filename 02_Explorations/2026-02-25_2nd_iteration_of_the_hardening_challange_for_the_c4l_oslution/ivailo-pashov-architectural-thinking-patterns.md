# Ivailo Pashov's Architectural Thinking Patterns

**Extracted from**: Meeting transcript, February 25, 2026
**Purpose**: Meta-analysis of architectural decision-making approaches

---

## Core Thinking Patterns

### 1. Documentation-First Mindset
- Emphasizes creating comprehensive architectural documentation upfront (diagrams, processing logic, non-functional requirements)
- Uses documentation as a reference point for gap analysis: *"when in doubt, you can also come back to this quality non-functional requirements and try to figure out if there are any particular gaps"*
- Documentation serves as a shared foundation for discussions and decision-making

### 2. Pragmatic Over Theoretical Optimization
- Acknowledges theoretically optimal solutions but weighs them against practical implementation costs
- **Example**: CDC approach would be "most efficient architecture from the perspective of latency" but "would build additional cost for the implementation and it's probably not worth it"
- **Philosophy**: *"We can still address the requirements from the customer with this architecture"*
- Prioritizes delivering working solutions over pursuing theoretical perfection

### 3. Trade-off Triangle: Performance-Complexity-Cost
- Constantly evaluates architectural decisions across three dimensions
- Willing to accept slightly less optimal performance to reduce implementation complexity
- Considers operational costs (DevOps work, integration testing, infrastructure expenses)
- Makes explicit trade-off decisions transparent to stakeholders

### 4. Batch Processing & Recovery Strategy
- Advocates for checkpointing and batch-based processing to handle failures gracefully
- Uses configurable batch sizes as tuning parameters: *"we can play around with the batch size"*
- Prefers storing offsets at batch boundaries to balance performance with recovery granularity
- Designs for recoverability from the start, not as an afterthought

### 5. Dynamic Adaptation to Load Patterns
- Proposes adaptive triggering based on previous batch fill rates
- *"If we filled in the entire batch... then the probability that there are other records and we need to run immediately is very, very high"*
- Prefers systems that automatically adjust to spikes rather than static configurations
- Designs systems to be self-regulating based on actual load patterns

### 6. Infrastructure Philosophy: Match Pattern to Technology
- Questions cloud functions for constantly-running workloads: *"when we have these frequent triggers... it should be living, should be running all the time"*
- Considers cost, testability, and operational simplicity when choosing between serverless and containerized approaches
- Not dogmatic about technology choices—adapts to execution patterns
- **Key insight**: Infrastructure choice should follow workload characteristics, not trends

### 7. Testing as a Design Constraint
- Views testability as a primary architectural concern, not an afterthought
- Critical of business logic embedded in workflows: *"There's too much logic, business logic in this workflow. So it's hard to test"*
- Advocates for architecture that enables local testing and component integration tests
- Testing difficulty is a code smell indicating architectural problems

### 8. Error Handling Rigor
- Distinguishes between transient vs. permanent errors with high precision
- **Warning**: *"false positive for an error that should be transient, but we identify it as non transient... leads to discarding some data which should have been retried"*
- Emphasizes classification as "critical" to prevent data loss
- Understands that error handling strategy directly impacts data integrity

### 9. Fault Isolation & Resilience Patterns
- Separate subscriptions for different platforms to isolate faults
- Concurrent message processing for fault granularity
- Idempotent processing as fundamental requirement
- At-least-once delivery with checkpointing
- Designs systems where individual failures don't cascade

### 10. Decoupling Principle
- Consistently pushes for late binding and deferring decisions: *"If we can defer that it would be more decoupled"*
- Prefers moving validation closer to where it's actually needed
- Questions preliminary validation steps that create coupling
- Values independence between system components

### 11. Configuration Over Dynamic Complexity
- Views certain problems as "configuration issues" rather than runtime concerns
- Advocates for fail-fast with dead-letter queues for configuration problems
- *"We shouldn't dynamically handle... this is more of a configuration issue"*
- Separates infrastructure problems from application logic problems

### 12. Regression Risk Awareness
- Strong emphasis on test-first approach during refactoring: *"Start actually with the test first and then evolve both the tests and the implementation"*
- Warns that without tests *"there would be more bugs and then customer won't be happy"*
- Understands that reliability fixes can't introduce new regressions
- Views confidence in changes as a deliverable outcome

### 13. Operational Simplicity
- Questions whether multiple instances are needed: *"I don't think that this will be a performance issue... we shouldn't in theory have an issue even if there is a single instance"*
- But balances with operational resilience: requires "sufficient health checks" and immediate failover if single instance fails
- Prefers simple solutions until proven insufficient by data

### 14. Concurrency Control
- Careful attention to avoiding duplicate processing when instances overlap
- Considers distributed locking mechanisms for resource allocation
- Aware of uneven load distribution challenges
- Designs to prevent race conditions and data duplication

### 15. Integration Complexity Tax
- Explicitly accounts for DevOps effort, backend work, and integration testing when evaluating options
- Considers "the amount of services that we need to host" as a cost factor
- Includes load on downstream systems in architectural decisions
- Views integration work as a first-class architectural cost

### 16. Bottleneck Identification
- Distinguishes between what's actually slow: *"it's not really extracting the information that's the bottleneck, but rather publishing it"*
- Uses data (120 records/minute peak) to validate whether scale concerns are real
- Avoids premature optimization by identifying actual bottlenecks
- Data-driven rather than assumption-driven optimization

### 17. Test-Driven Development for Complex Changes
- For refactoring: *"requires deep understanding of the code base and launching some stub dependencies... within slightly modified configuration"*
- Views integration testing as primarily backend developer work, not pure QA
- Requires "sufficient confidence about the overall success"
- Testing strategy is part of the architectural design

### 18. Health & Monitoring as Design Elements
- Health checks should validate not just instance health but also "whether the extraction phase has been completed"
- Proactive about operational monitoring and failure detection
- Monitoring is designed into the system, not added later

---

## Meta-Patterns

### Holistic Thinking
Never evaluates a solution on a single dimension. Always considers multiple perspectives: cost, performance, maintainability, testability, operability.

### Risk-Aware
Constantly identifies failure modes and edge cases. Thinks through "what could go wrong" scenarios systematically.

### Evidence-Based
Uses data and past experience to validate concerns. Challenges assumptions with measurements (e.g., 120 records/minute).

### Pragmatic Perfectionism
Seeks good-enough solutions that satisfy requirements without over-engineering. Balances ideal solutions with practical constraints.

### Communication-Oriented
Documents thoroughly and explains trade-offs transparently. Makes implicit architectural knowledge explicit.

---

## Priority Hierarchy

The architectural style prioritizes:

1. **Reliability** - System must not lose data or fail silently
2. **Performance** - Must meet customer requirements (but not over-optimize)
3. **Simplicity** - Prefer simpler solutions when they meet requirements
4. **Cost** - Consider total cost including development, operations, and infrastructure

While maintaining **practical deliverability** - solutions must be implementable within constraints.

---

## Key Decision-Making Questions

When evaluating architectural options, Ivailo consistently asks:

1. **Can we address customer requirements with this approach?**
2. **What is the implementation cost vs. theoretical benefit?**
3. **How will this be tested and maintained?**
4. **What happens when it fails?**
5. **Is this configuration or code?**
6. **Can we simplify without sacrificing reliability?**
7. **Do we have data to support this concern?**
8. **What operational burden does this create?**

---

## Application to Other Projects

These patterns can be applied to any architectural challenge:

- **Start with non-functional requirements documented**
- **Make trade-offs explicit and transparent**
- **Design for testability and operability from the start**
- **Use data to validate performance concerns**
- **Question whether complexity is justified**
- **Always have a recovery strategy**
- **Separate configuration problems from code problems**
- **Match infrastructure to workload patterns**

---

**Document Status**: Analysis complete
**Source Material**: 1.5 hour meeting transcript, 77 minutes of discussion
**Confidence Level**: High - patterns consistently demonstrated throughout discussion
