#!/bin/bash

# TreeDex - Terminal File Explorer
# A fast file explorer with size and type information

# Configuration
MAX_DEPTH=3
USE_EMOJI=true
SHOW_HIDDEN=false
SORT_BY="name"  # name, size, date
REVERSE_SORT=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# File type icons
declare -A TYPE_ICONS=(
    ["dir"]="📁"
    ["file"]="📄"
    ["symlink"]="🔗"
    ["executable"]="⚙️"
    ["image"]="🖼️"
    ["video"]="🎥"
    ["audio"]="🎵"
    ["archive"]="📦"
    ["code"]="📝"
    ["document"]="📑"
)

# ASCII icons (fallback)
declare -A ASCII_ICONS=(
    ["dir"]="[DIR]"
    ["file"]="[FILE]"
    ["symlink"]="[LINK]"
    ["executable"]="[EXE]"
    ["image"]="[IMG]"
    ["video"]="[VID]"
    ["audio"]="[AUD]"
    ["archive"]="[ARC]"
    ["code"]="[CODE]"
    ["document"]="[DOC]"
)

# Get file type
get_file_type() {
    local file="$1"
    
    if [ -L "$file" ]; then
        echo "symlink"
    elif [ -d "$file" ]; then
        echo "dir"
    elif [ -x "$file" ]; then
        echo "executable"
    else
        case "$(file -b --mime-type "$file")" in
            image/*) echo "image" ;;
            video/*) echo "video" ;;
            audio/*) echo "audio" ;;
            application/x-tar|application/gzip|application/zip) echo "archive" ;;
            text/x-*|application/x-*) echo "code" ;;
            text/*|application/pdf) echo "document" ;;
            *) echo "file" ;;
        esac
    fi
}

# Get file icon
get_file_icon() {
    local type="$1"
    
    if [ "$USE_EMOJI" = true ]; then
        echo "${TYPE_ICONS[$type]}"
    else
        echo "${ASCII_ICONS[$type]}"
    fi
}

# Format file size
format_size() {
    local size="$1"
    local units=("B" "K" "M" "G" "T")
    local unit=0
    
    while [ $size -ge 1024 ] && [ $unit -lt ${#units[@]} ]; do
        size=$((size / 1024))
        ((unit++))
    done
    
    echo "${size}${units[$unit]}"
}

# Get directory size
get_dir_size() {
    local dir="$1"
    local size=0
    
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            size=$((size + $(stat -c %s "$file")))
        fi
    done < <(find "$dir" -type f -print0)
    
    echo "$size"
}

# List directory contents
list_directory() {
    local dir="$1"
    local depth="$2"
    local prefix="$3"
    
    if [ $depth -gt $MAX_DEPTH ]; then
        return
    fi
    
    # Get directory contents
    local contents=()
    while IFS= read -r -d '' item; do
        if [ "$SHOW_HIDDEN" = false ] && [[ $(basename "$item") == .* ]]; then
            continue
        fi
        contents+=("$item")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0)
    
    # Sort contents
    if [ "$SORT_BY" = "size" ]; then
        contents=($(for item in "${contents[@]}"; do
            if [ -d "$item" ]; then
                size=$(get_dir_size "$item")
            else
                size=$(stat -c %s "$item")
            fi
            echo "$size|$item"
        done | sort -n | cut -d'|' -f2))
    elif [ "$SORT_BY" = "date" ]; then
        contents=($(for item in "${contents[@]}"; do
            date=$(stat -c %Y "$item")
            echo "$date|$item"
        done | sort -n | cut -d'|' -f2))
    else
        contents=($(printf "%s\n" "${contents[@]}" | sort))
    fi
    
    # Reverse if needed
    if [ "$REVERSE_SORT" = true ]; then
        contents=($(printf "%s\n" "${contents[@]}" | tac))
    fi
    
    # Print contents
    local count=${#contents[@]}
    local i=0
    for item in "${contents[@]}"; do
        local name=$(basename "$item")
        local type=$(get_file_type "$item")
        local icon=$(get_file_icon "$type")
        
        # Get size
        if [ -d "$item" ]; then
            local size=$(format_size $(get_dir_size "$item"))
        else
            local size=$(format_size $(stat -c %s "$item"))
        fi
        
        # Print item
        if [ $i -eq $((count - 1)) ]; then
            echo -e "${prefix}└── ${icon} ${BLUE}$name${NC} ($size)"
            list_directory "$item" $((depth + 1)) "${prefix}    "
        else
            echo -e "${prefix}├── ${icon} ${BLUE}$name${NC} ($size)"
            list_directory "$item" $((depth + 1)) "${prefix}│   "
        fi
        
        ((i++))
    done
}

# Find duplicates
find_duplicates() {
    local dir="$1"
    
    echo -e "${BLUE}Finding duplicate files...${NC}"
    
    # Find all files and calculate MD5
    find "$dir" -type f -print0 | while IFS= read -r -d '' file; do
        md5sum "$file"
    done | sort | uniq -d -w32 | while read -r hash file; do
        echo -e "${RED}Duplicate: $file${NC}"
    done
}

# Find large files
find_large_files() {
    local dir="$1"
    local size="$2"
    
    if [ -z "$size" ]; then
        size="100M"
    fi
    
    echo -e "${BLUE}Finding files larger than $size...${NC}"
    
    find "$dir" -type f -size "+$size" -print0 | while IFS= read -r -d '' file; do
        local size=$(format_size $(stat -c %s "$file"))
        echo -e "${YELLOW}$file ($size)${NC}"
    done
}

# Export as diagram
export_diagram() {
    local dir="$1"
    local output="$2"
    local format="$3"
    
    if [ -z "$output" ]; then
        output="treedex_diagram"
    fi
    
    if [ -z "$format" ]; then
        format="txt"
    fi
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Generate tree
    if [ "$format" = "md" ]; then
        echo "# Directory Structure" > "$temp_file"
        echo "\`\`\`" >> "$temp_file"
    fi
    
    list_directory "$dir" 0 "" >> "$temp_file"
    
    if [ "$format" = "md" ]; then
        echo "\`\`\`" >> "$temp_file"
    fi
    
    # Save output
    mv "$temp_file" "$output.$format"
    echo -e "${GREEN}Diagram exported to: $output.$format${NC}"
}

# Main function
main() {
    local dir="."
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--depth)
                MAX_DEPTH="$2"
                shift 2
                ;;
            -e|--emoji)
                USE_EMOJI=true
                shift
                ;;
            -a|--ascii)
                USE_EMOJI=false
                shift
                ;;
            -h|--hidden)
                SHOW_HIDDEN=true
                shift
                ;;
            -s|--sort)
                SORT_BY="$2"
                shift 2
                ;;
            -r|--reverse)
                REVERSE_SORT=true
                shift
                ;;
            -f|--find-duplicates)
                find_duplicates "$dir"
                exit 0
                ;;
            -l|--large-files)
                find_large_files "$dir" "$2"
                exit 0
                ;;
            -x|--export)
                export_diagram "$dir" "$2" "$3"
                exit 0
                ;;
            *)
                dir="$1"
                shift
                ;;
        esac
    done
    
    # List directory
    echo -e "${BLUE}Directory: $dir${NC}"
    echo "----------------------------------------"
    list_directory "$dir" 0 ""
}

# Run main function
main "$@" 