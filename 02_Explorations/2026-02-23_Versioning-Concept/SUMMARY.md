# Versioning Solution - Executive Summary

## Storage of version.json

Multiple locations throughout the deployment lifecycle:

### 1. **Generated During Build** (Temporary)
- Azure Pipeline workspace: `/home/vsts/work/1/s/`
- Created by bash script in pipeline
- Included in next steps

### 2. **Baked Into Docker Images** (Permanent)
- Backend: `europe-west3-docker.pkg.dev/.../backend:sha123` → `/app/wwwroot/version.json`
- TMS Bridge: `europe-west3-docker.pkg.dev/.../tms-bridge:sha123` → `/app/wwwroot/version.json`
- Frontend: `europe-west3-docker.pkg.dev/.../frontend:sha123` → `/usr/share/nginx/html/assets/version.json`

### 3. **Served at Runtime** (Live)
- Backend: `https://test.dispo.gcp.nagel-group.com/version.json` (ASP.NET Core static files)
- TMS Bridge: `https://test.tms-bridge.gcp.nagel-group.com/version.json` (ASP.NET Core static files)
- Frontend: `https://test.dispo.gcp.nagel-group.com/assets/version.json` (Nginx static files)

### 4. **Archived for History**
Git tags (automatically created by pipeline):
```
t-t/backend/20260223.5
t-t/frontend/20260223.3
t-t/tms-bridge/20260223.1
```

**Bug reports:** `git checkout t-t/backend/20260223.5` → exact code state.

## Tech Stack

| Component | Technology | Current Deployment |
|-----------|-----------|-------------------|
| Frontend | Angular 19 + NX → Nginx | Docker → Cloud Run |
| Backend | .NET 8.0 (ASP.NET Core) | Docker → Cloud Run |
| TMS Bridge | .NET 8.0 (ASP.NET Core) | Docker → Cloud Run |
| CI/CD | Azure DevOps Pipelines | YAML pipelines |

## Implementation Approach

See **`pragmatic-proposal-GROUNDED.md`** for:
- .NET-specific implementation (reading from `.csproj <Version>`)
- Azure Pipeline YAML examples
- Docker configuration examples
- Actual environment URLs
- Bash scripts for Azure Ubuntu agents

## Documents

| File | Purpose |
|------|---------|
| **pragmatic-proposal-GROUNDED.md** | Complete implementation guide (.NET + Azure + Cloud Run) |
| **storage-details.md** | Detailed storage locations throughout lifecycle |
| **comparison.md** | Compares static vs runtime approaches |
| **01_Communication/2026-02-23_answers-from-architect.md** | Direct answers to team questions |
| **SUMMARY.md** | Executive summary and quick reference |

## Implementation Steps

### Phase 1: Manual Validation (Week 1)
1. Add `generate-version.sh` scripts to each component
2. Test locally: verify version.json is generated
3. Test with mock bug report
4. **Decision:** Is this useful?

### Phase 2: Automation (Week 2)
1. Add scripts to Azure Pipeline YAML files
2. Deploy to TEST environment
3. Verify endpoints work
4. Gather team feedback

### Phase 3: UI & History (Week 3)
1. Create Angular component to display versions
2. Add Git tagging for history (optional)
3. Document for team

## Cost & Risk

| Aspect | Impact |
|--------|--------|
| **New infrastructure** | €0 (uses existing Cloud Run services) |
| **Development time** | 8-10 days vs 40-60 days for runtime PoC |
| **Risk** | Low - static files + Git tags, easy to remove |
| **Maintenance** | Minimal - automated by pipelines |
| **Version bumping** | None - Azure DevOps build numbers used automatically |
| **Commits to repo** | None - only Git tags created |
| **Historical tracking** | Git tags (free, built into Git) |

**Versioning:** TEST uses automatic build numbers (e.g., `20260223.5`). PROD uses semantic versions (e.g., `2.2.0`). No manual bumping for frequent TEST deployments.

**Simplified:** No aggregation needed. Each component tracks its own version via Git tags.

## Recommendation

**Start with pragmatic static approach:**
1. Validates concept immediately
2. No infrastructure investment
3. Can evolve to runtime service if needed
4. Minimal risk and learning overhead

## Next Actions

1. ✅ Review **pragmatic-proposal-GROUNDED.md**
2. ⏳ Decide: proceed with Phase 1 manual validation?
3. ⏳ Answer team questions at end of GROUNDED proposal:
   - Version from `.csproj` or Git tags?
   - Include EF migration versions?
   - Git tag permissions for Azure Pipelines?
   - Staging environment included?
