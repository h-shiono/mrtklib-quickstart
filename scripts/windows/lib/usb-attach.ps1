# ============================================================================
#  usb-attach.ps1  -  attach the mosaic-G5 to WSL
#
#  Role: use usbipd-win (v4+/v5) to find the mosaic-G5 among the *currently
#        connected* USB devices by VID:PID, then bind and attach it to WSL so
#        the container can read the two virtual COM ports (raw / CON).
#
#  Idempotency: if the device is already attached, do nothing.
# ============================================================================

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# --- mosaic-G5 USB identifier -----------------------------------------------
# The receiver enumerates as ONE composite USB device that exposes BOTH virtual
# COM ports (Port 1 / Port 2), so attaching this single device hands both ports
# to WSL at once.
#   usbipd state -> InstanceId "USB\VID_152A&PID_8231\..."
$VendorId  = '152A'
$ProductId = '8231'
$IdPattern = "VID_${VendorId}&PID_${ProductId}"

Write-Step "Attaching the USB device (mosaic-G5) to WSL"

if (-not (Test-Command 'usbipd')) {
    Fail-With-Hint "usbipd not found" `
                   "Install usbipd-win (see docs: install / usbipd-win)"
}

# --- Locate the currently connected mosaic-G5 -------------------------------
# `usbipd state` returns JSON. A device that was bound once but is now unplugged
# lingers in the list with BusId = null (a persisted entry with the same
# VID:PID). Filter on BusId so we only match what is plugged in right now.
try {
    $state = usbipd state | ConvertFrom-Json
} catch {
    Fail-With-Hint "Failed to run 'usbipd state'" `
                   "Reinstall usbipd-win, or run 'usbipd list' manually to check"
}

$devices = @($state.Devices | Where-Object { $_.InstanceId -match $IdPattern -and $_.BusId })

if ($devices.Count -eq 0) {
    Fail-With-Hint "mosaic-G5 (VID_${VendorId}&PID_${ProductId}) is not connected" `
                   "Reconnect the receiver by USB and confirm its driver (RxTools) is installed"
}
if ($devices.Count -gt 1) {
    Write-Warn "Multiple mosaic-G5 devices found; using the first (BusId $($devices[0].BusId))"
}
$dev   = $devices[0]
$busid = $dev.BusId
Write-Ok "Found mosaic-G5 at BusId $busid"

# --- Idempotent: already attached? ------------------------------------------
if ($dev.ClientIPAddress) {
    Write-Ok "Already attached to WSL (client $($dev.ClientIPAddress)); nothing to do"
    return
}

# --- Bind (share). Requires administrator; start.bat self-elevates. ----------
# Binding is idempotent: re-binding an already-shared device is a no-op.
Write-Step "Binding BusId $busid (usbipd bind)"
usbipd bind --busid $busid
if ($LASTEXITCODE -ne 0) {
    Fail-With-Hint "usbipd bind failed (exit $LASTEXITCODE)" `
                   "Run start.bat as administrator (bind requires elevation)"
}

# --- Attach to WSL ----------------------------------------------------------
Write-Step "Attaching BusId $busid to WSL (usbipd attach --wsl)"
usbipd attach --wsl --busid $busid
if ($LASTEXITCODE -ne 0) {
    Fail-With-Hint "usbipd attach failed (exit $LASTEXITCODE)" `
                   "Make sure WSL2 is running and a WSL distribution is available"
}

Write-Ok "mosaic-G5 attached to WSL (BusId $busid); both COM ports are now available in WSL"
