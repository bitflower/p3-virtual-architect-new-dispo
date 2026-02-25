#!/bin/bash

# Skill: explore
# Description: Start a new exploration with proper folder structure and template
# Usage: /explore <topic description>
# Example: /explore User Story 12345: Database performance analysis

set -e

# Get the exploration topic from arguments
TOPIC="$*"

if [ -z "$TOPIC" ]; then
    echo "Error: Please provide a topic for the exploration"
    echo "Usage: /explore <topic description>"
    echo "Example: /explore User Story 12345: Database performance analysis"
    exit 1
fi

# Get current date in format YYYY-MM-DD
CURRENT_DATE=$(date +%Y-%m-%d)

# Get the directory where this skill is located
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find project root (look for .git directory)
PROJECT_ROOT="$SKILL_DIR"
while [ "$PROJECT_ROOT" != "/" ]; do
    if [ -d "$PROJECT_ROOT/.git" ]; then
        break
    fi
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "Error: Could not find project root (no .git directory found)"
    exit 1
fi

# Clean up topic for folder name (remove special characters, limit length)
FOLDER_TOPIC=$(echo "$TOPIC" | sed 's/[^a-zA-Z0-9 _-]//g' | sed 's/ /_/g' | cut -c1-80)

# Create folder name: date + topic
FOLDER_NAME="${CURRENT_DATE}_${FOLDER_TOPIC}"
EXPLORATION_DIR="${PROJECT_ROOT}/02_Explorations/${FOLDER_NAME}"

# Check if directory already exists
if [ -d "$EXPLORATION_DIR" ]; then
    echo "Warning: Exploration directory already exists: $EXPLORATION_DIR"
    echo "Using existing directory."
else
    # Create the exploration directory
    mkdir -p "$EXPLORATION_DIR"
    echo "✓ Created directory: $EXPLORATION_DIR"
fi

# Create the markdown file name (lowercase with hyphens)
MD_FILENAME=$(echo "$FOLDER_TOPIC" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
MD_FILE="${EXPLORATION_DIR}/${MD_FILENAME}.md"

# Check if file already exists
if [ -f "$MD_FILE" ]; then
    echo "Error: Markdown file already exists: $MD_FILE"
    echo "Please use a different topic or delete the existing file."
    exit 1
fi

TEMPLATE_FILE="${SKILL_DIR}/template.md"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found at: $TEMPLATE_FILE"
    exit 1
fi

# Create the markdown file from template
# Replace placeholders in the template
sed -e "s|{{TITLE}}|${TOPIC}|g" \
    -e "s|{{DATE}}|${CURRENT_DATE}|g" \
    "$TEMPLATE_FILE" > "$MD_FILE"

echo "✓ Created markdown file: $MD_FILE"
echo ""
echo "📁 Exploration ready at: $EXPLORATION_DIR"
echo ""
echo "Next steps:"
echo "1. Open the file: $MD_FILE"
echo "2. Replace the 'Original User Input' section with your actual content"
echo "3. Fill in the relevant template sections as you explore"
echo ""
echo "Remember: Always keep your original input at the top of the document!"
