# Claude Code Skills

This directory contains custom skills for Claude Code to help automate common workflows.

## Available Skills

### `/explore` - Start New Exploration

Creates a new exploration with proper folder structure and markdown template.

### `/extract-trace` - Extract Tour Calculation Trace

Extracts and consolidates trace logs from all three components (Frontend, Backend, TMS Bridge) after a tour calculation. Creates a timestamped folder with complete JSON analysis and README.

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
