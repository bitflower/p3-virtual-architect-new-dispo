#!/bin/bash

# Script to fetch and pull master/main branches in all repos inside Code folder

echo "Updating all repositories in Code folder..."
echo "============================================"

# Navigate to the Code directory
cd "Code" || exit 1

# Loop through all subdirectories
for dir in */; do
    # Remove trailing slash
    repo_name="${dir%/}"

    echo ""
    echo "Processing: $repo_name"
    echo "----------------------------------------"

    # Check if it's a git repository
    if [ -d "$repo_name/.git" ]; then
        cd "$repo_name" || continue

        # Fetch all remotes
        echo "Fetching..."
        git fetch --all

        # Determine if the repo uses 'master' or 'main'
        if git show-ref --verify --quiet refs/heads/master; then
            branch="master"
        elif git show-ref --verify --quiet refs/heads/main; then
            branch="main"
        else
            echo "⚠️  Neither 'master' nor 'main' branch found, skipping..."
            cd ..
            continue
        fi

        echo "Checking out and pulling $branch branch..."
        git checkout "$branch"
        git pull origin "$branch"

        echo "✓ Done with $repo_name"

        cd ..
    else
        echo "⚠️  Not a git repository, skipping..."
    fi
done

echo ""
echo "============================================"
echo "All repositories updated!"
