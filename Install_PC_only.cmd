@echo off
call "%~dp0Install.cmd" -SkipFlash %*
exit /b %errorlevel%
