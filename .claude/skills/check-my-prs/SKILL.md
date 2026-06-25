---
name: check-my-prs
description: Triage my open Azure DevOps PRs across all New-Dispo repos. Detects review comments from other devs, vote/approval changes, merge conflicts and failing build pipelines since the last check; classifies comments SIMPLE vs COMPLEX. A manual run auto-applies SIMPLE fixes (renames, missing/failing tests, clean-code refactors) to the local Code/ working tree (never commits/pushes) behind the two-reviewer gate; called with --report-only by /loop-watch-sources it makes no code changes and only reports. COMPLEX items always get a read-only pre-analysis with options. Standalone (/check-my-prs) and folded into the loop's combined email as a "My PRs" section.
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Agent
---

# Check My PRs

Watches the pull requests **I** created on Azure DevOps, surfaces anything that needs my
attention since the last run, **fixes the easy stuff in the local working tree** (without
committing), and **pre-analyses the hard stuff** so I get context + options in the email.

## When to Use

- Standalone: `/check-my-prs` — triage my PRs on demand and print the report to the conversation.
- As a step inside `/loop-watch-sources` — the loop calls this skill and folds its output into
  the one combined notification email (alongside Wiki / TMS Bridge / Bugs).

## Modes — apply vs report-only

Read the invocation argument to pick the mode:

- **`/check-my-prs` (default — interactive / manual) → APPLY mode.** SIMPLE items are fixed in
  the local working tree (Step 7: uncommitted, behind the two-reviewer gate). You're present to
  see it happen.
- **`/check-my-prs --report-only` (how `/loop-watch-sources` calls it) → REPORT-ONLY mode.**
  Make **no code changes at all** — classify SIMPLE items and describe the fix that *would* be
  applied ("run `/check-my-prs` to apply"), but never checkout, edit, gate or test. This keeps
  the **unattended loop from editing working trees**.

COMPLEX pre-analysis (Step 8) is read-only and runs in **both** modes. The only behavioral
difference is whether Step 7 applies SIMPLE fixes or just reports them.

## Hard guarantees (safety rails — never violate)

1. **Never writes to Azure DevOps.** Read-only against ADO: no PR comments, no votes, no
   commits, no pushes, no thread resolution. The only writes are to the **local Code/ working
   tree** (applying fixes) and to this skill's **state file**.
2. **Never commits or pushes.** Fixes are left **uncommitted** in the working tree for me to
   review. The email tells me what changed and on which branch.
3. **Never clobbers my work.** A repo with **uncommitted changes is left untouched** — the skill
   downgrades that PR's fix to a manual note instead of switching branches over dirty state.
4. **Never destructive.** No `reset --hard`, no `checkout -f`, no `clean`, no force-push, no
   branch deletion. The only `git checkout --` allowed is to revert **the skill's own edit** on
   a file that was clean before the skill touched it (gate-failure rollback, Step 7).
5. **caldevops org is out of scope** (accepted). CALtms / TOP / TmsProxy PRs live in the
   `caldevops` org, which this MCP connection cannot reach. Not checked.

## Scope — projects scanned

The MCP is bound to org **`p3ds`**. One `created_by_me` query **per project** returns my PRs
across **every repo** in that project, so no repo enumeration is needed. Scan these three
New-Dispo projects (edit this list to change scope):

| Project | Covers |
|---|---|
| `Nagel-CAL Disposition` | TMS Bridge, Backend, Frontend, Nagel-GCP, Rollout-Tools, UI-Automation, tms-alloydb-schema |
| `P3-Self-Service-Terminal` | Driver Terminal (Self-Service-Terminal-Backend) |
| `Nagel-I-Cloud4Log` | Cloud4Log |

## Repo → local folder map

A PR's `repository` maps to `Code/<repository>`, **except** `Self-Service-Terminal-Backend` →
`Code/Driver-Terminal/Self-Service-Terminal-Backend`. The branch to work on is the PR's
`sourceRefName` with the `refs/heads/` prefix stripped.

## Repo → expert agent (pick the fitting agent by repo type)

Both the **fix** (Step 7) and the **complex analysis** (Step 8) are delegated to the agent that
knows the stack. Use a named expert **only for its own repo** — never push an expert outside its
built-in scope; for any repo without a dedicated expert, use `general-purpose` with the stack
note pasted into the prompt.

