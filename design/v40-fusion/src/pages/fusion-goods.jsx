// fusion-goods.jsx — 第 8 页：商品库存（B 原生列表 70% + A 衬线进销价 20% + C 进货 sheet 10%）
const {T, SERIF, P, Icon, Money, Badge, EmptyState, TabBar, Phone, Board} = window.FusionKit;

const GOODS = [
  { id:'yibao', name:'怡宝 550ml', cat:'饮料', spec:'550ml × 24 瓶/箱', buy:'¥0.80', sell:'¥1.20', stock:12, min:20, low:true,  exp:'4月12日', sold:38,  rev:45.60 },
  { id:'cola',  name:'可乐',      cat:'饮料', spec:'330ml × 24 罐/箱', buy:'¥2.10', sell:'¥3.00', stock:46, min:20, low:false, exp:'8月2日',  sold:126, rev:378.00 },
  { id:'nf',    name:'农夫山泉',  cat:'饮料', spec:'550ml × 24 瓶/箱', buy:'¥0.90', sell:'¥1.50', stock:8,  min:15, low:true,  exp:'6月18日', sold:64,  rev:96.00 },
  { id:'lays',  name:'乐事薯片',  cat:'零食', spec:'70g × 40 包/箱',   buy:'¥4.20', sell:'¥6.00', stock:31, min:15, low:false, exp:'5月9日',  sold:52,  rev:312.00 },
  { id:'qf',    name:'清风纸巾',  cat:'日用', spec:'3层 × 10 卷/提',   buy:'¥8.50', sell:'¥12.00', stock:5,  min:12, low:true,  exp:'1月10日', sold:18,  rev:216.00 },
  { id:'ht',    name:'海天生抽',  cat:'日用', spec:'1.9L × 6 瓶/箱',   buy:'¥16.00', sell:'¥22.00', stock:27, min:12, low:false, exp:'12月3日', sold:41,  rev:902.00 },
];

const fmt = (n) => '¥' + n.toLocaleString('en-US', { minimumFractionDigits: 2 });

function CatChips({t, cat, onChange}) {
  const cats = [{k:'全部', n:23}, {k:'饮料', n:3}, {k:'零食', n:1}, {k:'日用', n:2}];
  return <div style={{margin:'10px 16px 0', flexShrink:0, background:t.fill, borderRadius:22, padding:3, display:'flex', gap:3}}>
    {cats.map(c => <div key={c.k} onClick={() => onChange(c.k)} style={{flex:1, height:42, display:'flex',
      alignItems:'center', justifyContent:'center', gap:5, borderRadius:19, cursor:'pointer',
      background: cat === c.k ? t.surface : 'transparent',
      color: cat === c.k ? t.ink : t.ink3,
      boxShadow: cat === c.k ? '0 1px 2px rgba(0,0,0,0.08)' : 'none'}}>
      <span style={{fontSize:13, fontWeight:600}}>{c.k}</span>
      <span style={{fontSize:12, fontWeight:700, opacity: cat === c.k ? 0.95 : 0.75}}>{c.n}</span>
    </div>)}
  </div>;
}

function GoodsRow({t, g, onOpen}) {
  return <div onClick={() => onOpen(g)} style={{display:'flex', alignItems:'center', gap:10, padding:'10px 14px', cursor:'pointer'}}>
    <div style={{width:38, height:38, borderRadius:10, background:t.greenTint, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0}}>
      <Icon d={P.cube} size={19} color={t.greenDeep}/>
    </div>
    <div style={{flex:1, minWidth:0}}>
      <div style={{display:'flex', alignItems:'center', gap:6}}>
        <span style={{fontSize:15, fontWeight:600, color:t.ink, lineHeight:1.25, whiteSpace:'nowrap'}}>{g.name}</span>
        {g.low && <Badge tone="orange" t={t}>低库存</Badge>}
      </div>
      <div style={{fontSize:12, color:t.ink3, marginTop:1, lineHeight:1.3}}>{g.spec}</div>
      <div style={{fontSize:12, marginTop:1, lineHeight:1.3}}>
        <span style={{color:t.ink2, fontWeight:600}}>{'剩 ' + g.stock + ' 件'}</span>
        <span style={{color:t.ink3}}>{' · 到期 ' + g.exp}</span>
      </div>
    </div>
    <div style={{flexShrink:0, textAlign:'right'}}>
      <Money v={g.sell} size={15} color={t.greenInk}/>
      <div style={{fontSize:11.5, color:t.ink3, marginTop:2, lineHeight:1.3}}>进 <Money v={g.buy} size={11.5} color={t.ink3}/></div>
    </div>
  </div>;
}

