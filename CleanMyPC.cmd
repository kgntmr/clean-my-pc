@echo off
rem Clean My PC - double-click to open. Windows will ask for administrator rights.
if not exist "%~dp0src\CleanMyPC.psm1" goto notextracted
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0CleanMyPC.ps1"
exit /b

:notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show('Clean My PC needs to be unzipped before it can start.' + [char]10 + [char]10 + '1. Close this message.' + [char]10 + '2. Right-click the downloaded zip file and choose Extract All, then Extract.' + [char]10 + '3. Open the new folder and double-click the Clean My PC start file again.', 'Clean My PC')"
exit /b
