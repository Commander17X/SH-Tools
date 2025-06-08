#!/bin/bash

# SafePass - Encrypted Password CLI
# A secure password manager with GPG encryption

# Configuration
VAULT_DIR="$HOME/.local/share/safepass"
VAULT_FILE="$VAULT_DIR/vault.gpg"
CONFIG_FILE="$VAULT_DIR/config.json"
LOCK_TIMEOUT=300  # 5 minutes

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize vault
init_vault() {
    mkdir -p "$VAULT_DIR"
    
    # Check if GPG key exists
    if ! gpg --list-secret-keys &> /dev/null; then
        echo -e "${RED}Error: No GPG key found${NC}"
        echo "Please create a GPG key first:"
        echo "gpg --full-generate-key"
        exit 1
    fi
    
    # Create empty vault if it doesn't exist
    if [ ! -f "$VAULT_FILE" ]; then
        echo "{}" | gpg --encrypt --armor --output "$VAULT_FILE"
    fi
    
    # Create config if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{
            "last_unlock": 0,
            "clipboard_timeout": 30
        }' > "$CONFIG_FILE"
    fi
}

# Check if vault is locked
is_locked() {
    local last_unlock=$(jq -r '.last_unlock' "$CONFIG_FILE")
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_unlock))
    
    if [ $time_diff -gt $LOCK_TIMEOUT ]; then
        return 0  # Locked
    else
        return 1  # Unlocked
    fi
}

# Unlock vault
unlock_vault() {
    if is_locked; then
        echo -e "${YELLOW}Vault is locked. Please enter your GPG passphrase:${NC}"
        if ! gpg --decrypt "$VAULT_FILE" &> /dev/null; then
            echo -e "${RED}Error: Invalid passphrase${NC}"
            exit 1
        fi
        
        # Update last unlock time
        local temp_file=$(mktemp)
        jq --arg time "$(date +%s)" '.last_unlock = ($time|tonumber)' "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
        
        echo -e "${GREEN}Vault unlocked${NC}"
    fi
}

# Add password
add_password() {
    local name="$1"
    local username="$2"
    local password="$3"
    
    if [ -z "$name" ] || [ -z "$username" ] || [ -z "$password" ]; then
        echo -e "${RED}Error: Name, username, and password required${NC}"
        return 1
    fi
    
    unlock_vault
    
    # Decrypt vault
    local temp_file=$(mktemp)
    gpg --decrypt "$VAULT_FILE" > "$temp_file"
    
    # Add password
    jq --arg name "$name" \
       --arg username "$username" \
       --arg password "$password" \
       '.passwords[$name] = {"username": $username, "password": $password}' \
       "$temp_file" > "${temp_file}.new"
    
    # Encrypt vault
    gpg --encrypt --armor --output "$VAULT_FILE" < "${temp_file}.new"
    
    rm "$temp_file" "${temp_file}.new"
    echo -e "${GREEN}Added password: $name${NC}"
}

# Get password
get_password() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Password name required${NC}"
        return 1
    fi
    
    unlock_vault
    
    # Decrypt vault
    local temp_file=$(mktemp)
    gpg --decrypt "$VAULT_FILE" > "$temp_file"
    
    # Get password
    local username=$(jq -r ".passwords.$name.username" "$temp_file")
    local password=$(jq -r ".passwords.$name.password" "$temp_file")
    
    if [ "$username" = "null" ] || [ "$password" = "null" ]; then
        echo -e "${RED}Error: Password not found: $name${NC}"
        rm "$temp_file"
        return 1
    fi
    
    # Copy to clipboard
    if command -v wl-copy &> /dev/null; then
        echo -n "$password" | wl-copy
    elif command -v xclip &> /dev/null; then
        echo -n "$password" | xclip -selection clipboard
    else
        echo -e "${RED}Error: No clipboard manager found${NC}"
        rm "$temp_file"
        return 1
    fi
    
    echo -e "${GREEN}Password copied to clipboard: $name${NC}"
    echo -e "${BLUE}Username: $username${NC}"
    
    # Clear clipboard after timeout
    local timeout=$(jq -r '.clipboard_timeout' "$CONFIG_FILE")
    (
        sleep "$timeout"
        if command -v wl-copy &> /dev/null; then
            wl-copy --clear
        elif command -v xclip &> /dev/null; then
            echo -n "" | xclip -selection clipboard
        fi
    ) &
    
    rm "$temp_file"
}

