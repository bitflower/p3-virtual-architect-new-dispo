# Oracle CDC PoC - Project Offer

**Project:** Oracle Change Data Capture - Proof of Concept
**Date:** 2026-02-10
**Version:** 2.0 - Aligned with P3 Standard PoC Template
**Prepared by:** P3 Team (Matthias Max)
**Client:** Nagel IT
**Decision Maker:** Christian Lang

---

## 1. Executive Summary

### 1.1 Background

NewDispo requires Oracle CDC integration to be deployed independently from Project G. Striim is currently deployed on 5 Oracle branches (historically on all branches) for CDC purposes. Christian Lang has requested a comprehensive Proof of Concept to evaluate two CDC approaches:

1. **Option A: Striim → GCP Pub/Sub/Object Store** (leveraging existing Striim infrastructure)
2. **Option B: Oracle → GCP Datastream → Pub/Sub/Object Store** (GCP-native solution)

### 1.2 Project Objectives

- Validate end-to-end CDC functionality for both options on Nagel IT infrastructure
- Determine implementation effort, costs, and operational requirements for each option
- Define clear rollout steps for global deployment across all Oracle branches
- Provide decision-making basis for strategic CDC solution selection via ADR

### 1.3 Success Criteria

| Criterion                    | Target                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------ |
| **CDC Solution Identified**  | Suitable option selected based on performance, cost, and operational fit                         |
| **Change Capture Validated** | Table changes (INSERT, UPDATE, DELETE) successfully captured and written to Pub/Sub/Object Store |
| **Setup Documented**         | Complete documentation for future rollout on client infrastructure                               |
| **SE2 Compatibility**        | Validation of Oracle Standard Edition 2 support for selected option                              |
| **Cost Model**               | Clear production cost projection for both options                                                |

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
| **PoC Ends at Pub/Sub/Object Store**               | Full-stack chain validates: Oracle → CDC Tool → Pub/Sub/Object Store (GCS)                                                             |
| **No GoLive Until PROD-Readiness**                 | Technical evaluation only; production deployment is separate phase                                                                     |
| **Network Already Established**                    | Leverage existing VPN/Interconnect to GCP (provided by Nagel IT)                                                                       |

### 2.2 In Scope

**Technical Scope:**
- Test Oracle databases provided by Nagel IT (archivelog mode enabled, LogMiner configured)
- Configuration and testing of Striim → Pub/Sub integration
- Configuration and testing of Oracle → Datastream → Pub/Sub/Object Store integration
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
   - Purpose: Validate Striim extension to Pub/Sub/Object Store (GCS)
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
- Pub/Sub topics and subscriptions (if extended beyond Object Store)
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

## 3. Project Activities & Effort

### 3.1 Activity Breakdown

