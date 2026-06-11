---
name: validated-prd
description: Produce a validated feature PRD by triangulating signal from your project's prior-art, direction, and existing-work sources, then validating the draft through interactive sign-off gates with the user. Use when the user asks to write a PRD, scope a new feature, or convert a half-formed idea into a proper spec. Walks 6 phases with explicit user gates. Supports both surface-level features (server, SDK, auth, transport, API) and UI-level features (button, flow, modal, component).
argument-hint: <feature-idea | feature-name>
---

# Validated Feature PRD — Triangulated & Gated (portable)

Turn a half-formed feature idea into a PRD that is (a) aligned with the product direction,
(b) informed by prior-art / pattern-mining already done in the repo, (c) free of collision
with existing in-flight features, (d) brutally scoped by the user through interactive gates,
and (e) enterprise-grade on security when the surface calls for it.

The **user's interactive confirmation is the "validated" in the name.** Skipping gates
defeats the skill.

> **Output of this skill is the input to `implement-feature-plan`.** See `## Handoff
> contract` below. This skill produces a **PRD** (WHAT + WHY + an *unverified* sketch of
> HOW), not a buildable implementation plan.

---

## Config — set per project (or accept the defaults)

Fill these for your repo. Leave a knob unset to use its default; if a source layer doesn't
exist, the skill degrades gracefully and flags the gap in the audit rather than failing.

| Knob | Points at | Value |
|---|---|---|
| `PRIOR_ART_SOURCES` | Glob(s) for pattern-mining / competitor / comparison docs | `02_Explorations/**/*.md`, `09_ADRs/**/*.md` |
| `DIRECTION_SOURCES` | Vision / roadmap / strategy docs | not configured — skip layer, flag gap in audit |
| `EXISTING_WORK_SOURCES` | In-flight / planned features (collision + numbering) | `03_PRD/` (scan for existing PRD folders to avoid id collision) |
| `CONVENTIONS_FILE` | Binding conventions doc(s) | `CLAUDE.md` (root) |
| `FEATURE_ID_SCHEME` | How features are identified | `NNN_<Slug>` — zero-padded 3-digit id, underscore, Title_Case slug (e.g. `001_TMS_Bridge_Credential_Selection`). Next id = max existing + 1. |
| `OUTPUT_PATH_TEMPLATE` | Where the PRD file is written | `03_PRD/<id>/PRD.md` (e.g. `03_PRD/002_Feature_Name/PRD.md`) |
| `REFERENCE_PRD_SURFACE` | Example PRD to mirror for backend/API features | `03_PRD/001_TMS_Bridge_Credential_Selection/` |
| `REFERENCE_PRD_UI` | Example PRD to mirror for UI features | none yet — use surface reference adapted for UI |
| `SEARCH_AGENT` | Read-only search agent for deep reads | `Explore` agent type |

Throughout this skill, `{{KNOB}}` means "use the configured value, else the default."

---

## Input forms

Accept any of:
- A feature idea in plain text (e.g. "server for X", "bulk delete button")
- A feature name the user has already chosen
- A reference to an existing TODO note or bug folder

If nothing concrete is given, ask: *"What feature do you want to PRD? One sentence is enough."*

---

## Do-nots (read first)

- **Don't skip the Phase 0 review gate.** The user spot-checking your signal extraction is
  the load-bearing validation step. Without it your synthesis can drift without catching.
- **Don't write any file before Phase 5** (post-audit). Drafting in-chat lets the user
  revise cheaply.
- **Don't auto-resolve contradictions between sources.** Surface them as forks and force the
  user to pick a lane. The most common fork: a direction source frames a feature as bigger
  than a prior-art doc recommends — these are two different products, not refinements of one.
- **Don't skip `{{PRIOR_ART_SOURCES}}` — that's where pattern-mining already happened.**
  Grep-rank by feature-keyword hit count; delegate deep reads to `{{SEARCH_AGENT}}` for ≥5
  relevant docs.
- **Don't include shipped/closed features** in triangulation unless the user asks. Shipped
  features are not typically informative for scoping a new one.
- **Don't wave hands on enterprise security.** When the user says "enterprise-grade,"
  enumerate a T1–Tn threat table with MVP vs. V2 mitigation split. If the user descopes a
  security control, push back if it breaks the "enterprise-grade" label.
