#!/bin/bash

# SnapShot - Instant Backup CLI
# A fast backup tool with timestamped backups and preset support

# Configuration
BACKUP_DIR="$HOME/.local/share/snapshot"
CONFIG_FILE="$BACKUP_DIR/config.json"
MAX_BACKUPS=10

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize backup directory and config
init_backup() {
    mkdir -p "$BACKUP_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{
            "presets": {
                "home": {
                    "paths": ["$HOME/Documents", "$HOME/Pictures", "$HOME/Music"],
                    "exclude": ["*.tmp", "*.temp"]
                },
                "web": {
                    "paths": ["/var/www/html", "/etc/nginx"],
                    "exclude": ["*.log", "*.cache"]
                }
            }
        }' > "$CONFIG_FILE"
    fi
}

# Create timestamp
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Create backup
create_backup() {
    local source="$1"
    local preset="$2"
    local compress="$3"
    local timestamp=$(get_timestamp)
    local backup_name="backup_${preset}_${timestamp}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    echo -e "${BLUE}Creating backup: $backup_name${NC}"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Get paths from preset
    local paths=($(jq -r ".presets.$preset.paths[]" "$CONFIG_FILE"))
    local excludes=($(jq -r ".presets.$preset.exclude[]" "$CONFIG_FILE"))
    
    # Build exclude options
    local exclude_opts=""
    for exclude in "${excludes[@]}"; do
        exclude_opts+="--exclude='$exclude' "
    done
    
    # Create backup
    for path in "${paths[@]}"; do
        echo -e "${YELLOW}Backing up: $path${NC}"
        eval "rsync -av $exclude_opts \"$path\" \"$backup_path/\""
    done
    
    # Compress if requested
    if [ "$compress" = true ]; then
        echo -e "${YELLOW}Compressing backup...${NC}"
        tar -czf "${backup_path}.tar.gz" -C "$BACKUP_DIR" "$backup_name"
        rm -rf "$backup_path"
        echo -e "${GREEN}Backup compressed: ${backup_path}.tar.gz${NC}"
    else
        echo -e "${GREEN}Backup created: $backup_path${NC}"
    fi
    
    # Cleanup old backups
    cleanup_old_backups
}

# Cleanup old backups
cleanup_old_backups() {
    local backups=($(ls -t "$BACKUP_DIR" | grep "backup_"))
    local count=${#backups[@]}
    
    if [ $count -gt $MAX_BACKUPS ]; then
        echo -e "${YELLOW}Cleaning up old backups...${NC}"
        for ((i=$MAX_BACKUPS; i<$count; i++)); do
            rm -rf "$BACKUP_DIR/${backups[$i]}"
            echo -e "${GREEN}Removed: ${backups[$i]}${NC}"
        done
    fi
}

# List backups
list_backups() {
    echo -e "${BLUE}Available backups:${NC}"
    echo "----------------------------------------"
    
    ls -l "$BACKUP_DIR" | grep "backup_" | while read -r line; do
        local size=$(echo "$line" | awk '{print $5}')
        local name=$(echo "$line" | awk '{print $9}')
        local date=$(echo "$line" | awk '{print $6, $7, $8}')
        
        # Convert size to human readable
        if [ $size -gt 1024 ]; then
            size=$(echo "scale=2; $size/1024" | bc)"K"
        fi
        if [ $size -gt 1024 ]; then
            size=$(echo "scale=2; $size/1024" | bc)"M"
        fi
        
        echo -e "${GREEN}$name${NC} - $size - $date"
    done
}

# Restore backup
restore_backup() {
    local backup="$1"
    local target="$2"
    
    if [ ! -d "$BACKUP_DIR/$backup" ] && [ ! -f "$BACKUP_DIR/$backup.tar.gz" ]; then
        echo -e "${RED}Error: Backup not found: $backup${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Restoring backup: $backup${NC}"
    
    if [ -f "$BACKUP_DIR/$backup.tar.gz" ]; then
        # Restore from compressed backup
        echo -e "${YELLOW}Extracting backup...${NC}"
        tar -xzf "$BACKUP_DIR/$backup.tar.gz" -C "$BACKUP_DIR"
    fi
    
    # Restore files
    echo -e "${YELLOW}Restoring files...${NC}"
    rsync -av "$BACKUP_DIR/$backup/" "$target/"
    
    echo -e "${GREEN}Backup restored to: $target${NC}"
}

# Main function
main() {
    init_backup
    
    case "$1" in
        "create")
            if [ -z "$2" ]; then
                echo "Error: No preset specified"
                echo "Usage: $0 create [preset] [--compress]"
                exit 1
            fi
            
            local compress=false
            if [ "$3" = "--compress" ]; then
                compress=true
            fi
            
            create_backup "$HOME" "$2" "$compress"
            ;;
        "list")
            list_backups
            ;;
        "restore")
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Error: Missing arguments"
                echo "Usage: $0 restore [backup] [target]"
                exit 1
            fi
            
            restore_backup "$2" "$3"
            ;;
        *)
            echo "Usage: $0 [create|list|restore]"
            echo "  create [preset] [--compress]  - Create a new backup"
            echo "  list                         - List available backups"
            echo "  restore [backup] [target]    - Restore a backup"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 