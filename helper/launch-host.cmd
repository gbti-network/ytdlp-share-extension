@echo off
rem Chrome runs this to start the ytdlp share helper. Keep it beside host.ps1.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0host.ps1"
