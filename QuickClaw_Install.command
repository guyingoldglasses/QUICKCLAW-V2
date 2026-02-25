#!/bin/bash
# ============================================================================
# QuickClaw_Install.command — v2
# One-click installer for OpenClaw on macOS
# https://github.com/guyingoldglasses/QuickClaw
# ============================================================================

set -e

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/openclaw"
DASHBOARD_DIR="$SCRIPT_DIR/dashboard-files"
CONFIG_DIR="$INSTALL_DIR/config"
LOG_FILE="$SCRIPT_DIR/.quickclaw-install.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       ${BOLD}QuickClaw Installer v2${NC}${CYAN}               ║${NC}"
    echo -e "${CYAN}║       One-click OpenClaw for macOS         ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

info()    { echo -e "${BLUE}[info]${NC}  $1"; log "INFO: $1"; }
success() { echo -e "${GREEN}[ok]${NC}    $1"; log "OK: $1"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $1"; log "WARN: $1"; }
fail()    { echo -e "${RED}[fail]${NC}  $1"; log "FAIL: $1"; }

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
print_header

echo "Install location: $INSTALL_DIR"
echo "Log file:         $LOG_FILE"
echo ""
log "=== QuickClaw Install started ==="
log "Install dir: $INSTALL_DIR"

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    fail "QuickClaw is designed for macOS. Detected: $(uname)"
    exit 1
fi
success "macOS detected ($(sw_vers -productVersion))"

# ---------------------------------------------------------------------------
# Step 1: Homebrew
# ---------------------------------------------------------------------------
info "Checking for Homebrew..."

if command -v brew &>/dev/null; then
    success "Homebrew found at $(which brew)"
else
    info "Installing Homebrew (this may take a minute)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Handle Apple Silicon path
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        success "Homebrew installed"
    else
        fail "Homebrew installation failed. Please install manually: https://brew.sh"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Step 2: Node.js
# ---------------------------------------------------------------------------
info "Checking for Node.js..."

MINIMUM_NODE_VERSION=18

if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [[ "$NODE_VERSION" -ge "$MINIMUM_NODE_VERSION" ]]; then
        success "Node.js $(node -v) found (meets minimum v${MINIMUM_NODE_VERSION})"
    else
        warn "Node.js $(node -v) is below minimum v${MINIMUM_NODE_VERSION}. Upgrading..."
        brew install node
        success "Node.js upgraded to $(node -v)"
    fi
else
    info "Installing Node.js via Homebrew..."
    brew install node
    if command -v node &>/dev/null; then
        success "Node.js $(node -v) installed"
    else
        fail "Node.js installation failed"
        exit 1
    fi
fi

# Verify npm
if command -v npm &>/dev/null; then
    success "npm $(npm -v) available"
else
    fail "npm not found after Node.js install"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 3: Install OpenClaw
# ---------------------------------------------------------------------------
info "Installing OpenClaw (latest)..."

if npm list -g open-claw &>/dev/null 2>&1; then
    info "OpenClaw already installed globally. Updating to latest..."
    npm update -g open-claw 2>>"$LOG_FILE"
else
    npm install -g open-claw 2>>"$LOG_FILE"
fi

if command -v open-claw &>/dev/null || command -v openclaw &>/dev/null; then
    success "OpenClaw CLI available"
else
    # Try npx fallback check
    if npx open-claw --version &>/dev/null 2>&1; then
        success "OpenClaw available via npx"
    else
        warn "OpenClaw CLI not found in PATH — may still work via npx"
    fi
fi

# ---------------------------------------------------------------------------
# Step 4: Install Antfarm (compatible latest)
# ---------------------------------------------------------------------------
info "Installing Antfarm (latest compatible)..."

if npm list -g antfarm &>/dev/null 2>&1; then
    info "Antfarm already installed globally. Updating..."
    npm update -g antfarm 2>>"$LOG_FILE"
else
    npm install -g antfarm 2>>"$LOG_FILE"
fi

if command -v antfarm &>/dev/null; then
    success "Antfarm CLI available"
else
    warn "Antfarm CLI not found in PATH — may need manual setup"
fi

# ---------------------------------------------------------------------------
# Step 5: Create default config (if none exists)
# ---------------------------------------------------------------------------
info "Checking OpenClaw configuration..."

mkdir -p "$CONFIG_DIR"

CONFIG_FILE="$CONFIG_DIR/default.yaml"
if [[ -f "$CONFIG_FILE" ]]; then
    success "Config already exists at $CONFIG_FILE"
else
    info "Creating default configuration..."
    cat > "$CONFIG_FILE" << 'YAML'
# OpenClaw default configuration — created by QuickClaw v2
# Edit this file to customize your setup.

# Gateway settings
gateway:
  port: 5000
  host: 0.0.0.0

# Default model (change as needed)
model:
  provider: local
  name: default

# Logging
logging:
  level: info
  file: logs/openclaw.log
YAML
    success "Default config created at $CONFIG_FILE"
fi

# ---------------------------------------------------------------------------
# Step 6: Dashboard dependencies
# ---------------------------------------------------------------------------
info "Setting up dashboard..."

if [[ -d "$DASHBOARD_DIR" ]]; then
    cd "$DASHBOARD_DIR"

    if [[ -f "package.json" ]]; then
        npm install --production 2>>"$LOG_FILE"
        success "Dashboard dependencies installed"
    else
        # Create a minimal package.json if missing
        cat > package.json << 'JSON'
{
  "name": "quickclaw-dashboard",
  "version": "2.0.0",
  "private": true,
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
JSON
        npm install --production 2>>"$LOG_FILE"
        success "Dashboard created and dependencies installed"
    fi

    cd "$SCRIPT_DIR"
else
    warn "Dashboard directory not found at $DASHBOARD_DIR — skipping"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       ${BOLD}Installation Complete${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Install path:  ${BOLD}$INSTALL_DIR${NC}"
echo -e "  Config:        ${BOLD}$CONFIG_FILE${NC}"
echo -e "  Dashboard:     ${BOLD}$DASHBOARD_DIR${NC}"
echo ""
echo -e "  ${GREEN}Next steps:${NC}"
echo -e "    1. Double-click ${BOLD}QuickClaw_Launch.command${NC} to start"
echo -e "    2. Open ${BOLD}http://localhost:3000${NC} for the dashboard"
echo ""
echo -e "  ${YELLOW}Recommended:${NC}"
echo -e "    Run ${BOLD}QuickClaw_Verify.command${NC} to confirm everything is healthy."
echo ""
echo -e "  Add-ons (OpenAI, FTP, Email, Skills) can be configured"
echo -e "  from the dashboard's ${BOLD}Add-ons & Integrations${NC} section."
echo ""
echo -e "  Problems? Run ${BOLD}QuickClaw Doctor.command${NC} or report at:"
echo -e "    https://github.com/guyingoldglasses/QuickClaw/issues"
echo -e "    https://guyingoldglasses.com"
echo ""

log "=== QuickClaw Install completed ==="
