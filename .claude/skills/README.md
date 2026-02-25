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