function GoodsList({t, cat, onCat, onOpen}) {
  const rows = GOODS.filter(g => cat === '全部' || g.cat === cat);
  return <div style={{display:'flex', flexDirection:'column', flex:1, minHeight:0, overflow:'hidden'}}>
    <div style={{padding:'14px 16px 0', flexShrink:0}}>
      <div style={{fontSize:27, fontWeight:700, letterSpacing:-0.3, color:t.ink}}>商品</div>
      <div style={{fontSize:12.5, color:t.ink3, marginTop:2}}>共 23 种 · 低库存 3</div>
    </div>
    <div style={{margin:'10px 16px 0', flexShrink:0, height:40, background:t.fill, borderRadius:10, display:'flex', alignItems:'center', gap:8, padding:'0 12px'}}>
      <span data-deco="1" style={{position:'relative', width:14, height:14, flexShrink:0}}>
        <span style={{position:'absolute', left:0, top:0, width:9, height:9, borderRadius:'50%', border:'1.5px solid ' + t.ink4}}/>
        <span style={{position:'absolute', left:9, top:9, width:6, height:1.5, background:t.ink4, transform:'rotate(45deg)'}}/>
      </span>
      <span style={{fontSize:15, color:t.ink3}}>搜索商品 / 条码</span>
    </div>
    <CatChips t={t} cat={cat} onChange={onCat}/>
    <div style={{margin:'10px 16px 0', flex:1, minHeight:0, overflow:'hidden'}}>
      <div style={{background:t.surface, borderRadius:12, overflow:'hidden'}}>
        {rows.map((g, i) => <div key={g.id}>
          {i > 0 && <div style={{height:1, background:t.sep, margin:'0 14px'}}/>}
          <GoodsRow t={t} g={g} onOpen={onOpen}/>
        </div>)}
      </div>
    </div>
  </div>;
}

