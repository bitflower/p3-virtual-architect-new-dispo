# Versioning Implementation - Quick Start

## Solution Overview

**Git tags for version tracking. Zero infrastructure cost. No manual bumping.**

Each component:
1. Generates `version.json` during build (Azure Pipeline)
2. Includes it in Docker image
3. Serves at runtime
4. Tags deployment in Git automatically

## Implementation

### 1. Backend

**Script:** `Disposition-Backend/scripts/generate-version.sh`
```bash
#!/bin/bash
BUILD_NUMBER=${BUILD_BUILDNUMBER:-"local"}
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BRANCH=${BUILD_SOURCEBRANCHNAME:-$(git branch --show-current 2>/dev/null || echo "unknown")}

if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
  VERSION=$(grep -oP '<Version>\K[^<]+' CALConsult.Disposition.API/CALConsult.Disposition.API.csproj 2>/dev/null || echo "$BUILD_NUMBER")
else
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
```

**Pipeline:** Add to `azure-pipelines-cloudrun-t-t.yml`
```yaml
- task: CmdLine@2
  displayName: 'Generate version.json'
  inputs:
    script: |
      chmod +x scripts/generate-version.sh
      ./scripts/generate-version.sh

# ... Docker build steps ...

- task: CmdLine@2
  displayName: 'Tag deployment'
  condition: succeeded()
  inputs:
    script: |
      COMPONENT="backend"
      VERSION=$(cat CALConsult.Disposition.API/wwwroot/version.json | jq -r '.version')
      ENV=$([[ "$BUILD_SOURCEBRANCHNAME" == "main" ]] && echo "p-p" || echo "t-t")
      TAG="${ENV}/${COMPONENT}/${VERSION}"

      git config user.email "azure-pipelines@calconsult.com"
      git config user.name "Azure Pipelines"
      git tag -a "$TAG" -m "Deployment: ${ENV}/${COMPONENT}/${VERSION}"
      git push origin "$TAG"
```

**.gitignore:** Add `**/wwwroot/version.json`

### 2. TMS Bridge

Same as Backend, adjust paths:
- Script: `Disposition-Abstraction-Layer/scripts/generate-version.sh`
- Component: `"tms-bridge"`
- Path: `CALConsult.TMSBridge.API/wwwroot/version.json`

### 3. Frontend

**Script:** `Disposition-Frontend/scripts/generate-version.sh`
```bash
#!/bin/bash
BUILD_NUMBER=${BUILD_BUILDNUMBER:-"local"}
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BRANCH=${BUILD_SOURCEBRANCHNAME:-$(git branch --show-current 2>/dev/null || echo "unknown")}

if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
  VERSION=$(cat package.json | jq -r '.version // "0.0.0"')
else
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
```

**Pipeline:** Add to `azure-pipelines-cloudrun-t-t.yml`
```yaml
- task: CmdLine@2
  displayName: 'Generate version.json'
  inputs:
    script: |
      chmod +x scripts/generate-version.sh
      ./scripts/generate-version.sh

- script: npm run cal:build-production
  displayName: 'build frontend'

# ... Docker build and deployment ...

- task: CmdLine@2
  displayName: 'Tag deployment'
  condition: succeeded()
  inputs:
    script: |
      COMPONENT="frontend"
      VERSION=$(cat apps/nagel-cal-disposition/src/assets/component-version.json | jq -r '.version')
      ENV=$([[ "$BUILD_SOURCEBRANCHNAME" == "main" ]] && echo "p-p" || echo "t-t")
      TAG="${ENV}/${COMPONENT}/${VERSION}"

      git config user.email "azure-pipelines@calconsult.com"
      git config user.name "Azure Pipelines"
      git tag -a "$TAG" -m "Deployment: ${ENV}/${COMPONENT}/${VERSION}"
      git push origin "$TAG"
```

**.gitignore:** Add `**/component-version.json`

### 4. Grant Git Push Permissions

**Option A:** Pipeline YAML
```yaml
resources:
  repositories:
  - repository: self
    persistCredentials: true
```

**Option B:** Azure DevOps UI
- Project Settings → Repositories → [Repo] → Security
- Find "Build Service" account
- Grant "Contribute" and "Create tag" permissions

## Bug Report Workflow

```bash
# User: "Bug in version 20260223.5"

# Checkout exact code
git checkout t-t/backend/20260223.5

# List all TEST deployments today
git tag -l "t-t/*/20260223.*"

# Show tag metadata
git show t-t/backend/20260223.5
```

## Versioning Strategy

| Environment | Version Format | Example | Manual Work |
|-------------|---------------|---------|-------------|
| TEST | Build number | `20260223.5` | None |
| Staging | Build number | `20260223.12` | None |
| PROD | Semantic | `2.2.0` | Once per release |

## Optional: UI Display

```typescript
// Disposition-Frontend/apps/.../version-info.component.ts
@Component({
  selector: 'app-version-info',
  template: `
    <div *ngIf="version">
      Version: {{ version.version }} ({{ version.commitShort }})
    </div>
  `
})
export class VersionInfoComponent {
  version: any;

  ngOnInit() {
    this.http.get('/assets/component-version.json')
      .subscribe(data => this.version = data);
  }
}
```

## Summary

- ✅ No manual version bumping
- ✅ No commits to repo (only Git tags)
- ✅ No external dependencies (Cloud Storage, etc.)
- ✅ Git tags provide complete history
- ✅ Zero infrastructure cost
- ✅ Simple bug report workflow
