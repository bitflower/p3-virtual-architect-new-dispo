# Oracle CDC PoC - Project Offer

**Project:** Oracle Change Data Capture - Proof of Concept
**Date:** 2026-02-10
**Version:** 3.0 - Object Store Only, Simplified Structure
**Prepared by:** P3 Team (Matthias Max)
**Client:** Nagel IT
**Decision Maker:** Christian Lang

---

## 1. Executive Summary

### 1.1 Background

NewDispo requires Oracle CDC integration to be deployed independently from Project G. Striim is currently deployed on 5 Oracle branches (historically on all branches) for CDC purposes. Christian Lang has requested a comprehensive Proof of Concept to evaluate two CDC approaches:

1. **Option A: Striim → GCP Object Store** (leveraging existing Striim infrastructure)
2. **Option B: Oracle → GCP Datastream → Object Store** (GCP-native solution)

### 1.2 Project Objectives

- Validate end-to-end CDC functionality for both options on Nagel IT infrastructure
- Determine implementation effort, costs, and operational requirements for each option
- Define clear rollout steps for global deployment across all Oracle branches
- Provide decision-making basis for strategic CDC solution selection via ADR

### 1.3 Success Criteria

| Criterion                    | Target                                                                                      |
| ---------------------------- | ------------------------------------------------------------------------------------------- |
| **CDC Solution Identified**  | Suitable option selected based on performance, cost, and operational fit                    |
| **Change Capture Validated** | Table changes (INSERT, UPDATE, DELETE) successfully captured and written to Object Store    |
| **Setup Documented**         | Complete documentation for future rollout on client infrastructure                          |
| **SE2 Compatibility**        | Validation of Oracle Standard Edition 2 support for selected option                         |
| **Cost Model**               | Clear production cost projection for both options                                           |

---

## 2. PoC Scope & Constraints

### 2.1 Constraints

| Constraint                                         | Rationale                                                                                                                              |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **TMS Branch Databases Only**                      | PoC focuses on branch databases (Standard Edition 2) which represent the majority of the deployment target (~30 branches)              |
| **PoC on Nagel IT Infrastructure**                 | End-to-end validation on actual Nagel Oracle and GCP environment; requires separate/dedicated environment to not block testing on TEST |
| **Nagel IT Provides Infrastructure**               | Nagel IT responsible for providing Oracle databases meeting load criteria and GCP connectivity                                         |
| **Two Separate Branch Oracle Databases**           | ONE Striim-connected branch DB and ONE non-Striim branch DB to avoid dual-CDC conflicts                                                |
| **Fully Fledged Database with Single Table Focus** | Use actual production-like branch database, but constrain PoC testing to "sendung" table only                                          |
| **PoC Ends at Object Store**                       | Full-stack chain validates: Oracle → CDC Tool → Object Store (GCS)                                                                     |
| **No GoLive Until PROD-Readiness**                 | Technical evaluation only; production deployment is separate phase                                                                     |
| **Network Already Established**                    | Leverage existing VPN/Interconnect to GCP (provided by Nagel IT)                                                                       |

### 2.2 In Scope

**Technical Scope:**
- Test Oracle databases provided by Nagel IT (archivelog mode enabled, LogMiner configured)
- Configuration and testing of Striim → Object Store integration
- Configuration and testing of Oracle → Datastream → Object Store integration
- Performance and latency measurements for both options
- Oracle Standard Edition 2 compatibility validation (via documentation/Google support)
- Failure scenario testing (recovery, redo log gap handling)
- Cost analysis and projection for production deployment

**Deliverables:**
- Working PoC for both options
- ADR (Architecture Decision Record) with comparative evaluation
- Implementation guides for both options
- Production rollout plan (effort estimates and steps) - **TBD with Martin**
- Cost comparison and operational complexity assessment

### 2.3 Out of Scope

- **Central HQ Oracle database** (Enterprise Edition) - PoC focuses on branch databases (Standard Edition 2) only
- Production deployment on Nagel infrastructure (covered in rollout plan)
- Integration with actual NewDispo consumers (simulated in PoC)
- Cross-Dock/CALSuite integration
- Full decommissioning of non-selected option (plan provided, execution separate)

### 2.4 Test Setup

**Oracle Databases (Nagel Infrastructure):**

