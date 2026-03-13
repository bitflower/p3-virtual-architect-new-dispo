
## Agenda

Hi everyone, 

We would like to schedule this initial kickoff meeting to discuss the upcoming Oracle CDC proof-of-concept.

Following topics should be discussed in this meeting:
Motivation & Objectives POC (10 min)
Discussion pre-requisites & POC-Setup (50 min)
Oracle SE2 & LogMiner (Status Quo)
Striim (Status Quo)
Setup dedicated database environment
Setup GCP- & network access (buckets, datastream, VPN)
Clarification of input parameters / KPIs (performance baseline, volumes, throughput)

Thank you!

## Summary


Besprechungsnotizen:
Initiative for Oracle CDC Solution: 
Matthias introduced the meeting to kickstart an initiative, originally started by Christian, to implement a Change Data Capture (CDC) solution for Oracle databases, with the aim of supporting the new Dispo Go Live in June and ensuring feature parity with existing Postgres CDC mechanisms.
	Business Context and Timeline: Matthias explained that the strategic shift back to Oracle-based setups for TMS and disposition necessitates a CDC solution for on-premise Oracle databases, with the new Dispo Go Live in June serving as the key milestone. The CDC solution is critical to onboarding Oracle branches and ensuring a complete feature set.
	Previous Solution Evaluation: Matthias described the pre-phase evaluation, where four CDC solutions were considered. Debezium and Oracle GoldenGate were de-scoped due to configuration complexity, unfamiliarity, and cost, leaving 'stream' and Google Data Stream as the two candidates for proof of concept.
	POC Objectives and Scope: The team agreed to conduct proofs of concept for both 'stream' and Data Stream, focusing solely on CDC mechanisms for Oracle, not on database wrappers or broader integration. The POCs aim to provide fact-based insights for a later rollout to all branches and to avoid risks to the June Go Live.
Technical Architecture and Current State: 
Matthias, Matt Wilkinson, and Christian discussed the current CDC architecture, the separation of read/write operations via the TMS Bridge, and the specifics of the Postgres CDC implementation, clarifying the technical flow and the intended replication for Oracle.
	TMS Bridge and Pulse Mechanisms: Matthias clarified that all write-back operations to databases are performed via the TMS Bridge, which already supports Oracle, while CDC (Pulse) is used for real-time notifications of database changes. The harmonisation layer allows consistent connectivity for both Postgres and Oracle.
	Current Postgres CDC Setup: Matthias detailed the Postgres CDC setup: a replication slot and publication are created in the database, Data Stream captures changes from the 'Sendong' table, writes them to a cloud storage bucket, and triggers a cloud function to process relevant shipment types before sending to downstream systems.
	Oracle Migration Status: Matthias and Matt Wilkinson noted that while the TMS Bridge supports Oracle, the migration of wrappers and schema changes for new Dispo functionality is ongoing, with Joachim leading the effort. The CDC POC for Oracle will focus on validating the CDC mechanism, not the full migration.
Proof of Concept Planning and Database Selection: 
The group, including Matt Wilkinson, Ron, Pascal, and Matthias, discussed the selection of appropriate Oracle databases for the POCs, the need for isolated environments, and the technical requirements for both 'stream' and Data Stream solutions.
	Database Selection Criteria: Matthias emphasised the need to select two separate on-premise Oracle databases for the POCs—one for 'stream' and one for Data Stream—to avoid conflicts and ensure isolated testing. The preferred databases should have real-world data for meaningful results.
	Test Environment Setup: Matt Wilkinson and Ron discussed using existing test databases (e.g., 1034, 1060) and the process for populating them with relevant data, either by copying production data or generating test orders via the application. The team agreed to start with test environments before moving to production-like scenarios.
	Technical Requirements and Stakeholders: Matt Wilkinson highlighted the need for database engineers to review Oracle infrastructure requirements, such as log miner setup and user grants, and identified Thomas and Eric as key stakeholders for implementing changes. The group agreed to coordinate closely to avoid delays.
