# Pragmatic Versioning Solution - GROUNDED IN ACTUAL STACK

## Your Actual Tech Stack

Based on the codebases in this folder:

| Component | Technology | Deployment | CI/CD | Artifact |
|-----------|-----------|------------|-------|----------|
| **Frontend** | Angular 19 + NX → Nginx | Docker → Cloud Run | Azure Pipelines | `europe-west3-docker.pkg.dev/.../frontend` |
| **Backend** | .NET 8.0 (ASP.NET Core) | Docker → Cloud Run | Azure Pipelines | `europe-west3-docker.pkg.dev/.../backend` |
| **TMS Bridge** | .NET 8.0 (ASP.NET Core) | Docker → Cloud Run | Azure Pipelines | `europe-west3-docker.pkg.dev/.../tms-bridge` |

**Environments:**
- TEST (T-T): `https://test.dispo.gcp.nagel-group.com`
- PROD (P-P): Production environment
- Staging: `https://nagel-staging.ddns.net:8081`

## Pragmatic Versioning Implementation (Grounded)

### 1. Generate version.json in Each Component

#### Frontend (Angular/NX)
**File:** `Disposition-Frontend/scripts/generate-version.sh`

```bash
#!/bin/bash
# Generate version.json for Frontend

# Automated versioning - no manual bumping required
BUILD_NUMBER=${BUILD_BUILDNUMBER:-"local"}
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BRANCH=${BUILD_SOURCEBRANCHNAME:-$(git branch --show-current 2>/dev/null || echo "unknown")}

# Version strategy based on branch
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
  # Production: Use package.json version
  VERSION=$(cat package.json | jq -r '.version // "0.0.0"')
else
  # TEST/DEV: Use build number
  VERSION="$BUILD_NUMBER"
fi

mkdir -p apps/nagel-cal-disposition/src/assets

cat > apps/nagel-cal-disposition/src/assets/component-version.json <<EOF
{
  "component": "frontend",
  "version": "$VERSION",
  "commit": "$COMMIT",
  "commitShort": "$COMMIT_SHORT",
  "buildDate": "$BUILD_DATE",
  "branch": "$BRANCH",
  "buildNumber": "$BUILD_NUMBER"
}
EOF

echo "Generated component-version.json"
cat apps/nagel-cal-disposition/src/assets/component-version.json
```

**Add to `azure-pipelines-cloudrun-t-t.yml`:**

```yaml
# After npm install, before build
- task: CmdLine@2
  displayName: 'Generate version.json'
  inputs:
    script: |
      chmod +x scripts/generate-version.sh
      ./scripts/generate-version.sh
```

**Result:** `version.json` included in Angular build → Nginx serves it at `/assets/component-version.json`

**Important:** Add to `.gitignore`:
```gitignore
# Auto-generated version files - do NOT commit
**/version.json
**/component-version.json
```

#### Backend (.NET)
**File:** `Disposition-Backend/scripts/generate-version.sh`

```bash
#!/bin/bash
# Generate version.json for Backend

# Automated versioning - no manual bumping required
# Use Azure DevOps build number or commit SHA
BUILD_NUMBER=${BUILD_BUILDNUMBER:-"local"}
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BRANCH=${BUILD_SOURCEBRANCHNAME:-$(git branch --show-current 2>/dev/null || echo "unknown")}

# Version strategy based on branch
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
  # Production: Use semantic version from .csproj if exists, otherwise build number
  VERSION=$(grep -oP '<Version>\K[^<]+' CALConsult.Disposition.API/CALConsult.Disposition.API.csproj 2>/dev/null || echo "$BUILD_NUMBER")
else
  # TEST/DEV: Use build number for automatic versioning
  VERSION="$BUILD_NUMBER"
fi

cat > CALConsult.Disposition.API/wwwroot/version.json <<EOF
{
  "component": "backend",
  "version": "$VERSION",
  "commit": "$COMMIT",
  "commitShort": "$COMMIT_SHORT",
  "buildDate": "$BUILD_DATE",
  "branch": "$BRANCH",
  "buildNumber": "$BUILD_NUMBER"
}
EOF

echo "Generated version.json"
cat CALConsult.Disposition.API/wwwroot/version.json
```

**No manual version bumping required.** Azure DevOps automatically provides unique build numbers (e.g., `20260223.1`, `20260223.2`, etc.).

**Add to `azure-pipelines-cloudrun-t-t.yml`:**

