#!/bin/bash

# ClipMe - Clipboard Manager
# A powerful clipboard manager for the terminal

# Configuration
CLIPBOARD_DIR="$HOME/.local/share/clipme"
HISTORY_FILE="$CLIPBOARD_DIR/history.json"
MAX_HISTORY=1000

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize clipboard directory and history file
init_clipboard() {
    mkdir -p "$CLIPBOARD_DIR"
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "[]" > "$HISTORY_FILE"
    fi
}

# Detect clipboard manager based on platform
detect_clipboard() {
    if command -v wl-copy &> /dev/null; then
        echo "wayland"
    elif command -v xclip &> /dev/null; then
        echo "x11"
    else
        echo "unknown"
    fi
}

# Copy to clipboard based on platform
copy_to_clipboard() {
    local content="$1"
    case $(detect_clipboard) in
        "wayland")
            echo -n "$content" | wl-copy
            ;;
        "x11")
            echo -n "$content" | xclip -selection clipboard
            ;;
        *)
            echo -e "${RED}Error: No clipboard manager found${NC}"
            exit 1
            ;;
    esac
}

# Add entry to history
add_to_history() {
    local content="$1"
    local timestamp=$(date +%s)
    local temp_file=$(mktemp)
    
    jq --arg content "$content" --arg timestamp "$timestamp" \
       '. += [{"content": $content, "timestamp": $timestamp}]' \
       "$HISTORY_FILE" > "$temp_file"
    
    mv "$temp_file" "$HISTORY_FILE"
    
    # Trim history if needed
    if [ $(jq 'length' "$HISTORY_FILE") -gt $MAX_HISTORY ]; then
        jq '.[-'"$MAX_HISTORY"':]' "$HISTORY_FILE" > "$temp_file"
        mv "$temp_file" "$HISTORY_FILE"
    fi
}

# Show history with fuzzy search
show_history() {
    if ! command -v fzf &> /dev/null; then
        echo -e "${RED}Error: fzf is required for fuzzy search${NC}"
        exit 1
    fi
    
    local selected=$(jq -r '.[] | "\(.timestamp) | \(.content)"' "$HISTORY_FILE" | \
                    fzf --reverse --preview 'echo {}' --preview-window=up:3:wrap)
    
    if [ -n "$selected" ]; then
        local content=$(echo "$selected" | cut -d'|' -f2- | sed 's/^ *//')
        copy_to_clipboard "$content"
        echo -e "${GREEN}Copied to clipboard!${NC}"
    fi
}

# Monitor clipboard for changes
monitor_clipboard() {
    local last_content=""
    
    while true; do
        case $(detect_clipboard) in
            "wayland")
                current_content=$(wl-paste)
                ;;
            "x11")
                current_content=$(xclip -selection clipboard -o)
                ;;
        esac
        
        if [ "$current_content" != "$last_content" ] && [ -n "$current_content" ]; then
            add_to_history "$current_content"
            last_content="$current_content"
        fi
        
        sleep 1
    done
}

# Main function
main() {
    init_clipboard
    
    case "$1" in
        "history")
            show_history
            ;;
        "monitor")
            monitor_clipboard
            ;;
        *)
            echo "Usage: $0 [history|monitor]"
            echo "  history  - Show clipboard history with fuzzy search"
            echo "  monitor  - Start clipboard monitoring"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 