# Version.json Storage Locations - Detailed Explanation

## Where is version.json stored?

### 1. Build Time (Temporary)

**Location:** Azure Pipeline agent workspace (temporary directory)

```bash
# Example in Azure Pipelines (Ubuntu agent)
/home/vsts/work/1/s/
  ├── CALConsult.Disposition.API/
  │   └── wwwroot/
  │       └── version.json  ← Generated during build (Backend)
  ├── CALConsult.TMSBridge.API/
  │   └── wwwroot/
  │       └── version.json  ← Generated during build (TMS Bridge)
  └── apps/nagel-cal-disposition/src/assets/
      ├── component-version.json  ← Generated during build (Frontend component)
      └── version.json            ← Aggregated version (Frontend)
```

**When:** Created by bash script in Azure Pipeline step
**Lifetime:** Exists only during build, then incorporated into deployment artifact

---

### 2. In Deployment Artifact

**Location:** Inside the Docker image

#### Backend (Docker Container - .NET 8.0)
```dockerfile
# Disposition-Backend/Dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0
ENV ASPNETCORE_URLS=http://*:5101
WORKDIR /app
COPY CALConsult.Disposition.API/bin/Release/net8.0/publish/ /app/
# version.json is in /app/wwwroot/version.json ← Copied via publish
ENTRYPOINT ["dotnet", "CALConsult.Disposition.API.dll"]
```

**Storage:** Docker image in GCP Artifact Registry
```
europe-west3-docker.pkg.dev/prj-cal-w-wl4-t-4c48-53ad/cal-new-disposition-t-t-backend/cal-new-disposition-t-t-backend:sha123
  └── /app/wwwroot/version.json  ← Inside the image
```

#### TMS Bridge (Docker Container - .NET 8.0)
```dockerfile
# Disposition-Abstraction-Layer/Dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0
ENV ASPNETCORE_URLS=http://*:7153
WORKDIR /app
COPY CALConsult.TMSBridge.API/bin/Release/net8.0/publish/ /app
# version.json is in /app/wwwroot/version.json ← Copied via publish
ENTRYPOINT ["dotnet", "CALConsult.TMSBridge.API.dll"]
```

**Storage:** Docker image in GCP Artifact Registry
```
europe-west3-docker.pkg.dev/.../cal-new-disposition-t-t-tms-bridge/...:sha123
  └── /app/wwwroot/version.json  ← Inside the image
```

#### Frontend (Docker Container - Angular + Nginx)
```dockerfile
# Disposition-Frontend/Dockerfile.cloudrun
# Stage 1: Build
FROM node:20.15.1 AS builder
WORKDIR /build
COPY . .
# version.json generated before build, included in dist

# Stage 2: Serve
FROM nginx:latest
COPY --from=builder /build/dist/apps/nagel-cal-disposition/ /usr/share/nginx/html
# version.json at /usr/share/nginx/html/assets/version.json ← Copied from build
EXPOSE 8081
CMD ["nginx", "-g", "daemon off;"]
```

**Storage:** Docker image in GCP Artifact Registry
```
europe-west3-docker.pkg.dev/.../cal-new-disposition-t-t-frontend/...:sha123
  └── /usr/share/nginx/html/assets/version.json  ← Inside the image
```

---

### 3. Runtime (Serving the File)

Each deployed component exposes its version.json via HTTP endpoint.

#### Backend (ASP.NET Core on Cloud Run)
```csharp
// In Program.cs or Startup.cs (already configured)
app.UseStaticFiles(); // Serves wwwroot/version.json automatically

// ASP.NET Core automatically serves files from wwwroot/
// No additional code needed!
```

**Cloud Run Service:**
- Name: `cal-new-disposition-t-t-backend`
- Container path: `/app/wwwroot/version.json`
- Nginx serves static files automatically

**Accessible at:**
```
https://test.dispo.gcp.nagel-group.com/version.json
https://prod.dispo.gcp.nagel-group.com/version.json
```

#### TMS Bridge (ASP.NET Core on Cloud Run)
```csharp
// Same as Backend - UseStaticFiles() serves wwwroot/
app.UseStaticFiles();
```

**Cloud Run Service:**
- Name: `cal-new-disposition-t-t-tms-bridge`
- Container path: `/app/wwwroot/version.json`

**Accessible at:**
```
https://test.tms-bridge.gcp.nagel-group.com/version.json
https://prod.tms-bridge.gcp.nagel-group.com/version.json
```