**IMPORTANT: Dedicated/Separate Environment Required**
- PoC requires dedicated Oracle database environment (not TEST environment)
- Ensures PoC activities don't block or interfere with ongoing TEST activities
- Nagel IT to provide selected branch database instances for PoC

Two separate **branch** Oracle databases will be used to avoid dual-CDC conflicts:

1. **For Striim PoC:**
   - Database: ONE of the 5 existing Striim-connected **TMS branch** Oracle databases
   - Edition: Standard Edition 2 (branch database)
   - Purpose: Validate Striim extension to Object Store (GCS)
   - Configuration: Already configured with Striim CDC
   - Test Table: "sendung" table

2. **For Datastream PoC:**
   - Database: ONE **TMS branch** Oracle database that does NOT have Striim configured
   - Edition: Standard Edition 2 (branch database)
   - Purpose: Validate Datastream CDC independently on SE2
   - Configuration: Archivelog mode, LogMiner enabled, supplemental logging, necessary grants, and all further CDC-required configurations (to be validated with Nagel IT DB experts - support may be required)
   - Test Table: "sendung" table

**Rationale for Branch Database Focus:**
- Branch databases use **Standard Edition 2** with LogMiner limitations that need validation
- Branch databases represent the majority of the deployment target (~30 branches)
- SE2 compatibility is critical for production rollout success

**GCP Environment (Nagel GCP Project):**
- Cloud Storage buckets (Object Store) for both PoCs
- Datastream service configuration (for Option B)
- Monitoring and logging setup
- Existing network connectivity (VPN/Interconnect) leveraged

### 2.5 Load & Volume Requirements

Understanding the expected load and volume is critical for validating PoC performance and projecting production costs.

**Key Questions to Address During Kickoff:**

| Question                                          | Rationale                                                               | Status               |
| ------------------------------------------------- | ----------------------------------------------------------------------- | -------------------- |
| **How many shipments (Sendungen) per day?**       | Determines CDC event volume and throughput requirements                 | TBD - Nagel IT       |
| **Peak vs. low times during the day?**            | Identifies if solution must handle burst traffic or steady load         | TBD - Nagel IT       |
| **Average Sendung record size?**                  | Impacts Datastream per-GiB cost projections                             | TBD - Nagel IT       |
| **INSERT/UPDATE/DELETE ratio?**                   | Different operations may have different CDC characteristics             | TBD - Nagel IT       |
| **Does existing Oracle-Striim handle high-load?** | Validates if current Striim deployment can scale for additional targets | TBD - Matt Wilkinson |
| **Current Striim throughput metrics?**            | Baseline for comparison; validates if extension is viable               | TBD - Matt Wilkinson |

**Initial Assumptions (To Be Validated):**

- **Volume Estimate**: Assuming 10,000 - 100,000 shipments/day across all branches (TBD)
- **CDC Event Size**: Assuming average 2-5 KB per Sendung CDC event (TBD)
- **Peak Load**: Assuming 2-3x average during peak hours (TBD)
- **Daily Data Volume**: Estimated 20-500 MB/day CDC data (TBD)

**Impact on PoC:**

1. **Performance Testing**: PoC will simulate expected load to validate latency under realistic conditions
2. **Cost Projections**: Accurate volume data enables precise Datastream cost estimates (per-GiB pricing)
3. **Striim Capacity**: Validates if existing Striim can handle additional Object Store target without performance degradation
4. **Sizing Recommendations**: Informs production deployment sizing (GCP resources, network bandwidth)

**Note:** These questions will be addressed during the kickoff meeting. If accurate production metrics are unavailable, PoC will use conservative estimates and provide sensitivity analysis for cost projections.

---

## 3. Technical Approach

### 3.1 Option A: Striim → GCP Object Store

**Architecture (Client Infrastructure):**
```
Oracle DB (Nagel On-Prem) → Existing Striim → Object Store (GCS)
```

**Key Activities:**
1. Assess existing Striim deployment and configuration
2. Configure Object Store (GCS) writers in Striim
3. Configure CDC for "sendung" table
4. Run INSERT/UPDATE/DELETE operations and validate capture
5. Measure latency and throughput
6. Test failure scenarios (network interruption, redo log gap)
7. Document operational procedures

**Key Validations:**
- Striim can capture Oracle changes and publish to Object Store
- Latency meets requirements (target: < 5 seconds 95th percentile)
- Operational complexity is manageable
- Cost model for production (obtain Striim licensing costs from Nagel IT)

