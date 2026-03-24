Generiert von KI. Achten Sie darauf, die Genauigkeit zu überprüfen.
Besprechungsnotizen:
T Shipments and Conflict Resolution: 
Maximilian led an in-depth discussion with the team on the display, aggregation, and conflict resolution of T shipments, including UX requirements, edge cases, and the need for clear visualisation and manual resolution options for dispatchers.
	Aggregating Shipment Information: The team discussed the need to display aggregated A and T shipment information across shipment, transport order, and connection levels, ensuring that no information is lost regarding which T shipment was announced, its timing, and its linkage to A shipments.
	Conflict Visualisation and Manual Resolution: Maximilian described the UX requirement for marking unplanned A shipments with conflicts in orange, allowing dispatchers to filter and view only relevant transport orders, and providing a drag-and-drop interface for manual conflict resolution.
	Edge Case Handling and Questions: The group identified multiple edge cases, such as T shipments belonging to multiple A shipments and the implications of removing references, and agreed to document these scenarios and seek clarification from stakeholders.
	Automated Versus Manual Handling: It was agreed that only the most complex conflict cases would require manual resolution, while simpler cases would be handled automatically, and unresolved cases would be visualised for support intervention.
Event Counter and Change Tracking Implementation: 
Maximilian and the team explored technical and business requirements for implementing an event counter to track changes in lots, legs, and transport orders, debating filter application, performance considerations, and user expectations.
	User Requirements and Filtering: The team clarified that users expect the event counter to reflect changes according to the current filter and pagination, regardless of which page is visible, and that the counter should update at defined intervals.
	Technical Approaches: Pull vs Push: A consensus was reached to use a pull mechanism for change detection, as it allows user-specific tracking without maintaining state for each user, and to use timestamps or IDs to identify changes since the last refresh.
	Performance and Change Definition: The group discussed the need to avoid performance issues by limiting queries to filtered data and debated what constitutes a 'change', ultimately deciding to count any modification to a transport order as a change.
	Session Storage and User Context: It was agreed that the last refresh timestamp or relevant IDs should be stored per session, and that changes initiated by the user should not be counted as new changes for that user.
	Outstanding Questions for Stakeholders: Several open questions were identified, such as whether to reset pagination on refresh and how to handle address-based filtering, to be clarified with Patrick and other stakeholders.
Oracle Database Integration and Testing Strategy: 
Maximilian, Matthias, and the team reviewed the status and next steps for integrating Oracle databases, including CDC tool evaluation, test planning, and the need for harmonisation between Oracle and Postgres environments.
	CDC Tool Evaluation: The team is running two proofs of concept (POCs) for CDC: one using Stream (already in use for full replication) and another using Data Stream with the Oracle connector, with the final decision pending a holistic evaluation.
	Test Plan and Regression Coverage: It was agreed that a comprehensive test plan covering all scenarios and combinations is required for both Oracle and Postgres, with automated and manual tests to ensure regression confidence before go-live.
	Harmonisation and Transformation Logic: The group discussed the need to harmonise event formats between Oracle and Postgres, potentially using a cloud function as an anti-corruption layer to ensure the application receives unified events regardless of the CDC source.
	Dependency on External Teams: The team acknowledged dependencies on the TMS team and database administrators for migration, script execution, and CDC configuration, identifying these as key risks for the project timeline.
Transactional Behaviour and Resilience Patterns: 
Matthias and Maximilian led a technical discussion on ensuring transactional integrity and resilience, considering patterns such as fail-fast, rollback, and minimal outbox implementations to handle distributed system failures.
	Saga and Rollback Considerations: The team debated the complexity of implementing a full Saga pattern, agreeing instead to pursue a minimal approach where failed operations are rolled back if possible, and users are notified to retry if inconsistencies occur.
	Fail-Fast and Transactional Checks: A fail-fast approach was proposed, where a transaction is opened before attempting remote operations, ensuring that failures due to database unavailability are detected early and no inconsistent state is introduced.
	User-Driven Retry and Logging: It was agreed that users should be able to retry failed operations, with failures logged for troubleshooting, and that more complex solutions such as outbox tables could be considered if needed.
	Minimal Implementation Commitment: The group confirmed consensus to implement the minimal necessary resilience features, deferring more advanced patterns unless required by future scenarios or stakeholder feedback.
