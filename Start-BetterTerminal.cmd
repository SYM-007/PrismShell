@echo off
title Better Terminal Setup
cd /d "%~dp0"
powershell.exe -NoProfile -File "%~dp0Install-BetterTerminal.ps1"
if errorlevel 1 echo Setup could not finish. Review the error above and README.md for script policy guidance.
echo.
pause
