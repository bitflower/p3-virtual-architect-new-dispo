---
name: update-wikis
description: Fetch and pull all wiki repositories in the WIKI folder. Use when the user asks to update wikis, pull wikis, sync wiki documentation, or refresh wiki content.
tools: Bash
---

# Update All Wiki Repositories

Updates all git repositories in the WIKI folder by fetching and pulling the latest changes.

## When to use this skill

- User asks to "update wikis", "pull wikis", "sync wiki documentation", or "refresh wiki content"
- User wants to ensure all wiki repositories are up to date with their remotes
- Before reviewing documentation to ensure the latest content is available

## What this skill does

1. Navigates to the WIKI directory
2. Loops through all subdirectories
3. For each git repository:
   - Fetches all remotes
   - Detects the default branch (master or main)
   - Pulls the latest changes from origin
4. Provides clear status output for each wiki repository

## How to use this skill

The skill automatically runs the update script:

```bash
./update-wikis.sh
```

The script will automatically:
- Skip non-git directories
- Handle both master and main branches
- Show progress for each wiki repository
- Indicate any issues encountered

## Repositories managed

This skill updates all wiki repositories in the WIKI folder:
- Nagel-CAL-Disposition.wiki (currently)
- Any other wiki repositories added to the WIKI folder

## Output

The script provides:
- Clear section headers for each wiki repository
- Status indicators (✓ for success, ⚠️ for warnings)
- Final summary when all updates are complete