CDC Error Handling, Ordering, and Performance: 
The team examined current CDC error handling, event ordering, and performance issues, identifying the need for correct error codes, event ordering guarantees, and investigation into delays and proxy configurations.
	Error Response and Polling Mechanism: The backend was updated to return appropriate error codes instead of always acknowledging events, and the system now uses a polling mechanism to control event processing.
	Event Ordering and Concurrency: Concerns were raised about event ordering, especially with PubSub not guaranteeing order, and the team discussed using partition keys or timestamps to ensure only the latest event is applied.
	Performance Delays and Proxy Investigation: The group noted significant delays (up to five minutes) in event propagation, traced to batching and possible proxy configurations, and agreed to test direct database connections to improve reliability.
	Batch Recovery for Outages: A batch layer was proposed to recover missed changes after outages, using high watermark timestamps to backfill data, with manual intervention as a fallback.
Route Calculation and User Feedback Improvements: 
Maximilian and the team discussed improvements to route calculation logic, mandatory fixed start times, and enhanced user feedback during transport order creation, including UI adjustments for better visibility.
	Mandatory Fixed Start Times: The team agreed that every first tour point must have a fixed start time for route calculation, with the UI enforcing this requirement and highlighting missing values.
	Handling Tour Point Changes: Scenarios where the first tour point changes or loses its fixed time were addressed, with the system marking such cases and preventing recalculation until corrected.
	User Feedback During Creation: The group explored ways to provide real-time feedback to users during transport order creation, such as loading indicators and placeholder cards, to improve transparency and usability.
	UI Optimisation: Suggestions were made to reduce white space and optimise the planning page layout, with plans to review and implement incremental UI improvements.
Customer Communication and PDF Generation: 
The team outlined requirements for generating customer communication PDFs from CSV data, discussed library options and costs, and agreed on a minimal, cost-effective implementation approach.
	PDF Creation from CSV: The team will generate PDFs for customer communication using data from CSV files, ensuring the output contains all required details, and will consider both free and paid libraries based on cost and ease of implementation.
Backend Adjustments and Client Whitelisting: 
Maximilian described the implementation of a static CSV-based client whitelist to control which customers appear in planning and communication features, with minimal admin interface and simple update mechanisms.
	Static Whitelist File: A CSV file will be used to whitelist clients for planning and EDI communication, with updates managed by developers or DevOps without requiring full redeployment.
	Filtering Logic and Edge Cases: The team discussed filtering lots and legs based on the whitelist, handling potential mixed-client lots, and agreed to investigate grouping and filtering logic to avoid user confusion.
Project Risks, Dependencies, and Planning: 
The team reviewed outstanding risks, dependencies on external teams, and the need for detailed requirements and answers from stakeholders, planning to document open questions and adjust sprint structure for better refinement.
	External Dependencies and Risks: Key risks were identified around Oracle migration, CDC configuration, and reliance on the TMS team for database changes, with the team noting these could impact the go-live timeline.
	Requirement Gathering and Stakeholder Communication: The group agreed to document all open questions and scenarios, set deadlines for stakeholder responses, and consider direct sessions with Patrick to accelerate clarification.
	Sprint Structure and Refinement: A decision was made to shorten sprints to two weeks and, if necessary, dedicate time to pure refinement sessions to ensure a well-defined backlog.
	Testing and QA Capacity: Concerns were raised about manual testing workload, onboarding new QA resources, and the need to increase automated test coverage, with suggestions to involve developers in testing and leverage AI tools for test generation.
Folgeaufgaben:
T Shipments Edge Cases Clarification: 
Write down all edge case scenarios for T shipments and request detailed answers from Patrick to clarify expected behaviour in each case. (Maximilian)
Resilience and Transactional Behaviour Refinement: 
Organise a dedicated session to refine the resilience and transactional behaviour approach, ensuring all scenarios and minimal implementation are agreed upon by the team. (Maximilian, the team)
CDC Performance and Proxy Investigation: 
Investigate the impact of the current proxy setup on CDC performance and attempt a direct database connection to assess if delays are reduced. (Maximilian)
Oracle Migration and Testing Plan: 
Coordinate with Joachim to confirm the Oracle database migration is complete and ensure a comprehensive end-to-end test plan is in place before go-live. (Maximilian)
Customer Communication PDF Library Cost Assessment: 
Investigate available PDF generation libraries, including their costs, and inform Maximilian if a paid solution is required for customer communication PDFs. (the team)
UI Improvement Suggestions Review: 
Schedule a call with Boyan and Coco to review and discuss the proposed UI improvement suggestions before communicating them further. (Maximilian, Boyan, Coco)
Definition of 'Change' for Planning Page Updates: 
Clarify with Patrick what constitutes a 'change' for the planning page update counter and whether filtering should be applied. (Maximilian)
QA and Automated Testing Capacity Planning: 
Assess the need for additional QA or automated testing resources, especially for the final phase, and determine if onboarding new team members is feasible and beneficial. (the team)