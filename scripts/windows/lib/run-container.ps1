# ============================================================================
#  run-container.ps1  -  start the mrtklib-docker-ui container -> open the UI
#
#  Role:
#   1. Detect which WSL serial node carries the receiver's SBF stream
#      (fail fast if none is flowing).
#   2. docker run the container, passing the receiver's COM node(s) and the
#      workspace/data volumes, publishing the web UI port.
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
$Image         = 'hatognss/mrtklib-docker-ui:0.3.0-alpha'   # alt: ghcr.io/h-shiono/mrtklib-docker-ui:0.3.0-alpha
$ContainerName = 'mrtklib-web-ui'
$HostPort      = 8080
$ContainerPort = 8000
$UiUrl         = "http://localhost:$HostPort"

# Host directories for the container volumes (created if missing).
$DataRoot  = Join-Path $env:USERPROFILE 'mrtklib-quickstart'
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
# Pipe the script into WSL over stdin instead of translating its Windows path to
# a WSL path: wslpath cannot handle a UNC path (\\wsl.localhost\...) when the
# scripts live on the WSL filesystem. Strip CRs so bash does not choke if the
# file was checked out with CRLF.
$detectText = (Get-Content -Raw -LiteralPath $detectWin) -replace "`r", ""
$detectText = $detectText.TrimStart([char]0xFEFF)   # drop any leading BOM
# Pipe to WSL as UTF-8 *without* a BOM. If $OutputEncoding is UTF-8-with-BOM
# (common on some consoles), the BOM prepended to stdin stops '#' from starting
# a comment, so bash tries to execute the script's first line (the shebang).
$prevEncoding   = $OutputEncoding
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
try {
    $sbfDevice = ($detectText | wsl bash -s -- 3 | Out-String).Trim()
} finally {
    $OutputEncoding = $prevEncoding
}
if ($LASTEXITCODE -ne 0 -or -not $sbfDevice) {
    Fail-With-Hint "No SBF stream detected on the receiver's ports" `
                   "Run usb-attach, and set the receiver's SBF output to USB1 (see receiver setup)"
}
Write-Ok "SBF stream detected on $sbfDevice"

# Pass every receiver COM node (both raw / CON) so the container can pick.
$nodes = ((wsl bash -c "ls /dev/ttyACM* 2>/dev/null" | Out-String).Trim() -split "\s+") |
         Where-Object { $_ }
$deviceArgs = @()
foreach ($n in $nodes) { $deviceArgs += @('--device', "${n}:${n}") }
Write-Ok "Passing device(s): $($nodes -join ', ')"

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
    '-p', "${HostPort}:${ContainerPort}"
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
