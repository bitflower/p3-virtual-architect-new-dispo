# Automated Versioning for High-Frequency Releases

For test environments with 10+ releases per day, manual tagging is too tedious. Here are automation options.

---

## Problem

Manual workflow:
```bash
# Developer has to do this 10+ times per day
git tag v1.2.3
git push origin v1.2.3
```

This is error-prone and slows down development velocity.

---

## Solution Options

### Option 1: Auto-Tag on Merge to Main (Recommended)

**Trigger**: Merge to `main` branch automatically creates a tag and releases.

#### Implementation

**Modify Azure Pipeline**: `azure-pipelines-cloudrun-t-t.yml`

```yaml
trigger:
  branches:
    include:
      - main  # Trigger on every push to main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - name: ComponentName
    value: 'disposition-backend'
  # ... other variables

stages:
  - stage: Build
    jobs:
      - job: BuildJob
        steps:
          # Auto-generate version from Build.BuildNumber
          - task: PowerShell@2
            displayName: 'Generate version from build number'
            name: version
            inputs:
              targetType: 'inline'
              script: |
                # Generate semantic version
                $major = 0
                $minor = $(Get-Date -Format "yy")  # Year as minor (e.g., 26)
                $patch = "$(Build.BuildNumber)"     # Build number as patch

                $version = "$major.$minor.$patch"
                $commit = "$(Build.SourceVersion)".Substring(0, 7)

                Write-Host "Auto-generated version: $version"

                Write-Host "##vso[task.setvariable variable=VERSION;isOutput=true]$version"
                Write-Host "##vso[task.setvariable variable=COMMIT;isOutput=true]$commit"

          # Create Git tag automatically
          - task: Bash@3
            displayName: 'Auto-create Git tag'
            inputs:
              targetType: 'inline'
              script: |
                set -e

                VERSION=$(version.VERSION)

                git config user.email "azure-pipelines@cal-consult.com"
                git config user.name "Azure Pipelines"

                # Tag with v prefix
                git tag "v${VERSION}" || echo "Tag already exists"
                git push origin "v${VERSION}" || echo "Tag push failed (may already exist)"
            env:
              SYSTEM_ACCESSTOKEN: $(System.AccessToken)

          # ... rest of pipeline (build, push, bump system version, etc.)
```

#### Developer Workflow

```bash
# Developer just merges to main
git checkout -b feature/my-feature
# ... make changes ...
git commit -m "Add new feature"
git push origin feature/my-feature

# Create PR → Approve → Merge to main
# ✅ Pipeline automatically:
#    - Generates version (e.g., 0.26.1234)
#    - Creates Git tag (v0.26.1234)
#    - Builds & deploys
#    - Bumps system version
```

**Benefits**:
- ✅ Zero manual tagging
- ✅ Works for 100+ releases/day
- ✅ Version = year + build number (sortable, unique)

**Version Format**: `0.{year}.{build-number}`
- Example: `0.26.1234` (year 2026, build 1234)

---

### Option 2: Semantic Version from Commit Messages

**Trigger**: Parse commit messages to determine version bump type.

#### Commit Message Convention

```bash
# BREAKING CHANGE → major bump (1.0.0 → 2.0.0)
git commit -m "feat!: redesign API"

# feat: → minor bump (1.0.0 → 1.1.0)
git commit -m "feat: add new endpoint"

# fix: → patch bump (1.0.0 → 1.0.1)
git commit -m "fix: correct validation"

# chore: → no bump (just build)
git commit -m "chore: update dependencies"
```

#### Implementation

**Add to pipeline** (before build):

```yaml
- task: PowerShell@2
  displayName: 'Calculate semantic version'
  name: version
  inputs:
    targetType: 'inline'
    script: |
      # Get last tag
      $lastTag = git describe --tags --abbrev=0 2>$null
      if ([string]::IsNullOrEmpty($lastTag)) {
        $lastTag = "v0.0.0"
      }

      # Parse version
      $lastTag = $lastTag -replace "^v", ""
      $parts = $lastTag -split "\."
      $major = [int]$parts[0]
      $minor = [int]$parts[1]
      $patch = [int]$parts[2]

      # Get commits since last tag
      $commits = git log --oneline "$lastTag..HEAD"

      # Determine bump type
      $bumpType = "patch"  # default

      if ($commits -match "feat!:|BREAKING CHANGE") {
        $bumpType = "major"
      } elseif ($commits -match "feat:") {
        $bumpType = "minor"
      }

      # Bump version
      switch ($bumpType) {
        "major" { $major++; $minor=0; $patch=0 }
        "minor" { $minor++; $patch=0 }
        "patch" { $patch++ }
      }

      $newVersion = "$major.$minor.$patch"
      $commit = "$(Build.SourceVersion)".Substring(0, 7)

      Write-Host "Last version: $lastTag"
      Write-Host "Bump type: $bumpType"
      Write-Host "New version: $newVersion"

      Write-Host "##vso[task.setvariable variable=VERSION;isOutput=true]$newVersion"
      Write-Host "##vso[task.setvariable variable=COMMIT;isOutput=true]$commit"
```

