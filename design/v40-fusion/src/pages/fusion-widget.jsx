// fusion-widget.jsx — 「你的小掌柜」V4.0 融合设计 · 桌面小组件（中·中·小三卡横排 × Light/Dark）
const { T, FONT, P, Icon, Money, Badge, Board } = window.FusionKit;
const { useState } = window.React;

// 角标：显示名「小掌柜工作台」
function Corner({t}) {
  return (
    <div style={{display:'flex', alignItems:'center', gap:5, flexShrink:0}}>
      <Icon d={P.sparkles} size={12} color={t.greenDeep}/>
      <span style={{fontSize:11, color:t.ink3, fontWeight:600}}>小掌柜工作台</span>
    </div>
  );
}

// 中号「今日营业」· 点击切换 营业额 / 净额
function MediumStats({t}) {
  const [net, setNet] = useState(false);
  return (
    <div data-phone="1" onClick={()=>setNet(!net)} style={{width:329, height:155, boxSizing:'border-box',
      borderRadius:22, background:t.surface, padding:'12px 14px', cursor:'pointer',
      display:'flex', flexDirection:'column', fontFamily:FONT, color:t.ink}}>
      <div style={{display:'flex', alignItems:'center'}}>
        <Corner t={t}/>
        <span style={{flex:1}}/>
        <span style={{fontSize:11, color:t.ink3}}>{net? '点击返回营业额':'点击切换净额'}</span>
      </div>
      <div style={{flex:1, marginTop:4, display:'flex', gap:10, minHeight:0}}>
        <div style={{flex:1, minWidth:0, display:'flex', flexDirection:'column', justifyContent:'center'}}>
          <div style={{fontSize:12, color:t.ink3, lineHeight:'16px'}}>{net? '今日净额':'今日营业额'}</div>
          <div style={{lineHeight:'36px'}}><Money v={net? '¥2,260':'¥3,480'} size={28} color={t.ink}/></div>
          <div style={{display:'flex', alignItems:'center', gap:6}}>
            <Badge tone={net? 'gray':'green'} t={t}>{net? '支出 ¥1,220':'↑19% 较昨日'}</Badge>
            <span style={{fontSize:11, color:t.ink3}}>3 笔 · 待办 2</span>
          </div>
        </div>
        <div style={{width:118, flexShrink:0, display:'flex', flexDirection:'column', justifyContent:'center', gap:7}}>
          <div style={{display:'flex', alignItems:'center', gap:6}}>
            <span style={{width:10, height:10, borderRadius:5, border:`1.5px solid ${t.warn}`, flexShrink:0}}/>
            <span style={{fontSize:11, color:t.ink2, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>给 302 送怡宝</span>
          </div>
          <div style={{display:'flex', alignItems:'center', gap:6}}>
            <span style={{width:10, height:10, borderRadius:5, border:`1.5px solid ${t.greenDeep}`, flexShrink:0}}/>
            <span style={{fontSize:11, color:t.ink2, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>联系供应商</span>
          </div>
          <div style={{fontSize:11, color:t.ink3}}>下一件 15:00</div>
        </div>
      </div>
    </div>
  );
}

// 中号「待办」· 2 条 + 逾期 1，行点击勾选
function MediumTodo({t}) {
  const [done, setDone] = useState([false, false]);
  const ITEMS = [
    { txt:'给 302 送两箱怡宝', meta:'逾期 · 19:00', over:true },
    { txt:'联系饮料供应商', meta:'今天 15:00', over:false },
  ];
  return (
    <div data-phone="1" style={{width:329, height:155, boxSizing:'border-box', borderRadius:22,
      background:t.surface, padding:'12px 14px', display:'flex', flexDirection:'column', fontFamily:FONT, color:t.ink}}>
      <div style={{display:'flex', alignItems:'center'}}>
        <Corner t={t}/>
        <span style={{flex:1}}/>
        <span style={{fontSize:11, color:t.ink3}}>2 条 · 逾期 1 天</span>
      </div>
      <div style={{flex:1, marginTop:4, display:'flex', flexDirection:'column'}}>
        {ITEMS.map((it, i) => {
          const isDone = done[i];
          return (
            <div key={i} onClick={()=>{ const n=[...done]; n[i]=!n[i]; setDone(n); }}
              style={{flex:1, display:'flex', alignItems:'center', gap:8, cursor:'pointer', minHeight:38}}>
              <span style={{width:18, height:18, borderRadius:9, border:`1.5px solid ${it.over? t.warn : t.greenDeep}`,
                background: isDone? '#146B52' : 'transparent', display:'flex', alignItems:'center',
                justifyContent:'center', flexShrink:0}}>
                {isDone && <Icon d={P.check} size={11} color="#FFFFFF" strokeWidth={2.5}/>}
              </span>
              <span style={{flex:1, minWidth:0, fontSize:12.5, fontWeight:500,
                color: isDone? t.ink3 : t.ink, textDecoration: isDone? 'line-through':'none',
                overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{it.txt}</span>
              <span style={{fontSize:11, color: it.over? t.warn : t.ink3, whiteSpace:'nowrap'}}>{it.meta}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// 小号「快捷记录」· 点击记一笔
function SmallQuick({t}) {
  const [ok, setOk] = useState(false);
  return (
    <div data-phone="1" onClick={()=>setOk(!ok)} style={{width:155, height:155, boxSizing:'border-box',
      borderRadius:22, background:t.surface, padding:'12px', cursor:'pointer',
      display:'flex', flexDirection:'column', fontFamily:FONT, color:t.ink}}>
      <Corner t={t}/>
      <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:5}}>
        <div style={{width:52, height:52, borderRadius:26, background:'#146B52', display:'flex',
          alignItems:'center', justifyContent:'center', boxShadow:'0 6px 16px rgba(20,107,82,0.30)'}}>
          <Icon d={ok? P.check : P.plus} size={24} color="#FFFFFF" strokeWidth={2}/>
        </div>
        <div style={{fontSize:12.5, fontWeight:700, color:t.ink, lineHeight:'17px'}}>{ok? '已记一笔':'＋ 记一笔'}</div>
      </div>
      <div style={{display:'flex', justifyContent:'center', gap:8}}>
        <span style={{fontSize:11, color:t.ink3}}>{ok? '今日 4 笔':'今日 3 笔'}</span>
        <span style={{fontSize:11, color:t.ink3}}>{ok? '刚刚':'待办 2 件'}</span>
      </div>
    </div>
  );
}

function WidgetRow({dark, tag, tagNote}) {
  const t = dark? T.dark : T.light;
  return (
    <div>
      <div style={{fontSize:11.5, fontWeight:700, color:'#161A18', marginBottom:8}}>
        {tag}{tagNote && <span style={{fontWeight:400, color:'#5F646E', marginLeft:6}}>{tagNote}</span>}
      </div>
      <div style={{display:'flex', gap:16, alignItems:'flex-start'}}>
        <MediumStats t={t}/>
        <MediumTodo t={t}/>
        <SmallQuick t={t}/>
      </div>
    </div>
  );
}

window.FusionPage = function App() {
  return (
    <React.Fragment>
      <Board no="13" title="小组件 Widget" note="iOS 桌面小组件 · 显示名「小掌柜工作台」· 中号今日营业点击切换 营业额/净额 · 待办行可勾选">
        <div style={{display:'flex', flexDirection:'column', gap:28}}>
          <WidgetRow dark={false} tag="Light · 小组件" tagNote="中 · 中 · 小"/>
          <WidgetRow dark={true}  tag="Dark · 小组件"  tagNote="中 · 中 · 小"/>
        </div>
      </Board>
    </React.Fragment>
  );
};
