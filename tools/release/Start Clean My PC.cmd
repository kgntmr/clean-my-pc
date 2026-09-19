@echo off
rem Clean My PC - double-click to start. Windows will ask for administrator rights.
rem Developed by KomodoWorks.com - free, open source, collects nothing.
if not exist "%~dp0app\CleanMyPC.ps1" goto notextracted
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0app\CleanMyPC.ps1"
exit /b

:notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show('Clean My PC needs to be unzipped before it can start.' + [char]10 + [char]10 + '1. Close this message.' + [char]10 + '2. Right-click CleanMyPC.zip and choose Extract All, then Extract.' + [char]10 + '3. Open the new CleanMyPC folder and double-click Start Clean My PC.', 'Clean My PC')"
exit /b
