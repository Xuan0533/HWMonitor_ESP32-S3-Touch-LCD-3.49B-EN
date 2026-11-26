@echo off
call "%~dp0python.cmd" "%~dp0pc\agent.py" %*
exit /b %ERRORLEVEL%
