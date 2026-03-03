---
name: update-repos
description: Fetch and pull appropriate branches for all repositories in the Code folder. For TMS Database uses x.x.x.x+New-DISPO pattern, others use master/main. Use when the user asks to update repos, pull all repos, sync repositories, or refresh the codebase.
tools: Bash
---

# Update Repositories Skill

Updates all git repositories in the Code folder by fetching and pulling their appropriate branches.

## When to Use

- User asks to "update repos", "pull all repos", "sync repositories", or "refresh the codebase"
- Before starting work to ensure the latest code is available
- When checking for recent changes across all repositories

## How It Works

This skill:
1. Navigates to each repository in the Code directory
2. Fetches all remotes
3. For **TMS Database (tms-alloydb-schema)**:
   - Looks for branches matching pattern `x.x.x.x+New-DISPO` (e.g., `1.2.3.4+New-DISPO`)
   - Falls back to `master` or `main` if pattern not found
4. For all other repos:
   - Detects whether it uses `master` or `main` branch
5. Checks out and pulls the appropriate branch

## Repositories Updated

- **tms-alloydb-schema** (TMS Database)
- **Disposition-Abstraction-Layer** (TMS Bridge)
- **Disposition-Backend** (New Dispo Backend)
- **Disposition-Frontend** (New Dispo Frontend)
- **Nagel-GCP** (Cloud Functions)

## Output

Provides clear status for each repository:
- ✓ Success indicators
- ⚠️ Warning/failure indicators
- Summary of updated repositories
