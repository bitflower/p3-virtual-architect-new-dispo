# Oracle CDC PoC - Project Offer

**Project:** Oracle Change Data Capture - Proof of Concept
**Date:** 2026-02-10
**Version:** 1.0 - Draft for Review
**Prepared by:** P3 Team (Matthias Max)
**Client:** Nagel IT
**Decision Maker:** Christian Lang

---

## 1. Executive Summary

### 1.1 Background

NewDispo requires Oracle CDC integration to be deployed independently from Project G. Striim is currently deployed on 5 Oracle branches (historically on all branches) for CDC purposes. To determine the optimal path forward, a comprehensive Proof of Concept is required to evaluate two approaches:

1. **Option A: Striim → GCP Pub/Sub** (extending existing infrastructure)
2. **Option B: Oracle → GCP Datastream → Pub/Sub** (GCP-native solution)

### 1.2 Project Objectives

- Validate end-to-end CDC functionality on client infrastructure for both options
- Determine implementation effort, costs, and operational requirements for each option
- Define clear rollout steps for global deployment across all Oracle branches
- Provide decision-making basis for strategic CDC solution selection

### 1.3 Success Criteria

- Both PoC options successfully capture Oracle changes and publish to GCP Pub/Sub
- Performance, reliability, and operational requirements validated on client infrastructure
- Clear documentation of implementation steps, costs, and rollout strategy
- Validated compatibility with Oracle Standard Edition 2 (branch databases)
- Defined migration/decommissioning plan for non-selected option

---

## 2. PoC Scope

### 2.1 In Scope

**Technical Scope:**
- Configuration and testing of Striim → Pub/Sub integration
- Configuration and testing of Oracle → Datastream → Pub/Sub integration
- End-to-end validation on client infrastructure (on-premises Oracle to GCP)
- Performance and latency measurements
- Oracle Standard Edition 2 compatibility validation
- Failover and recovery testing (redo log gap scenarios)
- Integration with existing NewDispo consumers

**Deliverables:**
- Working PoC for both options on client infrastructure
- Comparative evaluation document (performance, cost, complexity, operations)
- Detailed implementation guide for both options
- Global rollout strategy and step-by-step plan
- Effort estimates and timeline for full production rollout
- Risk assessment and mitigation strategies
- Operational runbooks for both solutions

### 2.2 Out of Scope

- Production deployment across all branches (covered in rollout plan)
- Cross-Dock/CALSuite integration
- Oracle database schema migrations or modifications
- Development environment setup for P3 team (covered in separate workstream)
- Full decommissioning of non-selected option (plan provided, execution separate)

### 2.3 Test Environment

**Oracle Sources:**
- 1x Enterprise Edition database (HQ representative)
- 1x Standard Edition 2 database (branch representative)
- Minimum 3-5 tables from NewDispo table set

**GCP Environment:**
- Pub/Sub topics and subscriptions
- Cloud Functions for Datastream option
- Monitoring and logging setup
- Test consumer application (simplified NewDispo logic)

---

## 3. Technical Approach

### 3.1 Option A: Striim → GCP Pub/Sub

**Architecture:**
```
Oracle DB (On-Prem) → Existing Striim → GCP Pub/Sub → NewDispo
```

**PoC Activities:**
1. Assessment of existing Striim deployment and configuration
2. Configuration of Pub/Sub writer in Striim
3. Network connectivity validation (on-prem to GCP)
4. Table and supplemental logging setup
5. Initial load and CDC stream validation
6. Performance and latency testing
7. Failure scenario testing (network outage, redo log gap)
8. Cost analysis (licensing implications of Pub/Sub target)

**Key Validations:**
- Existing Striim can publish to Pub/Sub with acceptable latency
- No additional licensing costs for Pub/Sub target (or quantify if applicable)
- Operational stability on client infrastructure
- SE2 compatibility (already proven, but revalidate)

### 3.2 Option B: Oracle → GCP Datastream → Pub/Sub

**Architecture:**
```
Oracle DB (On-Prem) → Datastream Agent → GCS → Cloud Function → Pub/Sub → NewDispo
```

**PoC Activities:**
1. Datastream agent deployment planning (on-prem or GCP)
2. Oracle Standard Edition 2 compatibility validation with Google
3. Datastream connection profile and stream configuration
4. GCS bucket and Cloud Function setup
5. Pub/Sub integration and message transformation
6. Initial backfill and CDC stream validation
7. Performance and latency testing (including GCS intermediate step)
8. Failure scenario testing
9. Cost projection based on data volume

