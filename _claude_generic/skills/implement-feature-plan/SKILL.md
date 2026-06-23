---
name: implement-feature-plan
description: Plan and execute a feature PRD end-to-end with brutal pushback, an explicit implementation plan, parallel agent streams on a feature branch, and code-review gates between every step.
argument-hint: <path-to-prd.md>
---

# Implement Feature Plan (portable)

You are about to take a feature PRD (the output of `validated-prd`, or any PRD/README) and
drive it through to implementation. Follow this playbook **exactly**. The user explicitly
wants the methodology, not improvisation. Skipping a step is a failure.

The PRD is at: **$ARGUMENTS**

If `$ARGUMENTS` is empty, ask the user for the path and stop.

> **This skill consumes the PRD produced by `validated-prd`** (see `## Handoff contract`). It
> produces the buildable spec — `{{PLAN_FILENAME}}` — that the PRD deliberately is not.

---

## Config — set per project

| Knob | What it is | Default if unset |
|---|---|---|
| `REVIEWER_ARCHITECTURAL` | Agent for architecture/security review | built-in `/code-review` at high effort; else a `general-purpose` agent with the architectural checklist below |
| `REVIEWER_CLEANCODE` | Agent for clean-code/cohesion review | a `general-purpose` agent with the **Clean-code fallback checklist** below |
| `TEST_CMD` | Full test-suite command | infer from repo (package.json / Makefile / pytest / etc.); ask if ambiguous |
| `START_CMD` | How to start the stack for smoke test | infer from the project's readme; ask if ambiguous |
| `BRANCH_SCHEME` | Feature branch naming | `feature/<slug>` |
| `PLAN_FILENAME` | Implementation-plan filename | `IMPLEMENTATION_PLAN.md` |
| `CONVENTIONS_FILE` | Binding conventions doc(s), e.g. `CLAUDE.md` | infer from repo |
| `STACK_NOTES` | Project idioms for typed contracts / components / db | infer from repo |

`{{KNOB}}` means "use the configured value, else the default."

### Reviewer resolution (config-knob + fallback)

Two **independent** review lenses run at the gates — architectural/security and
clean-code/cohesion. Neither lens reliably catches the other's issues, so both run, in
parallel, in a single message with two tool calls.

- If `REVIEWER_ARCHITECTURAL` / `REVIEWER_CLEANCODE` name real custom agents in this repo, use them.
- Else for the architectural lens, prefer the built-in `/code-review` skill at high effort.
- Else (or for the clean-code lens), spawn a `general-purpose` agent and paste the matching
  checklist below into its prompt so the lens is concrete.

**Architectural fallback checklist:** OWASP/security boundaries, secret handling, edge cases,
fallback/partial-state semantics, error handling, concurrency/races, performance on hot
paths, schema/contract correctness, migration safety, API surface and status codes.

**Clean-code fallback checklist:** function size & SRP, module cohesion (did new logic land
in an already-large file that should have been split?), naming, dead code, DRY, comment
quality, test cleanliness, consistency with the named reference page/module.

---

## Phase 0 — Read and push back (no code, no branches)

1. Read the PRD in full. Read any docs it references.
2. Read enough of the actual codebase to verify the PRD's claims about file paths,
   conventions, and integration points. **PRDs lie.** They name files that don't exist,
   follow conventions the repo abandoned, or describe architectures from a previous
   iteration. The repo is the source of truth, not the PRD. Note every divergence. (The PRD's
   **Files Likely to Change** and **Implementation Approach** sections are exactly the
   unverified hints to re-verify here.)
