---
name: update-wikis
description: Fetch and pull all Wiki repositories in the WIKI folder. Use when the user asks to update wikis, pull wiki repos, sync wiki documentation, or refresh wiki content.
tools: Bash
---

# Update Wikis Skill

Updates all Wiki git repositories in the WIKI folder by fetching and pulling their master/main branches.

## When to Use

- User asks to "update wikis", "pull wiki repos", "sync wiki documentation", or "refresh wikis"
- Before working on documentation to ensure latest wiki content
- When checking for wiki updates

## How It Works

This skill:
1. Navigates to each repository in the WIKI directory
2. Fetches all remotes
3. Detects whether it uses `master` or `main` branch
4. Checks out and pulls the appropriate branch

## Repositories Updated

- **Nagel-CAL-Disposition.wiki** ("New TMS" Wiki)
- Any other wiki repositories in the WIKI folder

## Output

Provides clear status for each wiki repository:
- ✓ Success indicators
- ⚠️ Warning/failure indicators
- Summary of updated wikis
