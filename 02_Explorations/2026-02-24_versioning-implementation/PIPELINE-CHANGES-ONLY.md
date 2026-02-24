# Azure Pipeline Changes - Version System Integration

This document shows **ONLY the additions** needed to integrate versioning into your existing Azure pipelines. Keep your current pipeline structure and add these steps.

**Approach**: Uses reusable bash scripts (stored in `system-manifest` repo) to avoid pipeline code duplication.

---

## Prerequisites

1. Create and push the `system-manifest` repository with scripts (see `REUSABLE-SCRIPTS.md`)
2. Grant pipeline write access to `system-manifest` repository
3. Add pipeline variable:
   - `MANIFEST_REPO_URL` - URL to system-manifest repository

---

## Part 1: Backend Pipeline Changes

**File**: `Code/Disposition-Backend/azure-pipelines-cloudrun-t-t.yml`

### A. Add Variables (at the top, after existing variables)

```yaml
variables:
  # ... your existing variables ...

  # ADD THESE:
  - name: ComponentName
    value: 'disposition-backend'
  - name: ManifestRepoUrl
    value: 'https://$(System.AccessToken)@dev.azure.com/your-org/your-project/_git/system-manifest'
```

### B. Download Scripts from system-manifest (add early in pipeline, before build)

```yaml
# ADD THIS STEP - Download versioning scripts from system-manifest repo
- task: Bash@3
  displayName: 'Download versioning scripts'
  inputs:
    targetType: 'inline'
    script: |
      git clone --depth 1 $(ManifestRepoUrl) /tmp/manifest
      chmod +x /tmp/manifest/scripts/*.sh
      ls -la /tmp/manifest/scripts/
  env:
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

### C. Extract Version (simple script call)

```yaml
# ADD THIS STEP - Extract version using script
- task: Bash@3
  displayName: 'Extract version'
  name: version
  inputs:
    targetType: 'inline'
    script: |
      /tmp/manifest/scripts/extract-version.sh
  env:
    VERSION_MODE: auto-build  # or 'tag' for manual tags
    BUILD_NUMBER: $(Build.BuildNumber)
    SOURCE_BRANCH: $(Build.SourceBranch)
```

### D. Modify Docker Build Step (add labels to existing Docker task)

Find your existing Docker build task (around line 194) and **ADD** the `arguments` parameter:

```yaml
- task: Docker@2
  condition: and(succeeded(),eq(variables['Build.SourceBranch'], 'refs/heads/master'))
  displayName: 'Build and push image'
  inputs:
    Dockerfile: 'Dockerfile.cloudrun-t-t'
    command: buildAndPush
    repository: '$(DockerImageName)'
    tags: |
        $(Build.BuildNumber)
        $(version.VERSION)          # ADD THIS
    arguments: |                     # ADD ENTIRE arguments BLOCK
      --label "com.calconsult.component.name=$(ComponentName)"
      --label "com.calconsult.component.version=$(version.VERSION)"
      --label "com.calconsult.git.commit=$(version.COMMIT)"
      --label "com.calconsult.git.repo=Disposition-Backend"
      --label "com.calconsult.build.date=$(Build.BuildNumber)"
```

### E. Bump System Version (simple script call)

```yaml
# ADD THIS STEP - Bump system version using script
- task: Bash@3
  displayName: 'Bump system version'
  name: systemversion
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/master'))
  inputs:
    targetType: 'inline'
    script: |
      /tmp/manifest/scripts/bump-system-version.sh \
        "$(ComponentName)" \
        "$(version.VERSION)" \
        "$(version.COMMIT)"
  env:
    MANIFEST_REPO_URL: $(ManifestRepoUrl)
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

### F. Tag Component Repo (simple script call)

