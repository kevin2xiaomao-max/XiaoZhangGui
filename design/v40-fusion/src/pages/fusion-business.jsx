// fusion-business.jsx — 「你的小掌柜」iOS V4.0 融合设计 · 经营页（V3.9.2 结构）
const { T, FONT, SERIF, P, Icon, Money, Badge, TabBar, Phone, Board } = window.FusionKit;
const { useState, useEffect } = window.React;

const CSS = `
@keyframes popIn { from { opacity:0; transform: translateY(-4px) } to { opacity:1; transform:none } }
@keyframes sheetIn { from { opacity:0; transform: translateY(26px) } to { opacity:1; transform:none } }
@keyframes fadeIn { from { opacity:0 } to { opacity:1 } }
`;

const PERIODS = {
  day:   { bars:[1180,920,1360,1050,1280,1490,1140], labels:['10时','12时','14时','16时','18时','20时','22时'], total:'¥8,420', max:'¥1,490', avg:'¥1,203' },
  week:  { bars:[1480,2120,1850,2430,2080,1960,1930], labels:['周一','周二','周三','周四','周五','周六','周日'], total:'¥14,850', max:'¥2,430', avg:'¥2,121' },
  month: { bars:[1620,1480,1850,1720,1960,2040,1890,2210,2350,2480,2640,2980], labels:['14','15','16','17','18','19','20','21','22','23','24','25'], total:'¥25,220', max:'¥2,980', avg:'¥2,102' },
};

const RECS = [
  { date:'10月25日', ch:'美团', v:'¥680' },
  { date:'10月24日', ch:'门店', v:'¥1,240' },
  { date:'10月23日', ch:'美团', v:'¥520' },
  { date:'10月22日', ch:'门店', v:'¥890' },
  { date:'10月21日', ch:'美团', v:'¥430' },
];

// 局部小组件：三段切换（min 42px 高，保证 0.94× 后仍 ≥38）
const PERIOD_OPTS = [['day','日'],['week','周'],['month','月']];
function PeriodSwitch({t, value, onChange}) {
  return (
    <div data-deco="1" style={{display:'flex', background:t.fill, borderRadius:10, padding:3}}>
      {PERIOD_OPTS.map(([k,l]) => (
        <div key={k} data-deco="1" onClick={()=>onChange(k)}
          style={{padding:'11px 15px', fontSize:13, fontWeight:600, lineHeight:'20px', borderRadius:8,
            background: value===k ? t.surface : 'transparent',
            color: value===k ? t.ink : t.ink3,
            boxShadow: value===k ? '0 1px 3px rgba(0,0,0,0.10)' : 'none',
            cursor:'pointer', transition:'background 0.18s, color 0.18s'}}>{l}</div>
      ))}
    </div>
  );
}

// 局部小组件：收入趋势柱图（点柱读数；月视图静态高亮）
function TrendChart({t, period, bar, onBar}) {
  const P = PERIODS[period];
  const max = Math.max.apply(null, P.bars);
  const clickable = period !== 'month';
  return (
    <div style={{padding:'0 16px'}}>
      <div style={{display:'flex', alignItems:'flex-end', gap: clickable?8:4, height:112}}>
        {P.bars.map((v,i) => {
          const h = Math.round(v/max*82);
          const sel = i===bar;
          return (
            <div key={i} onClick={clickable?()=>onBar(i):undefined}
              style={{flex:1, position:'relative', height:112, cursor: clickable?'pointer':'default'}}>
              {sel && <div data-deco="1" style={{position:'absolute', bottom:h+24, left:'50%', transform:'translateX(-50%)',
                fontSize:11, fontWeight:600, color:t.ink, whiteSpace:'nowrap'}}>¥{v.toLocaleString()}</div>}
              <div data-deco="1" style={{position:'absolute', bottom:18, left:'50%', transform:'translateX(-50%)',
                width: clickable?24:16, height:h, borderRadius:'6px 6px 2px 2px',
                background: sel ? t.greenInk : t.greenTint, transition:'height 0.35s, background 0.2s'}}/>
              <div style={{position:'absolute', bottom:0, left:0, right:0, textAlign:'center', fontSize:11, color:t.ink3}}>{P.labels[i]}</div>
            </div>
          );
        })}
      </div>
      <div style={{display:'flex', gap:18, padding:'10px 0 4px', fontSize:11, color:t.ink3}}>
        <span>总收入 <Money v={P.total} size={11} serif={false} color={t.ink}/></span>
        <span>日均 <Money v={P.avg} size={11} serif={false} color={t.ink}/></span>
        <span>最高 <Money v={P.max} size={11} serif={false} color={t.ink}/></span>
      </div>
    </div>
  );
}

