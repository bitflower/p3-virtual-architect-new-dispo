# Implementation Guide - Complete Step-by-Step

This guide walks through implementing the versioning system from start to finish.

---

## Phase 0: Prerequisites

### Required Access
- [ ] Azure DevOps project access
- [ ] Permissions to create new Git repositories
- [ ] Permissions to modify Azure Pipelines
- [ ] Access to Google Cloud Run deployments

### Required Tools
- [ ] Git CLI
- [ ] Azure CLI (`az`) or Azure DevOps web access
- [ ] jq (for JSON manipulation in scripts)
- [ ] Docker (for local testing)

---

## Phase 1: System-Manifest Repository Setup

**Time Estimate**: 30 minutes

### Step 1.1: Create Repository in Azure DevOps

```bash
# Via Azure CLI
az repos create --name system-manifest --project YourProject --org https://dev.azure.com/your-org

# Or via web UI:
# 1. Go to Azure DevOps → Repos
# 2. Click "New repository"
# 3. Name: "system-manifest"
# 4. Initialize with README: No
```

### Step 1.2: Initialize and Push System-Manifest

```bash
# Use the prepared system-manifest folder
cd /path/to/system-manifest

# Initialize if not already done
git init
git add .
git commit -m "Initial system-manifest setup"

# Add remote and push
git remote add origin https://dev.azure.com/your-org/your-project/_git/system-manifest
git branch -M main
git push -u origin main
```

### Step 1.3: Grant Pipeline Permissions

**Option A: Via Web UI**

1. Go to Azure DevOps → Project Settings
2. Repositories → system-manifest
3. Security → Pipeline permissions
4. Grant permission to all component build pipelines:
   - Disposition-Backend pipeline
   - TMS-Bridge pipeline
   - Disposition-Frontend pipeline

**Option B: Via Service Connection**

Create a PAT (Personal Access Token) with `repo` scope and add to pipeline variables.

### Step 1.4: Verify Repository Access

```bash
# Test that you can clone
git clone https://dev.azure.com/your-org/your-project/_git/system-manifest
cd system-manifest
cat versions.json
```

**Expected Output**:
```json
{
  "system_version": 0,
  "components": { ... }
}
```

---

## Phase 2: Backend Integration (Disposition-Backend)

**Time Estimate**: 1-2 hours

### Step 2.1: Add Version Endpoint

Create `CALConsult.Disposition.API/Controllers/VersionController.cs`:

```csharp
using Microsoft.AspNetCore.Mvc;
using System;

namespace CALConsult.Disposition.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class VersionController : ControllerBase
{
    [HttpGet]
    public IActionResult GetVersion()
    {
        return Ok(new
        {
            component = Environment.GetEnvironmentVariable("COMPONENT_NAME") ?? "disposition-backend",
            version = Environment.GetEnvironmentVariable("COMPONENT_VERSION") ?? "unknown",
            systemVersion = Environment.GetEnvironmentVariable("SYSTEM_VERSION") ?? "unknown",
            gitCommit = Environment.GetEnvironmentVariable("GIT_COMMIT") ?? "unknown",
            timestamp = DateTime.UtcNow
        });
    }
}
```

### Step 2.2: Test Locally

```bash
cd Code/Disposition-Backend

# Set environment variables
export COMPONENT_NAME=disposition-backend
export COMPONENT_VERSION=1.0.0-dev
export SYSTEM_VERSION=0
export GIT_COMMIT=local

# Run
dotnet run --project CALConsult.Disposition.API

# Test endpoint
curl http://localhost:5101/api/version
```

**Expected Response**:
```json
{
  "component": "disposition-backend",
  "version": "1.0.0-dev",
  "systemVersion": "0",
  "gitCommit": "local",
  "timestamp": "2026-02-24T12:00:00Z"
}
```

### Step 2.3: Update Azure Pipeline

Open `azure-pipelines-cloudrun-t-t.yml` and add the changes from `PIPELINE-CHANGES-ONLY.md`:

1. Add variables (ComponentName, ManifestRepoUrl)
2. Add version extraction step
3. Modify Docker build with labels
4. Add system version bump step
5. Add component repo tagging
6. Add Docker re-tagging
7. Add release info logging

### Step 2.4: Commit and Test

```bash
git add .
git commit -m "Add versioning system to backend"
git push origin main

# Test with a tag (create a test release)
git tag v0.1.0-test
git push origin v0.1.0-test
```

Watch the pipeline run. It should:
- ✅ Build successfully
- ✅ Create Docker image with labels
- ✅ Bump system version to v1
- ✅ Tag backend repo with system-v1
- ✅ Push Docker image with both tags

