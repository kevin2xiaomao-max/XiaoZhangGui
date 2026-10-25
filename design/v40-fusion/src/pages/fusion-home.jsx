// fusion-home.jsx — 第 1 页：工作台首页（V3.9.2 权威结构 §20 + V4.0 融合方向）
// 自上而下：日期头(+记一笔 id=v39.home.quickRecord) → 本月营业额 Hero（A 基因衬线大数字）→ 四 chips → 近7日趋势+收入来源 → 掌柜晨报卡 → 问小掌柜胶囊 → 今日事项 → TabBar（小掌柜/待办/日历/经营）
// 已删除：快捷操作行/四宫格/「今日最重要」/「最近记录」（不得复活）
const {T, P, Icon, Money, Badge, Phone, Board} = window.FusionKit;

// ================= 局部组件（fusion-kit 未提供，仅在页面内定义） =================

// 四 Tab 冻结 IA：小掌柜/待办/日历/经营
function HomeTabBar({t, active, onChange}) {
  const tabs = [
    {k:'home', l:'小掌柜', i:P.house},
    {k:'todo', l:'待办', i:P.checklist},
    {k:'calendar', l:'日历', i:P.calendar},
    {k:'biz', l:'经营', i:P.chart},
  ];
  return <div style={{height:50, flexShrink:0, background:t.surface, borderTop:`0.5px solid ${t.sep}`, display:'flex', paddingBottom:2}}>
    {tabs.map(tb => <div key={tb.k} onClick={()=>onChange(tb.k)} style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:2, cursor:'pointer'}}>
      <Icon d={tb.i} size={22} color={active===tb.k? t.greenDeep : t.ink3}/>
      <div style={{fontSize:11, fontWeight:600, color:active===tb.k? t.greenInk : t.ink3}}>{tb.l}</div>
    </div>)}
  </div>;
}

