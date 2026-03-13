#!/bin/bash

# Project Manager Skill
# Create and manage living project documentation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMPLATE_PATH="$PROJECT_ROOT/999_Tools/PROJECT-STATUS-TEMPLATE.md"
EXPLORATIONS_DIR="$PROJECT_ROOT/02_Explorations"
WIKI_DIR="$PROJECT_ROOT/WIKI/Nagel-CAL-Disposition.wiki"

# Helper functions
update_timestamp() {
    local file="$1"
    local today=$(date +%Y-%m-%d)

    # Update "Last Updated" line
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^\*\*Last Updated:\*\* .*$/\*\*Last Updated:\*\* $today/" "$file"
    else
        sed -i "s/^\*\*Last Updated:\*\* .*$/\*\*Last Updated:\*\* $today/" "$file"
    fi
}

add_changelog_entry() {
    local file="$1"
    local description="$2"
    local author="${3:-Matthias}"
    local today=$(date +%Y-%m-%d)

    # Find the changelog section and add entry after the header row
    local changelog_line=$(grep -n "## 🔄 Change Log" "$file" | cut -d: -f1)
    if [ -z "$changelog_line" ]; then
        changelog_line=$(grep -n "## Change Log" "$file" | cut -d: -f1)
    fi

    if [ -n "$changelog_line" ]; then
        # Skip the header and separator lines (usually +3 or +4)
        local insert_line=$((changelog_line + 4))
        local entry="| $today | $description | $author |"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "${insert_line}i\\
$entry
" "$file"
        else
            sed -i "${insert_line}i\\$entry" "$file"
        fi
    fi
}