**Key Validations:**
- Datastream supports Oracle SE2 with required LogMiner features
- End-to-end latency meets NewDispo requirements
- Operational overhead is acceptable (managed service benefits)
- Cost model is sustainable at scale (per-GiB pricing)

### 3.3 Critical Constraints

| Constraint | Impact | Mitigation Strategy |
|------------|--------|---------------------|
| **Oracle SE2 limitations** | LogMiner features may be restricted on branch databases | Explicit validation in PoC; Striim as fallback |
| **Redo log retention (~1 hour)** | Short recovery window for CDC catchup | Design for full resync capability; monitoring and alerting |
| **Dual-CDC risk** | Running both Striim and Datastream risks conflicts | Clear decommissioning plan before production rollout |
| **Existing Striim deployment** | Infrastructure stability concerns | Assess current state; plan for improvements if selected |

---

## 4. Project Phases & Timeline

### Phase 1: Preparation & Setup (1-2 weeks)

**Activities:**
- Kickoff meeting with stakeholders (Nagel IT, P3, GCP contacts)
- Finalize PoC requirements and success criteria
- Obtain necessary access (Oracle, Striim, GCP environments)
- Validate Oracle Standard Edition 2 compatibility with Google (Datastream)
- Obtain Striim cost data for Pub/Sub extension
- Set up test Oracle databases (EE and SE2)
- Prepare GCP infrastructure (Pub/Sub, Cloud Functions)

**Effort Estimate:**
- P3: 40-60 hours
- Nagel IT: 20-30 hours (access, environment setup)

### Phase 2: PoC Implementation - Option A (Striim) (1-2 weeks)

**Activities:**
- Assess existing Striim deployment
- Configure Pub/Sub writer
- Set up table replication for test tables
- Initial load and CDC validation
- Performance testing and tuning
- Failure scenario testing
- Document findings and operational procedures

**Effort Estimate:**
- P3: 60-80 hours
- Nagel IT: 15-20 hours (Oracle access, validation)

### Phase 3: PoC Implementation - Option B (Datastream) (2-3 weeks)

**Activities:**
- Deploy Datastream agent (if on-prem) or configure connection
- Set up Datastream stream for Oracle sources
- Configure GCS bucket and Cloud Functions
- Implement Pub/Sub integration
- Initial backfill and CDC validation
- Performance testing and latency analysis
- Failure scenario testing
- Document findings and operational procedures

**Effort Estimate:**
- P3: 80-100 hours
- Nagel IT: 15-20 hours (Oracle access, validation)

### Phase 4: Evaluation & Documentation (1 week)

**Activities:**
- Comparative analysis (performance, cost, complexity, operations)
- Risk assessment for both options
- Global rollout plan development
- Effort estimation for full production deployment
- Final presentation and recommendations
- Stakeholder decision meeting

**Effort Estimate:**
- P3: 30-40 hours
- Nagel IT: 10-15 hours (review, decision making)

### Phase 5: Rollout Planning (1 week)

**Activities:**
- Detailed rollout strategy for selected option
- Branch-by-branch deployment plan
- Striim decommissioning plan (if Datastream selected)
- Operational runbooks and monitoring setup
- Training materials for operations team
- Risk mitigation and rollback procedures

**Effort Estimate:**
- P3: 30-40 hours
- Nagel IT: 10-15 hours (validation, process alignment)

---

## 5. Effort Summary

### 5.1 Total Effort Estimates

| Phase | P3 Effort | Nagel IT Effort | Duration |
|-------|-----------|----------------|----------|
| **Phase 1: Preparation** | 40-60h | 20-30h | 1-2 weeks |
| **Phase 2: Striim PoC** | 60-80h | 15-20h | 1-2 weeks |
| **Phase 3: Datastream PoC** | 80-100h | 15-20h | 2-3 weeks |
| **Phase 4: Evaluation** | 30-40h | 10-15h | 1 week |
| **Phase 5: Rollout Planning** | 30-40h | 10-15h | 1 week |
| **TOTAL** | **240-320h** | **70-100h** | **6-9 weeks** |

**Notes:**
- Phases 2 and 3 can potentially overlap partially to optimize timeline
- Actual duration depends on access to environments, stakeholder availability, and Oracle compatibility findings
- Contingency buffer recommended for unforeseen technical challenges (especially SE2 compatibility)

