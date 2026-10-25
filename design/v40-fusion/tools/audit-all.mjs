// audit-all.mjs — 六页批量体检：逐页跑 audit.mjs，汇总表格。exit 2 = 有页面失败。
// 用法：node audit-all.mjs [--width=1500] [--height=2000]
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const dir = import.meta.dirname;
const args = process.argv.slice(2);
const width = Number((args.find((a) => a.startsWith('--width=')) || '--width=1500').slice(8));
const height = Number((args.find((a) => a.startsWith('--height=')) || '--height=2000').slice(9));
const pages = [
  ['home', 'fusion-home.html'],
  ['ai', 'fusion-ai.html'],
  ['business', 'fusion-business.html'],
  ['todo', 'fusion-todo.html'],
  ['customer', 'fusion-customer.html'],
  ['calendar', 'fusion-calendar.html'],
  ['voice', 'fusion-voice.html'],
  ['memo', 'fusion-memo.html'],
  ['goods', 'fusion-goods.html'],
  ['expiry', 'fusion-expiry.html'],
  ['report', 'fusion-report.html'],
  ['settings', 'fusion-settings.html'],
  ['widget', 'fusion-widget.html'],
];
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'audit-all-'));
let anyFail = false;
console.log('| 页 | phones | totalFails | interactive(每台) | denseText(每台) |');
console.log('|---|---|---|---|---|');
for (const [name, html] of pages) {
  const file = path.join(dir, html);
  if (!fs.existsSync(file)) { console.log(`| ${name} | — | 文件缺失 | | |`); anyFail = true; continue; }
  const out = path.join(tmp, name + '.json');
  const fd = fs.openSync(out, 'w');
  const r = spawnSync(process.execPath, [path.join(dir, 'audit.mjs'),
    `--url=${pathToFileURL(file).href}`, `--width=${width}`, `--height=${height}`],
    { stdio: ['ignore', fd, 'ignore'] });
  fs.closeSync(fd);
  let report = null;
  try { report = JSON.parse(fs.readFileSync(out, 'utf8')); } catch {}
  if (!report || r.status !== 0 || report.totalFails > 0) anyFail = true;
  const det = report?.detail || [];
  const inter = det.map((d) => d.interactive).join('/');
  const dense = det.map((d) => d.denseText).join('/');
  console.log(`| ${name} | ${report?.phones ?? '—'} | ${report?.totalFails ?? '—'} | ${inter} | ${dense} |`);
  if (report?.totalFails > 0) {
    for (const d of det) {
      if (d.fails.overflow.length) console.log(`  ${name} phone${d.i} overflow: ${JSON.stringify(d.fails.overflow.slice(0, 3))}`);
      if (d.fails.smallTargets.length) console.log(`  ${name} phone${d.i} smallTargets: ${JSON.stringify(d.fails.smallTargets.slice(0, 3))}`);
      if (d.fails.smallText.length) console.log(`  ${name} phone${d.i} smallText: ${JSON.stringify(d.fails.smallText.slice(0, 3))}`);
      if (d.fails.contrast.length) console.log(`  ${name} phone${d.i} contrast: ${JSON.stringify(d.fails.contrast.slice(0, 3))}`);
    }
  }
}
fs.rmSync(tmp, { recursive: true, force: true });
process.exit(anyFail ? 2 : 0);
