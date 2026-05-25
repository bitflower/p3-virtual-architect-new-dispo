# Local Development Setup — New Dispo Stack

Run the TMS Bridge, Backend, and Frontend locally with a Docker-based PostgreSQL and Keycloak.

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Docker Desktop | any | `docker info` |
| .NET 8 SDK | 8.x | `dotnet --version` |
| Node.js | 20.x | `node --version` |
| VPN | connected | Required for TMS Bridge database and TOP Service |

All repositories must be cloned under `Code/` (see main `CLAUDE.md` for the full list).

## Quick Start

### Using Claude Code Skills

```
/local-dev-setup        # Prepare + start everything
/local-dev-prepare      # Prepare only (Docker, config, migrations)
/local-dev-start        # Start services only (after prepare)
/local-dev-teardown     # Stop services, revert code changes, optionally remove Docker
```

### Manual Setup

#### 1. Start Infrastructure

```bash
cd .claude/skills/local-dev-prepare
docker compose up -d
```

This starts:
- **PostgreSQL 16** on `localhost:5432`
- **Keycloak 25** on `localhost:8080`

#### 2. Configure Keycloak

```bash
.claude/skills/local-dev-prepare/keycloak-init.sh
```

Creates the required clients and a test user (idempotent — safe to re-run).

#### 3. Apply TMS Bridge Local Tweaks

The TMS Bridge requires four changes to run locally without Google Secret Manager and with local Keycloak:

```bash
cd Code/Disposition-Abstraction-Layer
```

**a)** Comment out Secret Manager in `CALConsult.TMSBridge.API/Program.cs`:
```csharp
// builder.AddOwnGoogleSecretsManagerConfiguration(projId, credentialPath);
```

**b)** Replace connection strings in `CALConsult.TMSBridge.API/appsettings.json` and `appsettings.Development.json`:
```json
"ConnectionStrings": {
    "D-10-34": "Host=10.100.4.16;Port=5432;Database=ent1034;Username=tms1034;Password=eB5Soo9ua6oosi_e;"
}
```

**c)** Point Keycloak to local instance in `appsettings.Development.json` — **critical**, without this tokens from local Keycloak are rejected:
```json
"ServerUrl": "http://localhost:8080",
```

**d)** In the same file, set:
```json
"RequireHttpsMetadata": false
```

#### 4. Apply Frontend Local Tweak

Point Keycloak to the local instance in `Code/Disposition-Frontend/apps/nagel-cal-disposition/environment/environment.ts`:
```typescript
url: 'http://localhost:8080',
```

#### 5. Run Backend Migrations

```bash
cd Code/Disposition-Backend
ASPNETCORE_ENVIRONMENT=Local dotnet ef database update --project CALConsult.Disposition.API
```

Alternatively, migrations apply automatically when the Backend starts with the `Local` profile.

#### 6. Install Frontend Dependencies

```bash
cd Code/Disposition-Frontend
npm install
```

#### 7. Start Services

```bash
# Terminal 1 — TMS Bridge
cd Code/Disposition-Abstraction-Layer
dotnet run --project CALConsult.TMSBridge.API

# Terminal 2 — Backend
cd Code/Disposition-Backend
ASPNETCORE_ENVIRONMENT=Local dotnet run --project CALConsult.Disposition.API

# Terminal 3 — Frontend
cd Code/Disposition-Frontend
npm run cal:start
```

#### 8. Seed Data (Requires All Services Running)

Once the TMS Bridge, Backend, and Frontend are running, initialize the local database with legs and lots from the TMS database. This fetches shipments from all TMS branches, extracts legs, and generates lots.

First, get a token from local Keycloak:

```bash
TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=test&grant_type=password&client_id=client-test" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

Then trigger the initialization for a specific branch:

```bash
curl -X POST "http://localhost:5101/api/pickup-planning-view" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Database-Identifier: D-10-34" \
  -H "Content-Type: application/json"
