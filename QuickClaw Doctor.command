#!/bin/bash
# ============================================================================
# QuickClaw Doctor.command — v2
# Diagnoses common issues and suggests fixes
# https://github.com/guyingoldglasses/QuickClaw
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/openclaw"
DASHBOARD_DIR="$SCRIPT_DIR/dashboard-files"
CONFIG_DIR="$INSTALL_DIR/config"
PID_DIR="$SCRIPT_DIR/.pids"
LOG_DIR="$SCRIPT_DIR/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ISSUES=0
WARNINGS=0

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        ${BOLD}QuickClaw Doctor v2${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}║        Diagnosing your installation...     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

check_pass() { echo -e "  ${GREEN}✓${NC}  $1"; }
check_warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; ((WARNINGS++)); }
check_fail() { echo -e "  ${RED}✗${NC}  $1"; ((ISSUES++)); }

# ---------------------------------------------------------------------------
# System checks
# ---------------------------------------------------------------------------
echo -e "${BOLD}System${NC}"

# macOS
if [[ "$(uname)" == "Darwin" ]]; then
    check_pass "macOS $(sw_vers -productVersion)"
else
    check_fail "Not macOS — QuickClaw is macOS only"
fi

# Architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    check_pass "Apple Silicon ($ARCH)"
elif [[ "$ARCH" == "x86_64" ]]; then
    check_pass "Intel Mac ($ARCH)"
else
    check_warn "Unexpected architecture: $ARCH"
fi

# Disk space
AVAILABLE_GB=$(df -g "$SCRIPT_DIR" 2>/dev/null | awk 'NR==2{print $4}')
if [[ -n "$AVAILABLE_GB" ]]; then
    if [[ "$AVAILABLE_GB" -ge 5 ]]; then
        check_pass "Disk space: ${AVAILABLE_GB}GB available"
    elif [[ "$AVAILABLE_GB" -ge 1 ]]; then
        check_warn "Disk space low: ${AVAILABLE_GB}GB available"
    else
        check_fail "Disk space critical: ${AVAILABLE_GB}GB available"
    fi
fi

echo ""
echo -e "${BOLD}Dependencies${NC}"

# Homebrew
if command -v brew &>/dev/null; then
    check_pass "Homebrew: $(brew --version | head -1)"
else
    check_fail "Homebrew not found — run QuickClaw_Install.command"
fi

# Node.js
if command -v node &>/dev/null; then
    NODE_VER=$(node -v)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
    if [[ "$NODE_MAJOR" -ge 18 ]]; then
        check_pass "Node.js: $NODE_VER"
    else
        check_warn "Node.js $NODE_VER is old — recommend v18+"
    fi
else
    check_fail "Node.js not found"
fi

# npm
if command -v npm &>/dev/null; then
    check_pass "npm: $(npm -v)"
else
    check_fail "npm not found"
fi

# OpenClaw CLI
if command -v open-claw &>/dev/null; then
    check_pass "OpenClaw CLI: $(open-claw --version 2>/dev/null || echo 'found')"
elif command -v openclaw &>/dev/null; then
    check_pass "OpenClaw CLI (as openclaw): $(openclaw --version 2>/dev/null || echo 'found')"
elif npx open-claw --version &>/dev/null 2>&1; then
    check_pass "OpenClaw available via npx"
else
    check_fail "OpenClaw CLI not found — run QuickClaw_Install.command"
fi

# Antfarm
if command -v antfarm &>/dev/null; then
    check_pass "Antfarm: $(antfarm --version 2>/dev/null || echo 'found')"
else
    check_warn "Antfarm CLI not found — some features may be unavailable"
fi

echo ""
echo -e "${BOLD}Installation${NC}"

# Install directory
if [[ -d "$INSTALL_DIR" ]]; then
    check_pass "Install directory: $INSTALL_DIR"
else
    check_fail "Install directory missing: $INSTALL_DIR"
fi

# Config
if [[ -f "$CONFIG_DIR/default.yaml" ]]; then
    check_pass "Config: $CONFIG_DIR/default.yaml"
else
    check_warn "No config found at $CONFIG_DIR/default.yaml"
