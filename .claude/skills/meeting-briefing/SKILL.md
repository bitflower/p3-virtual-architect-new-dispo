---
name: meeting-briefing
description: Extract actionable briefing (TODOs, topics, decisions) for Matthias Max from meeting transcripts (.vtt) or meeting notes (.md, .docx). Use when the user wants to get a meeting summary, extract action items, or create a briefing from a meeting recording or notes.
tools: Read,Write,Glob,Grep
---

# Meeting Briefing Skill

Extracts a concise, actionable briefing for **Matthias Max** from meeting transcripts or notes. Focuses on what matters to him: action items, decisions, topics needing his attention, and open questions.

## When to Use

- User asks to "brief me on this meeting" or "what's in this meeting for me"
- User wants to extract TODOs or action items from a meeting
- User provides a meeting transcript (.vtt) or meeting notes (.md, .docx)
- User references `/meeting-briefing` with a file path

## Usage

```
/meeting-briefing <path-to-meeting-file>
/meeting-briefing 00_Meetings/2026-06-08_some-meeting.vtt
```

If no file is provided, list recent files in `00_Meetings/` and ask the user to pick one.

## How It Works

### Step 1: Read and Parse the Meeting

1. **Read the meeting file** at the provided path
2. **Identify the format**:
   - `.vtt` — WebVTT transcript with speaker tags (`<v Speaker Name>...</v>`)
   - `.md` — Markdown meeting notes
   - `.docx` — Word document (read as-is, extract text content)
3. **Extract metadata** from the filename and content:
   - Date (from filename pattern `YYYY-MM-DD_...`)
   - Meeting title (from filename, cleaned up)
   - Participants (from speaker tags in VTT, or mentioned names)
   - Duration (from first/last timestamp in VTT)

### Step 2: Interpret the Content

**Critical: VTT transcripts are auto-generated and very noisy.** They come from speech-to-text that struggles with:
- German language (the meetings are primarily in German)
- Mixed German/English technical jargon
- Names of people and systems

When interpreting, apply these strategies:
- **Use domain knowledge**: The meetings are about the New Dispo project. Known systems: TMS, TMS Bridge, AlloyDB, Oracle CDC, Frontend, Backend, TOP, Cloud Functions, GCP. Known people: Matthias (Max), Maximilian (Kehder), Boyan, Martin, Christian, Nikolay, Pascal, Sebastian, Holger, Patrick, Joachim, Ron, Andreas.
- **Read through the noise**: "Dispo" might appear as "dispose", "display", etc. "Sendung" might appear as anything. "Verkehrsart" (traffic mode) often appears as "traffic mode". "Zustellung" (delivery) and "Abholung" (pickup) are common domain terms.
- **Focus on signal, not noise**: Short acknowledgments ("Yeah", "Mhm", "Okay", "Lapp") are just filler — skip them. Focus on longer utterances that carry meaning.
- **Be honest about uncertainty**: If a section is too garbled to interpret, say so rather than guessing.

### Step 3: Generate the Briefing

Produce a structured briefing with these sections. **Only include sections that have content.**

#### Output Structure

```markdown
# Meeting Briefing: {Meeting Title}

**Date:** {YYYY-MM-DD}
**Participants:** {list}
**Duration:** ~{X} min

---

## Topics Discussed

Numbered list of topics that came up, with 1-2 sentence summary each. Group related discussion points.

## Decisions Made

Bullet list of decisions or agreements reached. Include who decided/agreed.

## Action Items for Matthias

| # | Action | Context | Urgency |
|---|--------|---------|---------|
| 1 | What needs to be done | Why / from which discussion | High/Medium/Low |

## Action Items for Others

| Owner | Action | Context |
|-------|--------|---------|
| Name | What | Why |

## Topics Needing Matthias's Attention

Things discussed that Matthias should be aware of or may need to follow up on, even if no explicit action was assigned.

## Open Questions

Unresolved questions or items that were discussed but not concluded.

## Transcript Quality

Brief note on how interpretable the transcript was. Flag sections where the interpretation is uncertain.

---

<div align="center">
  <sub>Created by <strong>Virtual Architect</strong></sub>
</div>
```

### Step 4: Write to File

Save the briefing to `00a_MeetingBriefs/` with `-BRIEFING` suffix:

```
00a_MeetingBriefs/{original-filename}-BRIEFING.md
```

Example: `00_Meetings/2026-06-08_Some-Meeting.vtt` produces `00a_MeetingBriefs/2026-06-08_Some-Meeting-BRIEFING.md`

## Interpretation Guidelines

### Identifying Action Items

Look for these patterns (in both German and English):
- Direct assignments: "Matthias, kannst du..." / "Max, can you..."
- Self-assignments: "Ich mach das" / "I'll do that" (by Matthias)
- Implicit assignments based on role: architecture decisions, solution designs, explorations, emails to stakeholders
- Follow-up items from discussion: "das muss noch..." / "we still need to..."

### Urgency Classification

- **High**: Blocking other work, mentioned as urgent, needed before a deadline
- **Medium**: Important but not immediately blocking, part of current sprint work
- **Low**: Nice-to-have, future consideration, background task

### Topic Extraction

Group the conversation into coherent topics. A topic change is signaled by:
- Explicit transitions ("OK, next topic", "und dann...")
- New subject matter being introduced
- Shift to a different system or work item

## Tone

- Factual and concise — this is a work briefing, not meeting minutes
- Use technical terms as the team uses them (don't translate domain jargon)
- When uncertain, mark with [?] rather than omitting
- Prefer German domain terms where that's what the team uses (Sendung, Verkehrsart, Zustellung, Abholung)

## Output

- Writes the briefing markdown file to `00a_MeetingBriefs/`
- Displays the full briefing to the user
- Reports the file path
