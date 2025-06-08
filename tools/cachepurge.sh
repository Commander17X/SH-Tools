#!/bin/bash

# CachePurge - App Cache Cleaner
# A cache cleaner with support for popular apps

# Configuration
CACHE_DIRS=(
    "$HOME/.cache"
    "$HOME/.local/share/Trash"
    "$HOME/.thumbnails"
    "$HOME/.var/app/*/cache"
    "/var/cache/apt/archives"
    "/var/log"
)

APP_CACHES=(
    "firefox:rm -rf $HOME/.mozilla/firefox/*/cache2"
    "chrome:rm -rf $HOME/.config/google-chrome/Default/Cache"
    "chromium:rm -rf $HOME/.config/chromium/Default/Cache"
    "opera:rm -rf $HOME/.config/opera/Cache"
    "brave:rm -rf $HOME/.config/BraveSoftware/Brave-Browser/Default/Cache"
    "vivaldi:rm -rf $HOME/.config/vivaldi/Default/Cache"
    "thunderbird:rm -rf $HOME/.thunderbird/*/Cache"
    "vlc:rm -rf $HOME/.cache/vlc"
    "spotify:rm -rf $HOME/.cache/spotify"
    "discord:rm -rf $HOME/.config/discord/Cache"
    "slack:rm -rf $HOME/.config/Slack/Cache"
    "telegram:rm -rf $HOME/.local/share/TelegramDesktop/tdata/emoji"
    "signal:rm -rf $HOME/.config/Signal/Cache"
    "whatsapp:rm -rf $HOME/.config/WhatsApp/Cache"
    "zoom:rm -rf $HOME/.zoom/cache"
    "teams:rm -rf $HOME/.config/Microsoft/Microsoft Teams/Cache"
    "skype:rm -rf $HOME/.config/skypeforlinux/Cache"
    "steam:rm -rf $HOME/.steam/steam/appcache"
    "minecraft:rm -rf $HOME/.minecraft/cache"
    "wine:rm -rf $HOME/.wine/drive_c/windows/temp"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize variables
DRY_RUN=false
VERBOSE=false
SCHEDULE=false
CRON_JOB="0 0 * * 0"  # Weekly at midnight

# Print usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -d, --dry-run        Show what would be deleted without actually deleting"
    echo "  -v, --verbose        Show detailed information"
    echo "  -s, --schedule       Schedule regular cleanup"
    echo "  -c, --cron CRON      Set custom cron schedule (default: weekly)"
    echo "  -a, --app APP        Clean specific app cache"
    echo "  -l, --list-apps      List supported apps"
    exit 1
}

# List supported apps
list_apps() {
    echo -e "${BLUE}Supported apps:${NC}"
    echo "----------------------------------------"
    
    for app in "${APP_CACHES[@]}"; do
        local name=${app%%:*}
        echo -e "${GREEN}$name${NC}"
    done
}

# Clean app cache
clean_app_cache() {
    local app="$1"
    local found=false
    
    for app_cache in "${APP_CACHES[@]}"; do
        local name=${app_cache%%:*}
        local cmd=${app_cache#*:}
        
        if [ "$name" = "$app" ]; then
            found=true
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}Would run: $cmd${NC}"
            else
                echo -e "${BLUE}Cleaning $name cache...${NC}"
                eval "$cmd"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully cleaned $name cache${NC}"
                else
                    echo -e "${RED}Failed to clean $name cache${NC}"
                fi
            fi
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo -e "${RED}Error: Unsupported app: $app${NC}"
        return 1
    fi
}

# Clean system cache
clean_system_cache() {
    for dir in "${CACHE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}Would clean: $dir${NC}"
            else
                echo -e "${BLUE}Cleaning: $dir${NC}"
                if [ "$VERBOSE" = true ]; then
                    du -sh "$dir" 2>/dev/null
                fi
                rm -rf "$dir"/* 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully cleaned $dir${NC}"
                else
                    echo -e "${RED}Failed to clean $dir${NC}"
                fi
            fi
        fi
    done
}

# Schedule cleanup
schedule_cleanup() {
    local cron="$1"
    
    # Create temporary script
    local temp_script=$(mktemp)
    cat > "$temp_script" << EOF
#!/bin/bash
# CachePurge scheduled cleanup
$0
EOF
    
    chmod +x "$temp_script"
    
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "$temp_script"; echo "$cron $temp_script") | crontab -
    
    echo -e "${GREEN}Scheduled cleanup with cron: $cron${NC}"
}

# Calculate space saved
calculate_space_saved() {
    local total=0
    
    for dir in "${CACHE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local size=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
            total=$((total + size))
        fi
    done
    
    # Convert to human readable
    local units=("B" "K" "M" "G" "T")
    local unit=0
    
    while [ $total -ge 1024 ] && [ $unit -lt ${#units[@]} ]; do
        total=$((total / 1024))
        ((unit++))
    done
    
    echo "${total}${units[$unit]}"
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -s|--schedule)
                SCHEDULE=true
                shift
                ;;
            -c|--cron)
                CRON_JOB="$2"
                shift 2
                ;;
            -a|--app)
                clean_app_cache "$2"
                shift 2
                ;;
            -l|--list-apps)
                list_apps
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Show space before cleanup
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Space used by cache: $(calculate_space_saved)${NC}"
    fi
    
    # Clean system cache
    clean_system_cache
    
    # Show space after cleanup
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Space saved: $(calculate_space_saved)${NC}"
    fi
    
    # Schedule if requested
    if [ "$SCHEDULE" = true ]; then
        schedule_cleanup "$CRON_JOB"
    fi
}

# Run main function
main "$@" 