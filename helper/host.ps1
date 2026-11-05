# ytdlp share helper (Chrome native messaging host), Windows PowerShell 5.1 or later.
#
# Chrome starts this through launch-host.cmd, sends one {"url": ...} message, and waits for one reply:
# {"ok": true, "file": ...} or {"ok": false, "error": ...}. If Chrome disconnects first, yt-dlp is stopped.
#
# Only protocol bytes may reach stdout, so every other result here is assigned, piped to Out-Null, or
# written to logs\yt-dlp.log. Keep this file ASCII: PowerShell 5.1 reads a BOM-less script as ANSI.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$HelperDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $HelperDir 'logs'
$LogFile = Join-Path $LogDir 'yt-dlp.log'
$FileMark = 'YTDLP_SHARE_FILE '

function Write-Log([string]$Text) {
  try {
    if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    if ((Test-Path -LiteralPath $LogFile) -and (Get-Item -LiteralPath $LogFile).Length -gt 2MB) {
      Move-Item -LiteralPath $LogFile -Destination "$LogFile.old" -Force
    }
    [IO.File]::AppendAllText($LogFile, $Text, (New-Object Text.UTF8Encoding($false)))
  } catch { }
}

# Chrome native messaging framing: 4-byte little-endian length, then UTF-8 JSON.
function Send-Reply([hashtable]$Message) {
  $json = $Message | ConvertTo-Json -Compress
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  Write-Log ("[{0}] reply {1}`r`n" -f (Get-Date -Format o), $json)
  $stdout = [Console]::OpenStandardOutput()
  $stdout.Write([BitConverter]::GetBytes([int32]$bytes.Length), 0, 4)
  $stdout.Write($bytes, 0, $bytes.Length)
  $stdout.Flush()
  exit 0
}

function Read-Exactly([IO.Stream]$Stream, [int]$Count) {
  $buffer = New-Object byte[] $Count
  $read = 0
  while ($read -lt $Count) {
    $n = $Stream.Read($buffer, $read, $Count - $read)
    if ($n -le 0) { return $null }
    $read += $n
  }
  return ,$buffer
}

# One video only: HTTPS, a known YouTube host, an 11-character ID. Same rule as extension/background.js.
function Get-VideoUrl($Raw) {
  if ($Raw -isnot [string]) { return $null }
  $uri = $null
  if (-not [Uri]::TryCreate($Raw, [UriKind]::Absolute, [ref]$uri)) { return $null }
  if ($uri.Scheme -ne 'https' -or $uri.UserInfo -or -not $uri.IsDefaultPort) { return $null }
  $hostName = $uri.Host.ToLowerInvariant()
  $id = $null
  if ($hostName -eq 'youtu.be') {
    $id = $uri.AbsolutePath.Substring(1)
  } elseif (@('youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com') -contains $hostName) {
    if ($uri.AbsolutePath -ceq '/watch') {
      foreach ($pair in $uri.Query.TrimStart('?').Split('&')) {
        $kv = $pair.Split('=', 2)
        if ([Uri]::UnescapeDataString($kv[0].Replace('+', ' ')) -ceq 'v') {
          $id = if ($kv.Count -gt 1) { [Uri]::UnescapeDataString($kv[1].Replace('+', ' ')) } else { '' }
          break
        }
      }
    } elseif ($uri.AbsolutePath -cmatch '^/(?:shorts|live|embed)/([A-Za-z0-9_-]{11})/?$') {
      $id = $Matches[1]
    }
  }
  if ($id -is [string] -and $id -cmatch '^[A-Za-z0-9_-]{11}$') { return "https://www.youtube.com/watch?v=$id" }
  return $null
}

# Looks in WinGet's links folder and the SAVED user and machine PATH, because Chrome's own PATH can be
# older than a recent install.
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

# helper\config.json (written by install.ps1 -OutputDir) wins; otherwise <Downloads>\YouTube.
function Get-OutputDir {
  $config = Join-Path $HelperDir 'config.json'
  if (Test-Path -LiteralPath $config) {
    try { $c = Get-Content -LiteralPath $config -Raw | ConvertFrom-Json; if ($c.outputDir) { return [string]$c.outputDir } } catch { }
  }
  $downloads = $null
  try {
    $downloads = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}'
  } catch { }
  if (-not $downloads) { $downloads = Join-Path $env:USERPROFILE 'Downloads' }
  return Join-Path ([Environment]::ExpandEnvironmentVariables($downloads)) 'YouTube'
}

