// 用 Edge 无头 + CDP 驱动原型：截图 / 点击 / 捕获 pageerror。无第三方依赖（Node 24 内置 WebSocket）。
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const arg = (k, d) => {
  const hit = process.argv.find((a) => a.startsWith(`--${k}=`));
  return hit ? hit.slice(k.length + 3) : d;
};

const url = arg('url');
const out = arg('out', 'shots/page.png');
const width = Number(arg('width', 1500));
const height = Number(arg('height', 1200));
const clicks = arg('click', '') ? arg('click').split('||') : [];
const waitMs = Number(arg('wait', 900));
const clickGap = Number(arg('clickgap', 500));
const scale = Number(arg('scale', 2));
const fullPage = arg('full', '1') === '1';

const port = 9400 + Math.floor(Math.random() * 300);
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'edge-cdp-'));

const proc = spawn(EDGE, [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--no-first-run', '--no-default-browser-check', '--disable-gpu',
  '--hide-scrollbars', '--force-color-profile=srgb',
  `--window-size=${width},${height}`,
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(fn, timeout = 20000, gap = 150) {
  const t0 = Date.now();
  for (;;) {
    try { const v = await fn(); if (v) return v; } catch { /* retry */ }
    if (Date.now() - t0 > timeout) throw new Error('timeout waiting for endpoint');
    await sleep(gap);
  }
}

const list = await waitFor(async () => {
  const r = await fetch(`http://127.0.0.1:${port}/json/list`);
  const j = await r.json();
  return j.length ? j : null;
});
const page = list.find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

let id = 0;
const pending = new Map();
const problems = [];
ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { res, rej } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? rej(new Error(JSON.stringify(msg.error))) : res(msg.result);
    return;
  }
  if (msg.method === 'Runtime.exceptionThrown') {
    problems.push('EXCEPTION ' + (msg.params.exceptionDetails.exception?.description || msg.params.exceptionDetails.text));
  }
  if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') {
    problems.push('CONSOLE ' + msg.params.args.map((a) => a.value ?? a.description ?? '').join(' '));
  }
  if (msg.method === 'Log.entryAdded' && msg.params.entry.level === 'error') {
    problems.push('LOG ' + msg.params.entry.text);
  }
};
const send = (method, params = {}) => new Promise((res, rej) => {
  const mid = ++id;
  pending.set(mid, { res, rej });
  ws.send(JSON.stringify({ id: mid, method, params }));
});

await send('Page.enable');
await send('Runtime.enable');
await send('Log.enable');
await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: scale, mobile: false });

await send('Page.navigate', { url });
await sleep(waitMs);

const evalJs = async (expr) => {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.text + ' ' + (r.exceptionDetails.exception?.description || ''));
  return r.result.value;
};

// 点击：按可见文本匹配最内层元素并派发真实鼠标事件
const clickByText = (text) => evalJs(`(() => {
  const t = ${JSON.stringify(text)};
  const nodes = [...document.querySelectorAll('button, [role="button"], a, div, span')];
  const hit = nodes.filter(n => (n.innerText || '').trim() === t).pop()
           || nodes.filter(n => (n.innerText || '').includes(t)).pop();
  if (!hit) return 'MISS:' + t;
  const r = hit.getBoundingClientRect();
  const opts = { bubbles: true, cancelable: true, clientX: r.left + r.width / 2, clientY: r.top + r.height / 2 };
  hit.dispatchEvent(new PointerEvent('pointerdown', opts));
  hit.dispatchEvent(new MouseEvent('mousedown', opts));
  hit.dispatchEvent(new PointerEvent('pointerup', opts));
  hit.dispatchEvent(new MouseEvent('mouseup', opts));
  hit.click();
  return 'OK:' + t;
})()`);

const clickResults = [];
for (const c of clicks) {
  clickResults.push(await clickByText(c.trim()));
  await sleep(clickGap);
}

const metrics = fullPage
  ? await evalJs(`({ w: document.documentElement.scrollWidth, h: document.documentElement.scrollHeight })`)
  : { w: width, h: height };

await send('Emulation.setDeviceMetricsOverride', {
  width: Math.max(width, metrics.w), height: Math.max(height, metrics.h), deviceScaleFactor: scale, mobile: false,
});

const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: fullPage, fromSurface: true });
fs.mkdirSync(path.dirname(path.resolve(root(out))), { recursive: true });
fs.writeFileSync(path.resolve(root(out)), Buffer.from(shot.data, 'base64'));

const textSample = await evalJs(`(document.body.innerText || '').slice(0, 140).replace(/\\n+/g, ' / ')`);
const phoneCount = await evalJs(`document.querySelectorAll('[data-phone]').length`);

function root(p) {
  const base = path.dirname(new URL(import.meta.url).pathname).replace(/^\/([A-Za-z]:)/, '$1');
  return path.resolve(base, p);
}

console.log(JSON.stringify({
  file: out, size: `${metrics.w}x${metrics.h}`, phones: phoneCount,
  clicks: clickResults, problems, text: textSample,
}, null, 2));

ws.close();
proc.kill();
await sleep(300);
try { fs.rmSync(profile, { recursive: true, force: true }); } catch {}
process.exit(problems.length ? 1 : 0);
