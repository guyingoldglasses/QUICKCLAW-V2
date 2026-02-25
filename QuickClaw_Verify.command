#!/bin/bash
# ============================================================================
# QuickClaw_Verify.command — v2 (NEW)
# Quick pass/warn/fail health checks for QuickClaw installation
# https://github.com/guyingoldglasses/QuickClaw
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/openclaw"
DASHBOARD_DIR="$SCRIPT_DIR/dashboard-files"
CONFIG_DIR="$INSTALL_DIR/config"
PID_DIR="$SCRIPT_DIR/.pids"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       ${BOLD}QuickClaw Verify v2${NC}${CYAN}                  ║${NC}"
echo -e "${CYAN}║       Quick health check                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; ((PASS_COUNT++)); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; ((WARN_COUNT++)); }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; ((FAIL_COUNT++)); }

# ═══════════════════════════════════════════════════════════════════════════
# Check 1: Install path detected
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}1. Install path${NC}"

if [[ -d "$INSTALL_DIR" ]]; then
    pass "Install directory found: $INSTALL_DIR"
else
    fail "Install directory missing: $INSTALL_DIR"
    echo "       → Run QuickClaw_Install.command"
fi

# Verify we're not in a temp or weird location
case "$SCRIPT_DIR" in
    /tmp/*|/private/tmp/*)
        warn "Running from temp directory — consider moving to a permanent location"
        ;;
    *)
        pass "Install location looks stable"
        ;;
esac

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Check 2: OpenClaw config exists
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}2. OpenClaw config${NC}"

if [[ -d "$CONFIG_DIR" ]]; then
    pass "Config directory exists"
else
    fail "Config directory missing: $CONFIG_DIR"
fi

if [[ -f "$CONFIG_DIR/default.yaml" ]]; then
    # Check if file is not empty
    if [[ -s "$CONFIG_DIR/default.yaml" ]]; then
        pass "default.yaml exists and is not empty"
    else
        warn "default.yaml exists but is empty"
    fi
else
    fail "default.yaml not found at $CONFIG_DIR/default.yaml"
    echo "       → Run QuickClaw_Install.command to generate default config"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Check 3: Node and OpenClaw CLI available
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}3. CLI tools${NC}"

# Homebrew path (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Node.js
if command -v node &>/dev/null; then
    NODE_VER=$(node -v)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
    if [[ "$NODE_MAJOR" -ge 18 ]]; then
        pass "Node.js $NODE_VER (meets v18+ requirement)"
    else
        warn "Node.js $NODE_VER — recommend upgrading to v18+"
    fi
else
    fail "Node.js not found in PATH"
    echo "       → Run QuickClaw_Install.command or: brew install node"
fi

# npm
if command -v npm &>/dev/null; then
    pass "npm $(npm -v)"
else
    fail "npm not found"
fi

# OpenClaw CLI
CLAW_FOUND=false
if command -v open-claw &>/dev/null; then
    CLAW_VER=$(open-claw --version 2>/dev/null || echo "installed")
    pass "OpenClaw CLI available: $CLAW_VER"
    CLAW_FOUND=true
elif command -v openclaw &>/dev/null; then
    CLAW_VER=$(openclaw --version 2>/dev/null || echo "installed")
    pass "OpenClaw CLI (openclaw): $CLAW_VER"
    CLAW_FOUND=true
elif npx open-claw --version &>/dev/null 2>&1; then
    pass "OpenClaw available via npx"
    CLAW_FOUND=true
fi

if [[ "$CLAW_FOUND" == false ]]; then
    fail "OpenClaw CLI not found"
    echo "       → Run QuickClaw_Install.command"
fi

# Antfarm
if command -v antfarm &>/dev/null; then
    pass "Antfarm CLI available"
else
    warn "Antfarm CLI not found — optional but recommended"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Check 4: Dashboard health endpoint
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}4. Dashboard health${NC}"

if [[ -f "$DASHBOARD_DIR/server.js" ]]; then
    pass "Dashboard server.js exists"
else
    fail "Dashboard server.js not found"
fi

if [[ -f "$DASHBOARD_DIR/public/index.html" ]]; then
    pass "Dashboard index.html exists"
else
    warn "Dashboard index.html missing"
fi

if [[ -d "$DASHBOARD_DIR/node_modules" ]]; then
    pass "Dashboard dependencies installed"
else
    warn "Dashboard node_modules missing — run: cd dashboard-files && npm install"
fi

# Check if dashboard is responding
DASHBOARD_HEALTHY=false
if curl -sf http://localhost:3000/api/health --max-time 3 &>/dev/null; then
    HEALTH_RESPONSE=$(curl -sf http://localhost:3000/api/health --max-time 3)
    pass "Dashboard health endpoint responding"
    DASHBOARD_HEALTHY=true
    # Try to parse status
    if echo "$HEALTH_RESPONSE" | grep -q '"ok"' 2>/dev/null || echo "$HEALTH_RESPONSE" | grep -q '"healthy"' 2>/dev/null; then
        pass "Dashboard reports healthy status"
    fi
elif curl -sf http://localhost:3000 --max-time 3 &>/dev/null; then
    warn "Dashboard serving on :3000 but no /api/health endpoint"
    DASHBOARD_HEALTHY=true
else
    warn "Dashboard not responding on http://localhost:3000"
    echo "       → Start with QuickClaw_Launch.command"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Check 5: Gateway process
# ═══════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}5. Gateway process${NC}"

GATEWAY_RUNNING=false

# Check PID file
if [[ -f "$PID_DIR/gateway.pid" ]]; then
    GW_PID=$(cat "$PID_DIR/gateway.pid")
    if kill -0 "$GW_PID" 2>/dev/null; then
        pass "Gateway process running (PID $GW_PID)"
        GATEWAY_RUNNING=true
    else
        warn "Stale PID file — gateway not running (PID $GW_PID was)"
        echo "       → Start with QuickClaw_Launch.command"
    fi
fi

# Check port as fallback
if [[ "$GATEWAY_RUNNING" == false ]]; then
    if lsof -i :5000 &>/dev/null; then
        LISTENING_PID=$(lsof -t -i :5000 2>/dev/null | head -1)
        pass "Something listening on port 5000 (PID $LISTENING_PID)"
        GATEWAY_RUNNING=true
    else
        warn "Gateway not detected on port 5000"
        echo "       → Start with QuickClaw_Launch.command"
    fi
fi

# Try a request to the gateway
if [[ "$GATEWAY_RUNNING" == true ]]; then
    if curl -sf http://localhost:5000 --max-time 3 &>/dev/null; then
        pass "Gateway responding to HTTP requests"
    elif curl -sf http://localhost:5000/health --max-time 3 &>/dev/null; then
        pass "Gateway health endpoint responding"
    else
        warn "Gateway process running but not responding to HTTP"
        echo "       → Check logs: logs/gateway.log"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# Results
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}════════════════════════════════════════════${NC}"
TOTAL=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))

echo -e "  Results:  ${GREEN}$PASS_COUNT pass${NC}  ${YELLOW}$WARN_COUNT warn${NC}  ${RED}$FAIL_COUNT fail${NC}  (${TOTAL} checks)"
echo ""

if [[ "$FAIL_COUNT" -eq 0 && "$WARN_COUNT" -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}All checks passed.${NC} QuickClaw is healthy."
elif [[ "$FAIL_COUNT" -eq 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}Mostly good.${NC} $WARN_COUNT warning(s) — review above."
else
    echo -e "  ${RED}${BOLD}$FAIL_COUNT check(s) failed.${NC} See details above."
    echo ""
    echo "  Quick fixes:"
    echo "    • Run QuickClaw_Install.command to repair missing components"
    echo "    • Run QuickClaw_Launch.command to start services"
    echo "    • Run QuickClaw Doctor.command for detailed diagnostics"
fi

echo ""
echo "  Report issues: https://github.com/guyingoldglasses/QuickClaw/issues"
echo "                 https://guyingoldglasses.com"
echo ""
