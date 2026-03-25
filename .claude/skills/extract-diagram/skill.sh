#!/usr/bin/env bash
set -euo pipefail

# extract-diagram.sh
# Extracts Mermaid diagrams from markdown files to 07_Diagrams/Architecture/
# Generates SVG and updates the original file to reference the diagram

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo"
DIAGRAMS_DIR="$PROJECT_ROOT/07_Diagrams/Architecture"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << 'EOF'
Usage: extract-diagram [OPTIONS] <source-markdown-file>

Extract Mermaid diagrams from a markdown file, create versioned diagram in
07_Diagrams/Architecture/, generate SVG, and update source file to reference it.

Options:
    -n, --name NAME         Diagram name (auto-generated from file if not provided)
    -t, --title TITLE       Diagram title (extracted from source if not provided)
    -h, --help             Show this help message

Arguments:
    source-markdown-file    Path to markdown file containing Mermaid diagram

Examples:
    extract-diagram 02_Explorations/2026-03-16_My-Flow/flow.md
    extract-diagram -n my-custom-name -t "My Custom Title" path/to/file.md

Process:
    1. Extract first Mermaid code block from source file
    2. Create diagram markdown in 07_Diagrams/Architecture/
    3. Generate SVG using mermaid-cli (mmdc)
    4. Replace original Mermaid block with SVG reference