```yaml
# ADD THIS STEP - Tag component repo using script
- task: Bash@3
  displayName: 'Tag component repo'
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/master'))
  inputs:
    targetType: 'inline'
    script: |
      /tmp/manifest/scripts/tag-component-repo.sh \
        "$(systemversion.SYSTEM_VERSION)" \
        "$(version.VERSION)"
  env:
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

### G. Re-tag Docker Image (simple script call)

```yaml
# ADD THIS STEP - Re-tag Docker image using script
- task: Bash@3
  displayName: 'Tag Docker image with system version'
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/master'))
  inputs:
    targetType: 'inline'
    script: |
      /tmp/manifest/scripts/tag-docker-image.sh \
        "$(DockerImageName)" \
        "$(version.VERSION)" \
        "$(systemversion.SYSTEM_VERSION)"
```

### H. Log Release Info (optional)

```yaml
# ADD THIS STEP - Log release information
- task: Bash@3
  displayName: 'Log release info'
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/master'))
  inputs:
    targetType: 'inline'
    script: |
      echo "========================================="
      echo "Release Complete!"
      echo "========================================="
      echo "Component: $(ComponentName)"
      echo "Component Version: $(version.VERSION)"
      echo "System Version: $(systemversion.SYSTEM_VERSION)"
      echo "Git Commit: $(version.COMMIT)"
      echo "Docker Image: $(DockerImageName):$(version.VERSION)"
      echo "Docker Image (System): $(DockerImageName):system-v$(systemversion.SYSTEM_VERSION)"
      echo "========================================="
```

---

## Part 2: TMS Bridge Pipeline Changes

**File**: `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-t-t-wl5.yml`

Apply the **same changes as Backend**, but with:

```yaml
variables:
  - name: ComponentName
    value: 'tms-bridge'  # Different name
```

And in Docker labels:
```yaml
--label "com.calconsult.git.repo=Disposition-Abstraction-Layer"
```

---

## Part 3: Frontend Pipeline Changes

**File**: `Code/Disposition-Frontend/azure-pipelines-*.yml`

### Same changes as Backend, PLUS add manifest injection for deployment:

Add **AFTER** the system version bump:

```yaml
# ADD THIS STEP - Fetch current manifest for frontend injection
- task: Bash@3
  displayName: 'Fetch system manifest for frontend'
  name: manifest
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/master'))
  inputs:
    targetType: 'inline'
    script: |
      set -e

      git clone --depth 1 $(ManifestRepoUrl) /tmp/manifest
      MANIFEST_JSON=$(cat /tmp/manifest/versions.json | jq -c '.components')

      echo "Manifest: $MANIFEST_JSON"
      echo "##vso[task.setvariable variable=MANIFEST_JSON;isOutput=true]$MANIFEST_JSON"

      rm -rf /tmp/manifest
  env:
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

Update Cloud Run deployment to include environment variables:

```yaml
# MODIFY your existing gcloud run deploy command:
gcloud run deploy your-frontend-service \
  --image=$(YourFrontendImage):$(versionmeta.VERSION) \
  --region=europe-west3 \
  --set-env-vars="COMPONENT_NAME=disposition-frontend,COMPONENT_VERSION=$(versionmeta.VERSION),SYSTEM_VERSION=$(systemversion.SYSTEM_VERSION),GIT_COMMIT=$(versionmeta.COMMIT),SHOW_VERSION_PANEL=true,COMPONENT_MANIFEST=$(manifest.MANIFEST_JSON)"
```

---

## Part 4: Dockerfile Changes

### Backend & TMS Bridge Dockerfiles

**No changes needed** to Dockerfiles. Labels are added via build arguments in the pipeline.

### Frontend Dockerfile

**File**: `Code/Disposition-Frontend/Dockerfile`

**REPLACE** the existing Dockerfile with this version that adds runtime config:

