#!/bin/bash

# LinkFixer - Broken Link Scanner
# A link validator with support for various file types

# Configuration
TEMP_DIR="/tmp/linkfixer"
REPORT_FILE="$TEMP_DIR/report.csv"
MAX_CONCURRENT=10

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize temporary directory
init_temp() {
    mkdir -p "$TEMP_DIR"
    echo "URL,Status,File,Line" > "$REPORT_FILE"
}

# Extract URLs from file
extract_urls() {
    local file="$1"
    local line_number=0
    
    while IFS= read -r line; do
        ((line_number++))
        
        # Match URLs in different formats
        echo "$line" | grep -o -E 'https?://[^[:space:]"'\''<>]+' | while read -r url; do
            echo "$url|$line_number"
        done
    done < "$file"
}

# Check URL status
check_url() {
    local url="$1"
    local file="$2"
    local line="$3"
    
    # Skip empty URLs
    if [ -z "$url" ]; then
        return
    fi
    
    # Check URL with curl
    local status=$(curl -s -o /dev/null -w "%{http_code}" -L "$url" 2>/dev/null)
    
    # Add to report
    echo "$url,$status,$file,$line" >> "$REPORT_FILE"
    
    # Print status
    if [ "$status" = "200" ]; then
        echo -e "${GREEN}[OK] $url${NC}"
    else
        echo -e "${RED}[$status] $url${NC}"
    fi
}

# Process file
process_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File not found: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Processing file: $file${NC}"
    
    # Extract and check URLs
    extract_urls "$file" | while IFS='|' read -r url line; do
        check_url "$url" "$file" "$line" &
        
        # Limit concurrent checks
        if [ $(jobs -p | wc -l) -ge $MAX_CONCURRENT ]; then
            wait -n
        fi
    done
    
    # Wait for remaining checks
    wait
}

# Process directory
process_directory() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        echo -e "${RED}Error: Directory not found: $dir${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Processing directory: $dir${NC}"
    
    # Find all supported files
    find "$dir" -type f \( -name "*.md" -o -name "*.html" -o -name "*.txt" \) | while read -r file; do
        process_file "$file"
    done
}

# Process GitHub repository
process_github() {
    local repo="$1"
    local temp_dir="$TEMP_DIR/github"
    
    if [ -z "$repo" ]; then
        echo -e "${RED}Error: Repository required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Processing GitHub repository: $repo${NC}"
    
    # Clone repository
    if [ ! -d "$temp_dir" ]; then
        git clone "https://github.com/$repo.git" "$temp_dir"
    else
        cd "$temp_dir"
        git pull
    fi
    
    # Process repository
    process_directory "$temp_dir"
}

# Generate report
generate_report() {
    echo -e "${BLUE}Generating report...${NC}"
    
    # Count total URLs
    local total=$(wc -l < "$REPORT_FILE")
    ((total--))  # Subtract header
    
    # Count broken URLs
    local broken=$(grep -v "^URL," "$REPORT_FILE" | grep -v ",200," | wc -l)
    
    # Print summary
    echo "----------------------------------------"
    echo -e "${YELLOW}Summary:${NC}"
    echo "Total URLs: $total"
    echo -e "Broken URLs: ${RED}$broken${NC}"
    echo "----------------------------------------"
    
    # Print broken URLs
    if [ $broken -gt 0 ]; then
        echo -e "${YELLOW}Broken URLs:${NC}"
        grep -v "^URL," "$REPORT_FILE" | grep -v ",200," | while IFS=',' read -r url status file line; do
            echo -e "${RED}$url${NC} ($status) in $file:$line"
        done
    fi
}

# Main function
main() {
    init_temp
    
    case "$1" in
        "file")
            if [ -z "$2" ]; then
                echo "Error: File required"
                echo "Usage: $0 file [path]"
                exit 1
            fi
            
            process_file "$2"
            ;;
        "dir")
            if [ -z "$2" ]; then
                echo "Error: Directory required"
                echo "Usage: $0 dir [path]"
                exit 1
            fi
            
            process_directory "$2"
            ;;
        "github")
            if [ -z "$2" ]; then
                echo "Error: Repository required"
                echo "Usage: $0 github [user/repo]"
                exit 1
            fi
            
            process_github "$2"
            ;;
        *)
            echo "Usage: $0 [file|dir|github]"
            echo "  file [path]     - Process a single file"
            echo "  dir [path]      - Process a directory"
            echo "  github [repo]   - Process a GitHub repository"
            exit 1
            ;;
    esac
    
    generate_report
}

# Run main function
main "$@" 