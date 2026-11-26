@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0test_screen.ps1"  %*
set "rc=%errorlevel%"
pause
exit /b %rc%
