// probe.mjs — 找出溢出元素身份（一次性诊断）
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const url = process.argv[2]; const port = 9500 + Math.floor(Math.random() * 200);
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'edge-probe-'));
const proc = spawn(EDGE, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, '--no-first-run', '--disable-gpu', '--window-size=1500,1900', 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(fn, t = 20000) { const t0 = Date.now(); for (;;) { try { const v = await fn(); if (v) return v; } catch {} if (Date.now() - t0 > t) throw new Error('timeout'); await sleep(150); } }
const list = await waitFor(async () => { const r = await fetch(`http://127.0.0.1:${port}/json/list`); const j = await r.json(); return j.length ? j : null; });
const page = list.find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0; const pending = new Map();
ws.onmessage = (ev) => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { const { res, rej } = pending.get(m.id); pending.delete(m.id); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); } };
const send = (m, p = {}) => new Promise((res, rej) => { const mid = ++id; pending.set(mid, { res, rej }); ws.send(JSON.stringify({ id: mid, method: m, params: p })); });
await send('Page.enable'); await send('Runtime.enable');
await send('Page.navigate', { url }); await sleep(1100);
const r = await send('Runtime.evaluate', { returnByValue: true, expression: `(() => {
  const out = [];
  document.querySelectorAll('[data-phone] *').forEach((el) => {
    const s = el.scrollHeight - el.clientHeight, w = el.scrollWidth - el.clientWidth;
    if (s > 2 || w > 2) {
      const cs = getComputedStyle(el);
      out.push({ tag: el.tagName, s, w, cls: (el.className||'').toString().slice(0,40),
        style: el.getAttribute('style')?.slice(0,90), ov: cs.overflow, ovx: cs.overflowX,
        inner: (el.innerText||'').slice(0,24) });
    }
  });
  return out;
})()` });
console.log(JSON.stringify(r.result.value, null, 2));
ws.close(); proc.kill(); await sleep(300);
try { fs.rmSync(profile, { recursive: true, force: true }); } catch {}
process.exit(0);
