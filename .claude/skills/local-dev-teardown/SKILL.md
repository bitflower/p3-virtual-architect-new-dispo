---
name: local-dev-teardown
description: Tear down the local development environment. Stops services, reverts TMS Bridge tweaks, and optionally removes Docker infrastructure. Use when the user wants to stop local dev, clean up, or revert local changes.
allowed-tools: Bash,Read,Edit
---

# Local Dev Teardown Skill

Reverses everything done by `/local-dev-prepare` and `/local-dev-start`.

## When to Use

- User asks to "stop local dev", "tear down", "clean up local environment", "revert local changes"
- Before switching to work on a different branch in the TMS Bridge
- At the end of a local development session

## What It Does

### 1. Stop Running Services

Check for PID files and stop processes:

```bash
for pidfile in /tmp/tms-bridge.pid /tmp/new-dispo-backend.pid /tmp/new-dispo-frontend.pid; do
  if [ -f "$pidfile" ]; then
    kill $(cat "$pidfile") 2>/dev/null
    rm "$pidfile"
  fi
done
```

Also check for any processes on the expected ports as a fallback:
```bash
lsof -ti:5158 | xargs kill 2>/dev/null  # TMS Bridge
lsof -ti:5101 | xargs kill 2>/dev/null  # Backend
lsof -ti:4200 | xargs kill 2>/dev/null  # Frontend
```

### 2. Revert Local Tweaks

Restore the TMS Bridge and Frontend to their original committed state:

```bash
cd "Code/Disposition-Abstraction-Layer"
git checkout -- CALConsult.TMSBridge.API/Program.cs
git checkout -- CALConsult.TMSBridge.API/appsettings.json
git checkout -- CALConsult.TMSBridge.API/appsettings.Development.json

cd "Code/Disposition-Frontend"
git checkout -- apps/nagel-cal-disposition/environment/environment.ts
```

Verify with `git status` in both repos that working trees are clean.

### 3. Docker Infrastructure (Ask User)

Ask the user whether to:
- **Keep running**: Leave containers for next session (default)
- **Stop**: `cd .claude/skills/local-dev-prepare && docker compose stop` (data preserved, quick restart)
- **Remove everything**: `cd .claude/skills/local-dev-prepare && docker compose down -v` (volumes deleted, full reset)

### 4. Clean Up Log Files

```bash
rm -f /tmp/tms-bridge.log /tmp/new-dispo-backend.log /tmp/new-dispo-frontend.log
rm -f /tmp/tms-bridge.pid /tmp/new-dispo-backend.pid /tmp/new-dispo-frontend.pid
```

### 5. Summary Output

```
Local Dev Environment Torn Down
================================
Services:    ✓ All stopped
TMS Bridge:  ✓ Git changes reverted
Frontend:    ✓ Git changes reverted
Docker:      [kept running | stopped | removed]
Logs:        ✓ Cleaned up

To set up again: /local-dev-prepare or /local-dev-setup
```
