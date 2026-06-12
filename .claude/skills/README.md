# Claude Code Skills

This directory contains custom skills for Claude Code to help automate common workflows.

## Available Skills

### `/explore` - Start New Exploration

Creates a new exploration with proper folder structure and markdown template.

**Usage:**
```bash
/explore <topic description>
```

**Examples:**
```bash
/explore User Story 103821: OMS Sendung Quell_K analysis
/explore Database performance issue in SetDriver
/explore SignalR implementation considerations
```

**What it does:**
1. Creates a folder in `02_Explorations/` with format: `YYYY-MM-DD_Topic_Description`
2. Creates a markdown file inside the folder
3. Adds a template with sections for:
   - Original User Input (to be filled with your actual content)
   - Summary
   - Analysis
   - Database Schema
   - Source Code Evidence
   - Findings
   - Questions/Open Items
   - Related Files
   - Related User Stories/Tasks

**Important:** After running the skill, remember to:
1. Replace the "Original User Input" section with your actual input/context
2. Keep the original input at the top of the document
3. Fill in the relevant sections as you conduct the exploration

---

### `/extract-diagram` - Extract Mermaid Diagrams to Versioned SVG

Extracts Mermaid diagrams from markdown documentation and creates versioned SVG diagrams in `07_Diagrams/Architecture/`.

**Usage:**
```bash
/extract-diagram <source-markdown-file>
/extract-diagram -n <custom-name> -t "<custom-title>" <source-file>
```

**Examples:**
```bash
# Extract diagram with auto-generated name
/extract-diagram 02_Explorations/2026-03-24_My-Analysis/flow-diagram.md

# Extract with custom name and title
/extract-diagram -n auth-flow -t "Authentication Flow" path/to/file.md
```

**What it does:**
1. Extracts the first Mermaid diagram from a source markdown file
2. Creates a new markdown file in `07_Diagrams/Architecture/` with diagram + metadata
3. Generates an SVG from the Mermaid diagram using `mmdc`
4. Updates the original file to replace the Mermaid code block with an SVG reference

**Benefits:**
- ✅ Single source of truth for diagrams
- ✅ Versioned SVG assets (committed to git)
- ✅ Universal rendering (SVG works everywhere)
- ✅ Easy to update (edit .md, regenerate SVG)
- ✅ Text-based source (good git diffs)

