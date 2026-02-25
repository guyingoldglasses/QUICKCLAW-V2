#!/bin/bash
# ============================================================================
# QuickClaw_Launch.command — v2
# Starts OpenClaw gateway and dashboard
# https://github.com/guyingoldglasses/QuickClaw
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/openclaw"
DASHBOARD_DIR="$SCRIPT_DIR/dashboard-files"
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

mkdir -p "$PID_DIR" "$LOG_DIR"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         ${BOLD}QuickClaw Launch v2${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# ---------------------------------------------------------------------------
# Check for existing processes
# ---------------------------------------------------------------------------
ALREADY_RUNNING=false

if [[ -f "$PID_DIR/gateway.pid" ]]; then
    OLD_PID=$(cat "$PID_DIR/gateway.pid")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo -e "${YELLOW}[warn]${NC}  OpenClaw gateway already running (PID $OLD_PID)"
        ALREADY_RUNNING=true
    else
        rm -f "$PID_DIR/gateway.pid"
    fi
fi

if [[ -f "$PID_DIR/dashboard.pid" ]]; then
    OLD_PID=$(cat "$PID_DIR/dashboard.pid")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo -e "${YELLOW}[warn]${NC}  Dashboard already running (PID $OLD_PID)"
        ALREADY_RUNNING=true
    else
        rm -f "$PID_DIR/dashboard.pid"
    fi
fi

if [[ "$ALREADY_RUNNING" == true ]]; then
    echo ""
    echo -e "${YELLOW}Some processes are already running.${NC}"
    echo "Run QuickClaw_Stop.command first, or use the dashboard to manage."
    echo ""
    read -p "Continue anyway and start missing services? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# ---------------------------------------------------------------------------
# Homebrew path (Apple Silicon)
# ---------------------------------------------------------------------------
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---------------------------------------------------------------------------
# Start OpenClaw Gateway
# ---------------------------------------------------------------------------
echo -e "${BLUE}[info]${NC}  Starting OpenClaw gateway..."

GATEWAY_LOG="$LOG_DIR/gateway.log"
CONFIG_FILE="$INSTALL_DIR/config/default.yaml"

if [[ -f "$CONFIG_FILE" ]]; then
    CONFIG_FLAG="--config $CONFIG_FILE"
else
    CONFIG_FLAG=""
fi

# Try known commands in order
GATEWAY_STARTED=false

if command -v open-claw &>/dev/null; then
    nohup open-claw start $CONFIG_FLAG >> "$GATEWAY_LOG" 2>&1 &
    echo $! > "$PID_DIR/gateway.pid"
    GATEWAY_STARTED=true
elif command -v openclaw &>/dev/null; then
    nohup openclaw start $CONFIG_FLAG >> "$GATEWAY_LOG" 2>&1 &
    echo $! > "$PID_DIR/gateway.pid"
    GATEWAY_STARTED=true
elif npx open-claw --version &>/dev/null 2>&1; then
    nohup npx open-claw start $CONFIG_FLAG >> "$GATEWAY_LOG" 2>&1 &
    echo $! > "$PID_DIR/gateway.pid"
    GATEWAY_STARTED=true
fi

if [[ "$GATEWAY_STARTED" == true ]]; then
    sleep 2
    GW_PID=$(cat "$PID_DIR/gateway.pid")
    if kill -0 "$GW_PID" 2>/dev/null; then
        echo -e "${GREEN}[ok]${NC}    Gateway started (PID $GW_PID)"
        echo -e "        Log: $GATEWAY_LOG"
    else
        echo -e "${RED}[fail]${NC}  Gateway process exited. Check $GATEWAY_LOG"
    fi
else
    echo -e "${RED}[fail]${NC}  OpenClaw CLI not found. Run QuickClaw_Install.command first."
fi

# ---------------------------------------------------------------------------
# Start Dashboard
# ---------------------------------------------------------------------------
echo -e "${BLUE}[info]${NC}  Starting dashboard..."

DASHBOARD_LOG="$LOG_DIR/dashboard.log"

if [[ -f "$DASHBOARD_DIR/server.js" ]]; then
    cd "$DASHBOARD_DIR"

    # Ensure dependencies exist
    if [[ ! -d "node_modules" ]]; then
        echo -e "${BLUE}[info]${NC}  Installing dashboard dependencies..."
        npm install --production >> "$DASHBOARD_LOG" 2>&1
    fi

    QUICKCLAW_ROOT="$SCRIPT_DIR" nohup node server.js >> "$DASHBOARD_LOG" 2>&1 &
    echo $! > "$PID_DIR/dashboard.pid"

    sleep 2
    DB_PID=$(cat "$PID_DIR/dashboard.pid")
    if kill -0 "$DB_PID" 2>/dev/null; then
        echo -e "${GREEN}[ok]${NC}    Dashboard started (PID $DB_PID)"
        echo -e "        URL: ${BOLD}http://localhost:3000${NC}"
        echo -e "        Log: $DASHBOARD_LOG"
    else
        echo -e "${RED}[fail]${NC}  Dashboard process exited. Check $DASHBOARD_LOG"
    fi

    cd "$SCRIPT_DIR"
else
    echo -e "${YELLOW}[warn]${NC}  Dashboard server.js not found at $DASHBOARD_DIR"
    echo -e "        Skipping dashboard. OpenClaw gateway may still be running."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}QuickClaw is running.${NC}"
echo ""
echo "  Dashboard:  http://localhost:3000"
echo "  Gateway:    http://localhost:5000 (default)"
echo ""
echo "  Stop with:  QuickClaw_Stop.command"
echo ""
