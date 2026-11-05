// ytdlp share: one click sends the YouTube video in this tab to the local yt-dlp helper.
// Permissions: activeTab (this tab's URL, only when clicked) and nativeMessaging. Nothing else.

const HOST = 'network.gbti.ytdlp_share';
const IDLE_TITLE = 'Download this YouTube video';
const RED = '#d62a2a', BLUE = '#1a73e8', GREEN = '#1e8e3e';

let running = 0;   // downloads in progress
let failure = '';  // last error since the previous click, shown until the next click
let timer;

// One video only: HTTPS, a known YouTube host, an 11-character ID. Same rule as host/host.js.
function videoUrl(raw) {
  let url;
  try { url = new URL(raw); } catch { return null; }
  if (url.protocol !== 'https:' || url.username || url.password || url.port) return null;
  let id = null;
  if (url.hostname === 'youtu.be') id = url.pathname.slice(1);
  else if (['youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com'].includes(url.hostname)) {
    if (url.pathname === '/watch') id = url.searchParams.get('v');
    else id = /^\/(?:shorts|live|embed)\/([\w-]{11})\/?$/.exec(url.pathname)?.[1] ?? null;
  }
  return /^[\w-]{11}$/.test(id ?? '') ? `https://www.youtube.com/watch?v=${id}` : null;
}

function badge(text, color, title, clearAfterMs) {
  clearTimeout(timer);
  chrome.action.setBadgeText({ text });
  if (color) chrome.action.setBadgeBackgroundColor({ color });
  chrome.action.setTitle({ title: title || IDLE_TITLE });
  if (clearAfterMs) timer = setTimeout(showState, clearAfterMs);
}

function showState() {
  if (running) badge(String(running), BLUE, `Downloading ${running} video${running > 1 ? 's' : ''}`);
  else if (failure) badge('!', RED, `Download failed: ${failure}`);
  else badge('', null, '');
}

chrome.action.onClicked.addListener((tab) => {
  const url = videoUrl(tab.url || '');
  if (!url) return badge('×', RED, 'Not a YouTube video page', 3000);

  if (!running) failure = '';
  running++;
  showState();

  let settled = false;
  const finish = (reply) => {
    if (settled) return;
    settled = true;
    running--;
    if (!reply.ok) failure = reply.error || 'Unknown error';
    if (running || failure) showState();
    else badge('✓', GREEN, `Saved: ${reply.file || 'done'}`, 10000);
  };

  const port = chrome.runtime.connectNative(HOST);
  port.onMessage.addListener((reply) => { finish(reply); port.disconnect(); });
  port.onDisconnect.addListener(() => finish({
    ok: false,
    error: chrome.runtime.lastError?.message || 'The helper stopped before replying.',
  }));
  port.postMessage({ url });
});
