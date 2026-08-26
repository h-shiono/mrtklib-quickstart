# ============================================================================
#  common.ps1  -  shared constants / utilities / idempotent prerequisite checks
#
#  Provides the values and helper functions meant to be dot-sourced from the
#  other ps1 files, and doubles as the standalone prerequisite check (the first
#  step of start.bat).
#
#  Design principles:
#   - Idempotent: repeated runs do not accumulate side effects
#   - Every error carries a "next step" so participants can self-recover
#   - Each prerequisite check mirrors a section of docs/ja/90-troubleshooting,
#     and its "next step" points at that section. Add a check here and the
#     matching section there, or neither.
# ============================================================================

$ErrorActionPreference = 'Stop'

# --- Shared constants (single source of truth for every lib\*.ps1) ----------
# mosaic-G5 USB identifier. The receiver enumerates as ONE composite USB device
# exposing both virtual COM ports; usbipd reports it in InstanceId and
# Win32_PnPEntity in PNPDeviceID, both as "USB\VID_152A&PID_8231\...".
$ReceiverVendorId  = '152A'
$ReceiverProductId = '8231'
$ReceiverIdPattern = "VID_${ReceiverVendorId}&PID_${ReceiverProductId}"

# Container name and the host ports it publishes. Changing a port here is all
# it takes; the prerequisite check and run-container.ps1 both read these.
$ContainerName = 'mrtklib-web-ui'
$HostPort      = 8080   # web UI (MRTKLIB Console)
$OutPort       = 2101   # TCP/IP output of the solution

