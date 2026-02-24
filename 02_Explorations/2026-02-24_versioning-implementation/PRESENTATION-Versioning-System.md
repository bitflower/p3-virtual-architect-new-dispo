# Microservice Versioning System - Team Presentation

## Problem Statement

**Challenge**: In a microservice architecture with 3+ components (Backend, TMS Bridge, Frontend), how do we:
- Track which versions of components work together?
- Identify what's deployed in each environment?
- Reproduce old system states for debugging?
- Know which component triggered each release?

**Current Pain Points**:
- No unified "system version"
- Hard to answer "what was running on Feb 15?"
- Difficult to correlate component versions across services

---

## Solution: Automatic System Versioning

Every component release automatically generates a **monotonically increasing system version** that captures a complete snapshot of all component versions.

```mermaid
graph TD
    SV[System Version v42]
    SV --> BE[disposition-backend v1.2.3]
    SV --> TB[tms-bridge v2.1.0]
    SV --> FE[disposition-frontend v1.5.0]

    style SV fill:#00d9ff,stroke:#333,stroke-width:3px,color:#000
    style BE fill:#4CAF50,stroke:#333,stroke-width:2px,color:#fff
    style TB fill:#4CAF50,stroke:#333,stroke-width:2px,color:#fff
    style FE fill:#4CAF50,stroke:#333,stroke-width:2px,color:#fff
```

---

## Core Principles

### 1. **Decentralized**
- No central versioning service to maintain
- Everything lives in Git repos and Docker labels
- Works offline, no single point of failure

### 2. **Automatic**
- Developer only pushes a Git tag: `git tag v1.2.3 && git push origin v1.2.3`
- CI/CD handles everything else automatically

### 3. **Complete History**
- Git maintains full history
- Can query any past system version
- Reproducible builds

### 4. **Atomic**
- Race condition handling with retry logic
- Multiple simultaneous releases don't conflict

---

## How It Works: The Flow

### Overall Architecture

```mermaid
flowchart TB
    DEV[Developer] -->|git push tag v1.2.3| REPO[Component Repo]
    REPO -->|Trigger| PIPE[Azure Pipeline]

    PIPE -->|1. Build| BUILD[Build & Test]
    BUILD -->|2. Containerize| DOCKER[Docker Image backend:1.2.3]
    DOCKER -->|3. Push| REG[Container Registry]

    PIPE -->|4. Bump| MANIFEST[system-manifest repo]
    MANIFEST -->|system v42| MANIFEST

    MANIFEST -->|5. Tag back| REPO
    REPO -->|system-v42| REPO

    REG -->|6. Re-tag| REG2[backend:system-v42]

    REG2 -->|7. Manual Deploy| ENV[Test/Prod Environment]

    ENV -->|8. Query| FRONTEND[Frontend Version Panel]
    ENV -->|9. Expose| API[Version Endpoints]

    style DEV fill:#FFD700,stroke:#333,stroke-width:2px
    style MANIFEST fill:#00d9ff,stroke:#333,stroke-width:3px
    style PIPE fill:#FF6B6B,stroke:#333,stroke-width:2px
    style ENV fill:#4CAF50,stroke:#333,stroke-width:2px
    style FRONTEND fill:#9C27B0,stroke:#333,stroke-width:2px
```

### Detailed Pipeline Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Repo as Component Repo
    participant Pipeline as Azure Pipeline
    participant Docker as Container Registry
    participant Manifest as system-manifest

    Dev->>Repo: git tag v1.2.3<br/>git push origin v1.2.3
    Repo->>Pipeline: Trigger on tag

    Pipeline->>Pipeline: Build & Test
    Pipeline->>Docker: Push image<br/>backend:1.2.3

    Pipeline->>Manifest: Clone & Read<br/>current_version = 41
    Manifest-->>Pipeline: Return version 41

    Pipeline->>Manifest: Bump to 42<br/>Update components<br/>Commit & Tag
    Manifest->>Manifest: Tag system-v42

    Pipeline->>Repo: Tag system-v42
    Pipeline->>Docker: Re-tag image<br/>backend:system-v42

    Note over Pipeline: Manual Approval

    Pipeline->>Env: Deploy with<br/>env vars (v42, v1.2.3)

    participant Env as Test Environment