Requirements:
    - Source file must contain at least one Mermaid code block (```mermaid)
    - Mermaid CLI must be installed: npm install -g @mermaid-js/mermaid-cli
EOF
    exit 1
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Parse arguments
DIAGRAM_NAME=""
DIAGRAM_TITLE=""
SOURCE_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            DIAGRAM_NAME="$2"
            shift 2
            ;;
        -t|--title)
            DIAGRAM_TITLE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            SOURCE_FILE="$1"
            shift
            ;;
    esac
done

# Validate source file
if [[ -z "$SOURCE_FILE" ]]; then
    error "Source markdown file is required"
fi

# Convert to absolute path if relative
if [[ ! "$SOURCE_FILE" = /* ]]; then
    SOURCE_FILE="$PROJECT_ROOT/$SOURCE_FILE"
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
    error "Source file not found: $SOURCE_FILE"
fi

info "Processing: $SOURCE_FILE"

# Check for mermaid-cli
if ! command -v mmdc &> /dev/null; then
    error "Mermaid CLI (mmdc) not found. Install with: npm install -g @mermaid-js/mermaid-cli"
fi

# Extract first mermaid block
MERMAID_BLOCK=$(awk '/```mermaid/,/```/ {print}' "$SOURCE_FILE" | sed '$d' | tail -n +2)

if [[ -z "$MERMAID_BLOCK" ]]; then
    error "No Mermaid diagram found in source file"
fi

info "Found Mermaid diagram ($(echo "$MERMAID_BLOCK" | wc -l) lines)"

# Auto-generate diagram name from source file if not provided
if [[ -z "$DIAGRAM_NAME" ]]; then
    # Get parent folder name and file name (without extension)
    PARENT_FOLDER=$(basename "$(dirname "$SOURCE_FILE")")
    FILE_NAME=$(basename "$SOURCE_FILE" .md)

    # Create name from folder + file (e.g., "2026-03-16_My-Flow_flow" -> "my-flow-flow")
    DIAGRAM_NAME=$(echo "${PARENT_FOLDER}_${FILE_NAME}" |
                   sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_//' | # Remove date prefix
                   tr '[:upper:]' '[:lower:]' | # Lowercase
                   tr '_' '-' | # Underscores to hyphens
                   sed 's/--*/-/g') # Collapse multiple hyphens
fi

info "Diagram name: $DIAGRAM_NAME"

# Auto-extract title from source file if not provided
if [[ -z "$DIAGRAM_TITLE" ]]; then
    # Try to find first heading
    DIAGRAM_TITLE=$(grep -m 1 '^# ' "$SOURCE_FILE" | sed 's/^# //' || echo "Diagram")
fi

info "Diagram title: $DIAGRAM_TITLE"

# Calculate relative path from source to diagrams directory
SOURCE_DIR=$(dirname "$SOURCE_FILE")
RELATIVE_PATH=$(python3 -c "import os.path; print(os.path.relpath('$DIAGRAMS_DIR', '$SOURCE_DIR'))")

# Create output files
DIAGRAM_MD_FILE="$DIAGRAMS_DIR/${DIAGRAM_NAME}.md"
DIAGRAM_SVG_FILE="$DIAGRAMS_DIR/${DIAGRAM_NAME}.svg"

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Get relative path from source to project root
SOURCE_REL_PATH="${SOURCE_FILE#$PROJECT_ROOT/}"

# Create diagram markdown file
info "Creating diagram file: $DIAGRAM_MD_FILE"

cat > "$DIAGRAM_MD_FILE" << EOF
# ${DIAGRAM_TITLE}

**Date:** ${CURRENT_DATE}
**Version:** 1.0
**Status:** Verified
**Source:** [${SOURCE_REL_PATH}](../../${SOURCE_REL_PATH})

---

## Overview

Extracted diagram from the source documentation.

---

## Diagram

\`\`\`mermaid
${MERMAID_BLOCK}
\`\`\`

---

## Related Documentation

- **Source Documentation:** [${SOURCE_REL_PATH}](../../${SOURCE_REL_PATH})
- **Other Diagrams:** [07_Diagrams/](../)
EOF

success "Created: $DIAGRAM_MD_FILE"

# Generate SVG
info "Generating SVG..."
cd "$DIAGRAMS_DIR"
mmdc -i "${DIAGRAM_NAME}.md" -o "${DIAGRAM_NAME}-1.svg" -b transparent

# Rename generated SVG (mmdc adds -1 suffix)
if [[ -f "${DIAGRAM_NAME}-1.svg" ]]; then
    mv "${DIAGRAM_NAME}-1.svg" "${DIAGRAM_NAME}.svg"
    success "Generated: $DIAGRAM_SVG_FILE"
else
    error "SVG generation failed"
fi

# Update source file - replace mermaid block with SVG reference
info "Updating source file to reference SVG..."

# Create temporary file for the updated content
TEMP_FILE=$(mktemp)

# Python script to replace the mermaid block
python3 << EOF > "$TEMP_FILE"
import re
import sys

with open("$SOURCE_FILE", 'r') as f:
    content = f.read()

# Pattern to match the mermaid code block and its preceding header (if any)
# Captures optional header line before mermaid block
pattern = r'(^##? .*(?:Diagram|Flow|Architecture|Chart).*\n\n)?```mermaid\n.*?```'

replacement = r'''\1![${DIAGRAM_TITLE}](${RELATIVE_PATH}/${DIAGRAM_NAME}.svg)

**Source:** [${RELATIVE_PATH}/${DIAGRAM_NAME}.md](${RELATIVE_PATH}/${DIAGRAM_NAME}.md)'''

# Replace first occurrence
updated_content = re.sub(pattern, replacement, content, count=1, flags=re.DOTALL | re.MULTILINE)

if updated_content == content:
    print("WARNING: No replacement made - pattern might not match", file=sys.stderr)
    sys.exit(1)

print(updated_content, end='')
EOF

if [[ $? -eq 0 ]]; then
    # Backup original file
    cp "$SOURCE_FILE" "${SOURCE_FILE}.bak"
    mv "$TEMP_FILE" "$SOURCE_FILE"
    success "Updated source file (backup: ${SOURCE_FILE}.bak)"
else
    rm -f "$TEMP_FILE"
    warn "Could not automatically update source file"
    warn "Please manually replace the Mermaid block with:"
    echo ""
    echo "![${DIAGRAM_TITLE}](${RELATIVE_PATH}/${DIAGRAM_NAME}.svg)"
    echo ""
    echo "**Source:** [${RELATIVE_PATH}/${DIAGRAM_NAME}.md](${RELATIVE_PATH}/${DIAGRAM_NAME}.md)"
    echo ""
fi

# Summary
echo ""
success "Diagram extraction complete!"
echo ""
echo "Files created:"
echo "  - $DIAGRAM_MD_FILE"
echo "  - $DIAGRAM_SVG_FILE"
echo ""
echo "To update the diagram in the future:"
echo "  1. Edit: $DIAGRAM_MD_FILE"
echo "  2. Regenerate: cd \"$DIAGRAMS_DIR\" && mmdc -i ${DIAGRAM_NAME}.md -o ${DIAGRAM_NAME}.svg -b transparent"
echo ""
