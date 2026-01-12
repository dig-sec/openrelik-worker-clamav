#!/bin/bash
# WireGuard Configuration Switcher for Utgard Lab
# Allows easy switching between multiple Mullvad VPN endpoints

set -e

WIREGUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../wireguard" && pwd)"
ACTIVE_CONFIG="${WIREGUARD_DIR}/active-wg0.conf"
BACKUP_DIR="${WIREGUARD_DIR}/.backup"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
    cat << EOF
WireGuard Configuration Manager for Utgard Lab

USAGE:
    ./scripts/wg-config.sh [COMMAND] [OPTIONS]

COMMANDS:
    list                    List all available WireGuard configs
    select <config>         Select a WireGuard config to use
    info <config>           Show details of a config
    current                 Show currently active config
    activate <config>       Activate config for firewall VM
    test                    Test WireGuard connectivity
    rotate                  Randomly rotate to another endpoint
    backup                  Backup current config
    restore                 Restore backed up config

EXAMPLES:
    # List available configs
    ./scripts/wg-config.sh list

    # Select se-mma-wg-001 config
    ./scripts/wg-config.sh select se-mma-wg-001

    # Show config details
    ./scripts/wg-config.sh info se-mma-wg-001

    # Activate for next provisioning
    ./scripts/wg-config.sh activate se-mma-wg-001

    # Rotate endpoint (random)
    ./scripts/wg-config.sh rotate

    # Test connectivity
    ./scripts/wg-config.sh test

ENDPOINTS:
    se-mma-wg-001   193.138.218.220:51820 (Malmo 1)
    se-mma-wg-002   193.138.218.80:51820  (Malmo 2)
    se-mma-wg-003   193.138.218.83:51820  (Malmo 3)
    se-mma-wg-004   193.138.218.130:51820 (Malmo 4)
    se-mma-wg-005   193.138.218.82:51820  (Malmo 5)
    se-mma-wg-011   141.98.255.94:51820   (Malmo Alt 1)
    se-mma-wg-012   141.98.255.97:51820   (Malmo Alt 2)
    se-mma-wg-101   45.83.220.68:51820    (Malmo Cloud 1)
    se-mma-wg-102   45.83.220.69:51820    (Malmo Cloud 2)
    se-mma-wg-103   45.83.220.70:51820    (Malmo Cloud 3)
    se-mma-wg-111   45.129.59.19:51820    (Malmo Data 1)
    se-mma-wg-112   45.129.59.129:51820   (Malmo Data 2)

EOF
}

