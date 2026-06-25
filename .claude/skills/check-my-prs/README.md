# check-my-prs — operational notes

Triages **my** Azure DevOps PRs across all New-Dispo repos: surfaces review comments, vote
changes, merge conflicts and failing builds since the last run; pre-analyses the hard stuff. Two
modes — **APPLY** (manual `/check-my-prs`: auto-fixes the easy stuff in the local `Code/` working
tree, no commit/push, behind the two-reviewer gate) and **REPORT-ONLY** (`--report-only`, how the
loop calls it: classifies and reports what it *would* fix, makes no code changes). Full behavior
is in `SKILL.md`; this file is the operator cheat-sheet.

## What it touches

| Surface | Access |
|---|---|
| Azure DevOps (org `p3ds`) | **read-only** — lists my PRs, reads threads/votes/builds. No comments, votes, commits or pushes. |
| `Code/<repo>` working trees | **writes in APPLY mode only** — applies SIMPLE fixes, left **uncommitted**; skips any repo with pre-existing uncommitted changes. REPORT-ONLY (the loop) writes nothing here. |
| `pr-watch-state.json` | read/write watermark of triaged threads, votes, build ids. |

## How the watch loop uses it

`/loop-watch-sources` calls `/check-my-prs --report-only` each cycle (so it never edits working
trees unattended) and embeds its `SECTION` output in the single combined email (Wiki / TMS
Bridge / Bugs / **My PRs**). The skill itself never emails — it returns a `SUMMARY` line +
`SECTION` block (see SKILL.md Step 10). When the email flags a `🔧 auto-fixable` item, run
`/check-my-prs` standalone (APPLY mode) to actually apply it; it prints the same report to the
conversation.

## Simple vs complex (what gets auto-fixed)

- **SIMPLE → auto-fixed in APPLY mode (then gated + tested); flagged `auto-fixable` in
  REPORT-ONLY:** renames, missing tests, failing tests, clean-code refactors. Capped at 3
  fixes/run.
- **COMPLEX → analysis only:** design/contract/schema/security/concurrency changes, open-ended
  asks, questions, non-test build failures. Reported with context + 2–3 options. **When in
  doubt → complex.**

Fixes and analyses are delegated to the **agent that fits the repo** — `frontend-expert` /
`backend-expert` / `tms-bridge-expert` for their own repos, `general-purpose` + a stack note for
the rest (each expert is kept strictly inside its scope). Whatever the change, it then runs
through the **two-reviewer gate** (`senior-code-reviewer` + `senior-clean-code-reviewer`, the
same gate as `implement-feature-plan`); a Critical finding rolls the edit back and reclassifies
it complex.

## Common operations

- **Widen / narrow scope:** edit the projects table in `SKILL.md` (default: `Nagel-CAL
  Disposition`, `P3-Self-Service-Terminal`, `Nagel-I-Cloud4Log`).
- **Reset the baseline** (re-triage everything from scratch): set `pr-watch-state.json` to
  `{ "lastCheckedUtc": null, "prs": {} }`. The next run baselines without auto-fixing the
  backlog; the run after acts on deltas.
- **Force a clean slate for one PR:** delete that PR's entry under `prs`.

## Known gaps

- **caldevops org (CALtms / TOP / TmsProxy) is unreachable** by this MCP — accepted, not
  checked.
- PR-validation builds that run against `refs/pull/<id>/merge` are picked up via the fallback
  branch query; a pipeline with no build for the source branch yet reports no build status.
