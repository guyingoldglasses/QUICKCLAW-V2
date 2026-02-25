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
DASHBOARD_PORT=3000

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

# We intentionally avoid forcing --config because CLI flags can differ by version.
# Running from INSTALL_DIR lets the gateway discover config/default.yaml locally.

GATEWAY_STARTED=false
LAST_GATEWAY_CMD=""

try_start_gateway() {
    local mode="$1"   # bin | npx
    local target="$2" # binary path/name or package name
    local prev_dir="$PWD"

    cd "$INSTALL_DIR" 2>/dev/null || return 1

    if [[ "$mode" == "bin" ]]; then
        nohup "$target" gateway start >> "$GATEWAY_LOG" 2>&1 &
    else
        nohup npx "$target" gateway start >> "$GATEWAY_LOG" 2>&1 &
    fi

    local pid=$!
    cd "$prev_dir" || true

    echo "$pid" > "$PID_DIR/gateway.pid"
    sleep 2

    if kill -0 "$pid" 2>/dev/null; then
        GATEWAY_STARTED=true
        return 0
    fi

    # Fallback for older CLI shape: `<cli> start`
    cd "$INSTALL_DIR" 2>/dev/null || return 1
    if [[ "$mode" == "bin" ]]; then
        nohup "$target" start >> "$GATEWAY_LOG" 2>&1 &
    else
        nohup npx "$target" start >> "$GATEWAY_LOG" 2>&1 &
    fi
    pid=$!
    cd "$prev_dir" || true

    echo "$pid" > "$PID_DIR/gateway.pid"
    sleep 2

    if kill -0 "$pid" 2>/dev/null; then
        GATEWAY_STARTED=true
        return 0
    fi

    rm -f "$PID_DIR/gateway.pid"
    return 1
}

# Candidate order: local install first, then global, then npx
LOCAL_BIN_A="$INSTALL_DIR/node_modules/.bin/open-claw"
LOCAL_BIN_B="$INSTALL_DIR/node_modules/.bin/openclaw"

if [[ -x "$LOCAL_BIN_A" ]]; then
    LAST_GATEWAY_CMD="$LOCAL_BIN_A gateway start"
    try_start_gateway "bin" "$LOCAL_BIN_A"
fi

if [[ "$GATEWAY_STARTED" != true && -x "$LOCAL_BIN_B" ]]; then
    LAST_GATEWAY_CMD="$LOCAL_BIN_B gateway start"
    try_start_gateway "bin" "$LOCAL_BIN_B"
fi

if [[ "$GATEWAY_STARTED" != true && $(command -v open-claw >/dev/null 2>&1; echo $?) -eq 0 ]]; then
    LAST_GATEWAY_CMD="open-claw gateway start"
    try_start_gateway "bin" "open-claw"
fi

if [[ "$GATEWAY_STARTED" != true && $(command -v openclaw >/dev/null 2>&1; echo $?) -eq 0 ]]; then
    LAST_GATEWAY_CMD="openclaw gateway start"
    try_start_gateway "bin" "openclaw"
fi

if [[ "$GATEWAY_STARTED" != true ]]; then
    LAST_GATEWAY_CMD="npx open-claw gateway start"
    try_start_gateway "npx" "open-claw"
fi

if [[ "$GATEWAY_STARTED" != true ]]; then
    LAST_GATEWAY_CMD="npx openclaw gateway start"
    try_start_gateway "npx" "openclaw"
fi

if [[ "$GATEWAY_STARTED" == true ]]; then
    GW_PID=$(cat "$PID_DIR/gateway.pid")
    echo -e "${GREEN}[ok]${NC}    Gateway started (PID $GW_PID)"
    echo -e "        Log: $GATEWAY_LOG"
else
    echo -e "${RED}[fail]${NC}  Gateway did not start after trying multiple commands."
    echo -e "        Last attempted: $LAST_GATEWAY_CMD"
    echo -e "        Check log: $GATEWAY_LOG"
fi

# ---------------------------------------------------------------------------
# Start Dashboard
# ---------------------------------------------------------------------------
echo -e "${BLUE}[info]${NC}  Starting dashboard..."

DASHBOARD_LOG="$LOG_DIR/dashboard.log"
DASHBOARD_PORT=3000
DASHBOARD_STARTED=false

if [[ -f "$DASHBOARD_DIR/server.js" ]]; then
    cd "$DASHBOARD_DIR"

    # Ensure dependencies exist
    if [[ ! -d "node_modules" ]]; then
        echo -e "${BLUE}[info]${NC}  Installing dashboard dependencies..."
        npm install --production >> "$DASHBOARD_LOG" 2>&1
    fi

    # Handle existing listener on 3000 (common stale-process issue)
    PORT_PID=$(lsof -ti tcp:3000 2>/dev/null | head -n1 || true)
    if [[ -n "$PORT_PID" ]]; then
        PORT_CMD=$(ps -p "$PORT_PID" -o command= 2>/dev/null || true)
        if [[ "$PORT_CMD" == *"dashboard-files/server.js"* || "$PORT_CMD" == *"node server.js"* ]]; then
            echo -e "${YELLOW}[warn]${NC}  Existing dashboard process found on :3000 (PID $PORT_PID). Reusing it."
            echo "$PORT_PID" > "$PID_DIR/dashboard.pid"
            DASHBOARD_STARTED=true
        else
            echo -e "${YELLOW}[warn]${NC}  Port 3000 in use by another process (PID $PORT_PID). Starting dashboard on 3001."
            DASHBOARD_PORT=3001
        fi
    fi

    if [[ "$DASHBOARD_STARTED" != true ]]; then
        QUICKCLAW_ROOT="$SCRIPT_DIR" DASHBOARD_PORT="$DASHBOARD_PORT" nohup node server.js >> "$DASHBOARD_LOG" 2>&1 &
        echo $! > "$PID_DIR/dashboard.pid"

        sleep 2
        DB_PID=$(cat "$PID_DIR/dashboard.pid")
        if kill -0 "$DB_PID" 2>/dev/null; then
            DASHBOARD_STARTED=true
        fi
    fi

    if [[ "$DASHBOARD_STARTED" == true ]]; then
        DB_PID=$(cat "$PID_DIR/dashboard.pid" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}[ok]${NC}    Dashboard started (PID $DB_PID)"
        echo -e "        URL: ${BOLD}http://localhost:${DASHBOARD_PORT}${NC}"
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
echo "  Dashboard:  http://localhost:${DASHBOARD_PORT}"
echo "  Gateway:    http://localhost:5000 (default)"
echo ""
echo "  Stop with:  QuickClaw_Stop.command"
echo ""