function Write-Step  { param([string]$Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "[!!] $Msg" -ForegroundColor Yellow }

# Print "symptom + next step" and stop.
#
# Exits rather than throwing. An uncaught `throw` makes PowerShell append its
# own error record -- the exception message again, the maintainer's script path,
# the offending line with a squiggly underline, CategoryInfo and
# FullyQualifiedErrorId -- directly under the message a participant is meant to
# read, where it looks like a second, worse failure. `exit 1` gives start.bat
# the same non-zero exit code with none of that. Note that this exits the whole
# script, so it must stay a last resort, never a recoverable error.
function Fail-With-Hint {
    param([string]$Symptom, [string]$NextStep)
    Write-Host ""
    Write-Host "[ERROR] $Symptom" -ForegroundColor Red
    Write-Host "  Next step: $NextStep" -ForegroundColor Yellow
    exit 1
}

# Whether a command exists (basic building block for idempotent checks).
function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Registered WSL distributions, as objects {Name, Version, IsDefault}.
# `wsl -l -v` prints UTF-16LE, which PowerShell decodes into text with a NUL
# between every character; WSL_UTF8 (WSL 0.64+) makes it emit UTF-8 instead, and
# stripping NULs recovers the ASCII text on older builds where that is ignored.
# The header row is localised, so the columns are matched by shape (a trailing
# version digit) rather than by name.
function Get-WslDistro {
    if (-not (Test-Command 'wsl')) { return $null }

    $hadUtf8  = Test-Path Env:\WSL_UTF8
    $prevUtf8 = if ($hadUtf8) { $env:WSL_UTF8 } else { $null }
    $prevEnc  = $null
    try { $prevEnc = [Console]::OutputEncoding } catch { }

    $raw = ''
    try {
        $env:WSL_UTF8 = '1'
        if ($prevEnc) { try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { } }
        $raw = (wsl -l -v 2>$null | Out-String)
    } catch {
        $raw = ''
    } finally {
        if ($hadUtf8) { $env:WSL_UTF8 = $prevUtf8 }
        else { Remove-Item Env:\WSL_UTF8 -ErrorAction SilentlyContinue }
        if ($prevEnc) { try { [Console]::OutputEncoding = $prevEnc } catch { } }
    }
    if (-not $raw) { return $null }

    $distros = @()
    foreach ($line in (($raw -replace "`0", '') -split "`r?`n")) {
        # "* Ubuntu    Running    2" -> name / state / version. The state column
        # is localised too, so it is matched as "some word", never by value.
        if ($line -match '^\s*(\*?)\s*(.+?)\s+\S+\s+(\d+)\s*$') {
            $distros += [pscustomobject]@{
                Name      = $matches[2]
                Version   = [int]$matches[3]
                IsDefault = ($matches[1] -eq '*')
            }
        }
    }
    if ($distros.Count -eq 0) { return $null }
    return $distros
}

# --- Standalone run only: run the prerequisite checks ------------------------
if ($MyInvocation.InvocationName -ne '.') {
    Write-Step "Starting prerequisite checks"

    # Collected rather than thrown one at a time: a participant missing three
    # things should learn all three now, not over three runs.
    $problems = New-Object System.Collections.ArrayList
    function Add-Problem {
        param([string]$Symptom, [string]$NextStep)
        [void]$problems.Add([pscustomobject]@{ Symptom = $Symptom; NextStep = $NextStep })
    }

    # Native commands writing to stderr would surface as terminating errors
    # under 'Stop'. These checks read state and interpret exit codes themselves.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {

        # --- 1. Administrator privileges ------------------------------------
        # usbipd bind requires it. start.bat self-elevates, so this only trips
        # when common.ps1 is invoked directly.
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $isAdmin  = ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
                        [Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) {
            Write-Ok "Administrator privileges"
        } else {
            Add-Problem "Not running as administrator" `
                        "Run scripts\windows\start.bat (it elevates via UAC) instead of this script"
        }

        # --- 2/3. WSL2 and a real distribution ------------------------------
        # usbipd attach --wsl needs a real WSL2 distribution as the target; the
        # docker-desktop internal distribution is not accepted, and `wsl bash`
        # (run-container.ps1) runs in the default one.
        $distros = Get-WslDistro
        if ($null -eq $distros) {
            # Covers both shapes: wsl.exe missing, and wsl.exe present but with
            # no distribution registered (it then prints an error, not a table).
            Add-Problem "WSL is not available, or no distribution is registered" `
                        "Install WSL2 and Ubuntu: see docs 20-install-windows (WSL2)"
        } else {
            $real = @($distros | Where-Object { $_.Name -notlike 'docker-desktop*' -and $_.Version -eq 2 })
            $default = $distros | Where-Object { $_.IsDefault } | Select-Object -First 1
            if ($real.Count -eq 0) {
                Add-Problem "No WSL2 distribution is registered (docker-desktop does not count)" `
                            "Run 'wsl --install -d Ubuntu' and complete its first-time setup"
            } elseif ($default -and $default.Name -like 'docker-desktop*') {
                Add-Problem "The default WSL distribution is '$($default.Name)'" `
                            "Run 'wsl --set-default $($real[0].Name)' so usbipd and the container use it"
            } else {
                $name = if ($default) { $default.Name } else { $real[0].Name }
                Write-Ok "WSL2 distribution: $name"
            }
        }

        # --- 4/5. Docker CLI and daemon -------------------------------------
        $dockerUp = $false
        if (-not (Test-Command 'docker')) {
            Add-Problem "docker command not found" `
                        "Install Docker Desktop: see docs 20-install-windows (Docker Desktop)"
        } else {
            docker info 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $dockerUp = $true
                Write-Ok "Docker Desktop is running"
            } else {
                # Also the shape of the login-user / admin-user mismatch: the
                # elevated docker CLI cannot reach a pipe opened by another user.
                Add-Problem "Cannot reach the Docker daemon" `
                            "Start Docker Desktop and wait for 'Docker Desktop running'. If your login user differs from the administrator, start Docker Desktop as administrator: see docs 90-troubleshooting"
            }

            # --- 6. Docker Desktop's WSL2 backend ---------------------------
            # On the Hyper-V backend the container cannot see the devices WSL
            # holds ("no such file or directory") and bind mounts are denied.
            # Checked only once Docker is known to be installed, so a missing
            # docker-desktop distribution means "wrong backend", not "no Docker".
            if ($null -ne $distros) {
                if (@($distros | Where-Object { $_.Name -like 'docker-desktop*' }).Count -eq 0) {
                    Add-Problem "Docker Desktop is not using the WSL2 backend" `
                                "Enable 'Use the WSL 2 based engine' and WSL Integration: see docs 90-troubleshooting"
                } else {
                    Write-Ok "Docker Desktop is using the WSL2 backend"
                }
            }
        }

        # --- 7. usbipd-win --------------------------------------------------
        # usb-attach.ps1 parses `usbipd state`, which is v4+ only.
        $usbipdOk = $false
        if (-not (Test-Command 'usbipd')) {
            Add-Problem "usbipd not found" `
                        "Install usbipd-win: see docs 20-install-windows (usbipd-win)"
        } else {
            # `usbipd --version` reports a git-describe string, e.g.
            # "5.3.0-54+Branch.master.Sha.aa3db8b8...aa3db8b8..." -- long enough
            # to wrap the console twice and swamp the surrounding [OK] lines.
            # Show the X.Y.Z core; the major is all the version gate needs.
            $rawVer = (usbipd --version 2>$null | Out-String).Trim()
            $ver    = $rawVer
            $major  = $null
            if ($rawVer -match '^(\d+)(?:\.\d+){0,2}') {
                $ver   = $matches[0]
                $major = [int]$matches[1]
            }
            # An unrecognised (or empty) version is not treated as a failure:
            # `usbipd state` below is the real capability test, and it fails
            # with a better message than a version guess would.
            if (-not $ver) { $ver = '(version unknown)' }
            if ($null -ne $major -and $major -lt 4) {
                Add-Problem "usbipd-win $ver is too old" `
                            "Upgrade to v4 or later: 'winget upgrade --interactive --exact dorssel.usbipd-win'"
            } else {
                $usbipdOk = $true
                Write-Ok "usbipd-win $ver"
            }
        }

        # --- 8. The receiver is connected -----------------------------------
        # A device bound once but now unplugged lingers with BusId = null, so
        # filter on BusId to match only what is plugged in right now.
        if ($usbipdOk) {
            $state = $null
            try { $state = usbipd state 2>$null | ConvertFrom-Json } catch { $state = $null }
            if ($null -eq $state) {
                Add-Problem "Failed to read 'usbipd state'" `
                            "Reinstall usbipd-win, or run 'usbipd list' manually to check"
            } else {
                $found = @($state.Devices | Where-Object { $_.InstanceId -match $ReceiverIdPattern -and $_.BusId })
                if ($found.Count -eq 0) {
                    Add-Problem "mosaic-G5 (VID_${ReceiverVendorId}&PID_${ReceiverProductId}) is not connected" `
                                "Connect the receiver by USB and confirm its driver (RxTools) is installed: see docs 90-troubleshooting"
                } else {
                    Write-Ok "mosaic-G5 found at BusId $($found[0].BusId)"
                }
            }
        }

        # --- 9. The published ports are free --------------------------------
        # docker run fails outright if either is taken, so a conflict blocks the
        # whole run even for participants who never use the output port.
        if (Test-Command 'Get-NetTCPConnection') {
            $ours = ''
            if ($dockerUp) {
                $ours = (docker ps -aq --filter "name=^$ContainerName$" 2>$null | Out-String).Trim()
            }
            $busy = @()
            foreach ($port in @($HostPort, $OutPort)) {
                $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
                if ($listener) { $busy += $port }
            }
            if ($busy.Count -eq 0) {
                Write-Ok "Ports $HostPort, $OutPort are free"
            } elseif ($ours) {
                # run-container.ps1 removes the existing container before it
                # publishes, so this is very likely our own listener.
                Write-Warn "Port(s) $($busy -join ', ') in use, but an existing '$ContainerName' container will be removed at startup"
            } else {
                Add-Problem "Port(s) $($busy -join ', ') already in use" `
                            "Free the port, or change `$HostPort / `$OutPort in lib\common.ps1: see docs 90-troubleshooting"
            }
        }

    } finally {
        $ErrorActionPreference = $prevEap
    }

    if ($problems.Count -gt 0) {
        Write-Host ""
        Write-Host "[ERROR] Prerequisite checks failed ($($problems.Count) problem(s))" -ForegroundColor Red
        $n = 1
        foreach ($p in $problems) {
            Write-Host "  $n. $($p.Symptom)" -ForegroundColor Red
            Write-Host "     Next step: $($p.NextStep)" -ForegroundColor Yellow
            $n++
        }
        Write-Host ""
        exit 1   # not `throw`, for the reason given on Fail-With-Hint
    }

    Write-Ok "Prerequisite checks passed"
}
