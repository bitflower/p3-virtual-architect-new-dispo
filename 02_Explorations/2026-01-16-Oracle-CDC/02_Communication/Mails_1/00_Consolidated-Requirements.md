# Oracle CDC Integration - Consolidated Requirements

> Consolidated from mail stream December 2025 - January 2026

## 1. Business Context & Objectives

### Primary Goal
Enable the **NewDispo** system to be rolled out independently from **Project G** by fully integrating the **TMS Bridge** with all Oracle databases.

### Business Drivers
- **Independence from Project G**: Disposition must be deployable independently
- **Oracle Integration**: Current CDC solution only supports Postgres; Oracle support is required
- **Full DB Object Coverage**: All relevant database objects must be functional in Oracle
- **Clear Deployment Process**: Oracle deployment workflow must be defined and communicated

---

## 2. Scope Definition

### Use Case
- **Target Application**: NewDispo only
- **Tables**: Same tables currently used under AlloyDB
- **Not in Scope**: Cross-Dock/CALSuite, Cloud4Log, or other systems

### Architecture Decision
- **Sources NOT merged**: Postgres and Oracle sources will remain separate (not combined in a single event bus)
- **Not "invisible" for consumers**: Each source remains distinct

---

## 3. Technical Environment

### Oracle Infrastructure

| Aspect | Details |
|--------|---------|
| **Oracle Versions** | 12.1.0.2 (main), 19.9 and 19.21 (KRITIS databases) |
| **Edition** | Enterprise Edition (Zentrale), Standard Edition 2 (branches) |
| **Hosting** | On-premises, bare metal servers |
| **Archivelog Mode** | Yes, enabled |
| **Redo Log Storage** | Local, retention depends on available space per branch |
| **Backup Policy** | No archivelog deleted before backup |
| **LogMiner** | Partially active, can be used |

### Network & Connectivity
- **GCP Connectivity**: Established (confirmed via EBV integration)
- **TMS Bridge**: Already functional for communication

### CDC Tool Deployment Options
- **Preferred**: Cloud-hosted (GCP)
- **Alternative**: On-premises (not preferred)

---

## 4. Questions & Answers Log

### Technical Infrastructure (answered by Robert Zanter, 2026-01-15)

| Question | Answer |
|----------|--------|
| Which Oracle version is in use? | Mainly 12.1.0.2; KRITIS databases on 19.9 and 19.21 |
| Does every branch have the same version? | No, depends on KRITIS relevance |
| Which edition is used? | Enterprise Edition at headquarters, SE2 elsewhere |
| Are databases in Archivelog mode? | Yes |
| Are redo logs stored locally? How long? | Yes, retention depends on available space; no archivelog deleted without backup |
| Is LogMiner activated/allowed? | Yes, partially active and can be used |
| DBA team okay with GRANTS (LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc.)? | Yes, if approved by Nagel IT |
| How are databases hosted on-prem? | Bare metal servers |

### Business & Architecture (answered by Christian Lang, 2025-12-23)

| Question | Answer |
|----------|--------|
| What is the use case / business goal? | Enable NewDispo on Oracle-based systems |
| Which tables are needed? | Same tables as used under AlloyDB |
| Which systems are targets of the events? | NewDispo only (not Cross-Dock, Cloud4Log, etc.) |
| Should sources (Postgres & Oracle) be merged in one bus? | No |
| Tooling preferences? | Open to options; Oracle remains on-prem, tool can run in cloud (preferred) or on-prem |
| Network connectivity to GCP? | Yes, confirmed (see EBV) |

---

## 5. Open Questions (as of 2026-01-16)

The following questions were raised by Matthias Max and are pending answers:

### LogMiner Clarification
> Are we talking about **Oracle LogMiner** or **Binary Log Reader**?

### Database Hosting Architecture
Clarification needed on the exact setup:
- Option A: `Physical Server → Operating System → Oracle Database Server`
- Option B: `Physical Server → Operating System → VM → Oracle Server`

### Virtualization Details
> Which VM technology is being used?

*Context: This information is needed to potentially replicate the setup in an isolated test environment.*

### Dedicated CDC User
> Should a dedicated database user be created for the CDC process?

---

## 6. Proposed Workstreams

### Stream 1: Conceptual - Extend TMS Pulse for Oracle CDC

**Activities:**
1. Requirements specification by Nagel IT
2. Evaluate known options (e.g., GCP Datastream for Oracle, Pascal's options)
3. Mini-Kickoff Workshop (90-120 min, remote)
   - Present objectives
   - Present known options
   - Define tasks for PoC preparation
4. Conduct PoC(s) based on workshop outcomes

**Participants:** Christian, Pascal, Ron, Matt, Boyan/Yosif, Matthias

### Stream 2: Operational - Oracle Development Enablement

**Activities:**
- Migrate existing NewDispo objects to Oracle
- Enable P3 developers for Oracle development
- Establish dual-database development process (Postgres & Oracle)

**Next Steps:**
- Training by existing developers
- Tooling setup (IDEs)
- Repository/codebase access
- Dev testing environment (local instances? environments? UniFace needed?)
- QA enablement support
- Collaboration process (PRs, Nagel IT reviews)

### Stream 3: Deployment & Release Process

**Activities:**
- Define delivery boundaries (P3 vs. Nagel IT responsibilities)
- Define branching, versioning, and release process
- Define Postgres & Oracle synchronization (schema + data migrations)

**Next Steps:**
- Presentation of holistic deployment process by Nagel IT/Matt
- Ongoing coordination on P3 support for deployments

---

## 7. Action Items

| Action | Owner | Status |
|--------|-------|--------|
| Answer open questions (LogMiner type, hosting architecture, VM) | Robert Zanter / DBA Team | Pending |
| Prepare small proposal/offer for evaluation phase | P3 | Pending |
| Schedule Mini-Kickoff Workshop | TBD | Pending |

---

## 8. Document History

| Date | Description |
|------|-------------|
| 2025-12-01 | Original request from Christian Lang |
| 2025-12-12 | Proposal with two workstreams from Matthias Max |
| 2025-12-23 | Answers from Christian Lang on business questions |
| 2026-01-14 | Technical questions from Matthias Max |
| 2026-01-15 | Answers from Robert Zanter (DBA) |
| 2026-01-16 | Follow-up questions from Matthias Max |
| 2026-01-16 | This document consolidated |
