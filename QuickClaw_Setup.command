#!/bin/bash
# ============================================================================
# QuickClaw_Setup.command — v2 Bootstrap
# One-time setup: removes quarantine flags and runs the installer.
# After this, all QuickClaw scripts work with a normal double-click.
# https://github.com/guyingoldglasses/QuickClaw
# ============================================================================

clear

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}║          ${BOLD}Welcome to QuickClaw${NC}${CYAN}                        ║${NC}"
echo -e "${CYAN}║          First-time setup                              ║${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  This will:"
echo "    1. Allow all QuickClaw scripts to run on your Mac"
echo "    2. Install OpenClaw and its dependencies"
echo "    3. Set up the QuickClaw dashboard"
echo ""
echo -e "  Location: ${BOLD}$SCRIPT_DIR${NC}"
echo ""
read -p "  Ready to start? (Y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "  No problem. Run this again whenever you're ready."
    echo ""
    exit 0
fi

echo ""

# ---------------------------------------------------------------------------
# Step 1: Remove quarantine flags from all QuickClaw files
# ---------------------------------------------------------------------------
echo -e "${CYAN}Step 1 of 2:${NC} Preparing files..."
echo ""

FILE_COUNT=0

# Remove quarantine from all .command files
for f in "$SCRIPT_DIR"/*.command; do
    if [[ -f "$f" ]]; then
        xattr -d com.apple.quarantine "$f" 2>/dev/null
        chmod +x "$f"
        BASENAME=$(basename "$f")
        echo -e "  ${GREEN}✓${NC}  $BASENAME"
        ((FILE_COUNT++))
    fi
done

# Also handle the Doctor script (has a space in filename)
if [[ -f "$SCRIPT_DIR/QuickClaw Doctor.command" ]]; then
    xattr -d com.apple.quarantine "$SCRIPT_DIR/QuickClaw Doctor.command" 2>/dev/null
    chmod +x "$SCRIPT_DIR/QuickClaw Doctor.command"
fi

# Remove quarantine from dashboard files too
if [[ -d "$SCRIPT_DIR/dashboard-files" ]]; then
    xattr -dr com.apple.quarantine "$SCRIPT_DIR/dashboard-files" 2>/dev/null
    echo -e "  ${GREEN}✓${NC}  dashboard-files/"
fi

# Remove quarantine from any other nested files
xattr -dr com.apple.quarantine "$SCRIPT_DIR" 2>/dev/null

echo ""
echo -e "  ${GREEN}Done.${NC} $FILE_COUNT scripts unlocked."
echo ""

# ---------------------------------------------------------------------------
# Step 2: Run the installer
# ---------------------------------------------------------------------------
echo -e "${CYAN}Step 2 of 2:${NC} Running QuickClaw installer..."
echo ""

INSTALLER="$SCRIPT_DIR/QuickClaw_Install.command"

if [[ -f "$INSTALLER" ]]; then
    bash "$INSTALLER"
    INSTALL_EXIT=$?
else
    echo -e "  ${YELLOW}⚠${NC}  QuickClaw_Install.command not found."
    echo "     Make sure all files were extracted from the download."
    echo ""
    exit 1
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}║          ${BOLD}Setup complete!${NC}${CYAN}                              ║${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  From now on, you can just double-click these files:"
echo ""
echo -e "    ${BOLD}QuickClaw_Launch.command${NC}   → Start OpenClaw"
echo -e "    ${BOLD}QuickClaw_Stop.command${NC}     → Stop OpenClaw"
echo -e "    ${BOLD}QuickClaw_Verify.command${NC}   → Check installation health"
echo -e "    ${BOLD}QuickClaw Doctor.command${NC}   → Troubleshoot issues"
echo ""
echo "  You won't need to run this setup again."
echo ""
echo -e "  ${GREEN}Tip:${NC} Launch now? Just double-click ${BOLD}QuickClaw_Launch.command${NC}"
echo -e "  then open ${BOLD}http://localhost:3000${NC} in your browser."
echo ""
