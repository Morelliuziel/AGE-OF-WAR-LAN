@echo off
cd /d "%~dp0"
title Instalar sprites originales - AgeOfWar1v1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0InstalarSpritesOriginales.ps1"
echo.
pause
