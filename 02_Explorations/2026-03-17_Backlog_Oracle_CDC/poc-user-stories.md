# Oracle CDC PoC User Stories

## Datastream POC

**User Story:**
> As a technical team, we want to configure and validate Google Datastream for Oracle CDC replication to Cloud Storage, so that we can assess GCP-native CDC performance, latency, and integration simplicity for TMS branch databases.

**What Will Be Done:**
- Configure Datastream connection profile for Oracle database (TMS1034 ABN)
- Set up CDC stream to replicate Oracle redo logs to GCS bucket (oracle-datastream-bucket-poc)
- Execute manual insert test to validate replication
- Perform load testing using OMS order duplication (1-week duration)
- Measure throughput, latency, and stability metrics

**Expected Outcome:**
- Oracle CDC data successfully replicated to Cloud Storage in Datastream format
- Quantified throughput, latency, and stability metrics under load
- Assessment of GCP-native integration and operational simplicity
- Cost analysis for Datastream licensing and infrastructure
- Validation of compatibility with existing Postgres CDC patterns

---

## Striim POC

**User Story:**
> As a technical team, we want to configure and validate Striim for Oracle CDC replication to Cloud Storage, so that we can assess its character set mapping capabilities, performance, and suitability for TMS branch databases with complex encoding requirements.

**What Will Be Done:**

- Set up CDC stream to replicate Oracle redo logs to GCS bucket (oracle-striim-bucket-poc)
- Execute manual insert test to validate replication
- Perform load testing using OMS order duplication (1-week duration)
- Measure throughput, latency, and stability metrics
- Validate character set mapping capabilities (addressing Poland character corruption issues)

**Expected Outcome:**
- Oracle CDC data successfully replicated to Cloud Storage in Striim format
- Quantified throughput, latency, and stability metrics under load
- Assessment of Striim operational complexity and Nagel team familiarity
- Cost analysis for Striim licensing and infrastructure
- Comparison with Datastream for final technology selection
- Validation of character set compatibility and mapping correctness