list_configs() {
    echo -e "${BLUE}Available WireGuard Configurations:${NC}"
    echo ""
    for config in "${WIREGUARD_DIR}"/*.conf; do
        if [ -f "$config" ]; then
            local name=$(basename "$config" .conf)
            if [ "$name" == "active-wg0" ]; then
                continue
            fi
            local endpoint=$(grep "^Endpoint = " "$config" | cut -d' ' -f3)
            printf "  %-20s %s\n" "$name" "$endpoint"
        fi
    done
    echo ""
}

show_info() {
    local config="$1"
    local config_file="${WIREGUARD_DIR}/${config}.conf"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Config not found: $config${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Configuration: $config${NC}"
    echo "=========================================="
    cat "$config_file"
    echo "=========================================="
    echo ""
}

get_current() {
    if [ -f "$ACTIVE_CONFIG" ]; then
        grep "^# Config:" "$ACTIVE_CONFIG" 2>/dev/null | cut -d' ' -f3 || echo "Unknown"
    else
        echo "None (using default or environment variable)"
    fi
}

show_current() {
    local current=$(get_current)
    echo -e "${BLUE}Currently Active WireGuard Config:${NC} $current"
    
    if [ -f "$ACTIVE_CONFIG" ]; then
        echo ""
        local endpoint=$(grep "^Endpoint = " "$ACTIVE_CONFIG" | cut -d' ' -f3)
        echo -e "Endpoint: $endpoint"
    fi
    echo ""
}

select_config() {
    local config="$1"
    local config_file="${WIREGUARD_DIR}/${config}.conf"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Config not found: $config${NC}"
        echo "Use '$(basename $0) list' to see available configs"
        return 1
    fi
    
    # Copy config to active location with metadata
    {
        echo "# Config: $config"
        echo "# Selected: $(date)"
        cat "$config_file"
    } > "$ACTIVE_CONFIG"
    
    echo -e "${GREEN}[OK] Selected: $config${NC}"
    echo -e "  Endpoint: $(grep "^Endpoint = " "$config_file" | cut -d' ' -f3)"
    echo ""
    echo "To apply this config:"
    echo "  ./scripts/provision.sh firewall"
    echo ""
}

activate_config() {
    local config="$1"
    select_config "$config"
    
    echo -e "${YELLOW}To activate immediately, run:${NC}"
    echo "  vagrant ssh firewall"
    echo "  sudo systemctl stop lab-firewall"
    echo "  sudo wg-quick down wg0"
    echo "  sudo cp /tmp/active-wg0.conf /etc/wireguard/wg0.conf"
    echo "  sudo wg-quick up wg0"
    echo ""
}

rotate_config() {
    local configs=()
    for config in "${WIREGUARD_DIR}"/*.conf; do
        if [ -f "$config" ]; then
            local name=$(basename "$config" .conf)
            if [ "$name" != "active-wg0" ]; then
                configs+=("$name")
            fi
        fi
    done
    
    if [ ${#configs[@]} -eq 0 ]; then
        echo -e "${RED}No configs found${NC}"
        return 1
    fi
    
    local random_index=$((RANDOM % ${#configs[@]}))
    local selected="${configs[$random_index]}"
    
    echo -e "${YELLOW}Rotating to random endpoint...${NC}"
    select_config "$selected"
}

test_connectivity() {
    if [ ! -f "$ACTIVE_CONFIG" ]; then
        echo -e "${RED}Error: No active WireGuard config${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Testing WireGuard Connectivity:${NC}"
    echo ""
    
    # Try to ping the gateway
    if vagrant ssh firewall -c "ping -c 1 10.64.0.1" 2>/dev/null; then
        echo -e "${GREEN}[OK] Mullvad gateway reachable${NC}"
    else
        echo -e "${YELLOW}[WARNING] Mullvad gateway not reachable (firewall VM may not be running)${NC}"
    fi
    
    # Check WireGuard interface
    if vagrant ssh firewall -c "sudo wg show wg0 2>/dev/null" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] WireGuard interface active${NC}"
        vagrant ssh firewall -c "sudo wg show wg0 | head -5" 2>/dev/null || true
    else
        echo -e "${YELLOW}[WARNING] WireGuard interface not active${NC}"
    fi
    
    echo ""
}

backup_config() {
    if [ ! -f "$ACTIVE_CONFIG" ]; then
        echo -e "${YELLOW}No active config to backup${NC}"
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/wg0_${timestamp}.conf"
    
    cp "$ACTIVE_CONFIG" "$backup_file"
    echo -e "${GREEN}[OK] Config backed up to: $backup_file${NC}"
}

restore_config() {
    local latest=$(ls -t "$BACKUP_DIR"/wg0_*.conf 2>/dev/null | head -1)
    
    if [ -z "$latest" ]; then
        echo -e "${RED}No backup configs found${NC}"
        return 1
    fi
    
    cp "$latest" "$ACTIVE_CONFIG"
    echo -e "${GREEN}[OK] Restored from: $latest${NC}"
    show_current
}

# Main command handler
case "${1:-help}" in
    list)
        list_configs
        ;;
    select)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Config name required${NC}"
            show_help
            exit 1
        fi
        select_config "$2"
        ;;
    info)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Config name required${NC}"
            show_help
            exit 1
        fi
        show_info "$2"
        ;;
    current)
        show_current
        ;;
    activate)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Config name required${NC}"
            show_help
            exit 1
        fi
        activate_config "$2"
        ;;
    test)
        test_connectivity
        ;;
    rotate)
        rotate_config
        ;;
    backup)
        backup_config
        ;;
    restore)
        restore_config
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
