# Answers to Team Questions - Pragmatic Versioning Approach

**Date:** 2026-02-23
**From:** Solution Architect
**Re:** Versioning Concept - Pragmatic Alternative to Runtime PoC

## Direct Answers to Questions

### 1. How is the proposed versioning maintained?
**Automatically by Azure DevOps Pipelines. Zero manual work.**

Each component's pipeline generates a `version.json` during build:

```json
{
  "component": "backend",
  "version": "20260223.5",
  "commit": "abc123def456",
  "commitShort": "abc123d",
  "buildDate": "2026-02-23T10:30:00Z",
  "branch": "develop",
  "buildNumber": "20260223.5"
}
```

The file is included in the Docker image and served via HTTP at runtime.

### 2. For which environment should we have it?
**All environments: TEST (T-T), PROD (P-P), and Staging.**

Each component serves its version at:
- Backend TEST: `https://test.dispo.gcp.nagel-group.com/version.json`
- Backend PROD: `https://prod.dispo.gcp.nagel-group.com/version.json`
- TMS Bridge TEST: `https://test.tms-bridge.gcp.nagel-group.com/version.json`
- Frontend TEST (component): `https://test.dispo.gcp.nagel-group.com/assets/component-version.json`
- Frontend TEST (aggregated): `https://test.dispo.gcp.nagel-group.com/assets/version.json`

### 3. When is it maintained (with ~10 deployments/day)?
**Every deployment automatically generates version.json and creates a Git tag.**

Each component deployment:
1. Generates `version.json` during build
2. Includes it in Docker image
3. Deploys to Cloud Run
4. Creates Git tag: `t-t/backend/20260223.5`

No coordination between components. Each tracks itself independently.

### 4. Who is maintaining/updating it?
**Azure DevOps Pipelines. Zero manual version bumping.**

| Environment | Version Source | Example | Manual Work |
|-------------|---------------|---------|-------------|
| **TEST (T-T)** | Azure DevOps build number | `20260223.5` | None |
| **Staging** | Azure DevOps build number | `20260223.12` | None |
| **PROD (P-P)** | `.csproj` or `package.json` | `2.2.0` | Once per release |

Azure DevOps provides `BUILD_BUILDNUMBER` automatically (format: `yyyyMMdd.revision`). Each build gets a unique number. TEST with 10 deployments/day: all automatically versioned.

The version.json file is generated during the pipeline build and included in the Docker image. It is NOT committed to the repository. Only Git tags are created.

### 5. Where would this versioning be stored?

| Phase | Location | Example |
|-------|----------|---------|
| **Build** | Azure Pipeline workspace | `/home/vsts/work/1/s/wwwroot/version.json` |
| **Docker image** | GCP Artifact Registry | `europe-west3-docker.pkg.dev/.../backend:sha123` |
| **Runtime** | Cloud Run container | `/app/wwwroot/version.json` |
| **Live access** | HTTPS endpoint | `https://test.dispo.gcp.nagel-group.com/version.json` |
| **Historical** | Git tags | `t-t/backend/20260223.5` |

### 6. How will we resolve particular version in the PAST?
**Git tags provide complete version history. Zero cost.**

```bash
# User reports: "Bug in version 20260223.5"

# Checkout exact code state
git checkout t-t/backend/20260223.5

# List all deployments today
git tag -l "t-t/backend/20260223.*"

# Show tag metadata
git show t-t/backend/20260223.5
# Shows: Environment, Component, Version, Commit, Build Date, Build ID
```

**Git tag structure:**
```
t-t/backend/20260223.1
t-t/backend/20260223.2
t-t/backend/20260223.5
t-t/frontend/20260223.3
t-t/tms-bridge/20260223.1
p-p/backend/2.2.0
p-p/frontend/2.2.0
```

**Setup:** Grant Azure Pipeline push permissions via project settings or pipeline YAML.

### 7. How does this keep pipelines decoupled?
**Pipelines remain independent. Frontend optionally aggregates by fetching from deployed services.**

Each pipeline:
- Generates its own version.json
- Deploys independently
- Creates its own Git tag
- No inter-service triggers
- No shared state during build

**Frontend aggregation (optional):**

Frontend can fetch versions from deployed services during its build to create an aggregated view:

```yaml
# In Frontend pipeline, before build
- script: |
    # Fetch from deployed services
    curl -sf --max-time 5 https://test.dispo.gcp.nagel-group.com/version.json > backend-version.json || echo '{"error":"unavailable"}' > backend-version.json
    curl -sf --max-time 5 https://test.tms-bridge.gcp.nagel-group.com/version.json > tmsbridge-version.json || echo '{"error":"unavailable"}' > tmsbridge-version.json

    # Create aggregated version.json
    SYSTEM_VERSION=$(git tag -l "system/t-t/$(date +%Y%m%d).*" | sort -V | tail -1 | grep -oP 'system/t-t/\K.*' || echo "unknown")

    cat > src/assets/version.json <<EOF
    {
      "systemVersion": "$SYSTEM_VERSION",
      "frontend": $(cat src/assets/component-version.json),
      "backend": $(cat backend-version.json),
      "tmsBridge": $(cat tmsbridge-version.json),
      "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
    EOF
  displayName: 'Aggregate versions'
```

**Result:** Frontend serves aggregated view at `/assets/version.json`

**Decoupling maintained:**
- Backend doesn't know Frontend fetched its version
- Fetch happens during Frontend build (read-only HTTP GET)
- If service unavailable, marks as "unavailable" and continues
- No pipeline triggers between services

