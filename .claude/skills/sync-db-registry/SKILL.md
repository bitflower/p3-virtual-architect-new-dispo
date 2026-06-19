---
name: sync-db-registry
description: Diff-driven sync of db-objects.json from TMS Bridge source. Compares git HEAD against the stored extractedFromCommit watermark, scans only changed files in the extraction scope (EntityConfigurations, entities, mutations, queries, DbContext, Startup.cs, resolvers), and either reports "no changes" or re-runs the tms-bridge-db-extractor agent for a delta update. Use when the user wants to refresh the DB registry, check if it's stale, or as a loop target for continuous sync.
tools: Bash, Read, Glob, Grep, Agent, Edit, Write
---

# Sync DB Registry

Keeps `Code/Disposition-Rollout-Tools/TmsBridgeDbVerifier/Registry/db-objects.json` in sync with the TMS Bridge source code.

## When to Use

- User asks to sync/refresh/update the DB registry
- As a `/loop` target for continuous sync (e.g. `/loop 30m /sync-db-registry`)
- After pulling new TMS Bridge code
- Before running the TmsBridgeDbVerifier

## How It Works

### Step 0 — Branch guard

Verify the TMS Bridge repo (`Code/Disposition-Abstraction-Layer`) is on `master`. Only `master` is relevant for the registry — feature branches may have experimental changes that shouldn't be extracted.

If NOT on `master` → report "TMS Bridge is on branch {branch}, skipping sync (only master is tracked)" and stop.

### Step 1 — Watermark check

Read `extractedFromCommit` from `db-objects.json`. Compare against `git rev-parse --short origin/master` in the TMS Bridge repo (`Code/Disposition-Abstraction-Layer`). Use `origin/master` so a `git fetch` (e.g. from `/update-repos`) is picked up without requiring a local checkout.

If they match → report "db-objects.json is up to date at commit {hash}" and stop.

### Step 2 — Scoped diff

Run `git diff --name-only {watermark}..HEAD` in the TMS Bridge repo, filtered to these paths (the extraction scope):

```
CALConsult.TMSBridge.API/Data/Entities/
CALConsult.TMSBridge.API/Data/DbContexts/
CALConsult.TMSBridge.API/GraphQL/Mutations/
CALConsult.TMSBridge.API/GraphQL/Queries/
CALConsult.TMSBridge.API/Startup.cs
CALConsult.TMSBridge.API/Services/Resolvers/
```

If no files changed in scope → update only the `extractedFromCommit` watermark to HEAD and report "no extraction-relevant changes, watermark advanced to {hash}".

### Step 3 — Classify changes

Categorize the changed files:

| Change type | Trigger | Action |
|---|---|---|
| EntityConfiguration `*Configuration.cs` | Columns changed | Full re-extraction needed |
| Entity class `*.cs` in entity folders | Property types changed | Full re-extraction needed |
| `BranchDbContext.cs` | Schema/registration changes | Full re-extraction needed |
| `Startup.cs` | New/removed mutation registrations | Full re-extraction needed |
| Mutation/Query `*.cs` (not entity/config) | Routine parameter changes | Targeted patch: count AddInput/AddOutput for affected routines, update expectedArgs |
| Resolver `*.cs` | Implicit chain changes | Report only, no registry change needed |

### Step 4a — Full re-extraction (if needed)

Invoke the `tms-bridge-db-extractor` agent with:
```
Execute the full extraction pipeline (Steps 1-11) against the TMS Bridge source code at Code/Disposition-Abstraction-Layer. Output the complete db-objects.json JSON array.
```

Then merge the result into the existing file structure (preserve $schema, baselineSource, expectedArgs metadata), update the `extractedFromCommit` watermark to HEAD, and write the file.

### Step 4b — Targeted patch (if only mutation/query logic changed)

For each changed mutation/query file:
1. Extract the routine name (`routineName` or `procedureName` variable)
2. Count `AddInput` + `AddOutput` calls to get the current parameter count
3. Update `expectedArgs` in db-objects.json for matching entries
4. Update `extractedFromCommit` watermark to HEAD

### Step 5 — Report

Output a summary:
- Previous watermark → new watermark
- Files changed in scope
- Action taken (none / patch / full re-extraction)
- If patched: which entries changed and how
- If re-extracted: delta summary (new/removed objects, column count changes)
