// audit.mjs — 原型自动体检：布局溢出 / 点按目标 / 字号 / 对比度 / 密度。无依赖。
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const url = process.argv.find((a) => a.startsWith('--url=')).slice(6);
const width = Number((process.argv.find((a) => a.startsWith('--width=')) || '--width=1500').slice(8));
const height = Number((process.argv.find((a) => a.startsWith('--height=')) || '--height=1200').slice(9));
const port = 9400 + Math.floor(Math.random() * 300);
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'edge-audit-'));
const proc = spawn(EDGE, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
  '--no-first-run', '--disable-gpu', '--hide-scrollbars', '--force-color-profile=srgb',
  `--window-size=${width},${height}`, 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(fn, timeout = 20000) {
  const t0 = Date.now();
  for (;;) { try { const v = await fn(); if (v) return v; } catch {} if (Date.now() - t0 > timeout) throw new Error('timeout'); await sleep(150); }
}
const list = await waitFor(async () => { const r = await fetch(`http://127.0.0.1:${port}/json/list`); const j = await r.json(); return j.length ? j : null; });
const page = list.find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0; const pending = new Map();
ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) { const { res, rej } = pending.get(msg.id); pending.delete(msg.id); msg.error ? rej(new Error(JSON.stringify(msg.error))) : res(msg.result); }
};
const send = (m, p = {}) => new Promise((res, rej) => { const mid = ++id; pending.set(mid, { res, rej }); ws.send(JSON.stringify({ id: mid, method: m, params: p })); });
await send('Page.enable'); await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url });
await sleep(1100);
const evalJs = async (expr) => {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
  return r.result.value;
};

const report = await evalJs(`(() => {
  const lin = (c) => { // rgb()/rgba() → 相对亮度
    const m = c.match(/rgba?\\(([^)]*)\\)/); if (!m) return null;
    const p = m[1].split(',').map(Number); if (p.length === 4 && p[3] === 0) return null;
    const f = (x) => x <= 0.04045 ? x/12.92 : Math.pow((x+0.055)/1.055, 2.4);
    return 0.2126*f(p[0]/255) + 0.7152*f(p[1]/255) + 0.0722*f(p[2]/255);
  };
  const cr = (a, b) => { const hi = Math.max(a,b), lo = Math.min(a,b); return (hi+0.05)/(lo+0.05); };
  const phones = [...document.querySelectorAll('[data-phone]')].map((ph, i) => {
    const pr = ph.getBoundingClientRect();
    const fails = { overflow: [], smallTargets: [], smallText: [], contrast: [] };
    // 溢出（跳过装饰层、主动裁剪容器与状态栏装饰；只查未声明 hidden 却被撑开的元素）
    ph.querySelectorAll('*').forEach((el) => {
      if (el.closest('[data-deco]') || el.querySelector('[data-deco]')) return;
      let a = el;
      let inChrome = false;
      while (a && a !== ph) { if (getComputedStyle(a).pointerEvents === 'none') { inChrome = true; break; } a = a.parentElement; }
      if (inChrome) return;
      const cs0 = getComputedStyle(el);
      if (cs0.overflow === 'hidden' || cs0.overflowX === 'hidden' || cs0.overflowY === 'hidden') return;
      const s = el.scrollHeight - el.clientHeight;
      const w = el.scrollWidth - el.clientWidth;
      const cs = getComputedStyle(el);
      if ((s > 2 || w > 2) && !/(overflowX|overflowY):\\s*(auto|scroll)/.test('' + cs.overflowX + cs.overflowY)) {
        fails.overflow.push({ tag: el.tagName, txt: (el.innerText || '').slice(0, 22), s, w });
      }
    });
    // 点按目标（只查链上最外层 pointer 元素，避免 cursor 继承误报内层）
    ph.querySelectorAll('*').forEach((el) => {
      const cs = getComputedStyle(el);
      if (cs.cursor === 'pointer' && getComputedStyle(el.parentElement).cursor !== 'pointer') {
        const r = el.getBoundingClientRect();
        if (r.width > 0 && r.height > 0 && (r.width < 38 || r.height < 38)) {
          fails.smallTargets.push({ txt: (el.innerText || el.getAttribute('aria-label') || '').slice(0, 16), w: Math.round(r.width), h: Math.round(r.height) });
        }
      }
    });
    // 文本字号 & 对比度
    ph.querySelectorAll('*').forEach((el) => {
      if (!el.children.length && (el.textContent || '').trim()) {
        const cs = getComputedStyle(el);
        const fs = parseFloat(cs.fontSize);
        if (fs > 0 && fs < 11) fails.smallText.push({ txt: el.textContent.trim().slice(0, 16), fs });
        const cl = lin(cs.color); if (cl === null) return;
        let bg = null, n = el;
        while (n && n !== document.documentElement) {
          const b = lin(getComputedStyle(n).backgroundColor); if (b !== null) { bg = b; break; }
          n = n.parentElement;
        }
        if (bg !== null) {
          const r = cr(cl, bg);
          const need = fs >= 24 ? 3 : 4.5;
          if (r < need) fails.contrast.push({ txt: el.textContent.trim().slice(0, 16), color: cs.color, bg: getComputedStyle(n).backgroundColor, ratio: Math.round(r*100)/100, fs });
        }
      }
    });
    // 密度：含数字/¥/日期/时间的文本块数
    const dense = [...ph.querySelectorAll('div,span')].filter((el) =>
      !el.children.length && /(¥|\\d{2}:\\d{2}|\\d{1,2}月|还剩|天|笔|件)/.test(el.textContent || '')).length;
    const interactive = ph.querySelectorAll('*').length && [...ph.querySelectorAll('*')].filter((el) => getComputedStyle(el).cursor === 'pointer').length;
    return { i, x: Math.round(pr.x), y: Math.round(pr.y), w: Math.round(pr.width), h: Math.round(pr.height),
      interactive, denseText: dense, fails };
  });
  const pageFails = { };
  const total = phones.reduce((a, p) => a + p.fails.overflow.length + p.fails.smallTargets.length + p.fails.smallText.length + p.fails.contrast.length, 0);
  return { phones: phones.length, totalFails: total, detail: phones };
})()`);

console.log(JSON.stringify(report, null, 2));
ws.close(); proc.kill(); await sleep(300);
try { fs.rmSync(profile, { recursive: true, force: true }); } catch {}
process.exit(report.totalFails ? 2 : 0);