```

### Developer Workflow (Simple)

```bash
# Developer makes changes, ready to release
git tag v1.2.3
git push origin v1.2.3

# ✅ Everything else happens automatically:
# - Build & test
# - Create Docker images
# - Bump system version
# - Tag repos
# - Ready to deploy
```

---

## High-Frequency Releases (10+ per day)

### Problem: Manual Tagging is Tedious

For test environments with frequent releases, manual tagging becomes overhead:

```bash
# Manual workflow (tedious for 10+ releases/day)
git tag v1.2.3
git push origin v1.2.3
```

### Solution: Auto-Tag on Merge

**Pipeline triggers on every merge to main** → automatically generates version:

```mermaid
flowchart LR
    DEV[Developer] -->|Merge PR| MAIN[main branch]
    MAIN -->|Auto-trigger| PIPE[Pipeline]
    PIPE -->|Generate| VER[Version: 0.26.1234]
    VER -->|Auto-create| TAG[Git Tag: v0.26.1234]
    TAG -->|Continue| REST[Rest of Pipeline...]

    style MAIN fill:#4CAF50,stroke:#333,stroke-width:2px
    style VER fill:#00d9ff,stroke:#333,stroke-width:2px
    style TAG fill:#FFD700,stroke:#333,stroke-width:2px
```

### Automated Developer Workflow (Zero Manual Tagging)

```bash
# Developer just merges to main
git checkout -b feature/my-feature
# ... make changes ...
git commit -m "Add new feature"
git push origin feature/my-feature

# Create PR → Review → Merge
# ✅ Pipeline automatically:
#    - Generates version (0.26.1234)
#    - Creates Git tag
#    - Builds & deploys
#    - Bumps system version
```

### Version Format Options

**Option 1: Build Number** (Recommended for Test)
- Format: `0.{year}.{build-number}`
- Example: `0.26.1234` (year 2026, build 1234)
- ✅ Simple, unique, sortable
- ✅ Works for unlimited releases

**Option 2: Calendar Versioning**
- Format: `YYYY.MM.BUILD`
- Example: `2026.02.0034` (34th build in Feb)
- ✅ Date-based, easy to understand

### Recommendation

- **Test Environment**: Auto-tag on merge (no manual work)
- **Production**: Manual semantic tags (controlled releases)

This gives you:
- Fast iteration in test (10+ releases/day, zero overhead)
- Controlled releases in production (manual approval)

**All versioning benefits still work**: past resolution, system versions, full traceability.

---

## Component Interaction

```mermaid
graph LR
    subgraph "Git Repositories"
        BR[Backend Repo<br/>tags: v1.2.3<br/>system-v42]
        TR[TMS Bridge Repo<br/>tags: v2.1.0<br/>system-v42]
        FR[Frontend Repo<br/>tags: v1.5.0<br/>system-v42]
        MR[(system-manifest<br/>versions.json<br/>system-v42)]
    end

    subgraph "Container Registry"
        BI[backend:1.2.3<br/>backend:system-v42]
        TI[tms-bridge:2.1.0<br/>tms-bridge:system-v42]
        FI[frontend:1.5.0<br/>frontend:system-v42]
    end

    subgraph "Running Services"
        BS[Backend Service<br/>/api/version]
        TS[TMS Bridge Service<br/>/api/version]
        FS[Frontend<br/>Version Panel]
    end

    BR -.->|builds| BI
    TR -.->|builds| TI
    FR -.->|builds| FI

    BR --> MR
    TR --> MR
    FR --> MR

    BI -->|deploys| BS
    TI -->|deploys| TS
    FI -->|deploys| FS

    FS -->|queries| BS
    FS -->|queries| TS

    style MR fill:#00d9ff,stroke:#333,stroke-width:3px
    style FS fill:#9C27B0,stroke:#333,stroke-width:2px
