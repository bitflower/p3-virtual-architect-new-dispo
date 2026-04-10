---
name: publish-concept
description: Publish local exploration/documentation files to WIKI documentation using configured mappings. Use when the user wants to sync, publish, or push local documents to the wiki.
allowed-tools: Bash,Read,Write,Edit,Glob,Grep
---

# Publish Concept Skill

This skill publishes local concept/exploration files to WIKI documentation using diff-based synchronization.

## When to Use

- User asks to "publish to wiki" or "sync to wiki"
- User asks to "update the wiki" for a specific document
- User mentions `/publish-concept` with or without a mapping ID

## How It Works

1. **Load Mappings** from `.claude/skills/wiki-connector/publish-mappings.json`
2. **Identify Target**: If a mapping-id argument is provided, use that mapping. Otherwise list all available mappings and ask user to select.
3. **Read Source and Target Files**
4. **Strip Internal Sections**: Remove everything between `<!-- internal -->` and `<!-- /internal -->` markers from source content before publishing
5. **Rewrite Links**: If `linkRewriting.enabled`, rewrite relative paths to wiki paths and optionally remove internal-only links
6. **Handle Attachments**: If `attachmentHandling.enabled`, copy referenced images to wiki `.attachments/` folder and rewrite image paths
7. **Calculate Diff**: Compare processed source with existing target
8. **Show Preview**: Display unified diff of changes
9. **Write Changes**: After user confirmation, write to target

## Implementation

Follow the detailed specification in `.claude/skills/wiki-connector/publish-concept.md` for:
- Diff calculation algorithm
- Section-scoped vs full-document sync
- Date marker handling
- Conflict detection
- Attachment management
- Error handling

## Usage Examples

```
/publish-concept                              # Auto-detect or list mappings
/publish-concept driver-data-user-story       # Publish specific mapping
/publish-concept flow-createtransportorderfromleg  # Publish single flow
```

## Batch Publishing

When multiple mappings share a common prefix (e.g., all `flow-*` or all `infrastructure-*`), you can publish them all at once:

```
/publish-concept flow-*                       # All flow mappings
/publish-concept infrastructure-*             # All infrastructure mappings
```

Process each mapping using the same strip-internal + link-rewrite + diff pipeline.
