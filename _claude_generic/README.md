# `_claude_generic` — portable skills + agents bundle

Repo-agnostic versions of two skills and the two code-review agents they depend on,
extracted from this project and decoupled from its stack and conventions. The layout mirrors
`.claude/` so installing into another project is a straight copy.

```
_claude_generic/
├── README.md                                  ← this file (config knobs + handoff contract)
├── skills/
│   ├── validated-prd/SKILL.md                 ← idea → PRD
│   └── implement-feature-plan/SKILL.md        ← PRD → verified plan → shipped code
└── agents/
    ├── senior-code-reviewer.md                ← architectural / security review lens
    └── senior-clean-code-reviewer.md          ← clean-code / module-cohesion review lens
```

## Install into another project

```bash
cp -R _claude_generic/skills/*  <project>/.claude/skills/
cp -R _claude_generic/agents/*  <project>/.claude/agents/
```

Then open each `SKILL.md` and fill the `## Config` table (or leave knobs unset to use the
listed defaults / inference). If a knob's source doesn't exist in your repo (e.g. no
"comparisons" corpus), leave it unset — the skills degrade gracefully and flag the gap rather
than failing.

## The two skills form a pipeline

```
idea → [validated-prd]               → PRD  (a markdown file: WHAT + WHY, unverified HOW)
     → [implement-feature-plan Ph0–1] → PLAN (verified, buildable: schema, file ownership, gates)
     → [implement-feature-plan Ph2–5] → shipped, reviewed, smoke-tested code
```

`validated-prd` produces a **PRD**, not a buildable spec. The buildable spec
(`{{PLAN_FILENAME}}`) is produced by `implement-feature-plan` Phase 1. The PRD's
"Implementation Approach" / "Files Likely to Change" are deliberately *unverified hints* —
`implement-feature-plan` Phase 0 re-verifies them against the actual repo ("PRDs lie").

## The two agents

`implement-feature-plan` runs a **two-lens review gate** — architectural and clean-code, in
parallel — because neither lens reliably catches the other's issues. The skill resolves the
reviewers via its `REVIEWER_ARCHITECTURAL` / `REVIEWER_CLEANCODE` config knobs:

| Skill knob | Resolves to (this bundle) | If you don't install the agents |
|---|---|---|
| `REVIEWER_ARCHITECTURAL` | `agents/senior-code-reviewer.md` | built-in `/code-review` (high effort), else `general-purpose` + the skill's inlined architectural checklist |
| `REVIEWER_CLEANCODE` | `agents/senior-clean-code-reviewer.md` | `general-purpose` + the skill's inlined clean-code checklist |

So the bundle works **with or without** the agents — installing them upgrades the fallback to
the real named two-lens experience. Both agents emit findings as **Critical / High / Medium /
Low**, which is the exact tier set the skill triages on (Critical/High block the next step).

- **`senior-code-reviewer`** — ~95% portable as written. Explicitly stack-*adaptive* (it
  infers the language/framework from the files). No repo paths. The only opinionated bit is an
  optional `claude_docs/` doc-generation behavior you can ignore.
- **`senior-clean-code-reviewer`** — universal Clean Code core (verbatim) + a `## Project
  policy` block at the bottom. The policy block carries portable defaults (file-size limits
  ~200/300, one-concern-per-file, module cohesion, an optional frontend design-system
  subsection). **Whatever the project's conventions file specifies overrides those defaults**,
  so the agent adapts per repo instead of carrying this project's numbers.

## The PRD ⇄ Plan handoff contract (the thing that makes them compose)

Both skills reference this contract so the handoff is explicit, not accidental.

**`validated-prd` emits** a PRD file at `{{OUTPUT_PATH_TEMPLATE}}` with these sections:

