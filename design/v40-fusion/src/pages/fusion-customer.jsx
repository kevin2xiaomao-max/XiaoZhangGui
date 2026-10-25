// fusion-customer.jsx — 第 5 页：客户配送（B 原生列表 70% + A 收据式本月累计卡 20% + C 蓝点行进动画 10%）
const {T, FONT, SERIF, P, Icon, Money, EmptyState, TabBar, Phone, Board} = window.FusionKit;

const CUSTOMERS = [
  { name:'302 便利店', phone:'138****302', orders:12, amount:1860, status:'pending',   goods:'怡宝 2 箱',       addr:'清泉八街 24 号', time:'18:30' },
  { name:'老张面馆',   phone:'159****208', orders:8,  amount:1120, status:'done',      goods:'挂面 2 箱',       addr:'建安路 66 号',   time:'12:10' },
  { name:'怡宝水站',   phone:'137****510', orders:6,  amount:2340, status:'pending',   goods:'怡宝 550ml 5 箱', addr:'滨河市场 3-12',  time:'18:30' },
  { name:'楼下超市',   phone:'136****777', orders:15, amount:3080, status:'done',      goods:'可乐 2 箱',       addr:'清泉八街 1 号',  time:'09:40' },
  { name:'阿强烧烤',   phone:'188****466', orders:5,  amount:980,  status:'done',      goods:'啤酒 3 箱',       addr:'夜市街 9 号',    time:'20:00' },
  { name:'王姐水果',   phone:'135****952', orders:9,  amount:1540, status:'done',      goods:'应季果篮 2 提',   addr:'育才路 18 号',   time:'08:20' },
];

const fmt = (n) => '¥' + n.toLocaleString('en-US');

// 状态徽标（蓝点=配送中，仅图形用 info；文字保持对比度达标色）
function StatusBadge({t, s}) {
  if (s === 'pending') return <span style={{fontSize:11, fontWeight:600, color:t.warn, whiteSpace:'nowrap'}}>待配送</span>;
  if (s === 'delivering') return <span style={{fontSize:11, fontWeight:600, color:t.ink2, display:'flex', alignItems:'center', gap:4, whiteSpace:'nowrap'}}>
    <span style={{width:6, height:6, borderRadius:'50%', background:t.info}}/>配送中</span>;
  return <span style={{fontSize:11, fontWeight:600, color:t.greenInk, whiteSpace:'nowrap'}}>已送达</span>;
}

function FilterChips({t, filter, onChange}) {
  const chips = [{k:'all', l:'全部', n:24}, {k:'pending', l:'待配送', n:2}, {k:'done', l:'已送达', n:19}];
  return <div style={{background:t.fill, borderRadius:22, padding:3, display:'flex', gap:3}}>
    {chips.map(c => <div key={c.k} onClick={() => onChange(c.k)} style={{flex:1, height:42, display:'flex',
      alignItems:'center', justifyContent:'center', gap:5, borderRadius:19, cursor:'pointer',
      background: filter === c.k ? t.surface : 'transparent',
      color: filter === c.k ? t.ink : t.ink3,
      boxShadow: filter === c.k ? '0 1px 2px rgba(0,0,0,0.08)' : 'none'}}>
      <span style={{fontSize:13, fontWeight:600}}>{c.l}</span>
      <span style={{fontSize:12, fontWeight:700, opacity: filter === c.k ? 0.95 : 0.75}}>{c.n}</span>
    </div>)}
  </div>;
}

function CustomerList({t, filter, onFilter, onOpen}) {
  const rows = CUSTOMERS.filter(c => filter === 'all' || c.status === filter);
  return <div style={{display:'flex', flexDirection:'column', flex:1, minHeight:0, overflow:'hidden'}}>
    <div style={{padding:'14px 16px 0', flexShrink:0}}>
      <div style={{fontSize:27, fontWeight:700, letterSpacing:-0.3}}>客户</div>
      <div style={{fontSize:12.5, color:t.ink3, marginTop:2}}>本月 24 家 · 2 单待配送 · 19 家已送达</div>
    </div>
    <div style={{margin:'10px 16px 0', flexShrink:0}}><FilterChips t={t} filter={filter} onChange={onFilter}/></div>
    <div style={{margin:'10px 16px 0', flex:1, minHeight:0, overflow:'hidden'}}>
      <div style={{background:t.surface, borderRadius:12, overflow:'hidden'}}>
        {rows.map((c, i) => <div key={c.name}>
          {i > 0 && <div style={{height:1, background:t.sep, marginLeft:66}}/>}
          <div onClick={() => onOpen(c)} style={{display:'flex', alignItems:'center', gap:10, padding:'10px 14px', cursor:'pointer'}}>
            <div style={{width:38, height:38, borderRadius:10, background:t.greenTint, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0}}>
              <Icon d={P.store} size={19} color={t.greenDeep}/>
            </div>
            <div style={{flex:1, minWidth:0}}>
              <div style={{fontSize:15, fontWeight:600, color:t.ink}}>{c.name}</div>
              <div style={{fontSize:12, color:t.ink3, marginTop:1}}>{c.phone} · 本月 {c.orders} 单{c.status === 'pending' ? ' · 今日 ' + c.time : ''}</div>
            </div>
            <div style={{textAlign:'right', flexShrink:0}}>
              <Money v={fmt(c.amount)} size={16} color={t.greenInk}/>
              <div style={{marginTop:2}}><StatusBadge t={t} s={c.status}/></div>
            </div>
          </div>
        </div>)}
      </div>
    </div>
  </div>;
}

