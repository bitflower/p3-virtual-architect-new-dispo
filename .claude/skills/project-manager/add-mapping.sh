#!/bin/bash

# Add Project Mapping to publish-mappings.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MAPPINGS_FILE="$PROJECT_ROOT/.claude/skills/wiki-connector/publish-mappings.json"

add_mapping() {
    local id="$1"
    local source="$2"
    local target="$3"
    local description="$4"

    if [ ! -f "$MAPPINGS_FILE" ]; then
        echo "Error: Mappings file not found: $MAPPINGS_FILE"
        exit 1
    fi

    # Add mapping using Python
    python3 - "$id" "$source" "$target" "$description" <<'PYTHON_SCRIPT'
import json
import sys

mapping_id = sys.argv[1]
source_path = sys.argv[2]
target_path = sys.argv[3]
description = sys.argv[4]

mappings_file = sys.argv[0].replace('/dev/fd/', '/proc/self/fd/')  # Handle stdin
with open("$MAPPINGS_FILE", 'r') as f:
    data = json.load(f)

# Check if mapping already exists
for mapping in data['mappings']:
    if mapping['id'] == mapping_id:
        print(f"Mapping already exists: {mapping_id}")
        sys.exit(0)

# Add new mapping
new_mapping = {
    "id": mapping_id,
    "source": source_path,
    "target": target_path,
    "description": description,
    "syncStrategy": {
        "type": "full-sync",
        "scope": "full-document",
        "template": "wiki",
        "dateMarkers": {
            "enabled": False
        },
        "linkRewriting": {
            "enabled": True,
            "removeInternalLinks": True,
            "rewriteToWikiPaths": True
        },
        "notes": "Living project document - sync from exploration folder to wiki, rewrite internal links to wiki paths"
    }
}

data['mappings'].append(new_mapping)

# Write back
with open("$MAPPINGS_FILE", 'w') as f:
    json.dump(data, f, indent=2)

print(f"✓ Added mapping: {mapping_id}")
PYTHON_SCRIPT

    # Fix the Python script to use proper file path
    local temp_script="/tmp/add-mapping-$$.py"
    cat > "$temp_script" <<PYTHON_SCRIPT
import json
import sys

mapping_id = sys.argv[1]
source_path = sys.argv[2]
target_path = sys.argv[3]
description = sys.argv[4]
mappings_file = "$MAPPINGS_FILE"

with open(mappings_file, 'r') as f:
    data = json.load(f)

# Check if mapping already exists
for mapping in data['mappings']:
    if mapping['id'] == mapping_id:
        print(f"Mapping already exists: {mapping_id}")
        sys.exit(0)

# Add new mapping
new_mapping = {
    "id": mapping_id,
    "source": source_path,
    "target": target_path,
    "description": description,
    "syncStrategy": {
        "type": "full-sync",
        "scope": "full-document",
        "template": "wiki",
        "dateMarkers": {
            "enabled": False
        },
        "linkRewriting": {
            "enabled": True,
            "removeInternalLinks": True,
            "rewriteToWikiPaths": True
        },
        "notes": "Living project document - sync from exploration folder to wiki, rewrite internal links to wiki paths"
    }
}

data['mappings'].append(new_mapping)

# Write back
with open(mappings_file, 'w') as f:
    json.dump(data, f, indent=2)

print(f"✓ Added mapping: {mapping_id}")
PYTHON_SCRIPT

    python3 "$temp_script" "$id" "$source" "$target" "$description"
    rm "$temp_script"
}

# Main
if [ $# -ne 4 ]; then
    echo "Usage: add-mapping.sh <id> <source> <target> <description>"
    exit 1
fi

add_mapping "$1" "$2" "$3" "$4"