Technical Challenges and Constraints: 
Matt Wilkinson, Yosif, Ron, and Matthias examined technical risks including log file cycling, network reliability, character set mismatches, and infrastructure limitations, identifying these as critical factors to be tested and considered during the POCs.
	Log File Cycling and Data Loss: Matt Wilkinson explained that rapid cycling of Oracle redo logs could lead to data loss if CDC connections are not re-established promptly, necessitating a full database reload. The team agreed to test this scenario during the POC to assess resilience.
	Network and Proxy Issues: Yosif raised concerns about unstable connections and the use of proxies in the Postgres setup, which can corrupt replication slots. Matt Wilkinson clarified that Oracle allows direct connections, but network reliability between GCP and on-premise sites remains a risk.
	Character Set Compatibility: Matt Wilkinson noted that Oracle databases use older character sets, unlike Postgres's UTF-8, which could cause data corruption or misrepresentation. The team discussed the need to handle character set mapping, especially for special characters, and to verify tool support.
	Physical Infrastructure Constraints: Ron and Matt Wilkinson discussed disk space limitations on Oracle servers, which restrict the ability to increase log retention and may cause bottlenecks. The team acknowledged that these constraints could affect both CDC solutions and must be factored into planning.
Operational Next Steps and Coordination: 
Matthias, Matt Wilkinson, Ron, and others outlined the immediate next steps, including preparing GCP buckets, coordinating with database engineers, scheduling workshops, and defining responsibilities for setting up and testing the POCs.
	GCP Bucket Preparation: Matt Wilkinson requested the creation of two cloud storage buckets in GCP—one for Data Stream and one for 'stream'—to serve as destinations for CDC events during testing. Matthias confirmed this would be set up in the test environment.
	Testing and Validation Process: The team agreed to first validate technical setup and data flow using test databases, then perform volume testing and, if successful, replicate the process on production-like databases. Testers such as Patrick and Steve will generate test data to trigger CDC events.
	Scheduling and Resource Coordination: Matthias proposed scheduling a workshop towards the end of the week or early next week to bring together all relevant stakeholders for real-time setup and troubleshooting. Martin was identified to assist with meeting coordination.
	Responsibility Assignment: Matt Wilkinson and Matthias clarified that the GCP team is responsible for cloud setup, while the database team (including Thomas and Eric) will handle Oracle-side changes. Each party is to prepare their components ahead of the joint workshop.
Folgeaufgaben:
Database Selection for POCs: 
Determine and communicate which Oracle databases will be used for the Stream and Data Stream POCs, ensuring they are suitable and do not overlap, and confirm availability for testing. (Matt Wilkinson, Ron, Thomas)
GCP Cloud Storage Bucket Preparation: 
Set up two dedicated GCP cloud storage buckets, one for Stream and one for Data Stream, in the WL4 test environment and inform the team when they are ready for use. (Matthias)
Technical Setup for Data Stream on Oracle: 
Review and implement the required Oracle database changes (e.g., grants, log miner setup) for Data Stream CDC, and confirm feasibility on the selected test database. (Thomas, Matt Wilkinson)
OMS Test Data Generation: 
Coordinate with Thomas to ensure OMS shipments or relevant test data can be generated in the test Oracle database to support POC validation. (Matthias, Thomas)
Database Sizing and Transaction Details Sharing: 
Share the findings on database sizing, transaction counts, and free space for the selected Oracle test database with the team to inform POC planning. (Matt Wilkinson)
Meeting Scheduling for POC Setup: 
Arrange a meeting towards the start of next week with all relevant parties to perform the technical setup and initial testing of the POCs in real time. (Martin)
Character Set Compatibility Investigation: 
Investigate and document the character set differences between Oracle on-prem databases and GCP targets, and assess potential issues for the CDC solutions. (Matt Wilkinson)