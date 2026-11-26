@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "rc=%errorlevel%"
if not "%rc%"=="0" echo Installation failed. See error above.
pause
exit /b %rc%
