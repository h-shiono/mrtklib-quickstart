# ============================================================================
#  stop-container.ps1  -  stop and remove the mrtklib-docker-ui container
#
#  Counterpart to run-container.ps1. Used by stop.bat (before usb-detach.ps1).
#
#  Idempotency: if the container does not exist, do nothing.
# ============================================================================

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

# Must match $ContainerName in run-container.ps1.
$ContainerName = 'mrtklib-web-ui'

Write-Step "Stopping the mrtklib-docker-ui container"

if (-not (Test-Command 'docker')) {
    Fail-With-Hint "docker command not found" `
                   "Docker Desktop may not be installed or running"
}

$existing = (docker ps -aq --filter "name=^$ContainerName$" | Out-String).Trim()
if (-not $existing) {
    Write-Ok "Container '$ContainerName' not found; nothing to stop"
    return
}

docker rm -f $ContainerName | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail-With-Hint "Failed to stop/remove '$ContainerName' (exit $LASTEXITCODE)" `
                   "Check Docker Desktop, or run 'docker rm -f $ContainerName' manually"
}

Write-Ok "Container '$ContainerName' stopped and removed"
