# VA Experiment Extraction - ADDENDUM: Emergent Patterns

**These patterns emerged organically during the 4-week experiment and represent workflows NOT mentioned in the original VA feature list.**

---

## Pattern A: Structured ADR (Architecture Decision Record) Management

**Discovery:** Found 09_ADRs/ folder with template-based decision documentation

**How it works:**
```markdown
# [ADR{NNN}] {Title}
## Context (problem space + requirements)
#### Options Considered
## Decision (chosen option for each requirement)
## Rationale (why chosen, why others rejected)
## Costs (breakdown with assumptions)
## Consequences (positive + negative)
## Related ADRs (links to dependencies)
## References (PoCs, external docs)
## Architecture Diagram
```

**What makes this different from "exploration documents":**
- **ADRs are decisions** (past tense), explorations are investigations (present tense)
- **ADRs link to each other** ("supersedes ADR-001", "revised by ADR-005")
- **ADRs include cost breakdowns** with explicit assumptions
- **ADRs have formal status** (Draft → Closed)

**Evidence of usage:**
- ADR-001: Data Exchange TMS ↔ CALSuite Cross-Dock
- ADR-002: xServer Integration for Tour Optimization
- ADR-003: Email Sending via API
- ADR-004: TMS Bridge Database Identifier
- ADR-005: Dual Instance Deployment WL4 Test

**Why this matters for VA:**
This is a **decision artifact lifecycle** pattern:
1. Exploration (open-ended investigation)
2. Comparison table (options analysis)
3. **ADR (formal decision record)**
4. Implementation (execute decision)

VA currently focuses on #1 and #2. This shows #3 is a distinct artifact type with its own structure and cross-referencing needs.

**Proposed VA feature:** ADR Generator
- Input: Exploration + comparison table
- User: "Generate ADR for [decision]"
- VA: Extracts context (from exploration), options (from table), decision (user specifies), consequences (VA infers from analysis)
- Output: Structured ADR with template compliance
- VA: Links to related ADRs (if similar decisions exist)

---

## Pattern B: Dual-Space Documentation (Local vs. Public) ⭐ **CRITICAL**

**Discovery:** Project-manager skill with automatic local→wiki transformation

**Problem solved:**
- Internal docs have exploration links, meeting notes, raw data
- Stakeholder docs need clean presentation without internal references

**How it works:**
1. Create `PROJECT-STATUS.md` in exploration folder (local workspace)
   ```markdown
   ## Analysis
   See [detailed findings](./03_Analysis/database-performance.md)
   ```

2. Maintain mapping in `.claude/skills/wiki-connector/publish-mappings.json`:
   ```json
   {
     "02_Explorations/2026-03-11_Oracle_CDC/PROJECT-STATUS.md":
       "WIKI/Nagel-CAL-Disposition.wiki/Projects/Oracle-CDC.md"
   }
   ```

3. Run `/project-manager sync <file>`

4. Output in wiki:
   ```markdown
   ## Analysis
   See detailed findings
   ```
   (Link removed, text preserved)

**What gets transformed:**
- Remove internal exploration links
- Keep external URLs (vendor docs, GCP console)
- Keep section structure and content
- Add "Last synced" timestamp

**Why this matters:**
This is **audience-aware content transformation** with:
- **Persistent mapping** (know which local doc maps to which wiki page)
- **Selective link stripping** (internal vs external)
- **Two-way sync awareness** (which version is newer?)

**This differs from "Layered Communication Generator":**
- Layered = same content, different FORMAT (exec summary vs technical)
- Dual-space = same FORMAT, different AUDIENCE (internal vs client)

**The "Publish Step" Pattern:**

```
LOCAL (explorations/) → TRANSFORM → TARGET PLATFORM (wiki/Azure/Jira)
      Internal workspace    Rules        Stakeholder visibility
```

**Publish rules observed:**
1. **Link transformation**
   - Internal links: Remove or convert to plain text
   - External links: Preserve
   - Relative paths: Make absolute or remove

2. **Content filtering**
   - Remove: Internal meeting notes, raw data, exploration references
   - Keep: Conclusions, decisions, action items, public context

3. **Metadata injection**
   - Add: "Last synced", "Source", "Contact"
   - Version tracking: Local modified → suggest re-publish

4. **Platform-specific formatting**
   - Wiki: Markdown preserved
   - Azure DevOps: May need work item links
   - Jira: May need issue key formatting

