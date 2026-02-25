# Explore Skill

Creates a new exploration with proper folder structure and markdown template.

## Files

- **skill.sh** - Main executable script
- **template.md** - Markdown template with placeholders
- **README.md** - This file

## Usage

```bash
/explore <topic description>
```

## Example

```bash
/explore User Story 103821: OMS Sendung Quell_K analysis
```

Creates:
```
02_Explorations/2026-02-25_User_Story_103821_OMS_Sendung_Quell_K_analysis/
└── user-story-103821-oms-sendung-quell-k-analysis.md
```

## Template Placeholders

The `template.md` file uses these placeholders:

- `{{TITLE}}` - Replaced with the topic description
- `{{DATE}}` - Replaced with current date (YYYY-MM-DD)

## Customization

To customize the exploration template:

1. Edit `template.md`
2. Add or remove sections as needed
3. Use `{{TITLE}}` and `{{DATE}}` placeholders where needed

The skill will automatically replace these placeholders when creating new explorations.

## Structure Created

```
02_Explorations/
└── YYYY-MM-DD_Topic_Description/
    └── topic-description.md
```

Where:
- Folder name: `Date + sanitized topic` (max 80 chars for topic)
- File name: `lowercase-with-hyphens.md`
