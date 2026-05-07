# [Project Name] — Wiki

> Enterprise Web App · Scrum · Collective ownership — everyone keeps this up to date.

---

## Quick Links

| Resource | Link |
|---|---|
| 📋 Backlog | _link_ |
| 🔄 Sprint Board | _link_ |
| 📦 Repository | _link_ |
| 🚀 Staging | _link_ |
| 📌 Technical Decision Log | _link_ |
| 📋 Open Clarifications | _link_ |

---

## Table of Contents

1. [Stakeholder & Governance](#1-stakeholder--governance)
2. [Requirements & IT Refinement](#2-requirements--it-refinement)
3. [Scrum Process & Artifacts](#3-scrum-process--artifacts)
4. [Architecture & Technology](#4-architecture--technology)
5. [Development & Quality](#5-development--quality)
6. [Operations & Onboarding](#6-operations--onboarding)
7. [Workspace](#7-workspace)
8. [Archive & Migration](#8-archive--migration)
9. [Wiki Guidelines](#9-wiki-guidelines)

---

## 1. Stakeholder & Governance

### 1.1 Project Brief
- Mission statement & business goals
- Success criteria
- Key milestones & timeline

### 1.2 Stakeholder Register

| Name | Role | Side | Involvement | Contact |
|------|------|------|-------------|---------|
| | | Internal / Customer | RACI | |

### 1.3 Customer Contact Map ⭐

> One owner per domain — only the domain owner's answer is binding.

| Name | Domain | Fallback | Channel |
|------|--------|----------|---------|
| | Auth & Identity | | |
| | Data model & integrations | | |
| | Business logic & workflows | | |
| | Architecture decisions | | |

### 1.4 RACI — Roles & Responsibilities
- Responsibility matrix per key decisions and deliverables
- Clarify who is **R**esponsible, **A**ccountable, **C**onsulted, **I**nformed

### 1.5 Escalation Paths
- Level 1: Team-internal (Scrum Master / PO)
- Level 2: Our Architect ↔ Customer Lead Dev
- Level 3: Management / Customer escalation contact

### 1.6 Meeting Overview

| Meeting | Frequency | Participants | Purpose |
|---------|-----------|--------------|---------|
| Weekly Technical Sync | Weekly | Our Architect + Customer Devs/Architects | Clarifications, decisions |
| Sprint Review | End of sprint | Team + Stakeholders | Demo & feedback |
| Stakeholder Update | _tbd_ | PO + Customer management | Status, roadmap |

---

## 2. Requirements & IT Refinement

### 2.1 Product Vision & Roadmap
- Vision statement
- High-level roadmap (themes, milestones)
- Link to backlog tool

### 2.2 Refinement Process ⭐

**Two-stage model:**

```
Business requirement comes in
        ↓
  [Business Refinement]
  PO + Customer clarify scope & goals
        ↓
  Open technical questions? → Open Clarifications Log
        ↓
  [IT Refinement]
  Team refines, estimates, breaks down
        ↓
  Definition of Ready met? → Ready for Sprint Planning
```

**Who participates:**
- Business refinement: PO, relevant stakeholders, customer contact
- IT refinement: full dev team, PO, architect

**Cadence:** _e.g. business refinement Tuesday, IT refinement Thursday_

### 2.3 Technical Clarification Process ⭐

When a requirement has open technical questions that need customer input:

1. **Flag it immediately** — add to Open Clarifications Log, do not start IT refinement
2. **Batch questions internally** — collect all open questions before contacting the customer
3. **Send a structured request** — numbered questions, business context, explicit deadline
4. **Route through the primary channel** — Our Architect ↔ Customer Lead Dev; avoid unstructured side paths
5. **Bring to Weekly Sync** if unresolved — all overdue items are automatic agenda items
6. **Log the answer** — resolved questions move to the Technical Decision Log
7. **Graduate to IT Refinement** — only once all questions are answered

**Response SLA (to be agreed with customer):**
- Blocker / sprint-critical: 1 business day
- Normal: 3 business days
- Overdue → automatic escalation via weekly sync

### 2.4 Open Clarifications Log (template)

> Lives in the Workspace. One page per Epic or feature.
> Closed once all questions are resolved — answers move to the Technical Decision Log.

| # | Question | Context / why it matters | Asked by | Customer owner | Due | Status |
|---|----------|--------------------------|----------|----------------|-----|--------|
| 1 | | | | | | Open / Waiting / Resolved |

### 2.5 Technical Decision Log ⭐

> All decisions made in the Weekly Sync or via direct channel — confirmed by both sides.
> Changing a logged decision = new entry, new ticket, visible cost.

| Decision | Context | Made in | Customer confirmed | Ticket |
|----------|---------|---------|--------------------|--------|
| SSO applies to internal users only | Auth model | Weekly Sync 2025-04-22 | ✓ [Name] | #412 |

### 2.6 Definition of Ready (DoR) ⭐

A ticket is ready for sprint planning when:
- [ ] Clear user story (As a … I want … so that …)
- [ ] Acceptance criteria defined
- [ ] All open clarifications resolved
- [ ] Dependencies identified
- [ ] Estimated by the team
- [ ] UI/UX designs attached (if applicable)
- [ ] No blocking open questions

### 2.7 Acceptance Criteria Template

```
GIVEN [context / precondition]
WHEN  [action / trigger]
THEN  [expected outcome]
```

### 2.8 Non-Functional Requirements (NFR)
- Performance (response times, throughput)
- Availability & SLA targets (agreed with customer)
- Security & compliance requirements
- Accessibility standards
- Scalability expectations

### 2.9 Glossary — Customer Domain Terms

| Term | Definition | Source |
|------|------------|--------|
| | | |

---

## 3. Scrum Process & Artifacts

### 3.1 Sprint Calendar
- Sprint length: _e.g. 2 weeks_
- Sprint start / end: _e.g. Monday – Friday_
- Link to team calendar

### 3.2 Definition of Done (DoD) ⭐

A ticket is done when:
- [ ] Code implemented & peer-reviewed
- [ ] Unit tests written & passing
- [ ] Integration tests passing
- [ ] Deployed to staging
- [ ] Acceptance criteria verified by PO
- [ ] No new critical bugs introduced
- [ ] Documentation updated (if applicable)

### 3.3 Ceremonies — Guide & Agenda

| Ceremony | Duration | Participants | Goal |
|----------|----------|--------------|------|
| Sprint Planning | 2–4 h | Full team | Commit to sprint goal |
| Daily Standup | 15 min | Dev team | Sync & remove blockers |
| Sprint Review | 1–2 h | Team + Stakeholders | Demo & feedback |
| Sprint Retrospective | 1–1.5 h | Full team | Improve the process |
| Business Refinement | 1 h | PO + Customer | Clarify scope |
| IT Refinement | 1–2 h | Full team + PO | Estimate & break down |

### 3.4 Backlog Management Guidelines
- Ticket types: Epic, Story, Task, Bug, Spike
- Who can add to the backlog
- Priority levels & how they are set
- Story writing conventions

### 3.5 Velocity & Capacity Planning
- How velocity is measured
- Capacity formula for fluctuating team size (5–15 people)
- Historical velocity: _link_

### 3.6 Retrospective Protocols & Actions
- Format used: _e.g. Start / Stop / Continue_
- Archive of retro outcomes: _link_
- Open action items: _link_

---

## 4. Architecture & Technology

### 4.1 System Overview
- High-level architecture diagram
- Component overview
- External integrations map

### 4.2 Tech Stack

| Layer | Technology | Version | Why chosen |
|-------|-----------|---------|------------|
| Frontend | | | |
| Backend | | | |
| Database | | | |
| Auth | | | |
| Infrastructure | | | |
| CI/CD | | | |

### 4.3 ADR — Architecture Decision Records

> One sub-page per significant decision.

**Template:**
```
# ADR-[number]: [Short title]

Date: YYYY-MM-DD
Status: Proposed | Accepted | Deprecated | Superseded

## Context
What situation requires a decision?

## Decision
What was decided?

## Consequences
What are the trade-offs?
```

### 4.4 API Documentation
- Base URL per environment
- Authentication method
- Link to OpenAPI / Swagger spec
- Versioning strategy

### 4.5 Data Model & Interfaces
- Entity-relationship overview
- Key entities & attributes
- External interface contracts

### 4.6 Security & Data Protection ⭐
- Authentication & authorization concept
- Data classification
- Compliance requirements (GDPR, customer-specific)
- Secrets management
- Security review schedule

---

## 5. Development & Quality

### 5.1 Git Workflow & Branching
- Branching model: _e.g. trunk-based / Gitflow_
- Branch naming convention
- Commit message format
- PR process & merge rules
- Release tagging

### 5.2 Code Review Guidelines
- Who reviews what
- Review checklist
- Turnaround time expectation
- Handling disagreements

### 5.3 Test Strategy

| Test Type | Tool | Owner | Runs when |
|-----------|------|-------|-----------|
| Unit | | Dev | On commit |
| Integration | | Dev | On PR |
| E2E | | Dev / QA | On staging |
| Manual | | QA / PO | Pre-release |

- Coverage targets
- Test data management

### 5.4 CI/CD Pipeline
- Pipeline stages & tools
- Trigger rules per branch
- Environment variable & secrets management
- Pipeline diagram: _link_

### 5.5 Environments

| Environment | Purpose | URL | Access |
|-------------|---------|-----|--------|
| Local | Development | localhost | All devs |
| Dev | Integration | | Dev team |
| Staging | QA & demo | | Team + PO |
| Production | Live | | Restricted |

### 5.6 Tech Debt & Known Issues
- Active tech debt items (description, impact, effort estimate)
- Non-critical known bugs
- Refactoring backlog

---

## 6. Operations & Onboarding

### 6.1 Onboarding Guide 👋

> **Start here if you're new to the team.**

- Day 1 checklist (accounts, access, tools)
- What to read in the first 3 days
- Who to ask about what
- How to pick up your first ticket

### 6.2 Local Setup & Tooling
- Prerequisites (OS, tools, versions)
- Step-by-step setup
- Common issues & fixes
- Required IDE config / plugins

### 6.3 Deployment Runbook
- How to trigger a deployment
- Pre-deployment checklist
- Rollback procedure
- Hotfix process

### 6.4 Monitoring & Alerting
- Monitoring tools & dashboards: _link_
- Alert channels & on-call contacts
- Key metrics to watch

### 6.5 Incident Response

| Severity | Definition | Response time | Action |
|----------|------------|---------------|--------|
| P1 | Production down | 15 min | Page on-call, notify customer |
| P2 | Major feature broken | 1 h | Team alert |
| P3 | Degraded performance | 4 h | Ticket, fix in sprint |
| P4 | Minor issue | Next sprint | Backlog |

Post-mortem template: _link_

### 6.6 SLA & Customer Commitments ⭐
- Agreed availability targets
- Response & resolution times per severity
- Maintenance windows
- Customer notification requirements

### 6.7 Release Notes & Changelog
- Release cadence
- Changelog format
- Who communicates releases to the customer
- Archive: _link_

---

## 7. Workspace

> ✏️ **Work in progress — nothing here is final.**
> Develop, discuss, and draft here. Once content is reviewed and verified, move it to the relevant section above.
> Every page here should have a named owner and a target section noted at the top.

### Sub-pages

- **Refinement Prep** — user stories in draft, open questions, estimation notes
- **Sprint Planning Drafts** — capacity, candidate items, planning notes
- **Architecture Discussions** — RFCs, option analyses, open questions
- **Meeting Notes (Raw)** — unprocessed notes before clean-up
- **Concepts & Research** — tech evals, spikes, proof of concepts
- **Retro Actions in Progress** — open improvements not yet closed

---

## 8. Archive & Migration

> The old wiki is frozen (read-only). Do not delete it — link to it as a reference.
> Only migrate content that is still accurate and still needed. No copy-paste migration.

### Migration Status

| Old wiki section | Status | Notes |
|------------------|--------|-------|
| | Migrated / Archived / Discarded | |

### Rules
- Outdated content → discard, do not migrate
- Still valid content → migrate, verify, mark old page as "→ moved to [link]"
- When in doubt → discard and rebuild fresh

---

## 9. Wiki Guidelines

> How we keep this wiki healthy — collectively.

### The two-zone rule

| Zone | What goes here | Quality bar |
|------|---------------|-------------|
| **Knowledge area** (sections 1–6) | Finished, verified, stable content | Always accurate or marked outdated |
| **Workspace** (section 7) | Drafts, WIP, rough notes | No bar — anything goes |

Never mix the two. If it isn't ready, it goes in the Workspace.

### Collective ownership rules

- **Every page has an owner** — not the only editor, but responsible for keeping it accurate.
- **Mark before you leave** — if a page is outdated, add `⚠️ needs update`. A wrong page is worse than an empty one.
- **Short beats long** — if a page grows too large, split it.
- **Decisions belong here, not in Slack** — if something was decided, it goes in the Technical Decision Log.
- **Link, don't duplicate** — duplicated content always drifts out of sync.

### Page template

```
# Page title

> Owner: [Name] · Last reviewed: YYYY-MM-DD · Status: Current / ⚠️ needs update

## Summary
One or two sentences — what is this page about and who needs it?

## Content
...

## Open questions
...

## Related pages
- [link]
```
