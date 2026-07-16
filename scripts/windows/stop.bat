@echo off
REM ============================================================================
REM  stop.bat  -  tear down (counterpart to start.bat)
REM
REM  Stops/removes the container and detaches the receiver's USB from WSL so the
REM  receiver returns to Windows (e.g. to use RxControl again).
REM
REM  Does NOT require administrator (like detach.bat). Docker Desktop / WSL are
REM  left running and the usbipd bind is kept, so the next start.bat stays quick.
REM ============================================================================
setlocal

set "LIB=%~dp0lib"

powershell -NoProfile -ExecutionPolicy Bypass -File "%LIB%\stop-container.ps1" || goto :error
powershell -NoProfile -ExecutionPolicy Bypass -File "%LIB%\usb-detach.ps1"      || goto :error

echo.
echo Done.
pause
exit /b 0

:error
echo.
echo An error occurred. Check the message above and docs\ja\90-troubleshooting.
pause
exit /b 1