- **Don't generalize the skill's branch logic into mush.** Surface-level features (server,
  SDK, auth, transport) and UI-level features (button, modal, flow) follow different PRD
  shapes — respect the divergence; see §Phase 3 branching.
- **Don't commit.** Phase 5 writes the PRD file; git commits are the user's call.
- **Don't re-query the model when you can grep.** Source triangulation is file-reading, not
  LLM work.

---

## Phase 0 — Triangulate signal

Goal: build a defensible evidence base before a single PRD word is written.

### 0.1 Enumerate sources

Four layers, in priority order:

| Source | Purpose | How to read |
|---|---|---|
| `{{PRIOR_ART_SOURCES}}` | Patterns to steal, failure modes to avoid, moat items to defend | Grep-rank by feature keywords; deep-read top 3–5 |
| `{{DIRECTION_SOURCES}}` | Product direction, what's explicitly deferred / out of scope at the strategy level | Read short docs fully; grep long ones for feature keywords |
| `{{EXISTING_WORK_SOURCES}}` | Collision / adjacency / id allocation | Grep for feature keywords; note any existing feature that overlaps |
| `{{CONVENTIONS_FILE}}` | Binding conventions (naming, module layout, review-agent rules) | Always read in full before writing the draft |

Skip shipped/closed features unless the user specifies otherwise. If a layer's knob is
unset, note "layer not configured" and continue.

### 0.2 Rank prior art by relevance

```bash
# Adapt the glob to {{PRIOR_ART_SOURCES}}
for f in <PRIOR_ART_SOURCES_GLOB>; do
  [ -f "$f" ] || continue
  count=$(grep -c -i -E "<feature-keywords>" "$f" 2>/dev/null)
  [ "$count" != "0" ] && echo "$count  $f"
done | sort -rn | head -20
```

Keep docs with ≥5 hits. Skim 1–4 hits for false-positive patterns. Skip 0 hits.

For ≥5 docs to deep-read, **delegate to `{{SEARCH_AGENT}}`** with a bounded prompt:
- *"For each doc, report (1) what the target project does with `<feature-concept>`, (2) the
  explicit recommendation in the doc's Actionable Patterns / High Impact / Moat tables
  (quote verbatim), (3) failure modes called out, (4) relevance verdict
  HIGH/MEDIUM/LOW/FALSE-POSITIVE. Plus a cross-cutting patterns section for themes repeating
  across ≥3 docs."*

### 0.3 Synthesize

Produce (for the user, not the file):
1. **Cross-cutting consensus table** — patterns endorsed by ≥3 sources
2. **Critical contradictions** — places where a direction source and a high-relevance prior-art doc disagree on scope/framing
3. **Failure modes to avoid** — pulled from prior-art "what went wrong" sections
4. **Collision check** — any existing in-flight feature overlapping with the proposed one
5. **Next feature id** — per `{{FEATURE_ID_SCHEME}}`

### 0.4 Review gate — mandatory

Offer the user **three depth options**:

- **Option 1 — Verbal spot-check (~5 min):** show 1–2 verbatim quotes per HIGH-relevance
  source + your 1-sentence read; user flags each as *agreed / misread / missed-something*. Default.
- **Option 2 — Open-and-read together (~20 min):** walk each HIGH source; user reads along and
  calls out misreads / under-weighted nuance.
- **Option 3 — Challenge-driven:** user probes only the suspicious claims; you re-verify on demand.

**Offer three lenses** for whichever depth they pick:
- **Source coverage** — did you consult the right set?
- **Extraction accuracy** — did you read each source correctly?
- **Synthesis correctness** — do the cross-cutting patterns and contradictions hold up?

User's descope flags during this review **collapse the Phase 2 question space.** A
HIGH-relevance source recommending pattern X can be scoped out of MVP in one line by the user
during review — record that descope explicitly in the lock table.

Stop. Wait for review flags before Phase 1.

---

## Phase 1 — Brutal premise critique

Goal: force strategic forks into daylight before anyone writes requirements.

Produce a short critique covering at minimum three pushbacks:

1. **Consumer named?** Does the feature have a real, named consumer? "External agents,"
   "future customers," "the team" are not consumers. If the consumer isn't a person, a role,
   or a deployment scenario, you cannot design for them. If there's no consumer, the answer
   may be "don't build it."
2. **Is this actually one product or a bundle?** Servers are tools + hooks + installer. SDKs
   are lib + docs + examples. Auth systems are provider + middleware + UI. Bundles hide
   scope. Unpack the bundle; V1 should ship exactly one coherent layer.