// 日期头：左上「10月25日 周日」+ 右上 plus=记一笔
function DateHeader({t, onQuick}) {
  return <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', padding:'6px 12px 4px 16px'}}>
    <div>
      <div style={{fontSize:17, fontWeight:700, color:t.ink}}>10月25日 周日</div>
      <div style={{fontSize:11, color:t.ink3, marginTop:1}}>2026 · 今日营业中</div>
    </div>
    <div id="v39.home.quickRecord" onClick={onQuick} style={{width:44, height:44, borderRadius:12, background:t.fill, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer', flexShrink:0}}>
      <Icon d={P.plus} size={22} color={t.greenInk}/>
    </div>
  </div>;
}

// A 基因：本月营业额 Hero（深墨绿 + 衬线大数字 + 「本月」小标）
function Hero({t}) {
  return <div style={{margin:'10px 16px 0', background:t.hero, borderRadius:20, padding:'10px 16px 8px'}}>
    <div style={{display:'flex', alignItems:'center', gap:7}}>
      <span style={{fontSize:12.5, fontWeight:600, color:t.heroInk}}>本月营业额</span>
      <span style={{fontSize:11, fontWeight:700, color:t.hero, background:t.heroInk, borderRadius:5, padding:'1px 6px', lineHeight:1.4}}>本月</span>
    </div>
    <Money v="¥63,420" size={34} color={t.heroInk}/>
    <div style={{display:'flex', justifyContent:'space-between', marginTop:1}}>
      <span style={{fontSize:11.5, color:t.heroInk}}>较上月 ↑8.2%</span>
      <span style={{fontSize:11.5, color:t.heroInk}}>月目标 79%</span>
    </div>
  </div>;
}

// 四 chips：待办 2 / 逾期 1 / 临期 3 件 / 配送 2 单；点按选中高亮并显示注记
function ChipStrip({t, sel, onSel}) {
  const chips = [
    {k:'todo', n:'2', unit:'', label:'待办', note:'查看今日待办 · 上午优先'},
    {k:'overdue', n:'1', unit:'', label:'逾期', note:'直达待办 · 逾期筛选'},
    {k:'expiry', n:'3', unit:' 件', label:'临期', note:'7 天内到期 · 3 件商品'},
    {k:'delivery', n:'2', unit:' 单', label:'配送', note:'2 单配送 · 今天跟进'},
  ];
  const cur = chips.find(c => c.k === sel);
  return <div>
    <div style={{display:'flex', gap:8, margin:'10px 16px 0'}}>
      {chips.map(c => {
        const on = sel === c.k;
        return <div key={c.k} onClick={()=>onSel(on? null : c.k)} style={{flex:1, minWidth:0, borderRadius:12, padding:'7px 4px 6px', textAlign:'center', cursor:'pointer',
          background: on? t.surface : t.fill, border:`0.5px solid ${on? t.green : 'transparent'}`,
          boxShadow: on? '0 2px 8px rgba(31,169,113,0.16)' : 'none'}}>
          <div style={{fontSize:15, lineHeight:1.15, fontWeight:700, color: on? t.greenInk : t.ink, fontVariantNumeric:'tabular-nums'}}>
            {c.n}{c.unit && <span style={{fontSize:11, fontWeight:500}}>{c.unit}</span>}
          </div>
          <div style={{fontSize:11, lineHeight:1.15, marginTop:2, color: on? t.ink2 : t.ink3}}>{c.label}</div>
        </div>;
      })}
    </div>
    <div style={{margin:'4px 16px 0', minHeight:16, display:'flex', alignItems:'center', gap:6}}>
      {cur && <React.Fragment><span style={{width:6, height:6, borderRadius:'50%', background:t.green, flexShrink:0}}/><span style={{fontSize:11.5, fontWeight:600, color:t.ink2}}>{cur.note}</span></React.Fragment>}
    </div>
  </div>;
}

// 近 7 日趋势柱图（周一..周日，今天高亮）
function TrendChart({t, data, labels, todayIdx}) {
  const max = Math.max(...data);
  return <div data-deco="1" style={{marginTop:8}}>
    <div style={{display:'flex', alignItems:'flex-end', gap:5, height:44}}>
      {data.map((v,i) => <div key={i} style={{flex:1, display:'flex', justifyContent:'center'}}>
        <div style={{width:18, borderRadius:4, height:10 + Math.round(v/max*32),
          background: i===todayIdx? '#1FA971' : 'rgba(31,169,113,0.28)'}}/>
      </div>)}
    </div>
    <div style={{display:'flex', gap:5, marginTop:4}}>
      {labels.map((l,i) => <div key={i} style={{flex:1, textAlign:'center', fontSize:11, fontWeight: i===todayIdx? 700 : 400, color: i===todayIdx? t.greenInk : t.ink3}}>{l}</div>)}
    </div>
  </div>;
}

// 收入来源：门店 61% / 美团 32% / 其他 7% 三色条
function SourceBar({t}) {
  const srcs = [
    {k:'门店', p:61, c:'#1FA971'},
    {k:'美团', p:32, c:t.warn},
    {k:'其他', p:7, c:t.ink4},
  ];
  return <div>
    <div data-deco="1" style={{display:'flex', height:8, borderRadius:4, overflow:'hidden', marginTop:5}}>
      {srcs.map(s => <div key={s.k} style={{width:`${s.p}%`, background:s.c}}/>)}
    </div>
    <div style={{display:'flex', justifyContent:'space-between', marginTop:5}}>
      {srcs.map(s => <span key={s.k} style={{fontSize:11, color:t.ink3}}>{s.k} <span style={{color:t.ink, fontWeight:700}}>{s.p}%</span></span>)}
    </div>
  </div>;
}

// 近 7 日趋势 + 收入来源（同一卡片）
function TrendCard({t}) {
  const data = [3520, 4180, 2960, 4870, 3850, 5240, 3480];
  const labels = ['周一','周二','周三','周四','周五','周六','周日'];
  return <div style={{margin:'10px 16px 0', background:t.surface, borderRadius:12, overflow:'hidden', padding:'10px 14px 10px'}}>
    <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline'}}>
      <span style={{fontSize:13, fontWeight:600, color:t.ink3}}>近 7 日趋势</span>
      <span style={{fontSize:11.5, fontWeight:700, color:t.greenInk, fontVariantNumeric:'tabular-nums'}}>今日 ¥3,480</span>
    </div>
    <TrendChart t={t} data={data} labels={labels} todayIdx={6}/>
    <div style={{borderTop:`0.5px solid ${t.sep}`, marginTop:6}}/>
    <div style={{fontSize:13, fontWeight:600, color:t.ink3, marginTop:6}}>收入来源</div>
    <SourceBar t={t}/>
  </div>;
}

// 掌柜晨报卡片（新功能）：点击弹 MorningBriefSheet
function BriefCard({t, onOpen}) {
  return <div onClick={onOpen} style={{margin:'10px 16px 0', padding:'10px 14px', background:t.paper, border:`0.5px solid ${t.hair}`, borderRadius:12, display:'flex', alignItems:'center', gap:10, cursor:'pointer'}}>
    <div style={{width:36, height:36, borderRadius:9, background:t.hero, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0}}>
      <Icon d={P.sun} size={19} color={t.heroInk}/>
    </div>
    <div style={{flex:1, minWidth:0}}>
      <div style={{display:'flex', alignItems:'center', gap:6}}>
        <span style={{fontSize:14, fontWeight:700, color:t.ink}}>掌柜晨报</span>
        <span style={{fontSize:11, fontWeight:600, color:t.greenInk, border:`0.5px solid ${t.greenDeep}`, borderRadius:4, padding:'0 5px', lineHeight:1.5}}>新功能</span>
      </div>
      <div style={{fontSize:11.5, color:t.ink3, marginTop:2}}>昨日营业额 ¥2,860 · 较前日 ↑12%</div>
    </div>
    <Icon d={P.chevron} size={15} color={t.ink4} style={{flexShrink:0}}/>
  </div>;
}

// 问小掌柜胶囊：点击出「打开 AI 对话」注记
function AiCapsule({t, note, onToggle}) {
  return <div style={{margin:'10px 16px 0', position:'relative'}}>
    <div onClick={onToggle} style={{height:42, borderRadius:21, background:t.surface, border:`0.5px solid ${t.greenDeep}`,
      boxShadow:'0 2px 10px rgba(31,169,113,0.14)', display:'flex', alignItems:'center', gap:8, padding:'0 5px 0 14px', cursor:'pointer'}}>
      <Icon d={P.sparkles} size={16} color={t.greenDeep}/>
      <div style={{flex:1, fontSize:13.5, color:t.ink3}}>问小掌柜，记录或查询…</div>
      <div style={{width:34, height:34, borderRadius:'50%', background:'#146B52', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0}}>
        <Icon d={P.arrowUpRight} size={15} color="#FFFFFF" strokeWidth={2}/>
      </div>
    </div>
    {note && <div data-deco="1" style={{position:'absolute', left:12, bottom:52, zIndex:25, background:t.surface, border:`0.5px solid ${t.sep}`,
      boxShadow:'0 2px 10px rgba(0,0,0,0.12)', borderRadius:8, padding:'5px 9px', fontSize:11.5, fontWeight:600, color:t.greenInk, whiteSpace:'nowrap'}}>打开 AI 对话</div>}
  </div>;
}

// 今日事项（3 条）
function TodoSection({t}) {
  const items = [
    {time:'9:30', title:'供应商结账', dot:t.danger},
    {time:'14:00', title:'302 补货', dot:t.green},
    {time:'18:00', title:'盘点可乐', dot:t.warn},
  ];
  return <div style={{margin:'10px 16px 0'}}>
    <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:3}}>
      <span style={{fontSize:13, fontWeight:600, color:t.ink3}}>今日事项</span>
      <Badge tone="gray" t={t}>3 条</Badge>
    </div>
    <div style={{background:t.surface, borderRadius:12, overflow:'hidden', padding:'2px 14px'}}>
      {items.map((it,i) => <div key={i} style={{display:'flex', alignItems:'center', gap:10, padding:'9px 0', borderTop: i? `0.5px solid ${t.sep}` : 'none'}}>
        <span style={{width:5, height:5, borderRadius:'50%', background:it.dot, flexShrink:0}}/>
        <span style={{width:50, fontSize:12.5, fontWeight:700, color:t.greenInk, fontVariantNumeric:'tabular-nums'}}>{it.time}</span>
        <span style={{flex:1, fontSize:13.5, fontWeight:500, color:t.ink}}>{it.title}</span>
      </div>)}
    </div>
  </div>;
}

