#!/bin/bash

# Update All Wiki Repositories Script
# Updates all git repositories in the WIKI folder

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WIKI_DIR="$PROJECT_ROOT/WIKI"

echo "═══════════════════════════════════════════════════════════"
echo "  Updating All Wiki Repositories"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ ! -d "$WIKI_DIR" ]; then
    echo "⚠️  WIKI directory not found: $WIKI_DIR"
    exit 1
fi

cd "$WIKI_DIR"

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
    echo "📚 Wiki: $REPO_NAME"
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

    # Determine branch (wikiMaster, master, or main)
    BRANCH=""
    if git rev-parse --verify origin/wikiMaster >/dev/null 2>&1; then
        BRANCH="wikiMaster"
    elif git rev-parse --verify origin/master >/dev/null 2>&1; then
        BRANCH="master"
    elif git rev-parse --verify origin/main >/dev/null 2>&1; then
        BRANCH="main"
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
    echo "Failed wiki repositories:"
    for repo in "${FAILED_REPOS[@]}"; do
        echo "  - $repo"
    done
    exit 1
fi

echo ""
echo "✓ All wiki repositories updated successfully!"
