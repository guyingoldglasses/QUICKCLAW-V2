#!/bin/bash
# QuickClaw V2 Verify — post-install verification

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
clear

echo ""
echo -e "${CYAN}${BOLD}  ✅ QuickClaw Verify${NC}"
echo ""

PASS=0
FAIL=0
WARN=0

ok(){ echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
no(){ echo -e "  ${RED}✕${NC} $1"; FAIL=$((FAIL+1)); }
wa(){ echo -e "  ${YELLOW}⚠${NC} $1"; WARN=$((WARN+1)); }

ROOT=""
if [[ -d "$HOME/OpenClaw" ]]; then ROOT="$HOME/OpenClaw"; fi
if [[ -z "$ROOT" ]]; then
  for vol in /Volumes/*/OpenClaw; do
    [[ -d "$vol" ]] && ROOT="$vol" && break
  done
fi

if [[ -z "$ROOT" ]]; then
  no "OpenClaw install folder not found (~/OpenClaw or /Volumes/*/OpenClaw)"
  echo ""; read -n 1 -s -r -p "Press any key to close..."; exit 1
fi
ok "Install folder detected: $ROOT"

[[ -x "$ROOT/Start OpenClaw.command" ]] && ok "Start script present" || no "Start script missing"
[[ -x "$ROOT/Stop OpenClaw.command" ]] && ok "Stop script present" || no "Stop script missing"
[[ -f "$ROOT/dashboard/server.js" ]] && ok "Dashboard server present" || no "Dashboard server missing"
[[ -f "$HOME/.openclaw/openclaw.json" ]] && ok "OpenClaw config found" || no "~/.openclaw/openclaw.json missing"

export FNM_DIR="$ROOT/env/.fnm"
export PATH="$ROOT/env/.fnm/aliases/default/bin:$ROOT/env/.npm-global/bin:$PATH"

if command -v node >/dev/null 2>&1; then ok "Node.js available ($(node --version 2>/dev/null))"; else no "Node.js not available"; fi
if command -v openclaw >/dev/null 2>&1; then ok "OpenClaw CLI available ($(openclaw --version 2>/dev/null))"; else no "OpenClaw CLI not available"; fi
if command -v antfarm >/dev/null 2>&1; then ok "Antfarm available"; else wa "Antfarm not found (optional depending on install path)"; fi

if pgrep -f "openclaw.gateway" >/dev/null 2>&1; then
  ok "Gateway process is running"
else
  wa "Gateway process not running (start OpenClaw to verify runtime)"
fi

if curl -sf "http://localhost:18810/api/health" >/dev/null 2>&1; then
  ok "Dashboard health endpoint responding"
else
  wa "Dashboard health endpoint not responding (start dashboard to test)"
fi

echo ""
echo -e "  ${BOLD}Summary:${NC} ${GREEN}${PASS} passed${NC}, ${YELLOW}${WARN} warnings${NC}, ${RED}${FAIL} failed${NC}"

if [[ $FAIL -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}Ready for first-run setup and add-ons.${NC}"
else
  echo -e "  ${RED}${BOLD}Fix failed checks before continuing.${NC}"
fi

echo ""
read -n 1 -s -r -p "Press any key to close..."
