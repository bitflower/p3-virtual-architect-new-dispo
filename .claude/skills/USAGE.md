# How to Use Claude Code Skills

## The `/explore` Skill

### Purpose
Quickly start a new exploration with proper folder structure and markdown template.

### How to Use

Simply type `/explore` followed by your topic:

```
/explore User Story 103821: OMS Sendung Quell_K analysis
```

or with Claude:

```
Hey Claude, /explore Database performance issues in TMS Bridge
```

### What Gets Created

When you run `/explore User Story 12345: My Topic`, it creates:

```
02_Explorations/
└── 2026-02-25_User_Story_12345_My_Topic/
    └── user-story-12345-my-topic.md
```

The markdown file includes:
- **Your topic** as the title
- **Current date** automatically filled
- **Original User Input** section (for you to fill with context)
- **Template sections** for structured exploration

### Important Rules

1. **Always keep original input at top**: After the file is created, paste your original context/input in the "Original User Input" section
2. **One exploration per folder**: Each exploration gets its own dated folder
3. **Descriptive topics**: Use clear, searchable topic names

### Example Workflow

```bash
# 1. Start exploration
/explore Analyzing SetDriver database side effects

# 2. Claude creates:
#    02_Explorations/2026-02-25_Analyzing_SetDriver_database_side_effects/
#                    analyzing-setdriver-database-side-effects.md

# 3. Open the file and paste your original context at the top

# 4. Claude helps you fill in the sections as you explore
```

### Tips

- Use clear, descriptive topics that include user story numbers or key terms
- Don't worry about folder name length - it gets truncated automatically
- Special characters are removed from folder names automatically
- The skill prevents overwriting existing explorations

## Creating More Skills

Want to create another skill? Just:

1. Create a new executable bash script in `.claude/skills/`
2. Make it executable: `chmod +x .claude/skills/your-skill`
3. Document it in `README.md`
4. Use it with `/your-skill`

Example skill structure:

```bash
#!/bin/bash
# Skill: your-skill
# Description: What it does
# Usage: /your-skill <args>

# Your script logic here
echo "Doing something useful..."
```