```dockerfile
### stage 1 - compile ###
FROM node:20.15.1 AS builder
LABEL authors="Nikolay Hristov <nikolay.hristov@p3-group.com>"

WORKDIR /build
COPY . .
RUN npm ci && npm run cal:build-production

### stage 2 - serve with nginx ###
FROM nginx:alpine

# Copy built app
COPY --from=builder /build/dist/apps/nagel-cal-disposition/ /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

# ADD THIS: Create placeholder config.json
RUN mkdir -p /usr/share/nginx/html/assets && \
    echo '{"systemVersion":"dev","componentVersion":"dev","gitCommit":"local","showVersionPanel":"false","components":{},"services":{}}' \
    > /usr/share/nginx/html/assets/config.json

# ADD THIS: Create entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8081

# CHANGE THIS: Use entrypoint instead of direct CMD
ENTRYPOINT ["/docker-entrypoint.sh"]
```

**Create new file**: `Code/Disposition-Frontend/docker-entrypoint.sh`

```bash
#!/bin/sh
# Runtime configuration injection for Angular frontend

cat > /usr/share/nginx/html/assets/config.json <<EOF
{
  "systemVersion": "${SYSTEM_VERSION:-unknown}",
  "componentVersion": "${COMPONENT_VERSION:-unknown}",
  "gitCommit": "${GIT_COMMIT:-unknown}",
  "showVersionPanel": "${SHOW_VERSION_PANEL:-false}",
  "components": ${COMPONENT_MANIFEST:-"{}"},
  "services": {
    "backend": "${BACKEND_URL:-/api}",
    "tms-bridge": "${TMS_BRIDGE_URL:-/bridge}"
  }
}
EOF

exec nginx -g 'daemon off;'
```

Make it executable:
```bash
chmod +x Code/Disposition-Frontend/docker-entrypoint.sh
```

---

## Summary of Changes Per Component

### Disposition-Backend
- ✅ Add 2 variables (ComponentName, ManifestRepoUrl)
- ✅ Add 1 step: Download scripts from system-manifest
- ✅ Add 5 simple steps: Extract version, bump system version, tag repo, tag Docker, log
- ✅ Modify Docker build (add labels)
- **Total: ~30 lines of simple YAML** (no complex logic)

### TMS-Bridge
- ✅ Same as Backend (different component name variable)

### Disposition-Frontend
- ✅ Same as Backend PLUS
- ✅ Add docker-entrypoint.sh
- ✅ Modify Dockerfile
- ✅ Add manifest fetch step (1 extra script call)
- ✅ Modify deployment with env vars

---

## Testing the Changes

### Test Backend Release:

```bash
cd Code/Disposition-Backend
git tag v1.0.0
git push origin v1.0.0

# Watch Azure Pipeline
# Should see: System version bumped to v1
```

### Test TMS Bridge Release:

```bash
cd Code/Disposition-Abstraction-Layer
git tag v1.0.0
git push origin v1.0.0

# Should see: System version bumped to v2
```

### Verify System Manifest:

```bash
cd system-manifest
git log --oneline
# Should show:
# abc123 v2: tms-bridge → 1.0.0
# def456 v1: disposition-backend → 1.0.0

git show system-v2:versions.json
# Should show both components
```

---

## Rollback Plan

If something goes wrong:

1. **Pipelines still work** - new steps only run on `refs/heads/master` branch
2. **Docker images unaffected** - labels are metadata only
3. **Can disable**: Comment out the new steps with `#`
4. **Old tags remain** - component version tags (v1.0.0) still work

---

## Benefits of Script-Based Approach

✅ **No pipeline code duplication** - Logic in system-manifest repo
✅ **Unit tested** - Scripts tested before pipeline use
✅ **Easy to maintain** - Update once, affects all pipelines
✅ **Clear and simple** - Each step is one script call
✅ **Testable locally** - Run scripts on your machine before commit
✅ **One repo for versioning** - Scripts and data together

See `REUSABLE-SCRIPTS.md` for complete script implementations.

---

## Next: Add Version Endpoints & Frontend Panel

Once pipelines are working, continue with:
- Add `/api/version` endpoints to Backend & TMS Bridge (see `BACKEND-VERSION-ENDPOINT.md`)
- Add Angular ConfigService and Version Panel (see `FRONTEND-VERSION-PANEL.md`)
