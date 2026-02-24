#!/bin/bash

# Script to list all files touched by a user with the branches where changes occurred
# Usage: ./git-user-files-branches.sh <author> <since-date> <until-date>

set -e

# Function to display usage
usage() {
    echo "Usage: $0 <author> [<since-date>] [<until-date>]"
    echo ""
    echo "Arguments:"
    echo "  author       Git author name or email (required)"
    echo "  since-date   Start date in YYYY-MM-DD format (default: 2025-01-01)"
    echo "  until-date   End date in YYYY-MM-DD format (default: today)"
    echo ""
    echo "Examples:"
    echo "  $0 sonjapetkovicP3"
    echo "  $0 sonjapetkovicP3 2025-01-01 2025-11-17"
    echo "  $0 john.doe@example.com 2025-06-01"
    exit 1
}

# Check if author is provided
if [ -z "$1" ]; then
    echo "Error: Author name is required"
    usage
fi

AUTHOR="$1"
SINCE="${2:-2025-01-01}"
UNTIL="${3:-$(date +%Y-%m-%d)}"

# Create output filename
OUTPUT_FILE="git-files-${AUTHOR}-${SINCE}_${UNTIL}.md"

echo "Analyzing commits by: $AUTHOR"
echo "Date range: $SINCE to $UNTIL"
echo "Output file: $OUTPUT_FILE"
echo ""

# Create temporary file for commits
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Get all commits by author in date range
git log \
  --author="$AUTHOR" \
  --since="$SINCE" \
  --until="$UNTIL" \
  --no-merges \
  --pretty=format:"%H" > "$TEMP_FILE"

# Process commits with Python
python3 -c "
import subprocess
from collections import defaultdict
from datetime import datetime

file_branches = defaultdict(set)

with open('$TEMP_FILE', 'r') as f:
    commits = [line.strip() for line in f if line.strip()]

if not commits:
    print('No commits found for author \"$AUTHOR\" in the specified date range.')
    exit(0)

print(f'Processing {len(commits)} commits...', flush=True)

for idx, commit in enumerate(commits):
    if not commit:
        continue

    if (idx + 1) % 10 == 0:
        print(f'Processed {idx + 1}/{len(commits)} commits...', flush=True)

    # Get branches containing this commit
    try:
        branch_output = subprocess.check_output(
            ['git', 'branch', '-a', '--contains', commit],
            stderr=subprocess.DEVNULL,
            text=True
        )
        branches = set()
        for line in branch_output.split('\n'):
            line = line.strip().lstrip('* ')
            if line and 'HEAD' not in line:
                # Remove remotes/origin/ prefix
                branch = line.replace('remotes/origin/', '')
                branches.add(branch)
    except Exception as e:
        print(f'Error getting branches for {commit}: {e}', flush=True)
        branches = set()

    # Get files in this commit
    try:
        file_output = subprocess.check_output(
            ['git', 'show', '--pretty=', '--name-only', commit],
            stderr=subprocess.DEVNULL,
            text=True
        )
        for file in file_output.split('\n'):
            file = file.strip()
            if file:
                file_branches[file].update(branches)
    except Exception as e:
        print(f'Error getting files for {commit}: {e}', flush=True)

print(f'\nFound {len(file_branches)} unique files')
print(f'Writing results to $OUTPUT_FILE\n')

# Write markdown file
with open('$OUTPUT_FILE', 'w') as f:
    # Write header
    f.write('# Git Files Analysis\n\n')
    f.write(f'**Author:** $AUTHOR\n\n')
    f.write(f'**Date Range:** $SINCE to $UNTIL\n\n')
    f.write(f'**Total Commits:** {len(commits)}\n\n')
    f.write(f'**Total Files:** {len(file_branches)}\n\n')
    f.write(f'**Generated:** {datetime.now().strftime(\"%Y-%m-%d %H:%M:%S\")}\n\n')
    f.write('---\n\n')

    # Write table header
    f.write('| # | File | Branches |\n')
    f.write('|---|------|----------|\n')

    # Write table rows
    for idx, file in enumerate(sorted(file_branches.keys()), 1):
        branches_list = ', '.join(sorted(file_branches[file]))
        # Escape pipe characters in file paths and branch names for markdown
        file_escaped = file.replace('|', r'\|')
        branches_escaped = branches_list.replace('|', r'\|')
        f.write(f'| {idx} | {file_escaped} | {branches_escaped} |\n')

print(f'✓ Results written to $OUTPUT_FILE')
"
