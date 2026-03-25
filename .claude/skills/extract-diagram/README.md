# Extract Diagram Skill

Extract Mermaid diagrams from markdown documentation and create versioned SVG diagrams in `07_Diagrams/Architecture/`.

## Quick Start

```bash
# Extract diagram with auto-generated name
extract-diagram 02_Explorations/2026-03-24_My-Analysis/flow-diagram.md

# Extract with custom name and title
extract-diagram -n my-flow -t "My Custom Flow" path/to/file.md
```

## What It Does

1. **Extracts** the first Mermaid diagram from a source markdown file
2. **Creates** a new markdown file in `07_Diagrams/Architecture/` containing:
   - Diagram title and metadata (date, version, status)
   - The Mermaid source code
   - Link back to original documentation
3. **Generates** an SVG from the Mermaid diagram using `mmdc` (mermaid-cli)
4. **Updates** the original file to replace the Mermaid code block with an SVG reference

## Prerequisites

- **Mermaid CLI** must be installed:
  ```bash
  npm install -g @mermaid-js/mermaid-cli
  ```
- **Node.js** >= 18.19 (or >= 20.0 recommended)
- Source file must contain at least one Mermaid code block (` ```mermaid ... ``` `)

## Output

For a diagram named `my-diagram`, the skill creates:

```
07_Diagrams/Architecture/
├── my-diagram.md   ← Source markdown with Mermaid diagram
└── my-diagram.svg  ← Generated SVG (committed to git)
```

And updates the source file:
- Replaces ```` ```mermaid ... ``` ```` with `![Diagram](path/to/diagram.svg)`
- Adds source link: `**Source:** [path/to/diagram.md](...)`
- Creates `.bak` backup of original file

## Usage

### Basic Extraction

```bash
extract-diagram 02_Explorations/2026-03-24_My-Analysis/architecture.md
```

Auto-generates name from path: `my-analysis-architecture`

### Custom Name

```bash
extract-diagram -n auth-flow 02_Explorations/Auth/flow.md
```

Creates: `07_Diagrams/Architecture/auth-flow.md` and `auth-flow.svg`

### Custom Name and Title

```bash
extract-diagram \
  -n shipment-flow \
  -t "Shipment Processing Architecture" \
  08_Documentation/shipments.md
```

## Arguments

- **Required:**
  - `<source-markdown-file>` - Path to markdown file (absolute or relative to project root)

- **Optional:**
  - `-n, --name NAME` - Custom diagram name (default: auto-generated from path)
  - `-t, --title TITLE` - Custom diagram title (default: extracted from first `# ` heading)
  - `-h, --help` - Show help message

## Auto-Generated Names

When name is not specified, it's generated from the source file path:

| Source Path | Generated Name |
|-------------|----------------|
| `02_Explorations/2026-03-24_My-Flow/flow.md` | `my-flow-flow` |
| `08_Documentation/auth/architecture.md` | `auth-architecture` |
| `02_Explorations/CDC-Pipeline/overview.md` | `cdc-pipeline-overview` |

Rules:
- Date prefixes (`YYYY-MM-DD_`) are removed
- Underscores become hyphens
- Converted to lowercase
- Multiple hyphens collapsed to single

## Updating Diagrams

After extraction, to update a diagram:

1. **Edit the source:**
   ```bash
   # Edit 07_Diagrams/Architecture/my-diagram.md
   vim 07_Diagrams/Architecture/my-diagram.md
   ```

2. **Regenerate SVG:**
   ```bash
   cd 07_Diagrams/Architecture
   mmdc -i my-diagram.md -o my-diagram.svg -b transparent
   ```

3. **Commit both files:**
   ```bash
   git add my-diagram.md my-diagram.svg
   git commit -m "Update my-diagram"
   ```

## Benefits

✅ **Single source of truth** - One canonical diagram source
✅ **Versioned assets** - SVG committed to git
✅ **Universal rendering** - SVG works in all viewers/browsers
✅ **Easy updates** - Edit markdown, regenerate SVG
✅ **Good diffs** - Text-based source gives readable git diffs
✅ **DRY principle** - Reference diagram from multiple places

## Example Workflow

```bash
# 1. Write documentation with inline Mermaid diagram
vim 02_Explorations/2026-03-25_Auth/flow.md

# 2. Extract diagram to versioned asset
extract-diagram 02_Explorations/2026-03-25_Auth/flow.md

# 3. Files created:
#    - 07_Diagrams/Architecture/auth-flow.md
#    - 07_Diagrams/Architecture/auth-flow.svg
#    - Original file updated with SVG reference

# 4. Commit all changes
git add 02_Explorations/ 07_Diagrams/
git commit -m "Add auth flow diagram"

# 5. Later, update the diagram
vim 07_Diagrams/Architecture/auth-flow.md
cd 07_Diagrams/Architecture
mmdc -i auth-flow.md -o auth-flow.svg -b transparent
git add auth-flow.md auth-flow.svg
git commit -m "Update auth flow diagram"
```

## See Also

- [Parent README](../README.md) - All project skills
- [Project README](../../../README.md) - Diagram generation requirements
- [07_Diagrams/Architecture/](../../../07_Diagrams/Architecture/) - Existing diagrams