// 局部小组件：收入来源三色条 + 图例
function SourceBar({t}) {
  const parts = [
    { n:'门店', v:'¥38,690', p:61, c:t.greenInk },
    { n:'美团', v:'¥20,290', p:32, c:t.green },
    { n:'其他', v:'¥4,440', p:7, c:t.ink3 },
  ];
  return (
    <div style={{padding:'0 16px'}}>
      <div style={{display:'flex', height:10, borderRadius:5, overflow:'hidden'}}>
        {parts.map(s => <div key={s.n} style={{width:s.p+'%', background:s.c}}/>)}
      </div>
      <div style={{display:'flex', marginTop:8}}>
        {parts.map(s => (
          <div key={s.n} style={{flex:1, display:'flex', alignItems:'center', gap:7}}>
            <span style={{width:8, height:8, borderRadius:4, background:s.c, flexShrink:0}}/>
            <div>
              <div style={{fontSize:12, color:t.ink3, lineHeight:'16px'}}>{s.n}</div>
              <div style={{fontSize:13, fontWeight:700, color:t.ink, lineHeight:'18px', marginTop:1}}>
                <Money v={s.v} size={13}/> <span style={{fontSize:11, fontWeight:600, color:t.ink3}}>{s.p}%</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function RecRow({t, date, ch, v, last}) {
  return (
    <div style={{display:'flex', alignItems:'center', padding:'3px 16px', borderBottom: last?'none':`1px solid ${t.hair}`}}>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontSize:14, fontWeight:600, color:t.ink, lineHeight:'20px'}}>{ch}</div>
        <div style={{fontSize:11, color:t.ink3, lineHeight:'15px'}}>{date}</div>
      </div>
      <Money v={v} size={16} color={t.ink}/>
    </div>
  );
}

// 局部小组件：月度报表 bottom sheet
function MonthSheet({t, shared, onShare, onClose}) {
  const parts = [
    { n:'门店', p:61, c:t.greenInk }, { n:'美团', p:32, c:t.green }, { n:'其他', p:7, c:t.ink3 },
  ];
  const bars = [46,52,38,60,50,44,56];
  const btnText = shared ? '已生成图片 · 已保存到相册' : '分享月报图片';
  return (
    <div style={{position:'absolute', inset:0, zIndex:60, display:'flex', alignItems:'flex-end'}}>
      <div data-deco="1" style={{position:'absolute', inset:0, background:t.hero, opacity:0.62, animation:'fadeIn 0.2s ease'}}/>
      <div data-deco="1" style={{position:'relative', width:'100%', background:t.surface,
        borderRadius:'20px 20px 0 0', padding:'16px 16px 20px', animation:'sheetIn 0.25s ease',
        maxHeight:'88%', overflowY:'auto'}}>
        <div style={{display:'flex', alignItems:'center'}}>
          <span style={{fontSize:17, fontWeight:700, color:t.ink}}>掌柜的月报</span>
          <span style={{marginLeft:10, fontSize:12, fontWeight:600, color:t.ink, background:t.fill, padding:'3px 8px', borderRadius:6}}>10月</span>
          <span style={{flex:1}}/>
          <span onClick={onClose} style={{width:38, height:38, marginRight:-8, display:'flex', alignItems:'center',
            justifyContent:'center', fontSize:15, color:t.ink3, cursor:'pointer'}}>✕</span>
        </div>
        <div style={{marginTop:10}}><Badge tone="green" t={t}>↑12% 较上月同期</Badge></div>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline', marginTop:14}}>
          <span style={{fontSize:13, color:t.ink3}}>本月营业额</span>
          <Money v="¥63,420" size={26} color={t.ink}/>
        </div>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline', marginTop:8}}>
          <span style={{fontSize:13, color:t.ink3}}>支出</span>
          <Money v="¥38,150" size={20} color={t.ink2}/>
        </div>
        <div style={{fontSize:12, color:t.ink3, marginTop:14, marginBottom:4}}>近 7 日</div>
        <div style={{display:'flex', alignItems:'flex-end', gap:12}}>
          {bars.map((h,i) => (
            <div key={i} style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'flex-end', gap:4}}>
              {i===3 && <div style={{fontSize:11, fontWeight:600, color:t.ink, lineHeight:'14px'}}>¥2,430</div>}
              <div style={{width:26, height:h, borderRadius:5, background: i===3 ? t.greenInk : t.greenTint}}/>
              <div style={{fontSize:11, color:t.ink3, lineHeight:'14px'}}>{['一','二','三','四','五','六','日'][i]}</div>
            </div>
          ))}
        </div>
        <div style={{fontSize:12, color:t.ink3, marginTop:12, marginBottom:6}}>收入来源</div>
        <div style={{display:'flex', height:8, borderRadius:4, overflow:'hidden'}}>
          {parts.map(s => <div key={s.n} style={{width:s.p+'%', background:s.c}}/>)}
        </div>
        <div style={{display:'flex', gap:10, marginTop:7}}>
          {parts.map(s => (
            <span key={s.n} style={{fontSize:12, color:t.ink3, lineHeight:'16px'}}>
              <span style={{display:'inline-block', width:8, height:8, borderRadius:4, background:s.c, marginRight:5}}/>{s.n} {s.p}%
            </span>
          ))}
        </div>
        <div style={{marginTop:13}}>
          <div style={{display:'flex', justifyContent:'space-between', marginBottom:6}}>
            <span style={{fontSize:13, color:t.ink3}}>待办完成</span>
            <span style={{fontSize:13, fontWeight:700, color:t.greenInk}}>62%</span>
          </div>
          <div style={{height:4, background:t.fill, borderRadius:2, overflow:'hidden'}}>
            <div data-deco="1" style={{width:'62%', height:4, background:t.greenInk, borderRadius:2, transition:'width 0.4s'}}/>
          </div>
        </div>
        <button onClick={onShare} data-deco="1" style={{marginTop:16, width:'100%', height:46, border:'none', borderRadius:12,
          background:t.warn, color: t===T.light ? T.light.surface : T.light.ink, fontSize:15, fontWeight:700,
          cursor:'pointer', transition:'background 0.2s', fontFamily:FONT}}>{btnText}</button>
      </div>
    </div>
  );
}

function Screen({spec}) {
  const t = spec.dark ? T.dark : T.light;
  const [period, setPeriod] = useState(spec.period);
  const [bar, setBar] = useState(spec.bar);
  const [menu, setMenu] = useState(!!spec.menu);
  const [sheet, setSheet] = useState(!!spec.sheet);
  const [shared, setShared] = useState(false);
  return (
    <div style={{flex:1, minHeight:0, position:'relative', overflow:'hidden', display:'flex', flexDirection:'column'}}>
      <div style={{display:'flex', alignItems:'center', padding:'8px 16px 4px', position:'relative', zIndex:41}}>
        <span style={{flex:1, fontSize:17, fontWeight:700, color:t.ink}}>经营</span>
        <span onClick={()=>setMenu(!menu)} style={{width:42, height:42, display:'flex', alignItems:'center',
          justifyContent:'center', fontSize:20, color:t.ink, cursor:'pointer', borderRadius:10}}>⋯</span>
        {menu && (
          <div data-deco="1" style={{position:'absolute', top:48, right:12, zIndex:40, background:t.surface,
            border:`1px solid ${t.hair}`, borderRadius:12, padding:6,
            boxShadow:'0 8px 24px rgba(0,0,0,0.14)', animation:'popIn 0.18s ease'}}>
            <div style={{fontSize:11, color:t.ink3, padding:'6px 12px 2px', lineHeight:'15px'}}>数据报表</div>
            <div onClick={()=>{ setMenu(false); setSheet(true); }} style={{padding:'9px 12px', fontSize:13, fontWeight:600,
              color:t.ink, borderRadius:8, cursor:'pointer', whiteSpace:'nowrap'}}>月度报表</div>
          </div>
        )}
      </div>
      <div style={{padding:'2px 16px 6px'}}>
        <div style={{display:'flex', alignItems:'center', height:20}}>
          <span style={{fontSize:13, color:t.ink3}}>本月营业额</span>
          <span style={{marginLeft:10, fontSize:12, fontWeight:700, color:t.greenInk, background:t.fill,
            padding:'3px 9px', borderRadius:8, lineHeight:'18px'}}>较上月 ↑12%</span>
        </div>
        <div style={{marginTop:4, lineHeight:'48px'}}><Money v="¥63,420" size={40} color={t.ink}/></div>
      </div>
      <div style={{marginTop:6}}>
        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', padding:'0 16px 8px'}}>
          <span style={{fontSize:14, fontWeight:700, color:t.ink}}>收入趋势</span>
          <PeriodSwitch t={t} value={period} onChange={setPeriod}/>
        </div>
        <TrendChart t={t} period={period} bar={bar} onBar={setBar}/>
      </div>
      <div style={{marginTop:8}}>
        <div style={{padding:'0 16px 6px', fontSize:14, fontWeight:700, color:t.ink}}>收入来源</div>
        <SourceBar t={t}/>
      </div>
      <div style={{marginTop:8, padding:'0 16px'}}>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
          <span style={{fontSize:14, fontWeight:700, color:t.ink}}>月目标</span>
          <span style={{fontSize:13, fontWeight:700, color:t.greenInk}}>79%</span>
        </div>
        <div style={{height:4, background:t.fill, borderRadius:2, marginTop:8, overflow:'hidden'}}>
          <div data-deco="1" style={{width:'79%', height:4, background:t.greenInk, borderRadius:2, transition:'width 0.4s'}}/>
        </div>
        <div style={{marginTop:6, fontSize:12, color:t.ink3, lineHeight:'17px'}}>
          <Money v="¥63,420" size={12} serif={false} color={t.ink}/> / <Money v="¥80,000" size={12} serif={false} color={t.ink3}/>
        </div>
      </div>
      <div style={{marginTop:10}}>
        <div style={{display:'flex', justifyContent:'space-between', padding:'0 16px 6px'}}>
          <span style={{fontSize:14, fontWeight:700, color:t.ink}}>近期记录</span>
          <span style={{fontSize:12, color:t.greenInk}}>全部</span>
        </div>
        {RECS.map((r,i) => <RecRow key={i} t={t} date={r.date} ch={r.ch} v={r.v} last={i===RECS.length-1}/>)}
      </div>
      {sheet && <MonthSheet t={t} shared={shared} onShare={()=>setShared(true)} onClose={()=>setSheet(false)}/>}
    </div>
  );
}

function PhoneBox({spec}) {
  const t = spec.dark ? T.dark : T.light;
  const [tab, setTab] = useState('biz');
  const [toast, setToast] = useState(null);
  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(()=>setToast(null), 1600);
    return ()=>clearTimeout(id);
  }, [toast]);
  const onTab = (k) => {
    setTab(k);
    setToast('已切换至「' + ({home:'首页', todo:'待办', calendar:'日历', biz:'经营'}[k]) + '」（原型演示）');
  };
  return (
    <Phone dark={spec.dark} scale={spec.scale} tag={spec.tag} tagNote={spec.note}>
      <Screen spec={spec}/>
      {toast && (
        <div data-deco="1" style={{position:'absolute', right:14, bottom:56, zIndex:70, background:t.surface,
          border:`1px solid ${t.hair}`, borderRadius:10, padding:'8px 12px', fontSize:12, color:t.ink,
          boxShadow:'0 6px 18px rgba(0,0,0,0.16)', animation:'fadeIn 0.18s ease'}}>{toast}</div>
      )}
      <TabBar t={t} active={tab} onChange={onTab}/>
    </Phone>
  );
}

