# macOS launch scripts (maintainer technical notes)

Participant-facing instructions live in [`docs/ja/31-run-macos.qmd`](../../docs/ja/31-run-macos.qmd).
This file is for **people who edit the scripts**.

## Files and responsibilities

| File | Responsibility |
|------|----------------|
| `start.command` | Double-click entry point. Fixes the working directory and calls `lib/` |
| `lib/` | macOS core logic (to be implemented) |

## Differences from Windows (important)

- macOS has no `usbipd-win` concept. How USB / serial devices are passed into the
  container differs fundamentally from Windows, so `lib/` is a separate implementation.
- Mind Docker Desktop for Mac's device-passthrough constraints (handling of `--device`).

## Distribution notes

- **Execute permission**: `chmod +x start.command` is required. The execute bit is
  easily lost under git, so handle it in CI or document it.
- **Gatekeeper / notarization**: the first run is blocked. Provide guidance in the docs
  for right-click -> Open, or `xattr -d com.apple.quarantine start.command`.

## TODO (skeleton stage, before implementation)

- [ ] `lib/common.sh`: prerequisite checks (verify Docker Desktop is running, etc.)
- [ ] `lib/configure-receiver.sh`: receiver setup over serial
- [ ] `lib/run-container.sh`: `docker run` -> open the browser
- [ ] Decide the device-passthrough approach (investigate the Mac USB path)
