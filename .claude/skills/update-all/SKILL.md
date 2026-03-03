---
name: update-all
description: Update all repositories and wikis in one command. Runs update-repos followed by update-wikis. Use when the user asks to update everything, sync all, or refresh the entire codebase and documentation.
tools: Bash
---

# Update All Skill

Comprehensive update that runs both update-repos and update-wikis in sequence.

## When to Use

- User asks to "update everything", "sync all", "pull everything", or "refresh all"
- Before starting a work session to ensure all content is current
- When you need both code and documentation to be up to date

## How It Works

This skill runs two update processes in sequence:
1. **update-repos** - Updates all Code repositories
2. **update-wikis** - Updates all Wiki repositories

## What Gets Updated

**Code Repositories:**
- tms-alloydb-schema (TMS Database)
- Disposition-Abstraction-Layer (TMS Bridge)
- Disposition-Backend (New Dispo Backend)
- Disposition-Frontend (New Dispo Frontend)
- Nagel-GCP (Cloud Functions)

**Wiki Repositories:**
- Nagel-CAL-Disposition.wiki
- Any other wikis

## Output

Provides combined status for all repositories:
- Section headers for Code and Wiki updates
- ✓ Success indicators per repository
- ⚠️ Warning/failure indicators
- Final summary of all updates
