# Wiki Connector Plugin

A Claude Code plugin for publishing local concept and exploration files to the WIKI documentation.

## Purpose

This plugin helps maintain consistency between local working documents (explorations, documentation drafts) and their published versions in the WIKI by managing mappings and automating the synchronization process.

**Key Feature**: Uses a **git-like diff approach** - only changed content is synchronized, never blindly overwriting entire files or sections. This ensures safe, precise updates while preserving manual edits in the WIKI.

## Files

- `plugin.json` - Plugin metadata and configuration
- `publish-mappings.json` - Mappings between local files and WIKI targets
- `publish-concept.md` - The `/publish-concept` skill implementation
- `README.md` - This file

## Usage

### Publish Current File
If you have a mapped file open in your editor:
```bash
/publish-concept
```

### Publish by Mapping ID
```bash
/publish-concept driver-data-user-story
/publish-concept shipment-data-flow
```

## Adding New Mappings

Edit `publish-mappings.json` and add a new entry:

```json
{
  "id": "unique-identifier",
  "source": "path/to/local/file.md",
  "target": "WIKI/path/to/target.md",
  "description": "Human-readable description",
  "syncStrategy": {
    "type": "diff-sync",
    "scope": "full-document" | "sections",
    "trackingSections": ["Section Name 1", "Section Name 2"],
    "dateMarkers": {
      "enabled": true,
      "format": "*(Added: YYYY-MM-DD)*",
      "endFormat": "*(End Added: YYYY-MM-DD)*"
    },
    "notes": "Additional notes"
  }
}
```

### Sync Strategies

All syncs use **diff-based synchronization** - only changes are applied, never full replacements.

**Full Document Scope** (`scope: "full-document"`):
- Diffs entire source file against entire target
- Every line is potentially managed
- Use for standalone documentation articles where the entire file is owned by the source

**Section Scope** (`scope: "sections"`):
- Diffs only specified sections
- Uses date markers to identify managed regions in target
- Preserves untracked sections and content
- Use when local file contributes specific sections to a larger WIKI page

## How Diff-Based Sync Works

The plugin uses a git-like approach to synchronization:

1. **Calculate Diff**: Compare source and target line-by-line (within scope)
2. **Show Preview**: Display unified diff with additions (+), deletions (-), modifications (~)
3. **Get Approval**: Ask user to confirm before writing
4. **Apply Changes**: Only write changed lines, preserve everything else
5. **Detect Conflicts**: Warn if target was modified since last sync

### Example

**Source file** (local exploration):
```markdown
## Implementation Status *(Added: 2026-02-26)*
- Feature implemented ✓
- Tests passing ✓
- Ready for deployment
*(End Added: 2026-02-26)*
```

**Target file** (WIKI before sync):
```markdown
## Implementation Status *(Added: 2026-02-26)*
- Feature implemented ✓
- Tests pending
*(End Added: 2026-02-26)*
```

**Diff to apply**:
```diff
 ## Implementation Status *(Added: 2026-02-26)*
 - Feature implemented ✓
-- Tests pending
++ Tests passing ✓
++ Ready for deployment
 *(End Added: 2026-02-26)*
```

Only the changed lines are updated - everything else in the WIKI remains untouched.

## Current Mappings

1. **driver-data-user-story**: Driver data user story → Edit Flow Part 2 feature outline
   - Scope: sections (Business Constraints, Hardening Solution, Implementation Status)
   - Uses date markers to track managed regions

2. **shipment-data-flow**: Shipment data flow architecture documentation
   - Scope: full-document
   - Entire file is managed by source

## Maintenance

When WIKI structure changes:
1. Update target paths in `publish-mappings.json`
2. Verify section names match if using partial sync
3. Test publish to ensure correct sections are updated