| # | Section | Role in the handoff |
|---|---|---|
| 1 | Problem | Why; failure modes to avoid |
| 2 | Direction Alignment | Quotes from direction sources with refs |
| 3 | Requirements (MoSCoW + Won't) | **The scope boundary.** Must/Should = in V1; Could/Won't = out |
| 4 | Out of Scope (explicit) | Things a reader expects but won't find |
| 5a | Security (threat table T1–Tn) | Present only when the surface warrants it |
| 5 | Implementation Approach | **Unverified hint** — module layout, mount points |
| 6 | Files Likely to Change | **Unverified hint** — to be re-verified by the plan |
| 7 | Verification | Concrete acceptance steps |
| 8 | Related | Source paths + prereq/downstream features |

**`implement-feature-plan` consumes** that file path and MUST honor these mappings:

| PRD section | Becomes / drives in the plan |
|---|---|
| Requirements (MoSCoW) | Scope boundary; anything not Must/Should is Out of Scope for V1 |
| Verification | The plan's **Acceptance checklist** — derive it, don't reinvent it |
| Security threat table | Folded into the plan's **Risks & mitigations** table |
| Files Likely to Change | **Starting point to re-verify** against the repo (never trusted as-is) |
| Implementation Approach | **Hint to validate** in Phase 0; the repo wins on every conflict |
| Feature id / folder | The plan co-locates `{{PLAN_FILENAME}}` next to the PRD |

Running `implement-feature-plan` on any PRD/README (not just one from `validated-prd`) is
fine — missing sections are treated as "not provided" and derived by the skill.

## Config knob reference

### `validated-prd`

| Knob | Points at | This-repo example | Default if unset |
|---|---|---|---|
| `PRIOR_ART_SOURCES` | Pattern-mining / competitor / comparison docs | `_features/comparisons/*/PRD.md` | skip layer, flag gap in audit |
| `DIRECTION_SOURCES` | Vision / roadmap / strategy docs | `_features/vision_steering/artifacts/*.md` + `sources/*.md` | skip layer, flag gap |
| `EXISTING_WORK_SOURCES` | In-flight / planned features (collision + numbering) | `_features/{open,inbox}/*/README.md` | skip collision check, flag |
| `CONVENTIONS_FILE` | Binding conventions doc(s) | `CLAUDE.md` (root + nested) | none |
| `FEATURE_ID_SCHEME` | How features are identified | `NNN_<slug>`, id = max(existing)+1 | `<slug>` only |
| `OUTPUT_PATH_TEMPLATE` | Where the PRD is written | `_features/{open\|inbox}/<id>/README.md` | `docs/prd/<id>.md` |
| `REFERENCE_PRD_SURFACE` | Example PRD to mirror (backend/API) | `_features/open/068_mcp_server/README.md` | none |
| `REFERENCE_PRD_UI` | Example PRD to mirror (UI) | `_features/open/051_grounded_relationship_generation/README.md` | none |
| `SEARCH_AGENT` | Read-only search agent for deep reads | `Explore` | `general-purpose`, or read inline |

### `implement-feature-plan`

| Knob | What it is | This-repo example | Default if unset |
|---|---|---|---|
| `REVIEWER_ARCHITECTURAL` | Agent for architecture/security review | `senior-code-reviewer` | built-in `/code-review` (high effort); else `general-purpose` + inlined checklist |
| `REVIEWER_CLEANCODE` | Agent for clean-code/cohesion review | `senior-clean-code-reviewer` | `general-purpose` + the skill's inlined clean-code checklist |
| `TEST_CMD` | Full test-suite command | `./run_tests.sh -t all` | infer (package.json / Makefile / pytest); ask if ambiguous |
| `START_CMD` | How to start the stack for smoke test | per project `readme.md` | infer; ask if ambiguous |
| `BRANCH_SCHEME` | Feature branch naming | `feature/<NNN>-<slug>` | `feature/<slug>` |
| `PLAN_FILENAME` | Implementation-plan filename | `IMPLEMENTATION_PLAN.md` | `IMPLEMENTATION_PLAN.md` |
| `CONVENTIONS_FILE` | Binding conventions doc(s) | `CLAUDE.md` | none |
| `STACK_NOTES` | Project idioms for contracts/components/db | Pydantic / one-React-component-per-file / SQL FK `ON DELETE RESTRICT` | infer from repo |

## Provenance — what was generic vs. repo-specific

- **Kept verbatim (portable):** all skill phase structure + the skeptical-pushback persona,
  stop-and-wait gates, triangulation, 3-depth × 3-lens review gate, premise critique, MoSCoW
  + explicit Won't, security-when-warranted, surface-vs-UI branching, flagship self-check,
  two-lens code review + Critical/High/Medium/Low triage, disjoint file-ownership
  parallelism, no-worktrees-default; and the entire universal Clean Code core of the
  clean-code agent + the stack-adaptive body of the architectural agent.
- **Hoisted into Config knobs / Project policy:** the `_features/` directory taxonomy, the
  reviewer agent names, test/start commands, branch & feature-id schemes, reference-PRD
  paths, stack idioms (Pydantic/React/SQL), and the clean-code agent's file-size limits +
  language idioms + CSS/design-system rules.
- **Left behind (not portable):** the stack-expert agents (`cypher-query-optimizer`,
  `neo4j-*`, `path-rag-expert`) — they're Neo4j/PathRAG domain consultants, hollow off this
  stack — and `prompt-context-engineer` (RAG-flavored; not part of the skills' path).

## Not yet validated

These generic versions were authored but **not test-run in a fresh repo**. First real use
elsewhere will shake out whether the `TEST_CMD`/`START_CMD` inference and the clean-code
agent's "defer to conventions file" handoff are concrete enough, or need tightening.
