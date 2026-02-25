# QuickClaw v2

**One-click installer for [OpenClaw](https://github.com/open-claw) on macOS.**

QuickClaw gets OpenClaw running on your Mac with minimal setup — double-click to install, double-click to launch. Works on internal drives and external SSDs.

> **Hobby project disclaimer:** QuickClaw is a community tool maintained by [Guy in Gold Glasses](https://guyingoldglasses.com). It is not officially affiliated with the OpenClaw project. Use at your own discretion. Things may break between upstream releases — that's normal.

---

## What's in the box

| File | Purpose |
|------|---------|
| `START_HERE.html` | **Open this first.** Visual setup guide — works in any browser |
| `QuickClaw_Setup.command` | One-time bootstrap — unlocks all scripts and runs the installer |
| `QuickClaw_Install.command` | Installs Node.js (if needed), OpenClaw, Antfarm, and the dashboard |
| `QuickClaw_Launch.command` | Starts OpenClaw + dashboard in one click |
| `QuickClaw_Stop.command` | Gracefully stops all QuickClaw processes |
| `QuickClaw Doctor.command` | Diagnoses common issues and suggests fixes |
| `QuickClaw_Verify.command` | Runs pass/warn/fail health checks on your installation |

## Quick start

### First time (download from GitHub)

1. Click **Code → Download ZIP** on GitHub and unzip the folder
2. Open **`START_HERE.html`** — it opens in your browser with visual instructions
3. Follow the one-step setup (copy one line into Terminal, press Enter)
4. Done — from now on, just double-click the `.command` files to use QuickClaw

### If you use git

```bash
git clone https://github.com/guyingoldglasses/QuickClaw.git
cd QuickClaw
double-click QuickClaw_Install.command
```

Files pulled via `git clone` skip the Gatekeeper step entirely.

---

## macOS Gatekeeper

macOS blocks downloaded scripts by default. **The easiest fix is to open `START_HERE.html` and follow the one-step setup** — it handles everything.

If you've already done that (or used `git clone`), you can skip this section entirely.

For reference, here are the manual approaches:

### Option A — Right-click → Open (recommended)

1. Right-click (or Control-click) the `.command` file
2. Select **Open** from the context menu
3. Click **Open** in the dialog that appears
4. macOS remembers this choice — you only need to do it once per file

### Option B — System Settings

1. Double-click the file (it will be blocked)
2. Open **System Settings → Privacy & Security**
3. Scroll down — you'll see a message about the blocked file
4. Click **Open Anyway**
5. Confirm when prompted

### Option C — Remove quarantine flag (advanced)

If you're comfortable with Terminal, you can strip the quarantine attribute:

```bash
xattr -d com.apple.quarantine QuickClaw_Install.command
xattr -d com.apple.quarantine QuickClaw_Launch.command
xattr -d com.apple.quarantine QuickClaw_Stop.command
xattr -d com.apple.quarantine "QuickClaw Doctor.command"
xattr -d com.apple.quarantine QuickClaw_Verify.command
```

> **Caution:** Only do this for files you trust and have downloaded yourself. Removing quarantine flags bypasses a real security check.

---

## External SSD support

QuickClaw works fine on external SSDs. The installer detects its own location and installs relative to that path. Just keep the QuickClaw folder on whatever drive you prefer.

If you move the folder after install, run `QuickClaw_Install.command` again to relink paths.

---

## Dashboard

The built-in dashboard runs at `http://localhost:3000` and gives you:

- OpenClaw process status (running / stopped)
- Quick start/stop controls
- Log viewer
- **Add-ons & Integrations** panel — check status and configure optional features like OpenAI auth, FTP, email, and skills bundles

The dashboard is optional. OpenClaw works fine without it.

---

## Troubleshooting

Run **QuickClaw Doctor.command** first — it catches most common issues.

Run **QuickClaw_Verify.command** for a quick pass/fail health check of your installation.

If something is still broken:

1. **GitHub Issues:** [github.com/guyingoldglasses/QuickClaw/issues](https://github.com/guyingoldglasses/QuickClaw/issues)
2. **Website:** [guyingoldglasses.com](https://guyingoldglasses.com) — use the contact form or leave a comment

Include the output of `QuickClaw Doctor.command` and `QuickClaw_Verify.command` in your report. It helps a lot.

---

## v2 changelog

- **Added `START_HERE.html`** — visual setup guide that opens in any browser, no Gatekeeper issues
- **Added `QuickClaw_Setup.command`** — one-time bootstrap that unquarantines all scripts and runs install
- Added `QuickClaw_Verify.command` for quick health checks
- Dashboard: new Add-ons & Integrations section with status cards
- Installer: updated to pull latest compatible OpenClaw + Antfarm
- Installer: cleaner post-install summary with Verify reminder
- Doctor: improved diagnostic checks
- README: added Gatekeeper instructions, hobby disclaimer, bug reporting info
- All scripts: safer error handling, preserved v1 behavior

---

## License

MIT — do whatever you want with it.

Built by [Guy in Gold Glasses](https://guyingoldglasses.com).
