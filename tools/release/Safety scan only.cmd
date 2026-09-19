@echo off
rem Clean My PC - safety scan only. Changes nothing and opens a report when finished.
if not exist "%~dp0app\CleanMyPC.ps1" goto notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\CleanMyPC.ps1" -Scan
exit /b

:notextracted
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show('Clean My PC needs to be unzipped before it can start.' + [char]10 + [char]10 + '1. Close this message.' + [char]10 + '2. Right-click CleanMyPC.zip and choose Extract All, then Extract.' + [char]10 + '3. Open the new CleanMyPC folder and double-click Safety scan only.', 'Clean My PC')"
exit /b
