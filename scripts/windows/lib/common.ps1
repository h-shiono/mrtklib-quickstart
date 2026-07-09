# ============================================================================
#  common.ps1  -  shared utilities / idempotent prerequisite checks
#
#  Provides helper functions meant to be dot-sourced from the other ps1 files,
#  and doubles as the standalone prerequisite check (the first step of start.bat).
#
#  Design principles:
#   - Idempotent: repeated runs do not accumulate side effects
#   - Every error carries a "next step" so participants can self-recover
# ============================================================================

$ErrorActionPreference = 'Stop'

function Write-Step  { param([string]$Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "[!!] $Msg" -ForegroundColor Yellow }

# Print "symptom + next step" and stop.
function Fail-With-Hint {
    param([string]$Symptom, [string]$NextStep)
    Write-Host ""
    Write-Host "[ERROR] $Symptom" -ForegroundColor Red
    Write-Host "  Next step: $NextStep" -ForegroundColor Yellow
    throw $Symptom
}

# Whether a command exists (basic building block for idempotent checks).
function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# --- Standalone run only: run the prerequisite checks ------------------------
if ($MyInvocation.InvocationName -ne '.') {
    Write-Step "Starting prerequisite checks"

    # TODO: implement
    #  - Is Docker Desktop running (docker info)?
    #  - Is usbipd-win installed (usbipd list)?
    #  - Is WSL2 enabled?
    if (-not (Test-Command 'docker')) {
        Fail-With-Hint "docker command not found" `
                       "Install and start Docker Desktop (see docs 20-install)"
    }

    Write-Ok "Prerequisite checks (skeleton) passed"
}