| Repo | Stack | Agent |
|---|---|---|
| `Disposition-Frontend` | Angular 19, Nx, Angular Material | `frontend-expert` |
| `Disposition-Backend` | .NET 8 CQRS (MediatR), EF Core, MSTest | `backend-expert` |
| `Disposition-Abstraction-Layer` | .NET 8 HotChocolate GraphQL, multi-tenant | `tms-bridge-expert` |
| `Nagel-GCP` (Functions / Cloud4Log) | .NET cloud functions on GCP | `general-purpose` + stack note |
| `Disposition-Rollout-Tools` | .NET CLI tools | `general-purpose` + stack note |
| `Disposition-UI-Automation` | Selenium + NUnit (C#) | `general-purpose` + stack note |
| `Self-Service-Terminal-Backend` | Driver-Terminal backend | `general-purpose` + stack note |
| `tms-alloydb-schema` | AlloyDB / PostgreSQL schema + SQL | `general-purpose` + stack note |

The two-reviewer gate (`senior-code-reviewer` + `senior-clean-code-reviewer`) is
**repo-agnostic and always runs**, whichever expert applied the fix.

## Reference — Azure DevOps enum values

| Field | Values |
|---|---|
| PR `status` | 1 Active · 2 Abandoned · 3 Completed |
| PR `mergeStatus` | 0 NotSet · 1 Queued · **2 Conflicts** · 3 Succeeded · 4 RejectedByPolicy · 5 Failure |
| reviewer `vote` | **10 Approved** · 5 Approved-with-suggestions · 0 No vote · **-5 Waiting for author** · **-10 Rejected** |
| build `result` | 0 None · 2 Succeeded · 4 PartiallySucceeded · **8 Failed** · 32 Canceled |
| build `status` | 0 None · 1 InProgress · 2 Completed · 4 Cancelling · 8 Postponed · 32 NotStarted |

The system author `Microsoft.VisualStudio.Services.TFS` (ref-update / "published" / "added
reviewer" messages) is **not** a human comment — always filter it out.

## State file

`.claude/skills/check-my-prs/pr-watch-state.json` — the watermark of what's already been seen
and triaged, so each run only acts on **deltas** and never re-fixes the same comment:

```json
{
  "lastCheckedUtc": "2026-06-25T09:00:00Z",
  "prs": {
    "33458": {
      "repository": "Disposition-Frontend",
      "project": "Nagel-CAL Disposition",
      "sourceBranch": "feature/e2e-trace-sql-logging",
      "status": "Active",
      "isDraft": false,
      "mergeStatus": "Succeeded",
      "reviewerVotes": { "boyan.valchev@p3-group.com": 0 },
      "triagedThreads": { "198579": 1 },
      "pendingFixes": [],
      "lastBuildId": 0,
      "lastBuildResult": null
    }
  }
}
```

`triagedThreads` maps `threadId → commentCount` already triaged. A thread re-surfaces only if
its comment count grows (a new reply). `pendingFixes` queues SIMPLE items the **report-only**
loop classified but did not apply (`{ threadId, file, line, ask }`); a manual **APPLY** run
drains them — so "run `/check-my-prs` to apply" actually finds the work even though the thread
is already marked triaged. First run (state `prs` empty) establishes the baseline:
record current threads/votes/builds, report a one-line inventory, and **do not auto-fix the
pre-existing backlog** — only deltas from the next run onward trigger fixes.

## Tools to load first

Load these via **ToolSearch** at the start (they are deferred):
`mcp__azure-devops__repo_list_pull_requests_by_repo_or_project`,
`mcp__azure-devops__repo_get_pull_request_by_id`,
`mcp__azure-devops__repo_list_pull_request_threads`,
`mcp__azure-devops__pipelines_get_builds`,
`mcp__azure-devops__pipelines_get_build_log`.

---

## How It Works

### Step 1 — Load state

Read `pr-watch-state.json`. Keep `lastCheckedUtc` and the `prs` map. If the file is missing or
`prs` is empty, this is a **baseline run** (see Step 8 handling).

### Step 2 — List my active PRs (all repos, all three projects)

For each project in scope, call `repo_list_pull_requests_by_repo_or_project` with
`{ project, created_by_me: true, status: "Active", top: 100 }`. `created_by_me` uses the
**currently logged-in MCP identity** — no email is hardcoded. Union the results. Record
`pullRequestId`, `repository`, `project`, `title`, `sourceRefName`, `isDraft`.

### Step 3 — Detect completed / abandoned PRs

For each PR id in state but **absent** from Step 2's active set, fetch it by id
(`repo_get_pull_request_by_id` with the stored repository + project). If `status` is 3
(Completed) → news item "✅ merged"; if 2 (Abandoned) → news item "🗑 abandoned". Drop it from
state afterward.

### Step 4 — Per PR, gather news since last check

For each active PR, in parallel where possible:

**4a. Detail** — `repo_get_pull_request_by_id` (repo + id). Read `reviewers[].vote`,
`mergeStatus`, `isDraft`, `status`.
- **Vote change:** compare each reviewer's vote to `reviewerVotes` in state. Any change is a
  news item — `10` Approved, `5` Approved-with-suggestions, `-5` Waiting-for-author, `-10`
  Rejected. (-5 / -10 usually pair with comments handled in 4b; still report the vote.)
- **Merge conflict:** if `mergeStatus` is now `2` (Conflicts) and wasn't before → news item
  "⚔ merge conflict with target — rebase needed". Not auto-fixed.

**4b. Comment threads** — `repo_list_pull_request_threads` with `{ repositoryId, project,
pullRequestId, fullResponse: true }`. Keep threads whose `status` is `Active` and whose first
comment author is **not me** and **not** `Microsoft.VisualStudio.Services.TFS`. For each such
thread, compare its comment count to `triagedThreads[threadId]`: if the id is new, or its count
grew, it is a **new human comment** → actionable (Step 5). `fullResponse` gives `threadContext`
(`filePath`, `rightFileStart.line`) so the comment can be located in code.

**4c. Build pipeline** — `pipelines_get_builds` with `{ project, repositoryId,
branchName: sourceRefName, queryOrder: "FinishTimeDescending", top: 3 }`. Take the most recent
build. If `status` is 2 (Completed) and `result` is 8 (Failed) and its `id` differs from
`lastBuildId` → **failing build** news item. Fetch a short failing excerpt with
`pipelines_get_build_log`. If the first query is empty, retry once with
`branchName: "refs/pull/{pullRequestId}/merge"` (PR-validation builds sometimes use the merge
ref). A failing build whose cause is a failing/missing test is **simple** (Step 5); a
compile/infra failure is usually **complex**.

### Step 5 — Classify each actionable item: SIMPLE vs COMPLEX

Apply the rubric to every new human comment and every failing build:

**SIMPLE** — mechanical, low-risk, localized, no design decision, no public-API / contract /
schema / migration change:
- **Renames** — variables, methods, files, symbols (incl. an explicit "rename X to Y" request).
- **Missing tests** — add the called-out test(s). Backend/TMS Bridge use **MSTest**
  (`[TestClass]`, `[TestMethod]`, `[TestInitialize]` — not xUnit/NUnit; see root CLAUDE.md).
- **Failing tests** — fix the test, or the trivial one-line defect a failing test exposes
  (including test failures surfaced by a failing build in 4c).
- **Clean-code refactors** — extract method, remove dead code, DRY, formatting, small SRP
  split, naming consistency.

**COMPLEX** — needs a design/architecture decision; touches a contract / public API / schema /
migration; spans many files or crosses components; concerns security, concurrency or
fallback/partial-state semantics; is an open-ended ask or a **question** (not a concrete change
request); or a build failure that isn't a test failure.

**When in doubt → COMPLEX.** (Analysis-only is the safe default for this workspace.)

If, once you open the code, a "simple" fix turns out to need a contract/API/schema change or a
real design call → **abort and revert your partial edit** (Step 7 rollback), reclassify COMPLEX.

### Step 6 — Find the related PRD / exploration (context for every item)

For each PR, locate the matching spec to cite in the report:
- The PR `description` often names the PRD (e.g. "PRD 010"). Map the number to
  `03_PRD/Open/<NNN>_*/` or `03_PRD/Closed/<NNN>_*/`.
- Otherwise `Glob`/`Grep` `03_PRD/**` and `02_Explorations/**` for keywords from the PR title /
  branch slug. Cite the file path. If none found, say "no matching PRD/exploration".

### Step 7 — SIMPLE → apply the fix locally (no commit/push), then gate

**REPORT-ONLY mode (the loop):** skip every code change in this step. For each SIMPLE item: emit
a `[SIMPLE · auto-fixable]` line stating the exact fix that would be applied (file:line + what
changes) and "run `/check-my-prs` to apply", **and enqueue it into the PR's `pendingFixes`**
(`{ threadId, file, line, ask }`) so a later manual APPLY run can drain and apply it. No fetch,
checkout, edit, gate or test. Then continue to Step 8 for COMPLEX items. The rest of this step is
**APPLY mode only**.

**APPLY mode (manual, default):** first fold any `pendingFixes` queued by earlier report-only
(loop) runs into this run's SIMPLE set (drop entries whose thread is no longer Active), then add
this run's new SIMPLE deltas. Per repo touched by SIMPLE items, **at most one branch per repo per
run**:

1. **Resolve local path** from the repo→folder map. If the repo isn't cloned → downgrade to a
   manual note ("repo not cloned locally").
2. **Dirty guard:** `git -C <path> status --porcelain`. If non-empty (uncommitted changes that
   aren't this run's) → **do not touch**; downgrade every simple item for this repo to a manual
   note ("repo has uncommitted changes; not modified") and still do Step 8's analysis. Stop here
   for this repo.
3. **Get on the branch (clean tree only):** `git -C <path> fetch origin --quiet`, then
   `git -C <path> checkout <sourceBranch>` (create tracking from `origin/<sourceBranch>` if no
   local branch), then `git -C <path> pull --ff-only` to take the latest. If pull is non-ff,
   note it and work on the local tip.
4. **Apply the minimal fix via the repo's expert agent** (see *Repo → expert agent*). Hand the
   agent: the exact ask (quoted comment / failing test name), `threadContext.filePath` + line,
   the branch it is on, and hard constraints — *make only the minimal change requested; do not
   commit or push; do not touch unrelated files*. A trivial one-token rename you may apply
   inline with Edit instead of spawning an agent. Keep it tight to exactly what was asked.
5. **Two-reviewer gate (run on the change — required "on all changes"):** spawn **both** lenses
   in parallel, in a single message with two `Agent` calls, pointed at the repo's working-tree
   diff (`git -C <path> diff`):
   - `senior-code-reviewer` — architectural / security / correctness lens.
   - `senior-clean-code-reviewer` — clean-code / cohesion / naming / test-cleanliness lens.

   Triage findings **Critical / High / Medium / Low**:
   - **Critical** → roll back the skill's edit (`git -C <path> checkout -- <files I touched>` —
     safe, they were clean pre-edit) and **reclassify the item COMPLEX** with the finding as
     context. The "simple" fix wasn't safe.
   - **High** → keep the edit but flag it loudly ("⚠ gate: High — review carefully") and list
     the findings.
   - **Medium / Low** → keep; list briefly.
6. **For test fixes / additions / refactors, run the suite** to confirm green (`{{TEST_CMD}}`):
   - Backend: `dotnet test Code/Disposition-Backend/CALConsult.Disposition.API.sln`
   - TMS Bridge: `dotnet test Code/Disposition-Abstraction-Layer/*.sln`
   - Frontend: `cd Code/Disposition-Frontend && npx nx run-many --target=test`
   Report pass/fail. If still red, flag it.
7. **Leave it uncommitted.** Record file(s) changed, a one-line diff summary, the branch left
   checked out, the gate verdict, and the test result.

**Cap:** apply at most **3** simple fixes per run. List any beyond the cap as "pending — run
`/check-my-prs` manually" so an unattended loop never makes a large sweep of changes.

If a second simple item targets a different branch in a repo already dirtied by step 4 this
run → downgrade it to a manual note (can't switch branches over the in-progress fix).

### Step 8 — COMPLEX → pre-analysis with options (no code change)

For each complex item write a concise block: the **ask** (quote the comment / name the build
failure), **where** (`file:line` from `threadContext`, or failing stage), the **context** (the
PRD/exploration from Step 6 + one-line problem framing), and **2–3 solution options** with a
one-line trade-off each. Delegate the analysis to the repo's agent (see *Repo → expert agent* —
expert for the three core repos, `general-purpose` + stack note otherwise) so the options are
stack-aware, but keep the written block short — enough for me to decide, not a full design doc.

**Baseline run** (Step 1 said `prs` empty): do **not** auto-fix the pre-existing backlog — stale
unresolved threads may already be addressed in code, and an unattended first run shouldn't sweep
them. Instead, **read-only**: list each open PR with its current review status, and list any
currently-open human comments with their SIMPLE/COMPLEX classification (so nothing is hidden),
but make no code changes. Record everything into state (mark all current threads triaged) so
that from the next run on, only **new** activity triggers fixes/analysis. Lead the report with
"baseline established — N open PRs tracked".

### Step 9 — Update state

Write `pr-watch-state.json`: set `lastCheckedUtc` to now (UTC ISO 8601), upsert each active
PR's `reviewerVotes`, `mergeStatus`, `status`, `isDraft`, `lastBuildId`/`lastBuildResult`, and
add every triaged thread to `triagedThreads` (id → current comment count). In **report-only**
mode, enqueue SIMPLE items into `pendingFixes`; in **apply** mode, remove each `pendingFixes`
entry once its fix is applied. Remove completed / abandoned PRs.

### Step 10 — Emit output (the contract the loop consumes)

Print this block to the conversation **and** return it. `/loop-watch-sources` parses `SUMMARY`
into the email subject and embeds `SECTION` in the body; a standalone run just shows it.

```
=== check-my-prs ===
SUMMARY: <compact one-liner, or exactly "no changes">
SECTION:
--- My PRs ({N} items) ---
{formatted items — see legend}
===
```

If nothing is new, emit `SUMMARY: no changes` and omit `SECTION`. The skill **does not send
email** — that is the loop's job (and a standalone run doesn't need one).

