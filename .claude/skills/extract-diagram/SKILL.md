---
name: extract-diagram
description: Extract Mermaid diagrams from markdown to versioned SVG diagrams in 07_Diagrams/Architecture/
---

# Extract Diagram Skill

Extracts Mermaid diagrams from markdown files and creates versioned diagram assets.

## What it does

1. **Extracts** the first Mermaid diagram from a source markdown file
2. **Creates** a new markdown file in `07_Diagrams/Architecture/` with:
   - Diagram title and metadata
   - The Mermaid source code
   - Link back to original documentation
3. **Generates** an SVG from the Mermaid diagram using `mmdc`
4. **Updates** the original file to reference the SVG instead of inline Mermaid

## Usage

```bash
extract-diagram <source-markdown-file>
extract-diagram -n custom-name -t "Custom Title" <source-file>
```

## Examples

```bash
# Auto-generate name from file path
extract-diagram 02_Explorations/2026-03-16_My-Analysis/flow-diagram.md

# Custom name and title
extract-diagram -n auth-flow -t "Authentication Flow" path/to/auth-docs.md
```

## Arguments

- `<source-markdown-file>` - Path to markdown file containing Mermaid diagram (required)
- `-n, --name NAME` - Custom diagram name (optional, auto-generated if not provided)
- `-t, --title TITLE` - Custom diagram title (optional, extracted from source if not provided)
- `-h, --help` - Show help message

## Requirements

- Source file must contain at least one Mermaid code block (` ```mermaid `)
- Mermaid CLI must be installed: `npm install -g @mermaid-js/mermaid-cli`

## Output

Creates two files in `07_Diagrams/Architecture/`:
- `{diagram-name}.md` - Source markdown with Mermaid diagram
- `{diagram-name}.svg` - Generated SVG diagram

Updates the source file:
- Replaces Mermaid code block with SVG reference
- Adds link to diagram source
- Creates `.bak` backup of original file

## Benefits

✅ Single source of truth for diagrams
✅ Versioned SVG assets (committed to git)
✅ Universal rendering (SVG works everywhere)
✅ Easy to update (edit .md, regenerate SVG)
✅ Text-based source (good git diffs)

## Updating Diagrams

After creating a diagram, to update it:

1. Edit the diagram source: `07_Diagrams/Architecture/{diagram-name}.md`
2. Regenerate SVG:
   ```bash
   cd "07_Diagrams/Architecture"
   mmdc -i {diagram-name}.md -o {diagram-name}.svg -b transparent
   ```
3. Commit both files

## See Also

- [README.md](../../README.md) - Diagram generation requirements
- [07_Diagrams/Architecture/](../../07_Diagrams/Architecture/) - Existing diagrams
