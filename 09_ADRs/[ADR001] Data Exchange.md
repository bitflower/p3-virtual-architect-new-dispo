# [ADR001] Data Exchange Between TMS and CALSuite's Cross-Dock

## Title

Data Exchange Between TMS and CALSuite's Cross-Dock

## Context

The enterprise systems TMS (Transport Management System) and CALSuite's Cross-Dock require a robust data exchange mechanism supporting bidirectional communication. The solution must be designed for scalability to serve additional consumers beyond Cross-Dock, with any Cross-Dock-specific logic encapsulated within its own components.
*   **TMS**: Utilizes PostgreSQL databases managed via AlloyDB clusters on GCP.
*   **TMS Bridge**: A standalone system providing a REST-like gateway for accessing and manipulating data in the TMS database.
*   **CALSuite (Cross-Dock)**: Hosted on Microsoft Azure, leveraging Azure Service Bus for external communication.

Key requirements include:
1.  **Detecting Changes** in the PostgreSQL database.
2.  **Handling These Changes** by capturing and processing them.
3.  **Enriching Change Events** using the TMS Bridge.
4.  **Publishing Enriched Events** to Azure Service Bus.
5.  **Receiving Change Events** from CALSuite on Azure Service Bus.
6.  **Applying Changes** to TMS database via TMS Bridge.
7.  **Returning Success and Failure Results** of updates to Cross-Dock's Azure Service Bus.

The solution must be implemented on Nagel’s GCP account, ensuring modularity for future expansion.

#### Options Considered

1.  & 2. **Detecting and Handling Changes in the PostgreSQL Database:**
    *   **Option A: Database Trigger with Cloud Function**
    *   **Option B: CDC via Debezium (Open-source CDC Solution)**
    *   **Option C: CDC via Google Datastream with Cloud Storage and (optionally) Pub/Sub**
2.  **Enriching Change Events:**
    *   Utilize the TMS Bridge for data enrichment.
3.  & 7. **Publishing to CALSuite's Azure Service Bus:**
    *   Implement a separate cloud component for publishing events.
4.  **Receiving Change Events from CALSuite:**
    *   **Option A: Azure Function with GCP Listener**
    *   **Option B: Google EventArc for Azure Service Bus Events**
    *   **Option C: Custom Listener on Azure Service Bus**
5.  **Applying Changes to TMS Database:**
    *   Use TMS Bridge to apply changes.

## Decision

1.  & 2. **Detecting and Handling Changes in the PostgreSQL Database:**
    *   **Decision:** Google native Datastream
        *   Due to its seamless integration with GCP and managed service advantages.
2.  **Receiving Change Events from CALSuite:**
    *   **Decision:** Pending
    *   **Note:** The team is refining information received from CALSuite's team on Friday, 13th of December. The exact target architecture is therefore pending. The time delay between capturing the change events and reading the enriched data via TMS Bridge was specified as irrelevant during the alignment phase of the solution.
    *   **Additional Note:** This aspect will be handled in a separate ADR. This ADR focuses on change detection and publishing enriched transport order data accordingly.

## Rationale

*   **Google Datastream**: Recommended for its managed service capabilities, ensuring scalability, security, and integration within the GCP ecosystem. The architecture involves using Datastream to capture changes from the AlloyDB primary instance's write-ahead logs (WAL) and write them to Cloud Storage.
    
*   **Debezium with Kafka**: While considered for its flexibility and open-source nature, it requires significant infrastructure and management overhead. Additionally, a custom plugin derived from the open-source version of Debezium is necessary to filter watched tables at the root level. The out-of-the-box plugin monitors all tables and only filters the desired ones when publishing change events, potentially leading to higher-than-necessary database load.
    
*   **Database Trigger with Cloud Function**: This option carries the risk of event loss if the cloud function cannot be reached when the trigger attempts to publish an event using
    
    `pg_notify`
    
    . This reliability concern is significant and detracts from its suitability as a robust solution.
    
*   **Microservice for Receiving Events**: The decision is pending further refinement and alignment with CALSuite's team.
    

## Costs

