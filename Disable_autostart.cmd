@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0startup.ps1" -Action Disable %*
set "rc=%errorlevel%"
pause
exit /b %rc%
