# Dockerfile Updates - Version Labels & Runtime Config

This document shows the Dockerfile changes needed for the versioning system.

---

## Overview

- **Backend & TMS Bridge**: No Dockerfile changes needed (labels added via pipeline)
- **Frontend**: Needs docker-entrypoint.sh for runtime config injection

---

## Part 1: Backend Dockerfile (No Changes Needed)

**File**: `Code/Disposition-Backend/Dockerfile.cloudrun-t-t`

**Current Dockerfile can stay as-is.** Docker labels are added via pipeline `--label` arguments during build.

### How Labels Are Added (in Pipeline)

```bash
docker build \
  --label "com.calconsult.component.name=disposition-backend" \
  --label "com.calconsult.component.version=1.2.3" \
  --label "com.calconsult.git.commit=abc123" \
  -t image:tag .
```

No need to modify Dockerfile itself.

### Optional: Add LABELs in Dockerfile

If you prefer to have labels in Dockerfile (using ARGs):

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0

# Add these ARGs if you want to embed in Dockerfile
ARG COMPONENT_VERSION=unknown
ARG GIT_COMMIT=unknown
ARG SYSTEM_VERSION=unknown

# Add these LABELs
LABEL com.calconsult.component.name="disposition-backend"
LABEL com.calconsult.component.version="${COMPONENT_VERSION}"
LABEL com.calconsult.git.commit="${GIT_COMMIT}"
LABEL com.calconsult.system.version="${SYSTEM_VERSION}"

ENV ASPNETCORE_URLS=http://*:5101
ENV ASPNETCORE_ENVIRONMENT="Development"

WORKDIR /
COPY gke-auth-key.json /app/gke-auth-key.json
ENV GOOGLE_APPLICATION_CREDENTIALS="gke-auth-key.json"

WORKDIR /app
COPY CALConsult.Disposition.API/bin/Release/net8.0/publish/ /app/
ENTRYPOINT ["dotnet", "CALConsult.Disposition.API.dll", "--environment=Development"]
```

Then build with:

```bash
docker build \
  --build-arg COMPONENT_VERSION=1.2.3 \
  --build-arg GIT_COMMIT=abc123 \
  --build-arg SYSTEM_VERSION=42 \
  -t image:tag .
```

**Recommendation**: Use pipeline `--label` approach (simpler, no Dockerfile changes).

---

## Part 2: TMS Bridge Dockerfile (No Changes Needed)

**File**: `Code/Disposition-Abstraction-Layer/Dockerfile.cloudrun-t-t`

Same as Backend - no changes needed. Labels added via pipeline.

---

## Part 3: Frontend Dockerfile (Changes Required)

**File**: `Code/Disposition-Frontend/Dockerfile`

### Current Dockerfile:

```dockerfile
### stage 1 - compile ###
FROM node:20.15.1 AS builder
LABEL authors="Nikolay Hristov <nikolay.hristov@p3-group.com"

WORKDIR /build
COPY . .

### stage 2 - copy compiled ###
FROM nginx:latest
COPY --from=builder /build/dist/apps/nagel-cal-disposition/ /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 8081
CMD ["nginx", "-g", "daemon off;"]
```

### Updated Dockerfile:

```dockerfile
### stage 1 - compile ###
FROM node:20.15.1 AS builder
LABEL authors="Nikolay Hristov <nikolay.hristov@p3-group.com>"

WORKDIR /build
COPY . .

# Build Angular app
RUN npm ci && npm run cal:build-production

### stage 2 - serve with nginx ###
FROM nginx:alpine

# Copy built Angular app
COPY --from=builder /build/dist/apps/nagel-cal-disposition/ /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Create placeholder config.json for local development
RUN mkdir -p /usr/share/nginx/html/assets && \
    echo '{"systemVersion":"dev","componentVersion":"dev","gitCommit":"local","showVersionPanel":"false","components":{},"services":{}}' \
    > /usr/share/nginx/html/assets/config.json

# Copy and setup entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8081

# Use entrypoint instead of direct CMD
ENTRYPOINT ["/docker-entrypoint.sh"]
```

### Create docker-entrypoint.sh

**Create new file**: `Code/Disposition-Frontend/docker-entrypoint.sh`

```bash
#!/bin/sh
# Runtime configuration injection for Angular frontend
# This script runs when the container starts and generates config.json
# from environment variables set by Cloud Run deployment

set -e

echo "Generating runtime config.json..."

# Generate config.json from environment variables
cat > /usr/share/nginx/html/assets/config.json <<EOF
{
  "systemVersion": "${SYSTEM_VERSION:-unknown}",
  "componentVersion": "${COMPONENT_VERSION:-unknown}",
  "gitCommit": "${GIT_COMMIT:-unknown}",
  "showVersionPanel": "${SHOW_VERSION_PANEL:-false}",
  "components": ${COMPONENT_MANIFEST:-"{}"},
  "services": {
    "disposition-backend": "${BACKEND_URL:-/api}",
    "tms-bridge": "${TMS_BRIDGE_URL:-/bridge}"
  }
}
EOF

echo "Config.json generated:"
cat /usr/share/nginx/html/assets/config.json

# Start nginx
exec nginx -g 'daemon off;'
```

**Make executable locally**:

```bash
chmod +x Code/Disposition-Frontend/docker-entrypoint.sh
```

### Add to .gitignore (if needed)

Ensure `docker-entrypoint.sh` is tracked by Git (it should be):

```bash
# In .gitignore, make sure docker-entrypoint.sh is NOT ignored
# (it should be committed to the repo)
```

---

## Part 4: Testing Dockerfiles

### Test Backend Dockerfile Locally

```bash
cd Code/Disposition-Backend