#### Frontend (Nginx on Cloud Run)
```nginx
# nginx.conf.cloudrun (already configured)
# Nginx automatically serves files from /usr/share/nginx/html/
# No changes needed - version.json is already included in build
```

**Cloud Run Service:**
- Name: `cal-new-disposition-t-t-frontend`
- Container path: `/usr/share/nginx/html/assets/version.json`
- Nginx serves static files automatically

**Accessible at:**
```
https://test.dispo.gcp.nagel-group.com/assets/version.json
https://prod.dispo.gcp.nagel-group.com/assets/version.json
```

---

### 4. Historical Storage (Archives)

Multiple options for keeping version history:

#### Option A: Git Repository (Recommended)
```bash
# Separate "deployment-versions" repo or in frontend repo
deployment-versions/
  ├── .git/
  └── versions/
      ├── 2026-02-23/
      │   ├── test-10-35-00.json
      │   └── prod-14-20-00.json
      └── 2026-02-24/
          └── test-09-15-00.json

# With Git tags
git tag test/v2.2.0/2026-02-23T10:35:00Z
git push --tags
```

**Retrieval:**
```bash
git show test/v2.2.0/2026-02-23T10:35:00Z:versions/2026-02-23/test-10-35-00.json
```

#### Option B: Cloud Storage Bucket
```
GCS Bucket: gs://newdispo-version-history/
  ├── test/
  │   ├── 2026-02-23/
  │   │   ├── 10-35-00-version.json
  │   │   └── 14-20-00-version.json
  │   └── 2026-02-24/
  │       └── 09-15-00-version.json
  └── prod/
      └── 2026-02-23/
          └── 15-00-00-version.json
```

**Uploaded by:** Frontend deployment pipeline after generating aggregated version
```bash
# In Frontend CI/CD after aggregation
gsutil cp src/assets/version.json \
  gs://newdispo-version-history/test/$(date +%Y-%m-%d)/$(date +%H-%M-%S)-version.json
```

**Retrieval:**
```bash
gsutil ls gs://newdispo-version-history/test/2026-02-23/
gsutil cp gs://newdispo-version-history/test/2026-02-23/10-35-00-version.json ./
```

#### Option C: Artifact Registry Metadata
```
GCP Artifact Registry automatically stores:
  ├── Docker images (with version.json baked in)
  └── Metadata about builds

# Retrieve from old image
docker pull gcr.io/project-id/backend:2.2.124
docker run --rm gcr.io/project-id/backend:2.2.124 cat /app/version.json
```

---

## Complete Storage Flow

### Example: Backend Deployment

```
1. CI/CD Build
   ├─ Generate version.json in /workspace/version.json
   ├─ Include in Docker image
   └─ Push image to gcr.io/project-id/backend:2.2.124

2. Deployment
   ├─ Cloud Run pulls image
   ├─ Container starts with version.json at /app/version.json
   └─ Endpoint available: https://backend-test.newdispo.com/version.json

3. Frontend Aggregation
   ├─ Frontend CI/CD runs aggregation script
   ├─ curl https://backend-test.newdispo.com/version.json
   ├─ Combines with other versions
   └─ Creates src/assets/version.json

4. Frontend Deployment
   ├─ Build includes aggregated version.json
   ├─ Deploy to Cloud Storage / CDN
   └─ Accessible at: https://test.newdispo.com/assets/version.json

5. Historical Archive (optional)
   ├─ Frontend pipeline uploads to GCS
   └─ gs://newdispo-version-history/test/2026-02-23/10-35-00-version.json
```

---

## Implementation Details per Component

### Backend (Node.js + Express)

**File location in repo:**
```
backend/
  ├── src/
  ├── package.json
  └── version.json  ← NOT checked into Git (generated)
```

**Add to .gitignore:**
```gitignore
version.json
```

**Generate in CI/CD:**
```yaml
# cloudbuild.yaml or similar
steps:
  - name: 'gcr.io/cloud-builders/git'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        cat > version.json <<EOF
        {
          "component": "backend",
          "version": "$(cat package.json | jq -r .version)",
          "commit": "$(git rev-parse HEAD)",
          "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "branch": "${BRANCH_NAME}"
        }
        EOF

  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/backend:$SHORT_SHA', '.']
```

**Serve in application:**
```javascript
// src/app.js
app.get('/version.json', (req, res) => {
  res.sendFile(path.join(__dirname, '../version.json'));
});
```

### Frontend (React/Vue/Angular)

