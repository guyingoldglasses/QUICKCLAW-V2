#!/bin/bash
# ============================================================================
# QuickClaw_Stop.command — v2
# Gracefully stops OpenClaw gateway and dashboard
# https://github.com/guyingoldglasses/QuickClaw
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_DIR="$SCRIPT_DIR/.pids"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          ${BOLD}QuickClaw Stop v2${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

STOPPED_SOMETHING=false

# ---------------------------------------------------------------------------
# Stop by PID file
# ---------------------------------------------------------------------------
stop_process() {
    local NAME="$1"
    local PID_FILE="$PID_DIR/$2.pid"

    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "${BLUE}[info]${NC}  Stopping $NAME (PID $PID)..."
            kill "$PID" 2>/dev/null

            # Wait up to 5 seconds for graceful shutdown
            for i in {1..10}; do
                if ! kill -0 "$PID" 2>/dev/null; then
                    break
                fi
                sleep 0.5
            done

            # Force kill if still running
            if kill -0 "$PID" 2>/dev/null; then
                echo -e "${YELLOW}[warn]${NC}  $NAME didn't stop gracefully. Force killing..."
                kill -9 "$PID" 2>/dev/null
                sleep 1
            fi

            if ! kill -0 "$PID" 2>/dev/null; then
                echo -e "${GREEN}[ok]${NC}    $NAME stopped"
                STOPPED_SOMETHING=true
            else
                echo -e "${RED}[fail]${NC}  Could not stop $NAME (PID $PID)"
            fi
        else
            echo -e "${YELLOW}[info]${NC}  $NAME (PID $PID) was not running"
        fi
        rm -f "$PID_FILE"
    fi
}

stop_process "OpenClaw gateway" "gateway"
stop_process "Dashboard" "dashboard"

# ---------------------------------------------------------------------------
# Sweep for orphan processes (fallback)
# ---------------------------------------------------------------------------
echo -e "${BLUE}[info]${NC}  Checking for orphan processes..."

# Check for any node processes running from our directory
ORPHANS=$(pgrep -f "$SCRIPT_DIR" 2>/dev/null || true)

if [[ -n "$ORPHANS" ]]; then
    echo -e "${YELLOW}[warn]${NC}  Found orphan processes tied to QuickClaw:"
    while IFS= read -r OPID; do
        PROC_NAME=$(ps -p "$OPID" -o comm= 2>/dev/null || echo "unknown")
        echo -e "        PID $OPID ($PROC_NAME)"
        kill "$OPID" 2>/dev/null
        STOPPED_SOMETHING=true
    done <<< "$ORPHANS"
    sleep 1
    echo -e "${GREEN}[ok]${NC}    Orphan processes cleaned up"
else
    echo -e "${GREEN}[ok]${NC}    No orphan processes found"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
if [[ "$STOPPED_SOMETHING" == true ]]; then
    echo -e "${GREEN}QuickClaw stopped.${NC}"
else
    echo -e "${YELLOW}Nothing was running.${NC}"
fi
echo ""
