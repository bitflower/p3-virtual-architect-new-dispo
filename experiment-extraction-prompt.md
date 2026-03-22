# Extraction Prompt: 3-Month Customer Project Experiments

Use this prompt to extract and consolidate learnings from your Claude Code-based experiments on the real customer project. The goal is to produce a single structured document that informs Virtual Architect product prioritization.

---

## Instructions

Analyze the following sources from the customer project:
- Folder/file structure and organization patterns
- Git history (commits, branches, evolution over time)
- Claude Code conversation logs / CLAUDE.md files
- Any notes, READMEs, or documentation created during the work

Produce a consolidated markdown document structured as follows:

---

## Output Structure

### 1. Project Context
- What was the customer project / domain?
- What was the scope of your architectural involvement?
- How long did the engagement run and what was the cadence?

### 2. Features Prototyped (mapped to VA backlog)

For each Virtual Architect feature that you effectively simulated or prototyped during this project, create a section:

```
#### [Feature Name] — maps to backlog item [NNN] or [new]

**What I did:** (concrete description of how you approximated this feature)
**What worked:** (specific outcomes, moments where it delivered value)
**What didn't work / friction:** (where it broke down, was too slow, produced bad results)
**Key takeaway for VA product:** (one or two sentences — what should this mean for implementation priority or design?)
```

Known backlog items to check against (non-exhaustive):
- 026 Staged Entity Extraction
- 027 Document & Chunk Disqualification
- 028 Extraction Exists Indicator
- 029 RL / Fine-Tuning Pipeline
- 030 Add Relationship in Staging
- 031 Entity-Aware Chat Messages
- 033 Entity Split in Staging
- 034 NL Quick Connect
- 035 AI Missing Link Discovery
- 036 Thread-Level Architect Support Request
- 037 Per-Message Feedback
- Continuous Ingestion Pipeline (vision doc #1)
- Agent Canvas with Chat (vision doc #3)
- Architecture Visualization (vision doc #2)
- Instant Engineering / Live Solution Design (vision doc #5)

### 3. Workflow Patterns Developed

Describe the workflows, folder structures, prompt patterns, or conventions you evolved during the 3 months. Focus on:
- What patterns emerged organically vs. what you planned upfront?
- Which patterns proved durable (kept using them) vs. abandoned?
- How did information flow: capture → organize → retrieve → act?

### 4. New Feature Candidates

Features or capabilities you wished you had that do NOT exist in the current VA backlog. For each:
- What was the situation where you needed it?
- What did you do instead (workaround)?
- How important is it? (nice-to-have vs. critical gap)

### 5. Biggest Surprises

Things that contradicted your assumptions going in. Specifically:
- Features you thought would be critical but turned out to be less important — why?
- Features you underestimated that turned out to be essential — why?
- Unexpected friction points or failure modes

### 6. Concrete Evidence

Include verbatim quotes, specific commit messages, or conversation excerpts for the most important insights — the moments where something clicked or broke. These are more valuable than summaries. Format as:

```
> [verbatim quote or excerpt]
> — Source: [conversation date / commit hash / file path]

**Why this matters:** [1-2 sentence explanation]
```

### 7. Priority Implications

Based on everything above, state your revised opinion on:
- What should be built first and why (does it differ from the current backlog order?)
- What should be deprioritized or dropped
- What new items should be added to the backlog

---

## Guidelines

- Be specific and concrete. "Extraction quality was a problem" is useless. "The LLM extracted 12 duplicate 'API Gateway' nodes from 3 different documents because it couldn't distinguish the customer's gateway from AWS API Gateway" is useful.
- Include failures and dead ends — they're as informative as successes.
- If a learning confirms something already in the backlog, say so explicitly — confirmation from real usage is valuable signal.
- If you're unsure whether something maps to an existing feature, describe it anyway under New Feature Candidates.
- Keep the total document under ~3000 words. Dense and actionable beats comprehensive and vague.
