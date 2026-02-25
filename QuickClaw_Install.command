#!/bin/bash
# ============================================================================
# QuickClaw_Install.command — v2
# One-click installer for OpenClaw on macOS
# https://github.com/guyingoldglasses/QuickClaw
# ============================================================================

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

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}[fail]${NC}  QuickClaw is designed for macOS. Detected: $(uname)"
    exit 1
fi
echo -e "${GREEN}[ok]${NC}    macOS detected ($(sw_vers -productVersion))"

# Apple Silicon Homebrew path
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---------------------------------------------------------------------------
# Step 1: Choose install location
# ---------------------------------------------------------------------------
SCRIPT_DIR_ORIG="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR_ORIG/.quickclaw-install.log"

echo ""
echo -e "${CYAN}Where would you like to install QuickClaw?${NC}"
echo ""

# Detect external volumes
EXTERNAL_DRIVES=()
OPTION_NUM=1

for vol in /Volumes/*/; do
    vol_name=$(basename "$vol")
    # Skip system volumes
    case "$vol_name" in
        "Macintosh HD"|"Macintosh HD - Data"|"Recovery"|"Preboot"|"VM"|"Update"|com.apple*) continue ;;
    esac
    # Verify it's writable
    if [[ -w "$vol" ]]; then
        EXTERNAL_DRIVES+=("$vol")
        AVAIL=$(df -h "$vol" 2>/dev/null | awk 'NR==2{print $4}')
        echo -e "  ${BOLD}$OPTION_NUM)${NC}  $vol_name  ${BLUE}— External drive${NC} (${AVAIL} free)"
        ((OPTION_NUM++))
    fi
done

# Current location option
echo -e "  ${BOLD}$OPTION_NUM)${NC}  Current folder ($(basename "$SCRIPT_DIR_ORIG"))"

TOTAL_OPTIONS=$OPTION_NUM
echo ""

if [[ ${#EXTERNAL_DRIVES[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}Tip:${NC} Installing to an external drive keeps your Mac's"
    echo "  internal storage free and makes QuickClaw portable."
    echo ""
fi

read -p "  Choose (1-$TOTAL_OPTIONS) [${TOTAL_OPTIONS}]: " LOCATION_CHOICE
echo ""

# Default to current folder if empty
LOCATION_CHOICE=${LOCATION_CHOICE:-$TOTAL_OPTIONS}

if [[ "$LOCATION_CHOICE" == "$TOTAL_OPTIONS" ]]; then
    BASE_DIR="$SCRIPT_DIR_ORIG"
    info "Installing to current folder"
elif [[ "$LOCATION_CHOICE" -ge 1 ]] && [[ "$LOCATION_CHOICE" -lt "$TOTAL_OPTIONS" ]] 2>/dev/null; then
    DRIVE_INDEX=$((LOCATION_CHOICE - 1))
    CHOSEN_DRIVE="${EXTERNAL_DRIVES[$DRIVE_INDEX]}"
    DRIVE_NAME=$(basename "$CHOSEN_DRIVE")
    BASE_DIR="${CHOSEN_DRIVE}QuickClaw"
    info "Installing to external drive: $DRIVE_NAME"

    # Create QuickClaw folder on the drive
    mkdir -p "$BASE_DIR"
    success "Created QuickClaw folder on $DRIVE_NAME"

    # Copy QuickClaw files to external drive
    if [[ "$BASE_DIR" != "$SCRIPT_DIR_ORIG" ]]; then
        info "Copying QuickClaw files to $DRIVE_NAME..."
        for f in "$SCRIPT_DIR_ORIG"/*.command; do
            [[ -f "$f" ]] && cp "$f" "$BASE_DIR/"
        done
        [[ -f "$SCRIPT_DIR_ORIG/START_HERE.html" ]] && cp "$SCRIPT_DIR_ORIG/START_HERE.html" "$BASE_DIR/"
        [[ -f "$SCRIPT_DIR_ORIG/README.md" ]] && cp "$SCRIPT_DIR_ORIG/README.md" "$BASE_DIR/"
        [[ -d "$SCRIPT_DIR_ORIG/dashboard-files" ]] && cp -R "$SCRIPT_DIR_ORIG/dashboard-files" "$BASE_DIR/"
        chmod +x "$BASE_DIR"/*.command 2>/dev/null
        # Remove quarantine on copied files
        xattr -dr com.apple.quarantine "$BASE_DIR" 2>/dev/null
        success "Files copied to $BASE_DIR"
        echo ""
        echo -e "  ${GREEN}From now on, use the scripts on your external drive:${NC}"
        echo -e "  ${BOLD}$BASE_DIR${NC}"
        echo ""
    fi
else
    warn "Invalid choice. Installing to current folder."
    BASE_DIR="$SCRIPT_DIR_ORIG"
fi

# Set paths based on chosen location
SCRIPT_DIR="$BASE_DIR"
INSTALL_DIR="$BASE_DIR/openclaw"
DASHBOARD_DIR="$BASE_DIR/dashboard-files"
CONFIG_DIR="$INSTALL_DIR/config"
LOG_FILE="$BASE_DIR/.quickclaw-install.log"

log "=== QuickClaw Install started ==="
log "Install dir: $INSTALL_DIR"

# ---------------------------------------------------------------------------
# Step 2: Homebrew
# ---------------------------------------------------------------------------
info "Checking for Homebrew..."

if command -v brew &>/dev/null; then
    success "Homebrew found"
else
    info "Installing Homebrew (this may take a few minutes)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        success "Homebrew installed"
    else
        fail "Homebrew installation failed. Visit https://brew.sh for help."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Step 3: Node.js
# ---------------------------------------------------------------------------
info "Checking for Node.js..."

MINIMUM_NODE_VERSION=18

if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [[ "$NODE_VERSION" -ge "$MINIMUM_NODE_VERSION" ]]; then
        success "Node.js $(node -v)"
    else
        warn "Node.js $(node -v) is outdated. Upgrading..."
        brew install node
        success "Node.js upgraded to $(node -v)"
    fi
else
    info "Installing Node.js..."
    brew install node
    if command -v node &>/dev/null; then
        success "Node.js $(node -v) installed"
    else
        fail "Node.js installation failed"
        exit 1
    fi
fi

if command -v npm &>/dev/null; then
    success "npm $(npm -v)"
else
    fail "npm not found"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 4: Install OpenClaw (locally to install dir)
# ---------------------------------------------------------------------------
info "Setting up OpenClaw..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Create local package.json so OpenClaw installs TO THE CHOSEN DRIVE
if [[ ! -f "package.json" ]]; then
    cat > package.json << 'JSON'
{
  "name": "quickclaw-openclaw",
  "version": "2.0.0",
  "private": true,
  "dependencies": {}
}
JSON
fi

OPENCLAW_INSTALLED=false

# Try local npm install (keeps everything on the target drive)
info "Installing OpenClaw package..."
if npm install open-claw --save --no-fund --no-audit 2>>"$LOG_FILE"; then
    if [[ -d "$INSTALL_DIR/node_modules/open-claw" ]]; then
        success "OpenClaw installed"
        OPENCLAW_INSTALLED=true
    fi
fi

# Try alternative package name
if [[ "$OPENCLAW_INSTALLED" == false ]]; then
    if npm install openclaw --save --no-fund --no-audit 2>>"$LOG_FILE"; then
        if [[ -d "$INSTALL_DIR/node_modules/openclaw" ]]; then
            success "OpenClaw installed"
            OPENCLAW_INSTALLED=true
        fi
    fi
fi

if [[ "$OPENCLAW_INSTALLED" == false ]]; then
    echo ""
    warn "OpenClaw package was not found in the npm registry."
    echo ""
    echo -e "  This is normal if OpenClaw hasn't been published to npm yet"
    echo -e "  or uses a different package name."
    echo ""
    echo -e "  ${BOLD}What to do:${NC}"
    echo -e "  • Place your OpenClaw files manually in: ${BOLD}$INSTALL_DIR${NC}"
    echo -e "  • Or install from source if you have a URL"
    echo ""
    echo -e "  The dashboard and all other QuickClaw tools will still work."
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 5: Install Antfarm
# ---------------------------------------------------------------------------
info "Installing Antfarm..."

ANTFARM_INSTALLED=false

if npm install antfarm --save --no-fund --no-audit 2>>"$LOG_FILE"; then
    if [[ -d "$INSTALL_DIR/node_modules/antfarm" ]]; then
        success "Antfarm installed"
        ANTFARM_INSTALLED=true
    fi
fi

if [[ "$ANTFARM_INSTALLED" == false ]]; then
    warn "Antfarm not available — some features may be limited"
fi

cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Step 6: Create default config
# ---------------------------------------------------------------------------
info "Setting up configuration..."

mkdir -p "$CONFIG_DIR"

CONFIG_FILE="$CONFIG_DIR/default.yaml"
if [[ -f "$CONFIG_FILE" ]]; then
    success "Config already exists"
else
    cat > "$CONFIG_FILE" << 'YAML'
# OpenClaw configuration — created by QuickClaw v2
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

# ─── Integrations (uncomment and fill in as needed) ───

# telegram:
#   bot_token: YOUR_TELEGRAM_BOT_TOKEN

# anthropic:
#   api_key: sk-ant-YOUR_KEY_HERE

# openai:
#   api_key: sk-YOUR_KEY_HERE

# ftp:
#   host: ftp.example.com
#   user: your_username
#   pass: your_password

# email:
#   smtp_host: smtp.gmail.com
#   smtp_port: 587
#   user: your_email@gmail.com
#   pass: your_app_password
YAML
    success "Default config created"
fi

# ---------------------------------------------------------------------------
# Step 7: Dashboard dependencies
# ---------------------------------------------------------------------------
info "Setting up dashboard..."

if [[ -d "$DASHBOARD_DIR" ]]; then
    cd "$DASHBOARD_DIR"

    if [[ ! -f "package.json" ]]; then
        cat > package.json << 'JSON'
{
  "name": "quickclaw-dashboard",
  "version": "2.0.0",
  "private": true,
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.18.0" }
}
JSON
    fi

    npm install --production --no-fund --no-audit 2>>"$LOG_FILE"
    success "Dashboard ready"
    cd "$SCRIPT_DIR"
else
    warn "Dashboard directory not found — skipping"
fi

# ---------------------------------------------------------------------------
# Save install location for other scripts to find
# ---------------------------------------------------------------------------
echo "$BASE_DIR" > "$BASE_DIR/.quickclaw-root"
# Also save marker to original location so Setup can find it
if [[ "$BASE_DIR" != "$SCRIPT_DIR_ORIG" ]]; then
    echo "$BASE_DIR" > "$SCRIPT_DIR_ORIG/.quickclaw-root"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       ${BOLD}Installation Complete${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Install path: ${BOLD}$INSTALL_DIR${NC}"
echo -e "  Config:       ${BOLD}$CONFIG_FILE${NC}"
echo -e "  Dashboard:    ${BOLD}$DASHBOARD_DIR${NC}"

if [[ "$OPENCLAW_INSTALLED" == true ]]; then
    echo -e "  OpenClaw:     ${GREEN}Installed${NC}"
else
    echo -e "  OpenClaw:     ${YELLOW}Manual setup needed${NC}"
fi

echo ""

log "=== QuickClaw Install completed ==="
