# ⚡ QuickClaw V2

One-click OpenClaw installer for macOS (local or external SSD), with a **stable core install** and optional **guided add-ons** after first launch.

> **Hobby project disclaimer**
>
> QuickClaw V2 is a community-driven hobby project. Bugs and rough edges are expected.
> If you find issues, please report them so we can improve it together:
> - GitHub Issues (this repo)
> - https://guyingoldglasses.com

---

## V2 Goals

- Keep core install simple and reliable
- Add post-install verification checks
- Add guided setup for optional advanced features
- Preserve user control, portability, and low-cost operation
- Keep updates safe with backup/rollback paths

---

## What’s Included (Core)

| File | Purpose |
|---|---|
| `QuickClaw_Install.command` | Core installer (OpenClaw + dashboard + launch scripts) |
| `QuickClaw_Launch.command` | Finds install and starts services |
| `QuickClaw Doctor.command` | Health checks and diagnostics |
| `QuickClaw_Verify.command` | Post-install verification (core checks + readiness summary) |
| `QuickClaw_Stop.command` | Safe shutdown (+ optional SSD eject) |
| `dashboard-files/` | Command center dashboard server/frontend |

---

## Install (macOS)

1. Download the **release ZIP** from GitHub Releases (recommended)
2. Extract
3. Double-click `QuickClaw_Install.command`
4. Complete prompts

### If macOS blocks opening `.command`

macOS Gatekeeper may block unsigned scripts. Try in this order:

1. Right-click file → **Open**
2. If blocked, open **System Settings → Privacy & Security** and choose **Open Anyway**
3. Re-run the file

Optional terminal fallback (advanced users):

```bash
xattr -dr com.apple.quarantine "/path/to/QuickClawV2"
```

Only run that command if you trust the source of the files.

---

## V2 Architecture (Implementation Direction)

### Stage 1: Core install
- Minimal dependencies
- Known-good path to working dashboard + gateway
- No brittle optional integrations during core setup

### Stage 2: Guided add-ons (from dashboard)
- Optional integrations and skill packs
- Step-by-step setup with compatibility checks
- Clear enable/disable controls

---

## Planned V2 Additions

- Safe mode install fallback
- Post-install verification screen
- One-click debug bundle export
- Versioned feature packs
- Rollback snapshots before updates
- First-run onboarding checklist
- Trust/safety panel (what is local vs external)

See `docs/V2_PLAN.md` for details.

---

## Community

If you want to contribute ideas, testing results, or fixes:
- Open an issue in this repo
- Share practical feedback and reproducible steps
- Join us through https://guyingoldglasses.com

No hype, just useful improvements.
