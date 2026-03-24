# Skill: publish-concept

**Description**: Publishes local concept/exploration files to WIKI documentation using configured mappings.

## Usage
```
/publish-concept [mapping-id]
```

- If `mapping-id` is provided, publish that specific mapping
- If no argument is provided, detect the current file and find matching mapping
- If multiple mappings found, prompt user to select one

## Behavior

When invoked, this skill should:

### 1. Load Mappings

- Read `.claude/skills/wiki-connector/publish-mappings.json` from the plugin directory
- Parse the mappings configuration

### 2. Identify Target Mapping
- If a mapping-id argument is provided, use that mapping
- Otherwise, check if any currently open file matches a source path in mappings
- If no match found, list all available mappings and ask user to select one

### 3. Validate Files
- Verify source file exists and is readable
- Verify target file location (create directory if needed)
- Check if target file exists (warn if it will be created vs updated)

### 4. Execute Diff-Based Sync

All syncs use a **git-like diff approach** - only changed content is updated:

#### Step 4.1: Read Both Files
- Read source file (local concept/exploration)
- Read target file (WIKI)
- If target doesn't exist, this is an initial publish (create new file)

#### Step 4.1b: Handle Attachments (if enabled)
If `attachmentHandling.enabled: true` in syncStrategy:
- Parse source markdown for image references: `![alt](path/to/image.ext)`
- For each image reference:
  1. Resolve relative path from source file location
  2. Check if image file exists
  3. Determine target filename (basename or with hash if needed)
  4. Copy to `WIKI/.attachments/filename`
  5. Store mapping: original path → `/.attachments/filename`
- Apply mappings when writing target content (rewrite all image paths)

#### Step 4.2: Identify Sync Scope

**For `scope: "sections"`** (partial sync):
- Extract only the tracked sections from source file
- Find corresponding sections in target (match by header)
- Use date markers `*(Added: YYYY-MM-DD)*` to identify managed content regions
- Only diff content within these tracked sections

**For `scope: "full-document"`**:
- Diff the entire source against entire target
- Every line is potentially managed

#### Step 4.3: Calculate Diff
- Generate line-by-line diff between source and target (within scope)
- Identify:
  - **Additions**: Lines added in source
  - **Deletions**: Lines removed in source
  - **Modifications**: Lines changed in source
  - **Unchanged**: Lines that match (preserve as-is)

#### Step 4.4: Apply Changes
- Apply only the changes (additions, deletions, modifications)
- **Never blindly replace** entire sections or files
- Preserve untracked content in target
- Maintain date markers and structural elements

#### Step 4.5: Safety Checks
- Show preview/diff of what will change before writing
- Detect conflicts (target modified since last sync)
- Warn if untracked sections would be affected

### 5. Show Diff Preview
- Display a unified diff showing:
  - Lines to be added (prefixed with `+`)
  - Lines to be removed (prefixed with `-`)
  - Context lines (unchanged)
- Ask user to confirm before writing
- Allow user to review and cancel if needed

### 6. Write Changes & Provide Feedback
- Apply the approved changes to target file
- Show summary of what was published:
  - Number of lines added/removed/modified
  - Which sections were affected (for section-scoped sync)
  - Target file path
- Indicate if any warnings or conflicts occurred

## Implementation Notes

### Diff Algorithm
- Use standard unified diff algorithm (similar to `git diff`)
- Calculate diffs at line-level granularity
- Support both addition, deletion, and modification detection

### Section Matching
- Use markdown header patterns (e.g., `## Section Name`, `### Section Name`)
- Support nested sections
- Match headers by text content (case-sensitive)

### Date Markers & Tracking
- Date markers define "managed regions" in target files
- Content between `*(Added: YYYY-MM-DD)*` and `*(End Added: YYYY-MM-DD)*` is tracked
- Untracked content in target is never modified
- Automatically update date markers if content changes

