#!/usr/bin/env bash
# ============================================================================
#  mrtklib-quickstart  -  macOS entry point
#
#  A .command file that launches on double-click.
#  Its responsibilities are kept minimal here:
#    1) cd into the script's own directory (needed for double-click launch)
#    2) Invoke the core logic under lib/
#
#  Notes:
#    - Requires execute permission:  chmod +x start.command
#    - If blocked by Gatekeeper: right-click -> Open, or see the docs
#    - macOS USB path differs from Windows (no usbipd), so lib/ is a separate impl
# ============================================================================
set -euo pipefail

# Anchor everything to the script's location, even on double-click launch.
cd "$(dirname "$0")"
LIB="$(pwd)/lib"

echo "==> Starting mrtklib-quickstart (macOS)"

# --- Invoke the core logic (order matters) ----------------------------------
#  TODO: finalize this orchestration once lib/ is implemented.
#    1. prerequisite checks (Docker Desktop, ...)
#    2. receiver initial setup (over serial)
#    3. prepare USB / serial device passthrough
#    4. docker run -> open the browser
#
#  Example:
#    source "$LIB/common.sh"
#    "$LIB/configure-receiver.sh"
#    "$LIB/run-container.sh"

echo "[!!] macOS logic (lib/) is not implemented yet (skeleton)"
echo "     See docs/ja/31-run-macos for the procedure."

# Keep the window open on double-click launch so it does not close immediately.
read -r -p "Press Enter to close..."