**Item legend / formatting:**

```
🟢 #33456 SQL tracing decorator (Disposition-Abstraction-Layer)
   Boyan Valchev APPROVED · mergeable · build ✓ → ready to merge

✅ #33457 Trace propagation (Disposition-Backend) — comment [SIMPLE · fixed]   ← APPLY mode
   Boyan Valchev @ src/.../TraceMiddleware.cs:42 — "rename traceId → correlationId"
   Fixed: renamed traceId→correlationId (3 refs) · branch feature/e2e-trace-sql-logging · UNCOMMITTED
   Gate: clean (0 Critical/High) · Tests: 142 passed · PRD 03_PRD/Open/010_E2E_Trace_SQL_Logging/PRD.md
   ⚠ review & commit yourself

🔧 #33457 Trace propagation (Disposition-Backend) — comment [SIMPLE · auto-fixable]   ← REPORT-ONLY mode (loop)
   Boyan Valchev @ src/.../TraceMiddleware.cs:42 — "rename traceId → correlationId"
   Would rename traceId→correlationId (3 refs) on feature/e2e-trace-sql-logging · run /check-my-prs to apply
   PRD 03_PRD/Open/010_E2E_Trace_SQL_Logging/PRD.md

🧩 #33346 pg_notify CDC writer (Nagel-GCP) — comment [COMPLEX · needs you]
   Reviewer X @ writer.cs:88 — "could lose events if the channel buffer overflows under burst"
   Context: PRD 03_PRD/Open/004_PG_Notify_CDC_Sendung/PRD.md — unbounded NOTIFY backlog
   Options:
     A) bounded channel + drop-oldest + metric — simplest, loses events under extreme burst
     B) WAL/outbox table drained by writer — durable, adds a table + cleanup job
     C) backpressure to producer — no loss, couples producer to writer health

🔴 #33346 build FAILED (Nagel-GCP CI · stage "Test") — [SIMPLE · fixed]
   2 tests red: SendungWriterTests.Notify_* — null channel name
   Fixed: guard + test data · Gate: clean · Tests: green
   ⚠ review & commit yourself

⚔ #33458 Trace ID badge (Disposition-Frontend) — MERGE CONFLICT with master → rebase needed
   manual (not auto-fixed)
```

