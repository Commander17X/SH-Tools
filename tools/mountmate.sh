#!/bin/bash

# MountMate - Drive Mounter/Manager
# A simple drive manager with mount profiles and UI

# Configuration
CONFIG_DIR="$HOME/.local/share/mountmate"
PROFILES_FILE="$CONFIG_DIR/profiles.json"
USE_UI=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize configuration
init_config() {
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$PROFILES_FILE" ]; then
        echo '{
            "profiles": {
                "backup": {
                    "device": "/dev/sdb1",
                    "mountpoint": "/mnt/backup",
                    "options": "defaults,noatime"
                },
                "media": {
                    "device": "/dev/sdc1",
                    "mountpoint": "/mnt/media",
                    "options": "defaults,noatime"
                }
            }
        }' > "$PROFILES_FILE"
    fi
}

# List available devices
list_devices() {
    echo -e "${BLUE}Available devices:${NC}"
    echo "----------------------------------------"
    
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v "loop" | while read -r line; do
        if [[ $line == *"disk"* ]] || [[ $line == *"part"* ]]; then
            echo -e "${GREEN}$line${NC}"
        fi
    done
}

# List mounted devices
list_mounted() {
    echo -e "${BLUE}Mounted devices:${NC}"
    echo "----------------------------------------"
    
    mount | grep "^/dev/" | while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local mountpoint=$(echo "$line" | awk '{print $3}')
        local type=$(echo "$line" | awk '{print $5}')
        
        echo -e "${GREEN}$device${NC} -> $mountpoint ($type)"
    done
}

# Mount device
mount_device() {
    local device="$1"
    local mountpoint="$2"
    local options="$3"
    
    if [ -z "$device" ] || [ -z "$mountpoint" ]; then
        echo -e "${RED}Error: Device and mountpoint required${NC}"
        return 1
    fi
    
    # Create mountpoint if it doesn't exist
    if [ ! -d "$mountpoint" ]; then
        sudo mkdir -p "$mountpoint"
    fi
    
    # Mount device
    echo -e "${YELLOW}Mounting $device to $mountpoint...${NC}"
    if [ -n "$options" ]; then
        sudo mount -o "$options" "$device" "$mountpoint"
    else
        sudo mount "$device" "$mountpoint"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully mounted $device to $mountpoint${NC}"
    else
        echo -e "${RED}Failed to mount $device${NC}"
        return 1
    fi
}

# Unmount device
unmount_device() {
    local mountpoint="$1"
    
    if [ -z "$mountpoint" ]; then
        echo -e "${RED}Error: Mountpoint required${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Unmounting $mountpoint...${NC}"
    sudo umount "$mountpoint"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully unmounted $mountpoint${NC}"
    else
        echo -e "${RED}Failed to unmount $mountpoint${NC}"
        return 1
    fi
}

# Add mount profile
add_profile() {
    local name="$1"
    local device="$2"
    local mountpoint="$3"
    local options="$4"
    
    if [ -z "$name" ] || [ -z "$device" ] || [ -z "$mountpoint" ]; then
        echo -e "${RED}Error: Profile name, device, and mountpoint required${NC}"
        return 1
    fi
    
    # Add profile to config
    local temp_file=$(mktemp)
    jq --arg name "$name" \
       --arg device "$device" \
       --arg mountpoint "$mountpoint" \
       --arg options "$options" \
       '.profiles[$name] = {"device": $device, "mountpoint": $mountpoint, "options": $options}' \
       "$PROFILES_FILE" > "$temp_file"
    
    mv "$temp_file" "$PROFILES_FILE"
    echo -e "${GREEN}Added profile: $name${NC}"
}

# Remove mount profile
remove_profile() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Profile name required${NC}"
        return 1
    fi
    
    # Remove profile from config
    local temp_file=$(mktemp)
    jq --arg name "$name" 'del(.profiles[$name])' "$PROFILES_FILE" > "$temp_file"
    
    mv "$temp_file" "$PROFILES_FILE"
    echo -e "${GREEN}Removed profile: $name${NC}"
}

# List mount profiles
list_profiles() {
    echo -e "${BLUE}Available profiles:${NC}"
    echo "----------------------------------------"
    
    jq -r '.profiles | to_entries[] | "\(.key): \(.value.device) -> \(.value.mountpoint)"' "$PROFILES_FILE" | while read -r line; do
        echo -e "${GREEN}$line${NC}"
    done
}

