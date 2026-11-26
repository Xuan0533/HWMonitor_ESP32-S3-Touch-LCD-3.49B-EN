@echo off
cd /d "%~dp0"
call "%~dp0python.cmd" -m unittest discover -s "%~dp0tests" -v
set "rc=%errorlevel%"
pause
exit /b %rc%
