// fusion-todo.jsx — 「你的小掌柜」iOS V4.0 融合设计 · 待办页（V3.9.2 结构）
const { T, FONT, SERIF, P, Icon, Money, Badge, TabBar, EmptyState, Phone, Board } = window.FusionKit;
const { useState, useEffect } = window.React;

const CSS = `
@keyframes spin360 { to { transform: rotate(360deg) } }
@keyframes rowShake { 0%,100% { transform:none } 20% { transform:translateX(-5px) } 40% { transform:translateX(5px) } 60% { transform:translateX(-3px) } 80% { transform:translateX(3px) } }
@keyframes fadeIn { from { opacity:0 } to { opacity:1 } }
`;

const TABS = ['今天','明天','逾期','已完成','备忘'];

const INIT = [
  { id:'a', g:'上午', time:'9:30',  title:'供应商结账', src:'采购' },
  { id:'b', g:'上午', time:'10:00', title:'302 送水',    src:'外送' },
  { id:'c', g:'下午', time:'14:00', title:'302 补货',    src:'补货' },
  { id:'d', g:'下午', time:'15:30', title:'给美团对账',  src:'美团', over:'逾期 1 天' },
  { id:'e', g:'晚上', time:'18:00', title:'盘点可乐',    src:'库存' },
];
const OVER_ROWS = [
  { id:'f', g:'下午', time:'15:30', title:'给美团对账', src:'美团', over:'逾期 1 天' },
  { id:'g', g:'昨日', time:'16:00', title:'燃气缴费',   src:'缴费', over:'逾期 1 天' },
];
const DONE_ROWS = [
  { time:'9:00',  title:'查看昨日营收' },
  { time:'11:30', title:'回复供应商消息' },
  { time:'16:40', title:'更新库存表' },
];
const MEMOS = [
  ['补订收银纸', '11月2日'], ['续费美团年框', '11月15日'], ['给爸爸买生日礼物', '9月8日'],
];

// 局部小组件：五段分段器
function TodoSeg({t, value, onChange}) {
  return (
    <div data-deco="1" style={{display:'flex', background:t.fill, borderRadius:11, padding:3}}>
      {TABS.map(o => (
        <div key={o} data-deco="1" onClick={()=>onChange(o)} style={{flex:1, textAlign:'center',
          padding:'10px 0', fontSize:13, fontWeight:600, lineHeight:'20px', borderRadius:8, whiteSpace:'nowrap',
          background: value===o ? t.surface : 'transparent',
          color: value===o ? t.ink : t.ink3,
          boxShadow: value===o ? '0 1px 3px rgba(0,0,0,0.10)' : 'none',
          cursor:'pointer', transition:'background 0.18s, color 0.18s'}}>{o}</div>
      ))}
    </div>
  );
}

// 局部小组件：Editorial 进度头（32pt 衬线数字 + 4pt 进度条）
function TodoHeader({t, tab, counts}) {
  const CFG = {
    '今天':   ['今日待办', [['待办', counts.p], ['已完成', counts.d], ['逾期', counts.o]]],
    '明天':   ['明日待办', [['待办', 0], ['已完成', 0], ['逾期', 0]]],
    '逾期':   ['逾期事项', [['待处理', 2], ['已完成', 0], ['逾期', 2]]],
    '已完成': ['已办结',   [['待办', 0], ['已完成', 3], ['逾期', 0]]],
  };
  const cfg = CFG[tab];
  if (!cfg) return null;
  const nums = cfg[1];
  const total = nums[0][1] + nums[1][1] + nums[2][1];
  const pct = total ? Math.round(nums[1][1]/total*100) : 0;
  return (
    <div style={{padding:'8px 16px 12px'}}>
      <div style={{fontSize:12, color:t.ink3, marginBottom:8, lineHeight:'16px'}}>{cfg[0]}</div>
      <div style={{display:'flex', gap:30}}>
        {nums.map(([lab, num]) => (
          <div key={lab}>
            <div style={{fontFamily:SERIF, fontSize:32, fontWeight:700, color:t.ink,
              fontVariantNumeric:'tabular-nums', lineHeight:'36px'}}>{num}</div>
            <div style={{fontSize:12, color:t.ink3, marginTop:3, lineHeight:'16px'}}>{lab}</div>
          </div>
        ))}
      </div>
      <div style={{height:4, background:t.fill, borderRadius:2, marginTop:10, overflow:'hidden'}}>
        <div data-deco="1" style={{width:pct+'%', height:4, background:t.greenInk, borderRadius:2, transition:'width 0.4s'}}/>
      </div>
    </div>
  );
}

