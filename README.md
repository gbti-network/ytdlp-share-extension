# ytdlp share

A barebones Chrome extension that sends the YouTube video in your current tab to
[yt-dlp](https://github.com/yt-dlp/yt-dlp) on your own computer and saves it as an MP4.

One button and two permissions. No popup, no content scripts, no tracking, and nothing running between
clicks. Windows 10 and 11. It is not on the Chrome Web Store: you load it unpacked
([why](#why-not-the-chrome-web-store)).

## Install

1. **Download it.** Green **Code** button, **Download ZIP**, and extract it somewhere it can stay (for
   example `Documents\ytdlp-share-extension`). Or `git clone` it.
2. **Double-click `install.cmd`.** It installs yt-dlp, Deno and FFmpeg with winget if you do not have
   them, and registers the helper with Chrome. Windows may ask whether to run a file downloaded from the
   internet; choose **Run** (or **More info**, then **Run anyway**). When it finishes, the extension
   folder's path is on your clipboard and Chrome opens `chrome://extensions`.
3. **Load it in Chrome.** Turn on **Developer mode** (top right), click **Load unpacked**, paste the path
   into the folder picker, and select the `extension` folder. Pin the button from the puzzle-piece menu.

Open a YouTube video and click the button. That is all.

Do not move the folder afterwards. If you do, double-click `install.cmd` again and click **Reload** on
the extension.

**Requirements:** Windows 10 or 11, Google Chrome, and winget (built into Windows; if it is missing,
install **App Installer** from the Microsoft Store). Nothing else: the helper runs on Windows PowerShell,
which comes with Windows.

## What the installer changes

- **Installs only what is missing:** `yt-dlp.yt-dlp`, `DenoLand.Deno` and `yt-dlp.FFmpeg`, through winget,
  for your user only.
- **Adds one registry key,** for your Windows user only, no admin rights:
  `HKCU\Software\Google\Chrome\NativeMessagingHosts\network.gbti.ytdlp_share`. It points to
  `helper\network.gbti.ytdlp_share.json`, which the installer writes.

Nothing else. The registry key is how Chrome lets an extension talk to a program on your computer
([native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging));
password managers use the same mechanism. Chrome on Windows offers no other way to find the helper.

To save videos somewhere other than `Downloads\YouTube`, run it from a terminal with a folder:
`install.cmd -OutputDir "D:\Videos\YouTube"`.

## How it works

```
click the toolbar button
  extension\background.js   checks the tab is a single YouTube video, rebuilds a clean watch URL
  Chrome native messaging   finds the helper through the registry key, starts helper\launch-host.cmd
  helper\host.ps1           checks the URL again, runs yt-dlp, replies with the file name or the error
  yt-dlp, Deno, FFmpeg      download, solve YouTube's JavaScript challenge, merge video and audio
```

yt-dlp needs a JavaScript runtime to download from YouTube (since
[2025.11.12](https://github.com/yt-dlp/yt-dlp/issues/15012)); Deno is the one it enables by default.

## What it can see and do

| Permission | Why |
|---|---|
| `activeTab` | Read the URL of the tab you click on, at the moment you click. No other tabs, no history. |
| `nativeMessaging` | Hand that URL to the helper. |

That is the whole list: no `host_permissions`, no content scripts, no `cookies`, no `storage`, and no
network requests of its own.

The helper only accepts a single YouTube video (`watch?v=`, `youtu.be/`, `/shorts/`, `/live/`,
`/embed/`). It rebuilds the URL from the 11-character video ID and passes it to yt-dlp as a quoted
argument (never through a shell), with `--ignore-config --no-plugin-dirs --no-playlist`, so nothing on a
page or in a link can add options. Its registration allows only this extension's ID,
`gplfbjlengkjmkbcafkgbjmgnajnedfa`, which the `key` in `manifest.json` keeps fixed.

## Use

The file is saved to `Downloads\YouTube` as `<title> [<video id>].mp4`, with H.264 video and AAC audio
so it plays anywhere (yt-dlp's `-t mp4` preset; YouTube usually offers H.264 up to 1080p).

| Badge | Meaning |
|---|---|
| `1`, `2`, ... (blue) | Downloads in progress. Click other videos and they run side by side. |
| `✓` (green, for 10 seconds) | Done. Hover over the button for the file name. |
| `!` (red, until your next click) | Failed. Hover for the reason; details are in `helper\logs\yt-dlp.log`. |
| `×` (red, for 3 seconds) | This tab is not a single YouTube video. Nothing ran. |

A video opened from a playlist downloads just that video. Live streams are skipped. A video you already
have is not downloaded again.

## Keep it working

YouTube changes often. When downloads start failing with an extraction error, update yt-dlp:

```powershell
winget upgrade yt-dlp.yt-dlp
```

## Uninstall

1. Double-click `uninstall.cmd`. It removes the registry key and the files the installer wrote.
2. Remove the extension at `chrome://extensions`.
3. If nothing else uses them: `winget uninstall` `yt-dlp.yt-dlp`, `DenoLand.Deno` and `yt-dlp.FFmpeg`.

## Files

| Path | What it is |
|---|---|
| `install.cmd`, `install.ps1` | The installer. Safe to run again. |
| `uninstall.cmd`, `uninstall.ps1` | Removes the registration. |
| `extension\` | What Chrome loads: `manifest.json`, `background.js` (65 lines), icons. |
| `helper\host.ps1` | The helper Chrome starts for each click. |
| `helper\launch-host.cmd` | Starts `host.ps1`; Chrome needs a `.cmd` or `.exe` here. |

## Limits

- **Windows only.** The extension would run anywhere Chrome does, but the helper and installer use
  PowerShell and the Windows registry. A macOS or Linux helper would be a welcome contribution.
- **Closing Chrome stops a download in progress.** The helper ends yt-dlp when Chrome disconnects.
- **No progress percentage,** only the badge.
- **No cookies are passed, by design,** so age-restricted and members-only videos will fail.

## Why not the Chrome Web Store

The store does not accept extensions that download YouTube videos, and a native messaging helper cannot
be installed from the store anyway. Loading it unpacked also means you can read every line that runs.

## Use it responsibly

Download only videos you have the right to keep. You are responsible for following YouTube's Terms of
Service and the copyright law where you live.

## License

[MIT](LICENSE)
