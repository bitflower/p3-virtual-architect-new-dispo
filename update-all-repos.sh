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

        # Special handling for TMS Database repo
        if [ "$repo_name" = "tms-alloydb-schema" ]; then
            # Look for branch matching pattern x.x.x.x+New-DISPO
            new_dispo_branch=$(git branch -r | grep -E 'origin/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\+New-DISPO' | sed 's/.*origin\///' | head -n 1)

            if [ -n "$new_dispo_branch" ]; then
                branch="$new_dispo_branch"
                echo "Found New-DISPO branch: $branch"
            elif git show-ref --verify --quiet refs/heads/master; then
                branch="master"
                echo "New-DISPO branch not found, falling back to master"
            elif git show-ref --verify --quiet refs/heads/main; then
                branch="main"
                echo "New-DISPO branch not found, falling back to main"
            else
                echo "⚠️  No suitable branch found, skipping..."
                cd ..
                continue
            fi
        else
            # Standard behavior for other repos: use 'master' or 'main'
            if git show-ref --verify --quiet refs/heads/master; then
                branch="master"
            elif git show-ref --verify --quiet refs/heads/main; then
                branch="main"
            else
                echo "⚠️  Neither 'master' nor 'main' branch found, skipping..."
                cd ..
                continue
            fi
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
