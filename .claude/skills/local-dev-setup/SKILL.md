---
name: local-dev-setup
description: Full local development setup. Runs prepare (Docker PostgreSQL, TMS Bridge tweaks, build) then starts all services. Use when the user wants the complete local dev experience in one command.
allowed-tools: Bash,Read,Edit,Write
---

# Local Dev Setup Skill (Combined)

One-command setup that prepares the environment and starts all services.

## When to Use

- User asks to "set up local dev", "get everything running locally", "local dev setup"
- When the user wants both preparation and service startup in one go

## How It Works

This skill combines two other skills in sequence:

### Step 1: Prepare

Execute everything described in the `/local-dev-prepare` skill:
1. Check prerequisites (Docker, .NET 8, Node.js 20)
2. Start PostgreSQL Docker container (`new-dispo-postgres`)
3. Apply TMS Bridge local tweaks (comment out SecretManager, set connection strings, disable HTTPS metadata)
4. Build the Backend
5. Install Frontend dependencies

### Step 2: Start

Execute everything described in the `/local-dev-start` skill:
1. Verify infrastructure is ready
2. Start TMS Bridge (background, log to `/tmp/tms-bridge.log`)
3. Start Backend with `ASPNETCORE_ENVIRONMENT=Local` (background, log to `/tmp/new-dispo-backend.log`)
4. Start Frontend (background, log to `/tmp/new-dispo-frontend.log`)
5. Run health checks

### Step 3: Summary

Print combined status:

```
Local Dev Environment Ready
============================
Infrastructure:
  PostgreSQL:  ✓ localhost:5432 (Docker: new-dispo-postgres, DB: cal-new-dispo)
  Keycloak:    → https://dev.new-dispo.nagel.p3ds.net/keycloak/ (shared dev)

Services:
  TMS Bridge:  ✓ http://localhost:5158/bridge/     (PID: XXXX)
  Backend:     ✓ http://localhost:5101/swagger      (PID: XXXX)
  Frontend:    ✓ http://localhost:4200              (PID: XXXX)

Logs:
  tail -f /tmp/tms-bridge.log
  tail -f /tmp/new-dispo-backend.log
  tail -f /tmp/new-dispo-frontend.log

To stop everything: /local-dev-teardown
```

## Notes

- If `/local-dev-prepare` has already been run (PostgreSQL running, tweaks applied), it will skip those steps.
- The Backend auto-applies EF Core migrations at startup against the Docker PostgreSQL.
- VPN/network access is required for the TMS Bridge to reach the dev database at `10.100.4.16`.