# Quotes one argument for the Windows command line (CommandLineToArgvW rules).
function ConvertTo-Argument([string]$Value) {
  if ($Value -and $Value -notmatch '[\s"]') { return $Value }
  $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
  $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
  return '"' + $escaped + '"'
}

function Invoke-Download($Message) {
  $url = Get-VideoUrl $Message.url
  if (-not $url) { Send-Reply @{ ok = $false; error = 'Not a single YouTube video.' } }

  $ytdlp = Find-Tool 'yt-dlp.exe'
  if (-not $ytdlp) { Send-Reply @{ ok = $false; error = 'yt-dlp not found. Run install.cmd again.' } }
  # --encoding utf-8: yt-dlp.exe otherwise prints in the ANSI code page and turns characters such as
  # the full-width bar it uses in Windows file names into spaces.
  $ytArgs = @('--ignore-config', '--no-plugin-dirs', '--encoding', 'utf-8', '--no-playlist', '--match-filters', '!is_live', '-t', 'mp4')
  $deno = Find-Tool 'deno.exe'
  if ($deno) { $ytArgs += @('--no-js-runtimes', '--js-runtimes', "deno:$deno") }
  $ffmpeg = Find-Tool 'ffmpeg.exe'
  if ($ffmpeg) { $ytArgs += @('--ffmpeg-location', (Split-Path -Parent $ffmpeg)) }
  $ytArgs += @('-P', (Get-OutputDir), '-o', '%(title).150B [%(id)s].%(ext)s', '--windows-filenames',
    '--no-overwrites', '--no-progress', '--no-quiet', '--print', "after_move:$FileMark%(filepath)s", '--', $url)

  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $ytdlp
  $psi.Arguments = ($ytArgs | ForEach-Object { ConvertTo-Argument $_ }) -join ' '
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true   # never let yt-dlp inherit Chrome's pipe
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [Text.Encoding]::UTF8

  Write-Log ("`r`n[{0}] {1}`r`n" -f (Get-Date -Format o), $url)
  $proc = [Diagnostics.Process]::Start($psi)
  $proc.StandardInput.Close()
  $outTask = $proc.StandardOutput.ReadToEndAsync()
  $errTask = $proc.StandardError.ReadToEndAsync()

  # Chrome closing the pipe (browser closed, extension reloaded) ends the read with 0 bytes.
  $hangup = $script:Stdin.ReadAsync((New-Object byte[] 1), 0, 1)
  while (-not $proc.WaitForExit(250)) {
    if ($hangup.IsCompleted -and ($hangup.IsFaulted -or $hangup.Result -eq 0)) {
      Write-Log ("[{0}] Chrome disconnected; stopping yt-dlp`r`n" -f (Get-Date -Format o))
      & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-Null
      exit 0
    }
  }
  $proc.WaitForExit()
  $out = $outTask.Result
  $err = $errTask.Result
  Write-Log ($out + $err)

  $file = ($out -split "`r?`n") | Where-Object { $_.StartsWith($FileMark) } | Select-Object -Last 1
  $errorLine = ($err -split "`r?`n") | Where-Object { $_.StartsWith('ERROR:') } | Select-Object -Last 1
  if ($proc.ExitCode -ne 0) {
    $reason = if ($errorLine) { $errorLine.Substring(7) } else { "yt-dlp exited with code $($proc.ExitCode)" }
    Send-Reply @{ ok = $false; error = $reason }
  }
  if ($file) { Send-Reply @{ ok = $true; file = [IO.Path]::GetFileName($file.Substring($FileMark.Length)) } }
  if (($out + $err) -match 'does not pass filter') { Send-Reply @{ ok = $false; error = 'Live streams are not downloaded.' } }
  Send-Reply @{ ok = $true; file = 'already downloaded' }
}

try {
  $script:Stdin = [Console]::OpenStandardInput()
  $header = Read-Exactly $script:Stdin 4
  if (-not $header) { exit 0 }
  $length = [BitConverter]::ToInt32($header, 0)
  if ($length -le 0 -or $length -gt 65536) { Send-Reply @{ ok = $false; error = 'Malformed message.' } }
  $body = Read-Exactly $script:Stdin $length
  if (-not $body) { exit 0 }
  try { $message = [Text.Encoding]::UTF8.GetString($body) | ConvertFrom-Json } catch {
    Send-Reply @{ ok = $false; error = 'Malformed message.' }
  }
  Invoke-Download $message
} catch {
  Write-Log ("[{0}] helper error: {1}`r`n" -f (Get-Date -Format o), $_)
  Send-Reply @{ ok = $false; error = "Helper error: $($_.Exception.Message)" }
}