3. **Hidden prerequisites.** Features often rest on infrastructure that doesn't exist yet
   (multi-tenancy, auth, a migration, a service boundary). Name prerequisites explicitly.
   Either pull them onto the critical path or declare the MVP's limitation openly.

The explicit goal: surface contradictions between sources so the user has to pick a lane. The
most common fork: a direction source frames the feature as bidirectional/larger; a prior-art
doc recommends a read-only/smaller MVP. These are two different products. **The user picks;
you do not.**

---

## Phase 2 — Numbered gating questions

5–10 numbered decisions the user must answer (or accept defaults on). Typical shape for a
**surface-level** feature:

1. Consumer (internal dev / paying customer / external / community)
2. Lane (read-only vs. bidirectional / minimal vs. complete)
3. V1 surface (tools only / tools+hooks / full bundle)
4. Transport (stdio / HTTP / both)
5. Auth (none / API key / OAuth)
6. Catalog boundary (curated / raw / both)
7. State visibility (committed only / also pending)
8. Hooks (none / lifecycle subset / full lifecycle)
9. Output location (per `{{OUTPUT_PATH_TEMPLATE}}` — which bucket if it has buckets)

For **UI-level** features, substitute: interaction trigger, modal vs. inline, feedback
timing, error recovery, keyboard support, etc.

Always offer a **default** with rationale so silence is a valid answer. The user's descope
flags from Phase 0 collapse this list — record each already-answered question explicitly in a
lock table.

Stop. Wait for locks.

---

## Phase 3 — Draft PRD in chat (no file writes)

Required sections — the **hard checklist** (this is the emitting half of the handoff
contract; keep section names stable so `implement-feature-plan` can map them):

