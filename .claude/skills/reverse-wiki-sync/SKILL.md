---
name: reverse-wiki-sync
description: Sync wiki changes back to local files using publish-mappings.json in reverse. Preserves <!-- internal --> blocks and excludeSections in local files. Use when wiki pages were edited directly and local files need to catch up.
allowed-tools: Bash,Read,Write,Edit,Glob,Grep
---

# Reverse Wiki Sync

Pulls changes from `WIKI/Nagel-CAL-Disposition.wiki` back into local source files, using the publish-mappings.json as a reverse index. This is the inverse of `/wiki-connector` (which publishes local → wiki).

## When to Use

- Wiki pages were edited directly (by team members, during meetings, etc.)
- As target of `/loop-reverse-wiki-sync` for continuous sync
- User asks to "pull from wiki", "sync from wiki", or "reverse sync"

## How It Works

### Step 1 — Load reverse index

Read `.claude/skills/wiki-connector/publish-mappings.json`. Build a reverse lookup: for each mapping, the `target` (wiki path) becomes the source and `source` (local path) becomes the destination.

Only process mappings where **both** files exist on disk. Skip mappings where either file is missing (report as skipped).

### Step 2 — Diff each mapping pair

For each mapping, compare the wiki file against the local file's "published view" (i.e. local file minus internal blocks and excluded sections). If they're identical, skip — no changes needed.

To compute the "published view" of the local file:
1. Strip all content between `<!-- internal -->` and `<!-- /internal -->` markers (inclusive of the markers themselves)
2. Strip sections listed in the mapping's `excludeSections` array (the heading line and all content until the next heading of same or higher level)
3. If `linkRewriting.enabled`, apply the same link rewriting that publish would (local paths → wiki paths) so the comparison is apples-to-apples

Compare this published view against the wiki file content. If they match, skip this mapping.

### Step 3 — Preserve internal blocks from local file

Before modifying the local file, extract all protected content with position anchors:

**Internal blocks** (`<!-- internal -->` ... `<!-- /internal -->`):
- For each block, record its **anchor heading**: the nearest preceding markdown heading (`#`, `##`, `###`, etc.)
- If the block appears before any heading, anchor it as `__file-start__`
- If the block appears after the last heading's content (at the very end), anchor it as `__file-end__`
- Record the block's position relative to the anchor: `after-heading` (immediately after the heading line) or `end-of-section` (at the end of the section, before the next heading)

**Excluded sections** (from `excludeSections` in mapping):
- Record the full section content (heading + all body until next heading of same/higher level)
- Record the preceding heading as anchor

### Step 4 — Apply wiki content to local file

Start with the wiki file content as the base.

**Reverse link rewriting** (if `linkRewriting.enabled` in the mapping):
- Rewrite wiki-style paths back to local relative paths
- This is best-effort — use the mapping's source/target paths to infer the path transformation

**Re-insert internal blocks:**
- For each saved internal block, find its anchor heading in the new content
- Insert the block at its recorded position (after heading or end of section)
- If the anchor heading no longer exists, append the block at the end of the file with a warning comment: `<!-- WARNING: anchor heading "{heading}" was removed from wiki, orphaned internal block below -->`

**Re-insert excluded sections:**
- Insert each excluded section at its original position relative to surrounding headings
- If surrounding context changed, append at end of file with a similar warning

### Step 5 — Write and report

For each mapping where changes were applied:
1. Write the updated local file
2. Do NOT commit — leave changes in the working tree

Output a summary:
- Number of mappings checked
- Number of mappings with changes (list each: mapping id, local path, brief description of what changed)
- Number of mappings skipped (unchanged)
- Number of mappings skipped (file missing)
- Any warnings about orphaned internal blocks or excluded sections

## Edge Cases

- **New wiki page with no local file**: Skip — reverse sync only updates existing local files, it doesn't create new ones
- **Local file with no internal blocks**: Simple replacement — wiki content becomes the local file
- **Mapping with `scope: "sections"` and `trackingSections`**: Only reverse-sync the tracked sections, leave the rest of the local file untouched
- **Date markers**: When reverse-syncing section-scoped mappings, preserve the date marker structure — update content within managed regions only