# Mount using profile
mount_profile() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Profile name required${NC}"
        return 1
    fi
    
    # Get profile details
    local device=$(jq -r ".profiles.$name.device" "$PROFILES_FILE")
    local mountpoint=$(jq -r ".profiles.$name.mountpoint" "$PROFILES_FILE")
    local options=$(jq -r ".profiles.$name.options" "$PROFILES_FILE")
    
    if [ "$device" = "null" ] || [ "$mountpoint" = "null" ]; then
        echo -e "${RED}Error: Profile not found: $name${NC}"
        return 1
    fi
    
    mount_device "$device" "$mountpoint" "$options"
}

# Interactive UI
interactive_ui() {
    if ! command -v dialog &> /dev/null; then
        echo -e "${RED}Error: dialog is required for interactive UI${NC}"
        return 1
    fi
    
    while true; do
        choice=$(dialog --menu "MountMate" 20 60 10 \
            1 "List devices" \
            2 "List mounted" \
            3 "List profiles" \
            4 "Mount device" \
            5 "Unmount device" \
            6 "Add profile" \
            7 "Remove profile" \
            8 "Mount profile" \
            0 "Exit" 3>&1 1>&2 2>&3)
        
        case $choice in
            1) list_devices ;;
            2) list_mounted ;;
            3) list_profiles ;;
            4)
                device=$(dialog --inputbox "Enter device:" 10 60 3>&1 1>&2 2>&3)
                mountpoint=$(dialog --inputbox "Enter mountpoint:" 10 60 3>&1 1>&2 2>&3)
                options=$(dialog --inputbox "Enter options (optional):" 10 60 3>&1 1>&2 2>&3)
                mount_device "$device" "$mountpoint" "$options"
                ;;
            5)
                mountpoint=$(dialog --inputbox "Enter mountpoint:" 10 60 3>&1 1>&2 2>&3)
                unmount_device "$mountpoint"
                ;;
            6)
                name=$(dialog --inputbox "Enter profile name:" 10 60 3>&1 1>&2 2>&3)
                device=$(dialog --inputbox "Enter device:" 10 60 3>&1 1>&2 2>&3)
                mountpoint=$(dialog --inputbox "Enter mountpoint:" 10 60 3>&1 1>&2 2>&3)
                options=$(dialog --inputbox "Enter options (optional):" 10 60 3>&1 1>&2 2>&3)
                add_profile "$name" "$device" "$mountpoint" "$options"
                ;;
            7)
                name=$(dialog --inputbox "Enter profile name:" 10 60 3>&1 1>&2 2>&3)
                remove_profile "$name"
                ;;
            8)
                name=$(dialog --inputbox "Enter profile name:" 10 60 3>&1 1>&2 2>&3)
                mount_profile "$name"
                ;;
            0) exit 0 ;;
        esac
        
        dialog --msgbox "Press OK to continue" 10 60
    done
}

# Main function
main() {
    init_config
    
    case "$1" in
        "list")
            list_devices
            ;;
        "mounted")
            list_mounted
            ;;
        "mount")
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Error: Device and mountpoint required"
                echo "Usage: $0 mount [device] [mountpoint] [options]"
                exit 1
            fi
            
            mount_device "$2" "$3" "$4"
            ;;
        "unmount")
            if [ -z "$2" ]; then
                echo "Error: Mountpoint required"
                echo "Usage: $0 unmount [mountpoint]"
                exit 1
            fi
            
            unmount_device "$2"
            ;;
        "add-profile")
            if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
                echo "Error: Profile name, device, and mountpoint required"
                echo "Usage: $0 add-profile [name] [device] [mountpoint] [options]"
                exit 1
            fi
            
            add_profile "$2" "$3" "$4" "$5"
            ;;
        "remove-profile")
            if [ -z "$2" ]; then
                echo "Error: Profile name required"
                echo "Usage: $0 remove-profile [name]"
                exit 1
            fi
            
            remove_profile "$2"
            ;;
        "profiles")
            list_profiles
            ;;
        "mount-profile")
            if [ -z "$2" ]; then
                echo "Error: Profile name required"
                echo "Usage: $0 mount-profile [name]"
                exit 1
            fi
            
            mount_profile "$2"
            ;;
        "ui")
            interactive_ui
            ;;
        *)
            echo "Usage: $0 [list|mounted|mount|unmount|add-profile|remove-profile|profiles|mount-profile|ui]"
            echo "  list            - List available devices"
            echo "  mounted         - List mounted devices"
            echo "  mount           - Mount a device"
            echo "  unmount         - Unmount a device"
            echo "  add-profile     - Add a mount profile"
            echo "  remove-profile  - Remove a mount profile"
            echo "  profiles        - List mount profiles"
            echo "  mount-profile   - Mount using a profile"
            echo "  ui             - Start interactive UI"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 