**Evidence of multi-platform publishing:**
The `.claude/skills/wiki-connector/` structure suggests this was built to be **extensible**:
- `publish-mappings.json` (central registry)
- `publish-concept.md` (design philosophy)
- Future: `azure-connector/`, `jira-connector/`

**Proposed VA feature:** Multi-Platform Publishing Engine
- VA: Maintains mapping registry (local file → target platform + location)
- VA: Learns transformation rules per platform:
  - Wiki: Strip internal links, keep structure
  - Azure: Add work item references, format as ADO markdown
  - Jira: Convert to Jira markup, add issue keys
  - Confluence: Rich formatting, auto-table-of-contents
- User: "Publish exploration to Azure DevOps wiki"
- VA: Applies Azure-specific rules, creates clean version
- VA: Tracks sync state, suggests re-publish when local changes

**Critical insight from user:**
> "extremely important is the 'publish step' from 'local / internal' knowledge build up (in explorations) to 'target platform sharing' in e.g. azure (in this case) and later Jira etc."

This is the **bridge between private knowledge construction and public knowledge sharing**. VA needs to understand:
- Local space = full fidelity, everything linked, messy, evolving
- Target platform = curated, transformed, stakeholder-appropriate
- Publish = **not a copy**, it's a **transformation with rules**

---

## Pattern C: Granular Permission Refinement Over Time

**Discovery:** .claude/settings.local.json with 40+ specific allowed commands

**Evolution pattern:**
```json
{
  "permissions": {
    "allow": [
      "WebSearch",                    // Broad (day 1)
      "Bash(cat:*)",                  // Category (week 1)
      "Bash(git pull:*)",             // Specific command (week 2)
      "Skill(explore)",               // Custom skill (week 3)
      "Bash(mkdir -p \"/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code/Disposition-Backend/.claude/skills\")", // EXACT command (week 4)
    ]
  }
}
```

**Pattern observed:**
- Start broad: "Allow all Bash"
- Encounter issue: "Actually, don't allow `git credential fill`"
- Add to deny list
- Next time similar command needed: Add EXACT command to allow list
- Permission list grows as usage patterns solidify

**Why this is interesting:**
This is **progressive permission hardening** based on actual usage:
- Not "configure all permissions upfront"
- Not "deny everything by default"
- It's "learn from usage, refine over time"

The 40+ entries represent 4 weeks of "what commands did I actually need?"

**Proposed VA feature:** Permission Learning Mode
- VA: Tracks command usage over time
- VA: Suggests "You've run 'cd /path/to/repo && git pull' 15 times. Add to permanent permissions?"
- User: Approves
- VA: Adds to allowlist with appropriate pattern (`git pull:*` vs exact path)

This is **behavior-driven security** rather than upfront policy definition.

---

## Pattern D: Multi-Artifact Cross-Linking (The "Decision Thread") ⭐ **CRITICAL**

**Discovery:** Following a single decision across multiple artifact types

**Example: Oracle CDC Decision Thread**

1. **Meeting notes** (00_Meetings/2026-01-09_Austausch-Joachim.md)
   - Stakeholder raises need for Oracle CDC
   - Action: Investigate options

2. **Exploration folder** (02_Explorations/2026-01-16-Oracle-CDC/)
   - Requirements consolidation (from email threads)
   - Options evaluation (Datastream vs Striim vs Debezium)
   - Gemini sparring session (cost analysis)
   - Architecture evaluation document

3. **ADR** (09_ADRs/ADR-006-oracle-cdc-approach.md) ← *hypothetical, pattern observed*
   - Formal decision: GCP Datastream
   - References exploration folder for analysis
   - Cost breakdown from evaluation
   - Consequences documented

4. **Wiki documentation** (WIKI/Projects/Oracle-CDC.md)
   - Stakeholder-facing project status
   - Links back to ADR for technical readers

**The pattern:**
```
Meeting → Exploration → ADR → Implementation → Wiki Publication
  ↑                       ↑
  |                       └─ comparison table
  └─ requirements consolidation
```

**Why this matters:**
This is a **decision lifecycle with artifact handoffs**:
- Each step produces a specific artifact type
- Each artifact references the previous (audit trail)
- Each artifact serves a different purpose (investigation vs decision vs communication)

**Current VA capabilities miss this:**
- Entity extraction: single document
- Chat messages: linear conversation
- No concept of "artifact type" (exploration vs ADR vs wiki page)

