@echo off
cd /d "%~dp0"
call "%~dp0python.cmd" "%~dp0pc\launcher.py"
set "rc=%errorlevel%"
if not "%rc%"=="0" pause
exit /b %rc%