```yaml
# After config replacements, before Docker build
- task: CmdLine@2
  displayName: 'Generate version.json'
  inputs:
    script: |
      chmod +x scripts/generate-version.sh
      ./scripts/generate-version.sh

# After successful deployment
- task: CmdLine@2
  displayName: 'Tag deployment with version'
  condition: succeeded()
  inputs:
    script: |
      COMPONENT="backend"
      COMMIT=$(git rev-parse HEAD)
      VERSION=$(cat CALConsult.Disposition.API/wwwroot/version.json | jq -r '.version')

      # Determine environment from branch
      if [[ "$BUILD_SOURCEBRANCHNAME" == "main" ]] || [[ "$BUILD_SOURCEBRANCHNAME" == "master" ]]; then
        ENV="p-p"
      else
        ENV="t-t"
      fi

      TAG="${ENV}/${COMPONENT}/${VERSION}"

      git config user.email "azure-pipelines@calconsult.com"
      git config user.name "Azure Pipelines"

      git tag -a "$TAG" -m "Deployment
Environment: ${ENV}
Component: ${COMPONENT}
Version: ${VERSION}
Commit: ${COMMIT}
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Build ID: ${BUILD_BUILDID}"

      git push origin "$TAG"
```

**Ensure `wwwroot/version.json` is copied in build:**

Check `CALConsult.Disposition.API.csproj` has:
```xml
<ItemGroup>
  <Content Include="wwwroot\**" CopyToOutputDirectory="PreserveNewest" />
</ItemGroup>
```

**Serve via ASP.NET Core static files (already configured):**
```csharp
// In Program.cs or Startup.cs
app.UseStaticFiles(); // This already serves wwwroot/version.json
```

**Important:** Add to `.gitignore`:
```gitignore
# Auto-generated version files - do NOT commit
**/wwwroot/version.json
```

**Accessible at:** `https://test.dispo.gcp.nagel-group.com/version.json`

#### TMS Bridge (.NET)
**File:** `Disposition-Abstraction-Layer/scripts/generate-version.sh`

```bash
#!/bin/bash
# Generate version.json for TMS Bridge

# Automated versioning - no manual bumping required
BUILD_NUMBER=${BUILD_BUILDNUMBER:-"local"}
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BRANCH=${BUILD_SOURCEBRANCHNAME:-$(git branch --show-current 2>/dev/null || echo "unknown")}

# Version strategy based on branch
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
  VERSION=$(grep -oP '<Version>\K[^<]+' CALConsult.TMSBridge.API/CALConsult.TMSBridge.API.csproj 2>/dev/null || echo "$BUILD_NUMBER")
else
  VERSION="$BUILD_NUMBER"
fi

mkdir -p CALConsult.TMSBridge.API/wwwroot

cat > CALConsult.TMSBridge.API/wwwroot/version.json <<EOF
{
  "component": "tmsBridge",
  "version": "$VERSION",
  "commit": "$COMMIT",
  "commitShort": "$COMMIT_SHORT",
  "buildDate": "$BUILD_DATE",
  "branch": "$BRANCH",
  "buildNumber": "$BUILD_NUMBER"
}
EOF

echo "Generated version.json"
cat CALConsult.TMSBridge.API/wwwroot/version.json
```

**Add to `azure-pipelines-cloudrun-t-t.yml`:**

```yaml
- task: CmdLine@2
  displayName: 'Generate version.json'
  inputs:
    script: |
      chmod +x scripts/generate-version.sh
      ./scripts/generate-version.sh

# After successful deployment
- task: CmdLine@2
  displayName: 'Tag deployment with version'
  condition: succeeded()
  inputs:
    script: |
      COMPONENT="tms-bridge"
      COMMIT=$(git rev-parse HEAD)
      VERSION=$(cat CALConsult.TMSBridge.API/wwwroot/version.json | jq -r '.version')

      if [[ "$BUILD_SOURCEBRANCHNAME" == "main" ]] || [[ "$BUILD_SOURCEBRANCHNAME" == "master" ]]; then
        ENV="p-p"
      else
        ENV="t-t"
      fi

      TAG="${ENV}/${COMPONENT}/${VERSION}"

      git config user.email "azure-pipelines@calconsult.com"
      git config user.name "Azure Pipelines"

      git tag -a "$TAG" -m "Deployment
Environment: ${ENV}
Component: ${COMPONENT}
Version: ${VERSION}
Commit: ${COMMIT}
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Build ID: ${BUILD_BUILDID}"

      git push origin "$TAG"
```

**Important:** Add to `.gitignore`:
```gitignore
# Auto-generated version files - do NOT commit
**/wwwroot/version.json
```

