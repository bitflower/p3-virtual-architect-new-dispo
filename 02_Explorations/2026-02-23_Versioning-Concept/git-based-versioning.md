# Git-Based Versioning Analysis

## The Idea

Use Git commit hooks or Azure DevOps flows to bump versions and document them in Git history, instead of generating them only during pipeline builds.

## Benefits of Git-Based Versioning

| Benefit | Explanation |
|---------|-------------|
| **Git is source of truth** | No external dependency on Cloud Storage |
| **Version in history** | `git log` shows version progression |
| **Traceability** | Commit directly tied to version |
| **Simpler bug reports** | `git checkout v20260223.5` |
| **No Cloud Storage needed** | Git already replicated everywhere |

## Option A: Git Tags on Commit (Recommended)

**Concept:** Instead of committing version files, tag commits with version metadata.

### Implementation

```yaml
# In azure-pipelines-cloudrun-t-t.yml after successful deployment
- task: CmdLine@2
  displayName: 'Tag commit with version'
  inputs:
    script: |
      VERSION=$BUILD_BUILDNUMBER
      COMMIT=$(git rev-parse HEAD)

      git config user.email "azure-pipelines@calconsult.com"
      git config user.name "Azure Pipelines"

      # Create annotated tag with version metadata
      git tag -a "t-t/backend/${VERSION}" -m "Backend TEST deployment
      Version: ${VERSION}
      Commit: ${COMMIT}
      Build Date: $(date -u)
      Branch: ${BUILD_SOURCEBRANCHNAME}
      Build: ${BUILD_BUILDID}"

      git push origin "t-t/backend/${VERSION}"
```

### Git Tag Structure

```
Tags:
  t-t/backend/20260223.1
  t-t/backend/20260223.2
  t-t/backend/20260223.3
  t-t/frontend/20260223.1
  t-t/frontend/20260223.2
  t-t/tms-bridge/20260223.1
  p-p/backend/2.2.0
  p-p/frontend/2.2.0
```

### Bug Report Workflow

```bash
# User reports: "Bug in version 20260223.5"

# Checkout exact code
git checkout t-t/backend/20260223.5

# Or see what commit it was
git rev-list -n 1 t-t/backend/20260223.5

# See all deployments
git tag -l "t-t/backend/*"

# See deployments on a date
git tag -l "t-t/backend/20260223.*"
```

### Pros
- ✅ No file commits (clean history)
- ✅ Version in Git history
- ✅ Direct commit ↔ version mapping
- ✅ Simple `git checkout tag` for debugging
- ✅ No circular triggers
- ✅ No merge conflicts
- ✅ Works with existing Git tools

### Cons
- ❌ Requires Git push permissions from pipeline
- ❌ Many tags (10/day × 3 components = 30 tags/day)

---

## Option B: Auto-Bump on Merge to Branch

**Concept:** When PR merges to `develop`, pipeline bumps version in `.csproj`/`package.json` and commits back.

### Implementation

```yaml
# azure-pipelines-cloudrun-t-t.yml
trigger:
  branches:
    include:
    - develop

steps:
# After merge, before build
- task: CmdLine@2
  displayName: 'Auto-bump version'
  inputs:
    script: |
      # Generate version
      VERSION=$BUILD_BUILDNUMBER

      # Update .csproj
      sed -i "s/<Version>.*<\/Version>/<Version>${VERSION}<\/Version>/" \
        CALConsult.Disposition.API/CALConsult.Disposition.API.csproj

      # Commit back with [skip ci] to avoid loop
      git config user.email "azure-pipelines@calconsult.com"
      git config user.name "Azure Pipelines"
      git add CALConsult.Disposition.API/CALConsult.Disposition.API.csproj
      git commit -m "chore: bump version to ${VERSION} [skip ci]"
      git push origin develop

# Continue with build using new version
```

### Result in Git History

```
abc123d feat: add new feature
def456e chore: bump version to 20260223.5 [skip ci]
ghi789f feat: another feature
jkl012g chore: bump version to 20260223.6 [skip ci]
```

### Pros
- ✅ Version in Git history
- ✅ Version in .csproj (visible in IDE)
- ✅ [skip ci] prevents circular triggers

### Cons
- ❌ 10 extra commits/day for TEST (cluttered history)
- ❌ Potential merge conflicts on .csproj
- ❌ Requires Git push permissions
- ❌ Commit SHA changes after version bump (the bump commit is different from the code commit)

---

## Option C: Pre-Commit Hook (Developer Side)

**Concept:** Developers install Git hook that auto-bumps version on every commit.

### Implementation

```bash
# .git/hooks/pre-commit
#!/bin/bash

BRANCH=$(git branch --show-current)

# Only on non-PROD branches
if [[ "$BRANCH" != "main" ]] && [[ "$BRANCH" != "master" ]]; then
  # Generate version based on timestamp
  VERSION=$(date +%Y%m%d).$(git rev-list --count HEAD)

  # Update .csproj
  sed -i "s/<Version>.*<\/Version>/<Version>${VERSION}<\/Version>/" \
    CALConsult.Disposition.API/CALConsult.Disposition.API.csproj

  # Stage the change
  git add CALConsult.Disposition.API/CALConsult.Disposition.API.csproj
fi
```

### Pros
- ✅ Version committed with code change (single commit)
- ✅ No separate version commits
- ✅ Developer sees version in IDE

