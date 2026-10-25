// fusion-expiry.jsx — 第 9 页：临期退货（B 分组列表 70% + A 衬线合计统计头 20% + C 状态推进呼吸 10%）
const {T, SERIF, P, Icon, Money, Badge, EmptyState, TabBar, Phone, Board} = window.FusionKit;

const ITEMS = [
  { id:'mn', name:'蒙牛纯牛奶', group:'today', days:'今天到期', tone:'red',    batch:'20261025-03', qty:'×12 盒', buy:'1月18日', amount:680, status:'pending' },
  { id:'tl', name:'桃李面包',   group:'today', days:'今天到期', tone:'red',    batch:'20261024-07', qty:'×8 袋',  buy:'1月20日', amount:460, status:'pending' },
  { id:'gm', name:'光明酸奶',   group:'soon',  days:'还剩 2 天', tone:'orange', batch:'20261027-01', qty:'×6 杯',  buy:'1月22日', amount:720, status:'pending' },
  { id:'sq', name:'三全水饺',   group:'soon',  days:'还剩 3 天', tone:'orange', batch:'20261028-04', qty:'×4 袋',  buy:'2月3日',  amount:180, status:'contacted' },
  { id:'sh', name:'双汇火腿肠', group:'week',  days:'还剩 6 天', tone:'blue',   batch:'20261101-02', qty:'×20 根', buy:'2月10日', amount:160, status:'contacted' },
  { id:'yl', name:'伊利优酸乳', group:'week',  days:'还剩 7 天', tone:'blue',   batch:'20261102-05', qty:'×15 盒', buy:'2月15日', amount:120, status:'contacted' },
];

const SMETA = {
  pending:   { l:'待退货',       tone:'orange' },
  contacted: { l:'已联系供应商', tone:'blue' },
  returned:  { l:'已退回',       tone:'green' },
};

const GROUPS = [
  { k:'today', label:'今天到期', dot:'danger' },
  { k:'soon',  label:'3 天内',   dot:'warn' },
  { k:'week',  label:'7 天内',   dot:'info' },
];
const DOTCOLOR = { danger:'danger', warn:'warn', info:'info', green:'green' };

const fmt = (n) => '¥' + n.toLocaleString('en-US');