**Accessible at:** `https://test.tms-bridge.gcp.nagel-group.com/version.json`

---

### 2. Display Version in Frontend (Optional)

**Note:** We're simplifying to NOT aggregate versions. Each component serves only its own version.

If you want to display version in the UI:

**File:** `Disposition-Frontend/scripts/aggregate-versions.sh`

```bash
#!/bin/bash
# Aggregate versions from all deployed components

ENVIRONMENT="${1:-test}"
NEW_DISPO_VERSION="2.2.0"  # Update this manually or from a VERSION file

# Determine URLs based on environment
if [ "$ENVIRONMENT" == "test" ] || [ "$ENVIRONMENT" == "t-t" ]; then
    BACKEND_URL="https://test.dispo.gcp.nagel-group.com/version.json"
    TMS_BRIDGE_URL="https://test.tms-bridge.gcp.nagel-group.com/version.json"
elif [ "$ENVIRONMENT" == "prod" ] || [ "$ENVIRONMENT" == "p-p" ]; then
    BACKEND_URL="https://prod.dispo.gcp.nagel-group.com/version.json"
    TMS_BRIDGE_URL="https://prod.tms-bridge.gcp.nagel-group.com/version.json"
else
    BACKEND_URL="https://nagel-staging.ddns.net:8081/version.json"
    TMS_BRIDGE_URL="https://nagel-staging.ddns.net:8081/tms-bridge/version.json"
fi

# Fetch component versions (with timeout and fallback)
BACKEND_VERSION=$(curl -sf --max-time 5 "$BACKEND_URL" || echo '{"error":"unavailable"}')
TMS_BRIDGE_VERSION=$(curl -sf --max-time 5 "$TMS_BRIDGE_URL" || echo '{"error":"unavailable"}')

# Read frontend component version
FRONTEND_VERSION=$(cat apps/nagel-cal-disposition/src/assets/component-version.json)

# Generate aggregated version
mkdir -p apps/nagel-cal-disposition/src/assets

cat > apps/nagel-cal-disposition/src/assets/version.json <<EOF
{
  "newDispo": "$NEW_DISPO_VERSION",
  "generated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "environment": "$ENVIRONMENT",
  "components": {
    "frontend": $FRONTEND_VERSION,
    "backend": $BACKEND_VERSION,
    "tmsBridge": $TMS_BRIDGE_VERSION,
    "tmsDatabase": {
      "version": "7.0.0.81",
      "note": "Manual tracking - see https://github.com/cal-consult/tms-alloydb-schema/releases"
    }
  }
}
EOF

echo "Generated aggregated version.json"
cat apps/nagel-cal-disposition/src/assets/version.json
```

**Update `azure-pipelines-cloudrun-t-t.yml`:**

```yaml
# Replace the version generation step with:
- task: CmdLine@2
  displayName: 'Generate component version'
  inputs:
    script: |
      chmod +x scripts/generate-version.sh
      ./scripts/generate-version.sh

- script: |
    npm run cal:build-production
  displayName: 'build frontend'

# After successful deployment
- task: CmdLine@2
  displayName: 'Tag deployment with version'
  condition: succeeded()
  inputs:
    script: |
      COMPONENT="frontend"
      COMMIT=$(git rev-parse HEAD)
      VERSION=$(cat apps/nagel-cal-disposition/src/assets/component-version.json | jq -r '.version')

      if [[ "$BUILD_SOURCEBRANCHNAME" == "main" ]] || [[ "$BUILD_SOURCEBRANCHNAME" == "master" ]]; then
        ENV="p-p"
      else
        ENV="t-t"
      fi

      TAG="${ENV}/${COMPONENT}/${VERSION}"

      git config user.email "azure-pipelines@calconsult.com"
      git config user.name "Azure Pipelines"

      git tag -a "$TAG" -m "Deployment
Environment: ${ENV}
Component: ${COMPONENT}
Version: ${VERSION}
Commit: ${COMMIT}
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Build ID: ${BUILD_BUILDID}"

      git push origin "$TAG"
```

**Note:** Removed aggregation - each component only tracks its own version.

**Result:** Aggregated `version.json` at `https://test.dispo.gcp.nagel-group.com/assets/version.json`

---

### 3. Display Version in Angular Frontend

**Simplified component (shows only Frontend version):**

