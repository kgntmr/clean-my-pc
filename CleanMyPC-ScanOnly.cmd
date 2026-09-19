@echo off
rem Read-only scan: changes nothing, opens an HTML report when finished.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CleanMyPC.ps1" -Scan
