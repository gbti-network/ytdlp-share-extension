# ytdlp share

A barebones Chrome extension that adds one button to your toolbar. Click it on a YouTube video and the
video is saved to your PC as an MP4.

It has two parts. The extension in Chrome reads the address of the tab you click it on, and nothing
else. A small PowerShell script on your PC, the helper, takes that address and runs
[yt-dlp](https://github.com/yt-dlp/yt-dlp), a free, open-source download program, to save the video.
There is no popup and no tracking, and nothing runs in the background unless a video is downloading.

It works on Windows 10 and 11 only. It is not on the Chrome Web Store
([why](#why-not-the-chrome-web-store)), so you download it with git and load it into Chrome yourself.

## What it changes on your PC

Running the installer, `install.cmd`, changes these things and nothing else:

- **Installs yt-dlp, Deno and FFmpeg if you do not have them,** through winget, as the packages
  `yt-dlp.yt-dlp`, `DenoLand.Deno` and `yt-dlp.FFmpeg`. yt-dlp downloads the video, Deno lets it solve
  YouTube's JavaScript challenge, and FFmpeg merges the video and audio into one file. All three are
  portable packages that winget puts in your user profile, so no admin rights are needed.
- **Registers the helper with Chrome,** so the extension can start it. It writes
  `helper\network.gbti.ytdlp_share.json`, which allows only this extension's ID, and points one
  registry key at it: `HKCU\Software\Google\Chrome\NativeMessagingHosts\network.gbti.ytdlp_share`. The
  key belongs to your Windows user only. It is how Chrome lets an extension talk to a program on your
  computer ([native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging));
  password managers use the same mechanism. Chrome on Windows offers no other way to find the helper.
- **Clears the "downloaded from the internet" mark** on the files in `helper\` (`Unblock-File`).
- **Saves your download folder, only if you choose one** with `-OutputDir` (see
  [step 3](#3-run-the-installer)). It writes that folder to `helper\config.json`. A run without
  `-OutputDir` removes that file.

Each download then adds the video, in `Downloads\YouTube` or the folder you chose, and an entry in the
helper's log, `helper\logs\yt-dlp.log`, with the video's URL and what yt-dlp printed.

`uninstall.cmd` undoes the installer. It removes the registry key, those two files and the log. It
leaves your videos, and it leaves yt-dlp, Deno and FFmpeg installed because other programs may use
them. [Uninstall](#uninstall) shows how to remove those as well.

## Requirements

- Windows 10 or 11 (64-bit), and Google Chrome.
- git, to download the code. If you do not have it, run `winget install --id Git.Git -e` in
  PowerShell, then open a new PowerShell window.
- winget, the package installer built into Windows. If it is missing, install **App Installer** from
  the Microsoft Store.
- An AI coding agent (Claude Code, Codex, Cursor or similar) to check the code before you install it.
  Without one, you can read it yourself: about 430 lines in all.

Nothing else is needed. The installer fetches yt-dlp, Deno and FFmpeg, and the helper runs on Windows
PowerShell, which comes with Windows.

## Install

### 1. Download the code with git

Open PowerShell from the Start menu and run:

```powershell
cd $HOME
git clone https://github.com/gbti-network/ytdlp-share-extension.git
cd ytdlp-share-extension
```

That puts it in your user folder, `C:\Users\<you>\ytdlp-share-extension`, which OneDrive does not sync.
Leave it there. Chrome loads the extension from this folder and runs the helper from it on every
click, so keep it somewhere only you change.

### 2. Have your AI agent check the code

Do not run code from the internet on trust, including this. Before you install, open your AI coding
agent in the `ytdlp-share-extension` folder and paste this:

```text
Review this folder before I install it. Read every file, and do not run anything.
Confirm each point, citing file and line, and flag anything that does not match:

1. extension/manifest.json asks only for the activeTab and nativeMessaging permissions: no content
   scripts, no host permissions, no remote code.
2. extension/background.js makes no network requests of its own and sends only a YouTube watch URL to
   the native messaging host network.gbti.ytdlp_share.
3. install.cmd and uninstall.cmd only run install.ps1 and uninstall.ps1 with Windows PowerShell
   (-ExecutionPolicy Bypass) and then wait for a key press. helper/launch-host.cmd only runs
   helper/host.ps1 with Windows PowerShell (-ExecutionPolicy Bypass).
4. install.ps1 does only these things: winget installs of yt-dlp.yt-dlp, DenoLand.Deno and
   yt-dlp.FFmpeg when they are missing; Unblock-File on the files in helper/; writes
   helper/network.gbti.ytdlp_share.json; writes helper/config.json only with -OutputDir, and deletes
   it on a run without -OutputDir; sets one registry key under
   HKCU\Software\Google\Chrome\NativeMessagingHosts, creating that path if it is missing; and, unless -NoBrowser is given, copies the
   extension folder's path to the clipboard and opens chrome://extensions.
5. uninstall.ps1 removes that registry key, those two files and helper/logs, and nothing else.
6. helper/host.ps1 accepts only a single YouTube video URL, rebuilds it from the 11-character video ID,
   and starts yt-dlp without a shell, so nothing in a URL can add commands or options. The only file
   host.ps1 itself writes is its log, helper/logs/yt-dlp.log (moved to yt-dlp.log.old once it passes
   2 MB). If Chrome disconnects before yt-dlp finishes, it stops yt-dlp.
7. Apart from those winget packages and what yt-dlp fetches from YouTube (the video, and YouTube's
   player JavaScript, which yt-dlp runs in Deno to solve YouTube's challenge), these scripts download
   nothing and run no code from anywhere else.

Finish with a one-line verdict: clean, or the specific problems.
```

Continue only when the verdict is clean. Without an agent, read the files listed under
[Files](#files) yourself.

### 3. Run the installer

In the same PowerShell window, run:

```powershell
.\install.cmd
```

You can also double-click `install.cmd` in the folder. It installs yt-dlp, Deno and FFmpeg with winget
if you do not have them, and registers the helper with Chrome; the full list is under
[What it changes on your PC](#what-it-changes-on-your-pc). When it finishes, the extension folder's
path is on your clipboard and it opens `chrome://extensions` in Chrome. The window then says Done;
press any key to finish.

To save videos somewhere other than `Downloads\YouTube`, give the installer a folder instead:

```powershell
.\install.cmd -OutputDir "D:\Videos\YouTube"
```

### 4. Load the extension in Chrome

1. On `chrome://extensions` (if Chrome is not showing it, type that into the address bar), turn on
   **Developer mode** (top right).
2. Click **Load unpacked**. A folder picker opens.
3. Click in the folder picker's address bar, paste the path (Ctrl+V) and press Enter. That opens the
   `extension` folder. Click **Select Folder**.
4. Click the puzzle-piece icon in Chrome's toolbar and pin **ytdlp share**, so the button stays in
   view.

If the path is no longer on your clipboard, it is `C:\Users\<you>\ytdlp-share-extension\extension`.

## Save a YouTube video

Open a YouTube video and click the button. The file is saved to `Downloads\YouTube`, or the folder you
chose, as `<title> [<video id>].mp4`. yt-dlp's `-t mp4` preset prefers H.264 video and AAC audio, which
play almost anywhere. YouTube usually offers H.264 up to 1080p, so most videos arrive at 1080p or
lower.

The badge on the button shows what is happening:

| Badge | Meaning |
|---|---|
| `1`, `2`, ... (blue) | Downloads in progress. Click other videos and they run side by side. |
| `✓` (green, for 10 seconds) | Done. Hover over the button for the file name. |
| `!` (red, until you start another download) | Failed. Hover for the reason; details are in `helper\logs\yt-dlp.log`. |
| `×` (red, for 3 seconds) | This tab is not a single YouTube video. Nothing ran. |

A video opened from a playlist downloads just that video. A stream that is still live is not
downloaded, and the badge shows `!` with that reason. A video you already have is not downloaded again.

## If a download fails

Hover over the red `!` for the reason. The full output is in `helper\logs\yt-dlp.log`.

YouTube changes often. When downloads start failing with an extraction error, update yt-dlp:

```powershell
winget upgrade yt-dlp.yt-dlp
```

If the reason says the native messaging host was not found, Chrome cannot find the helper's
registration. Run `install.cmd` again.

Some videos cannot be downloaded at all. [Limits](#limits) lists them.

## Change where videos go, or move the folder

Both mean running the installer again, which is safe.

- **A different download folder:** Run `.\install.cmd -OutputDir "D:\Videos\YouTube"` with your own
  folder. A later run without `-OutputDir` sends videos back to `Downloads\YouTube`.
- **You moved the `ytdlp-share-extension` folder:** Run `install.cmd` from its new place. Then, on
  `chrome://extensions`, remove ytdlp share and load the `extension` folder again from the new place
  with **Load unpacked**.

## Uninstall

1. Double-click `uninstall.cmd`. It removes the registry key, the files the installer wrote, and the
   helper's log, which lists the URLs you downloaded. Your videos stay where they are.
2. On `chrome://extensions`, remove ytdlp share.
3. If nothing else uses yt-dlp, Deno or FFmpeg, remove them too:

   ```powershell
   winget uninstall --id yt-dlp.yt-dlp -e
   winget uninstall --id DenoLand.Deno -e
   winget uninstall --id yt-dlp.FFmpeg -e
   ```

4. Delete the `ytdlp-share-extension` folder.

## Limits

- **Windows only.** The extension would run anywhere Chrome does, but the helper and installer use
  PowerShell and the Windows registry. A macOS or Linux helper would be a welcome contribution.
- **Closing Chrome stops a download in progress.** The helper ends yt-dlp when Chrome disconnects.
- **No progress percentage,** only the badge.
- **No cookies are passed, by design,** so age-restricted and members-only videos will fail.

## Permissions and URL checks

| Permission | Why |
|---|---|
| `activeTab` | Read the URL of the tab you click on, at the moment you click. No other tabs, no history. |
| `nativeMessaging` | Hand that URL to the helper. |

The extension asks for nothing else: no `host_permissions`, no content scripts, no `cookies`, no
`storage`. It makes no network requests of its own.

The helper accepts only a single YouTube video (`watch?v=`, `youtu.be/`, `/shorts/`, `/live/`,
`/embed/`). It rebuilds the URL from the 11-character video ID and passes it to yt-dlp as a separate
argument after `--`, never through a shell, along with `--ignore-config --no-plugin-dirs --no-playlist`.
As a result, nothing on a page or in a link can add options. The helper's registration allows only
this extension's ID, `gplfbjlengkjmkbcafkgbjmgnajnedfa`, which the `key` in `manifest.json` keeps fixed.

## How it works

```text
click the toolbar button
  extension\background.js   checks the tab is a single YouTube video, rebuilds a clean watch URL
  Chrome native messaging   finds the helper through the registry key, starts helper\launch-host.cmd
  helper\host.ps1           checks the URL again, runs yt-dlp, replies with the file name or the error
  yt-dlp, Deno, FFmpeg      download, solve YouTube's JavaScript challenge, merge video and audio
```

yt-dlp needs a JavaScript runtime to download from YouTube (since
[2025.11.12](https://github.com/yt-dlp/yt-dlp/issues/15012)); Deno is the one it enables by default.

## Files

| Path | What it is |
|---|---|
| `install.cmd`, `install.ps1` | The installer. Safe to run again. |
| `uninstall.cmd`, `uninstall.ps1` | Removes the registration, the files the installer wrote and the log. |
| `extension\` | What Chrome loads: `manifest.json`, `background.js` (65 lines), icons. |
| `helper\host.ps1` | The helper Chrome starts for each click. |
| `helper\launch-host.cmd` | Starts `host.ps1`; Chrome needs a `.cmd` or `.exe` here. |

## Why not the Chrome Web Store

The store does not accept extensions that download YouTube videos, and a native messaging helper cannot
be installed from the store anyway. Loading it unpacked also means you can read every line of the
extension and the helper.

## Use it responsibly

Download only videos you have the right to keep. You are responsible for following YouTube's Terms of
Service and the copyright law where you live.

## License

[MIT](LICENSE)
