# ============================================================================
#  usb-detach.ps1  -  detach the mosaic-G5 from WSL (teardown)
#
#  Role: reverse of usb-attach.ps1. Return the receiver's two virtual COM
#        ports from WSL back to Windows with `usbipd detach`.
#
#  Notes:
#   - `detach` does NOT require administrator (only bind/unbind do), so the
#     detach.bat entry point does not self-elevate.
#   - The persistent bind is intentionally left in place so the next attach is
#     quick and needs no elevation. Pass -Unbind to also release the share
#     (that step DOES require administrator).
#
#  Idempotency: if the device is missing or already detached, do nothing.
# ============================================================================

param(
    [switch]$Unbind
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# --- mosaic-G5 USB identifier (must match usb-attach.ps1) --------------------
$VendorId  = '152A'
$ProductId = '8231'
$IdPattern = "VID_${VendorId}&PID_${ProductId}"

Write-Step "Detaching the USB device (mosaic-G5) from WSL"

if (-not (Test-Command 'usbipd')) {
    Fail-With-Hint "usbipd not found" `
                   "Install usbipd-win (see docs: install / usbipd-win)"
}

# --- Locate the currently connected mosaic-G5 -------------------------------
try {
    $state = usbipd state | ConvertFrom-Json
} catch {
    Fail-With-Hint "Failed to run 'usbipd state'" `
                   "Run 'usbipd list' manually to check"
}

$devices = @($state.Devices | Where-Object { $_.InstanceId -match $IdPattern -and $_.BusId })

if ($devices.Count -eq 0) {
    Write-Ok "mosaic-G5 is not connected; nothing to detach"
    return
}

$dev   = $devices[0]
$busid = $dev.BusId

# --- Detach (idempotent) ----------------------------------------------------
if ($dev.ClientIPAddress) {
    Write-Step "Detaching BusId $busid (usbipd detach)"
    usbipd detach --busid $busid
    if ($LASTEXITCODE -ne 0) {
        Fail-With-Hint "usbipd detach failed (exit $LASTEXITCODE)" `
                       "Try running 'usbipd detach --busid $busid' manually"
    }
    Write-Ok "mosaic-G5 detached from WSL (BusId $busid); the COM ports return to Windows"
} else {
    Write-Ok "mosaic-G5 (BusId $busid) is not attached to WSL; nothing to detach"
}

# --- Optional: release the persistent bind (requires administrator) ---------
if ($Unbind) {
    Write-Step "Unbinding BusId $busid (usbipd unbind)"
    usbipd unbind --busid $busid
    if ($LASTEXITCODE -ne 0) {
        Fail-With-Hint "usbipd unbind failed (exit $LASTEXITCODE)" `
                       "Run as administrator (unbind requires elevation)"
    }
    Write-Ok "mosaic-G5 unbound (BusId $busid); it is no longer shared"
}
