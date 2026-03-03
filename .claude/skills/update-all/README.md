---
name: update-all
description: Update all repositories (both Code and WIKI folders) in parallel. Use when the user asks to update everything, sync all repos, pull all changes, or refresh the entire codebase and documentation.
tools: Bash
---

# Update All Repositories and Wikis

Updates all git repositories in both the Code and WIKI folders simultaneously by running both update tasks in parallel.

## When to use this skill

- User asks to "update everything", "update all", "pull all repos", "sync everything", or "refresh all"
- User wants to ensure both code repositories and wiki documentation are up to date
- Before starting work to ensure the entire project is synced with remotes
- Default choice when user mentions updating without specifying Code or WIKI specifically

## What this skill does

1. Runs **update-repos** in parallel (for Code folder)
2. Runs **update-wikis** in parallel (for WIKI folder)
3. Waits for both operations to complete
4. Reports combined status from both updates

## How to use this skill

The skill automatically runs the update script:

```bash
./update-all.sh
```

The script will:
- Launch both update operations simultaneously
- Show real-time output from both processes
- Wait for both to complete
- Provide a combined success/failure status

## Repositories managed

This skill updates:

**Code Repositories:**
- tms-alloydb-schema (TMS Database) - uses x.x.x.x+New-DISPO branch pattern
- Disposition-Abstraction-Layer (TMS Bridge)
- Disposition-Backend (New Dispo Backend)
- Disposition-Frontend (New Dispo Frontend)

**Wiki Repositories:**
- Nagel-CAL-Disposition.wiki
- Any other wiki repositories in the WIKI folder

## Output

The script provides:
- Parallel output from both update processes
- Clear indicators of which process each message comes from
- Combined summary showing success/failure for both operations
- Exit code reflects overall status (fails if either operation fails)

## Related Skills

- **update-repos** - Update only Code folder repositories
- **update-wikis** - Update only WIKI folder repositories

Use these individual skills when you only need to update one type of repository.