In APPLY mode SIMPLE items render as `✅ … [SIMPLE · fixed]` with gate/test verdict; in
REPORT-ONLY mode as `🔧 … [SIMPLE · auto-fixable]` with a "would …" line and no gate/test. Order
items by urgency: rejected/conflict/failed-build first, then complex, then simple, then
approvals/info. End `SECTION` with a one-line note for any PR with **no** news ("4 other open
PRs unchanged"), and — if `pendingFixes` is non-empty across all PRs — a final reminder line
"N auto-fixable fix(es) pending — run /check-my-prs to apply."

---

## Error handling

- **MCP/ToolSearch fails:** report the error in `SUMMARY` and `SECTION` ("PR check unavailable:
  <error>"), do not touch any repo, leave state unchanged so the next run retries the same delta.
- **A single project query fails:** skip that project, continue the others, note it.
- **Repo dirty / not cloned:** downgrade that PR's fixes to manual notes (Step 7.1–7.2). Never
  an error — it's expected.
- **Gate agent fails to return:** treat as "gate inconclusive" → keep the edit but flag
  "⚠ gate did not complete — review manually", never auto-promote it to clean.
- **Test command fails to run** (toolchain missing): note "tests not run", don't block the report.
- **Nothing new:** `SUMMARY: no changes`, no section. The loop then won't email on PRs alone.