# Remove password
remove_password() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Password name required${NC}"
        return 1
    fi
    
    unlock_vault
    
    # Decrypt vault
    local temp_file=$(mktemp)
    gpg --decrypt "$VAULT_FILE" > "$temp_file"
    
    # Remove password
    jq --arg name "$name" 'del(.passwords[$name])' "$temp_file" > "${temp_file}.new"
    
    # Encrypt vault
    gpg --encrypt --armor --output "$VAULT_FILE" < "${temp_file}.new"
    
    rm "$temp_file" "${temp_file}.new"
    echo -e "${GREEN}Removed password: $name${NC}"
}

# List passwords
list_passwords() {
    unlock_vault
    
    # Decrypt vault
    local temp_file=$(mktemp)
    gpg --decrypt "$VAULT_FILE" > "$temp_file"
    
    echo -e "${BLUE}Available passwords:${NC}"
    echo "----------------------------------------"
    
    jq -r '.passwords | to_entries[] | "\(.key): \(.value.username)"' "$temp_file" | while read -r line; do
        echo -e "${GREEN}$line${NC}"
    done
    
    rm "$temp_file"
}

# Export vault
export_vault() {
    local output="$1"
    
    if [ -z "$output" ]; then
        echo -e "${RED}Error: Output file required${NC}"
        return 1
    fi
    
    unlock_vault
    
    # Decrypt vault
    local temp_file=$(mktemp)
    gpg --decrypt "$VAULT_FILE" > "$temp_file"
    
    # Export to file
    cp "$temp_file" "$output"
    
    rm "$temp_file"
    echo -e "${GREEN}Vault exported to: $output${NC}"
}

# Import vault
import_vault() {
    local input="$1"
    
    if [ -z "$input" ]; then
        echo -e "${RED}Error: Input file required${NC}"
        return 1
    fi
    
    if [ ! -f "$input" ]; then
        echo -e "${RED}Error: File not found: $input${NC}"
        return 1
    fi
    
    # Validate JSON
    if ! jq . "$input" &> /dev/null; then
        echo -e "${RED}Error: Invalid JSON file${NC}"
        return 1
    fi
    
    # Encrypt and import
    gpg --encrypt --armor --output "$VAULT_FILE" < "$input"
    
    echo -e "${GREEN}Vault imported from: $input${NC}"
}

# Main function
main() {
    init_vault
    
    case "$1" in
        "add")
            if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
                echo "Error: Name, username, and password required"
                echo "Usage: $0 add [name] [username] [password]"
                exit 1
            fi
            
            add_password "$2" "$3" "$4"
            ;;
        "get")
            if [ -z "$2" ]; then
                echo "Error: Password name required"
                echo "Usage: $0 get [name]"
                exit 1
            fi
            
            get_password "$2"
            ;;
        "remove")
            if [ -z "$2" ]; then
                echo "Error: Password name required"
                echo "Usage: $0 remove [name]"
                exit 1
            fi
            
            remove_password "$2"
            ;;
        "list")
            list_passwords
            ;;
        "export")
            if [ -z "$2" ]; then
                echo "Error: Output file required"
                echo "Usage: $0 export [file]"
                exit 1
            fi
            
            export_vault "$2"
            ;;
        "import")
            if [ -z "$2" ]; then
                echo "Error: Input file required"
                echo "Usage: $0 import [file]"
                exit 1
            fi
            
            import_vault "$2"
            ;;
        *)
            echo "Usage: $0 [add|get|remove|list|export|import]"
            echo "  add [name] [username] [password]  - Add a password"
            echo "  get [name]                       - Get a password"
            echo "  remove [name]                    - Remove a password"
            echo "  list                            - List all passwords"
            echo "  export [file]                   - Export vault"
            echo "  import [file]                   - Import vault"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 