#!/bin/bash

# Update All Repositories Script
# Updates all git repositories in the Code folder

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
CODE_DIR="$PROJECT_ROOT/Code"

echo "═══════════════════════════════════════════════════════════"
echo "  Updating All Repositories in Code Folder"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ ! -d "$CODE_DIR" ]; then
    echo "⚠️  Code directory not found: $CODE_DIR"
    exit 1
fi

cd "$CODE_DIR"

# Track success/failure
declare -i SUCCESS_COUNT=0
declare -i FAIL_COUNT=0
declare -a FAILED_REPOS=()

for dir in */; do
    REPO_NAME="${dir%/}"

    if [ ! -d "$REPO_NAME/.git" ]; then
        echo "⊘ Skipping $REPO_NAME (not a git repository)"
        echo ""
        continue
    fi

    echo "───────────────────────────────────────────────────────────"
    echo "📦 Repository: $REPO_NAME"
    echo "───────────────────────────────────────────────────────────"

    cd "$REPO_NAME"

    # Fetch all remotes
    echo "↓ Fetching remotes..."
    if ! git fetch --all 2>&1 | sed 's/^/  /'; then
        echo "⚠️  Failed to fetch remotes for $REPO_NAME"
        FAIL_COUNT+=1
        FAILED_REPOS+=("$REPO_NAME")
        cd ..
        echo ""
        continue
    fi

    # Determine branch to use
    BRANCH=""

    if [ "$REPO_NAME" = "tms-alloydb-schema" ]; then
        # Look for x.x.x.x+New-DISPO pattern
        echo "🔍 Looking for New-DISPO branch pattern..."
        BRANCH=$(git branch -r | grep -E 'origin/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[+]New-DISPO' | head -n 1 | sed 's/.*origin\///' | xargs)

        if [ -z "$BRANCH" ]; then
            echo "  No New-DISPO branch found, checking for master/main..."
            if git rev-parse --verify origin/master >/dev/null 2>&1; then
                BRANCH="master"
            elif git rev-parse --verify origin/main >/dev/null 2>&1; then
                BRANCH="main"
            fi
        else
            echo "  ✓ Found branch: $BRANCH"
        fi
    else
        # For other repos, use master or main
        if git rev-parse --verify origin/master >/dev/null 2>&1; then
            BRANCH="master"
        elif git rev-parse --verify origin/main >/dev/null 2>&1; then
            BRANCH="main"
        fi
    fi

    if [ -z "$BRANCH" ]; then
        echo "⚠️  Could not determine branch for $REPO_NAME"
        FAIL_COUNT+=1
        FAILED_REPOS+=("$REPO_NAME")
        cd ..
        echo ""
        continue
    fi

    # Checkout and pull
    echo "→ Checking out branch: $BRANCH"
    if ! git checkout "$BRANCH" 2>&1 | sed 's/^/  /'; then
        echo "⚠️  Failed to checkout $BRANCH for $REPO_NAME"
        FAIL_COUNT+=1
        FAILED_REPOS+=("$REPO_NAME")
        cd ..
        echo ""
        continue
    fi

    echo "↓ Pulling latest changes..."
    if ! git pull origin "$BRANCH" 2>&1 | sed 's/^/  /'; then
        echo "⚠️  Failed to pull $BRANCH for $REPO_NAME"
        FAIL_COUNT+=1
        FAILED_REPOS+=("$REPO_NAME")
        cd ..
        echo ""
        continue
    fi

    echo "✓ Successfully updated $REPO_NAME"
    SUCCESS_COUNT+=1

    cd ..
    echo ""
done

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "  Update Summary"
echo "═══════════════════════════════════════════════════════════"
echo "✓ Success: $SUCCESS_COUNT"
echo "⚠️  Failed:  $FAIL_COUNT"

if [ $FAIL_COUNT -gt 0 ]; then
    echo ""
    echo "Failed repositories:"
    for repo in "${FAILED_REPOS[@]}"; do
        echo "  - $repo"
    done
    exit 1
fi

echo ""
echo "✓ All repositories updated successfully!"