// 局部小组件：待办行（两段式勾选状态机：idle → spin(600ms) → done(停0.7s后移出) / fail）
function TodoRow({t, it, initial, onDone}) {
  const [st, setSt] = useState(initial || 'idle');
  const [gone, setGone] = useState(false);
  useEffect(() => {
    if (st !== 'spin') return;
    const id = setTimeout(()=>setSt(s => s==='spin' ? 'done' : s), 600);
    return ()=>clearTimeout(id);
  }, [st]);
  useEffect(() => {
    if (st !== 'done') return;
    if (onDone) onDone(it.id);
    const id = setTimeout(()=>setGone(true), 700);
    return ()=>clearTimeout(id);
  }, [st]);
  if (gone) return null;
  const click = st==='idle' ? ()=>setSt('spin') : undefined;
  return (
    <div data-deco={st!=='idle'?'1':undefined} onClick={click}
      style={{display:'flex', alignItems:'center', gap:12, padding:'10px 16px',
        cursor: st==='idle' ? 'pointer' : 'default',
        opacity: st==='done' ? 0.55 : 1, transition:'opacity 0.25s',
        animation: st==='fail' ? 'rowShake 0.45s ease' : undefined}}>
      <div style={{width:38, height:38, flexShrink:0, display:'flex', alignItems:'center',
        justifyContent:'center', position:'relative'}}>
        {st==='idle' && <div style={{width:22, height:22, borderRadius:11, border:`1.5px solid ${t.ink3}`, boxSizing:'border-box'}}/>}
        {st==='spin' && <div data-deco="1" style={{width:22, height:22, borderRadius:11,
          border:`2px solid ${t.ink4}`, borderTopColor:t.greenInk, boxSizing:'border-box',
          animation:'spin360 0.7s linear infinite'}}/>}
        {st==='done' && <div style={{width:22, height:22, borderRadius:11, background:'#146B52',
          display:'flex', alignItems:'center', justifyContent:'center',
          color:'#FFFFFF', fontSize:13, fontWeight:700}}>✓</div>}
        {st==='fail' && (
          <div style={{width:22, height:22, borderRadius:11, border:`1.5px solid ${t.danger}`, boxSizing:'border-box', position:'relative'}}>
            <div style={{position:'absolute', top:-3, right:-3, width:8, height:8, borderRadius:4,
              background:t.danger, border:'1.5px solid '+t.surface, boxSizing:'border-box'}}/>
          </div>
        )}
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:8, minWidth:0}}>
          <span style={{fontSize:14, fontWeight:600, color: st==='done' ? t.ink3 : t.ink,
            textDecoration: st==='done' ? 'line-through' : 'none', whiteSpace:'nowrap', lineHeight:'20px'}}>{it.title}</span>
          {it.over && <Badge tone="red" t={t}>{it.over}</Badge>}
        </div>
        {st==='fail' && (
          <div style={{display:'flex', alignItems:'center', gap:8, marginTop:6}}>
            <span style={{fontSize:11, fontWeight:600, color:t.dangerText, lineHeight:'16px'}}>保存失败，可重试</span>
            <span onClick={(e)=>{ e.stopPropagation(); setSt('spin'); }} style={{height:40, padding:'0 14px',
              display:'flex', alignItems:'center', background:'#146B52', color:'#FFFFFF', borderRadius:20,
              fontSize:12, fontWeight:600, cursor:'pointer'}}>重试</span>
            <span onClick={(e)=>{ e.stopPropagation(); setSt('idle'); }} style={{height:40, padding:'0 14px',
              display:'flex', alignItems:'center', background:t.fill, color:t.ink3, borderRadius:20,
              fontSize:12, fontWeight:600, cursor:'pointer'}}>放弃</span>
          </div>
        )}
      </div>
      <div style={{textAlign:'right', flexShrink:0}}>
        <div style={{fontSize:12, fontWeight:600, color:t.ink, fontVariantNumeric:'tabular-nums', lineHeight:'17px'}}>{it.time}</div>
        <div style={{fontSize:11, color:t.ink3, lineHeight:'15px'}}>{it.src}</div>
      </div>
    </div>
  );
}

function GroupList({t, groups, rows}) {
  return groups.map(g => {
    const list = rows.filter(r => r.g === g);
    if (!list.length) return null;
    return (
      <div key={g}>
        <div style={{padding:'10px 16px 4px', fontSize:12, fontWeight:700, color:t.ink3, letterSpacing:1, lineHeight:'16px'}}>{g}</div>
        {list.map(r => <TodoRow key={r.id} t={t} it={r} initial={r.initial} onDone={r.onDone}/>)}
      </div>
    );
  });
}