### 5.2 Post-PoC Rollout Effort (Estimated)

Based on the selected option, production rollout effort:

**Per Branch Deployment:**
- Configuration and setup: 8-12 hours
- Testing and validation: 4-6 hours
- Cutover and monitoring: 4-6 hours
- **Total per branch: 16-24 hours**

**For 30 branches (example):**
- Total rollout effort: 480-720 hours (P3)
- Can be parallelized to 4-6 weeks with proper planning

---

## 6. Cost Breakdown

### 6.1 PoC Costs

**P3 Professional Services:**
- 240-320 hours @ [your hourly rate]
- **Total P3 Fees: [calculate based on rate]**

**Infrastructure Costs (GCP - during PoC):**
- Pub/Sub: ~$40-100/month (test volume)
- Cloud Functions: ~$20-50/month
- GCS: ~$20-50/month
- Datastream: ~$50-150 (test data volume)
- **Total GCP PoC costs: ~$130-350**

**Striim Costs:**
- Existing deployment costs (obtain from Nagel IT)
- Potential extension costs for Pub/Sub (TBD - critical for evaluation)

### 6.2 Ongoing Production Costs (Estimates)

**Option A: Striim**
- Current costs: [TBD - obtain from Nagel IT]
- Extension costs for Pub/Sub: [TBD - obtain from Striim vendor]
- Infrastructure: Minimal (already deployed)
- **Total: [TBD pending cost data]**

**Option B: Datastream**
- Datastream: ~$2/GiB (volume dependent, estimate 100-500 GiB/month = $200-1,000/month)
- GCS storage: ~$20-100/month
- Cloud Functions: ~$50-200/month
- Pub/Sub: ~$200-500/month (production volume)
- **Estimated Total: $470-1,800/month**

**Note:** Actual Datastream costs depend heavily on data volume and change frequency. PoC will provide accurate projections.

---

## 7. Deliverables

### 7.1 PoC Deliverables

1. **Technical Documentation**
   - Architecture diagrams for both options
   - Configuration guides (step-by-step)
   - Network and security setup documentation
   - Performance test results and analysis

2. **Comparative Evaluation Report**
   - Performance comparison (latency, throughput, reliability)
   - Cost analysis (PoC + projected production costs)
   - Operational complexity assessment
   - Risk and dependency analysis
   - Recommendation with justification

3. **Implementation Guides**
   - Striim Pub/Sub configuration guide
   - Datastream setup and integration guide
   - Monitoring and alerting configuration
   - Troubleshooting runbooks

4. **Rollout Strategy Document**
   - Global deployment plan (branch-by-branch)
   - Effort and timeline projections
   - Risk mitigation strategies
   - Rollback procedures
   - Decommissioning plan for non-selected option

5. **Operational Runbooks**
   - Day-to-day operations procedures
   - Failure scenario handling (redo log gap, network outage)
   - Monitoring and alerting setup
   - Maintenance procedures

### 7.2 Knowledge Transfer

- Presentation of findings to stakeholders (2-hour session)
- Technical walkthrough for operations team (4-hour session)
- Q&A and support during decision-making process

---

## 8. Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Datastream incompatible with SE2** | Medium | High | Early validation with Google; Striim as fallback option |
| **Striim extension costs prohibitive** | Medium | High | Obtain cost data in Phase 1; may shift focus to Datastream |
| **Short redo log retention causes issues** | High | Medium | Design for resync capability; document operational procedures |
| **Dual-CDC conflicts if both run simultaneously** | Low | High | Clear separation; decommission plan before production rollout |
| **Performance not meeting NewDispo requirements** | Low | Medium | Performance testing in PoC; tuning and optimization |
| **Access delays to client infrastructure** | Medium | Low | Early engagement with Nagel IT; clear access requirements list |
| **Unforeseen Oracle SE2 limitations** | Medium | Medium | Test on actual SE2 database; validate LogMiner features with DBA |

---

## 9. Assumptions & Dependencies

### 9.1 Assumptions

- Existing network connectivity to GCP is stable and sufficient
- Oracle databases are in archivelog mode and LogMiner is enabled
- Necessary database grants can be obtained for CDC user
- Nagel IT team available for environment access and validation
- Existing Striim deployment can be used for PoC without disruption
- GCP project and permissions are available for P3 team

### 9.2 Dependencies

