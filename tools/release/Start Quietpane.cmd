@echo off
rem Quietpane - double-click to start. Windows will ask for administrator rights.
rem Developed by KomodoWorks.com - free, open source, collects nothing.
set "APPDIR=%~dp0App files - no need to open"
if not exist "%APPDIR%\src\Quietpane.psm1" goto notextracted
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%APPDIR%\Quietpane.ps1"
exit /b

:notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show('Quietpane needs to be unzipped before it can start.' + [char]10 + [char]10 + '1. Close this message.' + [char]10 + '2. Right-click Quietpane.zip and choose Extract All, then Extract.' + [char]10 + '3. In the new folder, double-click Start Quietpane.', 'Quietpane')"
exit /b
