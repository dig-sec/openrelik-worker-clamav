#!/usr/bin/env bash
set -euo pipefail

# Utgard Complete Deployment Script
# Deploys both lab VMs and Pangolin in one command

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=0
    
    if ! command -v vagrant &> /dev/null; then
        log_error "Vagrant not found. Install: sudo apt install vagrant"
        missing=1
    fi
    
    if ! command -v virsh &> /dev/null; then
        log_error "libvirt not found. Install: sudo apt install libvirt-daemon-system"
        missing=1
    fi
    
    if ! command -v podman &> /dev/null && ! command -v docker &> /dev/null; then
        log_error "Neither podman nor docker found. Install one of them."
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "Missing required tools. Please install them first."
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Parse command line arguments
SKIP_LAB=0
SKIP_PANGOLIN=0
LAB_ONLY=0
PANGOLIN_ONLY=0
REBUILD=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-lab)
            SKIP_LAB=1
            shift
            ;;
        --skip-pangolin)
            SKIP_PANGOLIN=1
            shift
            ;;
        --lab-only)
            LAB_ONLY=1
            SKIP_PANGOLIN=1
            shift
            ;;
        --pangolin-only)
            PANGOLIN_ONLY=1
            SKIP_LAB=1
            shift
            ;;
        --rebuild)
            REBUILD=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Deploy Utgard lab infrastructure and Pangolin access layer"
            echo ""
            echo "Options:"
            echo "  --lab-only          Deploy only lab VMs (skip Pangolin)"
            echo "  --pangolin-only     Deploy only Pangolin (skip lab VMs)"
            echo "  --skip-lab          Skip lab VM deployment"
            echo "  --skip-pangolin     Skip Pangolin deployment"
            echo "  --rebuild           Rebuild lab from scratch (destroys existing VMs)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  # Deploy everything"
            echo "  $0 --lab-only       # Deploy only lab VMs"
            echo "  $0 --rebuild        # Clean rebuild of everything"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "$ROOT_DIR"

echo "╔════════════════════════════════════════════════════╗"
echo "║        Utgard Complete Deployment                  ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

check_prerequisites

# Step 1: Deploy Lab VMs
if [ $SKIP_LAB -eq 0 ]; then
    log_info "Step 1: Deploying Utgard Lab VMs"
    echo ""
    
    if [ $REBUILD -eq 1 ]; then
        log_warning "Rebuild requested - destroying existing VMs"
        "$SCRIPT_DIR/rebuild-lab.sh"
    else
        log_info "Starting lab VMs (use --rebuild to force clean install)"
        "$SCRIPT_DIR/start-lab.sh"
    fi
    
    log_success "Lab VMs deployed"
    echo ""
else
    log_warning "Skipping lab VM deployment (--skip-lab)"
    echo ""
fi

# Step 2: Deploy Pangolin
if [ $SKIP_PANGOLIN -eq 0 ]; then
    log_info "Step 2: Deploying Pangolin Access Layer"
    echo ""
    
    PANGOLIN_DIR="$ROOT_DIR/pangolin"
    
    if [ ! -d "$PANGOLIN_DIR" ]; then
        log_error "Pangolin directory not found: $PANGOLIN_DIR"
        exit 1
    fi
    
    cd "$PANGOLIN_DIR"
    
    # Check if podman or docker
    if command -v podman-compose &> /dev/null; then
        COMPOSE_CMD="podman-compose"
        SUDO_PREFIX="sudo"
    elif command -v podman &> /dev/null; then
        COMPOSE_CMD="podman compose"
        SUDO_PREFIX="sudo"
    elif command -v docker &> /dev/null; then
        COMPOSE_CMD="docker compose"
        # Check if user is in docker group
        if groups | grep -q docker; then
            SUDO_PREFIX=""
        else
            SUDO_PREFIX="sudo"
        fi
    fi
    
    log_info "Using: $COMPOSE_CMD"
    
    # Stop existing containers if any
    log_info "Stopping existing Pangolin containers..."
    $SUDO_PREFIX $COMPOSE_CMD down 2>/dev/null || true
    
    # Start Pangolin stack
    log_info "Starting Pangolin stack..."
    $SUDO_PREFIX $COMPOSE_CMD up -d
    
    # Wait for services to be healthy
    log_info "Waiting for Pangolin to be healthy (30s)..."
    sleep 10
    
    for i in {1..20}; do
        if $SUDO_PREFIX $COMPOSE_CMD ps | grep -q "healthy"; then
            log_success "Pangolin is healthy"
            break
        fi
        if [ $i -eq 20 ]; then
            log_warning "Pangolin health check timeout - check logs manually"
        fi
        sleep 1
    done
    
    # Show status
    echo ""
    log_info "Pangolin container status:"
    $SUDO_PREFIX $COMPOSE_CMD ps
    
    log_success "Pangolin deployed"
    echo ""
    
    cd "$ROOT_DIR"
else
    log_warning "Skipping Pangolin deployment (--skip-pangolin)"
    echo ""
fi

# Step 3: Summary and next steps
echo "╔════════════════════════════════════════════════════╗"
echo "║             Deployment Complete                    ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

if [ $SKIP_LAB -eq 0 ]; then
    log_info "Lab Services (Direct Access - Lab Network Only):"
    echo "  • OpenRelik UI:  http://10.20.0.30:8711"
    echo "  • OpenRelik API: http://10.20.0.30:8710"
    echo "  • Neko Tor:      http://10.20.0.40:8080"
    echo "  • Neko Chromium: http://10.20.0.40:8090"
    echo ""
fi

if [ $SKIP_PANGOLIN -eq 0 ]; then
    log_info "Pangolin Access (External Access):"
    echo "  • Dashboard: https://utgard.dig-sec.com"
    echo "  • VPN Port:  51820/UDP (WireGuard)"
    echo ""
    log_warning "Next Steps:"
    echo "  1. Configure /etc/hosts or DNS:"
    echo "     127.0.0.1  utgard.dig-sec.com"
    echo "  2. Access https://utgard.dig-sec.com to complete initial setup"
    echo "  3. Create admin account and organization"
    echo "  4. Add lab services via Pangolin dashboard"
    echo ""
fi

log_info "Management Commands:"
echo "  • Check status:   ./scripts/check-status.sh"
echo "  • View lab VMs:   vagrant status"
echo "  • Stop lab:       vagrant halt"
echo "  • Destroy lab:    vagrant destroy -f"
if [ $SKIP_PANGOLIN -eq 0 ]; then
    echo "  • Pangolin logs:  cd pangolin && sudo $COMPOSE_CMD logs -f"
    echo "  • Stop Pangolin:  cd pangolin && sudo $COMPOSE_CMD down"
fi
echo ""

log_success "Deployment complete!"