#### Developer Workflow

```bash
# Developer uses conventional commits
git commit -m "feat: add user authentication"
git push origin main

# Pipeline automatically:
# - Detects "feat:" → minor bump
# - Creates tag v1.1.0
# - Releases
```

**Benefits**:
- ✅ Semantic versioning
- ✅ Meaningful version numbers
- ✅ No manual tagging

**Drawbacks**:
- ⚠️ Requires commit message discipline
- ⚠️ More complex logic

---

### Option 3: Calendar Versioning (CalVer)

**Format**: `YYYY.MM.BUILD` (e.g., `2026.02.0034`)

```yaml
- task: PowerShell@2
  displayName: 'Generate CalVer version'
  name: version
  inputs:
    targetType: 'inline'
    script: |
      $year = Get-Date -Format "yyyy"
      $month = Get-Date -Format "MM"
      $build = "$(Build.BuildNumber)"

      # Pad build number
      $buildPadded = $build.PadLeft(4, '0')

      $version = "$year.$month.$buildPadded"
      $commit = "$(Build.SourceVersion)".Substring(0, 7)

      Write-Host "CalVer version: $version"

      Write-Host "##vso[task.setvariable variable=VERSION;isOutput=true]$version"
      Write-Host "##vso[task.setvariable variable=COMMIT;isOutput=true]$commit"
```

**Benefits**:
- ✅ Easy to understand (date-based)
- ✅ Sortable
- ✅ Works for any frequency

**Example**: `2026.02.0034` (34th build in Feb 2026)

---

### Option 4: Continuous Deployment (No Tags)

For rapid iteration in test environments, skip versioning entirely:

```yaml
variables:
  - name: ComponentVersion
    value: '0.0.$(Build.BuildNumber)-alpha'

# No Git tags, just build numbers
# Docker tags: disposition-backend:0.0.1234-alpha
```

**Use For**:
- Test/dev environments
- Frequent iterations
- No need for version tracking

**Developer Workflow**:
```bash
# Just push to main
git push origin main
# Automatically deploys with build number
```

---

## Comparison Matrix

| Option | Complexity | Frequency | Version Format | Manual Work |
|--------|-----------|-----------|----------------|-------------|
| **Manual Tags** | Low | 1-5/day | v1.2.3 | High |
| **Auto-Tag on Merge** | Low | Unlimited | 0.26.1234 | None |
| **Conventional Commits** | Medium | Unlimited | 1.2.3 | Low (commits) |
| **CalVer** | Low | Unlimited | 2026.02.0034 | None |
| **Build Numbers Only** | Very Low | Unlimited | 0.0.1234-alpha | None |

---

## Recommendation for Test Environment (10+ releases/day)

### Use Option 1: Auto-Tag on Merge

**Why**:
- ✅ Simple to implement
- ✅ Works for any frequency
- ✅ Zero developer overhead
- ✅ Versions are unique and sortable
- ✅ Still provides past resolution

**Version Format**: `0.{year}.{build-number}`
- `0.26.1` = First build in 2026
- `0.26.2` = Second build in 2026
- `0.26.1000` = 1000th build in 2026

### Workflow

```
Developer → Push to main
           ↓
        Azure Pipeline
           ↓
    Auto-generate version (0.26.1234)
           ↓
    Create Git tag (v0.26.1234)
           ↓
    Build & Deploy
           ↓
    Bump system version
           ↓
    ✅ Done (no manual steps)
```

---

## Production Environment

For production, keep **manual tagging** for control:

```yaml
# Production pipeline
trigger: none  # No auto-trigger

# Only runs on tags matching pattern
trigger:
  tags:
    include:
      - v*.*.*  # Matches v1.2.3
```

Developer manually creates semantic version tags:
```bash
# Production release (manual)
git tag v1.2.3
git push origin v1.2.3
```

This gives you:
- **Test**: Automatic, high-frequency (auto-tag on merge)
- **Production**: Manual, controlled (explicit tags)

---

## Migration Path

### Week 1: Keep Manual Tagging
- Test the system with manual tags
- Get team comfortable

### Week 2: Enable Auto-Tagging for Test
- Modify test environment pipeline
- Keep production manual

### Week 3: Full Automation
- Auto-tag on every merge to test environment
- Manual tags for production releases

---

## Summary

**For 10+ releases/day**: Use **auto-tag on merge** with build numbers.

**No manual work needed**:
1. Developer merges PR → main
2. Pipeline auto-generates version
3. Pipeline creates Git tag
4. System version bumps automatically
5. Everything tracked and traceable

**Version format**: `0.26.1234` (year.build)
- Still get all benefits (past resolution, system versions, tracking)
- Zero overhead for developers
- Works for 100+ releases per day