fi

# Dashboard
if [[ -f "$DASHBOARD_DIR/server.js" ]]; then
    check_pass "Dashboard: server.js present"
    if [[ -d "$DASHBOARD_DIR/node_modules" ]]; then
        check_pass "Dashboard dependencies installed"
    else
        check_warn "Dashboard node_modules missing — run npm install in $DASHBOARD_DIR"
    fi
else
    check_warn "Dashboard server.js not found"
fi

# Public index
if [[ -f "$DASHBOARD_DIR/public/index.html" ]]; then
    check_pass "Dashboard UI: index.html present"
else
    check_warn "Dashboard index.html missing"
fi

echo ""
echo -e "${BOLD}Processes${NC}"

# Gateway
if [[ -f "$PID_DIR/gateway.pid" ]]; then
    GW_PID=$(cat "$PID_DIR/gateway.pid")
    if kill -0 "$GW_PID" 2>/dev/null; then
        check_pass "Gateway running (PID $GW_PID)"
    else
        check_warn "Gateway PID file exists but process not running (stale PID $GW_PID)"
    fi
else
    check_warn "Gateway not running"
fi

# Dashboard process
if [[ -f "$PID_DIR/dashboard.pid" ]]; then
    DB_PID=$(cat "$PID_DIR/dashboard.pid")
    if kill -0 "$DB_PID" 2>/dev/null; then
        check_pass "Dashboard running (PID $DB_PID)"
    else
        check_warn "Dashboard PID file exists but process not running (stale PID $DB_PID)"
    fi
else
    check_warn "Dashboard not running"
fi

# Port checks
if lsof -i :3000 &>/dev/null; then
    check_pass "Port 3000 in use (dashboard)"
else
    check_warn "Port 3000 free (dashboard not serving)"
fi

if lsof -i :5000 &>/dev/null; then
    check_pass "Port 5000 in use (gateway)"
else
    check_warn "Port 5000 free (gateway not serving)"
fi

echo ""
echo -e "${BOLD}Logs${NC}"

if [[ -d "$LOG_DIR" ]]; then
    check_pass "Log directory exists: $LOG_DIR"

    # Show recent errors from gateway log
    if [[ -f "$LOG_DIR/gateway.log" ]]; then
        RECENT_ERRORS=$(tail -50 "$LOG_DIR/gateway.log" 2>/dev/null | grep -i "error" | tail -3)
        if [[ -n "$RECENT_ERRORS" ]]; then
            check_warn "Recent gateway errors:"
            echo "$RECENT_ERRORS" | while IFS= read -r line; do
                echo -e "        ${RED}$line${NC}"
            done
        else
            check_pass "No recent gateway errors"
        fi
    fi

    if [[ -f "$LOG_DIR/dashboard.log" ]]; then
        RECENT_ERRORS=$(tail -50 "$LOG_DIR/dashboard.log" 2>/dev/null | grep -i "error" | tail -3)
        if [[ -n "$RECENT_ERRORS" ]]; then
            check_warn "Recent dashboard errors:"
            echo "$RECENT_ERRORS" | while IFS= read -r line; do
                echo -e "        ${RED}$line${NC}"
            done
        else
            check_pass "No recent dashboard errors"
        fi
    fi
else
    check_warn "No log directory found"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}────────────────────────────────────────────${NC}"

if [[ "$ISSUES" -eq 0 && "$WARNINGS" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All clear.${NC} No issues found."
elif [[ "$ISSUES" -eq 0 ]]; then
    echo -e "${YELLOW}${BOLD}$WARNINGS warning(s).${NC} Nothing critical, but worth checking."
else
    echo -e "${RED}${BOLD}$ISSUES issue(s)${NC} and ${YELLOW}$WARNINGS warning(s)${NC} found."
    echo "  Run QuickClaw_Install.command to fix missing components."
fi

echo ""
echo "  For a quick pass/fail check, run: QuickClaw_Verify.command"
echo "  Report bugs: https://github.com/guyingoldglasses/QuickClaw/issues"
echo "               https://guyingoldglasses.com"
echo ""