```

---

## Storage & Tagging Strategy

### 1. System-Manifest Repository

**Single file: `versions.json`**

```json
{
  "system_version": 42,
  "components": {
    "disposition-backend": "1.2.3",
    "tms-bridge": "2.1.0",
    "disposition-frontend": "1.5.0"
  },
  "released_at": "2026-02-15T14:30:00Z",
  "trigger": {
    "component": "disposition-backend",
    "from_version": "1.2.2",
    "to_version": "1.2.3",
    "git_commit": "abc123"
  }
}
```

**Git history = system version history:**

```
$ git log --oneline
f4e2a1b  v52: disposition-backend → 1.3.0
c3d4e5f  v51: tms-bridge → 2.2.0
a1b2c3d  v50: disposition-frontend → 1.6.0
9e8d7c6  v49: disposition-backend → 1.2.5
```

### 2. Component Repositories (Dual Tagging)

Each component gets **two Git tags** per release:

```bash
# Example: Disposition-Backend release
git tag v1.2.3         # Component version
git tag system-v42     # System version it belongs to
```

**Benefits**:
- `git checkout system-v42` → Get exact code from that system version
- `git tag --contains <commit>` → See which system version

### 3. Docker Images (Multiple Tags)

```bash
# Each Docker image gets tagged 3 ways:
disposition-backend:1.2.3          # Component version
disposition-backend:system-v42     # System version
disposition-backend:latest         # Latest
```

**Docker Labels** (metadata inside image):

```dockerfile
com.calconsult.component.name=disposition-backend
com.calconsult.component.version=1.2.3
com.calconsult.system.version=42
com.calconsult.git.commit=abc123
com.calconsult.git.repo=Disposition-Backend
```

Query running containers:
```bash
docker inspect <container> | jq '.[0].Config.Labels'
```

---

## Version Resolution: Past & Present

### Past Resolution: "What was in system v42?"

**1. View complete snapshot:**
```bash
cd system-manifest
git show system-v42:versions.json
```

**Output:**
```json
{
  "system_version": 42,
  "components": {
    "disposition-backend": "1.2.3",
    "tms-bridge": "2.1.0",
    "disposition-frontend": "1.5.0"
  },
  "released_at": "2026-02-15T14:30:00Z"
}
```

**2. Checkout code at system v42:**
```bash
cd Disposition-Backend
git checkout system-v42
# You now have the exact code that was released in system v42
```

**3. Compare two system versions:**
```bash
# What changed between v40 and v50?
diff <(git show system-v40:versions.json | jq '.components') \
     <(git show system-v50:versions.json | jq '.components')
```

**4. Find when component version was released:**
```bash
# Which system version had backend v1.2.3?
cd Disposition-Backend
git tag --contains v1.2.3 | grep system-v
# Output: system-v42
```

**5. Historical query:**
```bash
# What was running on February 15, 2026?
cd system-manifest
git log --before="2026-02-16" --format="%h %s" -1
# Output: abc1234 v42: disposition-backend → 1.2.3

git show system-v42:versions.json
```

### Present Resolution: "What's running now?"

**1. Frontend Version Panel** (for logged-in users):

```
┌─────────────────────────────────────────┐
│  System v42                           ▼ │
├─────────────────────────────────────────┤
│  MANIFEST (Expected)                    │
│  Component              Version         │
│  disposition-backend    1.2.3           │
│  tms-bridge            2.1.0            │
│  disposition-frontend   1.5.0           │
│                                         │
│  LIVE (Actual)                      ↻   │
│  Component          Version   Status    │
│  disposition-backend 1.2.3      ✅      │
│  tms-bridge         2.1.0       ✅      │
│  disposition-frontend 1.5.0     ✅      │
└─────────────────────────────────────────┘
```

**2. Query deployed containers:**
```bash
gcloud run services describe disposition-backend \
  --region=europe-west3 \
  --format='value(spec.template.spec.containers[0].image)'

# Output: europe-west3-docker.pkg.dev/.../disposition-backend:1.2.3
```

**3. Backend API endpoints:**
```bash
curl https://test.api.com/api/version