**File location in repo:**
```
frontend/
  ├── src/
  │   └── assets/
  │       └── version.json  ← Generated during build
  ├── public/
  └── package.json
```

**Generate aggregated version in CI/CD:**
```yaml
# cloudbuild.yaml
steps:
  # Step 1: Generate component version
  - name: 'gcr.io/cloud-builders/git'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        cat > component-version.json <<EOF
        {
          "component": "frontend",
          "version": "$(cat package.json | jq -r .version)",
          "commit": "$(git rev-parse HEAD)",
          "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "branch": "${BRANCH_NAME}"
        }
        EOF

  # Step 2: Fetch other component versions
  - name: 'gcr.io/cloud-builders/curl'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        curl -f https://backend-${_ENV}.newdispo.com/version.json > backend-version.json || echo '{"error":"unavailable"}' > backend-version.json
        curl -f https://tmsbridge-${_ENV}.newdispo.com/version.json > tmsbridge-version.json || echo '{"error":"unavailable"}' > tmsbridge-version.json

  # Step 3: Aggregate versions
  - name: 'gcr.io/cloud-builders/npm'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        mkdir -p src/assets
        cat > src/assets/version.json <<EOF
        {
          "newDispo": "2.2.0",
          "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "environment": "${_ENV}",
          "components": {
            "frontend": $(cat component-version.json),
            "backend": $(cat backend-version.json),
            "tmsBridge": $(cat tmsbridge-version.json),
            "tmsDatabase": {"version": "7.0.0.81", "note": "Manual tracking"}
          }
        }
        EOF

  # Step 4: Build frontend (includes version.json)
  - name: 'gcr.io/cloud-builders/npm'
    args: ['run', 'build']

  # Step 5 (Optional): Archive version to GCS
  - name: 'gcr.io/cloud-builders/gsutil'
    args:
      - 'cp'
      - 'src/assets/version.json'
      - 'gs://newdispo-version-history/${_ENV}/$(date +%Y-%m-%d)/$(date +%H-%M-%S)-version.json'

  # Step 6: Deploy
  - name: 'gcr.io/cloud-builders/gsutil'
    args: ['-m', 'rsync', '-r', '-c', '-d', 'dist/', 'gs://newdispo-frontend-${_ENV}/']
```

**Access in application:**
```javascript
// src/utils/version.js
export async function getVersion() {
  const response = await fetch('/assets/version.json');
  return response.json();
}

// src/components/VersionDisplay.vue
<template>
  <div>
    <p>New Dispo v{{ version.newDispo }}</p>
    <details>
      <summary>Component Versions</summary>
      <ul>
        <li>Frontend: {{ version.components.frontend.version }}</li>
        <li>Backend: {{ version.components.backend.version }}</li>
        <li>TMS Bridge: {{ version.components.tmsBridge.version }}</li>
      </ul>
    </details>
  </div>
</template>
```

---

## Storage Summary Table

| Phase | Storage Location | Lifetime | Purpose |
|-------|------------------|----------|---------|
| **Build** | CI/CD workspace `/workspace/version.json` | Minutes | Temporary during build |
| **Artifact** | Docker image `gcr.io/.../app/version.json` | Permanent | Deployed version |
| **Runtime** | Container/webserver serves via HTTP | While running | Live version info |
| **Archive** | GCS `gs://bucket/env/date/version.json` | Permanent | Historical record |
| **Git** | Tags + committed file in version repo | Permanent | Historical record |

---

## Recommended Approach

**For validation phase:**
1. ✅ Generate in CI/CD workspace
2. ✅ Include in deployment artifacts
3. ✅ Serve via HTTP endpoint
4. ⚠️ Skip historical archive initially (validate concept first)

**After validation succeeds:**
1. ✅ All of the above
2. ✅ Add Git tags in frontend repo
3. ✅ Optional: Archive to Cloud Storage for easy querying

---

## Storage Costs

| Storage Type | Cost | Notes |
|--------------|------|-------|
| In artifacts (Artifact Registry) | Included | Images stored anyway |
| Git tags | €0 | Part of Git repo |
| Cloud Storage archive | €0.01/GB/month | ~1KB per version = negligible |

**Example:** 10 deployments/day × 1KB × 365 days = 3.65MB/year ≈ €0.0004/year

---

## Next Steps

1. Decide on historical storage method (Git tags recommended)
2. Add version.json generation to CI/CD scripts
3. Implement HTTP endpoint in each component
4. Test accessing versions from deployed services