function ExpiryRow({t, it, onAdvance}) {
  const meta = SMETA[it.status];
  const primary = it.status !== 'returned';
  const label = it.status === 'pending' ? '开始退货' : it.status === 'contacted' ? '已退回' : '恢复';
  return <div style={{display:'flex', alignItems:'center', gap:10, padding:'6px 14px'}}>
    <div style={{flex:1, minWidth:0}}>
      <div style={{display:'flex', alignItems:'center', gap:6}}>
        <span style={{fontSize:15, fontWeight:600, color:t.ink, lineHeight:1.25, whiteSpace:'nowrap'}}>{it.name}</span>
        <Badge tone={it.tone} t={t}>{it.days}</Badge>
      </div>
      <div style={{fontSize:12, color:t.ink2, marginTop:2, lineHeight:1.3, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{it.batch} · {it.qty} · 进货 {it.buy}</div>
      <div style={{marginTop:3}}><Badge tone={meta.tone} t={t}>{meta.l}</Badge></div>
    </div>
    <div onClick={onAdvance} style={{flexShrink:0, width:84, height:44, borderRadius:10, display:'flex', alignItems:'center', justifyContent:'center', fontSize:13, fontWeight:600, cursor:'pointer',
      background: primary ? '#146B52' : 'transparent',
      color: primary ? '#FFFFFF' : t.greenInk,
      border: primary ? 'none' : `1px solid ${t.greenDeep}`}}>{label}</div>
  </div>;
}

function ExpiryList({t, items, onAdvance}) {
  const pending = items.filter(i => i.status === 'pending');
  const sum = pending.reduce((a, i) => a + i.amount, 0);
  const returned = items.filter(i => i.status === 'returned');
  const blocks = returned.length ? [...GROUPS, { k:'returned', label:'已退回', dot:'green' }] : GROUPS;
  return <div style={{display:'flex', flexDirection:'column', flex:1, minHeight:0, overflow:'hidden'}}>
    <div style={{padding:'14px 16px 0', flexShrink:0}}>
      <div style={{fontSize:27, fontWeight:700, letterSpacing:-0.3, color:t.ink}}>临期退货</div>
      <div style={{fontSize:12.5, color:t.ink3, marginTop:2}}>共 6 件 · 今天到期 2 · 3 天内 2 · 7 天内 2</div>
    </div>
    <div style={{margin:'10px 16px 0', flexShrink:0, background:t.paper, border:`1px solid ${t.hair}`, borderRadius:14, padding:'12px 16px', position:'relative', overflow:'hidden', display:'flex', justifyContent:'space-between', alignItems:'baseline'}}>
      <div style={{position:'absolute', left:0, top:0, bottom:0, width:3, background:t.green}}/>
      <div>
        <span style={{fontSize:13, fontWeight:700, color:t.ink2}}>{pending.length} 批临期</span>
        <span style={{fontSize:13, color:t.ink3}}> · 合计 </span>
      </div>
      <Money v={fmt(sum)} size={24} color={t.greenInk}/>
    </div>
    <div style={{flex:1, minHeight:0, overflow:'hidden'}}>
      {blocks.map(b => {
        const rows = items.filter(i => b.k === 'returned' ? i.status === 'returned' : (i.group === b.k && i.status !== 'returned'));
        if (!rows.length) return null;
        return <div key={b.k} style={{margin:'10px 16px 0'}}>
          <div style={{display:'flex', alignItems:'center', gap:6, padding:'0 2px 6px'}}>
            <span style={{width:6, height:6, borderRadius:'50%', background:t[DOTCOLOR[b.dot]], flexShrink:0}}/>
            <span style={{fontSize:13, fontWeight:600, color:t.ink3, letterSpacing:0.4}}>{b.label}</span>
          </div>
          <div style={{background:t.surface, borderRadius:12, overflow:'hidden'}}>
            {rows.map((it, i) => <div key={it.id}>
              {i > 0 && <div style={{height:1, background:t.sep, margin:'0 14px'}}/>}
              <ExpiryRow t={t} it={it} onAdvance={() => onAdvance(it.id)}/>
            </div>)}
          </div>
        </div>;
      })}
    </div>
  </div>;
}

function TabStub({t, tab}) {
  const map = { home:{l:'首页', i:P.house}, todo:{l:'待办', i:P.checklist}, calendar:{l:'日历', i:P.calendar}, biz:{l:'经营', i:P.chart} };
  const m = map[tab];
  return <div style={{flex:1, display:'flex', flexDirection:'column'}}>
    <div style={{height:44, display:'flex', alignItems:'center', justifyContent:'center', fontSize:16, fontWeight:700, borderBottom:`0.5px solid ${t.sep}`}}>{m.l}</div>
    <EmptyState t={t} icon={m.i} title={m.l + '页原型'} subtitle="见对应页面原型"/>
  </div>;
}

function ExpiryScreen({t, initStatus}) {
  const [tab, setTab] = React.useState('home');
  const [items, setItems] = React.useState(() => ITEMS.map(it => ({...it, status: (initStatus && initStatus[it.id]) || it.status})));
  const advance = (id) => setItems(prev => prev.map(it => it.id === id ? {...it,
    status: it.status === 'pending' ? 'contacted' : it.status === 'contacted' ? 'returned' : 'pending'} : it));
  return <div style={{display:'flex', flexDirection:'column', height:'100%'}}>
    <div style={{flex:1, minHeight:0, display:'flex', flexDirection:'column', overflow:'hidden'}}>
      {tab !== 'home' ? <TabStub t={t} tab={tab}/> : <ExpiryList t={t} items={items} onAdvance={advance}/>}
    </div>
    <TabBar t={t} active={tab} onChange={setTab}/>
  </div>;
}

function ExpiryPhone({dark, tag, note, scale, initStatus}) {
  const t = dark ? T.dark : T.light;
  return <Phone dark={dark} scale={scale} tag={tag} tagNote={note}>
    <ExpiryScreen t={t} initStatus={initStatus}/>
  </Phone>;
}

function App() {
  return <Board no="临期退货" title="临期退货 · 状态推进"
    note="B：分组列表（今天到期 / 3 天内 / 7 天内）+ 行内按钮（70%）。A：衬线合计金额统计头 + 发丝线 + 左绿条（20%）。C：退货状态推进呼吸（10%）。点「开始退货」→ 已联系供应商 → 点「已退回」→ 移入已退回组（可「恢复」），统计头实时联动。">
    <ExpiryPhone tag="临期退货 · Light" note="主屏 1.2× · 3 批待退 · 合计 ¥1,860" scale={1.2}/>
    <ExpiryPhone dark tag="临期退货 · Dark" note="红 / 橙 / 蓝徽标暗色 AA" scale={1.08}/>
    <ExpiryPhone tag="已联系供应商" note="蒙牛 · 蓝色状态徽标 · 剩 2 批 ¥1,180" initStatus={{mn:'contacted'}}/>
    <ExpiryPhone tag="已退回 · 可恢复" note="蒙牛移入已退回组" initStatus={{mn:'returned'}}/>
    <ExpiryPhone tag="退货列表 · 0.92×" note="点「开始退货」→「已退回」" scale={0.92}/>
  </Board>;
}

window.FusionPage = App;
