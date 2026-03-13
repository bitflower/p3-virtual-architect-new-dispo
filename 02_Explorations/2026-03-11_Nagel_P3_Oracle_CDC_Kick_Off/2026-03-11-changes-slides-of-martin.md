# POC-Tasks Slide - Recommended Changes

**Date:** 2026-03-11
**Reference:** Yosif's estimation documents

---

## Issues with Current Slide

### Major Missing Tasks

#### Option A: Striim
- ❌ **No mention of Adapter implementation** (Task 6: 16h realistic - nearly HALF the effort)
  - "Implement new interfaces to make an Adapter and normalize event data structure between DataStream and Striim"
  - Without this, the downstream pipeline won't work
- Missing: Creating GCP Service Account for Striim (Task 3)
- Missing: Actual Striim client/app configuration (Task 4)

#### Option B: Datastream
- ❌ **No mention of GCP environment setup** (Task 2: 12h realistic - BIGGEST SINGLE TASK, ~20% of total effort)
  - "Setting up the provided GCP environment with all the needed infrastructure for enabling CDC (DataStream, CloudStorage, PubSub, CloudFn etc.) including integration with a dev PostgresDB"
- Missing: Access requirements coordination (Task 1)
- Missing: Cloud Storage Bucket adjustments (Task 5)
- Missing: Cloud Function adjustments for Oracle+Postgres (Task 6)
- Missing: Database load simulation (Task 8: requires solving Oracle access from GCP)
- Missing: Redo lag gap testing and recovery documentation (Task 10)
- Missing: Documentation deliverables (Tasks 12, 15, 16, 17: Setup Guide, ADR, Rollout Plan, Cost Analysis)

### Conceptual Issues

1. **"Validate Datastream compatibility with Oracle SE2"** (B.1)
   - Not in Yosif's tasks
   - Prerequisites assume Oracle compatibility
   - Actual Task 1 is "Access requirements coordination"

2. **"Test under real Oracle Standard Edition 2 conditions"** (Common Scope)
   - Yosif's doc says "development/testing" without specifying SE2
   - Is SE2 a confirmed requirement?

3. **Tasks 4-5 are outcomes/assessments, not tasks:**
   - A.4: "Test basic failure and recovery scenarios" - Not in Striim doc
   - A.5: "Assess operational effort..." - Outcome, not a task
   - B.5: "Assess operational simplicity..." - Outcome, not a task

4. **"Execute CDC for representative/separate Oracle branch database"**
   - Sounds like production-scale
   - Yosif's docs say "Dev testing" (basic validation)
   - Task 8 (load simulation) is separate and requires special setup

### Prerequisites Not Highlighted

Nagel-side blockers not shown on slide:

**For DataStream:**
1. Oracle database with ARCHIVELOG enabled
2. Supplemental logging enabled
3. Dedicated CDC user with LogMiner privileges
4. Network connectivity: GCP ↔ on-premise Oracle (Task 3: 0h CAL, all Nagel)
5. Dedicated GCP environment

**For Striim:**
1. Striim version confirmation
2. Striim deployment type and access strategy

---

## Recommended Changes (Space-Efficient)

### COMMON SCOPE
- Validate end-to-end CDC functionality (INSERT, UPDATE, DELETE from Oracle to Google Cloud Object Store)
- Test under real Oracle Standard Edition 2 conditions
- Measure latency, stability, and operational behavior
- Document findings in a structured, decision-ready format

### /// A: Striim
**Oracle → Striim → Google Cloud Object Store**

1. Validate Striim setup and configure GCP service account
2. Configure Google Cloud Object Storage as CDC target
3. **Develop adapter to normalize Striim/Datastream output formats**
4. Execute CDC for representative Oracle branch database
5. Performance testing and operational documentation

### /// B: Datastream
**Oracle → Google Cloud Datastream → Google Cloud Object Store**

1. Coordinate Oracle database access and CDC prerequisites
2. **Setup GCP CDC infrastructure integrated with existing Postgres pipeline**
3. Configure Datastream connection profiles and Oracle CDC streams
4. **Implement database load simulation and execute CDC testing**
5. Performance measurement and operational documentation (Setup Guide, ADR, Rollout Plan)

---

## Key Improvements

**What's now visible:**
- ✅ Adapter requirement (Striim's hidden complexity - 16h)
- ✅ GCP infrastructure setup (Datastream's biggest task - 12h)
- ✅ Integration with Postgres pipeline (critical architectural point)
- ✅ Load simulation complexity (access challenge)
- ✅ Documentation deliverables mentioned

**What's consolidated:**
- Multiple config tasks → "Setup/Configure" items
- Multiple docs → "operational documentation" with key deliverables listed
- Testing tasks → grouped by type

**Space impact:** Similar number of items (5 each), but more accurate

---

## Alternative: Add Prerequisites Section

If space allows, consider adding a callout box:

```
NAGEL PREREQUISITES (Required before POC start):
- Oracle DB: ARCHIVELOG, supplemental logging, CDC user with LogMiner privileges
- Network: GCP ↔ on-premise Oracle connectivity configured
- Environment: Dedicated GCP environment (not blocking TEST)
```

---

## Source Documents

- `WIKI/Nagel-CAL-Disposition.wiki/Planning/Estimations/CDC-Oracle-Support-POC-Striim-Option-Estimates.md`
- `WIKI/Nagel-CAL-Disposition.wiki/Planning/Estimations/CDC-Oracle-Support-POC-DataStream-Option-Estimates.md`
