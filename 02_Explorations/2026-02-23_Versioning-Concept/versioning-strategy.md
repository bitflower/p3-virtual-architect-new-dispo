# Versioning Strategy - No Manual Bumping Required

## Problem Statement

With ~10 deployments/day to TEST environment, manual version bumping in `.csproj` or `package.json` is not feasible.

## Solution: Environment-Based Versioning

Use different versioning strategies based on environment:

| Environment | Version Source | Example | Manual Effort |
|-------------|---------------|---------|---------------|
| **TEST (T-T)** | Azure DevOps build number | `20260223.5` | Zero |
| **Staging** | Azure DevOps build number | `20260223.12` | Zero |
| **PROD (P-P)** | Semantic version from `.csproj` or `package.json` | `2.2.0` | Once per release |

## Azure DevOps Build Numbers

Azure DevOps automatically provides `BUILD_BUILDNUMBER` environment variable:

**Format:** `yyyyMMdd.revision`
- Date: `20260223` (February 23, 2026)
- Revision: Increments per build on that date (`1`, `2`, `3`, ...)
- Example: `20260223.5` = 5th build on February 23, 2026

**Characteristics:**
- Unique per pipeline run
- Monotonically increasing within a day
- Human-readable (includes date)
- Zero configuration required

## Implementation

### Backend/TMS Bridge (.NET)

```bash
#!/bin/bash
# Automatic versioning based on branch

BUILD_NUMBER=${BUILD_BUILDNUMBER:-"local"}
BRANCH=${BUILD_SOURCEBRANCHNAME:-$(git branch --show-current)}

# Production branch: Use .csproj version (manually set for releases)
# Other branches: Use build number (fully automatic)
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
  VERSION=$(grep -oP '<Version>\K[^<]+' Project.csproj 2>/dev/null || echo "$BUILD_NUMBER")
else
  VERSION="$BUILD_NUMBER"
fi

cat > wwwroot/version.json <<EOF
{
  "component": "backend",
  "version": "$VERSION",
  "commit": "$(git rev-parse HEAD)",
  "commitShort": "$(git rev-parse --short HEAD)",
  "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "$BRANCH",
  "buildNumber": "$BUILD_NUMBER"
}
EOF
```

### Frontend (Angular)

```bash
#!/bin/bash
# Automatic versioning based on branch

BUILD_NUMBER=${BUILD_BUILDNUMBER:-"local"}
BRANCH=${BUILD_SOURCEBRANCHNAME:-$(git branch --show-current)}

# Production branch: Use package.json version (manually set for releases)
# Other branches: Use build number (fully automatic)
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
  VERSION=$(cat package.json | jq -r '.version')
else
  VERSION="$BUILD_NUMBER"
fi

cat > src/assets/component-version.json <<EOF
{
  "component": "frontend",
  "version": "$VERSION",
  "commit": "$(git rev-parse HEAD)",
  "commitShort": "$(git rev-parse --short HEAD)",
  "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "branch": "$BRANCH",
  "buildNumber": "$BUILD_NUMBER"
}
EOF
```

## Example Outputs

### TEST Environment (Branch: develop)
```json
{
  "component": "backend",
  "version": "20260223.5",
  "commit": "abc123def456789",
  "commitShort": "abc123d",
  "buildDate": "2026-02-23T10:30:00Z",
  "branch": "develop",
  "buildNumber": "20260223.5"
}
```

### PROD Environment (Branch: main)
```json
{
  "component": "backend",
  "version": "2.2.0",
  "commit": "xyz789abc123456",
  "commitShort": "xyz789a",
  "buildDate": "2026-02-23T15:00:00Z",
  "branch": "main",
  "buildNumber": "20260223.15"
}
```

## Deployment Scenarios

### Scenario 1: TEST - Multiple Deployments Same Day
```
09:00 - Deploy to TEST → version: 20260223.1
10:30 - Deploy to TEST → version: 20260223.2
11:45 - Deploy to TEST → version: 20260223.3
14:00 - Deploy to TEST → version: 20260223.4
...
```
All automatic. No human intervention.

### Scenario 2: PROD Release
```
1. Update .csproj: <Version>2.3.0</Version>
2. Commit to main branch
3. Deploy to PROD → version: 2.3.0
```
Manual version bump only once per release.

## Benefits

| Aspect | Benefit |
|--------|---------|
| **TEST deployments** | Zero manual work, always unique |
| **PROD releases** | Semantic versioning for communication |
| **Commit tracking** | Always included for precise identification |
| **Build traceability** | Build number always included |
| **Debugging** | Can identify exact build from any environment |

## Alternative: Commit SHA Only

If even simpler approach is preferred:

```bash
VERSION=$(git rev-parse --short HEAD)
# Example: "abc123d"
```

**Pros:**
- Absolutely zero manual work
- Works identically in all environments
- Directly maps to Git history

**Cons:**
- Less human-friendly (no date info)
- Harder to communicate to non-technical users

**Recommendation:** Use build numbers - they're automatic AND human-friendly.

## Customization Options

### Option 1: Customize Build Number Format
In Azure Pipeline YAML:
```yaml
name: $(Date:yyyyMMdd)$(Rev:.r)-$(SourceBranchName)
# Example: 20260223.5-develop
```

### Option 2: Semantic Version with Auto-Increment
Use GitVersion or similar:
```yaml
- task: gitversion/setup@0
- task: gitversion/execute@0
# Automatically calculates next version based on Git history
```

