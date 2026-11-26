@echo off
cd /d "%~dp0"
set "old=%~1"
if not defined old set "old=C:\PCMonitor"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -Target "%old%"
pause