### 3.2 Option B: Oracle → GCP Datastream → Object Store

**Architecture (Client Infrastructure):**
```
Oracle DB (Nagel On-Prem) → Datastream → Object Store (GCS)
```

**Key Activities:**
1. Validate Datastream Oracle Standard Edition 2 support (documentation + Google support)
2. Configure Datastream connection profile for Oracle
3. Set up Datastream stream for "sendung" table
4. Configure GCS bucket as target
5. Run INSERT/UPDATE/DELETE operations and validate capture
6. Measure latency and throughput (including GCS write latency)
7. Test failure scenarios
8. Document operational procedures

**Key Validations:**
- Datastream supports Oracle SE2 with required LogMiner features
- End-to-end latency is acceptable (note: GCS intermediate step adds latency)
- Cost model for production (per-GiB pricing)
- Operational simplicity (fully managed service)

### 3.3 Comparative Evaluation Criteria

| Criterion                   | Weight | Notes                                                        |
| --------------------------- | ------ | ------------------------------------------------------------ |
| **Technical Feasibility**   | High   | SE2 compatibility, performance, reliability                  |
| **Cost (PoC + Production)** | High   | Licensing costs (Striim) vs. volume-based costs (Datastream) |
| **Operational Complexity**  | Medium | Setup, maintenance, monitoring, troubleshooting              |
| **Strategic Alignment**     | Medium | Existing Striim investment vs. GCP-native strategy           |
| **Vendor Lock-in Risk**     | Low    | Dependency on third-party (Striim) vs. GCP                   |
| **Time to Production**      | Medium | Effort to deploy on Nagel infrastructure                     |

---

## 4. Key Technical Challenges & Mitigations

### 4.1 Oracle Standard Edition 2 Limitations

**Challenge:** Oracle SE2 does not support all LogMiner features:
- No Continuous LogMiner (streaming API)
- Limited concurrent LogMiner sessions
- Supplemental Logging restrictions

**Impact:** Datastream (and potentially Striim) may have degraded functionality or incompatibility on SE2.

**Mitigation:**
- **Phase 1**: Validate Datastream SE2 support via Google documentation and support ticket
- **PoC**: Test both options with clean Oracle SE2 install
- **Fallback**: If Datastream incompatible with SE2, Striim becomes primary option (already proven on Nagel SE2 branches)

### 4.2 Redo Log Retention (~1 hour on some branches)

**Challenge:** Nagel branches (e.g., D33) have ~1 hour redo log retention due to space constraints.

**Impact:** Network outage > 1 hour results in transaction sequence loss, requiring full initial load.

**Mitigation:**
- Design CDC solution with recovery/resync capability
- Document operational procedures for full reload scenarios
- **PoC**: Test redo log gap scenario and document recovery steps

### 4.3 Dual-CDC Risk

**Challenge:** Running both Striim and Datastream simultaneously risks data conflicts and infrastructure complexity.

**Mitigation:**
- **Clear Decision via ADR**: Select one option based on PoC results
- **Decommissioning Plan**: Before production rollout of new option, coordinate Striim retirement with Nagel IT
- **Database Separation**: Using separate Oracle databases for Striim and Datastream PoCs avoids dual-CDC conflicts

### 4.4 Cost Uncertainty

**Challenge:** Striim licensing costs for extending to Object Store are unknown. New Striim deployment costs $9,600+/month.

**Impact:** If Striim extension costs are prohibitive, Datastream may be more cost-effective.

**Mitigation:**
- **Immediate Action**: Obtain Striim cost data from Nagel IT (Matt Wilkinson) before/during PoC
- **Cost Modeling**: Project production costs for both options based on:
  - Striim: licensing + infrastructure
  - Datastream: per-GiB pricing (~$2/GiB) based on expected data volume

---

## 5. Deliverables

### 5.1 Technical Documentation

1. **PoC Setup Guide**
   - Oracle database installation and configuration
   - Striim deployment and configuration guide
   - Datastream setup and configuration guide
   - GCP infrastructure (GCS, networking) setup

2. **Performance Test Results**
   - Latency measurements (95th percentile, average)
   - Throughput measurements (events/second)
   - Resource utilization (CPU, memory, network)
   - Failure scenario test results (recovery time, data loss)

3. **Operational Runbooks**
   - Day-to-day operations procedures
   - Monitoring and alerting setup
   - Troubleshooting guide (common issues and resolution)
   - Failure recovery procedures (redo log gap, network outage)

