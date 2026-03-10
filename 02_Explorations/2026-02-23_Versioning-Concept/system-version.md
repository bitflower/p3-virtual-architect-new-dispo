# System Version Management

## Problem

You have 3 separate Git repos (Backend, Frontend, TMS Bridge). You want a single "system version" that:
- Represents the entire New Dispo system
- Auto-increments when ANY component deploys
- Can be reported by users
- Tracks deployment history

## Solution: Timestamp-Based System Versioning in Frontend Repo

Use Frontend repo as the central registry for system version tags. Each component deployment creates a system tag there using timestamp.

**Why timestamp-based:**
- No coordination needed between repos
- No race conditions
- Naturally ordered
- Auto-increments

**Why Frontend repo:**
- Users interact with Frontend - natural place for system version
- Frontend can read its own tags to display system version
- Avoids creating additional repo

## Implementation

### 1. Add to Each Component Pipeline

After component deployment succeeds, tag the Frontend repo with system version.

**Backend example:**
```yaml
# In Disposition-Backend/azure-pipelines-cloudrun-t-t.yml
# After successful deployment and component tagging

- task: CmdLine@2
  displayName: 'Tag system version in Frontend repo'
  condition: succeeded()
  inputs:
    script: |
      # Clone Frontend repo
      git clone https://$(System.AccessToken)@dev.azure.com/org/project/_git/Disposition-Frontend /tmp/frontend-repo
      cd /tmp/frontend-repo

      # System version = timestamp
      SYSTEM_VERSION=$(date -u +%Y%m%d.%H%M)

      # Determine environment
      if [[ "$BUILD_SOURCEBRANCHNAME" == "main" ]]; then
        ENV="p-p"
      else
        ENV="t-t"
      fi

      # Get component info
      COMPONENT="backend"
      COMPONENT_VERSION=$(cat ../CALConsult.Disposition.API/wwwroot/version.json | jq -r '.version')
      COMPONENT_COMMIT=$(git -C .. rev-parse HEAD)

      # Create system version tag in Frontend repo
      git tag -a "system/${ENV}/${SYSTEM_VERSION}" -m "System deployment
Environment: ${ENV}
System Version: ${SYSTEM_VERSION}
Triggered by: ${COMPONENT}
Component Version: ${COMPONENT_VERSION}
Component Commit: ${COMPONENT_COMMIT}
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Build ID: ${BUILD_BUILDID}"

      git push origin "system/${ENV}/${SYSTEM_VERSION}" || {
        echo "Tag may already exist (race condition), continuing..."
        exit 0
      }
```

**TMS Bridge example:**
Same script, change:
- `COMPONENT="tms-bridge"`
- Path to `CALConsult.TMSBridge.API/wwwroot/version.json`

**Frontend example:**
Simpler - no need to clone, already in Frontend repo:
```yaml
- task: CmdLine@2
  displayName: 'Tag system version'
  condition: succeeded()
  inputs:
    script: |
      SYSTEM_VERSION=$(date -u +%Y%m%d.%H%M)
      ENV=$([[ "$BUILD_SOURCEBRANCHNAME" == "main" ]] && echo "p-p" || echo "t-t")
      COMPONENT="frontend"
      COMPONENT_VERSION=$(cat apps/nagel-cal-disposition/src/assets/component-version.json | jq -r '.version')
      COMPONENT_COMMIT=$(git rev-parse HEAD)

      git tag -a "system/${ENV}/${SYSTEM_VERSION}" -m "System deployment
Environment: ${ENV}
System Version: ${SYSTEM_VERSION}
Triggered by: ${COMPONENT}
Component Version: ${COMPONENT_VERSION}
Component Commit: ${COMPONENT_COMMIT}
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Build ID: ${BUILD_BUILDID}"

      git push origin "system/${ENV}/${SYSTEM_VERSION}"
```

### 2. Git Tag Structure

**In Frontend repo:**
```
# Frontend component tags (own deployments)
t-t/frontend/20260223.1
t-t/frontend/20260223.2
t-t/frontend/20260223.3

# System tags (ALL component deployments)
system/t-t/20260223.0915   <- Backend deployed at 09:15
system/t-t/20260223.1030   <- Frontend deployed at 10:30
system/t-t/20260223.1145   <- Backend deployed at 11:45
system/t-t/20260223.1400   <- TMS Bridge deployed at 14:00
system/t-t/20260223.1615   <- Frontend deployed at 16:15
```

**In Backend repo:**
```
# Only Backend component tags
t-t/backend/20260223.1
t-t/backend/20260223.2
t-t/backend/20260223.3
```

**In TMS Bridge repo:**
```
# Only TMS Bridge component tags
t-t/tms-bridge/20260223.1
t-t/tms-bridge/20260223.2
```

### 3. View System Version History

