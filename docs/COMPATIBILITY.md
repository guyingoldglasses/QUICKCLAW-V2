# Compatibility Matrix (Draft)

## Supported
- macOS Ventura (13+) and newer
- Apple Silicon + Intel (to be validated in CI/manual matrix)
- Local install (`~/OpenClaw`) or external SSD (`/Volumes/<drive>/OpenClaw`)

## Known Caveats
- Gatekeeper may block `.command` scripts on first run
- External SSD unplug without safe stop may cause corruption risk
- Some integrations may require additional credentials/providers

## Verification Checklist
- [ ] Installer completes without manual terminal steps
- [ ] Dashboard health endpoint responds
- [ ] Gateway starts and stops cleanly
- [ ] Backup script creates archive successfully
