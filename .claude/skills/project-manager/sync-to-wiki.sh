#!/bin/bash

# Sync Project Status to Wiki
# Uses publish-mappings.json for source-to-target mapping

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MAPPINGS_FILE="$PROJECT_ROOT/.claude/skills/wiki-connector/publish-mappings.json"

sync_project_to_wiki() {
    local source_file="$1"

    if [ ! -f "$source_file" ]; then
        echo "Error: Source file not found: $source_file"
        exit 1
    fi

    if [ ! -f "$MAPPINGS_FILE" ]; then
        echo "Error: Mappings file not found: $MAPPINGS_FILE"
        exit 1
    fi

    # Make source file relative to PROJECT_ROOT
    local rel_source=$(realpath --relative-to="$PROJECT_ROOT" "$source_file" 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$source_file', '$PROJECT_ROOT'))")

    # Find mapping in JSON
    local target_path=$(python3 -c "
import json
import sys

with open('$MAPPINGS_FILE', 'r') as f:
    data = json.load(f)

for mapping in data['mappings']:
    if mapping['source'] == '$rel_source':
        print(mapping['target'])
        sys.exit(0)

sys.exit(1)
" 2>/dev/null)

    if [ -z "$target_path" ]; then
        echo "Error: No mapping found for: $rel_source"
        echo "Please add mapping to: $MAPPINGS_FILE"
        exit 1
    fi

    local target_file="$PROJECT_ROOT/$target_path"
    local target_dir=$(dirname "$target_file")

    # Create target directory if needed
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    fi

    echo "Syncing project to wiki..."
    echo "  Source: $rel_source"
    echo "  Target: $target_path"

    # Copy content and transform links
    # Transform wiki links from relative to wiki-internal paths
    # Remove internal exploration links
    python3 - "$source_file" "$target_file" <<'PYTHON_SCRIPT'
import sys
import re

source_path = sys.argv[1]
target_path = sys.argv[2]

with open(source_path, 'r') as f:
    content = f.read()

# Transform wiki links from ../../../WIKI/Nagel-CAL-Disposition.wiki/Path to wiki-relative Path
content = re.sub(r'\[([^\]]+)\]\(\.\./\.\./\.\./WIKI/Nagel-CAL-Disposition\.wiki/([^)]+)\)', r'[\1](\2)', content)

# Remove links to internal exploration files (keep text, remove link)
# Pattern: [text](filename.md) where filename doesn't start with http or / or already transformed wiki path
content = re.sub(r'\[([^\]]+)\]\((?!http|/|#|[A-Z])([^)]+\.md)\)', r'\1', content)

# Remove "Details" and "Analysis" type links completely
content = re.sub(r' - \[(Details|Analysis|Link to .*)\]\([^)]+\)', '', content)

# Write to target
with open(target_path, 'w') as f:
    f.write(content)

print(f"✓ Transformed and wrote to: {target_path}")
PYTHON_SCRIPT

    echo ""
    echo "✓ Sync completed"
    echo ""
    echo "Next steps:"
    echo "  1. Review wiki file: $target_file"
    echo "  2. cd WIKI/Nagel-CAL-Disposition.wiki"
    echo "  3. git add Projects/"
    echo "  4. git commit -m 'Update project status: [description]'"
    echo "  5. git push"
}

# Main
if [ -z "$1" ]; then
    echo "Usage: sync-to-wiki.sh <project-status-file>"
    echo "Example: sync-to-wiki.sh PROJECT-STATUS.md"
    exit 1
fi

sync_project_to_wiki "$1"
