@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0startup.ps1" -Action Enable %*
set "rc=%errorlevel%"
pause
exit /b %rc%