# Build with labels
docker build \
  -f Dockerfile.cloudrun-t-t \
  --label "com.calconsult.component.version=1.2.3" \
  --label "com.calconsult.git.commit=abc123" \
  -t backend-test:latest .

# Inspect labels
docker inspect backend-test:latest | jq '.[0].Config.Labels'

# Run with environment variables
docker run -p 5101:5101 \
  -e COMPONENT_NAME=disposition-backend \
  -e COMPONENT_VERSION=1.2.3 \
  -e SYSTEM_VERSION=42 \
  -e GIT_COMMIT=abc123 \
  backend-test:latest

# Test version endpoint
curl http://localhost:5101/api/version
```

### Test Frontend Dockerfile Locally

```bash
cd Code/Disposition-Frontend

# Build
docker build -t frontend-test:latest .

# Run with environment variables
docker run -p 8081:8081 \
  -e SYSTEM_VERSION=42 \
  -e COMPONENT_VERSION=1.5.0 \
  -e GIT_COMMIT=abc123 \
  -e SHOW_VERSION_PANEL=true \
  -e COMPONENT_MANIFEST='{"disposition-backend":"1.2.3","tms-bridge":"2.1.0","disposition-frontend":"1.5.0"}' \
  frontend-test:latest

# Check generated config.json
docker exec <container-id> cat /usr/share/nginx/html/assets/config.json

# Open browser
open http://localhost:8081
```

### Expected Results

**Backend/TMS Bridge**:
- Container starts normally
- `/api/version` endpoint returns correct values
- Labels visible in `docker inspect`

**Frontend**:
- Container starts
- config.json generated with environment variables
- Version panel visible in UI (if SHOW_VERSION_PANEL=true)
- Can fetch live versions from backends

---

## Part 5: Multi-Stage Build Optimization (Optional)

### Frontend Build Optimization

If you want to reduce final image size:

```dockerfile
### stage 1 - compile ###
FROM node:20.15.1 AS builder

WORKDIR /build
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run cal:build-production

### stage 2 - serve ###
FROM nginx:alpine

# Install jq for JSON manipulation (if needed)
RUN apk add --no-cache jq

# Copy only built artifacts
COPY --from=builder /build/dist/apps/nagel-cal-disposition/ /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

# Setup config
RUN mkdir -p /usr/share/nginx/html/assets && \
    echo '{"systemVersion":"dev","componentVersion":"dev","gitCommit":"local","showVersionPanel":"false","components":{},"services":{}}' \
    > /usr/share/nginx/html/assets/config.json

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8081
ENTRYPOINT ["/docker-entrypoint.sh"]
```

---

## Part 6: Docker Compose (Local Development)

**Create**: `Code/docker-compose.yml` (for local testing)

```yaml
version: '3.8'

services:
  backend:
    build:
      context: ./Disposition-Backend
      dockerfile: Dockerfile.cloudrun-t-t
    ports:
      - "5101:5101"
    environment:
      - COMPONENT_NAME=disposition-backend
      - COMPONENT_VERSION=1.0.0-local
      - SYSTEM_VERSION=1
      - GIT_COMMIT=local

  tms-bridge:
    build:
      context: ./Disposition-Abstraction-Layer
      dockerfile: Dockerfile.cloudrun-t-t
    ports:
      - "7153:7153"
    environment:
      - COMPONENT_NAME=tms-bridge
      - COMPONENT_VERSION=1.0.0-local
      - SYSTEM_VERSION=1
      - GIT_COMMIT=local

  frontend:
    build:
      context: ./Disposition-Frontend
      dockerfile: Dockerfile
    ports:
      - "8081:8081"
    environment:
      - SYSTEM_VERSION=1
      - COMPONENT_VERSION=1.0.0-local
      - GIT_COMMIT=local
      - SHOW_VERSION_PANEL=true
      - COMPONENT_MANIFEST={"disposition-backend":"1.0.0-local","tms-bridge":"1.0.0-local","disposition-frontend":"1.0.0-local"}
      - BACKEND_URL=http://localhost:5101/api
      - TMS_BRIDGE_URL=http://localhost:7153/api
    depends_on:
      - backend
      - tms-bridge
```

**Test with**:

```bash
cd Code
docker-compose up --build

# Access
# Frontend: http://localhost:8081
# Backend: http://localhost:5101/api/version
# TMS Bridge: http://localhost:7153/api/version
```

---

## Part 7: .dockerignore (Optional)

To speed up builds, add `.dockerignore` files:

**Backend**: `Code/Disposition-Backend/.dockerignore`

```
bin/
obj/
.vs/
.vscode/
*.user
.git/
.gitignore
README.md
```

**Frontend**: `Code/Disposition-Frontend/.dockerignore`

```
node_modules/
dist/
.angular/
.nx/
coverage/
.git/
.gitignore
README.md
*.md
.vscode/
```

---

## Summary

### Backend & TMS Bridge
- **No Dockerfile changes required**
- Labels added via pipeline during build
- Environment variables set during deployment

### Frontend
- **Add docker-entrypoint.sh** script
- **Modify Dockerfile** to use ENTRYPOINT
- **Create placeholder config.json** in assets
- Runtime config injection from environment variables

### Testing
- Test locally with `docker build` and `docker run`
- Use docker-compose for full stack testing
- Verify config.json generation
- Check version endpoints work

### Files to Create
1. `Code/Disposition-Frontend/docker-entrypoint.sh`
2. (Optional) `Code/docker-compose.yml`

### Files to Modify
1. `Code/Disposition-Frontend/Dockerfile`

That's it! The Docker configuration is now ready for the versioning system.