| Task                                               | Role      | Days          | Reference/Notes                                                                                      |
| -------------------------------------------------- | --------- | ------------- | ---------------------------------------------------------------------------------------------------- |
| **1. Kickoff**                                     |           | **2.5**       | Define success criteria (tables, etc.) with prep                                                     |
|                                                    | Architect | 1.0           |                                                                                                      |
|                                                    | DB-Dev    | 0.5           |                                                                                                      |
|                                                    | DevOps    | 0.5           |                                                                                                      |
|                                                    | PM        | 0.5           |                                                                                                      |
| **2. Environment Access & Validation**             |           | **1.5**       | Access to Nagel Oracle, GCP, Striim; validate setup                                                  |
|                                                    | DB-Dev    | 0.5           | Oracle database access, LogMiner validation                                                          |
|                                                    | DevOps    | 1.0           | GCP access, network connectivity check                                                               |
| **3. Options Review**                              |           | **1.0**       | Assess Striim vs. Datastream criteria                                                                |
|                                                    | Architect | 0.5           | Exclusion criteria: cost or vendor lock-in                                                           |
|                                                    | DB-Dev    | 0.5           |                                                                                                      |
| **4. Option A: Striim → Pub/Sub/Object Store**     |           | **5.0**       | Configure Striim, test CDC to Pub/Sub/Object Store (GCS)                                             |
|                                                    | DB-Dev    | 3.0           | Striim configuration and CDC setup on existing Striim; includes Striim vendor consultation if needed |
|                                                    | DevOps    | 2.0           | GCP integration (Pub/Sub, GCS), monitoring                                                           |
| **5. Option B: Datastream → Pub/Sub/Object Store** |           | **5.0**       | Configure Datastream, validate SE2 support                                                           |
|                                                    | DB-Dev    | 3.0           | Datastream setup, Oracle integration; includes Google Cloud expert consultation                      |
|                                                    | DevOps    | 2.0           | Pub/Sub/GCS integration; includes Google Cloud support if needed                                     |
| **6. ADR: Architecture Decision Record**           |           | **0.5**       | Document options, results, decision, reasoning                                                       |
|                                                    | Architect | 0.5           | Comparative evaluation with recommendation                                                           |
| **7. Meetings (1-2 Ongoing Rounds)**               |           | **2.75**      | Smaller stakeholder sync meetings                                                                    |
|                                                    | Architect | 0.5           |                                                                                                      |
|                                                    | DevOps    | 1.0           |                                                                                                      |
|                                                    | DB-Dev    | 1.0           |                                                                                                      |
|                                                    | PM        | 0.25          |                                                                                                      |
| **8. Reporting/Steering**                          |           | **0.25**      | Status updates to stakeholders                                                                       |
|                                                    | PM        | 0.25          |                                                                                                      |
| **9. Production Rollout Planning**                 |           | **1.0**       | Plan for PROD-readiness, documentation, efforts (TBD with Martin)                                    |
|                                                    | DB-Dev    | 0.5           | Preliminary effort estimates for global rollout                                                      |
|                                                    | Architect | 0.5           | Rollout strategy and phasing framework                                                               |
| **TOTAL PoC EFFORT**                               |           | **19.5 days** |                                                                                                      |

### 3.2 Effort Summary by Role

| Role          | Days          | Notes                                                                         |
| ------------- | ------------- | ----------------------------------------------------------------------------- |
| **Architect** | 3.0           | Architecture evaluation, ADR, meetings, rollout planning                      |
| **DB-Dev**    | 9.0           | Oracle access, CDC configuration (both options), testing, vendor consultation |
| **DevOps**    | 6.5           | GCP infrastructure, networking, integration, monitoring, Google Cloud support |
| **PM**        | 1.0           | Kickoff, meetings, reporting                                                  |
| **TOTAL**     | **19.5 days** | ~156 hours total effort                                                       |

**Note on Vendor/Expert Consultation:**

The effort estimates **include time for consulting with vendor and cloud experts**:

- **Striim Vendor Support**: DB-Dev time includes Striim vendor consultation for configuration guidance, troubleshooting, and best practices (estimated 0.5-1 day embedded in Option A)
- **Google Cloud Support**: DB-Dev and DevOps time includes Google Cloud expert consultation for Datastream configuration, SE2 compatibility validation, and troubleshooting (estimated 0.5-1 day embedded in Option B)
- **Assumptions**:
  - Vendor response times are reasonable (24-48 hours for non-critical questions)
  - Critical issues get escalated support
  - Majority of configuration can be done independently using documentation
  - Vendor consultation is for validation, best practices, and edge cases

**If vendor support is not available or significantly delayed**, timeline may extend by 1-2 weeks while waiting for responses. In this case, we'll work on parallel activities (documentation, other option testing) to minimize impact.

### 3.3 Timeline

**Total Duration:** 4-5 weeks (calendar time)

| Week         | Activities                                       | Deliverables                              |
| ------------ | ------------------------------------------------ | ----------------------------------------- |
| **Week 1**   | Kickoff, Access & Validation, Options Review     | Access confirmed, options validated       |
| **Week 2**   | Option A (Striim) Implementation and Testing     | Striim PoC complete, performance data     |
| **Week 3**   | Option B (Datastream) Implementation and Testing | Datastream PoC complete, performance data |
| **Week 4-5** | ADR Documentation, Meetings, Rollout Planning    | Final recommendation, rollout plan        |

**Note:** Some activities can overlap (e.g., Options Review while foundations are being set up).

---

## 4. Technical Approach

### 4.1 Option A: Striim → GCP Pub/Sub/Object Store