### 5.2 Architecture Decision Record (ADR)

Comprehensive ADR document including:

1. **Context & Requirements**
   - Business objectives and constraints
   - Technical environment (Oracle versions, editions, infrastructure)

2. **Options Evaluated**
   - Option A: Striim → Object Store (detailed analysis)
   - Option B: Datastream → Object Store (detailed analysis)
   - Options considered but rejected (e.g., Debezium, GoldenGate)

3. **Comparative Evaluation**
   - Performance comparison (latency, throughput)
   - Cost analysis (PoC + projected production costs)
   - Operational complexity assessment
   - Risk and dependency analysis
   - Strategic alignment considerations

4. **Recommendation**
   - Recommended option with clear justification
   - Trade-offs and considerations
   - Implementation roadmap

5. **Consequences**
   - Impact of decision on architecture
   - Required follow-up actions
   - Risks and mitigation strategies

### 5.3 Production Rollout Plan

**Note:** Detailed production rollout plan (effort estimates, timeline, and steps) is **TBD with Martin**. The following outlines the expected structure and key areas to be covered:

1. **Deployment Strategy**
   - Phase-by-phase rollout approach (pilot branches → full rollout)
   - Branch prioritization (based on criticality, Oracle version/edition)
   - Rollback procedures and contingency plans

2. **Effort Estimates**
   - Per-branch deployment effort (setup, testing, cutover)
   - Total effort for all Oracle branches (~30 branches estimated)
   - Timeline projections (parallelization opportunities)

3. **Prerequisites & Dependencies**
   - Network connectivity requirements
   - Oracle database grants and configuration
   - GCP infrastructure setup
   - Stakeholder approvals and coordination

4. **Risk Assessment**
   - Technical risks (SE2 compatibility, redo log gaps)
   - Operational risks (dual-CDC conflicts, downtime)
   - Mitigation strategies and contingency plans

5. **Decommissioning Plan (if applicable)**
   - Steps to retire non-selected CDC option
   - Data validation during transition
   - Rollback procedures if issues arise

---

## 6. Risks & Mitigation

| Risk                                                  | Likelihood | Impact | Mitigation                                                                             |
| ----------------------------------------------------- | ---------- | ------ | -------------------------------------------------------------------------------------- |
| **Datastream incompatible with Oracle SE2**           | Medium     | High   | Early validation with Google; Striim as proven fallback                                |
| **Striim extension costs prohibitive**                | Medium     | High   | Obtain cost data early in PoC; shift focus to Datastream if needed                     |
| **Short redo log retention causes production issues** | High       | Medium | Design for resync capability; operational procedures documented                        |
| **Dual-CDC conflicts on Nagel infrastructure**        | Low        | High   | Clear ADR decision; decommissioning plan before production rollout                     |
| **PoC blocks TEST environment or causes disruption**  | Low        | Medium | Use dedicated/separate environment; coordinate with Nagel IT on environment allocation |
| **Latency exceeds NewDispo requirements**             | Low        | Medium | Performance testing in PoC; tuning and optimization                                    |
| **Access delays to Nagel Striim cost data**           | Medium     | Low    | Immediate request to Matt Wilkinson; proceed with PoC in parallel                      |

---

## 7. Success Metrics & Acceptance Criteria

### 7.1 PoC Success Metrics

| Metric                           | Target                        | Measurement                                         |
| -------------------------------- | ----------------------------- | --------------------------------------------------- |
| **CDC Event Capture Accuracy**   | 100%                          | Validate all INSERT/UPDATE/DELETE captured          |
| **End-to-End Latency**           | < 5 seconds (95th percentile) | Measure from Oracle commit to Object Store write    |
| **Initial Load Performance**     | < 1 hour for test dataset     | Validate backfill mechanism                         |
| **Recovery Time (Redo Log Gap)** | < 30 minutes                  | Test resync after simulated outage                  |
| **SE2 Compatibility**            | Full functionality            | Validate on Oracle SE2 instance                     |
| **Operational Complexity**       | Manageable by Ops team        | Documented procedures, clear runbooks               |
| **Cost Predictability**          | ±20% accuracy                 | Production cost projections validated               |

### 7.2 ADR Acceptance Criteria