### Step 2.5: Verify System-Manifest Updated

```bash
cd system-manifest
git pull

git log --oneline
# Should show: "v1: disposition-backend → 0.1.0-test"

cat versions.json
```

**Expected**:
```json
{
  "system_version": 1,
  "components": {
    "disposition-backend": "0.1.0-test",
    "tms-bridge": "0.0.0",
    "disposition-frontend": "0.0.0"
  },
  "trigger": {
    "component": "disposition-backend",
    "to_version": "0.1.0-test",
    ...
  }
}
```

---

## Phase 3: TMS-Bridge Integration

**Time Estimate**: 1 hour

### Step 3.1: Add Version Endpoint

Same as Backend, but in `CALConsult.TMSBridge.API/Controllers/VersionController.cs`

```csharp
// Same code as backend, but:
component = Environment.GetEnvironmentVariable("COMPONENT_NAME") ?? "tms-bridge"
```

### Step 3.2: Update Pipeline

Apply same changes to `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-t-t-wl5.yml`

Variables:
```yaml
- name: ComponentName
  value: 'tms-bridge'
```

### Step 3.3: Test

```bash
cd Code/Disposition-Abstraction-Layer

git add .
git commit -m "Add versioning system to TMS bridge"
git push origin main

git tag v0.1.0-test
git push origin v0.1.0-test
```

Watch pipeline → Should bump system version to v2.

---

## Phase 4: Frontend Integration

**Time Estimate**: 2-3 hours

### Step 4.1: Add ConfigService

Create files from `FRONTEND-VERSION-PANEL.md`:
1. `config/config.types.ts`
2. `config/config.service.ts`

### Step 4.2: Update App Config

Modify `app.config.ts` to add APP_INITIALIZER.

### Step 4.3: Create Version Panel Component

Create `components/system-version-panel/system-version-panel.component.ts`

### Step 4.4: Update App Component

Add version panel to `app.component.ts` template.

### Step 4.5: Add Docker Configuration

1. Create `docker-entrypoint.sh` (see `DOCKERFILE-UPDATES.md`)
2. Update `Dockerfile` to use entrypoint
3. Create placeholder `assets/config.json`

### Step 4.6: Test Locally

```bash
cd Code/Disposition-Frontend

# Test Angular changes
npm run cal:start
# Visit http://localhost:4200
# Should see version panel with "dev" versions

# Test Docker build
docker build -t frontend-test .
docker run -p 8081:8081 \
  -e SYSTEM_VERSION=2 \
  -e COMPONENT_VERSION=0.1.0-test \
  -e SHOW_VERSION_PANEL=true \
  frontend-test

# Visit http://localhost:8081
```

### Step 4.7: Update Pipeline

Apply changes from `PIPELINE-CHANGES-ONLY.md` (frontend section).

### Step 4.8: Test Release

```bash
git add .
git commit -m "Add versioning system to frontend"
git push origin main

git tag v0.1.0-test
git push origin v0.1.0-test
```

System version should bump to v3.

---

## Phase 5: Integration Testing

**Time Estimate**: 1 hour

### Step 5.1: Verify All Components

```bash
cd system-manifest
git pull

cat versions.json
```

**Expected**:
```json
{
  "system_version": 3,
  "components": {
    "disposition-backend": "0.1.0-test",
    "tms-bridge": "0.1.0-test",
    "disposition-frontend": "0.1.0-test"
  }
}
```

### Step 5.2: Test Version Endpoints

```bash
# Backend
curl https://test.dispo.gcp.nagel-group.com/api/version

# TMS Bridge
curl https://test.tms-bridge.gcp.nagel-group.com/api/version
```

### Step 5.3: Test Frontend Panel

1. Open frontend in browser
2. Version panel should show in bottom-right
3. Click to expand
4. Should show system v3
5. Click refresh (↻) to fetch live versions
6. All should show ✅ (no mismatches)

### Step 5.4: Test Past Resolution

```bash
cd system-manifest

# View history
git log --oneline

# View specific version
git show system-v2:versions.json

# Checkout backend at system v2
cd ../Code/Disposition-Backend
git checkout system-v2
git log -1
# Should show commit tagged with system-v2
```

---

## Phase 6: Team Rollout

**Time Estimate**: 2 hours (training + documentation)

### Step 6.1: Team Presentation

Use `PRESENTATION-Versioning-System.md` to present to team.

### Step 6.2: Update Documentation

1. Add to project README
2. Update deployment runbooks
3. Document developer workflow

### Step 6.3: Developer Training

Show developers:

1. **How to release**:
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

2. **How to check versions**:
   - Frontend version panel
   - `/api/version` endpoints
   - System-manifest repo

3. **How to query past versions**:
   ```bash
   cd system-manifest
   git show system-v42:versions.json
   ```

4. **How to checkout old code**:
   ```bash
   git checkout system-v42
   ```

### Step 6.4: Update CI/CD Documentation

Document the new pipeline behavior:
- Tag triggers release pipeline
- Manual deployment approval required
- System version auto-increments

---

## Phase 7: Production Rollout

**Time Estimate**: 1-2 hours

### Step 7.1: Create Production Pipelines

Duplicate pipelines for production:
- `azure-pipelines-cloudrun-p-p.yml` (production)
- Apply same versioning changes
- Set `SHOW_VERSION_PANEL=false` for production

### Step 7.2: First Production Release

```bash
# Tag for production
git tag v1.0.0
git push origin v1.0.0

# Manually approve deployment in Azure DevOps
```

### Step 7.3: Verify Production

1. Check version endpoints (should work)
2. Version panel hidden (SHOW_VERSION_PANEL=false)
3. System-manifest updated
4. All services show same system version

---

## Rollback Plan

If something goes wrong:

### Immediate Rollback

1. **Disable new pipeline steps**: Comment out versioning steps in YAML
2. **Redeploy previous versions**: Use old Docker images
3. **System-manifest**: Still accessible, won't affect running services

### Partial Rollback

- Keep backend versioning, disable frontend
- Keep manifest, disable auto-deployment
- Use manual system version bumps

### Data Safety

- System-manifest is append-only (Git history preserved)
- Component repos retain all tags
- Docker images retain all tags
- No data loss possible

---

## Troubleshooting

### Pipeline fails at bump-system-version

**Symptoms**: "Max retries reached"

**Solution**:
- Check system-manifest repo permissions
- Verify `System.AccessToken` has write access
- Manually push a commit to manifest repo to unstick

### Version endpoint returns "unknown"

**Symptoms**: `/api/version` shows all "unknown"

**Solution**:
- Check Cloud Run environment variables
- Verify pipeline sets env vars during deployment
- Check container logs for startup errors

### Frontend panel doesn't show

**Symptoms**: No version panel in UI

**Solution**:
- Check `SHOW_VERSION_PANEL=true` in deployment
- Verify `config.json` generated correctly
- Check browser console for errors
- Verify APP_INITIALIZER runs

### Docker labels missing

**Symptoms**: `docker inspect` shows no labels

**Solution**:
- Check pipeline adds `--label` arguments
- Verify Docker build step syntax
- Try local build with labels

### Concurrent release conflicts

**Symptoms**: Two releases at same time, one fails

**Expected**: Retry logic should handle this automatically

**If fails**:
- Check bump-system-version.sh retry logic
- Manually re-run failed pipeline

---

## Maintenance

### Daily Operations

- Monitor system-manifest repo growth (minimal)
- Watch for pipeline failures
- Review version mismatches in test environment

### Weekly Tasks

- Review system version history
- Clean up old Docker images (keep system-vX tags)
- Update documentation if needed

### Monthly Tasks

- Review and optimize pipeline performance
- Update team on versioning practices
- Consider automation improvements

---

## Success Metrics

After implementation, you should be able to:

✅ Answer "What's deployed in test?" in <30 seconds
✅ Reproduce any past system state
✅ Identify which component triggered each release
✅ Detect version mismatches immediately
✅ Release without manual version coordination
✅ Track full history of all releases

---

## Next Steps

After successful implementation:

1. **Automation**: Consider auto-tagging from CI
2. **Notifications**: Add Slack notifications for releases
3. **Dashboards**: Create version status dashboard
4. **Monitoring**: Integrate with monitoring tools
5. **Analytics**: Track release frequency and patterns

---

## Support

If you encounter issues:

1. Check this implementation guide
2. Review troubleshooting section
3. Check system-manifest repo logs
4. Review pipeline logs in Azure DevOps
5. Test locally with Docker

---

## Summary Timeline

- **Phase 1**: System-manifest setup (30 min)
- **Phase 2**: Backend integration (1-2 hours)
- **Phase 3**: TMS-Bridge integration (1 hour)
- **Phase 4**: Frontend integration (2-3 hours)
- **Phase 5**: Integration testing (1 hour)
- **Phase 6**: Team rollout (2 hours)
- **Phase 7**: Production rollout (1-2 hours)

**Total**: 8-11 hours of implementation time

Spread over 1-2 weeks for proper testing and rollout.
