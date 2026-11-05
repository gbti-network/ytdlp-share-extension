# ytdlp share installer for Windows. Double-click install.cmd, or run:
#   powershell -ExecutionPolicy Bypass -File install.ps1 [-OutputDir "D:\Videos\YouTube"] [-NoBrowser]
#
#   1. Installs yt-dlp, Deno and FFmpeg with winget if they are missing.
#   2. Registers the helper with Chrome for this Windows user: writes
#      helper\network.gbti.ytdlp_share.json and one registry key,
#      HKCU\Software\Google\Chrome\NativeMessagingHosts\network.gbti.ytdlp_share. No admin rights.
#   3. Copies the extension folder's path to the clipboard and opens chrome://extensions
#      (skipped with -NoBrowser).
#
# Safe to run again. Undo with uninstall.cmd. Keep this file ASCII (PowerShell 5.1 reads it as ANSI).

param(
  [string]$OutputDir,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$HostName = 'network.gbti.ytdlp_share'
$ExtensionId = 'gplfbjlengkjmkbcafkgbjmgnajnedfa'   # fixed by the key in extension\manifest.json
$HelperDir = Join-Path $Root 'helper'
$ExtensionDir = Join-Path $Root 'extension'

function Write-Step([string]$Text) { Write-Host ''; Write-Host $Text -ForegroundColor Cyan }

# Same search as helper\host.ps1: WinGet's links folder, then the saved user and machine PATH.
function Find-Tool([string]$Name) {
  $dirs = @(Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links') +
    ([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') +
    ([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';')
  foreach ($dir in $dirs) {
    if (-not $dir) { continue }
    try {
      $candidate = [IO.Path]::Combine([Environment]::ExpandEnvironmentVariables($dir.Trim('"')), $Name)
      if ([IO.File]::Exists($candidate)) { return $candidate }
    } catch { }
  }
  return $null
}

try {
  foreach ($required in @($ExtensionDir, (Join-Path $HelperDir 'host.ps1'), (Join-Path $HelperDir 'launch-host.cmd'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing $required. Run this from the ytdlp-share-extension folder." }
  }

  Write-Step '1/3  yt-dlp, Deno and FFmpeg'
  $tools = [ordered]@{ 'yt-dlp.exe' = 'yt-dlp.yt-dlp'; 'deno.exe' = 'DenoLand.Deno'; 'ffmpeg.exe' = 'yt-dlp.FFmpeg' }
  foreach ($exe in $tools.Keys) {
    $found = Find-Tool $exe
    if (-not $found) {
      $id = $tools[$exe]
      if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "$exe is missing and winget is not available. Install winget (App Installer, from the Microsoft Store) or install $id yourself, then run this again."
      }
      Write-Host "     Installing $id with winget..."
      & winget.exe install --id $id -e --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Host
      $found = Find-Tool $exe
      if (-not $found) { throw "$id did not install. Try: winget install --id $id -e" }
    }
    Write-Host ("     {0,-11} {1}" -f $exe, $found)
  }

  Write-Step '2/3  Registering the helper with Chrome'
  # Files from a downloaded ZIP carry a "came from the internet" mark; clear it on the helper.
  Get-ChildItem -LiteralPath $HelperDir -File | Unblock-File
  $manifestPath = Join-Path $HelperDir "$HostName.json"
  $manifest = [ordered]@{
    name = $HostName
    description = 'ytdlp share helper (runs yt-dlp)'
    path = (Join-Path $HelperDir 'launch-host.cmd')
    type = 'stdio'
    allowed_origins = @("chrome-extension://$ExtensionId/")
  }
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
  $regPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName"
  New-Item -Path $regPath -Force | Out-Null
  Set-Item -Path $regPath -Value $manifestPath
  Write-Host "     Registry key: HKCU\Software\Google\Chrome\NativeMessagingHosts\$HostName"

  $configPath = Join-Path $HelperDir 'config.json'
  if ($OutputDir) {
    $OutputDir = [IO.Path]::GetFullPath($OutputDir)
    [IO.File]::WriteAllText($configPath, (@{ outputDir = $OutputDir } | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    Write-Host "     Videos go to: $OutputDir"
  } else {
    if (Test-Path -LiteralPath $configPath) { Remove-Item -LiteralPath $configPath }
    Write-Host '     Videos go to: your Downloads folder, in YouTube'
  }

  Write-Step '3/3  Load the extension in Chrome'
  Write-Host '     1. Open chrome://extensions and turn on Developer mode (top right).'
  Write-Host '     2. Click Load unpacked and choose this folder:'
  Write-Host "        $ExtensionDir" -ForegroundColor Yellow
  Write-Host '     3. Pin the button from the puzzle-piece menu, open a YouTube video, click it.'
  if (-not $NoBrowser) {
    try { Set-Clipboard -Value $ExtensionDir; Write-Host '     The folder path is on your clipboard: paste it into the folder picker.' } catch { }
    try { Start-Process 'chrome.exe' 'chrome://extensions' } catch { }
  }
  Write-Host ''
  Write-Host 'Done.' -ForegroundColor Green
} catch {
  Write-Host ''
  Write-Host "Install stopped: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