- [ ] Both options evaluated with objective criteria
- [ ] Performance data collected and analyzed
- [ ] Cost comparison completed (PoC + 12-month production projection)
- [ ] Operational complexity assessed for both options
- [ ] Clear recommendation with justification
- [ ] Risk assessment and mitigation strategies documented
- [ ] Stakeholder review and approval obtained

### 7.3 Rollout Plan Acceptance Criteria

**Note:** Detailed acceptance criteria are **TBD with Martin**. Preliminary criteria include:

- [ ] Phase-by-phase deployment strategy framework defined
- [ ] Preliminary per-branch effort estimates provided
- [ ] Indicative rollout timeline projected
- [ ] Key prerequisites and dependencies identified
- [ ] Risk mitigation and rollback procedures documented
- [ ] Decommissioning plan for non-selected option (if applicable)

---

## 8. Assumptions & Dependencies

### 8.1 Assumptions

- **Client Infrastructure**: Nagel IT provides dedicated/separate infrastructure meeting load criteria and GCP connectivity
- **Infrastructure Responsibility**: Nagel IT responsible for:
  - Providing dedicated/separate PoC environment (not TEST environment)
  - Providing two Oracle branch databases (one Striim-connected, one non-Striim)
  - Ensuring databases meet expected load characteristics (Sendungen volume)
  - Maintaining network connectivity to GCP (VPN/Interconnect)
  - Oracle configuration (archivelog mode, LogMiner enabled, supplemental logging, necessary grants, and all CDC-required configurations; DB expert support from Nagel IT available)
