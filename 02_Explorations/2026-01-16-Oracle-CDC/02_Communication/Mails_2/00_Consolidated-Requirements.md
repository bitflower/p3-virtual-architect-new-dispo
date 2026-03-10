# Oracle CDC - Striim Configuration & Requirements (Side Communication)

**Source:** Email thread with Matt Wilkinson (2026-01-15 to 2026-01-16)
**Context:** Preparation for Oracle CDC evaluation for New Dispo

---

## 1. Current State - Striim Deployment

| Aspect | Status |
|--------|--------|
| Current deployment | Running on 5 branches |
| Historical deployment | Was running on all branches, can be re-enabled |
| Character | Potentially temporary (until Alloy migration) |

---

## 2. Questions & Answers

### Q1: Striim Branch Coverage
**Q:** Is Striim only used on a small dedicated set of branch DBs? Is it temporary and will be phased out once all branches are on Alloy?
**A:** Currently running on 5 branches. It has been running across all branches before and can be re-enabled.

**Follow-up Q (Open):** What is the target picture?
- To have it running on all branches (for which use cases?)
- Or to phase it out slowly once migrated to Postgres or stay on Oracle?
- Is there still a need to push data to Postgres once a branch is live on Postgres?

---

### Q2: Archive Log Mode
**Q:** Are the databases in archive log mode?
**A:** Clarification requested - which databases? (Oracle side confirmed)

**Clarification:** Only Oracle is relevant. Either Oracle LogMiner or Binary Log Reader must be enabled for CDC.

---

### Q3: Redo Log Retention
**Q:** Are the redo logs stored locally? For how long?
**A:** Yes, stored locally. Retention varies per branch due to storage constraints on Oracle disks.

**Critical Example (D33):** If Striim loses connection (e.g., network blip), it must be restored ASAP. Transaction count recycles within approximately 1 hour - after which a full initial load would be required.

**Assessment:** CDC is secondary priority to such scenarios (which would result in heavier data loss anyway).

---

### Q4: LogMiner Status
**Q:** Is LogMiner enabled/allowed?
**A:** Unsure. Question raised about impact on database load.

**Action:** Matthias to contact Robert about LogMiner/Binary Log Reader options.

---

### Q5: DBA Grants Approval
**Q:** Does the DBA team agree with GRANTS such as LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc.?
**A:** Once the use case is understood, it should be OK. Concern raised about introducing another tool and additional cost.

---

## 3. Technical Requirements & Constraints

### 3.1 Use Case Definition
- **NOT** pushing large amounts of data
- Trigger business logic based on **specific data changes**
- Example: New shipment arrives
- Narrow scope: Changes to specific fields in specific table records
- **Target:** Installed on all productive databases (same approach for Postgres)

### 3.2 Infrastructure Concerns
| Concern | Details |
|---------|---------|
| Oracle infrastructure state | Described as "creeky" (unreliable/slow) |
| CDC conflict risk | Potential conflict running two CDC systems simultaneously |
| Redo log retention | Very short retention window (~1 hour at some branches) |
| Recovery scenario | Initial load required if CDC connection lost too long |

### 3.3 CDC Technology Options
| Option | Notes |
|--------|-------|
| Oracle LogMiner | One of two options for Oracle CDC |
| Binary Log Reader | Alternative to LogMiner |
| Google Datastream | Offers Oracle source - suggested as first approach to try |

---

## 4. Open Questions (To Be Resolved)

1. **Striim Strategy:** Temporary (phase out) vs. long-term (reactivate on all branches)?
2. **LogMiner Status:** Is it enabled? What is the impact on database load?
3. **Striim Costs:** What are the current and last 6 months' billing costs?
4. **Post-Migration Need:** Is CDC still needed once a branch is live on Postgres?
5. **Infrastructure Impact:** Detailed assessment of adding another transaction log monitor

---

## 5. Recommendations & Next Steps

1. **Separate concerns:** Distinguish between use cases and strategy (phase out Striim vs. reactivate)
2. **Evaluate Datastream first:** Since it offers Oracle support, this should be the first approach
3. **Cost analysis:** Obtain Striim cost data (current + 6 months historical)
4. **Technical clarification:** Contact Robert regarding LogMiner/Binary Log Reader options
5. **Avoid dual CDC:** Strong preference to avoid running two CDC systems in parallel

---

## 6. Key Contacts

| Role | Name |
|------|------|
| Programme Management | Matt Wilkinson |
| DBA Contact | Robert (to be contacted for LogMiner details) |
