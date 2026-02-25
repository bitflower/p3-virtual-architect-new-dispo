---
name: explore
description: Start a new exploration with proper folder structure and template. Use when the user wants to begin analyzing a user story, investigating a technical issue, or exploring a new topic that should be documented.
allowed-tools: Bash,Write,Read,Edit
---

# Explore Skill

This skill creates a new exploration folder with a structured markdown template for documenting investigations, analyses, and research.

## When to Use

- User asks to "explore" or "investigate" a topic
- User wants to start analyzing a user story
- User needs to document a technical investigation
- User mentions creating a new exploration document

## How It Works

Execute the skill.sh script in this directory, passing the topic as arguments:

```bash
cd .claude/skills/explore && ./skill.sh $ARGUMENTS
```

## What Gets Created

Creates a dated folder in `02_Explorations/` with this structure:

```
02_Explorations/YYYY-MM-DD_Topic_Description/
└── topic-description.md
```

The markdown file includes:
- Topic as title
- Current date
- Original User Input section (to be filled with context)
- Template sections for structured documentation

## After Creation

After running the skill, remind the user to:
1. Open the created file
2. Replace the "Original User Input" section with their actual context
3. Fill in relevant template sections as they explore

## Usage Examples

```
/explore User Story 103821: OMS Sendung Quell_K analysis
/explore Database performance issue in SetDriver
/explore SignalR implementation considerations
```
