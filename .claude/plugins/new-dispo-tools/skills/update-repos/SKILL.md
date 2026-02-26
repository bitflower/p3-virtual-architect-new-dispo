---
name: update-repos
description: Fetch and pull appropriate branches for all repositories in the Code folder. For TMS Database uses x.x.x.x+New-DISPO pattern, others use master/main. Use when the user asks to update repos, pull all repos, sync repositories, or refresh the codebase.
tools: Bash
---

# Update All Repositories

Updates all git repositories in the Code folder by fetching and pulling their appropriate branches (New-DISPO branch for TMS Database, master/main for others).

## When to use this skill

- User asks to "update repos", "pull all repos", "sync all repositories", or "refresh the codebase"
- User wants to ensure all repositories are up to date with their remotes
- Before starting work to ensure the latest code is available

## What this skill does

1. Navigates to the Code directory
2. Loops through all subdirectories
3. For each git repository:
   - Fetches all remotes
   - For **TMS Database (tms-alloydb-schema)**:
     - First looks for branches matching pattern `x.x.x.x+New-DISPO` (e.g., `1.2.3.4+New-DISPO`)
     - Falls back to `master` or `main` if pattern not found
   - For all other repos:
     - Detects whether it uses `master` or `main` branch
   - Checks out the appropriate branch
   - Pulls the latest changes from origin
4. Provides clear status output for each repository

## How to use this skill

Simply run the update script that's already in place:

```bash
./update-all-repos.sh
```

The script will automatically:
- Skip non-git directories
- Handle both master and main branches
- Show progress for each repository
- Indicate any issues encountered

## Repositories managed

This skill updates all four New Dispo components:
- tms-alloydb-schema (TMS Database)
- Disposition-Abstraction-Layer (TMS Bridge)
- Disposition-Backend (New Dispo Backend)
- Disposition-Frontend (New Dispo Frontend)

## Output

The script provides:
- Clear section headers for each repository
- Status indicators (✓ for success, ⚠️ for warnings)
- Final summary when all updates are complete