### Cons
- ❌ All developers must install hook
- ❌ Hook can fail or be bypassed
- ❌ Merge conflicts on .csproj
- ❌ Version not deterministic (depends on when developer commits)
- ❌ Hard to enforce

---

## Option D: Hybrid - Tags + Azure Commit

**Concept:** Best of both worlds.

1. **For TEST:** Git tags only (Option A)
2. **For PROD:** Manual version update in .csproj + Git tag

### Implementation

```yaml
# azure-pipelines.yml

# Always tag after deployment
- script: |
    if [[ "$BUILD_SOURCEBRANCHNAME" == "develop" ]]; then
      TAG_PREFIX="t-t"
      VERSION=$BUILD_BUILDNUMBER
    else
      TAG_PREFIX="p-p"
      VERSION=$(grep -oP '<Version>\K[^<]+' *.csproj)
    fi

    git tag -a "${TAG_PREFIX}/backend/${VERSION}" -m "Deployment"
    git push origin "${TAG_PREFIX}/backend/${VERSION}"
  displayName: 'Tag deployment'
```

### Pros
- ✅ Clean history (no version bump commits)
- ✅ Versions in Git (via tags)
- ✅ Simple for TEST (automatic)
- ✅ Semantic versions for PROD (manual)

### Cons
- ❌ Requires Git push permissions

---

## Comparison Table

| Aspect | Option A: Tags | Option B: Auto-Commit | Option C: Pre-Commit | Option D: Hybrid |
|--------|----------------|----------------------|---------------------|------------------|
| **Git history** | Clean | 10 extra commits/day | Clean | Clean |
| **Version in files** | No (runtime only) | Yes (.csproj) | Yes (.csproj) | No (runtime only) |
| **Merge conflicts** | Never | Possible | Possible | Never |
| **Setup complexity** | Low | Medium | High | Low |
| **Circular triggers** | No | [skip ci] needed | No | No |
| **Developer action** | None | None | Install hook | None |
| **Pipeline permissions** | Git push | Git push | None | Git push |
| **Bug report workflow** | `git checkout tag` | `git checkout commit` | `git checkout commit` | `git checkout tag` |

---

## Recommendation

### **Option A: Git Tags (Recommended)**

**Why:**
1. **Clean history** - No version bump commits cluttering Git log
2. **No conflicts** - Tags don't conflict with merges
3. **Simple bug reports** - `git checkout t-t/backend/20260223.5`
4. **Automatic** - No developer setup required
5. **Version in Git** - Satisfies "documented in Git" requirement

**Setup:**

```yaml
# Add to all three component pipelines after successful deployment

- task: CmdLine@2
  displayName: 'Tag deployment with version'
  condition: succeeded()
  inputs:
    script: |
      COMPONENT="backend"  # or "frontend", "tms-bridge"

      if [[ "$BUILD_SOURCEBRANCHNAME" == "main" ]] || [[ "$BUILD_SOURCEBRANCHNAME" == "master" ]]; then
        ENV="p-p"
        VERSION=$(grep -oP '<Version>\K[^<]+' *.csproj)
      else
        ENV="t-t"
        VERSION=$BUILD_BUILDNUMBER
      fi

      TAG="${ENV}/${COMPONENT}/${VERSION}"

      git config user.email "azure-pipelines@calconsult.com"
      git config user.name "Azure Pipelines"

      git tag -a "$TAG" -m "Deployment
      Environment: ${ENV}
      Component: ${COMPONENT}
      Version: ${VERSION}
      Commit: $(git rev-parse HEAD)
      Build Date: $(date -u)
      Build ID: ${BUILD_BUILDID}"

      git push origin "$TAG"
```

**Bug Report Workflow:**

```bash
# User: "Bug in version 20260223.5"

# Checkout exact code
git checkout t-t/backend/20260223.5

# Or get commit hash
git rev-list -n 1 t-t/backend/20260223.5

# List all TEST deployments today
git tag -l "t-t/backend/20260223.*"

# Show tag details
git show t-t/backend/20260223.5
```

**Tag cleanup (optional):**
```bash
# Delete old TEST tags after 90 days
git tag -l "t-t/*" | xargs -I {} bash -c \
  'git log -1 --format=%ai {} | grep -q "2025-11" && git push --delete origin {}'
```

---

## Addressing Concerns

### "No external dependency on Cloud Storage"

Git tags provide version history without Cloud Storage. However, Cloud Storage is still useful for:
- Storing the full version.json (with all metadata)
- Faster queries (gsutil vs git)

**Recommendation:** Use both:
- Git tags: Primary version tracking
- Cloud Storage: Backup + full metadata

### "10 deployments/day creates many tags"

Yes, but:
- Tags are lightweight (just pointers)
- Can be cleaned up periodically
- Better than 10 commits/day cluttering history

### "Git push permissions needed"

Pipeline needs permission to push tags:

```yaml
# In pipeline YAML
resources:
  repositories:
  - repository: self
    persistCredentials: true
```

Or use personal access token (PAT) with tag push permission.

---

## Final Recommendation

**Use Git Tags (Option A):**
1. No file commits → clean history
2. Version documented in Git → satisfies requirement
3. Simple bug reports → `git checkout tag`
4. No merge conflicts → tags don't conflict
5. Automatic → no developer action needed

**Plus optionally keep Cloud Storage** as backup/full metadata storage.

This gives you the best of both worlds:
- Git as source of truth (tags)
- Cloud Storage as convenient backup (optional)
- Clean Git history (no version bump commits)