# Response:
{
  "component": "disposition-backend",
  "version": "1.2.3",
  "systemVersion": "42",
  "gitCommit": "abc123"
}
```

---

## Race Condition Handling

### Problem: Multiple Releases at Same Time

```mermaid
sequenceDiagram
    participant PA as Pipeline A<br/>(Backend)
    participant PB as Pipeline B<br/>(Frontend)
    participant M as system-manifest

    Note over PA,PB: Both start simultaneously

    PA->>M: Read version = 41
    PB->>M: Read version = 41

    PA->>PA: Calculate: 41 + 1 = 42
    PB->>PB: Calculate: 41 + 1 = 42

    PA->>M: Push v42 ✅
    PB->>M: Push v42 ❌ CONFLICT!

    Note over PB: Retry with fresh clone

    PB->>M: Read version = 42
    PB->>PB: Calculate: 42 + 1 = 43
    PB->>M: Push v43 ✅
```

### Solution: Atomic Bump with Retry Loop

**`bump-system-version.sh` strategy:**

```bash
for attempt in 1..10; do
  # 1. Fresh clone (always latest)
  git clone system-manifest

  # 2. Read current version
  CURRENT=$(jq '.system_version' versions.json)
  NEW=$((CURRENT + 1))

  # 3. Update JSON
  jq '.system_version = $NEW' versions.json > tmp.json

  # 4. Commit & tag
  git commit -m "v${NEW}: ${COMPONENT} → ${VERSION}"
  git tag "system-v${NEW}"

  # 5. Push (fails atomically if outdated)
  if git push && git push --tags; then
    echo "Success! System version: ${NEW}"
    exit 0
  fi

  # 6. Retry (someone else was faster)
  sleep random(1-3 seconds)
done
```

**Why it works:**
- `git push` fails atomically if remote is ahead
- Next attempt clones fresh → reads the version the other pipeline wrote
- Eventually all pipelines succeed with unique version numbers

```mermaid
flowchart TD
    START[Start Bump] --> CLONE[Clone manifest repo]
    CLONE --> READ[Read current version]
    READ --> INC[Increment version]
    INC --> COMMIT[Commit & Tag]
    COMMIT --> PUSH{Git Push}

    PUSH -->|Success ✅| DONE[Done]
    PUSH -->|Conflict ❌| RETRY{Retries < 10?}

    RETRY -->|Yes| WAIT[Wait random 1-3s]
    WAIT --> CLONE

    RETRY -->|No| FAIL[Fail]

    style DONE fill:#4CAF50,stroke:#333,stroke-width:2px
    style FAIL fill:#FF6B6B,stroke:#333,stroke-width:2px
    style PUSH fill:#FFA500,stroke:#333,stroke-width:2px
```

---

## Benefits Summary

### For Developers
✅ **Simple workflow**: Just push a tag
✅ **No manual coordination**: Everything automatic
✅ **Clear history**: See what changed and when

### For Operations
✅ **Environment visibility**: Know exactly what's deployed
✅ **Reproducibility**: Can redeploy any old system version
✅ **Debugging**: "What was running when bug X appeared?"

### For Testing
✅ **Version alignment**: Ensure all components match
✅ **Mismatch detection**: Frontend shows if services are out of sync
✅ **Test traceability**: Link test results to exact system version

---

## Migration Path

```mermaid
gantt
    title Implementation Timeline
    dateFormat YYYY-MM-DD
    section Setup
    Create system-manifest repo           :done, setup1, 2026-02-24, 1d
    Grant permissions                     :done, setup2, after setup1, 1d

    section Backend
    Add version endpoint                  :active, be1, after setup2, 1d
    Update pipeline                       :active, be2, after be1, 2d
    Test & verify                         :crit, be3, after be2, 1d

    section TMS Bridge
    Add version endpoint                  :tb1, after be3, 1d
    Update pipeline                       :tb2, after tb1, 1d

    section Frontend
    Add ConfigService                     :fe1, after tb2, 2d
    Add Version Panel                     :fe2, after fe1, 1d
    Update Docker config                  :fe3, after fe2, 1d

    section Rollout
    Integration testing                   :crit, test1, after fe3, 2d
    Team training                         :train, after test1, 1d
    Production rollout                    :crit, prod, after train, 2d
