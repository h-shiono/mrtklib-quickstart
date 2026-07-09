@echo off
REM ============================================================================
REM  mrtklib-quickstart  -  Windows entry point
REM
REM  The single file a participant runs.
REM  Its responsibilities are kept minimal here:
REM    1) Self-elevate to admin and re-run if not already elevated
REM    2) Invoke the PowerShell logic under lib\*.ps1
REM
REM  The actual work lives in the ps1 files under lib\ (for maintainability).
REM ============================================================================
setlocal

REM --- Self-elevation (UAC) ---------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administrator privileges are required. Re-launching elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "LIB=%~dp0lib"

REM --- Invoke the core logic (order matters) ----------------------------------
REM  TODO: finalize this orchestration once each ps1 is implemented.
REM   1. common.ps1            : prerequisite checks (Docker / usbipd / ...)
REM   2. configure-receiver.ps1: send config commands to COM (Win side, pre-attach)
REM   3. usb-attach.ps1        : attach the mosaic-G5 to WSL
REM   4. run-container.ps1     : docker run -> open the browser

powershell -NoProfile -ExecutionPolicy Bypass -File "%LIB%\common.ps1"             || goto :error
powershell -NoProfile -ExecutionPolicy Bypass -File "%LIB%\configure-receiver.ps1" || goto :error
powershell -NoProfile -ExecutionPolicy Bypass -File "%LIB%\usb-attach.ps1"         || goto :error
powershell -NoProfile -ExecutionPolicy Bypass -File "%LIB%\run-container.ps1"       || goto :error

echo.
echo Done. If the browser does not open, see the troubleshooting docs.
pause
exit /b 0

:error
echo.
echo An error occurred. Check the message above and docs\ja\90-troubleshooting.
pause
exit /b 1