**Note:** The cloud costs are based on the largest branch, Borgolzhausen, and will most probably be less in reality as there are significant differences in size and data volume across the various branches, including very small branches among the 59 in total. We calculated on a basis of 30 days per month workload.

**Cloud-Native CDC Costs:**
*   **Datastream:**
    *   **Monthly Cost**: $211.392
    *   **Annual Cost**: $2,536.704
    *   Assumptions include 64 databases each with 800 daily changes, totaling 96 GB/month.
*   **Cloud Storage:**
    *   **Monthly Cost**: $1.92
    *   **Annual Cost**: $23.04
    *   Based on storing 96 GB/month in Standard Storage in europe-west1.
*   **Pub/Sub:**
    *   **Cost**: Falls within the free tier for throughput and storage, with no additional costs due to real-time processing and regional delivery.
*   **Cloud Function:**
    *   **Invocation and Compute Costs**: Within the free tier limits.
    *   **Deployment Costs**: Minimal, within Artifact Registry's free tier.

**Debezium-Kafka CDC Costs:**
*   **Key Assumptions**:
    *   800 x 64 records per day, with each row-level record at 12 KB.
    *   Daily data volume: 1.17 GiB, Monthly volume: 36.27 GiB.
    *   Costs for CPU and memory are calculated based on Cloud Run pricing for a Tier 1 region.
*   **CPU Cost**:
    *   **Monthly**: $42.34 per dedicated CPU
*   **Memory Cost**:
    *   **Monthly**: $187.13
*   **Infrastructure**:
    *   Includes components like Zookeeper, Kafka UI, Debezium, Kafka Connect, and Kafka Broker, with additional considerations for the number of topics, replications, and retention.

## Consequences

*   **Positive**: The recommended solutions align with the strategic goals of utilizing GCP's managed services while ensuring flexibility and scalability for future needs.
*   **Negative**: Additional infrastructure management and potential cost implications with open-source solutions like Debezium and Kafka. The need for a custom plugin in Debezium adds complexity and development overhead. The database trigger solution's reliability issues highlight the importance of choosing a robust alternative.

## Related ADRs

*   [ADR001 Revision 13-01-2024](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/12372/Revision-of-ADR001-13-01-2024)

## References

*   PoC results for Debezium and Kafka: [ServiceBusPoC namespace](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Backend?path=/CALConsult.Disposition.API/ServiceBusPoC&version=GBfeature/consume-cross-dock-data&_a=contents)
*   PoC results for Kafka handling: [Kafka POC Branch](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Backend?version=GBcdc-debezium-kafka-POC&path=/CALConsult.Disposition.API/Infrastructure/KafkaPOC)

**Conducted PoCs:**
*   **106672**: PoC 2: Debezium Integration (Closed)
*   **106674**: PoC 3: Investigate Google-native CDC (Closed)
*   **106677**: PoC 6: TMS Bridge Authentication M2M (In Progress)
*   **107221**: PoC 7: Listen to Azure Service Bus (Closed)
*   **106675**: PoC 4: Azure Service Bus Event Publishing (Closed)
*   **106676**: PoC 5: Cloud-to-Cloud Communication (Closed)

**Results from PoCs:**
*   PoC-CDC with GCP Tools Set Up
*   Proof of Concept - Consuming messages for Azure Service Bus
*   Proof of Concept - Streaming of Database changes
*   Proof of Concept - Consumption of Kafka events

## Architecture Diagram

### Anmerkungen

- Striim used for data sync (CDC)
- Pretzel ist der DB Cluster Name, nicht die Datensyncronisationslösung
- Fehlt:
  - Kosten für alle 3 Varianten
  - Laufende Ops Kosten (DevOps, Dev, Monitoring, Admin-Tätigkeiten) = Vollkosten
  - Abgrenzung zu New Dispo: Kein Head-COunt basiertes Modell
  - Über PoCs sollten ca. 70% der Kosten der Gesamtlösung bereits abgedeckt sein

![==image_0==.png](/.attachments/==image_0==-11ca8d92-4f72-4d40-a014-0a54a36144d4.png) 