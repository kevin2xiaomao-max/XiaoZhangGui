// fusion-kit.jsx — V4.0 融合设计系统原型共享组件（B70/A20/C10）
// 依赖：React 18 UMD（global React）、_vendor/ios_frame.jsx（IosFrame + iosFrameStyles 原样内联）
const FONT = '-apple-system,"SF Pro Text","PingFang SC"';
const SERIF = 'Georgia,"Songti SC",serif';

const T = {
  light: {
    page:'#F3F8F5', surface:'#FFFFFF', fill:'#EAF3EE', paper:'#FCFBF7',
    ink:'#1A1D21', ink2:'#3A3F47', ink3:'#5F646E', ink4:'#B0B4BC',
    sep:'rgba(60,60,67,0.12)', hair:'rgba(22,26,24,0.16)',
    green:'#1FA971', greenDeep:'#168B68', greenInk:'#146B52',
    greenTint:'rgba(31,169,113,0.10)',
    warn:'#B25000', danger:'#E5484D', dangerText:'#D03028', info:'#0A84FF', infoText:'#0856B3',
    hero:'#10382A', heroInk:'#EAF3EE',
    bubble:'#0A6ED1', bubbleInk:'#FFFFFF',
    nav:'rgba(243,248,245,0.86)'
  },
  dark: {
    page:'#0B0F0D', surface:'#1C1C1E', fill:'#101614', paper:'#131815',
    ink:'#F5F5F7', ink2:'#C7C7CC', ink3:'#8E8E93', ink4:'#636366',
    sep:'rgba(255,255,255,0.08)', hair:'rgba(255,255,255,0.18)',
    green:'#1FA971', greenDeep:'#168B68', greenInk:'#2FBF71',
    greenTint:'rgba(31,169,113,0.14)',
    warn:'#FFB340', danger:'#FF6B6B', dangerText:'#FF6B6B', info:'#409CFF', infoText:'#409CFF',
    hero:'#12352B', heroInk:'#CBE9DA',
    bubble:'#0A5FD9', bubbleInk:'#FFFFFF',
    nav:'rgba(11,15,13,0.86)'
  }
};

// ---- 图标（极简 stroke SVG）----
const P = {
  house:'M3 11.4 12 3.8l9 7.6V21h-6v-6H9v6H3z',
  checklist:'M5 5h14M5 12h14M5 19h7 M19.2 16.4l1.3 1.3 2.5-2.9',
  calendar:'M5 6.5A1.5 1.5 0 0 1 6.5 5h11A1.5 1.5 0 0 1 19 6.5V19.5A1.5 1.5 0 0 1 17.5 21h-11A1.5 1.5 0 0 1 5 19.5zM5 9.5h14M8.5 3.5V7M15.5 3.5V7',
  chart:'M5 20V12M12 20V5M19 20V9',
  plus:'M12 5v14M5 12h14',
  mic:'M12 3.5a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0v-5a3 3 0 0 1 3-3z M5.5 12.5a6.5 6.5 0 0 0 13 0 M12 19v2.5',
  sparkles:'M12 4l1.5 4L17 9.5l-3.5 1.5L12 15l-1.5-4L7 9.5l3.5-1.5z M18.5 15l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z M5.5 3l.7 1.8L8 5.5l-1.8.7L5.5 8l-.7-1.8L3 5.5l1.8-.7z',
  chevron:'M9 5.5 15.5 12 9 18.5',
  gear:'M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7zM12 3l1.2 2.6 2.8-.6 1 2.7 2.6 1.2-.6 2.8 2.1 2.1-2.1 2.1.6 2.8-2.6 1.2-1-2.7-2.8.6L12 21l-1.2-2.6-2.8.6-1-2.7-2.6-1.2.6-2.8L3 10.2 5.1 8.1 4.5 5.3l2.6-1.2 1 2.7 2.8-.6z',
  bell:'M6 16v-5a6 6 0 0 1 12 0v5l1.5 2.5h-15zM10 21a2.2 2.2 0 0 0 4 0',
  cube:'M12 3.5 21 8.5v7L12 20.5 3 15.5v-7z M3 8.5l9 5 9-5 M12 13.5v7',
  clock:'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3.5 2',
  truck:'M2.5 6h11v10h-11zM13.5 10h4l3 3v3h-7z M7 19.5a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6zM17.5 19.5a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6z',
  store:'M4 8l1.6-4.5h12.8L20 8 M4 8v2.2c0 1.4 1 2.3 2.2 2.3 1.4 0 2.3-1.1 2.3-2.5 0 1.4 1 2.5 2.3 2.5 1.4 0 2.3-1.1 2.3-2.5 0 1.4 1 2.5 2.3 2.5 1.3 0 2.2-1 2.2-2.3V8 M5 12.5V20h14v-7.5 M9.5 20v-4.5h5V20',
  wallet:'M3.5 7A2.5 2.5 0 0 1 6 4.5h12V17H6a2.5 2.5 0 0 0-2.5 2.5z M3.5 7v9.5A2.5 2.5 0 0 0 6 19h12 M16.5 12h2.5',
  doc:'M6.5 3.5h7l4 4V20.5h-11z M13.5 3.5v4h4 M9.5 12h5M9.5 15.5h5',
  person:'M12 11.5a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 21a7.5 7.5 0 0 1 15 0',
  sun:'M12 17.5a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11zM12 2.5v2M12 19.5v2M4.5 12h-2M21.5 12h-2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M18.7 5.3l-1.4 1.4M6.7 17.3l-1.4 1.4',
  moon:'M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z',
  check:'M5 12.5l4.2 4.2L19 7',
  xmark:'M6 6l12 12M18 6L6 18',
  arrowUpRight:'M7 17 17 7M9 7h8v8',
  phone:'M6.5 3.5h3l1.6 4-2 1.6a12.5 12.5 0 0 0 5.8 5.8l1.6-2 4 1.6v3a2 2 0 0 1-2.2 2A16 16 0 0 1 4.5 5.7a2 2 0 0 1 2-2.2z',
  map:'M9 4 3.5 6v14L9 18l6 2 5.5-2V4L15 6z M9 4v14M15 6v14',
  bag:'M6.5 8h11l1 12.5h-13z M9 8V6.5a3 3 0 0 1 6 0V8',
  fire:'M12 21a6.5 6.5 0 0 1-6.5-6.5C5.5 10 8.5 7.5 12 3c0 3 1.5 5 3.5 6.5 2 1.5 3 3.5 3 5A6.5 6.5 0 0 1 12 21z',
  trash:'M4.5 7h15M9 7V4.5h6V7M7 7l1 13.5h8L17 7 M10 11v6M14 11v6'
};

