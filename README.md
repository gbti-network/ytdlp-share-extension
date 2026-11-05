# ytdlp share

A barebones Chrome extension that sends the YouTube video in your current tab to
[yt-dlp](https://github.com/yt-dlp/yt-dlp) on your own computer and saves it as an MP4.

One toolbar button, and two permissions:

| Permission | Why |
|---|---|
| `activeTab` | Read the URL of the tab you click on, at the moment you click. |
| `nativeMessaging` | Hand that URL to a helper program on your computer. |

No popup, no content scripts, no access to any site, no tracking. The code is `background.js`.

## It needs a local helper

A Chrome extension cannot run programs, so the button passes the video link through Chrome's
[native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging) to a
helper registered as `network.gbti.ytdlp_share`, which runs yt-dlp. **The helper is not in this
repository.** Without one, the button shows a red `!`.

The helper receives `{"url": "https://www.youtube.com/watch?v=<id>"}` and replies with
`{"ok": true, "file": "<file name>"}` or `{"ok": false, "error": "<reason>"}`. Its native messaging
manifest must allow `chrome-extension://gplfbjlengkjmkbcafkgbjmgnajnedfa/`.

## Load it

It is not on the Chrome Web Store. Open `chrome://extensions`, turn on **Developer mode**, click
**Load unpacked** and choose this folder. The extension ID is always `gplfbjlengkjmkbcafkgbjmgnajnedfa`,
fixed by the `key` in `manifest.json`.

## The badge

| Badge | Meaning |
|---|---|
| `1`, `2`, ... (blue) | Downloads in progress |
| `✓` (green, for 10 seconds) | Done. Hover over the button for the file name. |
| `!` (red, until your next click) | Failed. Hover for the reason. |
| `×` (red, for 3 seconds) | This tab is not a single YouTube video. Nothing was sent. |

## Use it responsibly

Download only videos you have the right to keep. You are responsible for following YouTube's Terms of
Service and the copyright law where you live.

## License

[MIT](LICENSE)