```

Expected response:
```json
[{"BranchKey":"D-10-34","Status":"Completed","Errors":[]}]
```

This creates ~3,300 legs and ~190 lots for branch D-10-34. The operation is tracked in `initialize_pickup_planning_state` and won't duplicate data on re-run.

To seed additional branches, change the `Database-Identifier` header (requires matching connection strings in the TMS Bridge config).

## Service URLs

| Service | URL | Notes |
|---------|-----|-------|
| Frontend | http://localhost:4200 | Angular dev server |
| Backend (Swagger) | http://localhost:5101/swagger | API documentation |
| TMS Bridge (GraphQL) | http://localhost:5158/bridge/ | GraphQL playground at `/playground` |
| Keycloak Admin | http://localhost:8080/admin/master/console/ | Realm configuration |
| PostgreSQL | localhost:5432 | Database: `cal-new-dispo` |

## Credentials

### Keycloak Admin

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `admin` |
| Console | http://localhost:8080/admin/master/console/ |

### Keycloak Test User

| Field | Value |
|-------|-------|
| Username | `testuser` |
| Password | `test` |
| Email | test@local.dev |
| Roles | `manage-account-links`, `manage-account`, `view-profile` |

Use this account to log in to the Frontend.

### PostgreSQL

| Field | Value |
|-------|-------|
| Host | localhost |
| Port | 5432 |
| Database | cal-new-dispo |
| Username | `postgres` |
| Password | `postgres` |

### TMS Database (via VPN)

| Field | Value |
|-------|-------|
| Host | 10.100.4.16 |
| Port | 5432 |
| Database | ent1034 |
| Username | `tms1034` |
| Password | `eB5Soo9ua6oosi_e` |
| Identifier | D-10-34 |

## Keycloak Clients

| Client ID | Type | Used By |
|-----------|------|---------|
| `client-test` | Public | Frontend (browser login) |
| `client-credentials-test` | Confidential (secret: `test-secret`) | Backend (service-to-service) |
| `tms-cloud-service` | Bearer-only | TMS Bridge (audience validation) |
| `ebv-client` | Bearer-only | TMS Bridge (audience validation) |

## Authorization Model

The security model is authentication-only — no role-based access control in the Backend or TMS Bridge.

- **Backend**: `[Authorize]` on all endpoints. Extracts `sub` (user ID) and `name` claims from the JWT.
- **TMS Bridge**: `[Authorize]` on all GraphQL queries and mutations. No claims inspection.
- **Frontend**: Route guard checks for the `manage-account-links` client role (built-in Keycloak `account` client role). Redirects to `/unauthorized` if missing.

## External Dependencies

| Service | Local | Remote (via VPN) | Required For |
|---------|-------|-----------------|--------------|
| PostgreSQL | Docker (localhost:5432) | — | Backend database |
| Keycloak | Docker (localhost:8080) | — | Authentication |
| TMS Database | — | 10.100.4.16:5432 | TMS Bridge data |
| TOP Service | not available | development-top.cal-consult.int | Route calculation |
| XServer | not available | 10.32.3.102:30000 | Route calculation |

**TOP Service** is a .NET Framework 4.6 application and cannot run on macOS. Use the dev instance over VPN. Route calculation is only needed when testing tour optimization features.

## Reverting Local Changes

The TMS Bridge and Frontend tweaks are uncommitted git changes. To revert:

```bash
# TMS Bridge
cd Code/Disposition-Abstraction-Layer
git checkout -- CALConsult.TMSBridge.API/Program.cs
git checkout -- CALConsult.TMSBridge.API/appsettings.json
git checkout -- CALConsult.TMSBridge.API/appsettings.Development.json

# Frontend
cd Code/Disposition-Frontend
git checkout -- apps/nagel-cal-disposition/environment/environment.ts
```

Or use the `/local-dev-teardown` skill.

## Docker Management

```bash
cd .claude/skills/local-dev-prepare

docker compose up -d       # Start containers
docker compose stop        # Stop (preserve data)
docker compose start       # Restart stopped containers
docker compose down        # Remove containers (preserve volume)
docker compose down -v     # Remove containers AND data
docker compose logs -f     # Follow logs
```

## Troubleshooting

**Port already in use (5101, 5158, 4200)**
```bash
lsof -ti:5101 | xargs kill   # Backend
lsof -ti:5158 | xargs kill   # TMS Bridge
lsof -ti:4200 | xargs kill   # Frontend
```

**TMS Bridge fails to connect to database**
- Check VPN connection. The TMS database at `10.100.4.16` is only reachable via VPN.

**Backend migration fails**
- Ensure PostgreSQL container is running: `docker ps --filter name=new-dispo-postgres`
- Check connection: `docker exec new-dispo-postgres pg_isready -U postgres`

**Keycloak login redirect fails in Frontend**
- Verify `environment.ts` points to `http://localhost:8080` (not the dev instance).
- Check Keycloak is running: `curl -s http://localhost:8080/realms/master | head -1`

**"Invalid token" or 401 errors**
- Ensure the Backend and TMS Bridge both point to the same Keycloak instance as the Frontend.
- Backend `appsettings.Local.json` uses `http://localhost:8080` by default.
- TMS Bridge `appsettings.json` uses `http://localhost:8080` by default.

## Files

| File | Purpose |
|------|---------|
| `.claude/skills/local-dev-prepare/docker-compose.yml` | PostgreSQL + Keycloak containers |
| `.claude/skills/local-dev-prepare/keycloak-init.sh` | Keycloak client + user seeding |
| `.claude/skills/local-dev-prepare/SKILL.md` | Claude Code prepare skill definition |
| `.claude/skills/local-dev-start/SKILL.md` | Claude Code start skill definition |
| `.claude/skills/local-dev-setup/SKILL.md` | Claude Code combined skill definition |
| `.claude/skills/local-dev-teardown/SKILL.md` | Claude Code teardown skill definition |
