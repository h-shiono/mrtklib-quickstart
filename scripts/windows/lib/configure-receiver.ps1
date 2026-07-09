# ============================================================================
#  configure-receiver.ps1  -  receiver (mosaic-G5) initial setup
#
#  Role: before attaching the USB device to WSL, send configuration commands
#        to the receiver over the COM port from the Windows side.
#        (After attach, Windows can no longer see the COM port, so order matters.)
#
#  Idempotency: the command sequence must be safe to re-send even if already set.
# ============================================================================

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

Write-Step "Configuring the receiver over COM"

# TODO: implement
#  1. Identify the receiver's COM port (detect by VID:PID or device description)
#  2. Open it at the right baud rate and send the config command sequence
#  3. Verify the response and decide completion idempotently
#
#  Example (pseudo-code):
#    $port = Find-ReceiverComPort   # -> "COM5"
#    $sp = New-Object System.IO.Ports.SerialPort $port, 115200
#    $sp.Open()
#    $sp.WriteLine("...config command...")
#    ...

Write-Warn "configure-receiver.ps1 is not implemented yet (skeleton)"