```

### Phase Details

**Week 1**: Setup (2 days)
1. Create `system-manifest` repository in Azure DevOps
2. Initialize with `versions.json` and `bump-system-version.sh`
3. Grant pipeline permissions

**Week 2**: Backend Integration (4 days)
1. Add `/api/version` endpoint to Backend & TMS Bridge
2. Update pipelines with version steps
3. Test & verify system version bumping

**Week 3**: Frontend Integration (4 days)
1. Add Angular ConfigService + APP_INITIALIZER
2. Create SystemVersionPanel component
3. Add docker-entrypoint.sh for runtime config
4. Update Azure Pipeline

**Week 4**: Rollout (5 days)
1. Integration testing across all components
2. Team presentation (this document)
3. First production release with new system
4. Documentation and runbook updates

---

## Avoiding Pipeline Code Duplication

### Concern: Pipeline Creep

Versioning logic could be duplicated across 3 pipelines (hard to maintain, no testing, complex YAML).

### Solution: Reusable Scripts

To avoid pipeline code duplication, all versioning logic lives in the **`system-manifest` repository** alongside `versions.json`:

**Repository**: `system-manifest` (already created)

```
system-manifest/
├── versions.json                   # System version state
├── scripts/
│   ├── extract-version.sh          # Version extraction logic
│   ├── bump-system-version.sh      # System version bump (already here!)
│   ├── tag-component-repo.sh       # Git tagging
│   └── tag-docker-image.sh         # Docker re-tagging
└── tests/                          # Unit tests
```

Component pipelines **download and execute** these scripts from system-manifest.

### Pipeline Implementation (Clean & Simple)

```yaml
# Download scripts from system-manifest repo
- task: Bash@3
  script: git clone system-manifest /tmp/manifest

# Extract version
- task: Bash@3
  script: /tmp/manifest/scripts/extract-version.sh

# Bump system version
- task: Bash@3
  script: /tmp/manifest/scripts/bump-system-version.sh "backend" "1.2.3" "abc123"

# Tag component repo
- task: Bash@3
  script: /tmp/manifest/scripts/tag-component-repo.sh "42"

# Tag Docker image
- task: Bash@3
  script: /tmp/manifest/scripts/tag-docker-image.sh "backend:1.2.3" "42"
```

**Benefits**:
- ✅ Logic centralized in one repository
- ✅ Unit tested before pipeline use
- ✅ Update once, affects all components
- ✅ Can test locally before deployment
- ✅ No duplication across pipelines

**Why system-manifest repo?**
- ✅ Scripts and data in one place
- ✅ One repository to maintain (not two)
- ✅ `bump-system-version.sh` already lives here
- ✅ Simpler architecture

See `REUSABLE-SCRIPTS.md` for complete implementation.

---

## Questions & Discussion

**Q: What happens to existing pipelines?**
A: Keep them running in parallel during migration. New tag-based pipelines are separate.

**Q: Do we need to change how we develop?**
A: No. You still develop the same way. Only the release process changes.

**Q: What if system-manifest repo is unavailable?**
A: Build still succeeds, but system version bump fails. Can be retried later. Component versions are reconstructable from Git tags.

**Q: Can we skip version numbers?**
A: No. System versions are sequential. Any gaps indicate a failed/rolled-back release (still visible in Git history).

**Q: How much storage does this need?**
A: Minimal. System-manifest repo is <1MB. Git tags add no significant space. Docker registry may grow (multiple tags per image) but images are the same.

---

## Next Steps

1. **Review & Discuss** this proposal
2. **Assign owner** for implementation
3. **Create Azure DevOps tasks** for each phase
4. **Schedule** implementation sprints
5. **Plan** team training session

---

*Ready to proceed with implementation?*
