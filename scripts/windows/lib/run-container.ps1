# ============================================================================
#  run-container.ps1  -  start the mrtklib-docker-ui container -> open the UI
#
#  Role:
#   1. Detect which WSL serial node carries the receiver's SBF stream
#      (fail fast if none is flowing).
#   2. docker run the container, passing that node under a fixed path and the
#      workspace/data volumes, publishing the web UI and solution-output ports.
#   3. Wait for the UI to answer, then open the browser.
#
#  Image / ports / volumes come from the mrtklib-docker-ui README:
#      https://github.com/h-shiono/mrtklib-docker-ui
#
#  Idempotency: an existing container with the same name is removed first.
# ============================================================================

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# --- Configuration ----------------------------------------------------------
# $ContainerName / $HostPort / $OutPort come from common.ps1, so the
# prerequisite check and this script always agree on them.
$Image         = 'hatognss/mrtklib-docker-ui:0.3.0-alpha'   # alt: ghcr.io/h-shiono/mrtklib-docker-ui:0.3.0-alpha
$ContainerPort = 8000
$UiUrl         = "http://localhost:$HostPort"

# Fixed path the receiver's SBF node gets inside the container (see step 1).
# The docs and the bundled preset refer to this name, so keep them in sync.
$ContainerDevice = '/dev/ttyACM0'

# Host directories for the container volumes (created if missing).
# NOTE: start.bat self-elevates via UAC, so $env:USERPROFILE would resolve to
# the *elevating admin* account, not the interactive user. On machines where the
# admin account differs (e.g. a standard user elevating with a separate admin),
# that path lives under another profile the logged-in user (and Docker Desktop)
# cannot access -> "Access is denied" on the bind mount. Anchor the volumes to
# the extracted project folder instead: the user always has access there and
# Docker Desktop can mount it. ($PSScriptRoot = scripts\windows\lib -> repo root
# is three levels up.)
$RepoRoot  = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$DataRoot  = Join-Path $RepoRoot 'mrtklib-quickstart-data'
$Workspace = Join-Path $DataRoot 'workspace'
$DataDir   = Join-Path $DataRoot 'data'

# Optional credentials for data download (leave unset to omit).
#   $env:EARTHDATA_USER / $env:EARTHDATA_PASSWORD / $env:GSI_USER / $env:GSI_PASSWORD

Write-Step "Starting the mrtklib-docker-ui container"

if (-not (Test-Command 'docker')) {
    Fail-With-Hint "docker command not found" `
                   "Install and start Docker Desktop (see docs: install)"
}

# --- 1. Detect the SBF serial node inside WSL -------------------------------
# The receiver's SBF stream is on one of /dev/ttyACM*; detect-sbf-port.sh reads
# each and returns the one carrying SBF. It runs in WSL, where the device lives.
Write-Step "Detecting the SBF serial port in WSL"
$detectWin = Join-Path $PSScriptRoot 'detect-sbf-port.sh'
if (-not (Test-Path -LiteralPath $detectWin)) {
    Fail-With-Hint "detect-sbf-port.sh not found next to run-container.ps1" `
                   "Re-download the scripts folder"
}
# Hand the script to WSL by value instead of translating its Windows path to a
# WSL path: wslpath cannot handle a UNC path (\\wsl.localhost\...) when the
# scripts live on the WSL filesystem. Strip CRs so bash does not choke if the
# file was checked out with CRLF, and drop a leading BOM if one is there.
$detectText = (Get-Content -Raw -LiteralPath $detectWin) -replace "`r", ""
$detectText = $detectText.TrimStart([char]0xFEFF)

# Pass it as a base64 *argument*, not on stdin. Windows PowerShell 5.1 fixes the
# encoding it uses for a native command's stdin when the process starts: if the
# console is already at code page 65001 -- which a native tool run earlier in
# start.bat can leave behind -- it writes a UTF-8 BOM ahead of the text, and
# assigning $OutputEncoding afterwards does not undo it. bash then reads
# "<BOM>#!/usr/bin/env" as a command and prints "No such file or directory".
# base64 is pure ASCII, so an argument is immune to whatever the code page is.
$detectB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($detectText))

# Fail on the real cause rather than on its symptom: without the nodes, the
# detector can only report "no SBF stream", which sends the participant off to
# re-check the receiver's output configuration when nothing is attached at all.
if (-not (Wait-WslSerialNode 15)) {
    Fail-With-Hint "No /dev/ttyACM* in WSL: the receiver is not attached" `
                   "Run start.bat (or usb-attach.ps1) so usbipd attaches the receiver to WSL"
}

$sbfDevice = (wsl bash -c "echo $detectB64 | base64 -d | bash -s -- 3" | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $sbfDevice) {
    Fail-With-Hint "No SBF stream detected on the receiver's ports" `
                   "Set the receiver's SBF output to USB1 (see receiver setup)"
}
Write-Ok "SBF stream detected on $sbfDevice"

# Pass ONLY the node carrying SBF, pinned to a fixed path in the container.
# Which host node carries SBF varies (ttyACM0 / ttyACM1) with the receiver's
# USB1/USB2 assignment and the WSL enumeration order, so the participant used to
# have to read the detected path out of the log above and retype it in the UI.
# docker's `--device host:container` renaming removes that step: whatever the
# host node is, the container always sees it at $ContainerDevice, so the UI's
# rover path is a constant.
# The receiver's other node (the CON / command port) is deliberately NOT passed:
# configure-receiver.ps1 talks to the receiver over COM on the Windows side
# *before* the attach, so nothing in the container needs it. It stays in WSL.
$deviceArgs = @('--device', "${sbfDevice}:${ContainerDevice}")
Write-Ok "Passing device: $sbfDevice -> $ContainerDevice (as seen in the container)"

# --- 2. Prepare host volume directories -------------------------------------
New-Item -ItemType Directory -Force -Path $Workspace, $DataDir | Out-Null

# --- 3. (Re)create the container (idempotent) -------------------------------
$existing = (docker ps -aq --filter "name=^$ContainerName$" | Out-String).Trim()
if ($existing) {
    Write-Step "Removing existing container '$ContainerName'"
    docker rm -f $ContainerName | Out-Null
}

Write-Step "docker run ($Image)"
$runArgs = @(
    'run', '-d', '--name', $ContainerName,
    '-p', "${HostPort}:${ContainerPort}",
    '-p', "${OutPort}:${OutPort}"
) + $deviceArgs + @(
    '-v', "${Workspace}:/workspace:rw",
    '-v', "${DataDir}:/data:ro",
    $Image
)
docker @runArgs | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail-With-Hint "docker run failed (exit $LASTEXITCODE)" `
                   "Check 'docker logs $ContainerName' and that Docker Desktop is running"
}

# --- 4. Wait for the UI, then open the browser ------------------------------
Write-Step "Waiting for the web UI at $UiUrl"
$ready = $false
foreach ($i in 1..30) {
    try {
        $r = Invoke-WebRequest -Uri $UiUrl -UseBasicParsing -TimeoutSec 2
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { $ready = $true; break }
    } catch {
        Start-Sleep -Seconds 1
    }
}
if ($ready) {
    Write-Ok "Web UI is up; opening $UiUrl"
    Start-Process $UiUrl
} else {
    Write-Warn "Web UI did not respond in time. Open $UiUrl manually, or check 'docker logs $ContainerName'"
}