```typescript
import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';

interface ComponentVersion {
  component: string;
  version: string;
  commit: string;
  commitShort: string;
  buildDate: string;
  branch: string;
}

@Component({
  selector: 'app-version-info',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="version-info" *ngIf="version">
      Version: {{ version.version }}
      <span class="commit">({{ version.commitShort }})</span>
    </div>
  `,
  styles: [`
    .version-info {
      font-size: 0.85rem;
      color: #666;
    }
    .commit {
      font-family: monospace;
      margin-left: 0.5rem;
    }
  `]
})
export class VersionInfoComponent implements OnInit {
  version: ComponentVersion | null = null;

  constructor(private http: HttpClient) {}

  ngOnInit() {
    this.http.get<ComponentVersion>('/assets/component-version.json')
      .subscribe({
        next: (data) => this.version = data,
        error: (err) => console.error('Failed to load version', err)
      });
  }
}
```

---

### 4. Historical Tracking via Git Tags

**Pipeline automatically tags each deployment (see steps above in each component).**

**Setup: Grant pipeline push permissions (one-time):**

Option A - In pipeline YAML:
```yaml
resources:
  repositories:
  - repository: self
    persistCredentials: true
```

Option B - Azure DevOps Project Settings:
1. Go to Project Settings → Repositories → [Your Repo] → Security
2. Find "Build Service" account
3. Grant "Contribute" and "Create tag" permissions

**Git tag structure:**
```
Git Tags:
  t-t/backend/20260223.1
  t-t/backend/20260223.2
  t-t/backend/20260223.3
  t-t/frontend/20260223.1
  t-t/frontend/20260223.2
  t-t/tms-bridge/20260223.1
  p-p/backend/2.2.0
  p-p/frontend/2.2.0
  p-p/tms-bridge/2.2.0
```

**Retrieve historical versions for bug reports:**
```bash
# User reports bug with version 20260223.2

# Checkout exact code state
git checkout t-t/backend/20260223.2

# Or get commit hash
git rev-list -n 1 t-t/backend/20260223.2

# List all deployments today
git tag -l "t-t/backend/20260223.*"

# Show tag details (includes all metadata)
git show t-t/backend/20260223.2
```

**Tag cleanup (optional - after 90 days):**
```bash
# List old tags
git tag -l "t-t/*" --sort=-creatordate | tail -n +1000

# Delete old TEST tags (keep PROD tags forever)
git tag -l "t-t/*" | head -n -100 | xargs -I {} git push --delete origin {}
```

**Cost:** €0 - Git tags are free

---

## Operational Simplification

**No aggregation needed.** Each component:
- Generates its own version.json
- Serves it at runtime
- Tags deployment in Git

**For bug reports:**
- User reports Frontend version from UI
- Support checks Git tags for exact commits of all components at that time
- No staleness issues
- No coordination between pipelines

---

## Implementation Plan (Grounded)

### Phase 1: Manual Validation (Week 1)

**Day 1-2: Backend**
1. Create `Disposition-Backend/scripts/generate-version.sh`
2. Add `<Version>2.2.0</Version>` to `CALConsult.Disposition.API.csproj`
3. Manually run script and verify `wwwroot/version.json` exists
4. Test locally: `curl http://localhost:5101/version.json`

**Day 3-4: TMS Bridge**
1. Create `Disposition-Abstraction-Layer/scripts/generate-version.sh`
2. Add `<Version>2.2.0</Version>` to `CALConsult.TMSBridge.API.csproj`
3. Test locally: `curl http://localhost:7153/version.json`

**Day 5: Frontend**
1. Create `Disposition-Frontend/scripts/generate-version.sh`
2. Create `Disposition-Frontend/scripts/aggregate-versions.sh`
3. Manually run both scripts
4. Verify `apps/nagel-cal-disposition/src/assets/version.json` exists
5. Run `npm run cal:build-dev` and check `dist/apps/nagel-cal-disposition/assets/version.json`

**Test with mock bug report:**
- User reports issue with version "2.2.0"
- Support accesses `/assets/version.json`
- Can identify exact commit of each component
- **Decision point:** Is this useful?

### Phase 2: Automate in Pipelines (Week 2)

**Backend Pipeline:**
1. Add script to `azure-pipelines-cloudrun-t-t.yml`
2. Trigger deployment
3. Verify: `curl https://test.dispo.gcp.nagel-group.com/version.json`

**TMS Bridge Pipeline:**
1. Add script to `azure-pipelines-cloudrun-t-t.yml`
2. Trigger deployment
3. Verify: `curl https://test.tms-bridge.gcp.nagel-group.com/version.json`

