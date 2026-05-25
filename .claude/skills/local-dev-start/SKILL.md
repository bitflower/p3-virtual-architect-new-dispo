---
name: local-dev-start
description: Start all local development services (TMS Bridge, Backend, Frontend). Use when the user wants to launch the local stack, start all services, or run the local environment.
allowed-tools: Bash,Read
---

# Local Dev Start Skill

Launches all three New Dispo services for local development.

## When to Use

- User asks to "start local dev", "launch services", "run the stack locally"
- After running `/local-dev-prepare`

## Prerequisites

Before starting, verify:
1. PostgreSQL container `new-dispo-postgres` is running (`docker ps --filter name=new-dispo-postgres`)
2. TMS Bridge local tweaks are applied (check if `Program.cs` has the SecretManager line commented out)

If prerequisites aren't met, suggest running `/local-dev-prepare` first.

## What It Does

### 1. Verify Infrastructure

```bash
docker ps --filter name=new-dispo-postgres --format "{{.Status}}"
```

If not running, offer to start it or suggest `/local-dev-prepare`.

### 2. Start Services

Start each service in a separate background process. Use `nohup` and redirect output to log files.

**IMPORTANT**: Set the working directory correctly for each service using absolute paths from the project root.

#### a) TMS Bridge

```bash
BASE="/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code/Disposition-Abstraction-Layer"
cd "$BASE" && nohup dotnet run --project CALConsult.TMSBridge.API > /tmp/tms-bridge.log 2>&1 &
echo $! > /tmp/tms-bridge.pid
```

Wait ~5 seconds, then check if the process is still running and verify the log shows startup.

#### b) Backend

**IMPORTANT**: The Backend csproj has `TreatWarningsAsErrors=true` and `EnforceCodeStyleInBuild=true`. Pre-existing style violations (IDE0008/IDE0161) block the build unless overridden.

```bash
BASE="/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code/Disposition-Backend"
cd "$BASE" && ASPNETCORE_ENVIRONMENT=Local nohup dotnet run --project CALConsult.Disposition.API /p:EnforceCodeStyleInBuild=false /p:AnalysisLevel=none /p:TreatWarningsAsErrors=false > /tmp/new-dispo-backend.log 2>&1 &
echo $! > /tmp/new-dispo-backend.pid
```

The `ASPNETCORE_ENVIRONMENT=Local` is critical — it:
- Loads `appsettings.Local.json` (local PostgreSQL, local Keycloak, etc.)
- Skips Google Secret Manager
- Auto-applies EF Core migrations against the Docker PostgreSQL

Wait ~10 seconds for migrations to complete, then check the log.

#### c) Frontend

```bash
BASE="/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code/Disposition-Frontend"
cd "$BASE" && nohup npm run cal:start > /tmp/new-dispo-frontend.log 2>&1 &
echo $! > /tmp/new-dispo-frontend.pid
```

Wait ~10 seconds for webpack to compile, then check the log.

### 3. Health Check

After all services are started, verify they're accessible:

```bash
# TMS Bridge GraphQL endpoint
curl -s -o /dev/null -w "%{http_code}" http://localhost:5158/bridge/ || echo "not ready"

# Backend Swagger
curl -s -o /dev/null -w "%{http_code}" http://localhost:5101/swagger/index.html || echo "not ready"

# Frontend
curl -s -o /dev/null -w "%{http_code}" http://localhost:4200 || echo "not ready"
```

Note: Health checks may return auth redirects (302) or similar — that's fine, it means the service is running.

### 4. Summary Output

```
Local Dev Services Started
==========================
TMS Bridge:  ✓ http://localhost:5158/bridge/     (PID: XXXX, log: /tmp/tms-bridge.log)
Backend:     ✓ http://localhost:5101/swagger      (PID: XXXX, log: /tmp/new-dispo-backend.log)
Frontend:    ✓ http://localhost:4200              (PID: XXXX, log: /tmp/new-dispo-frontend.log)

Keycloak:    → http://localhost:8080 (local Docker, admin/admin, testuser/test)
PostgreSQL:  → localhost:5432 (Docker: new-dispo-postgres)

To view logs:
  tail -f /tmp/tms-bridge.log
  tail -f /tmp/new-dispo-backend.log
  tail -f /tmp/new-dispo-frontend.log

To stop: /local-dev-teardown
```

## Troubleshooting

- If Backend fails to start: check `/tmp/new-dispo-backend.log` for migration errors. The PostgreSQL container might need more time to initialize.
- If TMS Bridge fails: verify the `D-10-34` database at `10.100.4.16` is reachable (VPN required).
- If Frontend fails: run `npm install` in `Code/Disposition-Frontend` first.
