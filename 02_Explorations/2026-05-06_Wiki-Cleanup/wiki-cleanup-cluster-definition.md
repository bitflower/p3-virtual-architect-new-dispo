# Wiki Cleanup: Cluster Definition

**Date:** 2026-05-06
**Source:** Meeting Matthias Max & Maximilian Kehder (Product Owner)
**Wiki:** Nagel-CAL-Disposition.wiki (Azure DevOps)
**Status:** DRAFT - open for sparring

---

## Current State

| Metric | Value |
|---|---|
| Total pages | 531 |
| Root sections | 14 |
| Max nesting depth | 14 levels |
| Dominant section | Planning (307 pages = 58%) |

### Pages per Root Section

| Section | Pages | Note |
|---|---|---|
| Planning | 307 | Team-Refinements (133), Stakeholder-Refinements (62), Sprint-Planning (34), Cross-Dock-Weekly (26) |
| Architecure | 61 | Backend (26), Database (11), Front-end (4), Keycloak (4), Mobile-X (3) |
| Requirements | 45 | Pickup-Planning (7), TMS Pulse/CDC (13), Archive (19) |
| Devops | 41 | Google-ENV (31) |
| Technical-Documentation | 21 | ADRs (9), Architecture (2), Infrastructure (5), Process-Flows (1) |
| Projects | 20 | Active (19), Completed (0), On-Hold (0) |
| Release-Notes | 8 | New Dispo (1), TMS Bridge (3), Versioning-Pattern (1) |
| Onboarding | 4 | Local-environment-setup, Ivailo-Pashow |
| _Archive | 4 | Central-Master-Data (2) |
| EBV-TMS-Bridge | 3 | Likely copy-paste from another project |
| TMS-Knowledge | 2 | |
| Versioning-Strategy | 1 | Duplicated topic (appears 4x across wiki) |

### Key Structural Issues (from meeting)

- No naming convention (kebab-case URL-encoded, inconsistent)
- Wildwuchs (organic growth without system)
- Content duplication (e.g. Versioning Strategy appears 4 times)
- Mixed content types in same sections (validated docs next to meeting notes)
- Copy-paste from unrelated projects discovered
- Planning section overwhelms everything else and pollutes search
- No separation between customer-facing and internal content

---

## Proposed Clusters

### Cluster 1: Technische Dokumentation & Entscheidungsnachweise

**Purpose:** Validated, authoritative, customer-facing documentation.

**Content:** How solutions work, which processes exist, how decisions were made and approved (ADRs), architecture overviews, infrastructure setup, DevOps configuration.

**Quality bar:** No drafts, no exploration notes, no meeting notes. Content that Nagel (the customer) could read and find professional. "Die eigentliche Doku, die Doku Deliverable."

**Audience:** Development team, customer (Nagel), stakeholders, new team members.

**Likely wiki content for this cluster:**
- `Technical-Documentation/` (ADRs, Architecture, Infrastructure, Process-Flows)
- Parts of `Architecure/` (validated architecture docs)
- `Devops/` (infrastructure, deployment, environment setup)
- `Release-Notes/`
- `Onboarding/`
- `Versioning-Strategy` (consolidated, single source of truth)
- `Terms-&-Namespaces`

### Cluster 2: Interner Arbeitsbereich / Sandbox

**Purpose:** Team working space for ongoing and recent work.

**Content:** Explorations, refinement context, feature discussions, internal decisions and their rationale, retrospective action items (in customer-safe language), active project documentation, scope definitions in progress.

**Quality bar:** Does not need to be polished, but should be structured enough for navigation. Not raw transcripts but condensed summaries. "Can be a bit wild" as long as it's findable and bidirectionally linked to formal documentation.

**Audience:** P3 development team, Product Owner. Customer can see it but it's clearly marked as internal workspace.

**Lifecycle:** Content here may graduate to Cluster 1 once validated and finalized (e.g., a scope definition becomes an approved ADR).

**Likely wiki content for this cluster:**
- `Planning/Scopes` (active scope definitions)
- `Planning/Stakeholder-Refinements` (recent/active only)
- `Planning/Team-Refinements` (recent/active only)
- `Requirements/` (active feature specs)
- `Projects/Active`
- Parts of `Architecure/` that are working documents / explorations

### Cluster 3: Archiv / Löschen

**Purpose:** Content that no longer reflects current reality and should be removed from the active wiki.

**Content:** Outdated planning entries, concept drafts never finalized, duplicated content, copy-paste from other projects, empty/stub pages, completed/superseded requirements.

**Action per item:** Either move to `_Archive` or delete entirely.

**Likely wiki content for this cluster:**
- `_Archive/` (already archived)
- `EBV-%2D-TMS-Bridge` (copy-paste from other project)
- `Planning/` bulk: old dated refinements, sprint plans, meeting notes
- `Planning/Cross-Dock-Weekly` (26 dated meeting entries)
- `Planning/IT-Alignment-Meetings` (14 dated entries)
- `Planning/Infrastructure-Weekly` (10 dated entries)
- `Planning/Retrospective` (7 entries)
- `Requirements/_Archive` (19 pages already marked)
- `Projects/Completed`, `Projects/On-Hold`
- Duplicate Versioning Strategy pages (keep one in Cluster 1)

---

## Open Questions

### 1. Scope Definition: Separate cluster or lifecycle stage?

Maximilian mentioned "Scopes festlegen und abnehmen" as a distinct wiki purpose. In this proposal, scope definitions live in Cluster 2 (Sandbox) while in progress and graduate to Cluster 1 once approved.

**Alternative:** A dedicated "Scoping & Governance" cluster that holds all scope-related content regardless of approval status.

**Decision needed:** Two-stage lifecycle (Sandbox -> Technical Docs) or separate cluster?

### 2. Planning: The elephant in the room (307 pages / 58%)

Most of Planning is dated meeting content (refinements, sprint plans, weeklies). The meeting consensus was that meeting notes pollute search and don't belong in the active wiki.

**Decision needed:**
- Archive ALL dated meeting entries? (aggressive cleanup)
- Keep last N months of refinements in Cluster 2? (rolling window)
- Keep only entries that are still actively referenced? (selective)

### 3. Customer-facing quality gap flagging

Everything stays in one wiki (no second wiki), but internal vs. external content needs clear separation. During classification, should pages in Cluster 1 that don't meet the customer-facing quality bar be flagged separately?

This would surface pages needing **rewriting**, not just **reorganizing**.

### 4. "Was fehlt" (What's missing)

Maximilian explicitly asked to identify gaps: "was fehlt hier, dass man es gut benutzen kann." Should the classification output include a "missing documentation" dimension, or should that be a separate follow-up deliverable?

### 5. Retrospective outcomes

Maximilian wants retro action items in the wiki (customer-safe language). This is new content that doesn't exist yet. Which cluster does it belong to?

**Proposal:** Cluster 2 (Sandbox), with a dedicated sub-section for team process improvements.

---

## Next Steps (proposed)

1. **Align on clusters** - Sparring between Matthias and Maximilian on this document
2. **Classify all wiki content** - Page-by-page / folder-by-folder classification against the agreed clusters, with action recommendation (keep, move, archive, delete)
3. **Review classification** - Joint review of the classified list
4. **Present to team** - Share the proposed structure with the dev team for feedback
5. **Execute cleanup** - Implement the agreed restructuring
