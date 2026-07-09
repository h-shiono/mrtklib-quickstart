# ============================================================================
#  usb-attach.ps1  -  attach the mosaic-G5 to WSL
#
#  Role: use usbipd-win to detect the mosaic-G5's busid by VID:PID, then
#        bind and attach it.
#
#  Idempotency: if already attached, do nothing (do not error on re-attach).
# ============================================================================

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# mosaic-G5 identifier (TODO: replace with the real VID:PID).
$VID_PID = 'XXXX:XXXX'

Write-Step "Attaching the USB device (mosaic-G5) to WSL"

if (-not (Test-Command 'usbipd')) {
    Fail-With-Hint "usbipd not found" `
                   "Install usbipd-win (see docs 20-install)"
}

# TODO: implement
#  1. Find the line matching $VID_PID in `usbipd list` and get its busid
#  2. If not bound: `usbipd bind --busid <busid>`
#  3. If not attached: `usbipd attach --wsl --busid <busid>`
#  4. Idempotent: if already attached, treat as OK and return

Write-Warn "usb-attach.ps1 is not implemented yet (skeleton)"