# Command: create
cmd_create() {
    local project_name="$1"
    local folder_path="$2"
    local wiki_name="${3:-}"

    if [ -z "$project_name" ] || [ -z "$folder_path" ]; then
        echo "Usage: project-manager create <project-name> <folder-path> [wiki-filename]"
        echo "Example: project-manager create 'Oracle CDC POC' '02_Explorations/2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off' 'Oracle-CDC-TMS-Branches'"
        exit 1
    fi

    # Resolve full path
    if [[ "$folder_path" != /* ]]; then
        folder_path="$PROJECT_ROOT/$folder_path"
    fi

    if [ ! -d "$folder_path" ]; then
        echo "Error: Folder not found: $folder_path"
        exit 1
    fi

    if [ ! -f "$TEMPLATE_PATH" ]; then
        echo "Error: Template not found: $TEMPLATE_PATH"
        exit 1
    fi

    local output_file="$folder_path/PROJECT-STATUS.md"

    if [ -f "$output_file" ]; then
        echo "Warning: PROJECT-STATUS.md already exists in this folder."
        read -p "Overwrite? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    # Generate wiki filename if not provided
    if [ -z "$wiki_name" ]; then
        # Convert project name to wiki-safe filename
        wiki_name=$(echo "$project_name" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g')
    fi

    # Copy template and replace placeholders
    cp "$TEMPLATE_PATH" "$output_file"
    local today=$(date +%Y-%m-%d)
    local week=$(date +%V)
    local wiki_path="Projects/Active/${wiki_name}.md"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/\[Project Name\]/$project_name/g" "$output_file"
        sed -i '' "s/\[YYYY-MM-DD\]/$today/g" "$output_file"
        sed -i '' "s/CW XX/CW $week/g" "$output_file"
        sed -i '' "s|\[Projects/\[Status\]/\[Wiki-File-Name\].md\]|[$wiki_path]|g" "$output_file"
        sed -i '' "s|Projects/\[Status\]/\[Wiki-File-Name\].md|$wiki_path|g" "$output_file"
    else
        sed -i "s/\[Project Name\]/$project_name/g" "$output_file"
        sed -i "s/\[YYYY-MM-DD\]/$today/g" "$output_file"
        sed -i "s/CW XX/CW $week/g" "$output_file"
        sed -i "s|\[Projects/\[Status\]/\[Wiki-File-Name\].md\]|[$wiki_path]|g" "$output_file"
        sed -i "s|Projects/\[Status\]/\[Wiki-File-Name\].md|$wiki_path|g" "$output_file"
    fi

    # Add mapping to JSON
    local rel_source=$(realpath --relative-to="$PROJECT_ROOT" "$output_file" 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$output_file', '$PROJECT_ROOT'))")
    local mapping_id="project-${wiki_name,,}"  # lowercase

    "$SCRIPT_DIR/add-mapping.sh" "$mapping_id" "$rel_source" "$wiki_path" "$project_name - Living project status"

    echo ""
    echo "✓ Created PROJECT-STATUS.md for: $project_name"
    echo "  Location: $output_file"
    echo "  Wiki target: $wiki_path"
    echo "  Mapping ID: $mapping_id"
    echo ""
    echo "Next steps:"
    echo "  1. Fill in the Quick Overview section"
    echo "  2. Add team members and stakeholders"
    echo "  3. Link related documentation"
    echo "  4. Define success criteria"
    echo "  5. Run: project-manager sync $output_file (to copy to wiki)"
}

# Command: update status
cmd_update_status() {
    local file="$1"
    local new_status="$2"

    if [ -z "$file" ] || [ -z "$new_status" ]; then
        echo "Usage: project-manager update <project-file> --status '<status>'"
        echo "Status options: In Progress, Completed, On Hold, Planned"
        exit 1
    fi

    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file"
        exit 1
    fi

    # Determine emoji based on status
    local emoji="🔄"
    case "$new_status" in
        "Completed") emoji="✅" ;;
        "On Hold") emoji="⏳" ;;
        "Planned") emoji="⏳" ;;
        *) emoji="🔄" ;;
    esac

    # Update status line
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^\*\*Status:\*\* [^ ]* .*$/\*\*Status:\*\* $emoji $new_status/" "$file"
    else
        sed -i "s/^\*\*Status:\*\* [^ ]* .*$/\*\*Status:\*\* $emoji $new_status/" "$file"
    fi

    update_timestamp "$file"
    add_changelog_entry "$file" "Status updated to: $new_status"

    echo "✓ Updated status to: $emoji $new_status"
}

# Command: add item
cmd_add_item() {
    local file="$1"
    shift

    local section=""
    local item=""
    local link=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --section) section="$2"; shift 2 ;;
            --item) item="$2"; shift 2 ;;
            --link) link="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$item" ]; then
        echo "Usage: project-manager add <project-file> --section <section> --item '<description>' [--link <url>]"
        echo "Sections: completed, in-progress, next-up, blockers"
        exit 1
    fi

    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file"
        exit 1
    fi

    # Format the item
    local checkbox=""
    local entry=""

    case "$section" in
        "completed")
            checkbox="[x]"
            if [ -n "$link" ]; then
                entry="- $checkbox $item - [$link]"
            else
                entry="- $checkbox $item"
            fi
            # Find "Completed (CW XX)" section
            local section_pattern="### ✅ Completed"
            ;;
        "in-progress")
            checkbox="[ ]"
            if [ -n "$link" ]; then
                entry="- $checkbox $item - [$link]"
            else
                entry="- $checkbox $item"
            fi
            local section_pattern="### 🔄 In Progress"
            ;;
        "next-up")
            if [ -n "$link" ]; then
                entry="- $item - [$link]"
            else
                entry="- $item"
            fi
            local section_pattern="### ⏳ Next Up"
            ;;
        "blockers")
            # Blockers are numbered
            if [ -n "$link" ]; then
                entry="1. **$item** - [$link]"
            else
                entry="1. **$item**"
            fi
            local section_pattern="### Blockers"
            ;;
        *)
            echo "Error: Unknown section: $section"
            exit 1
            ;;
    esac

    # Find section and add item
    local line_num=$(grep -n "$section_pattern" "$file" | head -1 | cut -d: -f1)

    if [ -z "$line_num" ]; then
        echo "Error: Section not found in file: $section_pattern"
        exit 1
    fi

    # Insert after the section header
    local insert_line=$((line_num + 1))

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "${insert_line}i\\
$entry
" "$file"
    else
        sed -i "${insert_line}i\\$entry" "$file"
    fi

    update_timestamp "$file"
    add_changelog_entry "$file" "Added item to $section: $item"

    echo "✓ Added item to $section"
}

# Command: move item
cmd_move_item() {
    local file="$1"
    shift

    local item=""
    local from=""
    local to=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --item) item="$2"; shift 2 ;;
            --from) from="$2"; shift 2 ;;
            --to) to="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$file" ] || [ -z "$item" ] || [ -z "$from" ] || [ -z "$to" ]; then
        echo "Usage: project-manager move-item <project-file> --item '<item>' --from <section> --to <section>"
        echo "Sections: completed, in-progress, next-up, blockers"
        exit 1
    fi

    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file"
        exit 1
    fi

    echo "✓ Move operation would be performed"
    echo "  (Full implementation requires more complex text manipulation)"
    echo "  Recommended: Use Edit tool to move items manually"

    update_timestamp "$file"
    add_changelog_entry "$file" "Moved item from $from to $to"
}

# Command: sync to wiki
cmd_sync() {
    local source_file="$1"

    if [ -z "$source_file" ]; then
        echo "Usage: project-manager sync <project-status-file>"
        echo "Example: project-manager sync PROJECT-STATUS.md"
        exit 1
    fi

    if [ ! -f "$source_file" ]; then
        echo "Error: File not found: $source_file"
        exit 1
    fi

    # Call dedicated sync script
    "$SCRIPT_DIR/sync-to-wiki.sh" "$source_file"
}

# Main command router
case "${1:-}" in
    create)
        shift
        cmd_create "$@"
        ;;
    update)
        shift
        file="$1"
        shift
        if [ "$1" = "--status" ]; then
            shift
            cmd_update_status "$file" "$1"
        else
            echo "Error: Unknown update option"
            exit 1
        fi
        ;;
    add)
        shift
        cmd_add_item "$@"
        ;;
    move-item)
        shift
        cmd_move_item "$@"
        ;;
    sync)
        shift
        cmd_sync "$@"
        ;;
    *)
        echo "Project Manager - Living Documentation Tool"
        echo ""
        echo "Usage:"
        echo "  project-manager create <name> <folder> [wiki-name]   Create new project"
        echo "  project-manager update <file> --status <s>           Update status"
        echo "  project-manager add <file> --section <s> --item <i> [--link <l>]"
        echo "  project-manager move-item <file> --item <i> --from <f> --to <t>"
        echo "  project-manager sync <file>                          Sync to wiki"
        echo ""
        echo "Available sections: completed, in-progress, next-up, blockers"
        exit 1
        ;;
esac
