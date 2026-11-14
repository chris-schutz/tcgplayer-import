@echo off
rem Relaunch in a classic console window, minimized (Windows Terminal ignores "minimized")
if /i not "%~1"=="min" (
  start "TCG Import Builder" /min conhost.exe cmd /c ""%~f0" min"
  exit /b
)
title TCG Import Builder
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
