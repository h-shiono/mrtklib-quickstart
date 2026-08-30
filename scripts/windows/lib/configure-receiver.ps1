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
#    setSBFOutput,Stream1,USB1,Support,sec1   SBF "Support" group @ 1 Hz on USB1
#    setDataInOut,USB1, ,+SBF            allow SBF output on USB1
#    exeCopyConfigFile,Current,Boot      persist so it survives a power cycle
#
#  The "Support" group includes QZSRawL6D/QZSRawL6E plus MeasEpoch and the nav
#  messages, i.e. everything the engine needs for MADOCA-PPP.
#
#  Idempotency: every command is safe to re-send; re-running just re-applies the
#  same configuration.
#
#  Streaming contamination: on a receiver configured by a previous run, the
#  boot config streams SBF on USB1 from power-up, and the COM port used here
#  may be that very connection (Windows picks whichever of the two ports it
#  enumerates first). Binary SBF interleaved with the ASCII replies used to
#  trip the ack parser: ReadExisting() decodes with the port's Encoding, and
#  the default (ASCII) turns every byte >= 0x80 into '?', so a '$R' + high
#  byte inside an SBF block reads as the rejection marker '$R?'. Three
#  defenses below keep the parser honest:
#    1. output on BOTH USB connections is silenced before any reply is parsed
#       (and only re-enabled by the last configuration command),
#    2. the port decodes as Latin-1, so binary bytes map 1:1 instead of
#       collapsing onto '?',
#    3. the reply loop only judges '$R?' after the ack deadline has truly
#       passed, so a chance match in noise can no longer outrun the real ack.
# ============================================================================

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# --- Command sequence -------------------------------------------------------
# Ordered so that setDataInOut,USB1,...,+SBF comes as late as possible: the
# moment it executes, a previously-saved Stream1 starts flowing again, and
# every command after it is parsed on a line carrying binary SBF. Only
# exeCopyConfigFile has to live with that (it must run last to persist the
# +SBF state), and the hardened reply parser below tolerates it.
$Commands = @(
    'setSignalTracking,+QZSL6'
    'setSatelliteTracking,all'
    'setSBFOutput,Stream1,USB1,Support,sec1'
    'setDataInOut,USB1, ,+SBF'
    'exeCopyConfigFile,Current,Boot'
)

Write-Step "Configuring the receiver over COM"

# --- Find the receiver's Windows COM port -----------------------------------
# The mosaic-G5 exposes two virtual COM ports; commands are accepted on either,
# so we use the first one. If none is found the device is likely still attached
# to WSL (detach first) or simply not connected.
function Find-ReceiverComPort {
    $entities = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
        Where-Object { $_.PNPDeviceID -match $ReceiverIdPattern -and $_.Name -match '\(COM\d+\)' }
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
# Latin-1, not the default ASCII: ReadExisting() replaces every byte >= 0x80
# with '?' under ASCII, which inflates the odds of binary SBF decoding to the
# rejection marker '$R?' by ~128x. Latin-1 maps bytes 1:1, so the ASCII
# replies still read fine and binary noise stays binary.
$sp.Encoding = [System.Text.Encoding]::GetEncoding('ISO-8859-1')

try {
    $sp.Open()
} catch {
    Fail-With-Hint "Could not open $com ($($_.Exception.Message))" `
                   "Close RxControl (it holds the port) and make sure the device is not attached to WSL"
}

# Send one command and wait for the receiver's acknowledgement.
#   valid command  -> reply begins with '$R:' (or '$R;' for block-style replies)
#   invalid command-> reply begins with '$R?'
#
# The loop accumulates until the ack or the deadline, and never exits early on
# '$R?': with SBF streaming on this port, binary noise can decode to '$R?' by
# chance, and bailing out on it either rejects a healthy command or reports
# "no acknowledgement" while the true ack was still in flight. Every command
# sent here is from the fixed, known-valid list, so a genuine rejection is the
# rare case -- it is still reported, at the deadline, when the ack has
# demonstrably not arrived.
function Send-RxCommand {
    param([System.IO.Ports.SerialPort]$Port, [string]$Cmd)

    $Port.DiscardInBuffer()
    $Port.Write($Cmd + "`r")

    $resp     = ''
    $deadline = (Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
        try { $resp += $Port.ReadExisting() } catch {}
        if ($resp -match '\$R[:;]') {
            # The marker leads the reply, so its tail (command echo, prompt)
            # may still be in flight. Swallow it here rather than leave it to
            # land after the next command's DiscardInBuffer, where it would
            # muddy that command's reply window and failure diagnostics.
            Start-Sleep -Milliseconds 100
            try { [void]$Port.ReadExisting() } catch {}
            Write-Ok "  $Cmd"
            return
        }
    }

    # Binary bytes (Latin-1 keeps them raw) would garble the console and the
    # error report a participant copies back to us; print them as '.'.
    $shown = ($resp -replace '[^\x20-\x7E]', '.').Trim()
    if ($resp -match '\$R\?') {
        Fail-With-Hint "Receiver rejected: $Cmd" "Reply: $shown"
    }
    Fail-With-Hint "No acknowledgement for: $Cmd" `
                   "Reply so far: $shown; is this the receiver's command port?"
}

# Read and discard incoming data until the line has been silent for $QuietMs
# (true), or until $TimeoutSeconds passes while data keeps arriving (false).
# A fixed sleep-then-discard leaves a race: bytes already in flight through
# the receiver/USB/driver buffers land right after the discard and contaminate
# the first reply window. Waiting for observed silence does not.
function Wait-PortQuiet {
    param(
        [System.IO.Ports.SerialPort]$Port,
        [int]$QuietMs        = 300,
        [int]$TimeoutSeconds = 3
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastData = Get-Date
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 50
        $chunk = ''
        try { $chunk = $Port.ReadExisting() } catch {}
        if ($chunk) {
            $lastData = Get-Date
        } elseif (((Get-Date) - $lastData).TotalMilliseconds -ge $QuietMs) {
            return $true
        }
    }
    return $false
}

try {
    # Force a clean command prompt: a run of 'S' resets any partial input line.
    $sp.DiscardInBuffer()
    $sp.Write("SSSSSSSSSS`r")
    Start-Sleep -Milliseconds 500
    $sp.DiscardInBuffer()

    # Silence the receiver's output on BOTH USB connections before parsing any
    # reply (see "Streaming contamination" above). Sent blind, no ack check:
    # these have to work on the very line state they exist to end. Both are
    # silenced because commands may be talking to either USB port, and a
    # leftover stream from manual experiments (RxControl etc.) can sit on
    # USB2 just as well. USB1's SBF output is restored by the +SBF command in
    # $Commands; USB2 stays silent, which is the quickstart's intended state.
    # If this script dies between here and that +SBF, the silence is not saved
    # to boot, so a power cycle -- or simply the next successful run -- undoes it.
    foreach ($quiet in @('setDataInOut,USB1,,none', 'setDataInOut,USB2,,none')) {
        $sp.Write($quiet + "`r")
        Start-Sleep -Milliseconds 200
    }

    # Let the acks to the two commands above and any in-flight SBF drain out,
    # then start the parsed sequence on an observably quiet line.
    if (-not (Wait-PortQuiet -Port $sp)) {
        Write-Warn "Port $com is still streaming after silencing; replies may be noisy"
    }
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