// 掌柜晨报 Sheet（全屏覆盖在 phone 内容区内，从底部升起）
function MorningBriefSheet({t, onClose}) {
  const stats = [
    {k:'今日收入', v:'¥3,480'},
    {k:'今日待办', v:'2 项'},
    {k:'配送中', v:'2 单'},
  ];
  const focus = [
    {t:'逾期待办 ×1', d:'昨天供应商对账'},
    {t:'临期商品 ×3', d:'可乐剩 6 件 · 最早 10月27日'},
  ];
  const tips = [
    {dot:t.danger, tag:'逾期', txt:'有 1 项待办逾期，建议今天处理'},
    {dot:t.warn, tag:'临期', txt:'可乐剩余 6 件，低于预警线 10 件，建议补货'},
    {dot:t.info, tag:'配送', txt:'有 2 单配送待跟进，建议关注时效'},
  ];
  return <div data-deco="1" style={{position:'absolute', left:0, top:0, right:0, bottom:0, zIndex:30, background:t.page,
    padding:'10px 16px 16px', overflowY:'auto', animation:'fusionSheetUp 300ms cubic-bezier(0.32,0.72,0,1)'}}>
    <style>{'@keyframes fusionSheetUp{from{transform:translateY(64px);opacity:0}to{transform:translateY(0);opacity:1}}'}</style>
    <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10}}>
      <div>
        <div style={{fontSize:16, fontWeight:700, color:t.ink}}>掌柜晨报</div>
        <div style={{fontSize:11, color:t.ink3, marginTop:1}}>10月25日 · 周日 · 08:00 生成</div>
      </div>
      <div onClick={onClose} style={{width:48, height:44, borderRadius:10, background:t.fill, color:t.greenInk, fontSize:12, fontWeight:700,
        display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer', flexShrink:0}}>关闭</div>
    </div>

    <div style={{background:t.hero, borderRadius:16, padding:'14px 16px'}}>
      <div style={{fontSize:17, fontWeight:700, color:t.heroInk}}>早上好，掌柜</div>
      <div style={{fontSize:11.5, color:t.heroInk, marginTop:3}}>昨日营业额 ¥2,860 · 较前日 ↑12%</div>
    </div>

    <div style={{fontSize:12, fontWeight:700, color:t.ink3, letterSpacing:0.5, margin:'14px 0 6px'}}>今日重点</div>
    <div style={{background:t.surface, borderRadius:12, overflow:'hidden', padding:'4px 14px'}}>
      {focus.map((f,i) => <div key={i} style={{display:'flex', alignItems:'center', gap:10, padding:'9px 0', borderTop: i? `0.5px solid ${t.sep}` : 'none'}}>
        <span style={{width:6, height:6, borderRadius:'50%', background:t.green, flexShrink:0}}/>
        <span style={{flex:1, minWidth:0, fontSize:13, fontWeight:600, color:t.ink2}}>{f.t}</span>
        <span style={{fontSize:11, color:t.ink3, whiteSpace:'nowrap'}}>{f.d}</span>
      </div>)}
    </div>

    <div style={{fontSize:12, fontWeight:700, color:t.ink3, letterSpacing:0.5, margin:'14px 0 6px'}}>今日概览</div>
    <div style={{background:t.surface, borderRadius:12, padding:'12px 6px', display:'flex'}}>
      {stats.map((s,i) => <div key={i} style={{flex:1, textAlign:'center', borderLeft: i? `0.5px solid ${t.sep}` : 'none'}}>
        <div style={{fontSize:17, fontWeight:700, color:t.greenInk, fontVariantNumeric:'tabular-nums'}}>{s.v}</div>
        <div style={{fontSize:11, color:t.ink3, marginTop:2}}>{s.k}</div>
      </div>)}
    </div>

    <div style={{fontSize:12, fontWeight:700, color:t.ink3, letterSpacing:0.5, margin:'14px 0 6px'}}>月目标</div>
    <div style={{background:t.surface, borderRadius:12, padding:'12px 14px'}}>
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline'}}>
        <span style={{fontSize:13.5, fontWeight:700, color:t.ink}}>本月 79%</span>
        <span style={{fontSize:11.5, color:t.ink3, fontVariantNumeric:'tabular-nums'}}>¥63,420 / ¥80,000</span>
      </div>
      <div data-deco="1" style={{position:'relative', height:6, borderRadius:3, background:t.fill, marginTop:9}}>
        <div style={{position:'absolute', left:0, top:0, bottom:0, width:'79%', borderRadius:3, background:'#1FA971'}}/>
      </div>
    </div>

    <div style={{fontSize:12, fontWeight:700, color:t.ink3, letterSpacing:0.5, margin:'14px 0 6px'}}>掌柜建议</div>
    <div style={{background:t.surface, borderRadius:12, overflow:'hidden', padding:'2px 14px'}}>
      {tips.map((tp,i) => <div key={i} style={{display:'flex', alignItems:'flex-start', gap:9, padding:'10px 0', borderTop: i? `0.5px solid ${t.sep}` : 'none'}}>
        <span style={{marginTop:5, width:6, height:6, borderRadius:'50%', background:tp.dot, flexShrink:0}}/>
        <span style={{marginTop:1, fontSize:11.5, fontWeight:700, color:t.ink2, flexShrink:0}}>{tp.tag}</span>
        <span style={{flex:1, fontSize:12.5, color:t.ink2, lineHeight:1.45}}>{tp.txt}</span>
      </div>)}
    </div>
  </div>;
}

// 工作台整屏（phone 内容区 764 内）
function HomeScreen({t, mode}) {
  const [chip, setChip] = React.useState(mode === 'overdue' ? 'overdue' : null);
  const [sheetOpen, setSheetOpen] = React.useState(mode === 'sheet');
  const [aiNote, setAiNote] = React.useState(false);
  const [plusNote, setPlusNote] = React.useState(false);
  const [tab, setTab] = React.useState('home');

  const onQuick = () => {
    setPlusNote(true);
    setTimeout(() => setPlusNote(false), 1600);
  };

  return <div style={{display:'flex', flexDirection:'column', height:'100%', position:'relative'}}>
    <div style={{flex:1, overflowY:'auto'}}>
      <DateHeader t={t} onQuick={onQuick}/>
      <Hero t={t}/>
      <ChipStrip t={t} sel={chip} onSel={setChip}/>
      <TrendCard t={t}/>
      <BriefCard t={t} onOpen={()=>setSheetOpen(true)}/>
      <AiCapsule t={t} note={aiNote} onToggle={()=>setAiNote(v=>!v)}/>
      <TodoSection t={t}/>
    </div>
    <HomeTabBar t={t} active={tab} onChange={setTab}/>
    {plusNote && <div data-deco="1" style={{position:'absolute', right:12, top:58, zIndex:25, background:t.surface, border:`0.5px solid ${t.sep}`,
      boxShadow:'0 2px 10px rgba(0,0,0,0.12)', borderRadius:8, padding:'5px 10px', fontSize:11.5, fontWeight:600, color:t.greenInk, whiteSpace:'nowrap'}}>记一笔 · 快速记录</div>}
    {sheetOpen && <MorningBriefSheet t={t} onClose={()=>setSheetOpen(false)}/>}
  </div>;
}

function HomePhone({dark=false, scale=1, tag, tagNote, mode='default'}) {
  return <Phone dark={dark} scale={scale} tag={tag} tagNote={tagNote}>
    <HomeScreen t={dark? T.dark : T.light} mode={mode}/>
  </Phone>;
}

function App() {
  return <Board no="工作台 · 首页" title="小掌柜工作台 · 首页"
    note="V3.9.2 权威结构：日期头+记一笔 → 本月营业额 Hero → 四 chips（点按选中出注记，逾期注记直达待办）→ 近 7 日趋势+收入来源 → 掌柜晨报卡（点击弹晨报 sheet，可关闭）→ 问小掌柜胶囊（点击出「打开 AI 对话」注记）→ 今日事项。已删除快捷操作行/四宫格/今日最重要/最近记录。">
    <HomePhone tag="工作台 · Light 完整首页" note="主视觉 1.2× · 全部区块" scale={1.2}/>
    <HomePhone dark tag="工作台 · Dark" note="暗色语义色 AA 达标" scale={1.08}/>
    <HomePhone mode="sheet" tag="掌柜晨报 · Sheet 展开态" note="晨报全内容 · 从底部升起" scale={1.08}/>
    <HomePhone mode="overdue" tag="逾期 chip 选中 + 注记态" note="直达待办 · 逾期筛选" scale={1}/>
    <HomePhone tag="工作台 · Light 小比例" note="0.92× 整体总览" scale={0.92}/>
  </Board>;
}

window.FusionPage = App;