**Architecture (Client Infrastructure):**
```
Oracle DB (Nagel On-Prem) → Existing Striim → Pub/Sub and/or Object Store (GCS)
```

**Key Activities:**
1. Assess existing Striim deployment and configuration
2. Configure Pub/Sub and/or Object Store (GCS) writers in Striim
3. Configure CDC for "sendung" table
4. Run INSERT/UPDATE/DELETE operations and validate capture
5. Measure latency and throughput
6. Test failure scenarios (network interruption, redo log gap)
7. Document operational procedures

**Key Validations:**
- Striim can capture Oracle changes and publish to Pub/Sub and/or Object Store
- Latency meets requirements (target: < 5 seconds 95th percentile)
- Operational complexity is manageable
- Cost model for production (obtain Striim licensing costs from Nagel IT)

### 4.2 Option B: Oracle → GCP Datastream → Pub/Sub/Object Store

**Architecture (Client Infrastructure):**
```
Oracle DB (Nagel On-Prem) → Datastream → GCS (Object Store) and/or Pub/Sub
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

### 4.3 Comparative Evaluation Criteria

| Criterion                   | Weight | Notes                                                        |
| --------------------------- | ------ | ------------------------------------------------------------ |
| **Technical Feasibility**   | High   | SE2 compatibility, performance, reliability                  |
| **Cost (PoC + Production)** | High   | Licensing costs (Striim) vs. volume-based costs (Datastream) |
| **Operational Complexity**  | Medium | Setup, maintenance, monitoring, troubleshooting              |
| **Strategic Alignment**     | Medium | Existing Striim investment vs. GCP-native strategy           |
| **Vendor Lock-in Risk**     | Low    | Dependency on third-party (Striim) vs. GCP                   |
| **Time to Production**      | Medium | Effort to deploy on Nagel infrastructure                     |

---

## 5. Key Technical Challenges & Mitigations

### 5.1 Oracle Standard Edition 2 Limitations

**Challenge:** Oracle SE2 does not support all LogMiner features:
- No Continuous LogMiner (streaming API)
- Limited concurrent LogMiner sessions
- Supplemental Logging restrictions

**Impact:** Datastream (and potentially Striim) may have degraded functionality or incompatibility on SE2.

**Mitigation:**
- **Phase 1**: Validate Datastream SE2 support via Google documentation and support ticket
- **PoC**: Test both options with clean Oracle SE2 install
- **Fallback**: If Datastream incompatible with SE2, Striim becomes primary option (already proven on Nagel SE2 branches)

### 5.2 Redo Log Retention (~1 hour on some branches)

**Challenge:** Nagel branches (e.g., D33) have ~1 hour redo log retention due to space constraints.

**Impact:** Network outage > 1 hour results in transaction sequence loss, requiring full initial load.

**Mitigation:**
- Design CDC solution with recovery/resync capability
- Document operational procedures for full reload scenarios
- **PoC**: Test redo log gap scenario and document recovery steps

### 5.3 Dual-CDC Risk

**Challenge:** Running both Striim and Datastream simultaneously risks data conflicts and infrastructure complexity.

**Mitigation:**
- **Clear Decision via ADR**: Select one option based on PoC results
- **Decommissioning Plan**: Before production rollout of new option, coordinate Striim retirement with Nagel IT
- **Database Separation**: Using separate Oracle databases for Striim and Datastream PoCs avoids dual-CDC conflicts

### 5.4 Cost Uncertainty

**Challenge:** Striim licensing costs for extending to Pub/Sub are unknown. New Striim deployment costs $9,600+/month.

**Impact:** If Striim extension costs are prohibitive, Datastream may be more cost-effective.

**Mitigation:**
- **Immediate Action**: Obtain Striim cost data from Nagel IT (Matt Wilkinson) before/during PoC
- **Cost Modeling**: Project production costs for both options based on:
  - Striim: licensing + infrastructure
  - Datastream: per-GiB pricing (~$2/GiB) based on expected data volume

---

## 6. Deliverables

### 6.1 Technical Documentation

1. **PoC Setup Guide**
   - Oracle database installation and configuration
   - Striim deployment and configuration guide
   - Datastream setup and configuration guide
   - GCP infrastructure (Pub/Sub, GCS, networking) setup

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

### 6.2 Architecture Decision Record (ADR)

Comprehensive ADR document including:

1. **Context & Requirements**
   - Business objectives and constraints
   - Technical environment (Oracle versions, editions, infrastructure)

2. **Options Evaluated**
   - Option A: Striim → Pub/Sub/Object Store/Object Store (detailed analysis)
   - Option B: Datastream → Pub/Sub/Object Store (detailed analysis)
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

### 6.3 Production Rollout Plan

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

### 6.4 Cost Analysis Document

1. **PoC Costs**
   - P3 professional services (~19.5 days effort)
   - GCP infrastructure costs (Pub/Sub, GCS, Datastream)
   - Striim trial/evaluation costs (if applicable)

2. **Production Cost Projections**
   - **Striim Option**: Licensing costs + infrastructure costs per branch
   - **Datastream Option**: Per-GiB costs based on projected data volume + infrastructure
   - **12-Month Total Cost of Ownership** for each option

3. **Cost Comparison**
   - Break-even analysis
   - Sensitivity analysis (data volume variations)
   - Hidden costs (operational overhead, training)

---

## 7. Cost Breakdown

### 7.1 PoC Costs

**P3 Professional Services:**
- **~19.5 days @ [your daily rate]**
  - Architect: 3.0 days
  - DB-Dev: 9.0 days
  - DevOps: 6.5 days
  - PM: 1.0 day
- **Total P3 Fees: [calculate: 19.5 days × daily rate]**

**Infrastructure Costs (GCP - PoC Duration: 4-5 weeks):**
| Component               | Estimated Cost |
| ----------------------- | -------------- |
| Pub/Sub (test volume)   | $20-50         |
| Cloud Storage (GCS)     | $10-30         |
| Datastream (test)       | $50-150        |
| Networking (marginal)   | $10-20         |
| **Total GCP PoC Costs** | **$90-250**    |

**Total PoC Investment: P3 Fees + GCP Costs**

**Note:** Oracle databases and Striim infrastructure already exist at Nagel, no additional provisioning costs.

### 7.2 Production Cost Estimates (Per Month)

**Option A: Striim → Pub/Sub/Object Store**
| Component             | Estimated Monthly Cost           | Notes                                         |
| --------------------- | -------------------------------- | --------------------------------------------- |
| Striim Licensing      | **[TBD - obtain from Nagel IT]** | Extension costs for Pub/Sub target - CRITICAL |
| Striim Infrastructure | $0 (already deployed)            | Existing on-prem infrastructure               |
| GCP Pub/Sub           | $200-500                         | Based on production volume                    |
| GCP Networking        | $50-100                          | VPN/Interconnect                              |
| **Total (Striim)**    | **$250-600 + Striim licensing**  | Licensing cost is key variable                |

**Option B: Datastream → Pub/Sub/Object Store**
| Component              | Estimated Monthly Cost | Notes                                                |
| ---------------------- | ---------------------- | ---------------------------------------------------- |
| Datastream             | $200-1,000             | ~$2/GiB; assumes 100-500 GiB/month (validate in PoC) |
| Cloud Storage (GCS)    | $20-100                | Object Store for CDC events                          |
| Pub/Sub                | $200-500               | Production volume                                    |
| Networking             | $50-100                | VPN/Interconnect                                     |
| **Total (Datastream)** | **$470-1,700**         | Volume-dependent pricing                             |

**Note:** Actual costs depend on data volume, change frequency, and table count. PoC will provide accurate projections based on representative data.

### 7.3 Production Rollout Costs (Estimated)

**Note:** Detailed rollout effort estimates and timeline are **TBD with Martin**. The following provides preliminary estimates based on typical CDC deployments:

**Per-Branch Deployment Effort:**
- Configuration and setup: 1-2 days
- Testing and validation: 0.5-1 day
- Cutover and monitoring: 0.5-1 day
- **Total per branch: 2-4 days**

**For ~30 Oracle branches:**
- **Total Effort: 60-120 days** (can be parallelized)
- **Timeline: 8-12 weeks** with proper planning and resource allocation

**Rollout Costs:**
- P3 Professional Services: 60-120 days @ daily rate
- Nagel IT Coordination: ~30-50 days (access, validation, approvals)
- GCP Infrastructure Scale-up: Marginal costs (Pub/Sub, networking scale linearly)

---

## 8. Risks & Mitigation

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

## 9. Success Metrics & Acceptance Criteria

### 9.1 PoC Success Metrics

| Metric                           | Target                        | Measurement                                              |
| -------------------------------- | ----------------------------- | -------------------------------------------------------- |
| **CDC Event Capture Accuracy**   | 100%                          | Validate all INSERT/UPDATE/DELETE captured               |
| **End-to-End Latency**           | < 5 seconds (95th percentile) | Measure from Oracle commit to Pub/Sub/Object Store write |
| **Initial Load Performance**     | < 1 hour for test dataset     | Validate backfill mechanism                              |
| **Recovery Time (Redo Log Gap)** | < 30 minutes                  | Test resync after simulated outage                       |
| **SE2 Compatibility**            | Full functionality            | Validate on Oracle SE2 instance                          |
| **Operational Complexity**       | Manageable by Ops team        | Documented procedures, clear runbooks                    |
| **Cost Predictability**          | ±20% accuracy                 | Production cost projections validated                    |

### 9.2 ADR Acceptance Criteria

- [ ] Both options evaluated with objective criteria
- [ ] Performance data collected and analyzed
- [ ] Cost comparison completed (PoC + 12-month production projection)
- [ ] Operational complexity assessed for both options
- [ ] Clear recommendation with justification
- [ ] Risk assessment and mitigation strategies documented
- [ ] Stakeholder review and approval obtained

### 9.3 Rollout Plan Acceptance Criteria

**Note:** Detailed acceptance criteria are **TBD with Martin**. Preliminary criteria include:

- [ ] Phase-by-phase deployment strategy framework defined
- [ ] Preliminary per-branch effort estimates provided
- [ ] Indicative rollout timeline projected
- [ ] Key prerequisites and dependencies identified
- [ ] Risk mitigation and rollback procedures documented
- [ ] Decommissioning plan for non-selected option (if applicable)

---

## 10. Assumptions & Dependencies

### 10.1 Assumptions

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

### 10.2 Dependencies

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

## 11. Next Steps

### 11.1 Immediate Actions (Pre-Kickoff)

| Action                                                                                        | Owner                     | Deadline |
| --------------------------------------------------------------------------------------------- | ------------------------- | -------- |
| Approve PoC offer and budget                                                                  | Christian Lang (Nagel IT) | [TBD]    |
| Provide dedicated/separate PoC environment (not TEST)                                         | Nagel IT / Robert Zanter  | Week 1   |
| Obtain Striim cost data (current + Object Store extension)                                    | Matt Wilkinson (Nagel IT) | Week 1   |
| Obtain Striim performance metrics (throughput, load)                                          | Matt Wilkinson (Nagel IT) | Week 1   |
| Identify and provide access to ONE Striim-connected branch Oracle database in PoC environment | Robert Zanter (Nagel IT)  | Week 1   |
| Identify and provide access to ONE non-Striim branch Oracle database (SE2) in PoC environment | Robert Zanter (Nagel IT)  | Week 1   |
| Provide expected Sendungen volume data (per day, peak times)                                  | Nagel IT                  | Week 1   |
| Provide Nagel GCP project access for P3 team                                                  | Nagel IT DevOps           | Week 1   |
| Provide Striim access and credentials                                                         | Matt Wilkinson (Nagel IT) | Week 1   |
| Schedule kickoff meeting                                                                      | P3 PM                     | Week 1   |
| Initiate Datastream SE2 validation with Google                                                | P3 Architect              | Week 1   |

### 11.2 Kickoff Meeting Agenda (1.5 hours)

1. **Project Objectives & Success Criteria** (15 min)
   - Review business goals and technical requirements
   - Confirm success metrics and acceptance criteria

2. **PoC Scope & Constraints** (15 min)
   - Nagel IT infrastructure approach (not isolated sandbox)
   - Fully fledged database with single table focus ("sendung")
   - TMS branch databases only
   - Out-of-scope items

3. **Technical Approach & Options** (30 min)
   - Option A: Striim → Pub/Sub/Object Store
   - Option B: Datastream → Pub/Sub/Object Store
   - Evaluation criteria and trade-offs

4. **Timeline & Effort** (15 min)
   - 4-5 week PoC timeline
   - 23-day effort breakdown by role
   - Key milestones and deliverables

5. **Roles, Responsibilities & Communication** (15 min)
   - P3 team roles (Architect, DB-Dev, DevOps, PM)
   - Nagel IT stakeholders (Christian, Matt, Robert)
   - Communication plan and meeting cadence (weekly syncs)

6. **Dependencies & Next Steps** (10 min)
   - Access requirements and approvals
   - Striim cost data and Datastream SE2 validation
   - Immediate action items

**Proposed Kickoff Date:** [TBD - within 1 week of offer approval]

---

## 12. Appendix

### 12.1 Key Stakeholders

| Name           | Organization | Role           | Responsibility                                          |
| -------------- | ------------ | -------------- | ------------------------------------------------------- |
| Christian Lang | Nagel IT     | Decision Maker | Strategic direction, final ADR approval                 |
| Matt Wilkinson | Nagel IT     | Striim Lead    | Striim cost data, technical guidance                    |
| Robert Zanter  | Nagel IT     | DBA Lead       | Oracle technical validation, LogMiner insights          |
| Matthias Max   | P3           | Architect      | PoC architecture, ADR authoring, evaluation             |
| [TBD]          | P3           | DB-Dev Lead    | Oracle setup, CDC configuration, testing                |
| [TBD]          | P3           | DevOps Lead    | GCP infrastructure, networking, integration             |
| [TBD]          | P3           | PM             | Project coordination, reporting, stakeholder management |

### 12.2 Reference Documents

- [Original Request (2025-12-01)](../02_Communication/Mails_1/2025-12-01-original-request.md)
- [Consolidated Requirements](../02_Communication/Mails_1/00_Consolidated-Requirements.md)
- [Architecture Status Update (2026-01-16)](../02_Communication/Mails_3/2026-01-16-architecture-status-intermediate.md)
- [Architecture Evaluation](../03_Exploration/2026-01-16-status-wrapup/00_Architecture-Evaluation.md)
- [P3 Standard PoC Template](../03_Exploration/2026-02-10-final-poc-offer/)

### 12.3 Glossary

| Term               | Definition                                                                          |
| ------------------ | ----------------------------------------------------------------------------------- |
| **ADR**            | Architecture Decision Record - document capturing options, evaluation, and decision |
| **CDC**            | Change Data Capture - technology to track and capture database changes              |
| **LogMiner**       | Oracle feature to read redo logs for change tracking                                |
| **SE2**            | Oracle Standard Edition 2 (vs. Enterprise Edition) - has LogMiner limitations       |
| **Redo Log**       | Oracle transaction log used for recovery and CDC                                    |
| **Pub/Sub**        | Google Cloud Pub/Sub messaging service                                              |
| **Datastream**     | Google Cloud service for database replication and CDC                               |
| **Striim**         | Third-party real-time data integration platform (currently deployed at Nagel)       |
| **Object Store**   | Cloud storage (e.g., GCS) for persisting CDC events                                 |
| **GCS**            | Google Cloud Storage                                                                |
| **End-to-End PoC** | PoC validates full CDC flow on actual client infrastructure (not isolated sandbox)  |

### 12.4 Oracle SE2 LogMiner Limitations

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

## 13. Approval

| Role                | Name            | Signature | Date |
| ------------------- | --------------- | --------- | ---- |
| **Client Approver** | Christian Lang  |           |      |
| **P3 Project Lead** | Martin Dittmann |           |      |

---

**Document Version History:**

| Version | Date       | Author       | Changes                                                          |
| ------- | ---------- | ------------ | ---------------------------------------------------------------- |
| 1.0     | 2026-02-10 | Matthias Max | Initial draft                                                    |
| 2.0     | 2026-02-10 | Matthias Max | Aligned with P3 standard PoC template, adjusted scope and effort |

