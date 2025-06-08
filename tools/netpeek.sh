#!/bin/bash

# NetPeek - Network Analyzer
# A minimalist network analysis tool

# Configuration
LOG_DIR="$HOME/.local/share/netpeek"
LOG_FILE="$LOG_DIR/network.log"
SCAN_INTERVAL=60  # seconds
PING_COUNT=5
PING_TIMEOUT=2

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize log directory
init_logs() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
}

# Get current bandwidth usage
get_bandwidth() {
    local interface=$(ip route | grep default | awk '{print $5}')
    local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    
    sleep 1
    
    local rx_bytes_new=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local tx_bytes_new=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    
    local rx_speed=$(( (rx_bytes_new - rx_bytes) / 1024 ))
    local tx_speed=$(( (tx_bytes_new - tx_bytes) / 1024 ))
    
    echo "Download: ${rx_speed}KB/s Upload: ${tx_speed}KB/s"
}

# Scan network for devices
scan_network() {
    if ! command -v nmap &> /dev/null; then
        echo -e "${RED}Error: nmap is required for network scanning${NC}"
        return 1
    fi
    
    local network=$(ip route | grep default | awk '{print $3}' | cut -d. -f1-3).0/24
    echo -e "${BLUE}Scanning network: $network${NC}"
    
    nmap -sn "$network" | grep "Nmap scan" | while read -r line; do
        local ip=$(echo "$line" | awk '{print $5}')
        local hostname=$(echo "$line" | awk '{print $6}' | tr -d '()')
        echo -e "${GREEN}$ip${NC} - $hostname"
    done
}

# Monitor ping to a host
monitor_ping() {
    local host="$1"
    if [ -z "$host" ]; then
        host="8.8.8.8"  # Default to Google DNS
    fi
    
    echo -e "${BLUE}Monitoring ping to $host${NC}"
    while true; do
        local ping_result=$(ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$host" 2>/dev/null)
        local success=$?
        
        if [ $success -eq 0 ]; then
            local avg_time=$(echo "$ping_result" | grep "avg" | awk -F'/' '{print $5}')
            echo -e "${GREEN}Ping to $host: ${avg_time}ms${NC}"
        else
            echo -e "${RED}Connection to $host failed${NC}"
            echo "$(date) - Connection to $host failed" >> "$LOG_FILE"
        fi
        
        sleep "$SCAN_INTERVAL"
    done
}

# Show network statistics
show_stats() {
    echo -e "${BLUE}Network Statistics:${NC}"
    echo "----------------------------------------"
    
    # Show bandwidth
    echo -e "${YELLOW}Current Bandwidth:${NC}"
    get_bandwidth
    
    # Show active connections
    echo -e "\n${YELLOW}Active Connections:${NC}"
    netstat -tun | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr
    
    # Show recent connection drops
    echo -e "\n${YELLOW}Recent Connection Drops:${NC}"
    tail -n 5 "$LOG_FILE"
}

# Main function
main() {
    init_logs
    
    case "$1" in
        "scan")
            scan_network
            ;;
        "ping")
            monitor_ping "$2"
            ;;
        "stats")
            show_stats
            ;;
        *)
            echo "Usage: $0 [scan|ping [host]|stats]"
            echo "  scan         - Scan network for devices"
            echo "  ping [host]  - Monitor ping to host (default: 8.8.8.8)"
            echo "  stats        - Show network statistics"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 