function Icon({d, size=22, color='currentColor', strokeWidth=1.6, style}) {
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
    strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" style={style}>
    <path d={d}/>
  </svg>;
}

// ---- 基础组件 ----
function Money({v, size=28, color, serif=true, suffix=''}) {
  return <span style={{fontFamily: serif?SERIF:FONT, fontSize:size, fontWeight:serif?700:600,
    color, fontVariantNumeric:'tabular-nums', letterSpacing:serif?'-0.01em':'0'}}>
    {v}{suffix}</span>;
}

function Badge({tone, children, t}) {
  const map = {green:[t.fill,t.greenInk], gray:[t.fill,t.ink3], orange:[t.fill,t.warn], red:[t.surface,t.dangerText], blue:[t.fill,t.infoText]};
  const [bg,fg] = map[tone]||map.gray;
  return <span style={{background:bg, color:fg, fontSize:11, fontWeight:600, padding:'2px 7px', borderRadius:6, whiteSpace:'nowrap'}}>{children}</span>;
}

function Row({t, icon, iconColor, title, subtitle, value, valueColor, trailing, onClick, style}) {
  return <div onClick={onClick} style={{display:'flex', alignItems:'center', gap:10, padding:'10px 16px',
    background:'transparent', cursor:onClick?'pointer':'default', ...style}}>
    {icon && <Icon d={icon} size={20} color={iconColor||t.greenDeep} style={{flexShrink:0}}/>}
    <div style={{flex:1, minWidth:0}}>
      <div style={{fontSize:15, fontWeight:600, color:t.ink, lineHeight:1.25, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{title}</div>
      {subtitle && <div style={{fontSize:12.5, color:t.ink3, lineHeight:1.3, marginTop:1, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{subtitle}</div>}
    </div>
    {value && <div style={{fontSize:14, color:valueColor||t.ink3, fontWeight:600, whiteSpace:'nowrap'}}>{value}</div>}
    {trailing || (onClick && <Icon d={P.chevron} size={15} color={t.ink4}/>)}
  </div>;
}

function Section({t, title, children, style}) {
  return <div style={{margin:'14px 16px 0', ...style}}>
    {title && <div style={{fontSize:13, fontWeight:600, color:t.ink3, textTransform:'uppercase', letterSpacing:0.4, marginBottom:6}}>{title}</div>}
    <div style={{background:t.surface, borderRadius:12, overflow:'hidden'}}>{children}</div>
  </div>;
}

function Sep({t}) { return <div style={{height:1, background:t.sep, marginLeft:46}}/>; }

function EmptyState({t, icon, title, subtitle, style}) {
  return <div style={{padding:'28px 16px', textAlign:'center', color:t.ink3, ...style}}>
    <div style={{marginBottom:8}}><Icon d={icon} size={30} color={t.ink4} strokeWidth={1.2}/></div>
    <div style={{fontSize:16, fontWeight:600, color:t.ink2}}>{title}</div>
    {subtitle && <div style={{fontSize:13, marginTop:3}}>{subtitle}</div>}
  </div>;
}

function Segmented({t, options, value, onChange, style}) {
  return <div style={{display:'flex', background:t.fill, borderRadius:9, padding:2, margin:'0 16px', ...style}}>
    {options.map(o => <div key={o} onClick={()=>onChange(o)} style={{flex:1, textAlign:'center',
      padding:'9px 0', fontSize:13, fontWeight:600, borderRadius:7,
      background: value===o? t.surface : 'transparent',
      color: value===o? t.ink : t.ink3,
      boxShadow: value===o? '0 1px 2px rgba(0,0,0,0.08)' : 'none',
      cursor:'pointer'}}>{o}</div>)}
  </div>;
}

// 原生 TabBar（4 Tab 冻结 IA）
function TabBar({t, active, onChange}) {
  const tabs = [{k:'home', l:'首页', i:P.house},{k:'todo', l:'待办', i:P.checklist},{k:'calendar', l:'日历', i:P.calendar},{k:'biz', l:'经营', i:P.chart}];
  return <div style={{height:50, flexShrink:0, background:t.surface, borderTop:`0.5px solid ${t.sep}`,
    display:'flex', paddingBottom:2}}>
    {tabs.map(tb => <div key={tb.k} onClick={()=>onChange(tb.k)} style={{flex:1, display:'flex',
      flexDirection:'column', alignItems:'center', justifyContent:'center', gap:2, cursor:'pointer'}}>
      <Icon d={tb.i} size={22} color={active===tb.k? t.greenDeep : t.ink3}/>
      <div style={{fontSize:11, fontWeight:600, color:active===tb.k? t.greenInk : t.ink3}}>{tb.l}</div>
    </div>)}
  </div>;
}

// A 基因：收据式确认卡
function ReceiptCard({t, title, rows, amount, note, stamp, actions, onAction}) {
  return <div style={{background:t.paper, border:`1px solid ${t.hair}`, borderRadius:14,
    padding:'14px 16px 12px', position:'relative', marginTop:10, overflow:'hidden'}}>
    <div style={{position:'absolute', left:0, top:0, bottom:0, width:3, background:t.green}}/>
    <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
      <div style={{fontSize:13, fontWeight:700, color:t.ink2, letterSpacing:0.3}}>{title}</div>
      {stamp && <div data-deco="1" style={{border:`1.5px solid ${t.green}`, color:t.greenInk, fontSize:11, fontWeight:700,
        padding:'2px 6px', borderRadius:6, transform:'rotate(-8deg)', letterSpacing:1}}>{stamp}</div>}
    </div>
    {rows.map(r => <div key={r.k} style={{display:'flex', justifyContent:'space-between', gap:12, marginTop:8}}>
      <span style={{fontSize:13, color:t.ink3, flexShrink:0}}>{r.k}</span>
      <span style={{fontSize:13, color:t.ink, fontWeight:500, textAlign:'right'}}>{r.v}</span>
    </div>)}
    <div style={{borderTop:`1px dashed ${t.hair}`, margin:'10px -16px 0', padding:'8px 16px 0', display:'flex', justifyContent:'space-between', alignItems:'baseline'}}>
      <span style={{fontSize:12, color:t.ink3}}>合计</span>
      <Money v={amount} size={26} color={t.greenInk}/>
    </div>
    {note && <div style={{fontSize:12, color:t.ink3, marginTop:6}}>{note}</div>}
    {actions && <div style={{display:'flex', gap:8, marginTop:12}}>
      {actions.map(a => <div key={a.l} onClick={()=>onAction && onAction(a)} style={{flex:1, textAlign:'center',
        padding:'11px 0', borderRadius:10, fontSize:14, fontWeight:600, cursor:'pointer',
        background: a.primary? '#146B52' : 'transparent',
        color: a.primary? '#FFFFFF' : t.greenInk,
        border: a.primary? 'none' : `1px solid ${t.greenDeep}`}}>{a.l}</div>)}
    </div>}
  </div>;
}

// C 基因：语音球（同心环）
function VoiceOrb({t, size=120, active=false, onClick}) {
  const ring = (d) => ({position:'absolute', left:'50%', top:'50%', width:d, height:d, marginLeft:-d/2, marginTop:-d/2,
    borderRadius:'50%', border:`1px solid ${t.green}`, opacity:0.35});
  return <div onClick={onClick} data-deco="1" style={{position:'relative', width:size, height:size, cursor:onClick?'pointer':'default'}}>
    <div style={ring(size*2.1)}/><div style={ring(size*1.62)}/><div style={ring(size*1.2)}/>
    <div style={{position:'absolute', left:'50%', top:'50%', width:size, height:size, marginLeft:-size/2, marginTop:-size/2,
      borderRadius:'50%', background:'radial-gradient(circle at 34% 28%, #3FC98A 0%, #1FA971 52%, #146B52 100%)',
      display:'flex', alignItems:'center', justifyContent:'center',
      boxShadow:'0 12px 28px rgba(31,169,113,0.35)'}}>
      <Icon d={P.mic} size={size*0.34} color="#FFFFFF" strokeWidth={1.8}/>
    </div>
    {active && <div style={{position:'absolute', left:'50%', top:'50%', width:size+18, height:size+18,
      marginLeft:-(size+18)/2, marginTop:-(size+18)/2, borderRadius:'50%', border:`2px solid ${t.green}`,
      animation:'fusionPulse 1.6s ease-out infinite'}}/>}
    <style>{'@keyframes fusionPulse{0%{transform:scale(0.95);opacity:0.9}100%{transform:scale(1.25);opacity:0}}'}</style>
  </div>;
}

// 运行三步条（AI processing 可视化）
function RunStrip({t, steps, done}) {
  return <div style={{display:'flex', flexDirection:'column', gap:6, padding:'10px 12px',
    background:t.fill, borderRadius:12}}>
    {steps.map((s,i) => <div key={i} style={{display:'flex', alignItems:'center', gap:8, fontSize:12.5}}>
      <span style={{width:16, height:16, borderRadius:'50%', display:'flex', alignItems:'center', justifyContent:'center',
        background: i<done? '#146B52' : (i===done? t.fill : t.surface),
        color: i<done? '#fff' : (i===done? t.greenInk : t.ink3), fontSize:11, fontWeight:700, flexShrink:0}}>
        {i<done? '✓' : (i===done? '·' : i+1)}
      </span>
      <span style={{color: i<=done? t.ink2 : t.ink3, fontWeight: i===done? 600:400}}>{s}</span>
    </div>)}
  </div>;
}

// 页级手机外壳
function Phone({dark=false, scale=1, tag, tagNote, children, width=393, extra}) {
  const t = dark? T.dark : T.light;
  return <div data-phone style={{width:417*scale, flexShrink:0, position:'relative'}}>
    <div style={{transform:`scale(${scale})`, transformOrigin:'top left', width:417}}>
      <IosFrame width={393} height={852} time="9:41" battery={dark?58:85} darkMode={dark}>
        <div style={{height:764, background:t.page, color:t.ink, fontFamily:FONT, position:'relative',
          overflow:'hidden', display:'flex', flexDirection:'column', fontSize:15}}>
          {children}
        </div>
      </IosFrame>
    </div>
    {tag && <div style={{fontSize:11.5, fontWeight:700, color:'#161A18', marginTop:6, display:'flex', gap:6, alignItems:'center'}}>
      {tag}{tagNote && <span style={{fontWeight:400, color:'#5F646E'}}>{tagNote}</span>}
    </div>}
  </div>;
}

// 展示板外壳
function Board({no, title, note, children}) {
  return <div style={{minHeight:'100vh', background:'#E9EFEB', padding:'30px 28px', fontFamily:FONT, color:'#161A18'}}>
    <div style={{marginBottom:18}}>
      <div style={{fontSize:11, fontWeight:700, letterSpacing:2.5, color:'#146B52'}}>V4.0 FUSION · {no}</div>
      <div style={{fontSize:25, fontWeight:700, marginTop:4}}>{title}</div>
      {note && <div style={{fontSize:13, color:'#5F646E', marginTop:4, maxWidth:860}}>{note}</div>}
    </div>
    <div style={{display:'flex', gap:24, alignItems:'flex-start', flexWrap:'wrap'}}>{children}</div>
  </div>;
}

window.FusionKit = {T, FONT, SERIF, P, Icon, Money, Badge, Row, Section, Sep, EmptyState, Segmented, TabBar, ReceiptCard, VoiceOrb, RunStrip, Phone, Board};
