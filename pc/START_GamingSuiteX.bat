@echo off
title GamingSuite X
cd /d "%~dp0"

rem Automatisch als Administrator neu starten (fuer die Optimierung noetig)
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0GamingSuiteX.ps1"
if errorlevel 1 pause