const PHONES = [
  { dark:false, scale:1.14, tag:'Light · 日视图',    note:'主视图 · 默认日趋势',   period:'day',   bar:4,  menu:true,  sheet:false },
  { dark:true,  scale:1,    tag:'Dark · 周视图',     note:'周趋势 · 点柱读数',     period:'week',  bar:2,  menu:false, sheet:false },
  { dark:false, scale:1,    tag:'Light · 月报展开',  note:'月度报表 bottom sheet', period:'day',   bar:4,  menu:false, sheet:true  },
  { dark:false, scale:0.94, tag:'Light · 月视图',    note:'月趋势 · 0.94×',       period:'month', bar:11, menu:false, sheet:false },
  { dark:true,  scale:0.94, tag:'Dark · 日视图',     note:'深色 · 0.94× 错落',     period:'day',   bar:5,  menu:false, sheet:false, stagger:true },
];

window.FusionPage = function App() {
  return (
    <React.Fragment>
      <style>{CSS}</style>
      <Board no="02" title="经营" note="V3.9.2 · 本月营业额 ¥63,420 · 收入结构与月报分享">
        {PHONES.map((s,i) => (
          <div key={i} style={s.stagger ? {marginTop:52} : undefined}>
            <PhoneBox spec={s}/>
          </div>
        ))}
      </Board>
    </React.Fragment>
  );
};
