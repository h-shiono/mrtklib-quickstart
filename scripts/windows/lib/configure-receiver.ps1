# ============================================================================
#  configure-receiver.ps1  -  configure the mosaic-G5 over its COM port
#
#  Role: BEFORE attaching the USB device to WSL, send the receiver's ASCII
#        configuration commands from the Windows side. Once usbipd attaches the
#        device to WSL, Windows can no longer see the COM port, so this must run
#        first (start.bat orders it before usb-attach.ps1).
#
#  What it configures (mirrors the manual RxControl steps, see receiver setup
#  doc). Command syntax is from the mosaic-G5 Firmware Reference Guide:
#    setSignalTracking,+QZSL6            enable QZSS L6 -> yields QZSRawL6D/E
#    setSatelliteTracking,all            track all constellations
#    setDataInOut,USB1, ,+SBF            allow SBF output on USB1
#    setSBFOutput,Stream1,USB1,Support,sec1   SBF "Support" group @ 1 Hz on USB1
#    exeCopyConfigFile,Current,Boot      persist so it survives a power cycle
#
#  The "Support" group includes QZSRawL6D/QZSRawL6E plus MeasEpoch and the nav
#  messages, i.e. everything the engine needs for MADOCA-PPP.
#
#  Idempotency: every command is safe to re-send; re-running just re-applies the
#  same configuration.
# ============================================================================

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# --- mosaic-G5 USB identifier (must match usb-attach.ps1) --------------------
$VendorId  = '152A'
$ProductId = '8231'
$IdPattern = "VID_${VendorId}&PID_${ProductId}"

# --- Command sequence -------------------------------------------------------
$Commands = @(
    'setSignalTracking,+QZSL6'
    'setSatelliteTracking,all'
    'setDataInOut,USB1, ,+SBF'
    'setSBFOutput,Stream1,USB1,Support,sec1'
    'exeCopyConfigFile,Current,Boot'
)

Write-Step "Configuring the receiver over COM"

# --- Find the receiver's Windows COM port -----------------------------------
# The mosaic-G5 exposes two virtual COM ports; commands are accepted on either,
# so we use the first one. If none is found the device is likely still attached
# to WSL (detach first) or simply not connected.
function Find-ReceiverComPort {
    $entities = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
        Where-Object { $_.PNPDeviceID -match $IdPattern -and $_.Name -match '\(COM\d+\)' }
    foreach ($e in $entities) {
        if ($e.Name -match '\((COM\d+)\)') { return $matches[1] }
    }
    return $null
}

$com = Find-ReceiverComPort
if (-not $com) {
    Fail-With-Hint "No Septentrio COM port found" `
                   "Connect the receiver, close RxControl, and detach it from WSL (detach.bat) first"
}
Write-Ok "Using receiver COM port $com"

# --- Open the serial port ---------------------------------------------------
# USB CDC ignores the baud rate, but a value is required. CR terminates each
# Septentrio command.
$sp = New-Object System.IO.Ports.SerialPort $com, 115200, 'None', 8, 'One'
$sp.NewLine      = "`r"
$sp.ReadTimeout  = 2000
$sp.WriteTimeout = 2000
$sp.DtrEnable    = $true
$sp.RtsEnable    = $true

try {
    $sp.Open()
} catch {
    Fail-With-Hint "Could not open $com ($($_.Exception.Message))" `
                   "Close RxControl (it holds the port) and make sure the device is not attached to WSL"
}

# Send one command and wait for the receiver's acknowledgement.
#   valid command  -> reply begins with '$R:' (or '$R;' for block-style replies)
#   invalid command-> reply begins with '$R?'
function Send-RxCommand {
    param([System.IO.Ports.SerialPort]$Port, [string]$Cmd)

    $Port.DiscardInBuffer()
    $Port.Write($Cmd + "`r")

    $resp     = ''
    $deadline = (Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
        try { $resp += $Port.ReadExisting() } catch {}
        if ($resp -match '\$R\?' -or $resp -match '\$R[:;]') {
            Start-Sleep -Milliseconds 100
            try { $resp += $Port.ReadExisting() } catch {}
            break
        }
    }

    if ($resp -match '\$R\?') {
        Fail-With-Hint "Receiver rejected: $Cmd" "Reply: $($resp.Trim())"
    }
    if ($resp -notmatch '\$R[:;]') {
        Fail-With-Hint "No acknowledgement for: $Cmd" `
                       "Reply so far: $($resp.Trim()); is this the receiver's command port?"
    }
    Write-Ok "  $Cmd"
}

try {
    # Force a clean command prompt: a run of 'S' resets any partial input line.
    $sp.DiscardInBuffer()
    $sp.Write("SSSSSSSSSS`r")
    Start-Sleep -Milliseconds 500
    $sp.DiscardInBuffer()

    foreach ($cmd in $Commands) {
        Send-RxCommand -Port $sp -Cmd $cmd
    }
}
finally {
    if ($sp.IsOpen) { $sp.Close() }
    $sp.Dispose()
}

Write-Ok "Receiver configured and saved to boot configuration"