### Option 3: Hybrid Approach
```bash
# Format: semantic.buildnumber
# Example: 2.2.20260223.5
SEMANTIC_VERSION=$(grep -oP '<Version>\K[^<]+' Project.csproj)
VERSION="$SEMANTIC_VERSION.${BUILD_BUILDNUMBER}"
```

## Recommendation

**Start with:** Azure DevOps build numbers for TEST/Staging, semantic versions for PROD.

**Why:**
- Zero effort for frequent TEST deployments
- Professional semantic versions for PROD communication
- Easy to implement
- Easy to understand
- Can evolve if needed

## Important: No Commits to Repository (But History is Preserved)

**The version.json file is generated during the pipeline build and is NOT committed back to the repository.**

```
Pipeline Flow:
1. Git checkout code
2. Pipeline runs generate-version.sh script
3. Script creates version.json in build workspace
4. version.json included in Docker image build
5. Docker image pushed to Artifact Registry
6. Deploy to Cloud Run

→ No git commit to main codebase
→ Clean Git history with only real code changes
```

**Why no commits to main codebase:**
- No "version bump" commits cluttering Git history
- No circular trigger issues (commit → pipeline → commit → pipeline)
- No merge conflicts on version files
- Git history stays clean with only real code changes

**But historical tracking IS preserved via:**

### Option A: Archive to Cloud Storage (Recommended for TEST)
```yaml
# In azure-pipelines-cloudrun-t-t.yml after generating version.json
- task: CmdLine@2
  displayName: 'Archive version.json for history'
  inputs:
    script: |
      # Archive to Cloud Storage bucket
      TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S")
      gsutil cp wwwroot/version.json \
        gs://newdispo-version-history/t-t/backend/${TIMESTAMP}_version.json
```

**Retrieval for bug reports:**
```bash
# User reports bug with version 20260223.5
# Find the archived version
gsutil ls gs://newdispo-version-history/t-t/backend/ | grep "20260223"
gsutil cp gs://newdispo-version-history/t-t/backend/2026-02-23_10-30-15_version.json ./

# Shows:
# {
#   "version": "20260223.5",
#   "commit": "abc123def",
#   "buildDate": "2026-02-23T10:30:15Z"
# }

# Now you can checkout that exact commit:
git checkout abc123def
```

### Option B: Git Tags in Deployment History Repo
```yaml
# After deployment succeeds
- task: CmdLine@2
  displayName: 'Tag deployment with version info'
  inputs:
    script: |
      # Clone deployment-history repo (separate from main codebase)
      git clone https://deployment-history-repo.git
      cd deployment-history

      # Store version.json
      mkdir -p t-t/backend/2026-02-23
      cp ../wwwroot/version.json t-t/backend/2026-02-23/10-30-15_version.json

      git add .
      git commit -m "Backend TEST deployment: 20260223.5"
      git tag t-t/backend/20260223.5
      git push --all
      git push --tags
```

### Option C: Query Docker Images (Always Available)
```bash
# User reports bug with version 20260223.5
# Extract version.json from old Docker image

# Find image by date/time
gcloud artifacts docker images list \
  europe-west3-docker.pkg.dev/.../backend \
  --filter="createTime>2026-02-23T09:00:00" \
  --filter="createTime<2026-02-23T11:00:00"

# Pull and extract version.json
docker pull europe-west3-docker.pkg.dev/.../backend:sha-abc123
docker run --rm europe-west3-docker.pkg.dev/.../backend:sha-abc123 \
  cat /app/wwwroot/version.json
```

## Recommended Approach for TEST

Use **Cloud Storage archiving** (Option A):

**Pros:**
- Simple one-line gsutil command
- Fast retrieval
- No separate Git repo needed
- Storage cost negligible (~€0.01/year for 10,000 versions)
- No Docker image pulling required

**Implementation:**
```yaml
# Add to all three pipelines after version.json generation
- script: |
    TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S")
    VERSION=$(cat wwwroot/version.json | jq -r '.version')
    gsutil cp wwwroot/version.json \
      gs://newdispo-version-history/$(ENVIRONMENT)/$(COMPONENT)/${TIMESTAMP}_${VERSION}.json
  displayName: 'Archive version for history'
```

**The .gitignore in main repos should include:**
```gitignore
# Auto-generated version files - do NOT commit to main codebase
version.json
wwwroot/version.json
**/assets/version.json
```

## Bug Report Workflow

**User reports:** "I found a bug in version 20260223.5"

**Support process:**
```bash
# 1. Find the archived version
gsutil ls gs://newdispo-version-history/t-t/backend/ | grep "20260223.5"
# Returns: 2026-02-23_10-30-15_20260223.5.json

# 2. Download it
gsutil cp gs://newdispo-version-history/t-t/backend/2026-02-23_10-30-15_20260223.5.json ./

# 3. Read commit hash
cat 2026-02-23_10-30-15_20260223.5.json
# Shows: "commit": "abc123def456"

# 4. Checkout exact code
git checkout abc123def456

# 5. Reproduce bug with exact code state
```

**Total time: ~30 seconds**

## No Manual Bumping Required ✓

The versioning strategy is fully automated for TEST/Staging environments where you deploy frequently. Manual semantic versioning only needed for PROD releases where you want meaningful version numbers for communication.
