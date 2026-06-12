---
name: meeting-task-router
description: Take action items from a meeting brief, find matching explorations, and present options for how meeting context could update those explorations. Use when the user wants to route meeting tasks into existing explorations or decide what to do with action items.
allowed-tools: Read,Glob,Grep,Bash,Write,Edit
---

# Meeting Task Router

Routes action items from a meeting briefing into matching explorations. For each task assigned to Matthias, finds relevant explorations and presents concrete options for how the meeting context should affect them.

## When to Use

- User asks to "route tasks from this meeting" or "what do I need to do from this meeting"
- User provides a briefing file and wants to act on it
- User mentions `/meeting-task-router` with a briefing path

## Usage

```
/meeting-task-router <path-to-briefing.md>
/meeting-task-router 00a_MeetingBriefs/2026-06-11_some-meeting-BRIEFING.md
```

If no file is provided, list recent files in `00a_MeetingBriefs/` and ask the user to pick one.

## Process

### Phase 1: Extract Tasks

1. **Read the briefing file** at the provided path.
2. **Parse the "Action Items for Matthias" table.** Each row has columns: `#`, `Action`, `Context`, `Urgency`.
3. **Also scan "Topics Needing Matthias's Attention"** for implicit tasks — things that aren't explicit action items but need follow-up.
4. Build an internal task list. Each task has:
   - `action`: what needs to be done
   - `context`: why, from which discussion
   - `urgency`: High / Medium / Low
   - `source_section`: which briefing section it came from
   - `keywords`: extracted domain terms for matching (systems, concepts, German domain terms)

If there are **zero tasks** for Matthias, report that clearly and stop.

### Phase 2: Find Matching Explorations

For each task, search `02_Explorations/` for related explorations.

**Search strategy — cast a wide net, then rank:**

1. **Extract keywords** from the task's action + context:
   - System names: TMS Bridge, AlloyDB, Oracle, CDC, Frontend, Backend, TOP, Cloud Functions, GCP, SignalR, Driver Terminal
   - Domain concepts: Sendung, Verkehrsart, Zustellung, Abholung, Disposition, Traffic Mode, Transport Order, Edit Flow
   - Feature/topic names: whatever specific subject the task mentions
   - Ticket/story references: any IDs like `US-12345`, `#12345`, PBI numbers

2. **Search exploration folder names** using glob patterns on `02_Explorations/*/`:
   - Match keywords against folder names (date-prefixed, so match the topic part)
   - Be fuzzy: "Traffic Mode" should match `Traffic-Mode`, `traffic_mode`, `TrafficMode`

3. **Search exploration file contents** using grep for keywords that didn't match by folder name:
   - Grep through `02_Explorations/**/*.md` for key phrases from the task
   - Read the first 50 lines of matching files to confirm relevance (avoid false positives from passing mentions)

4. **Rank matches** per task:
   - **Strong match**: folder name or document title directly addresses the task's subject
   - **Partial match**: document mentions the subject but isn't primarily about it
   - **No match**: no existing exploration covers this topic

5. **Read matched exploration summaries.** For each strong or partial match, read enough of the exploration (title, status, executive summary, key findings) to understand its current state and scope.

### Phase 3: Present Options Per Task

For each task, present a structured decision block. **Stop after presenting all blocks and wait for user input.**

#### Option Block Format

```markdown
---

### Task {#}: {Action} [{Urgency}]

**Meeting context:** {Context from briefing — 1-2 sentences}

**Matching explorations:**

| Match | Exploration | Status | How this task relates |
|-------|-------------|--------|----------------------|
| Strong | `02_Explorations/YYYY-MM-DD_Topic/` | {status if visible} | {how the meeting context connects} |
| Partial | `02_Explorations/YYYY-MM-DD_Other/` | {status} | {weaker connection explained} |

**Options:**

1. **Update existing exploration** — Integrate the meeting's decision/context into `{exploration path}`. Specifically: {what would change — new section? updated decision? revised recommendation?}
2. **Start new exploration** — The meeting raised a topic not covered by existing work. Would create `02_Explorations/{suggested folder name}/`
3. **No exploration needed** — This is a simple action (send an email, update a config, have a conversation) that doesn't need documented analysis.
4. **Needs more context first** — Before acting, we'd need: {what's missing — another document, a conversation, a code check}

Only show options that actually apply. Don't show "Update existing" when there are no matches. Don't show "Start new" when a strong match already exists (unless the task truly warrants a separate exploration).
```

### Phase 4: Wait for User Input (MANDATORY GATE)

**Stop. Present all option blocks. Wait for the user to respond.**

The user may:
- **Pick an option** for each task (e.g., "Task 1: option 1, Task 2: option 3")
- **Provide additional context** (e.g., "For task 1, also check the email from Ron about X")
- **Ask to read an exploration first** before deciding
- **Defer tasks** ("skip task 3 for now")
- **Combine tasks** ("tasks 1 and 2 are actually the same thing, update exploration X")

Do NOT proceed to modify any exploration until the user has explicitly chosen an option.

### Phase 5: Execute Chosen Actions

For each task where the user chose an action:

#### If "Update existing exploration":
1. Read the full exploration document to be updated.
2. **Draft the changes** — show the user what you'd add/modify. Frame changes as:
   - New information from the meeting (decisions, constraints, timeline changes)
   - Updated status or conclusions based on meeting outcomes
   - New sections if the meeting raised sub-topics not yet covered
3. **Apply changes only after user confirms** the draft looks right.
4. Preserve the exploration's existing structure and voice. Integrate, don't append a "meeting update" block.

#### If "Start new exploration":
1. Use the `/explore` skill pattern: create `02_Explorations/YYYY-MM-DD_{Topic}/` with a structured markdown file.
2. Pre-populate with context from the meeting briefing.
3. Flag sections that need additional input.

#### If "Needs more context first":
1. Explain what's missing and where it might come from.
2. If the user provides the context, loop back to option presentation for that task.

## Key Rules

- **Never modify an exploration without explicit user approval.** This skill is advisory first, action second.
- **Keyword matching is fuzzy, not exact.** Domain terms appear in many forms (German, English, abbreviated, hyphenated). Cast a wide net.
- **One task may match multiple explorations.** Present all matches, ranked. The user decides which one to update.
- **Multiple tasks may match the same exploration.** Group them in the presentation so the user can decide whether to handle them together.
- **Be honest about match quality.** "No match found" is a valid and useful result — not every meeting task relates to existing work.
- **Respect the feedback rule: integrate, don't append.** When updating an exploration, weave the new information into existing sections. Never add a standalone "Update from meeting YYYY-MM-DD" block.

## Output Style

- Terse, factual, structured. This is a routing decision, not a narrative.
- Use the task's original German domain terms — don't translate Sendung to "shipment" etc.
- Show file paths so the user can navigate directly.