function Detail({t, c, initialStatus, onBack}) {
  const [status, setStatus] = React.useState(initialStatus || 'pending');
  const signTime = initialStatus === 'done' ? '18:12' : '18:20';
  const rows = [['收货', c.goods], ['客户', c.name], ['电话', c.phone], ['地址', c.addr]];
  return <div style={{display:'flex', flexDirection:'column', flex:1, minHeight:0, overflow:'hidden'}}>
    <div style={{height:44, flexShrink:0, display:'flex', alignItems:'center', padding:'0 6px', borderBottom:`0.5px solid ${t.sep}`}}>
      <div onClick={onBack} style={{width:44, height:44, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
        <span data-deco="1" style={{transform:'rotate(180deg)', display:'flex'}}><Icon d={P.chevron} size={18} color={t.ink2}/></span>
      </div>
      <div style={{flex:1, textAlign:'center', fontSize:16, fontWeight:700}}>{c.name}</div>
      <div style={{width:40}}/>
    </div>
    {/* A 基因：收据式本月累计卡（衬线金额 + 发丝虚线 + 左绿条） */}
    <div style={{margin:'14px 16px 0', flexShrink:0, background:t.paper, border:`1px solid ${t.hair}`, borderRadius:14,
      padding:'13px 16px 11px', position:'relative', overflow:'hidden'}}>
      <div style={{position:'absolute', left:0, top:0, bottom:0, width:3, background:t.green}}/>
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
        <span style={{fontSize:13, fontWeight:700, color:t.ink2, letterSpacing:0.3}}>本月累计</span>
        <span style={{fontSize:12, color:t.ink3}}>较上月 <span style={{color:t.greenInk, fontWeight:700}}>↑8%</span></span>
      </div>
      <div style={{display:'flex', alignItems:'baseline', gap:10, marginTop:6}}>
        <Money v={fmt(c.amount)} size={30} color={t.greenInk}/>
        <span style={{fontSize:12.5, color:t.ink3}}>{c.orders} 单 · 均价 ¥{Math.round(c.amount / c.orders)}</span>
      </div>
      <div style={{borderTop:`1px dashed ${t.hair}`, margin:'9px -16px 0', padding:'7px 16px 0', display:'flex', justifyContent:'space-between'}}>
        <span style={{fontSize:12, color:t.ink3}}>最近配送 10月25日 · 今日 1 单</span>
        <span style={{fontSize:12, color:t.ink3}}>回购 3 次</span>
      </div>
    </div>
    {/* 今日配送单卡 */}
    <div style={{margin:'12px 16px 0', flexShrink:0, background:t.surface, borderRadius:14, padding:'14px 16px 12px'}}>
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
        <span style={{fontSize:13, fontWeight:700, color:t.ink2}}>今日配送单</span>
        <StatusBadge t={t} s={status}/>
      </div>
      {rows.map(r => <div key={r[0]} style={{display:'flex', justifyContent:'space-between', gap:12, marginTop:8}}>
        <span style={{fontSize:13, color:t.ink3, flexShrink:0}}>{r[0]}</span>
        <span style={{fontSize:13, color:t.ink, fontWeight:500, textAlign:'right'}}>{r[1]}</span>
      </div>)}
      <div style={{borderTop:`0.5px solid ${t.sep}`, margin:'10px -16px 0', padding:'10px 16px 0'}}>
        {status === 'pending' && <div style={{display:'flex', alignItems:'center', gap:8}}>
          <Icon d={P.clock} size={16} color={t.warn}/>
          <span style={{fontSize:12.5, color:t.ink2}}>预计 18:30 前送达 · 送前电话联系</span>
        </div>}
        {status === 'delivering' && <div>
          <div data-deco="1" style={{position:'relative', height:22, margin:'0 2px'}}>
            <div style={{position:'absolute', left:0, right:0, top:11, borderTop:`1.5px dashed ${t.hair}`}}/>
            <div style={{position:'absolute', top:7, width:8, height:8, borderRadius:'50%', background:t.info, animation:'xzgTrack 2.2s linear infinite'}}/>
          </div>
          <div style={{display:'flex', alignItems:'center', gap:8, marginTop:2}}>
            <Icon d={P.truck} size={16} color={t.ink3}/>
            <span style={{fontSize:12.5, color:t.ink2}}>预计 <span style={{fontWeight:700}}>18:20</span> 送达 · 在路上</span>
          </div>
        </div>}
        {status === 'done' && <div style={{display:'flex', alignItems:'center', gap:8}}>
          <div style={{width:22, height:22, borderRadius:'50%', background:t.green, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0}}>
            <Icon d={P.check} size={13} color="#FFFFFF" strokeWidth={2.6}/>
          </div>
          <span style={{fontSize:12.5, color:t.greenInk, fontWeight:600}}>已送达 · {signTime} 签收</span>
          <span style={{fontSize:12, color:t.ink3}}>签收人 王姐</span>
        </div>}
        {status !== 'done' && <div onClick={() => setStatus(status === 'pending' ? 'delivering' : 'done')}
          style={{marginTop:12, padding:'13px 0', textAlign:'center', background:'#146B52', color:'#FFFFFF',
            fontSize:15, fontWeight:600, borderRadius:12, cursor:'pointer'}}>
          {status === 'pending' ? '开始配送' : '确认送达'}
        </div>}
        {status === 'done' && <div style={{marginTop:12, padding:'13px 0', textAlign:'center', background:t.fill,
          color:t.ink3, fontSize:13, fontWeight:600, borderRadius:12}}>订单已完成</div>}
      </div>
    </div>
    <style>{'@keyframes xzgTrack{0%{left:2px}100%{left:calc(100% - 10px)}}'}</style>
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

function CustomerScreen({t, initialFilter, initialOpen, initialStatus}) {
  const [tab, setTab] = React.useState('home');
  const [filter, setFilter] = React.useState(initialFilter || 'all');
  const [open, setOpen] = React.useState(initialOpen || null);
  return <div style={{display:'flex', flexDirection:'column', height:'100%'}}>
    <div style={{flex:1, minHeight:0, display:'flex', flexDirection:'column', overflow:'hidden'}}>
      {tab !== 'home' ? <TabStub t={t} tab={tab}/>
        : (open ? <Detail t={t} c={open} initialStatus={initialStatus} onBack={() => setOpen(null)}/>
                : <CustomerList t={t} filter={filter} onFilter={setFilter} onOpen={setOpen}/>)}
    </div>
    <TabBar t={t} active={tab} onChange={setTab}/>
  </div>;
}

function CustomerPhone({dark, tag, note, scale, initialFilter, initialOpen, initialStatus}) {
  const t = dark ? T.dark : T.light;
  return <Phone dark={dark} scale={scale} tag={tag} tagNote={note}>
    <CustomerScreen t={t} initialFilter={initialFilter} initialOpen={initialOpen} initialStatus={initialStatus}/>
  </Phone>;
}

function App() {
  return <Board no="客户配送" title="客户 · 配送跟进"
    note="B：原生客户列表 + 全部/待配送/已送达筛选（70%）。A：收据式本月累计卡——衬线 tabular 金额、发丝虚线、左绿条（20%）。C：配送中蓝点行进动画（10%）。点行进详情可跑通：待配送 → 开始配送 → 配送中（动画 + 预计 18:20 送达）→ 确认送达 → 已送达（绿对勾 + 签收时间）。">
    <CustomerPhone tag="客户列表 · Light" note="主屏 1.14× · 全部 24 家" scale={1.14}/>
    <CustomerPhone dark tag="客户列表 · Dark" note="暗色语义色 AA 达标"/>
    <CustomerPhone tag="详情 · 配送中" note="蓝点行进动画 · 预计 18:20 送达" initialOpen={CUSTOMERS[0]} initialStatus="delivering"/>
    <CustomerPhone tag="详情 · 已送达" note="绿对勾 · 18:12 签收" initialOpen={CUSTOMERS[0]} initialStatus="done"/>
    <CustomerPhone tag="待配送筛选 · 0.94×" note="点行进详情 → 开始配送" scale={0.94} initialFilter="pending"/>
  </Board>;
}

window.FusionPage = App;