**Frontend Pipeline:**
1. Add both scripts to `azure-pipelines-cloudrun-t-t.yml`
2. Trigger deployment
3. Verify: `curl https://test.dispo.gcp.nagel-group.com/assets/version.json`

### Phase 3: UI Component (Week 3)

1. Create `VersionInfoComponent` in Frontend
2. Add to footer or settings page
3. Deploy and test in TEST environment
4. Gather feedback from team

### Phase 4: Historical Tracking (Optional)

1. Add Git tagging to Frontend pipeline
2. Test retrieval of historical versions
3. Document process for team

---

## Storage Locations (Actual)

| Phase | Location | Example |
|-------|----------|---------|
| **Build** | Azure Pipeline workspace | `/home/vsts/work/1/s/version.json` |
| **Docker Image** | Artifact Registry | `europe-west3-docker.pkg.dev/.../backend:sha123` |
| **Runtime (Backend)** | Cloud Run container | `/app/wwwroot/version.json` |
| **Runtime (Frontend)** | Cloud Run container (Nginx) | `/usr/share/nginx/html/assets/version.json` |
| **Live Access** | HTTPS endpoint | `https://test.dispo.gcp.nagel-group.com/assets/version.json` |
| **Historical** | Git tags + committed files | `deployment-history/version-2026-02-23T10-35-00Z.json` |

---

## Key Differences from Generic Proposal

| Generic Proposal | Your Actual Stack |
|------------------|-------------------|
| Node.js/Express backend | ✅ .NET 8.0 (ASP.NET Core) |
| Generic CI/CD examples | ✅ Azure DevOps Pipelines |
| Cloud Build scripts | ✅ Azure Pipeline YAML |
| `package.json` versions | ✅ `.csproj <Version>` tags for .NET |
| GCS static hosting | ✅ Docker + Nginx on Cloud Run |
| Generic bash scripts | ✅ Scripts compatible with Azure Pipelines Ubuntu agents |

---

## Cost Analysis (Grounded)

**Current Infrastructure:**
- 3 Cloud Run services (already running)
- GCP Artifact Registry (already in use)
- Azure DevOps Pipelines (already in use)

**Additional Cost:**
- **€0** - No new infrastructure
- Negligible increase in Docker image size (~1KB per version.json)
- Negligible increase in pipeline runtime (~10 seconds per build)

**Compared to Runtime PoC:**
- Saves: New Cloud Run service + Database + Cloud Functions
- Saves: ~€75/month infrastructure
- Saves: ~50 hours development time

---

## Next Steps

1. **Review with team** - Does this match your current processes?
2. **Phase 1 validation** - Manual implementation in one component
3. **Test with real bug report** - Does it provide value?
4. **Decide on automation** - If valuable, proceed to Phase 2

---

## Versioning Strategy

**Automated versioning - no manual bumping, no commits to repo:**

The version.json files are generated during the Azure Pipeline build and included in Docker images. **They are NOT committed back to the repository.**

```
Pipeline Flow:
1. Checkout code from Git
2. Run generate-version.sh (creates version.json in workspace)
3. Include version.json in Docker build
4. Push Docker image to Artifact Registry
5. Deploy to Cloud Run

→ No git commits
→ No changes pushed to repo
→ Clean Git history
```

**Versioning approach:**

| Environment | Version Source | Example | Manual Work |
|-------------|---------------|---------|-------------|
| **TEST (T-T)** | Azure DevOps build number | `20260223.5` | None - fully automatic |
| **Staging** | Azure DevOps build number | `20260223.12` | None - fully automatic |
| **PROD (P-P)** | `.csproj <Version>` or `package.json` | `2.2.0` | Only for PROD releases |

**Why this works:**
- TEST with 10 deployments/day: Each gets unique build number automatically
- PROD releases: Manually set semantic version before release
- Commit SHA always included for precise identification
- Build number always included as fallback

**Azure DevOps provides `BUILD_BUILDNUMBER` automatically:**
- Format: `yyyyMMdd.revision` (e.g., `20260223.5`)
- Unique per pipeline run
- No configuration needed

## Questions for Team

1. Should we include EF migration version from `CALConsult.Disposition.API` migrations?
2. Who should have permissions to push Git tags from Azure Pipelines?
3. Do you want versioning in Staging environment or only TEST and PROD?
4. **Is aggregated version staleness acceptable during validation, or do you need it always current?**
   - If acceptable: Use Option A (simplest)
   - If not acceptable: Plan for Option B (lightweight update job)
5. For PROD releases: Do you want to use `.csproj <Version>` tags or Git release tags?
