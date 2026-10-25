// fusion-calendar.jsx — 第 6 页：日历（V3.9.2 权威结构：masthead → 当日时间 → 全天 → 月/周密度月历 → 当日详情 → 当日经营）
const {T, FONT, SERIF, P, Icon, EmptyState, TabBar, Phone, Board} = window.FusionKit;

// 当日详情数据（key: 'M-D'，2026-10 真实排布：10月1日=周四，今日 25 日=周日）
const DAY_EVENTS = {
  '10-25': { items: [
    { time:'9:30', title:'供应商结账', dot:'record', right:'已结 · ¥1,220' },
    { time:'14:00', title:'302 补货', dot:'delivery', right:'待配送' },
    { time:'18:00', title:'盘点可乐', dot:'todo', right:'库存 3 箱' },
  ], income:3480, expense:1220, count:3 },
  '10-26': { items: [ { time:'10:00', title:'老张面馆送餐', dot:'delivery', right:'待配送' } ], income:680, expense:0, count:1 },
};
// 月历格底事件点：exp=收支绿 / todo=待办蓝 / delivery=配送灰 / record=记录浅灰
const DAY_DOTS = { '10-1':['exp'], '10-14':['exp'], '10-20':['todo','exp'], '10-25':['exp','todo','delivery'], '10-26':['exp'] };
const WEEK_CN = ['日','一','二','三','四','五','六'];
const fmt = (n) => '¥' + n.toLocaleString('en-US');
const GOLD = '#D4A017', GOLD_RING = '#B8860B', GOLD_INK = '#1A1D21';

// 周一开头的 6 行 × 7 列 = 42 格（首尾补上月/下月 ghost 日）
function monthCells(y, m) {
  const lead = (new Date(y, m, 1).getDay() + 6) % 7;
  const days = new Date(y, m + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < 42; i++) {
    const d = i - lead + 1;
    if (d < 1) {
      const pmY = m === 0 ? y - 1 : y, pmM = m === 0 ? 11 : m - 1;
      const pmD = new Date(pmY, pmM + 1, 0).getDate();
      cells.push({ y: pmY, m: pmM, d: pmD + d, ghost: true });
    } else if (d > days) {
      const nmY = m === 11 ? y + 1 : y, nmM = m === 11 ? 0 : m + 1;
      cells.push({ y: nmY, m: nmM, d: d - days, ghost: true });
    } else cells.push({ y, m, d, ghost: false });
  }
  return cells;
}
function weekCells(y, m, d) {
  const mon = new Date(y, m, d - ((new Date(y, m, d).getDay() + 6) % 7));
  const out = [];
  for (let i = 0; i < 7; i++) {
    const dt = new Date(mon.getFullYear(), mon.getMonth(), mon.getDate() + i);
    out.push({ y: dt.getFullYear(), m: dt.getMonth(), d: dt.getDate(), ghost: dt.getMonth() !== m });
  }
  return out;
}
const dotColor = (t, k) => k === 'exp' ? t.green : k === 'todo' ? t.info : t.ink4;

function DayCell({t, c, isToday, selected, onPick}) {
  const isSel = selected && selected.y === c.y && selected.m === c.m && selected.d === c.d;
  const dots = c.ghost ? [] : (DAY_DOTS[(c.m + 1) + '-' + c.d] || []);
  const ghostColor = t === T.dark ? 'rgba(142,142,147,0.4)' : 'rgba(95,100,110,0.4)';
  return <div onClick={() => onPick(c)} style={{flex:1, height:44, display:'flex', alignItems:'center',
    justifyContent:'center', position:'relative', cursor:'pointer'}}>
    <div style={{width:32, height:32, borderRadius:'50%', boxSizing:'border-box', display:'flex', alignItems:'center', justifyContent:'center',
      background: isToday ? GOLD : 'transparent',
      border: isSel ? `2px solid ${GOLD_RING}` : '2px solid transparent'}}>
      <span style={{fontSize:13, fontWeight:600, color: c.ghost ? ghostColor : (isToday ? GOLD_INK : t.ink)}}>{c.d}</span>
    </div>
    {dots.length > 0 && <div style={{position:'absolute', bottom:4, left:0, right:0, display:'flex', gap:2, justifyContent:'center'}}>
      {dots.map((k, i) => <span key={i} style={{width:4, height:4, borderRadius:'50%', background:dotColor(t, k), opacity:k === 'record' ? 0.5 : 1}}/>)}
    </div>}
  </div>;
}

function DensityChips({t, density, onChange}) {
  return <div style={{margin:'10px 16px 0', flexShrink:0, background:t.fill, borderRadius:22, padding:3, display:'flex', gap:3}}>
    {['月','周'].map(k => <div key={k} onClick={() => onChange(k)} style={{flex:1, height:38,
      display:'flex', alignItems:'center', justifyContent:'center', borderRadius:19, cursor:'pointer',
      background: density === k ? GOLD : 'transparent', color: density === k ? GOLD_INK : t.ink3,
      fontSize:13, fontWeight:600}}>{k}</div>)}
  </div>;
}