```bash
# In Frontend repo
cd Disposition-Frontend

# List all system deployments today
git tag -l "system/t-t/20260223.*"

# Show what triggered system version at 14:00
git show system/t-t/20260223.1400
# Output:
# System deployment
# Environment: t-t
# System Version: 20260223.1400
# Triggered by: tms-bridge
# Component Version: 20260223.4
# Component Commit: abc123def
# Build Date: 2026-02-23T14:00:00Z
# Build ID: 12345

# List all PROD releases
git tag -l "system/p-p/*"
```

### 4. Display System Version in Frontend

**Include in build:**
```yaml
# In Frontend pipeline, before build
- script: |
    cd Disposition-Frontend
    SYSTEM_VERSION=$(git tag -l "system/t-t/$(date +%Y%m%d).*" | sort -V | tail -1 | grep -oP 'system/t-t/\K.*')

    # Write to environment file
    cat > src/environments/system-version.ts <<EOF
    export const SYSTEM_VERSION = '${SYSTEM_VERSION}';
    EOF
  displayName: 'Get latest system version'
```

**Use in Angular:**
```typescript
// src/environments/system-version.ts (generated)
export const SYSTEM_VERSION = '20260223.1400';

// version-info.component.ts
import { SYSTEM_VERSION } from '../environments/system-version';

template: `
  <div>
    New Dispo System v{{ systemVersion }}
    <small>(Frontend: {{ componentVersion }})</small>
  </div>
`

systemVersion = SYSTEM_VERSION;
```

### 5. Bug Report Workflow

**User reports:** "Bug in System v20260223.1400"

**Support process:**
```bash
# 1. In Frontend repo, find what deployed at 14:00
cd Disposition-Frontend
git show system/t-t/20260223.1400
# Output: Triggered by tms-bridge, component version 20260223.4, commit abc123

# 2. Reconstruct full system state at 14:00
# Find latest component deployment BEFORE OR AT 14:00

# Backend - check Backend repo
cd ../Disposition-Backend
git tag -l "t-t/backend/20260223.*" | sort -V
# Find latest before 14:00 (1400)
# Result: t-t/backend/20260223.2 (deployed at ~11:45, version 20260223.3)

# Frontend - check Frontend repo
cd ../Disposition-Frontend
git tag -l "t-t/frontend/20260223.*" | sort -V
# Find latest before 14:00
# Result: t-t/frontend/20260223.2 (deployed at ~10:30, version 20260223.2)

# TMS Bridge - check TMS Bridge repo
cd ../Disposition-Abstraction-Layer
git tag -l "t-t/tms-bridge/20260223.*" | sort -V
# The one at 14:00
# Result: t-t/tms-bridge/20260223.4 (deployed at ~14:00, version 20260223.4)

# 3. Checkout all three at those versions
cd Disposition-Backend && git checkout t-t/backend/20260223.2
cd Disposition-Frontend && git checkout t-t/frontend/20260223.2
cd Disposition-Abstraction-Layer && git checkout t-t/tms-bridge/20260223.4

# 4. Reproduce bug with exact system state at 14:00
```

## Versioning Strategy Summary

| Level | Format | Example | Where Stored |
|-------|--------|---------|--------------|
| **System** | `yyyyMMdd.HHmm` | `20260223.1400` | Frontend repo |
| **Component** | `yyyyMMdd.N` | `20260223.3` | Each component's repo |
| **Commit** | SHA | `abc123def` | Each component's repo |

## Benefits

| Benefit | Explanation |
|---------|-------------|
| **Single version for users** | "Bug in System v20260223.1400" is clear |
| **Auto-increment** | Timestamp naturally increases, no manual work |
| **No coordination** | Each component independently tags Frontend repo |
| **No race conditions** | Timestamp includes time, unlikely to conflict |
| **Git-based** | Zero cost, already in Git |
| **Traceable** | Each system tag shows which component triggered it |
| **Decoupled** | Components still deploy independently |

## Permissions Required

Grant Backend and TMS Bridge pipelines access to Frontend repo:

**Azure DevOps Project Settings:**
1. Go to Disposition-Frontend repo → Security
2. Find "[Backend Project] Build Service" account
3. Grant "Contribute" and "Create tag" permissions
4. Repeat for TMS Bridge Build Service

**Or use System.AccessToken in pipelines** (already available, just needs repo permissions configured)

## Alternative: Use Backend or TMS Bridge Repo

If you prefer, you could use Backend or TMS Bridge repo as the system version registry instead. Frontend is just the suggested default since users interact with it.

## For PROD

PROD system version uses semantic versioning:
```
system/p-p/2.2.0
system/p-p/2.2.1
```

Manually tag after all components deployed for a release.

## Handling Same-Minute Deployments

If two components deploy in the same minute (unlikely), the second will fail to push the tag. This is acceptable:
- First deployment creates the system version tag
- Second deployment fails gracefully (already handled in script with `|| exit 0`)
- Both deployments are tracked via their component tags
- System version points to whichever deployed first

## Cost

€0 - Git tags are free