**Requirements:**
- Mermaid CLI: `npm install -g @mermaid-js/mermaid-cli`
- Source file must contain at least one Mermaid code block (` ```mermaid `)

**Output:**
- Creates `07_Diagrams/Architecture/{diagram-name}.md` (source)
- Creates `07_Diagrams/Architecture/{diagram-name}.svg` (generated)
- Updates source file to reference SVG
- Creates `.bak` backup of original file

**Related docs:**
- See `.claude/skills/extract-diagram/README.md` for detailed usage
- See `README.md` in project root for diagram generation requirements

---

### `/extract-trace` - Extract Tour Calculation Trace

Extracts and consolidates trace logs from all three components (Frontend, Backend, TMS Bridge) and creates a complete analysis.

**Usage:**
```bash
/extract-trace
```

**What it does:**
1. Prompts you to paste the Frontend console log (including trace ID)
2. Extracts the trace ID and finds matching logs in Backend and TMS Bridge
3. Creates a timestamped folder in `02_Explorations/2026-03-10_holistic-tour-calculation-tracing/trace-logs/`
4. Copies all 3 log files (Frontend, Backend, TMS Bridge)
5. Generates `complete-trace.json` with:
   - All 14 capture points in chronological order
   - Performance metrics and breakdown
   - Bottleneck identification
6. Generates `README.md` with:
   - Timeline table (with step duration and cumulative time)
   - Performance analysis
   - Visual timeline
   - Key findings

**Prerequisites:**
- Backend and TMS Bridge must be running and writing logs to files
- Serilog must be configured with Console and File sinks at Information level
- A tour calculation must have been performed

**Example console log to paste:**
```
[TraceIdService] Generated new trace ID: 6837d454-6b09-41d5-be55-be6316e3790d
[CalculateRoutesService] Starting tour calculation for order 10340432603203...
[TraceCaptureService] {"traceId":"6837d454-6b09-41d5-be55-be6316e3790d",...}
...
```

**Output folder structure:**
```
trace-logs/
└── 2026-03-10_18-23-37_trace-6837d454/
    ├── complete-trace.json          ← Structured JSON (all capture points + metrics)
    ├── frontend-console-log.txt     ← Your pasted log
    ├── backend-log-20260310.txt     ← Auto-fetched from Backend
    ├── tms-bridge-log-20260310.txt  ← Auto-fetched from TMS Bridge
    └── README.md                     ← Timeline and performance analysis
```

**What gets analyzed:**
- **14 capture points** across Frontend (2), Backend (8), TMS Bridge (4)
- **Performance timing** for each step
- **Cumulative execution time** from start to each point
- **Bottleneck identification** (typically TOP Service optimization)
- **Component breakdown** (time spent in each service)

**Tips:**
- Run immediately after a tour calculation (easier to find in fresh logs)
- Use DevTools Console filter: `TraceIdService OR TraceCaptureService`
- Ensure all services are running and writing logs

**Related docs:**
- See `02_Explorations/2026-03-10_holistic-tour-calculation-tracing/trace-logs/HOW-TO-EXTRACT-TRACES.md`
- See `.claude/skills/extract-trace/README.md` for detailed usage

---

### `/project-manager` - Manage Living Project Documentation

Creates and manages living project documentation that stays current as work progresses.

**Usage:**
```bash
# Create new project
/project-manager create "<project-name>" "<exploration-folder>"

# Update project status
/project-manager update <project-file> --status "<status>"

# Add completed item
/project-manager add <project-file> --section completed --item "<description>" [--link "<file>"]

# Add in-progress item
/project-manager add <project-file> --section in-progress --item "<description>"

# Add next-up item
/project-manager add <project-file> --section next-up --item "<description>"

# Add blocker
/project-manager add <project-file> --section blockers --item "<description>"
```

**Examples:**
```bash
/project-manager create "Oracle CDC POC" "02_Explorations/2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off"
/project-manager update PROJECT-STATUS.md --status "In Progress"
/project-manager add PROJECT-STATUS.md --section completed --item "GCP infrastructure provisioned"
```

**What it does:**
1. Creates PROJECT-STATUS.md from template with all sections
2. Tracks current status, milestones, and timeline
3. Manages team assignments and stakeholders
4. Links related documentation and meeting notes
5. Maintains automatic change log with timestamps
6. Uses minimal emojis (only 🎯 ✅ 🔄 ⏳)

**Features:**
- Template-based creation with standard structure
- Status management (In Progress, Completed, On Hold)
- Item tracking across completed/in-progress/next-up sections
- Automatic timestamp and change log updates
- Calendar week tracking for completed items (CW XX)
- Integration with wiki-connector for stakeholder visibility

**Output:**
Creates or updates PROJECT-STATUS.md files with:
- Current status overview with minimal emojis
- Timeline and milestones table
- Team and stakeholder lists
- Related documentation links
- Success criteria and health indicators
- Automatic change log

**Two-Space Architecture:**
- **Local** (exploration folders): Internal working documents with all details and internal links
- **Wiki** (WIKI/Projects/): Clean, client-facing documents with transformed content
- Mapping managed in `.claude/skills/wiki-connector/publish-mappings.json`

**Sync Process:**
```bash
# Work locally in exploration folder
/project-manager add PROJECT-STATUS.md --section completed --item "Task done"

# Sync to wiki (removes internal links, keeps clean content)
/project-manager sync PROJECT-STATUS.md

# Result: Wiki updated, ready for client/stakeholder viewing
```

**Templates:**
- `999_Tools/PROJECT-STATUS-TEMPLATE.md` - Local template (internal)
- `999_Tools/PROJECT-STATUS-WIKI-TEMPLATE.md` - Wiki template (client-facing)

**Related docs:**
- See `.claude/skills/project-manager/SKILL.md` for detailed usage
- See example at `02_Explorations/2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off/PROJECT-STATUS.md`
- Mapping file: `.claude/skills/wiki-connector/publish-mappings.json`

---

### `/send-status-update-mail` - Generate Project Status Update Email

Generates a compact, management-style status update email from a project's PROJECT-STATUS.md file, written in Matthias's tone of voice.

**Usage:**
```bash
/send-status-update-mail <project-status-file>
/send-status-update-mail 02_Explorations/.../PROJECT-STATUS.md
```

**What it does:**
1. Reads the PROJECT-STATUS.md and tone of voice reference files
2. Resolves the wiki link from `publish-mappings.json`
3. Drafts a compact email with: key decisions, options, blockers, parallel tracks, pending actions table, next steps
4. Writes the email to `01_Communication/` with date-prefixed naming
5. Adds Virtual Architect branding footer

**Email structure:**
- Subject: `{Topic} — Status Update (CW {NN})`
- Key Decision(s) + Options + Blocker(s)
- Parallel tracks (bullet list with owners)
- Pending Actions table (What | Owner | ETA)
- Next Steps (numbered)
- Wiki link to full project status
- Sign-off: "Thanks!\nMatthias"

**Output:**
- `01_Communication/{YYYY-MM-DD}_{Topic}-Status-Update-CW{NN}.md`
- Virtual Architect footer branding included

**Example:**
- See `01_Communication/2026-04-23_Oracle-CDC-Status-Update-CW17.md`

---

### `/meeting-task-router` - Route Meeting Tasks to Explorations

Takes action items from a meeting briefing, finds matching explorations, and presents options for how to act on each task.

**Usage:**
```bash
/meeting-task-router <path-to-briefing.md>
/meeting-task-router 00a_MeetingBriefs/2026-06-11_some-meeting-BRIEFING.md
```

**What it does:**
1. Parses "Action Items for Matthias" + "Topics Needing Matthias's Attention" from the briefing
2. For each task, searches `02_Explorations/` by folder name and file content for matches
3. Presents a decision block per task: matching explorations, match quality, and concrete options
4. Waits for your input before touching anything
5. Executes chosen actions (update exploration, start new one, etc.)

**Options per task:**
- **Update existing exploration** — integrate meeting context into a matched exploration
- **Start new exploration** — create a new exploration for topics not yet covered
- **No exploration needed** — simple action item (email, config change, conversation)
- **Needs more context** — flag what's missing before you can decide

**Key behavior:**
- Never modifies an exploration without explicit approval
- Fuzzy keyword matching (German/English domain terms, abbreviations)
- Groups tasks that point to the same exploration
- Integrates changes into existing sections (never appends "meeting update" blocks)

---

### `/update-repos` - Update Code Repositories

Fetches and pulls appropriate branches for all repositories in the Code folder.

**Usage:**
```bash
/update-repos
```

**What it does:**
- Updates TMS Database (x.x.x.x+New-DISPO pattern)
- Updates other repos (master/main)
- Shows summary of all updates

---

### `/update-wikis` - Update Wiki Repositories

Fetches and pulls all Wiki repositories in the WIKI folder.

**Usage:**
```bash
/update-wikis
```

**What it does:**
- Updates Nagel-CAL-Disposition.wiki (wikiMaster branch)
- Updates any other wiki repos
- Shows summary of all updates

---

### `/update-all` - Update Everything

Updates all repositories and wikis in one command.

**Usage:**
```bash
/update-all
```

**What it does:**
- Runs update-repos and update-wikis in parallel
- Shows combined summary

---

## Skill Development

### Simple Skills (Single File)
For simple skills with no dependencies:
1. Create an executable bash script in this directory
2. Name it without extension (e.g., `review`, `commit`, etc.)
3. Make it executable: `chmod +x .claude/skills/<skill-name>`
4. Document it in this README

### Complex Skills (Multiple Files)
For skills that need templates, helpers, or multiple files:
1. Create a folder: `.claude/skills/<skill-name>/`
2. Create `skill.sh` as the main executable
3. Add any additional files (templates, configs, helpers)
4. Create a `README.md` in the folder to document the skill
5. Make the script executable: `chmod +x .claude/skills/<skill-name>/skill.sh`
6. Document it in this README

Example structure:
```
.claude/skills/
├── README.md (this file)
├── USAGE.md
├── simple-skill (single file executable)
└── complex-skill/
    ├── skill.sh (main executable)
    ├── template.md (template file)
    ├── helper.sh (helper script)
    └── README.md (skill documentation)
```

## Notes

- Skills are project-specific and stored in `.claude/skills/`
- Use folders for skills with multiple files (templates, helpers, etc.)
- Use single files for simple, standalone skills
- All exploration folders should follow the naming pattern: `YYYY-MM-DD_Topic_Description`
- Markdown files should have descriptive names related to the content
- Always keep original user input at the top of exploration documents