| Dependency | Owner | Required By |
|------------|-------|-------------|
| Oracle test database access (EE + SE2) | Nagel IT / DBA Team | Phase 1 |
| Striim access and configuration rights | Nagel IT / Matt Wilkinson | Phase 2 |
| Striim cost data (current + extension) | Nagel IT / Matt Wilkinson | Phase 1 |
| GCP project access for P3 team | Nagel IT / Christian Lang | Phase 1 |
| Datastream SE2 compatibility confirmation | Google Cloud Support | Phase 1 |
| Oracle LogMiner feature validation on SE2 | Nagel IT / DBA Team (Robert Zanter) | Phase 1 |
| NewDispo test consumer or mock | P3 / Nagel IT | Phase 2-3 |

---

## 10. Success Metrics

### 10.1 PoC Success Criteria

| Metric | Target |
|--------|--------|
| **End-to-end latency** | < 5 seconds (95th percentile) |
| **Initial load performance** | Complete within acceptable timeframe (< 1 hour for test dataset) |
| **SE2 compatibility** | Full CDC functionality on Standard Edition 2 |
| **Recovery after redo log gap** | Documented resync procedure, < 30 min recovery time |
| **Message accuracy** | 100% CDC event capture (validated through row count comparison) |
| **Operational complexity** | Clearly documented procedures, manageable by ops team |
| **Cost predictability** | Clear cost model with +/- 20% accuracy for production projection |

### 10.2 Decision Criteria

Final recommendation will be based on:
1. **Technical feasibility** (SE2 compatibility, performance, reliability)
2. **Cost** (PoC + projected production costs over 12 months)
3. **Operational complexity** (setup, maintenance, troubleshooting)
4. **Strategic alignment** (GCP-native vs. existing Striim investment)
5. **Risk profile** (dependencies, vendor lock-in, recovery capabilities)

---

## 11. Next Steps

### 11.1 Immediate Actions (Pre-Kickoff)

1. **P3**: Prepare detailed access requirements list
2. **Nagel IT**: Obtain Striim cost data (current + extension for Pub/Sub)
3. **Nagel IT**: Confirm test Oracle database availability (EE + SE2)
4. **P3**: Validate Datastream SE2 support with Google (documentation review)
5. **Nagel IT**: Confirm GCP project access for P3 team

### 11.2 Kickoff Meeting Agenda

- Project objectives and success criteria review
- PoC scope and approach walkthrough
- Environment and access requirements validation
- Timeline and effort commitment confirmation
- Roles and responsibilities clarification
- Communication plan and checkpoints

**Proposed Kickoff Date:** [TBD - within 1 week of offer approval]

---

## 12. Appendix

### 12.1 Key Stakeholders

| Name | Role | Responsibility |
|------|------|----------------|
| Christian Lang | Decision Maker | Strategic direction, final approval |
| Matt Wilkinson | Striim Lead | Striim access, cost data, technical guidance |
| Robert Zanter | DBA Lead | Oracle access, LogMiner validation, grants |
| Matthias Max (P3) | Project Lead | PoC execution, documentation, recommendations |
| [Additional P3 resources] | Engineers | Implementation, testing, documentation |

### 12.2 Reference Documents

- [Original Request (2025-12-01)](../02_Communication/Mails_1/2025-12-01-original-request.md)
- [Consolidated Requirements](../02_Communication/Mails_1/00_Consolidated-Requirements.md)
- [Architecture Status Update (2026-01-16)](../02_Communication/Mails_3/2026-01-16-architecture-status-intermediate.md)
- [Architecture Evaluation](../03_Exploration/2026-01-16-status-wrapup/00_Architecture-Evaluation.md)

### 12.3 Glossary

| Term | Definition |
|------|------------|
| **CDC** | Change Data Capture - technology to track and capture database changes |
| **LogMiner** | Oracle feature to read redo logs for change tracking |
| **SE2** | Oracle Standard Edition 2 (vs. Enterprise Edition) |
| **Redo Log** | Oracle transaction log used for recovery and CDC |
| **Pub/Sub** | Google Cloud Pub/Sub messaging service |
| **Datastream** | Google Cloud service for database replication and CDC |
| **Striim** | Third-party real-time data integration platform |
| **NewDispo** | Target application consuming CDC events |

---

## Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Client Approver | Christian Lang | | |
| P3 Project Lead | Matthias Max | | |

---

**Document Version History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-10 | Matthias Max | Initial draft for review |

