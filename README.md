# Virtual Architect - New Dispo

Technical architecture documentation and exploration workspace for the New Dispo system.

## Repository Structure

See [CLAUDE.md](./CLAUDE.md) for complete tech stack details.

### Key Folders

- **Code/** - Source code repositories for all components
- **WIKI/** - Documentation wikis
- **00_Meetings/** - Meeting notes and transcripts
- **02_Explorations/** - Technical investigations and analyses
- **07_Diagrams/** - Architecture diagrams and visualizations
- **08_Documentation/** - Published documentation

## Requirements

### Diagram Generation

This repository uses **Mermaid CLI** to generate versioned SVG diagrams from Mermaid markdown files.

**Install Mermaid CLI:**

```bash
npm install -g @mermaid-js/mermaid-cli
```

**Node.js requirement:** Node.js >= 18.19 (or >= 20.0 recommended)

**Generate SVG from Mermaid diagram:**

```bash
# From the diagram directory
mmdc -i diagram-name.md -o diagram-name.svg -b transparent

# Or with full path
mmdc -i /path/to/diagram.md -o /path/to/diagram.svg -b transparent
```

### Diagram Workflow

1. Create/edit Mermaid diagram in markdown file (e.g., `07_Diagrams/Architecture/my-diagram.md`)
2. Generate versioned SVG: `mmdc -i my-diagram.md -o my-diagram.svg -b transparent`
3. Include SVG in documentation: `![Diagram](07_Diagrams/Architecture/my-diagram.svg)`
4. Commit both the source `.md` and generated `.svg` files

**Benefits of this approach:**
- ✅ Text-based diagrams in version control
- ✅ Renders universally (SVG works everywhere)
- ✅ Single source of truth (regenerate SVG from source)
- ✅ Works with GitHub, markdown viewers, documentation sites

## Architecture

See [CLAUDE.md](./CLAUDE.md) for the complete component list and folder structure.

### Component Overview

| Component | Location | Technology |
|-----------|----------|------------|
| TMS Database | Code/tms-alloydb-schema | AlloyDB (PostgreSQL) |
| TMS Bridge | Code/Disposition-Abstraction-Layer | .NET / Cloud Run |
| Backend | Code/Disposition-Backend | .NET / Cloud Run |
| Frontend | Code/Disposition-Frontend | Angular |
| Cloud Functions | Code/Nagel-GCP/CALConsult.Disposition.Functions | .NET / Cloud Functions |
| Cloud4Log | Code/Nagel-GCP/Cloud4Log | .NET / Cloud Functions |
