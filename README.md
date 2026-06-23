# Virtual Architect - New Dispo

Technical architecture documentation and exploration workspace for the New Dispo system.

## Repository Structure

See [CLAUDE.md](./CLAUDE.md) for complete tech stack details.

### Key Folders

- **Code/** — Source code repositories for all components (gitignored, cloned separately)
- **WIKI/** — Documentation wikis (gitignored, cloned separately)
- **00_Input/** — Raw input materials (external docs, transcripts for processing)
- **00_Meetings/** — Meeting notes and transcripts
- **00a_MeetingBriefs/** — AI-generated meeting briefings
- **01_Communication/** — Emails, messages, and external communication drafts
- **02_Explorations/** — Technical investigations and analyses
- **03_PRD/** — Product Requirement Documents and implementation plans (Open / Closed)
- **06_SQL/** — Standalone SQL scripts and queries
- **07_Diagrams/** — Architecture diagrams and visualizations (Mermaid, PlantUML)
- **08_Documentation/** — Published documentation
- **09_ADRs/** — Architecture Decision Records
- **20_Bug-Analysis/** — Bug investigation reports
- **999_Tools/** — Templates and tooling utilities
- **new-dispo-architecture/** — Legacy architecture notes and diagrams

## Getting Started

After cloning this root repo, the `Code/` and `WIKI/` folders will be empty (they are gitignored). You must clone the nested repositories into them manually.

See **[CLAUDE.md — Components & Repositories](./CLAUDE.md#components--repositories)** for the full list of repos, providers, users, and remote URLs.

### Clone Instructions

After cloning, set the local git identity for this repo (not stored in the repo, must be done per machine):

```bash
git config user.name "Matthias Max"
git config user.email "matthias.max@bitflower.net"
```

Then clone the nested repos from the repo root:

```bash
# GitHub — user: matthiasmax-p3
git clone https://github.com/cal-consult/tms-alloydb-schema.git Code/tms-alloydb-schema

# Azure DevOps — user: matthias.max@p3-group.com (PAT or SSH)
git clone https://p3ds@dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Abstraction-Layer Code/Disposition-Abstraction-Layer
git clone https://p3ds@dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Backend Code/Disposition-Backend
git clone https://p3ds@dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Frontend Code/Disposition-Frontend
git clone https://p3ds@dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Rollout-Tools Code/Disposition-Rollout-Tools
git clone https://p3ds@dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-UI-Automation Code/Disposition-UI-Automation
git clone https://p3ds@dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Nagel-GCP Code/Nagel-GCP
mkdir -p Code/Driver-Terminal
git clone https://p3ds@dev.azure.com/p3ds/P3-Self-Service-Terminal/_git/Self-Service-Terminal-Backend Code/Driver-Terminal/Self-Service-Terminal-Backend
git clone https://p3ds@dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Nagel-CAL-Disposition.wiki WIKI/Nagel-CAL-Disposition.wiki

# CALtms monorepo — user: x_matthias.max@nagel-group.com (PAT or SSH)
# Clone outside this repo, then symlink:
# git clone https://caldevops@dev.azure.com/caldevops/Agile/_git/CALtms /path/to/CALtms
# ln -s /path/to/CALtms/3GL/CALConsult.TOP Code/CALConsult.TOP
# ln -s /path/to/CALtms/3GL/CALConsult.TmsProxy Code/CALConsult.TmsProxy
# ln -s /path/to/CALtms/3GL/CALConsult.TmsProxyClient Code/CALConsult.TmsProxyClient
```

### Git Identity — Multiple GitHub / Azure Accounts

This workspace uses **two GitHub accounts** (`bitflower`, `matthiasmax-p3`) and **two Azure DevOps identities**. To avoid pushing with the wrong account, configure SSH host aliases and conditional git identity:

**1. SSH host aliases** (`~/.ssh/config`) — one alias per GitHub account:

```
# GitHub: bitflower (root repo)
Host github.com-bitflower
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_bitflower

# GitHub: matthiasmax-p3 (tms-alloydb-schema)
Host github.com-matthiasmax-p3
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_matthiasmax_p3
```

Then set the root repo remote to use the alias:

```bash
git remote set-url origin git@github.com-bitflower:bitflower/p3-virtual-architect-new-dispo.git
```

And in `Code/tms-alloydb-schema`:

```bash
git remote set-url origin git@github.com-matthiasmax-p3:cal-consult/tms-alloydb-schema.git
```

**2. Conditional git identity** (`~/.gitconfig`) — set `user.name`/`user.email` per directory:

```gitconfig
[includeIf "gitdir:/path/to/Virtual Architect - New Dispo/"]
  path = ~/.gitconfig-bitflower

[includeIf "gitdir:/path/to/Virtual Architect - New Dispo/Code/tms-alloydb-schema/"]
  path = ~/.gitconfig-matthiasmax-p3
```

Where `~/.gitconfig-bitflower` contains:

```gitconfig
[user]
  name = Matthias Max
  email = <bitflower-email>
```

And `~/.gitconfig-matthiasmax-p3` contains:

```gitconfig
[user]
  name = Matthias Max
  email = <matthiasmax-p3-email>
```

**3. Azure DevOps** — currently using HTTPS with PAT. Preferred future setup: SSH keys per identity, similar to the GitHub approach above.

## Requirements

- Azure MCP needs Node version 20+

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