**Staleness consideration:** Aggregated view reflects component versions at time of Frontend build. For exact state, use Git tags.

### 8. How is the "system version" bumped and managed?
**Use timestamp-based system version. No coordination needed between repos.**

Since you have 3 separate repos with no shared registry, use deployment timestamp as system version.

**System version = timestamp of deployment:**
```
Format: yyyyMMdd.HHmm
Example: 20260223.1430 (Feb 23, 2026 at 14:30)
```

**Each component's pipeline creates system tag in Frontend repo:**

```yaml
# In Backend pipeline (after component tagging)
- task: CmdLine@2
  displayName: 'Tag system version in Frontend repo'
  inputs:
    script: |
      # Clone Frontend repo
      git clone https://$(System.AccessToken)@dev.azure.com/org/project/_git/Disposition-Frontend /tmp/frontend-repo
      cd /tmp/frontend-repo

      # System version = current timestamp
      SYSTEM_VERSION=$(date +%Y%m%d.%H%M)
      ENV=$([[ "$BUILD_SOURCEBRANCHNAME" == "main" ]] && echo "p-p" || echo "t-t")

      # Tag with deployment metadata
      git tag -a "system/${ENV}/${SYSTEM_VERSION}" -m "System deployment
Environment: ${ENV}
System Version: ${SYSTEM_VERSION}
Triggered by: backend
Component Version: $(cat ../CALConsult.Disposition.API/wwwroot/version.json | jq -r '.version')
Component Commit: $(git -C .. rev-parse HEAD)
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Build ID: ${BUILD_BUILDID}"

      git push origin "system/${ENV}/${SYSTEM_VERSION}"
```

**Why Frontend repo for system tags?**
- Users interact with Frontend, natural place for system version
- Avoids creating additional repo
- Frontend can read its own tags to display system version

**Git tag structure in Frontend repo:**
```
# Component tags (Frontend's own deployments)
t-t/frontend/20260223.1
t-t/frontend/20260223.2
t-t/frontend/20260223.3

# System tags (any component deployment)
system/t-t/20260223.0915   (Backend deployed at 09:15)
system/t-t/20260223.1030   (Frontend deployed at 10:30)
system/t-t/20260223.1145   (Backend deployed at 11:45)
system/t-t/20260223.1400   (TMS Bridge deployed at 14:00)
```

**User-facing system version:**

Frontend displays: "New Dispo System v20260223.1400"

**Bug report workflow:**
```bash
# User: "Bug in system version 20260223.1400"

# In Frontend repo, find what deployed at 14:00
git show system/t-t/20260223.1400
# Shows:
# Triggered by: tms-bridge
# Component Version: 20260223.4
# Component Commit: abc123

# Reconstruct system state at 14:00
# Find latest component deployment BEFORE 14:00

# Backend - last before 14:00
git tag -l "t-t/backend/20260223.*" --sort=-version:refname | while read tag; do
  TIME=$(echo $tag | grep -oP '\d{4}$')
  [[ $TIME -le 1400 ]] && echo $tag && break
done
# Or check Backend repo: git tag -l "t-t/backend/20260223.*"

# Frontend - last before 14:00
# Check: t-t/frontend/20260223.2 (deployed at 10:30)

# TMS Bridge - the one that triggered system v14:00
# Check: t-t/tms-bridge/20260223.4 (deployed at 14:00)
```

**Benefits:**
- ✅ Single system version users can report
- ✅ Auto-increments (timestamp naturally increases)
- ✅ No coordination between repos needed
- ✅ No race conditions
- ✅ Zero cost (Git tags)
- ✅ Frontend repo is natural home for system tags

**For PROD:**
System version uses semantic format manually: `system/p-p/2.2.0`

## Why Not the Runtime PoC?

The runtime PoC requires:
- New Version Management Service
- Cloud Functions per service
- Database for version storage
- Additional infrastructure to maintain

We have zero versioning today and a small stack (3 components). Validate that versioning helps bug reporting before investing in runtime infrastructure.

## Pragmatic Alternative Summary

**What:** Git tags for version tracking. Each component serves its own version.json.

**Technology:**
- Bash scripts in Azure Pipelines
- Git tags for history
- ASP.NET Core static files (Backend/TMS Bridge)
- Nginx static files (Frontend)
- Docker + Cloud Run

**Infrastructure:** None - just Azure Pipeline YAML modifications and bash scripts.

**Timeline:** 8-10 days vs 40-60 days for runtime service.

**Risk:** Minimal. Easy to implement, debug, and remove if needed.

## Validation Phase

1. **Week 1:** Manual implementation - add bash scripts, generate version files locally, test with bug reports
2. **Week 2:** Automate - add to Azure Pipeline YAML, deploy to TEST, verify endpoints
3. **Week 3:** Evaluate - assess if it helps support process

## Tech Stack

- **Backend**: .NET 8.0 → Docker → Cloud Run
- **TMS Bridge**: .NET 8.0 → Docker → Cloud Run
- **Frontend**: Angular 19 + NX → Nginx → Docker → Cloud Run
- **CI/CD**: Azure DevOps Pipelines
- **Registry**: GCP Artifact Registry
- **Environments**: TEST (T-T), PROD (P-P), Staging

## Recommendation

Start with Git tags approach. Prove the concept works. Evolve if needed.

---

**See full implementation:**
- `IMPLEMENTATION.md` - Quick start guide with scripts and pipeline examples
- `pragmatic-proposal-GROUNDED.md` - Complete implementation details
- `git-based-versioning.md` - Analysis of Git tags approach
- `comparison.md` - Static vs runtime comparison
