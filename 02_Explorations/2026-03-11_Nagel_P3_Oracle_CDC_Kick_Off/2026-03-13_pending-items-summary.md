# Oracle CDC POC - Pending Items Summary

**Date:** 2026-03-13
**Status:** Awaiting Nagel-side prerequisites

---

## ✅ Completed (P3 Side)

### GCP Infrastructure Setup
- **Status:** Done (PBI 123445)
- **Deliverables:**
  - `oracle-striim-bucket-poc` - Created
  - `oracle-datastream-bucket-poc` - Created
  - `new-dispo-oracle-cdc-datastream-sendung` Datastream instance - Provisioned
- **Environment:** TEST / WL5
- **Note:** Temporary setup for PoC only, will be deleted post-POC

### Workshop Scheduling
- **Status:** Done
- **Date:** Monday, March 16, 2026, 14:30-15:00
- **Title:** Follow-up | Oracle CDC PoC

---

## ⏳ Pending (Critical Path)

### 1. Database Selection & Availability
**Owner:** Matt Wilkinson, Ron, Thomas
**Status:** Awaiting confirmation
**Required:**
- Confirm specific Oracle databases for POCs (candidates: 1034, 1060)
- Verify database availability timeline
- Assess current configuration status

### 2. Oracle Prerequisites Configuration
**Owner:** Thomas, Matt Wilkinson
**Status:** Awaiting setup
**Required:**
- ARCHIVELOG mode verification/enablement
- Supplemental logging configuration
- CDC user creation with required grants (LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE)
- LogMiner setup for Datastream
- Character set compatibility investigation results

### 3. Infrastructure Capacity Assessment
**Owner:** Matt Wilkinson, Thomas
**Status:** Awaiting confirmation
**Required:**
- Disk space assessment for log retention
- Network connectivity validation (GCP ↔ Oracle)
- Redo log cycling behavior analysis

### 4. Workshop Scheduling
**Owner:** Martin
**Status:** ✅ Scheduled
**Date:** Monday, March 16, 2026
**Time:** 14:30 - 15:00
**Title:** Follow-up | Oracle CDC PoC
**Purpose:** Technical setup walkthrough and POC kickoff

### 5. Database Sizing & Transaction Details
**Owner:** Matt Wilkinson
**Status:** Awaiting information
**Required:**
- Current transaction volume metrics
- Expected throughput requirements
- Peak load characteristics

---

## 🤝 Coordination Required

### 6. OMS Test Data Generation
**Owners:** Matthias (P3), Thomas (Nagel)
**Status:** Coordination pending
**Approach TBD:**
- Option A: Copy production data from 1060/1034
- Option B: Application-driven test data generation via OMS
**Decision needed:** Once databases confirmed

### 7. Success Criteria Definition
**Owners:** Matthias, Matt Wilkinson, Christian
**Status:** Not yet defined
**Missing:**
- Throughput targets (events/sec or rows/min)
- Maximum acceptable latency
- Volume requirements for POC validation
- Stability duration requirements (hours/days)

### 8. POC Evaluation Framework
**Owners:** Matthias, Christian, Martin
**Status:** Not yet defined
**Missing:**
- Decision criteria for Striim vs Datastream selection
- Weighting factors (cost vs consistency vs effort vs risk)
- Decision maker and timeline for final selection

---

## 📋 Open Questions

### Technical
1. **Datastream Documentation:** Is the shared link the correct reference for Oracle setup?
2. **Character Set Handling:** Status of Poland character set issue investigation?
3. **Load Testing Approach:** How will we execute updates on on-premise Oracle from GCP (VM provisioning needed)?
4. **Network Architecture:** Direct connection vs proxy for CDC replication?

### Process
5. **Communication Channel:** Preferred platform for updates (Teams group chat, email thread, other)?
6. **Resource Availability:** DBA team availability for setup and troubleshooting?
7. **Timeline Validation:** Is target "this week for manual confirmation" still realistic given pending prerequisites?
8. **Load Test Duration:** Confirm one-week duration for order duplication test (pending database cleanup process)?

---

## 🎯 Immediate Next Steps

### Before Workshop (Monday, March 16)
- **P3:** Ready and waiting for Oracle database availability
- **Nagel Infrastructure:** Complete database selection and prerequisite assessment
- **Nagel DBA:** Verify/configure ARCHIVELOG, supplemental logging, CDC user
- **Matt Wilkinson:** Share Oracle prerequisite status and database sizing details

### Pre-Workshop
- **Matt Wilkinson:** Share Oracle prerequisite status and database sizing details
- **Thomas/Eric:** Confirm test database configuration readiness
- **Matthias:** Prepare technical setup documentation for workshop

### Post-Workshop
- **All:** Execute POCs in parallel (Striim + Datastream)
- **All:** Define success criteria and evaluation framework
- **All:** Begin OMS-driven load testing once manual validation complete

---

## 🔴 Blockers

1. **Database availability** - Blocks both POC streams
2. **Oracle prerequisites** - Blocks Datastream POC specifically (LogMiner, supplemental logging)

---

## 📊 POC Readiness Matrix

| Component | P3/GCP Side | Nagel/Oracle Side |
|-----------|-------------|-------------------|
| Storage Buckets | ✅ Ready | N/A |
| Datastream Instance | ✅ Ready | ⏳ Awaiting Oracle config |
| Striim Setup | ✅ Ready (pending buckets only) | ⏳ Awaiting database |
| Test Databases | N/A | ⏳ Selection pending |
| Network Connectivity | ✅ Assumed ready | ⏳ Validation needed |
| Oracle Prerequisites | N/A | ⏳ Configuration needed |
| Test Data Strategy | 🔄 Coordination needed | 🔄 Coordination needed |

**Legend:** ✅ Complete | ⏳ Pending | 🔄 In coordination | N/A Not applicable

---

## Notes

- GCP infrastructure is fully ready from P3 side
- Critical path is now on Nagel infrastructure team (database selection + Oracle configuration)
- Workshop scheduling is essential to align on technical details and POC execution approach
- Success criteria definition is urgent to ensure POC validation clarity