- **P3 Team Access**: P3 has access to Nagel Oracle databases, Striim, and GCP project
- **Separate PoC Environment**: Dedicated/separate Oracle database environment provided by Nagel IT that won't block TEST environment or disrupt production
- **Striim Access**: Existing Striim deployment accessible for configuration changes
- **Internal Support Guaranteed**: Support requests from Nagel IT, Platform, and BIT teams are guaranteed and prioritized by Christian Lang throughout PoC duration
- **Vendor Support Availability**:
  - Striim vendor support accessible if needed (via Nagel IT's support contract)
  - Google Cloud support available for Datastream questions (reasonable response times: 24-48h)
  - Critical issues can be escalated
- **Data Volume Estimates**: Nagel IT can provide expected CDC data volume for cost projections
- **Fully Fledged Database**: PoC uses actual production-like branch database with full TMS-Schema; testing constrained to "sendung" table only

### 8.2 Dependencies

| Dependency                                                                                                          | Owner                              | Required By    | Status  |
| ------------------------------------------------------------------------------------------------------------------- | ---------------------------------- | -------------- | ------- |
| **Infrastructure Provision**: Nagel IT provides dedicated/separate PoC environment meeting load criteria (not TEST) | Nagel IT                           | Week 1         | Pending |
| **GCP Connectivity**: Nagel IT ensures stable VPN/Interconnect to GCP                                               | Nagel IT / DevOps                  | Week 1         | Pending |
| **Oracle DB #1**: Access to ONE Striim-connected database                                                           | Nagel IT / DBA Team                | Week 1         | Pending |
| **Oracle DB #2**: Access to ONE non-Striim Oracle database (preferably SE2)                                         | Nagel IT / DBA Team                | Week 1         | Pending |
| Nagel GCP project access for P3 team                                                                                | Nagel IT / DevOps                  | Week 1         | Pending |
| Striim access and configuration rights                                                                              | Nagel IT (Matt Wilkinson)          | Week 1         | Pending |
| Striim cost data (current + Object Store extension)                                                                 | Nagel IT (Matt Wilkinson)          | Week 1-2       | Pending |
| Striim performance metrics (throughput, current load)                                                               | Nagel IT (Matt Wilkinson)          | Week 1-2       | Pending |
| Striim vendor support access (if needed for troubleshooting)                                                        | Nagel IT (Matt Wilkinson)          | Week 2-3       | Pending |
| Datastream SE2 compatibility confirmation                                                                           | Google Cloud Support               | Week 1-2       | Pending |
| Google Cloud expert support access for Datastream setup                                                             | P3 / Nagel IT                      | Week 2-3       | Pending |
| Expected CDC data volume estimates (Sendungen/day, sizes)                                                           | Nagel IT                           | Week 1-2       | Pending |
| Stakeholder availability for meetings                                                                               | Nagel IT (Christian, Matt, Robert) | Throughout PoC | Pending |
| Internal support from Nagel IT, Platform, BIT teams guaranteed and prioritized                                      | Christian Lang                     | Throughout PoC | Pending |

---

## 9. Appendix

### 9.1 Key Stakeholders

| Name           | Organization | Role           | Responsibility                                          |
| -------------- | ------------ | -------------- | ------------------------------------------------------- |
| Christian Lang | Nagel IT     | Decision Maker | Strategic direction, final ADR approval                 |
| Matt Wilkinson | Nagel IT     | Striim Lead    | Striim cost data, technical guidance                    |
| Robert Zanter  | Nagel IT     | DBA Lead       | Oracle technical validation, LogMiner insights          |
| Matthias Max   | P3           | Architect      | PoC architecture, ADR authoring, evaluation             |
| [TBD]          | P3           | DB-Dev Lead    | Oracle setup, CDC configuration, testing                |
| [TBD]          | P3           | DevOps Lead    | GCP infrastructure, networking, integration             |
| [TBD]          | P3           | PM             | Project coordination, reporting, stakeholder management |

### 9.2 Reference Documents

- [Original Request (2025-12-01)](../02_Communication/Mails_1/2025-12-01-original-request.md)
- [Consolidated Requirements](../02_Communication/Mails_1/00_Consolidated-Requirements.md)
- [Architecture Status Update (2026-01-16)](../02_Communication/Mails_3/2026-01-16-architecture-status-intermediate.md)
- [Architecture Evaluation](../03_Exploration/2026-01-16-status-wrapup/00_Architecture-Evaluation.md)
- [P3 Standard PoC Template](../03_Exploration/2026-02-10-final-poc-offer/)

### 9.3 Glossary

| Term               | Definition                                                                          |
| ------------------ | ----------------------------------------------------------------------------------- |
| **ADR**            | Architecture Decision Record - document capturing options, evaluation, and decision |
| **CDC**            | Change Data Capture - technology to track and capture database changes              |
| **LogMiner**       | Oracle feature to read redo logs for change tracking                                |
| **SE2**            | Oracle Standard Edition 2 (vs. Enterprise Edition) - has LogMiner limitations       |
| **Redo Log**       | Oracle transaction log used for recovery and CDC                                    |
| **Datastream**     | Google Cloud service for database replication and CDC                               |
| **Striim**         | Third-party real-time data integration platform (currently deployed at Nagel)       |
| **Object Store**   | Cloud storage (e.g., GCS) for persisting CDC events                                 |
| **GCS**            | Google Cloud Storage                                                                |
| **End-to-End PoC** | PoC validates full CDC flow on actual client infrastructure (not isolated sandbox)  |

### 9.4 Oracle SE2 LogMiner Limitations

Oracle Standard Edition 2 has the following LogMiner restrictions that may impact CDC tools:

| Feature                                | Enterprise Edition | Standard Edition 2             |
| -------------------------------------- | ------------------ | ------------------------------ |
| **Continuous LogMiner**                | Supported          | **Not Supported**              |
| **Concurrent LogMiner Sessions**       | Unlimited          | Limited (typically 1-2)        |
| **Supplemental Logging (All Columns)** | Supported          | Limited in some configurations |
| **Online Catalog**                     | Supported          | Supported                      |
| **Dictionary Extraction**              | Supported          | Supported                      |

**Impact:** CDC tools that rely on Continuous LogMiner API (streaming mode) may require polling-based approach on SE2, potentially affecting latency and resource usage.

**Validation Required:** Confirm Datastream's SE2 support via Google Cloud documentation and support ticket during PoC preparation phase.

---

## 10. Approval

| Role                | Name            | Signature | Date |
| ------------------- | --------------- | --------- | ---- |
| **Client Approver** | Christian Lang  |           |      |
| **P3 Project Lead** | Martin Dittmann |           |      |

---

**Document Version History:**

| Version | Date       | Author       | Changes                                                                 |
| ------- | ---------- | ------------ | ----------------------------------------------------------------------- |
| 1.0     | 2026-02-10 | Matthias Max | Initial draft                                                           |
| 2.0     | 2026-02-10 | Matthias Max | Aligned with P3 standard PoC template, adjusted scope and effort        |
| 3.0     | 2026-02-16 | Matthias Max | Changed to Object Store only (removed Pub/Sub), removed sections: Project Activities & Effort, Cost Analysis Document, Cost Breakdown, Next Steps |