function Screen({spec}) {
  const t = spec.dark ? T.dark : T.light;
  const [tab, setTab] = useState(spec.tab);
  const [doneIds, setDoneIds] = useState({});
  const counts = {
    p: INIT.filter(i => !i.over && !doneIds[i.id]).length,
    d: 3 + Object.keys(doneIds).length,
    o: INIT.filter(i => i.over && !doneIds[i.id]).length,
  };
  const todayRows = INIT.map(it => ({
    ...it,
    initial: spec.failId === it.id ? 'fail' : 'idle',
    onDone: (id)=>setDoneIds(prev => prev[id] ? prev : { ...prev, [id]:true }),
  }));
  return (
    <div style={{flex:1, minHeight:0, position:'relative', overflow:'hidden', display:'flex', flexDirection:'column'}}>
      <div style={{padding:'10px 16px 0'}}><TodoSeg t={t} value={tab} onChange={setTab}/></div>
      {tab==='今天' && (
        <React.Fragment>
          <TodoHeader t={t} tab="今天" counts={counts}/>
          <GroupList t={t} groups={['上午','下午','晚上']} rows={todayRows}/>
        </React.Fragment>
      )}
      {tab==='明天' && (
        <React.Fragment>
          <TodoHeader t={t} tab="明天" counts={{}}/>
          <EmptyState t={t} icon="sparkles" title="今天没有待办，去休息一下吧"/>
        </React.Fragment>
      )}
      {tab==='逾期' && (
        <React.Fragment>
          <TodoHeader t={t} tab="逾期" counts={{}}/>
          <GroupList t={t} groups={['下午','昨日']} rows={OVER_ROWS.map(r => ({...r, onDone:()=>{}}))}/>
        </React.Fragment>
      )}
      {tab==='已完成' && (
        <React.Fragment>
          <TodoHeader t={t} tab="已完成" counts={{}}/>
          {DONE_ROWS.map(r => (
            <div key={r.time} style={{display:'flex', alignItems:'center', gap:12, padding:'10px 16px', opacity:0.55}}>
              <div style={{width:38, height:38, flexShrink:0, display:'flex', alignItems:'center', justifyContent:'center'}}>
                <div style={{width:22, height:22, borderRadius:11, background:'#146B52', display:'flex',
                  alignItems:'center', justifyContent:'center', color:'#FFFFFF', fontSize:13, fontWeight:700}}>✓</div>
              </div>
              <div style={{flex:1, fontSize:14, fontWeight:600, color:t.ink3, textDecoration:'line-through', lineHeight:'20px'}}>{r.title}</div>
              <div style={{fontSize:12, fontWeight:600, color:t.ink3, fontVariantNumeric:'tabular-nums'}}>{r.time}</div>
            </div>
          ))}
        </React.Fragment>
      )}
      {tab==='备忘' && (
        <React.Fragment>
          <div style={{padding:'12px 16px 6px', fontSize:14, fontWeight:700, color:t.ink}}>备忘</div>
          {MEMOS.map(m => (
            <div key={m[0]} style={{display:'flex', alignItems:'center', gap:10, padding:'9px 16px'}}>
              <span style={{width:6, height:6, borderRadius:3, background:t.green, flexShrink:0}}/>
              <span style={{flex:1, fontSize:14, color:t.ink, lineHeight:'20px'}}>{m[0]}</span>
              <span style={{fontSize:12, color:t.ink3}}>{m[1]}</span>
            </div>
          ))}
        </React.Fragment>
      )}
    </div>
  );
}

function PhoneBox({spec}) {
  const t = spec.dark ? T.dark : T.light;
  const [toast, setToast] = useState(null);
  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(()=>setToast(null), 1600);
    return ()=>clearTimeout(id);
  }, [toast]);
  return (
    <Phone dark={spec.dark} scale={spec.scale} tag={spec.tag} tagNote={spec.note}>
      <Screen spec={spec}/>
      {toast && (
        <div data-deco="1" style={{position:'absolute', right:14, bottom:56, zIndex:70, background:t.surface,
          border:`1px solid ${t.hair}`, borderRadius:10, padding:'8px 12px', fontSize:12, color:t.ink,
          boxShadow:'0 6px 18px rgba(0,0,0,0.16)', animation:'fadeIn 0.18s ease'}}>{toast}</div>
      )}
      <TabBar t={t} active="todo" onChange={(k)=>setToast('已切换至「' + ({home:'首页', todo:'待办', calendar:'日历', biz:'经营'}[k]) + '」（原型演示）')}/>
    </Phone>
  );
}

const PHONES = [
  { dark:false, scale:1.14, tag:'Light · 今天',   note:'主视图 · 勾选演示',  tab:'今天' },
  { dark:true,  scale:1,    tag:'Dark · 今天',    note:'深色模式',           tab:'今天' },
  { dark:false, scale:1,    tag:'逾期事项',       note:'红标 · 逾期 1 天',   tab:'逾期' },
  { dark:false, scale:1,    tag:'已完成',         note:'删除线列表',         tab:'已完成' },
  { dark:false, scale:1,    tag:'失败态演示',     note:'保存失败 · 可重试',  tab:'今天', failId:'b' },
];

window.FusionPage = function App() {
  return (
    <React.Fragment>
      <style>{CSS}</style>
      <Board no="04" title="待办" note="V3.9.2 · 今日待办 4 · 已完成 3 · 逾期 1 · 两段式勾选">
        {PHONES.map((s,i) => (
          <div key={i} style={{}}>
            <PhoneBox spec={s}/>
          </div>
        ))}
      </Board>
    </React.Fragment>
  );
};
