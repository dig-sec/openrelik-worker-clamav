#!/usr/bin/env bash
set -euo pipefail

# Pangolin Standalone Deployment Script
# Quick deployment of just the Pangolin access layer

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PANGOLIN_DIR="$ROOT_DIR/pangolin"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

cd "$PANGOLIN_DIR"

echo "╔════════════════════════════════════════════════════╗"
echo "║           Pangolin Access Layer Deploy            ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Detect compose command
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="sudo podman-compose"
    log_info "Using podman-compose"
elif command -v podman &> /dev/null; then
    COMPOSE_CMD="sudo podman compose"
    log_info "Using podman compose"
elif command -v docker &> /dev/null; then
    if groups | grep -q docker; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="sudo docker compose"
    fi
    log_info "Using docker compose"
else
    log_error "Neither podman nor docker found. Please install one."
    exit 1
fi

# Parse command line
ACTION="${1:-start}"

case "$ACTION" in
    start|up)
        log_info "Starting Pangolin stack..."
        $COMPOSE_CMD up -d
        
        log_info "Waiting for services to start..."
        sleep 10
        
        log_info "Container status:"
        $COMPOSE_CMD ps
        
        echo ""
        log_info "Checking Pangolin health..."
        if $COMPOSE_CMD ps | grep -q "healthy"; then
            log_success "Pangolin is healthy!"
        else
            log_warning "Pangolin health check pending - may take a minute"
            log_info "Check logs: $COMPOSE_CMD logs -f"
        fi
        
        echo ""
        log_success "Pangolin started"
        echo ""
        echo "Access: https://utgard.dig-sec.com"
        echo "Add to /etc/hosts: 127.0.0.1  utgard.dig-sec.com"
        ;;
        
    stop|down)
        log_info "Stopping Pangolin stack..."
        $COMPOSE_CMD down
        log_success "Pangolin stopped"
        ;;
        
    restart)
        log_info "Restarting Pangolin stack..."
        $COMPOSE_CMD down
        $COMPOSE_CMD up -d
        sleep 10
        $COMPOSE_CMD ps
        log_success "Pangolin restarted"
        ;;
        
    logs)
        log_info "Showing Pangolin logs (Ctrl+C to exit)..."
        $COMPOSE_CMD logs -f --tail=100
        ;;
        
    status)
        echo "Pangolin Stack Status:"
        echo ""
        $COMPOSE_CMD ps
        echo ""
        
        log_info "Recent logs (pangolin):"
        $COMPOSE_CMD logs --tail=10 pangolin 2>&1 || true
        echo ""
        
        log_info "Recent logs (gerbil):"
        $COMPOSE_CMD logs --tail=10 gerbil 2>&1 || true
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|logs|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start Pangolin stack"
        echo "  stop    - Stop Pangolin stack"
        echo "  restart - Restart Pangolin stack"
        echo "  logs    - Show live logs"
        echo "  status  - Show container status"
        exit 1
        ;;
esac
