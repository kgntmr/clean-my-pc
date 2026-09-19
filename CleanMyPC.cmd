@echo off
rem Clean My PC - double-click to open. Windows will ask for administrator rights.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0CleanMyPC.ps1"