| # | Section | Notes |
|---|---|---|
| 1 | Problem | Concrete consequences, evidence from prior art, failure modes to avoid |
| 2 | Direction Alignment | Quote direction sources with file:line refs; call out conscious scope reductions |
| 3 | Requirements (MoSCoW + Won't Have) | Must / Should / Could / Won't — every Won't is an explicit decision, not a shrug |
| 4 | Out of Scope (explicit) | Separate from Won't; things a reader might expect but won't find |
| 5 | Implementation Approach | Module layout, file paths following `{{CONVENTIONS_FILE}}`, mount points — **unverified hint** |
| 6 | Files Likely to Change | Table: file → change, new vs. modified — **unverified hint** |
| 7 | Verification | Concrete acceptance steps — deployment + functional + load |
| 8 | Related | Prior-art with file paths, direction with line refs, downstream/prereq features |

**Add a Security section** (first-class, section #5a between Out of Scope and Implementation
Approach) **when the feature surface is:**
- Exposed over the network
- Handles authentication, secrets, or credentials
- Processes untrusted input (including LLM output against structured systems)
- Operates on multi-tenant data
- The user said "enterprise-grade"

Security section template: threat table T1–Tn with MVP mitigation column + V2 upgrade column.

### Branching — surface-level vs. UI-level features

| Aspect | Surface (server, SDK, auth, API) | UI (button, modal, flow) |
|---|---|---|
| Reference PRD | `{{REFERENCE_PRD_SURFACE}}` | `{{REFERENCE_PRD_UI}}` |
| Security section? | Often yes | Rarely (auth/credentials flows are the exception) |
| Transport / auth questions | Yes | No |
| Interaction trigger / component questions | No | Yes |
| Verification focus | Deployment + load + security | Visual + interaction + accessibility |
| Primary failure mode | Raw primitives / missing curation / auth gap | Hallucinated content / ungrounded suggestion / UX confusion |

### Critical self-check before finishing draft

**Walk the primary flow(s) the feature intersects** and confirm every flow has a mapped
tool / endpoint / interaction in the PRD. Omission here is the most common "I forgot the
flagship" bug — e.g., a server PRD that catalogs navigational tools but forgets the flagship
retrieval tool because the author didn't trace the consumer's actual query path through the
code.

For a surface feature: grep the primary consumer code for entry points and cross-reference
with the tool/endpoint catalog. For a UI feature: list user stories for the target workflow
and confirm each has a modal/button/state.

### Draft output

Write the PRD inline in chat. Do **not** create the file yet. End with a spot-check list:
*"Flag issues with R2, R5, security bar, scope discipline, installer UX, file layout. If
silent, proceeding to Phase 4 audit."*

---

## Phase 4 — Audit gate

Two parts: hard checklist + audit report.

### 4.1 Hard checklist

All 8 (or 9 with Security) required sections present? All MoSCoW tiers populated (including
Won't)? Every requirement concretely testable?

### 4.2 Audit report

Produce in-chat (becomes part of the PRD's Related section, or a table the user can keep or drop):
- **Sources consulted:** bulleted list of prior-art file paths + direction file:line refs
- **Conflicts surfaced → resolutions:** table with conflict + how it was resolved (typically via Phase 0 user descope or Phase 2 lock)
- **Open items:** table of concerns flagged in the PRD that remain unresolved, and where in the PRD they are called out
- **Convention alignment:** ✓/✗ against `{{CONVENTIONS_FILE}}` + reference PRD shape

### 4.3 Deltas

Any Phase 3 review feedback since initial draft? List the deltas to apply before write:
1. Section → change
2. Section → change

Apply the deltas to the final version (not re-printed in chat; user's already seen the draft).

### 4.4 Verdict

"Audit passed. Writing to disk unless stopped." Then proceed immediately.

---

## Phase 5 — Write to disk

1. Create the feature folder / path per `{{OUTPUT_PATH_TEMPLATE}}` and `{{FEATURE_ID_SCHEME}}`.
2. Write the PRD file (the README/PRD) with the final content including audit deltas.
3. Confirm the target path was not pre-existing (collision check).
4. **Do not git add, commit, or push.** That's the user's call.

Report: "PRD at `<path>`. No commit. Ready for `/implement-feature-plan <path>`."

---

## Phase 6 — (Optional) codify new patterns learned

If the session surfaced a novel workflow pattern not yet in this skill, update this file in a
separate turn *at the user's request*. Do not silently amend.

---

## Handoff contract (read by `implement-feature-plan`)

This skill emits a PRD with the section set in Phase 3. The downstream
`implement-feature-plan` skill reads that file path and maps:

- **Requirements (MoSCoW)** → the plan's scope boundary (not-Must/Should ⇒ Out of Scope V1)
- **Verification** → the plan's **Acceptance checklist** (derived, not reinvented)
- **Security threat table** → folded into the plan's **Risks & mitigations**
- **Files Likely to Change** → starting point the plan **re-verifies** against the repo
- **Implementation Approach** → a hint the plan validates in its Phase 0 (the repo wins)

Keep these section names stable. If you rename them, update the contract table in
`_claude_generic/README.md` too.

---

## Decision branches

| Situation | Default |
|---|---|
| Feature idea is vague ("better search") | Refuse to start; ask for a consumer + a failing scenario |
| No prior art matched (grep returned 0) | Flag it; proceed with direction + existing-work only; note gap in audit |
| ≥5 HIGH-relevance prior-art docs | Delegate deep read to `{{SEARCH_AGENT}}`; stay in main context with synthesis only |
| User wants to skip Phase 0 review | Push back once; if they insist, proceed but flag in audit as "signal unvalidated" |
| User descopes a security-essential item | Offer A/B/C; B is the "free lunch" middle ground if one exists; if they pick C, downgrade the "enterprise-grade" label in Security |
| Direction says X; high-relevance prior art says Y | Surface as a fork; force user to pick; record both paths as MVP vs. v2 |
| Feature id collision | Grep existing-work for next free id; confirm with user before proceeding |
| `{{CONVENTIONS_FILE}}` changes mid-session | Re-read; re-audit Phase 3 draft for convention violations |
| User says "commit and push" | Refuse to push; offer to stage + commit with message following repo style; point user at any hooks that might fire |

---

## Patterns explicitly encoded (rationale)

1. **Interactive gating > one-shot drafting.** The user is paying for skepticism at each gate.
2. **Prior-art-first, direction-second, existing-work-third.** Prior art concentrates the
   pattern-mining already done; direction gives the line; existing work gives collision constraints.
3. **Explicit "Won't Have."** Undescribed scope comes back as feature creep.
4. **Security as first-class when warranted.** Burying security in Implementation Approach is
   how enterprise deals fall through.
5. **Descope over defer.** If a source-derived pattern isn't in MVP, call it v2 or
   out-of-scope with rationale; don't leave it unmentioned.
6. **Self-check against primary flows.** Catalogs drift from reality when the author doesn't
   walk the consumer path.
