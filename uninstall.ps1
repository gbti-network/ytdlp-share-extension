# ytdlp share uninstaller. Double-click uninstall.cmd, or run:
#   powershell -ExecutionPolicy Bypass -File uninstall.ps1
#
# Removes the registry key and the helper manifest that install.ps1 wrote. Leaves your videos, and
# leaves yt-dlp, Deno and FFmpeg installed because other programs may use them.

$ErrorActionPreference = 'Stop'
$HelperDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'helper'
$HostName = 'network.gbti.ytdlp_share'

$regPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName"
if (Test-Path -LiteralPath $regPath) { Remove-Item -LiteralPath $regPath; Write-Host 'Removed the registry key.' }
else { Write-Host 'The registry key was already gone.' }

foreach ($generated in @("$HostName.json", 'config.json')) {
  $path = Join-Path $HelperDir $generated
  if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
}

Write-Host ''
Write-Host 'Now remove the extension at chrome://extensions. To remove the tools as well:'
Write-Host '  winget uninstall --id yt-dlp.yt-dlp -e'
Write-Host '  winget uninstall --id DenoLand.Deno -e'
Write-Host '  winget uninstall --id yt-dlp.FFmpeg -e'
