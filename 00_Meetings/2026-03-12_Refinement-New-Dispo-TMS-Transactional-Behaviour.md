
## Besprechungsnotizen

Outbox Pattern Concept and Implementation: 

Ivailo presented the high-level concept and technical flow of the outbox pattern for synchronizing data between the new Dispo system and TMS, with Matthias, Yosif, Boyan, and Vesela contributing to the discussion on implementation details, error handling, and user experience implications.
	Technical Flow Overview: Ivailo explained the overall flow, describing how incoming HTTP modification requests are processed by the new Dispo front end, with changes reflected in both the new Dispo database and external storages like TMS. The outbox pattern is used to ensure reliable coordination, with local transactions storing messages in an outbox table and handlers registered to process these messages. Synchronization can occur either synchronously or via a background process, ensuring eventual consistency.
	Synchronous and Asynchronous Operations: Ivailo detailed the optimistic synchronous flow, where operations appear atomic and immediate to the end user if all systems are available, and the pessimistic asynchronous flow, where a background process handles retries if immediate synchronization fails. Timeout adjustments and user interface considerations were noted to ensure a reasonable user experience.
	Error Handling and User Notification: The team discussed how to handle errors, including immediate failures (e.g., TMS bridge or database outages), recoverable versus non-recoverable errors, and the need to classify errors for appropriate handling. Ivailo and Yosif debated whether to notify users of failures, roll back changes, or allow users to retry operations, with the consensus that requirements from product ownership are needed to finalize the approach.
	Business Requirements and User Experience: Ivailo emphasized that the final behavior, especially regarding user notifications and handling of long-running retries, depends on business requirements. The team agreed that some scenarios may require user-driven retries, while others could be handled automatically, and that product ownership input is necessary to determine the preferred approach.

Edge Cases and Failure Scenarios: 

Matthias, Yosif, and Ivailo systematically identified and discussed various edge cases and failure scenarios, including database and TMS bridge outages, network issues, and the implications for data consistency and recovery.
	Classification of Failure Scenarios: Matthias led the group in enumerating possible outcomes: success or failure at the TMS bridge, success or failure at the new Dispo database, and combinations thereof. The team clarified that the outbox pattern is primarily needed to handle cases where the local database is unavailable after a successful TMS operation, ensuring data can be realigned later.
	Handling Lost Responses and Inconsistent State: The team discussed scenarios where the TMS operation succeeds but the response is lost due to network issues, leading to potential inconsistencies. Ivailo and Yosif agreed that while such cases are rare, they must be accounted for, and the outbox pattern or manual user-driven retries could be used to resolve inconsistencies.
	Manual Versus Automated Recovery: Options for recovery were debated, including automated retries via the outbox pattern and manual user-driven retries. The team considered the trade-offs between implementation complexity, reliability, and user experience, with Matthias suggesting that documenting all failure scenarios is essential for any chosen approach.

Alternative Approaches: Event-Driven and Manual Solutions: 

Yosif and Ivailo explored alternative strategies to the outbox pattern, such as event-driven architectures using cloud tasks or Pub/Sub, and manual user-driven recovery, with input from Matthias and Boyan on feasibility and alignment with project timelines.
	Event-Driven Architecture Discussion: Yosif proposed considering event-driven strategies, such as using cloud tasks or Pub/Sub for asynchronous processing. Ivailo explained the limitations of these approaches, particularly the lack of atomic guarantees when synchronizing local and remote changes, and emphasized that the outbox pattern remains the standard for ensuring consistency across systems.
	Manual User-Driven Recovery: The team discussed the possibility of shifting responsibility for retrying failed operations to the end user, allowing users to manually trigger retries and realign data. Ivailo noted that this approach is less complex and could be implemented more quickly, but may not provide the same reliability as automated solutions.
	Short-Term Versus Long-Term Solutions: Matthias highlighted the need to balance short-term delivery goals (e.g., the June release) with long-term architectural improvements. The team agreed that a simpler, manual solution could be implemented for the immediate deadline, with more robust event-driven or outbox-based solutions considered for future refactoring.

Next Steps and Decision-Making: 

Matthias summarized the need for a timely decision on which approach to implement, proposing that the team reflect on error scenarios and prepare estimates for both manual and outbox-based solutions, with further discussions planned to finalize the direction.
	Action Items and Timeline: Matthias requested that all participants review and document possible error scenarios to build a backlog of failure cases. The team should prepare estimates for implementing both the manual and outbox pattern solutions, with the goal of making a decision soon due to the tight timeline for the June release.

## Folgeaufgaben

Error Scenario Documentation: 
Document all possible error and failure scenarios related to the discussed integration flows to support decision-making and backlog creation. (Matthias, the team)
Effort Estimation for Implementation Options: 
Prepare effort estimates for both the manual retry flow and the outbox pattern implementation to inform client discussions and decision-making. (Matthias)
Decision on Outbox Pattern Implementation: 
Reflect on the discussed error scenarios and provide feedback or counterarguments to reach a consensus on whether to implement the outbox pattern for the June release. (the team)

## Chat

The 3 error scenarios:

1. Success from Bridge (including TMS database) => Fail New Dispo DB (e.g. infrastructure outage on New Dispo / GCP side)
2. 400/500 From Bridge => "Early Fail" (the easiest to cover)
3. Request to Bridge successful => TMS SQL executes => Connection breaks => we don't get a response but TMS Database is already updated leading to out of sync data situation of New Dispo and TMS