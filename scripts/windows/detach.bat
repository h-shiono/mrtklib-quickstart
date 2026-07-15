@echo off
REM ============================================================================
REM  detach.bat  -  detach the mosaic-G5 from WSL (teardown)
REM
REM  Returns the receiver's USB COM ports from WSL back to Windows (e.g. to use
REM  RxControl again, or to re-run the setup).
REM
REM  Unlike start.bat, this does NOT self-elevate: `usbipd detach` does not
REM  require administrator privileges. The persistent bind is left in place so
REM  the next attach stays quick; run "detach.bat /unbind" to also release it
REM  (that variant needs administrator and will prompt via UAC).
REM ============================================================================
setlocal

set "LIB=%~dp0lib"
set "PSARGS="
if /i "%~1"=="/unbind" set "PSARGS=-Unbind"

REM --- /unbind needs administrator; re-launch elevated if requested ----------
if defined PSARGS (
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo Administrator privileges are required for /unbind. Re-launching elevated...
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '/unbind' -Verb RunAs"
        exit /b
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%LIB%\usb-detach.ps1" %PSARGS% || goto :error

echo.
echo Done.
pause
exit /b 0

:error
echo.
echo An error occurred. Check the message above and docs\ja\90-troubleshooting.
pause
exit /b 1
