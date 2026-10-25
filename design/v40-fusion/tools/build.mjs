// build.mjs — V4.0 fusion 原型构建：Babel 预编译 + 单文件 HTML（file:// 离线可用）
import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';

const dir = process.cwd();
const req = createRequire(path.join(dir, '_vendor', 'noop.js'));
const Babel = req('./babel.js');
const compile = (code) => Babel.transform(code, { presets: ['react'] }).code;

const REACT = fs.readFileSync(path.join(dir, '_vendor/react.js'), 'utf8');
const RDOM = fs.readFileSync(path.join(dir, '_vendor/react-dom.js'), 'utf8');
const KIT = compile(fs.readFileSync(path.join(dir, 'src/fusion-kit.jsx'), 'utf8'));
const FRAME = compile(fs.readFileSync(path.join(dir, '_vendor/ios_frame.jsx'), 'utf8'));

const targets = [
  ['src/pages/fusion-home.jsx',     'fusion-home.html',     '工作台 · V4.0 FUSION'],
  ['src/pages/fusion-ai.jsx',       'fusion-ai.html',       'AI 对话 · V4.0 FUSION'],
  ['src/pages/fusion-business.jsx', 'fusion-business.html', '经营 · V4.0 FUSION'],
  ['src/pages/fusion-todo.jsx',     'fusion-todo.html',     '待办 · V4.0 FUSION'],
  ['src/pages/fusion-customer.jsx', 'fusion-customer.html', '客户配送 · V4.0 FUSION'],
  ['src/pages/fusion-calendar.jsx', 'fusion-calendar.html', '日历 · V4.0 FUSION'],
  ['src/pages/fusion-voice.jsx',    'fusion-voice.html',    '语音记账 · V4.0 FUSION'],
  ['src/pages/fusion-memo.jsx',     'fusion-memo.html',     '备忘 · V4.0 FUSION'],
  ['src/pages/fusion-goods.jsx',    'fusion-goods.html',    '商品 · V4.0 FUSION'],
  ['src/pages/fusion-expiry.jsx',   'fusion-expiry.html',   '临期退货 · V4.0 FUSION'],
  ['src/pages/fusion-report.jsx',   'fusion-report.html',   '今日日报 · V4.0 FUSION'],
  ['src/pages/fusion-settings.jsx', 'fusion-settings.html', '设置 · V4.0 FUSION'],
  ['src/pages/fusion-widget.jsx',   'fusion-widget.html',   '小组件 · V4.0 FUSION'],
];

for (const [src, out, title] of targets) {
  const full = path.join(dir, src);
  if (!fs.existsSync(full)) { console.log('SKIP (missing):', out); continue; }
  const page = compile(fs.readFileSync(full, 'utf8'));
  const wrap = (c) => `(function(){\n${c}\n})();`;
  const html = `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${title}</title><style>html,body{margin:0;padding:0}</style></head><body><div id="root"></div><script>${REACT}</script><script>${RDOM}</script><script>${wrap(KIT)}</script><script>${wrap(FRAME)}</script><script>${wrap(page)}</script><script>ReactDOM.createRoot(document.getElementById('root')).render(React.createElement(window.FusionPage));</script></body></html>`;
  fs.writeFileSync(path.join(dir, out), html);
  console.log('built', out, Math.round(html.length / 1024) + ' KB');
}