**Proposed VA feature:** Decision Thread Visualization
- VA: Detects decision topic (e.g., "Oracle CDC")
- VA: Finds all artifacts mentioning it across folders
- VA: Classifies by type (meeting → exploration → ADR → wiki)
- VA: Shows timeline: "This decision evolved over 6 weeks across 12 artifacts"
- User: Clicks artifact → opens in context

This is like a **topic-based "git log"** across heterogeneous document types.

---

## Pattern E: Infrastructure Documentation Separation

**Discovery:** 08_Documentation/Infrastructure/ folder separate from explorations

**Structure:**
```
08_Documentation/
└── Infrastructure/
    ├── Cloud Run/
    ├── AlloyDB/
    ├── Pub Sub/
    └── Cloud Functions/
```

**Why separate from 02_Explorations/?**
- **Explorations** are temporal (dated, investigation-focused)
- **Infrastructure docs** are reference material (timeless, configuration-focused)

**Content type difference:**
- Exploration: "We investigated 3 options for X, chose Y because Z"
- Infrastructure: "Here's how our Cloud Run setup works, here's the config"

**This pattern suggests two knowledge spaces:**
1. **Historical/Decision** (explorations, ADRs) - "How did we get here?"
2. **Current/Reference** (infrastructure, architecture diagrams) - "How does it work now?"

**Proposed VA feature:** Knowledge Space Classification
- VA: Automatically classifies documents as "historical" vs "reference"
- User: "How does our Cloud Run setup work?" → VA prioritizes 08_Documentation/
- User: "Why did we choose Cloud Run?" → VA prioritizes explorations + ADRs
- Different retrieval strategies for different question types

---

## Summary: New Patterns Mapped to VA Product Opportunities

| Pattern | VA Feature | Priority | Rationale |
|---------|-----------|----------|-----------|
| **A. ADR Management** | ADR Generator | High | Completes decision lifecycle (investigation → decision → record) |
| **B. Dual-Space Docs** | Multi-Platform Publishing Engine | **CRITICAL** | **Bridge from local to public, multi-platform support** |
| **C. Permission Refinement** | Permission Learning Mode | Low | Nice-to-have, helps with tool security |
| **D. Decision Thread** | Decision Timeline Visualization | **CRITICAL** | **Shows decision evolution across artifact types** |
| **E. Infra Doc Separation** | Knowledge Space Classification | Medium | Different retrieval for "how?" vs "why?" questions |

---

## Two Critical Missing Capabilities

### 1. Multi-Platform Publishing Engine (Pattern B)

**What it solves:**
The gap between "I built knowledge internally" and "I need to share it with stakeholders on their platforms."

**Why it's critical:**
Every architecture decision must be communicated to multiple audiences on multiple platforms:
- **Internal team:** Full exploration folder (local)
- **Management:** Executive summary (email)
- **Client:** Project status (wiki)
- **Development team:** ADR + implementation guide (Azure DevOps)
- **Support team:** Runbooks (Confluence)
- **Compliance:** Audit trail (Jira)

**Current state:** Manual copy-paste + manual reformatting for each platform.

**What VA needs:**
1. **Mapping registry:** "This exploration → these target platforms"
2. **Transformation rules per platform:** Link handling, formatting, metadata
3. **Sync awareness:** "Local changed, wiki is stale → suggest re-publish"
4. **Multi-destination publish:** One source → many platforms with different rules

---

### 2. Decision Timeline Visualization (Pattern D)

**What it solves:**
Understanding how a decision evolved from initial question to final implementation across multiple artifact types.

**Why it's critical:**
- **Onboarding:** New team member asks "Why did we choose GCP Datastream?"
  - Current: Read 12 documents scattered across folders
  - With Decision Thread: See timeline from meeting → exploration → ADR → deployment

- **Decision review:** "Let's revisit the Oracle CDC approach"
  - Current: Remember which documents exist, hunt for them
  - With Decision Thread: See complete history in one view

- **Audit/Compliance:** "Show me the decision process for X"
  - Current: Reconstruct from Git history
  - With Decision Thread: Automatic audit trail

**What VA needs:**
1. **Artifact type detection:** Classify document as meeting/exploration/ADR/wiki
2. **Topic extraction:** "This document is about Oracle CDC"
3. **Timeline construction:** Order artifacts chronologically
4. **Relationship inference:** "ADR-006 references exploration 2026-01-16"
5. **Visual timeline:** Show evolution graphically

---

**Generated:** 2026-03-21
**Focus:** Patterns NOT in original VA backlog but emerged during 4-week experiment