3. Read `{{CONVENTIONS_FILE}}` (root + any nested) for binding conventions.
4. **Push back skeptically and brutally** in a single response before doing anything else.
   Cover at minimum:
   - **Footguns in the PRD** — things that will break in production but the PRD hand-waves
     (partial state, fallback semantics, secret handling, hot-reload races, framework
     introspection of magic functions, migrations on virgin DBs, etc.).
   - **Wrong file paths in the PRD** vs the actual repo conventions you observed.
   - **Parallelization reality check** — most "parallelizable" features have a few sequential
     bottleneck files that will cause merge collisions. State which files are bottlenecks. If
     the user asked for git worktrees, recommend against them unless the parallel streams
     truly touch disjoint trees, and explain the merge-cost vs wall-clock-savings tradeoff honestly.
   - **Security boundaries** — anything that touches secrets, admin actions, or user data:
     explicitly call out where the work must run server-side vs client-side.
   - **Scope creep** — anything in the PRD that depends on a concept not yet defined in the
     repo (e.g. "per-project X" when "project" isn't a real entity). Recommend descoping
     completely, not deferring.
5. Propose a **stream breakdown** — typically Stream 0 (foundation, done by you in the main
   session), then 2 parallel agent streams on disjoint file sets, then a final integration stream.
6. Ask 3–7 numbered questions covering the locked-in decisions you need before you can write
   the plan. Examples: worktrees yes/no? fallback semantics for partial config? auto-seed on
   migrate vs manual CLI? server-side vs client-side for sensitive ops? confirm scope cuts?
   UI consistency reference (which existing page should new UI mirror)?
7. **Stop. Wait for answers.** Do not edit files. Do not create branches. Do not write the plan yet.

This phase exists because the user is paying you to be skeptical, not compliant. If you
cannot find at least three things to push back on, you have not read the PRD carefully enough.

---

## Phase 1 — Write the implementation plan as a markdown file

After the user answers Phase 0 questions:

1. Write the plan to `<feature-folder>/{{PLAN_FILENAME}}` (same folder as the PRD).
2. The plan **must contain** these sections in this order:
   - **Status + Branch + Worktree decision** at the very top
   - **Decisions locked in** — a table of every Phase 0 question with the user's answer
   - **Architectural notes that bind the implementation** — the actual integration points
     discovered in the repo, including any places where the PRD's file paths were wrong (call
     them out explicitly)
   - **Schema** — full column-by-column table for any new DB tables, with FK behavior,
     indexes, and unique constraints
   - **File-level work breakdown** — per stream, the **exact list of files each stream
     owns**. The lists must be disjoint. Constraints handed to each agent (what they may NOT
     touch, conventions they must follow) go inline with the file list.
   - **Code review gates** — see Phase 3
   - **Risks & mitigations** table — *seed this from the PRD's Security threat table if present*
   - **Out of scope** — explicit list of what is NOT being built, including anything the PRD
     mentioned that got descoped
   - **Acceptance checklist** — concrete, verifiable items — *derive these from the PRD's
     Verification section; don't reinvent them*
   - **Execution order** — numbered step list including branch creation, plan commit, each
     stream, each review gate
3. Write the plan with the same brutal honesty as Phase 0. If the PRD says "use provider X"
   and you know the resolver has no tests for it, say so in Risks.
4. **Stop. Show the file path. Wait for the user to read it and approve or push back.** Do not
   start coding.

---

## Phase 2 — Create the feature branch and commit the plan to it (NEVER to the default branch)

After the user approves the plan:

1. The plan file is currently sitting **uncommitted on the default branch** in the working
   tree. Branching now carries it to the new branch automatically.
2. Run, in this exact order (adapt the name to `{{BRANCH_SCHEME}}`):
   ```
   git checkout -b <branch per {{BRANCH_SCHEME}}>
   git add <feature-folder>/{{PLAN_FILENAME}}
   git commit -m "docs: implementation plan"
   ```
3. **The plan must never land on the default branch.** If at any point you notice the default
   branch has the plan file staged or committed, stop and tell the user.
4. **Stop and wait for the user's "go" before Stream 0.** This is a hard gate even though the
   plan was already approved — branch creation deserves its own confirmation, because it's the
   moment work becomes real.

---

## Phase 3 — Code review gates (the rule that makes everything else worth doing)

**Every implementation step is followed by a code review before the next step starts.** Run
BOTH lenses in parallel for Foundation and Backend-implementation streams (resolve each lens
via the Reviewer-resolution rules above):

| Stream type | Lenses | Why |
|---|---|---|
| Foundation: schemas, migrations, resolver/service skeletons, typed contracts | architectural AND clean-code (parallel, single message, two tool calls) | Architectural correctness (schema/contract mistakes cascade into every downstream stream) + module cohesion (foundation code often lands in existing large files; wrong home kills maintainability). |
| Backend implementation: services, adapters, API routes, hot-path surgery, security-sensitive endpoints, tests | architectural AND clean-code (parallel) | OWASP, edge cases, fallback semantics, performance + function size, SRP, naming, no-bloat-of-already-large-files, test cleanliness. The architectural lens does not reliably flag module-cohesion or function-extractability issues — the clean-code lens does. |
| Frontend: pages, components, services | clean-code for the bulk pass (cleanliness, SRP, DRY, naming, consistency with reference page) **plus** a focused architectural mini-pass on any component that touches admin endpoints or secrets |
| Final integration: rebase, smoke test, cross-cutting behavior | architectural | Does the assembled feature actually work under all the fallback/partial/full paths? Clean-code concerns already vetted upstream. |

**Review handling rules (non-negotiable):**
- Each review's findings get triaged into **Critical / High / Medium / Low**.
- **Critical and High must be fixed before the next step starts.**
- **Medium** gets fixed inside the next step if cheap, otherwise logged in a "deferred"
  section of the plan.
- **Low** is logged only.
- Fixes ship as follow-up commits with the message `review-fix: <area>` so the audit trail is clear.
- If a reviewer raises something that contradicts the plan, **stop and ask the user** before
  changing course. Reviewers don't override user decisions.

**Reviewer parallelism:** two flavors apply:
1. Within a single stream's gate, when the table specifies BOTH lenses, spawn them in a single
   message with two tool calls.
2. Across streams, review gates on disjoint streams (e.g. backend Stream A and frontend Stream
   B) also run in parallel in a single message.

---

## Phase 4 — Spawn parallel implementation agents

After Stream 0 + its review gate are committed:

1. Spawn the parallel implementation agents in **a single message with multiple `Agent` tool
   calls**. Never sequentially.
2. Each agent gets:
   - The post-review commit SHA as its starting point
   - The **exact file ownership list** from the plan (what it owns AND what it must not touch)
   - All conventions from `{{CONVENTIONS_FILE}}` and the plan's "constraints handed to this agent" notes
   - The typed contracts (schemas/interfaces, per `{{STACK_NOTES}}`) from Stream 0 so frontend
     and backend agents agree without coordinating
3. **No git worktrees by default.** Single branch. Parallelism is enforced by disjoint file
   ownership, not by isolated working trees. Worktrees are only justified when streams
   genuinely touch disjoint subtrees AND the user explicitly asks for them after hearing the
   merge-cost argument.

---

## Phase 5 — Integrate, smoke test, report

1. Pull both agents' work into the feature branch.
2. Run any migrations against a real dev DB.
3. Start the actual stack with `{{START_CMD}}` (never standalone/ad-hoc containers if the
   project documents a compose/start flow).
4. Run a real smoke test that exercises the new code path end-to-end. Not just unit tests.
5. Run the full test suite with `{{TEST_CMD}}`.
6. Final review gate: architectural lens on the integrated feature.
7. Report back with:
   - What's green
   - What's not
   - All review findings (Critical/High/Medium/Low counts, with links to fix commits)
   - Any deviations from the plan and why

---

## Handoff contract (what this skill expects from the PRD)

The PRD (ideally produced by `validated-prd`) provides these, which this skill maps:

| PRD section | Used here as |
|---|---|
| Requirements (MoSCoW) | Scope boundary — anything not Must/Should is Out of Scope V1 |
| Verification | Source for the plan's **Acceptance checklist** |
| Security threat table | Seed for the plan's **Risks & mitigations** |
| Files Likely to Change | Starting point to **re-verify** against the repo in Phase 0 |
| Implementation Approach | Hint to validate in Phase 0 (the repo wins on conflict) |

If the input PRD lacks a section, treat it as "not provided" and derive it yourself. Any
PRD/README is a valid input; sections just make the handoff cleaner.

---

## Cross-cutting rules (apply at every phase)

### Branch hygiene
- Feature work lives on a `{{BRANCH_SCHEME}}` branch. Never commit feature work to the default branch.
- The implementation plan file is the **first commit** on the feature branch, before any code.
- Never force-push, never reset, never amend without explicit user approval.

### Parallelization
- Default to single branch with disjoint file ownership.
- Use worktrees only when the user insists AND the streams are genuinely disjoint subtrees.
- When using parallel agents, always spawn them in a **single message with multiple `Agent`
  tool calls** — never sequentially.
- Review gates on disjoint streams run in parallel too.

### Confirmation gates (stop and wait)
- After Phase 0 pushback (before writing the plan)
- After Phase 1 plan write (before branching)
- After Phase 2 branch + plan commit (before Stream 0)
- After every review gate (before next stream)
- Whenever a reviewer's finding contradicts the plan
- Whenever you're tempted to do something destructive (force-push, reset, drop tables, delete
  files you didn't create)

### Honest pushback
- State arguments for the alternative even when the user has told you their preference. Then
  comply if they don't change their mind.
- If the PRD says "easy" and you see a footgun, name the footgun.
- If you cannot find anything to push back on in Phase 0, you have not read carefully enough.

### Repo conventions over PRD conventions
- The PRD describes intent. The repo describes reality. When they conflict, the repo wins.
- Common PRD lies: file paths, model locations, backward-compat assumptions, "this just
  works" claims about external providers.
- Always verify the PRD's integration points by reading the actual files before the plan is written.

### UI consistency
- New UI must match the **most recent reference page** the user names. Read that page first.
  Mirror its structural patterns: imports, layout shell, table component, action idioms,
  notification style.
- Follow the project's component conventions (per `{{STACK_NOTES}}` — e.g. one component per file).
- Do not introduce new UI libraries when the project already uses one.

### Scope discipline
- Anything that depends on a concept not yet defined in the repo gets **descoped**, not
  "schema-supported but UI-deferred". The schema cost is not free.
- "Out of scope" goes in the plan explicitly so future you can find it.

### Secrets and admin
- Secrets never enter the database. Store env-var **names**, resolve at runtime.
- Admin actions and any operation that needs an API key run **server-side**. The browser never
  sees keys.
- Test/diagnostic endpoints get rate limited.
- Deletion of referenced rows is blocked at the data layer (e.g. FK `ON DELETE RESTRICT`), not
  just in app code.

### Tests
- New behavior gets new tests. Fallback paths get tested explicitly.
- Tests must cover: happy path, every fallback branch, error handling, security refusal cases,
  idempotency of seed/migration code.

---

## What this skill is NOT for

- Trivial single-file edits.
- Bug fixes without architectural impact.
- Pure refactors with no new behavior.
- Anything that doesn't have a written PRD/spec to start from.

For those cases, work directly without this playbook.