### Attachment Management
When `attachmentHandling.enabled: true` in syncStrategy:
- **Detect** image/diagram references in source markdown (e.g., `![](../../07_Diagrams/file.svg)`)
- **Copy** referenced files to wiki's `.attachments/` folder
- **Rewrite** links in target to use `/.attachments/filename` path
- **Preserve** original file in source location (don't modify source)
- **Skip** if file already exists in `.attachments/` (unless `forceUpdate: true`)
- **Supported formats**: .svg, .png, .jpg, .jpeg, .gif, .pdf

### Conflict Detection
- Track last sync timestamp (could use git-like approach with hash)
- Warn if target file has been modified since last sync
- Allow user to:
  - Proceed anyway (overwrite target changes)
  - Cancel and review manually
  - Show 3-way merge (original, source, target)

### Safety Features
- **Always preview**: Show diff before writing
- **Read target first**: Understand existing structure before modifying
- **Preserve untracked content**: Never touch content outside managed regions
- **Validation**: Verify all referenced sections exist before syncing

### Error Handling
- If source file not found, show error and list available mappings
- If target file not found for section-scoped sync, offer to create it or cancel
- If tracked section not found in source, warn user (section was deleted?)
- If tracked section not found in target, warn user (WIKI structure changed?)

## Examples

### Example 1: Auto-detect and preview changes
```bash
/publish-concept
```
Output:
```
Found mapping: driver-data-user-story
Source: 02_Explorations/.../user-story.md
Target: WIKI/.../Edit-Flow---Part-2---Feature-Outline.md

Calculating diff for tracked sections:
  - Business Constraints
  - Hardening Solution (Driver Terminal Constraint)
  - Implementation Status & Dependencies

Changes to apply:
  +12 lines added
  -3 lines removed
  ~5 lines modified

[Shows unified diff preview]

Proceed with publish? (y/n)
```

### Example 2: Publish by mapping ID
```bash
/publish-concept shipment-data-flow
```
Output:
```
Publishing full document diff...
Target file doesn't exist - this will create a new file.

+450 lines to be added

Proceed? (y/n)
```

### Example 3: Conflict detected
```bash
/publish-concept driver-data-user-story
```
Output:
```
⚠️  WARNING: Target file has been modified since last sync
   Last sync: 2026-02-26 14:30
   Target modified: 2026-02-26 15:45

Conflicting changes detected in:
  - Section "Implementation Status & Dependencies"

Options:
  1. Show 3-way diff
  2. Proceed anyway (overwrite target)
  3. Cancel and review manually

Choice:
```

## Error Messages

- `"No mapping found for current file. Available mappings: [list]"`
- `"Source file not found: [path]"`
- `"Target file not found: [path]. Create new file? (y/n)"`
- `"Tracked section '[section name]' not found in source file. Was it deleted?"`
- `"Tracked section '[section name]' not found in target file. WIKI structure may have changed."`
- `"Date markers not found in target section. Cannot determine managed region."`
- `"Conflict detected: Target has been modified since last sync. See options above."`
- `"Cannot calculate diff: Invalid markdown structure in source or target."`

## Future Enhancements

### Phase 2
- **Bi-directional sync**: Pull changes from WIKI back to local files
- **Sync history**: Track all syncs in `.claude/skills/wiki-connector/sync-history.json`
  - Store timestamps, file hashes, change summaries
  - Enable "undo last publish" functionality
- **3-way merge**: When conflicts detected, show original, source, and target versions
- **Automatic conflict resolution**: Smart merge for non-overlapping changes

### Phase 3
- **Multiple targets per source**: One local file can publish to multiple WIKI pages
- **Template variables**: Support placeholders like `{{DATE}}`, `{{VERSION}}` in content
- **Batch publish**: Publish multiple mappings at once
- **Dry-run mode**: Flag to preview all changes without writing
- **Git integration**: Auto-commit WIKI changes with descriptive messages

### Phase 4
- **Visual diff viewer**: Rich side-by-side comparison UI
- **Section mapping rules**: Define rules like "always sync intro, optionally sync examples"
- **Conditional publishing**: Publish only if certain conditions met (tests pass, etc.)
- **Change notifications**: Alert team members when WIKI pages are updated
