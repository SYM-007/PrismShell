@echo off
title Better Terminal Setup
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-BetterTerminal.ps1"
echo.
pause
