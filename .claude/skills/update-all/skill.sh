#!/bin/bash

# Update All Repositories and Wikis Script
# Runs update-repos and update-wikis in parallel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

UPDATE_REPOS_SCRIPT="$SKILLS_DIR/update-repos/update-repos.sh"
UPDATE_WIKIS_SCRIPT="$SKILLS_DIR/update-wikis/update-wikis.sh"

echo "═══════════════════════════════════════════════════════════"
echo "  Updating All Repositories and Wikis (Parallel)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if scripts exist
if [ ! -f "$UPDATE_REPOS_SCRIPT" ]; then
    echo "⚠️  Update repos script not found: $UPDATE_REPOS_SCRIPT"
    exit 1
fi

if [ ! -f "$UPDATE_WIKIS_SCRIPT" ]; then
    echo "⚠️  Update wikis script not found: $UPDATE_WIKIS_SCRIPT"
    exit 1
fi

# Create temporary files for capturing output
REPOS_OUTPUT=$(mktemp)
WIKIS_OUTPUT=$(mktemp)
REPOS_EXIT=$(mktemp)
WIKIS_EXIT=$(mktemp)

# Cleanup function
cleanup() {
    rm -f "$REPOS_OUTPUT" "$WIKIS_OUTPUT" "$REPOS_EXIT" "$WIKIS_EXIT"
}
trap cleanup EXIT

# Function to run update-repos
run_repos_update() {
    if bash "$UPDATE_REPOS_SCRIPT" > "$REPOS_OUTPUT" 2>&1; then
        echo "0" > "$REPOS_EXIT"
    else
        echo "$?" > "$REPOS_EXIT"
    fi
}

# Function to run update-wikis
run_wikis_update() {
    if bash "$UPDATE_WIKIS_SCRIPT" > "$WIKIS_OUTPUT" 2>&1; then
        echo "0" > "$WIKIS_EXIT"
    else
        echo "$?" > "$WIKIS_EXIT"
    fi
}

echo "🚀 Starting parallel updates..."
echo ""

# Run both in parallel
run_repos_update &
REPOS_PID=$!

run_wikis_update &
WIKIS_PID=$!

# Wait for both to complete
wait $REPOS_PID
wait $WIKIS_PID

echo "═══════════════════════════════════════════════════════════"
echo "  Code Repositories Output"
echo "═══════════════════════════════════════════════════════════"
echo ""
cat "$REPOS_OUTPUT"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  Wiki Repositories Output"
echo "═══════════════════════════════════════════════════════════"
echo ""
cat "$WIKIS_OUTPUT"
echo ""

# Check exit codes
REPOS_STATUS=$(cat "$REPOS_EXIT")
WIKIS_STATUS=$(cat "$WIKIS_EXIT")

echo "═══════════════════════════════════════════════════════════"
echo "  Combined Update Summary"
echo "═══════════════════════════════════════════════════════════"

if [ "$REPOS_STATUS" -eq 0 ] && [ "$WIKIS_STATUS" -eq 0 ]; then
    echo "✓ Code repositories: SUCCESS"
    echo "✓ Wiki repositories: SUCCESS"
    echo ""
    echo "✓ All updates completed successfully!"
    exit 0
elif [ "$REPOS_STATUS" -ne 0 ] && [ "$WIKIS_STATUS" -ne 0 ]; then
    echo "⚠️  Code repositories: FAILED"
    echo "⚠️  Wiki repositories: FAILED"
    echo ""
    echo "⚠️  Both updates failed! Check output above for details."
    exit 1
elif [ "$REPOS_STATUS" -ne 0 ]; then
    echo "⚠️  Code repositories: FAILED"
    echo "✓ Wiki repositories: SUCCESS"
    echo ""
    echo "⚠️  Code update failed! Check output above for details."
    exit 1
else
    echo "✓ Code repositories: SUCCESS"
    echo "⚠️  Wiki repositories: FAILED"
    echo ""
    echo "⚠️  Wiki update failed! Check output above for details."
    exit 1
fi
