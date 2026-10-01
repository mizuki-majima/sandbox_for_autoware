@echo off
rem Windows entry point: runs scripts\run.ps1 with Windows PowerShell.
rem "-ExecutionPolicy Bypass" applies only to this run, so no system setting has to be changed.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
rem Keep the window open when this file was started by double-click.
echo %CMDCMDLINE% | findstr /I /C:"%~nx0" >nul && pause
exit /b %EXIT_CODE%
