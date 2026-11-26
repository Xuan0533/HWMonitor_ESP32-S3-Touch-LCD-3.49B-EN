@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash_entry.ps1"  %*
set "rc=%errorlevel%"
pause
exit /b %rc%