// 进货数量 sheet（C 基因：少即是多，仅数量步进 + 快捷量）
function RestockSheet({t, g, stock, qty, setQty, onCancel, onConfirm}) {
  const chips = [{n:5, l:'+5 件'}, {n:10, l:'+10 件'}, {n:20, l:'+20 件'}];
  return <div>
    <div onClick={onCancel} style={{position:'absolute', left:0, top:0, right:0, bottom:0, background:'rgba(0,0,0,0.32)', zIndex:20, cursor:'pointer'}}/>
    <div style={{position:'absolute', left:0, right:0, bottom:0, background:t.surface, borderTopLeftRadius:20, borderTopRightRadius:20, padding:'16px 16px 16px', zIndex:21}}>
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline'}}>
        <span style={{fontSize:17, fontWeight:700, color:t.ink}}>进货入库</span>
        <span style={{fontSize:12.5, color:t.ink3}}>{g.name} · 当前库存 {stock} 件</span>
      </div>
      <div style={{display:'flex', alignItems:'center', justifyContent:'center', gap:18, marginTop:16}}>
        <div onClick={() => setQty(Math.max(1, qty - 1))} style={{width:44, height:44, borderRadius:12, background:t.fill, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
          <Icon d="M5 12H19" size={22} color={t.ink} strokeWidth={2}/>
        </div>
        <span style={{fontSize:28, fontWeight:700, fontFamily:SERIF, color:t.ink, minWidth:64, textAlign:'center', fontVariantNumeric:'tabular-nums'}}>{qty}</span>
        <div onClick={() => setQty(qty + 1)} style={{width:44, height:44, borderRadius:12, background:t.fill, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
          <Icon d={P.plus} size={20} color={t.ink}/>
        </div>
      </div>
      <div style={{display:'flex', gap:8, marginTop:14}}>
        {chips.map(c => <div key={c.n} onClick={() => setQty(c.n)} style={{flex:1, height:42, borderRadius:10,
          background:t.fill, color:t.ink2, fontSize:13, fontWeight:600, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>{c.l}</div>)}
      </div>
      <div style={{display:'flex', gap:10, marginTop:16}}>
        <div onClick={onCancel} style={{flex:1, height:46, borderRadius:12, border:`1px solid ${t.greenDeep}`, color:t.greenInk, fontSize:14, fontWeight:600, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>取消</div>
        <div onClick={onConfirm} style={{flex:2, height:46, borderRadius:12, background:'#146B52', color:'#FFFFFF', fontSize:14, fontWeight:600, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>确认进货</div>
      </div>
    </div>
  </div>;
}

function GoodsDetail({t, g, initialSheet, btnLabel, onBack}) {
  const [stock, setStock] = React.useState(g.stock);
  const [sheet, setSheet] = React.useState(!!initialSheet);
  const [qty, setQty] = React.useState(10);
  const [added, setAdded] = React.useState(null);
  const rows = [['当前库存', stock + ' 件'], ['最低库存', g.min + ' 件'], ['到期日期', g.exp]];
  return <div style={{display:'flex', flexDirection:'column', flex:1, minHeight:0, overflow:'hidden', position:'relative'}}>
    <div style={{height:44, flexShrink:0, display:'flex', alignItems:'center', padding:'0 6px', borderBottom:`0.5px solid ${t.sep}`}}>
      <div onClick={onBack} style={{width:44, height:44, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
        <span data-deco="1" style={{transform:'rotate(180deg)', display:'flex'}}><Icon d={P.chevron} size={18} color={t.ink2}/></span>
      </div>
      <div style={{flex:1, textAlign:'center', fontSize:16, fontWeight:700, color:t.ink}}>商品详情</div>
      <div style={{width:44}}/>
    </div>
    <div style={{margin:'14px 16px 0', flexShrink:0, background:t.surface, borderRadius:14, padding:'14px 16px', display:'flex', alignItems:'center', gap:12}}>
      <div style={{width:44, height:44, borderRadius:12, background:t.greenTint, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0}}>
        <Icon d={P.cube} size={22} color={t.greenDeep}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:6}}>
          <span style={{fontSize:17, fontWeight:700, color:t.ink, whiteSpace:'nowrap'}}>{g.name}</span>
          {g.low && <Badge tone="orange" t={t}>低库存</Badge>}
        </div>
        <div style={{fontSize:12.5, color:t.ink3, marginTop:2}}>{g.spec} · {g.cat}</div>
      </div>
    </div>
    <div style={{margin:'12px 16px 0', flexShrink:0, background:t.surface, borderRadius:14, padding:'0 16px 8px'}}>
      <div style={{fontSize:13, fontWeight:600, color:t.ink3, letterSpacing:0.4, padding:'10px 0 2px'}}>库存</div>
      {rows.map(r => <div key={r[0]} style={{display:'flex', justifyContent:'space-between', gap:12, padding:'8px 0'}}>
        <span style={{fontSize:13, color:t.ink3, flexShrink:0}}>{r[0]}</span>
        <span style={{fontSize:13, color:t.ink, fontWeight:600}}>{r[1]}</span>
      </div>)}
    </div>
    <div style={{margin:'12px 16px 0', flexShrink:0, background:t.surface, borderRadius:14, padding:'12px 16px 12px'}}>
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline'}}>
        <span style={{fontSize:13, fontWeight:600, color:t.ink3}}>近30天售出</span>
        <span style={{fontSize:13, color:t.ink, fontWeight:600}}>{g.sold} 件 · 营收 <Money v={fmt(g.rev)} size={15} color={t.greenInk}/></span>
      </div>
      <div style={{borderTop:`1px dashed ${t.hair}`, margin:'10px -16px 0', padding:'10px 16px 0', display:'flex', justifyContent:'space-between'}}>
        <span style={{fontSize:12.5, color:t.ink3}}>进价 <Money v={g.buy} size={13} color={t.ink3}/></span>
        <span style={{fontSize:12.5, color:t.ink3}}>售价 <Money v={g.sell} size={15} color={t.greenInk}/></span>
      </div>
    </div>
    <div style={{margin:'16px 16px 0', flexShrink:0}}>
      <div onClick={() => setSheet(true)} style={{height:48, display:'flex', alignItems:'center', justifyContent:'center', background:'#146B52', color:'#FFFFFF', fontSize:15, fontWeight:600, borderRadius:12, cursor:'pointer'}}>{btnLabel || '进货'}</div>
      {added && <div style={{marginTop:10, padding:'11px 14px', background:t.greenTint, borderRadius:10, display:'flex', alignItems:'center', gap:6}}>
        <Icon d={P.check} size={14} color={t.greenInk} strokeWidth={2.4}/>
        <span style={{fontSize:12.5, color:t.greenInk, fontWeight:600}}>已入库 {added} 件 · 当前库存 {stock} 件</span>
      </div>}
    </div>
    {sheet && <RestockSheet t={t} g={g} stock={stock} qty={qty} setQty={setQty}
      onCancel={() => setSheet(false)}
      onConfirm={() => { setStock(s => s + qty); setAdded(qty); setSheet(false); }}/>}
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

function GoodsScreen({t, initialCat, initialOpen, initialSheet}) {
  const [tab, setTab] = React.useState('home');
  const [cat, setCat] = React.useState(initialCat || '全部');
  const [open, setOpen] = React.useState(initialOpen || null);
  return <div style={{display:'flex', flexDirection:'column', height:'100%'}}>
    <div style={{flex:1, minHeight:0, display:'flex', flexDirection:'column', overflow:'hidden'}}>
      {tab !== 'home' ? <TabStub t={t} tab={tab}/>
        : (open ? <GoodsDetail t={t} g={open} initialSheet={initialSheet} btnLabel={initialSheet ? '进货入库' : '进货'} onBack={() => setOpen(null)}/>
                : <GoodsList t={t} cat={cat} onCat={setCat} onOpen={setOpen}/>)}
    </div>
    <TabBar t={t} active={tab} onChange={setTab}/>
  </div>;
}

function GoodsPhone({dark, tag, note, scale, initialCat, initialOpen, initialSheet}) {
  const t = dark ? T.dark : T.light;
  return <Phone dark={dark} scale={scale} tag={tag} tagNote={note}>
    <GoodsScreen t={t} initialCat={initialCat} initialOpen={initialOpen} initialSheet={initialSheet}/>
  </Phone>;
}

function App() {
  return <Board no="商品库存" title="商品 · 库存与进货"
    note="B：原生商品列表 + 分类 chips + 搜索条（70%）。A：衬线进价/售价数字（20%）。C：进货 sheet 数量步进（10%）。点「怡宝 550ml」进详情 → 点「进货」出数量 sheet（+5/+10/+20 快捷量）→ 确认入库后库存联动更新。">
    <GoodsPhone tag="商品列表 · Light" note="主屏 1.2× · 6 商品 · 3 低库存" scale={1.2}/>
    <GoodsPhone dark tag="商品列表 · Dark" note="日用分类 · 暗色低库存徽标" scale={1.08} initialCat="日用"/>
    <GoodsPhone tag="商品详情" note="农夫山泉 · 库存 8 / 最低 15" initialOpen={GOODS[2]}/>
    <GoodsPhone tag="进货入库 Sheet" note="可乐 · 步进器与 +5/+10/+20" initialOpen={GOODS[1]} initialSheet/>
    <GoodsPhone tag="日用分类 · 0.92×" note="小屏点按目标 44px" scale={0.92} initialCat="日用"/>
  </Board>;
}

window.FusionPage = App;
