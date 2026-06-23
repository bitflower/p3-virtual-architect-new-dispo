---
name: loop-watch-sources
description: Fetch wiki and TMS Bridge repos, check Azure DevOps for new/updated bugs, run sync skills if needed, send one combined notification email. Use as /loop target, e.g. /loop 5m /loop-watch-sources.
allowed-tools: Bash,Read,Glob,Grep
---

# Loop Watch Sources

Combined loop that watches all upstream sources (wiki, TMS Bridge, Azure DevOps bugs), runs the appropriate sync skills when changes are detected, and sends a single notification email with all changes.

## When to Use

- As a `/loop` target: `/loop 5m /loop-watch-sources`
- User asks to "watch for changes", "keep things in sync", or "monitor upstream"

## How It Works

### Step 1 — Fetch both repos

Run in sequence (not parallel — keep git operations predictable):

```bash
git -C WIKI/Nagel-CAL-Disposition.wiki fetch origin --quiet
git -C Code/Disposition-Abstraction-Layer fetch origin --quiet
```

If either fetch fails (e.g. network down), log the error but continue with the other repo.

### Step 2 — Check for new wiki commits

```bash
git -C WIKI/Nagel-CAL-Disposition.wiki log wikiMaster..origin/wikiMaster --oneline
```

If output is non-empty, store it as `wiki_commits`. Otherwise `wiki_commits` is empty.

### Step 3 — Check for new TMS Bridge commits

```bash
git -C Code/Disposition-Abstraction-Layer log master..origin/master --oneline
```

If output is non-empty, store it as `bridge_commits`. Otherwise `bridge_commits` is empty.

### Step 4 — Check Azure DevOps for new/updated bugs

Read the watermark timestamp from `.claude/skills/loop-watch-sources/last-bug-check.txt`. If the file doesn't exist, use "5 minutes ago" as the initial watermark.

Use `mcp__azure-devops__wit_query_by_wiql` (load via ToolSearch first) with project `Nagel-CAL Disposition` and this WIQL:

```sql
SELECT [System.Id], [System.Title], [System.State], [System.CreatedDate],
       [System.ChangedDate], [System.AssignedTo], [System.Reason]
FROM WorkItems
WHERE [System.TeamProject] = 'Nagel-CAL Disposition'
  AND [System.WorkItemType] = 'Bug'
  AND [System.ChangedDate] >= '{watermark_iso}'
ORDER BY [System.ChangedDate] DESC
```

Where `{watermark_iso}` is the stored timestamp in ISO 8601 format (e.g. `2026-06-23T09:30:00Z`).

If the query returns results, fetch each work item's details via `mcp__azure-devops__wit_get_work_item` and categorize:
- **NEW**: `CreatedDate >= watermark` → newly filed bug
- **UPDATED**: `CreatedDate < watermark` → existing bug with state or field changes

Store results as `bug_changes`. Update the watermark file to the current UTC timestamp.

If the query returns no results, `bug_changes` is empty. Still update the watermark.

### Step 5 — Early exit if nothing changed

If `wiki_commits`, `bridge_commits`, and `bug_changes` are all empty, report "No changes detected" and stop. Do NOT send an email.

### Step 6 — Pull and sync wiki (if changed)

If `wiki_commits` is non-empty:

```bash
git -C WIKI/Nagel-CAL-Disposition.wiki pull --ff-only
```

If pull fails, record the error in `wiki_result` and skip the sync.
If pull succeeds, invoke `/reverse-wiki-sync` and capture its output as `wiki_result`.

### Step 7 — Pull and sync TMS Bridge (if changed)

If `bridge_commits` is non-empty:

```bash
git -C Code/Disposition-Abstraction-Layer pull --ff-only
```

If pull fails, record the error in `bridge_result` and skip the sync.
If pull succeeds, invoke `/sync-db-registry` and capture its output as `bridge_result`.

### Step 8 — Send combined notification email

Construct the email subject and body, then invoke `/send-notification-email`.

**Subject format:**
`[VA] {summary}`

Where `{summary}` is a compact description combining all detected changes, e.g.:
- `3 wiki + 2 TMS Bridge commits, 1 new bug`
- `5 wiki commits`
- `2 new bugs, 1 bug updated`
- `4 TMS Bridge commits, 3 bugs updated`

**Body format:**

```
Changes detected at {timestamp}.

--- Wiki ({N} commits) ---

{wiki_commits — the raw git log --oneline output}

Sync result:
{wiki_result — output from /reverse-wiki-sync}

--- TMS Bridge ({N} commits) ---

{bridge_commits — the raw git log --oneline output}

Sync result:
{bridge_result — output from /sync-db-registry}

--- Bugs ({N} new, {M} updated) ---

New:
  #12345 "Title here" [New] — Assigned to: Nobody
  #12346 "Another bug" [New] — Assigned to: Developer X

Updated:
  #12340 "Existing bug" [Active → Resolved] — Assigned to: Developer Y
  #12341 "Old issue" [New → Active] — Assigned to: Developer Z

---
Wiki/TMS Bridge changes are in the working tree (uncommitted).
Bug tickets: https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems
```

Omit sections where no changes were detected. For example, if only bugs changed, omit the Wiki and TMS Bridge sections entirely.

### Step 9 — Report to conversation

Output the same summary to the conversation (identical to the email body). This way the loop produces output regardless of whether email delivery succeeds.

## Error Handling

- **Fetch fails**: Log error, continue with other repo. Include error in email if the other repo had changes.
- **Pull fails**: Log error, skip sync for that repo. Include error in email.
- **Sync skill fails**: Include error output in email body.
- **Email fails**: Log msmtp error to conversation. The sync results are still applied — email failure does not block the sync.
- **Nothing changed**: No email, no conversation output beyond "No changes detected".
- **Bug query fails**: Log MCP error, continue with other checks. Include error in email if other sources had changes.
- **ToolSearch fails**: Log error for bug check, continue with git-based checks.
