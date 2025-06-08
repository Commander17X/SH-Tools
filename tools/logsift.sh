#!/bin/bash

# LogSift - Smart Log File Filter
# A smart log file filter with highlighting and regex support

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default patterns
ERROR_PATTERN='(error|exception|fail|critical|fatal)'
WARNING_PATTERN='(warn|warning|notice)'
TIMESTAMP_PATTERN='\d{4}-\d{2}-\d{2}|\d{2}:\d{2}:\d{2}'
IP_PATTERN='\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'

# Initialize variables
FILE=""
PATTERNS=()
CUSTOM_PATTERN=""
INTERACTIVE=false
FOLLOW=false

# Print usage information
usage() {
    echo "Usage: $0 [options] [file]"
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -i, --interactive    Enable interactive mode"
    echo "  -f, --follow         Follow file updates"
    echo "  -p, --pattern PAT    Add custom pattern"
    echo "  -e, --error          Highlight errors"
    echo "  -w, --warning        Highlight warnings"
    echo "  -t, --timestamp      Highlight timestamps"
    echo "  -ip, --ip            Highlight IP addresses"
    echo "  -c, --color          Enable color output"
    echo "  -n, --no-color       Disable color output"
    exit 1
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -f|--follow)
                FOLLOW=true
                shift
                ;;
            -p|--pattern)
                CUSTOM_PATTERN="$2"
                shift 2
                ;;
            -e|--error)
                PATTERNS+=("$ERROR_PATTERN")
                shift
                ;;
            -w|--warning)
                PATTERNS+=("$WARNING_PATTERN")
                shift
                ;;
            -t|--timestamp)
                PATTERNS+=("$TIMESTAMP_PATTERN")
                shift
                ;;
            -ip|--ip)
                PATTERNS+=("$IP_PATTERN")
                shift
                ;;
            -c|--color)
                USE_COLOR=true
                shift
                ;;
            -n|--no-color)
                USE_COLOR=false
                shift
                ;;
            *)
                if [ -z "$FILE" ]; then
                    FILE="$1"
                else
                    echo "Error: Unexpected argument: $1"
                    usage
                fi
                shift
                ;;
        esac
    done
}

# Apply highlighting to a line
highlight_line() {
    local line="$1"
    local highlighted="$line"
    
    # Apply custom pattern if specified
    if [ -n "$CUSTOM_PATTERN" ]; then
        highlighted=$(echo "$highlighted" | sed -E "s/($CUSTOM_PATTERN)/${MAGENTA}\1${NC}/g")
    fi
    
    # Apply default patterns
    for pattern in "${PATTERNS[@]}"; do
        case "$pattern" in
            "$ERROR_PATTERN")
                highlighted=$(echo "$highlighted" | sed -E "s/($pattern)/${RED}\1${NC}/g")
                ;;
            "$WARNING_PATTERN")
                highlighted=$(echo "$highlighted" | sed -E "s/($pattern)/${YELLOW}\1${NC}/g")
                ;;
            "$TIMESTAMP_PATTERN")
                highlighted=$(echo "$highlighted" | sed -E "s/($pattern)/${GREEN}\1${NC}/g")
                ;;
            "$IP_PATTERN")
                highlighted=$(echo "$highlighted" | sed -E "s/($pattern)/${BLUE}\1${NC}/g")
                ;;
            *)
                highlighted=$(echo "$highlighted" | sed -E "s/($pattern)/${CYAN}\1${NC}/g")
                ;;
        esac
    done
    
    echo "$highlighted"
}

# Process log file
process_file() {
    if [ ! -f "$FILE" ]; then
        echo "Error: File not found: $FILE"
        exit 1
    fi
    
    if [ "$FOLLOW" = true ]; then
        tail -f "$FILE" | while read -r line; do
            highlight_line "$line"
        done
    else
        while read -r line; do
            highlight_line "$line"
        done < "$FILE"
    fi
}

# Interactive mode
interactive_mode() {
    if [ ! -f "$FILE" ]; then
        echo "Error: File not found: $FILE"
        exit 1
    fi
    
    echo "Interactive mode started. Press 'q' to quit, 'h' for help."
    echo "----------------------------------------"
    
    # Use less for interactive viewing
    if [ "$FOLLOW" = true ]; then
        tail -f "$FILE" | while read -r line; do
            highlight_line "$line"
        done | less -R
    else
        while read -r line; do
            highlight_line "$line"
        done < "$FILE" | less -R
    fi
}

# Main function
main() {
    parse_args "$@"
    
    if [ -z "$FILE" ]; then
        echo "Error: No file specified"
        usage
    fi
    
    if [ "$INTERACTIVE" = true ]; then
        interactive_mode
    else
        process_file
    fi
}

# Run main function
main "$@" 