---
name: local-dev-prepare
description: Prepare the local development environment. Starts PostgreSQL + Keycloak via Docker Compose, configures Keycloak clients, applies TMS Bridge local tweaks, and runs Backend migrations. Use when the user wants to set up local dev, prepare for local development, or initialize the local stack.
allowed-tools: Bash,Read,Edit,Write
---

# Local Dev Prepare Skill

Prepares the full local development environment for the New Dispo stack (TMS Bridge + Backend + Frontend).

## When to Use

- User asks to "prepare local dev", "set up local", "initialize local environment"
- Before starting a local development session
- After a fresh clone or environment reset

## What It Does

### 1. Prerequisites Check

Verify the following are available:
- Docker is running (`docker info`)
- .NET 8 SDK installed (`dotnet --version`)
- Node.js 20.x installed (`node --version`)
- Required repos exist under `Code/`

If any prerequisite fails, report it clearly and stop.

### 2. Docker Compose: PostgreSQL + Keycloak

Start infrastructure via Docker Compose:

```bash
SKILL_DIR=".claude/skills/local-dev-prepare"
cd "$SKILL_DIR" && docker compose up -d
```

This starts:
- **PostgreSQL 16** on `localhost:5432` (DB: `cal-new-dispo`, user: `postgres/postgres`)
- **Keycloak 25** on `localhost:8080` (admin: `admin/admin`)

Data is persisted in Docker volume `local-dev-prepare_new-dispo-pgdata`.

If containers already exist:
- If running: skip (report "already running")
- If stopped: `docker compose start`

Wait for both to be healthy before proceeding.

### 3. Configure Keycloak

Run the init script to create clients and test user in the master realm:

```bash
"$SKILL_DIR/keycloak-init.sh"
```

This creates:
- `client-test` — Frontend (public client, redirect to localhost:4200)
- `client-credentials-test` — Backend (confidential, secret: `test-secret`)
- `tms-cloud-service` — TMS Bridge audience (bearer-only)
- `ebv-client` — TMS Bridge audience (bearer-only)
- `testuser` / `test` — Test user for login

The script is idempotent (skips existing resources).

### 4. TMS Bridge Local Tweaks (Git Stash Approach)

The TMS Bridge needs changes to run locally without Google Secret Manager.

**Check first**: Run `git status` in `Code/Disposition-Abstraction-Layer`. If there are already uncommitted changes, warn the user and ask whether to proceed.

If clean, apply these changes:

#### a) Comment out Secret Manager in Program.cs

In `CALConsult.TMSBridge.API/Program.cs`, change:
```csharp
builder.AddOwnGoogleSecretsManagerConfiguration(projId, credentialPath);
```
to:
```csharp
// builder.AddOwnGoogleSecretsManagerConfiguration(projId, credentialPath);
```

#### b) Set connection strings in appsettings.Development.json

Replace the `ConnectionStrings` block:
```json
"ConnectionStrings": {
    "D-10-34": "Host=10.100.4.16;Port=5432;Database=ent1034;Username=tms1034;Password=eB5Soo9ua6oosi_e;"
}
```

#### c) Point Keycloak to local instance in appsettings.Development.json

**CRITICAL**: Without this, the TMS Bridge validates tokens against the remote dev Keycloak while the Backend and Frontend use the local one. Tokens will be rejected with AUTH_NOT_AUTHORIZED.

```json
"ServerUrl": "http://localhost:8080",
```

#### d) Disable HTTPS metadata requirement in appsettings.Development.json

```json
"RequireHttpsMetadata": false
```

#### e) Set connection strings in appsettings.json

Apply the same connection string change as in step b.

### 5. Backend Local Tweaks

#### a) Add D-10-34 branch to appsettings.Local.json

The Backend's `appsettings.Local.json` only ships with `Database3` and `Database4` connection strings. The TMS Bridge is configured with `D-10-34`, so the Backend needs it too — otherwise the branch won't appear in the Frontend dropdown, and GraphQL calls to the TMS Bridge will fail with `Invalid database identifier`.

In `Code/Disposition-Backend/CALConsult.Disposition.API/appsettings.Local.json`, add `D-10-34` to the `ConnectionStrings` block:
```json
"ConnectionStrings": {
    "Database3": "Host=localhost;Port=5432;Database=backend;Username=postgres;Password=postgres;",
    "Database4": "Host=localhost;Port=5432;Database=branch-copy;Username=postgres;Password=postgres;",
    "D-10-34": "Host=10.100.4.16;Port=5432;Database=ent1034;Username=tms1034;Password=eB5Soo9ua6oosi_e;"
}
```

#### b) Apply EF Core migrations

The Backend csproj has `TreatWarningsAsErrors=true` and `EnforceCodeStyleInBuild=true`. Existing code has style violations (IDE0008/IDE0161) that block `dotnet ef`. Work around by building first with overrides, then running migrations with `--no-build`:

```bash
cd Code/Disposition-Backend
dotnet clean CALConsult.Disposition.API -q
ASPNETCORE_ENVIRONMENT=Local dotnet build CALConsult.Disposition.API /p:EnforceCodeStyleInBuild=false /p:AnalysisLevel=none /p:TreatWarningsAsErrors=false -q
ASPNETCORE_ENVIRONMENT=Local dotnet ef database update --project CALConsult.Disposition.API --no-build
```

### 6. Frontend Local Tweaks

#### a) Point Keycloak to local instance

In `Code/Disposition-Frontend/apps/nagel-cal-disposition/environment/environment.ts`, change:
```typescript
url: 'https://dev.new-dispo.nagel.p3ds.net/keycloak',
```
to:
```typescript
url: 'http://localhost:8080',
```

#### b) Install dependencies

```bash
cd Code/Disposition-Frontend
npm install
```

### 7. Summary Output

Print a status table:

```
Local Dev Environment Prepared
==============================
PostgreSQL:   ✓ Running on localhost:5432 (cal-new-dispo)
Keycloak:     ✓ Running on localhost:8080 (admin/admin, testuser/test)
TMS Bridge:   ✓ Local tweaks applied (use /local-dev-teardown to revert)
Backend:      ✓ Migrations applied
Frontend:     ✓ Dependencies installed

Next: Run /local-dev-start to launch all services
      Or start individually:
        TMS Bridge: cd Code/Disposition-Abstraction-Layer && dotnet run --project CALConsult.TMSBridge.API
        Backend:    cd Code/Disposition-Backend && ASPNETCORE_ENVIRONMENT=Local dotnet run --project CALConsult.Disposition.API
        Frontend:   cd Code/Disposition-Frontend && npm run cal:start
```

## Important Notes

- The TMS Bridge connection string `D-10-34` points to the shared dev TMS database at `10.100.4.16`. This requires VPN/network access.
- The Backend `appsettings.Local.json` needs `D-10-34` added to `ConnectionStrings` — without it the branch won't appear in the Frontend and TMS Bridge calls fail.
- The Backend build requires analyzer overrides (`/p:EnforceCodeStyleInBuild=false /p:AnalysisLevel=none /p:TreatWarningsAsErrors=false`) due to pre-existing style violations in the repo.
- The Frontend `environment.ts` Keycloak URL is changed to `http://localhost:8080` during prepare and reverted during teardown (same git checkout approach as TMS Bridge).
- Docker Compose file and Keycloak init script live in `.claude/skills/local-dev-prepare/`.
