@echo off
rem Quietpane - safety scan only. Changes nothing and opens a report when finished.
set "APPDIR=%~dp0App files - no need to open"
if not exist "%APPDIR%\src\Quietpane.psm1" goto notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%APPDIR%\Quietpane.ps1" -Scan
exit /b

:notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show('Quietpane needs to be unzipped before it can start.' + [char]10 + [char]10 + '1. Close this message.' + [char]10 + '2. Right-click Quietpane.zip and choose Extract All, then Extract.' + [char]10 + '3. In the new folder, double-click Safety scan only.', 'Quietpane')"
exit /b