function TabStub({t, tab}) {
  const map = { home:{l:'首页', i:P.house, f:'fusion-home.html'}, todo:{l:'待办', i:P.checklist, f:'fusion-todo.html'},
    calendar:{l:'日历', i:P.calendar, f:'fusion-calendar.html'}, biz:{l:'经营', i:P.chart, f:'fusion-business.html'} };
  const m = map[tab];
  return <div style={{flex:1, display:'flex', flexDirection:'column'}}>
    <div style={{height:44, display:'flex', alignItems:'center', justifyContent:'center', fontSize:16, fontWeight:700, borderBottom:`0.5px solid ${t.sep}`}}>{m.l}</div>
    <EmptyState t={t} icon={m.i} title={m.l + '页原型'} subtitle={'见 ' + m.f}/>
  </div>;
}

function CalendarScreen({t, initialSel, initialDensity}) {
  const [tab, setTab] = React.useState('calendar');
  const [ym, setYm] = React.useState({ y: 2026, m: 9 });
  const [sel, setSel] = React.useState(initialSel || { y: 2026, m: 9, d: 25 });
  const [density, setDensity] = React.useState(initialDensity || 'month');
  const today = { y: 2026, m: 9, d: 25 };
  const cells = density === 'month' ? monthCells(ym.y, ym.m) : weekCells(sel.y, sel.m, sel.d);
  const ev = (sel.y === 2026 && sel.m === 9) ? DAY_EVENTS[(sel.m + 1) + '-' + sel.d] : null;
  const pick = (c) => { setSel({ y: c.y, m: c.m, d: c.d }); if (c.y !== ym.y || c.m !== ym.m) setYm({ y: c.y, m: c.m }); };
  const prevM = () => setYm(p => p.m === 0 ? { y: p.y - 1, m: 11 } : { y: p.y, m: p.m - 1 });
  const nextM = () => setYm(p => p.m === 11 ? { y: p.y + 1, m: 0 } : { y: p.y, m: p.m + 1 });
  return <div style={{display:'flex', flexDirection:'column', height:'100%'}}>
    <div style={{flex:1, minHeight:0, display:'flex', flexDirection:'column', overflow:'hidden'}}>
      {tab !== 'calendar' ? <TabStub t={t} tab={tab}/> : <div style={{flex:1, minHeight:0, display:'flex', flexDirection:'column', overflow:'hidden'}}>
        {/* ① masthead：月份 + 左右箭头 */}
        <div style={{height:44, flexShrink:0, display:'flex', alignItems:'center', padding:'0 6px'}}>
          <div onClick={prevM} style={{width:40, height:40, borderRadius:20, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
            <span data-deco="1" style={{transform:'rotate(180deg)', display:'flex'}}><Icon d={P.chevron} size={17} color={t.ink2}/></span>
          </div>
          <div style={{flex:1, textAlign:'center', fontSize:17, fontWeight:700}}>{ym.m + 1}月 {ym.y}</div>
          <div onClick={nextM} style={{width:40, height:40, borderRadius:20, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
            <Icon d={P.chevron} size={17} color={t.ink2}/>
          </div>
        </div>
        {/* ② 当日时间 */}
        <div style={{padding:'2px 16px', flexShrink:0, fontSize:13, fontWeight:600, color:t.ink2}}>今天 · 10月25日 周日</div>
        {/* ③ 全天事项 */}
        <div style={{margin:'8px 16px 0', flexShrink:0}}>
          <div style={{fontSize:12, color:t.ink3, marginBottom:4}}>全天 · 1 项</div>
          <div style={{background:t.surface, borderRadius:12, padding:'9px 14px', display:'flex', alignItems:'center', gap:10}}>
            <span style={{fontSize:11, fontWeight:600, color:t.greenInk, background:t.fill, padding:'2px 7px', borderRadius:6, whiteSpace:'nowrap'}}>全天</span>
            <span style={{fontSize:14, fontWeight:600, color:t.ink, flex:1}}>店庆备货</span>
            <span style={{fontSize:12, color:t.ink3}}>可乐 3 箱 · 下午到货</span>
          </div>
        </div>
        <DensityChips t={t} density={density} onChange={setDensity}/>
        {/* ④ 月历：周头（周一开头）+ 网格 */}
        <div style={{margin:'6px 16px 0', display:'flex', flexShrink:0}}>
          {['一','二','三','四','五','六','日'].map(w => <span key={w} style={{flex:1, textAlign:'center', fontSize:11, color:t.ink3}}>{w}</span>)}
        </div>
        <div style={{margin:'2px 16px 0', flexShrink:0}}>
          {[0,1,2,3,4,5].map(r => {
            const row = cells.slice(r * 7, r * 7 + 7);
            if (!row.length) return null;
            return <div key={r} style={{display:'flex'}}>
              {row.map(c => <DayCell key={c.y + '-' + c.m + '-' + c.d} t={t} c={c}
                isToday={c.y === today.y && c.m === today.m && c.d === today.d} selected={sel} onPick={pick}/>)}
            </div>;
          })}
        </div>
        {/* divider */}
        <div style={{height:1, background:t.sep, margin:'10px 16px 0', flexShrink:0}}/>
        {/* ⑤ 当日详情（与选中日联动） */}
        <div style={{margin:'8px 16px 0', flexShrink:0}}>
          <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline', marginBottom:4}}>
            <span style={{fontSize:13, fontWeight:700, color:t.ink2}}>当日详情</span>
            <span style={{fontSize:12, color:t.ink3}}>{sel.m + 1}月{sel.d}日 · 周{WEEK_CN[new Date(sel.y, sel.m, sel.d).getDay()]}</span>
          </div>
          {ev ? <div style={{background:t.surface, borderRadius:12, overflow:'hidden'}}>
            {ev.items.map(it => <div key={it.time} style={{display:'flex', alignItems:'center', gap:10, padding:'9px 14px'}}>
              <span style={{fontSize:12.5, color:t.ink3, fontVariantNumeric:'tabular-nums', width:36, flexShrink:0}}>{it.time}</span>
              <span style={{width:5, height:5, borderRadius:'50%', background:dotColor(t, it.dot), flexShrink:0, opacity:it.dot === 'record' ? 0.55 : 1}}/>
              <span style={{flex:1, fontSize:14, fontWeight:600, color:t.ink}}>{it.title}</span>
              <span style={{fontSize:12, color: it.dot === 'delivery' ? t.warn : t.ink3, fontWeight: it.dot === 'delivery' ? 600 : 400, whiteSpace:'nowrap'}}>{it.right}</span>
            </div>)}
          </div> : <EmptyState t={t} icon={P.sun} title="这一天没有安排" subtitle="点其他日期查看当日计划"/>}
        </div>
        {/* ⑥ 当日经营单行 */}
        <div style={{margin:'10px 16px 0', flexShrink:0, background:t.surface, borderRadius:12, padding:'11px 14px', display:'flex', alignItems:'center', gap:8}}>
          <Icon d={P.chart} size={16} color={t.greenDeep}/>
          <span style={{fontSize:13, fontWeight:600, color:t.ink2}}>当日经营</span>
          <span style={{flex:1}}/>
          <span style={{fontSize:12.5, color:t.greenInk, fontWeight:700, fontVariantNumeric:'tabular-nums'}}>收入 {fmt(ev ? ev.income : 0)}</span>
          <span style={{fontSize:12.5, color:t.ink2, fontVariantNumeric:'tabular-nums'}}>支出 {fmt(ev ? ev.expense : 0)}</span>
          <span style={{fontSize:12, color:t.ink3}}>{ev ? ev.count : 0} 笔</span>
        </div>
      </div>}
    </div>
    <TabBar t={t} active={tab} onChange={setTab}/>
  </div>;
}

function CalPhone({dark, tag, note, scale, initialSel, density}) {
  const t = dark ? T.dark : T.light;
  return <Phone dark={dark} scale={scale} tag={tag} tagNote={note}>
    <CalendarScreen t={t} initialSel={initialSel} initialDensity={density}/>
  </Phone>;
}

function App() {
  return <Board no="日历" title="日历 · 2026年10月"
    note="V3.9.2 权威结构：masthead（月份 + 可点箭头）→ 当日时间 → 全天事项 → 月/周密度月历（PR-K：今日香槟金实心圆 + 深墨字、选中金环、密度 chips 金底深墨字）→ divider → 当日详情 → 当日经营单行。点日期格金环联动详情，箭头/ghost 日换月，空日显空态。">
    <CalPhone tag="日历 · Light 月密度" note="主屏 1.14× · 今日 25 金圆选中" scale={1.14}/>
    <CalPhone dark tag="日历 · Dark 月密度" note="暗色月历 · 金色标记不变"/>
    <CalPhone tag="日历 · 周密度" note="只显示选中周 7 列" density="week"/>
    <CalPhone tag="选中 26 日" note="当日详情与经营行联动" initialSel={{y:2026, m:9, d:26}}/>
    <CalPhone tag="空日空态" note="28 日无安排 · 可点周/日期格" initialSel={{y:2026, m:9, d:28}}/>
  </Board>;
}

window.FusionPage = App;
