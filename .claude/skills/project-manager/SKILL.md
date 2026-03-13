# Project Manager Skill

Create and manage living project documentation that stays up-to-date as projects evolve.

## Overview

This skill manages **two separate document spaces**:

1. **Local (Exploration Folder)**: Internal working document with all details, internal links, and exploration references
2. **Wiki**: Clean, client-facing document with transformed links and no internal references

The mapping between local and wiki documents is managed in `.claude/skills/wiki-connector/publish-mappings.json`.

## When to Use

- Creating a new project tracking document
- Updating project status, milestones, or blockers
- Moving items between status categories (completed, in progress, next up)
- Adding team members, documentation links, or meeting notes
- Marking phases complete or updating timelines
- Syncing local changes to wiki for stakeholder visibility

## Commands

### Create New Project
```bash
/project-manager create <project-name> <folder-path> [wiki-filename]
```
Creates a new project from template in the specified exploration folder with automatic wiki mapping.

### Update Project Status
```bash
/project-manager update <project-file> --status "In Progress|Completed|On Hold"
```
Updates the overall project status.

### Move Item
```bash
/project-manager move-item <project-file> --item "Item description" --from "in-progress" --to "completed"
```
Moves an item between status sections.

### Add Entry
```bash
/project-manager add <project-file> --section "completed|in-progress|next-up|blockers" --item "Description" [--link "URL"]
```
Adds a new item to a specific section.

### Sync to Wiki
```bash
/project-manager sync <project-file>
```
Syncs the project status document to wiki:
- Reads mapping from `publish-mappings.json`
- Copies content from local to wiki
- Removes internal exploration links
- Keeps wiki-appropriate content only
- Provides git commit instructions

## Emoji Usage

The skill uses emojis sparingly, following the established style:

**Status Indicators (used sparingly):**
- ✅ Completed items
- 🔄 In Progress items
- ⏳ Scheduled/Pending items
- 🟢 🟡 🔴 Health indicators only

**No emojis in:**
- Main heading (# Project: ...)
- Section headers (## Timeline, ## Team, etc.)
- Body text
- Descriptions
- Team member lists
- Documentation links

## Integration

This skill works with:
- Exploration folders in `02_Explorations/` (local working space)
- Wiki folder in `WIKI/Nagel-CAL-Disposition.wiki/Projects/` (client communication)
- Mapping file: `.claude/skills/wiki-connector/publish-mappings.json`
- Templates:
  - `999_Tools/PROJECT-STATUS-TEMPLATE.md` (local)
  - `999_Tools/PROJECT-STATUS-WIKI-TEMPLATE.md` (wiki)

## Document Philosophy

**Local Document (Exploration Folder)**:
- Full details and context
- Links to internal exploration files
- Meeting notes, analyses, internal references
- "Working space" for the team

**Wiki Document (WIKI/Projects/)**:
- Clean, professional presentation
- No internal exploration links
- Client-facing content only
- "Landing zone" for stakeholders

Links in local documents (e.g., `[Details](2026-03-13_analysis.md)`) are automatically removed in wiki version, keeping only the text.

## Output

Creates or updates PROJECT-STATUS.md files with:
- Current status overview
- Timeline and milestones
- Team assignments
- Related documentation
- Automatic change log
- Last updated timestamp
