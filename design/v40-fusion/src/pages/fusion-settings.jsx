// fusion-settings.jsx — 「你的小掌柜」V4.0 融合设计 · 设置 / 我的（B 分组列表 + Editorial 头像头）
const { T, FONT, SERIF, P, Icon, Row, Section, Sep, Phone, Board } = window.FusionKit;
const { useState, useEffect } = window.React;

const CSS = `
@keyframes fadeIn { from { opacity:0 } to { opacity:1 } }
@keyframes sheetIn { from { opacity:0; transform: translateY(26px) } to { opacity:1; transform:none } }
`;

// iOS 开关（视觉，行整体为点按目标 ≥44px）
function Switch({on}) {
  return (
    <span style={{width:46, height:28, borderRadius:14, background: on? '#146B52' : 'rgba(120,120,128,0.32)',
      position:'relative', flexShrink:0, display:'inline-block', transition:'background 0.2s'}}>
      <span style={{position:'absolute', top:2, left: on? 20:2, width:24, height:24, borderRadius:12,
        background:'#FFFFFF', boxShadow:'0 1px 3px rgba(0,0,0,0.25)', transition:'left 0.2s'}}/>
    </span>
  );
}

// 外观模式三段切换（min 42px 高，0.92× 后仍 ≥38）
const MODES = ['跟随系统','浅色','深色'];
function Seg3({t, value, onChange}) {
  return (
    <div style={{display:'flex', background:t.fill, borderRadius:10, padding:3, margin:'0 12px 10px'}}>
      {MODES.map(o => (
        <div key={o} onClick={()=>onChange(o)} style={{flex:1, textAlign:'center', padding:'11px 4px',
          fontSize:13, fontWeight:600, lineHeight:'20px', borderRadius:8,
          background: value===o? t.surface : 'transparent',
          color: value===o? t.ink : t.ink3,
          boxShadow: value===o? '0 1px 3px rgba(0,0,0,0.10)' : 'none',
          cursor:'pointer', transition:'background 0.18s, color 0.18s'}}>{o}</div>
      ))}
    </div>
  );
}

// 恢复备份 bottom sheet
function RestoreSheet({t, onClose, onConfirm}) {
  return (
    <div style={{position:'absolute', inset:0, zIndex:60, display:'flex', alignItems:'flex-end'}}>
      <div data-deco="1" style={{position:'absolute', inset:0, background:t.hero, opacity:0.62, animation:'fadeIn 0.2s ease'}}/>
      <div style={{position:'relative', width:'100%', background:t.surface, borderRadius:'20px 20px 0 0',
        padding:'16px 16px 18px', animation:'sheetIn 0.25s ease'}}>
        <div style={{display:'flex', alignItems:'center'}}>
          <span style={{fontSize:17, fontWeight:700, color:t.ink}}>恢复备份</span>
          <span style={{flex:1}}/>
          <span onClick={onClose} style={{width:38, height:38, display:'flex', alignItems:'center',
            justifyContent:'center', fontSize:15, color:t.ink3, cursor:'pointer'}}>✕</span>
        </div>
        <div style={{fontSize:12, color:t.ink3, marginTop:6, lineHeight:'17px'}}>备份文件 · 2026-10-24 备份.json</div>
        <div style={{marginTop:12, background:t.fill, borderRadius:10, padding:'12px 14px', fontSize:13, color:t.ink2, lineHeight:'19px'}}>
          恢复为追加合并，不会删除现有数据
        </div>
        <div style={{fontSize:12, color:t.ink3, marginTop:8, lineHeight:'17px'}}>预计新增 12 条 · 已存在跳过 3 条</div>
        <div style={{display:'flex', gap:10, marginTop:14}}>
          <div onClick={onClose} style={{flex:1, textAlign:'center', padding:'12px 0', borderRadius:12,
            fontSize:14, fontWeight:600, color:t.ink, background:t.fill, cursor:'pointer'}}>取消</div>
          <div onClick={onConfirm} style={{flex:1, textAlign:'center', padding:'12px 0', borderRadius:12,
            fontSize:14, fontWeight:700, color:'#FFFFFF', background:'#146B52', cursor:'pointer'}}>开始恢复</div>
        </div>
      </div>
    </div>
  );
}

function Screen({spec}) {
  const t = spec.dark ? T.dark : T.light;
  const [morning, setMorning] = useState(!!spec.morning);
  const [weekly, setWeekly] = useState(!!spec.weekly);
  const [mode, setMode] = useState(spec.mode || '跟随系统');
  const [notice, setNotice] = useState(spec.notice || null);
  const [sheet, setSheet] = useState(!!spec.sheet);
  const [toast, setToast] = useState(null);
  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(()=>setToast(null), 1800);
    return ()=>clearTimeout(id);
  }, [toast]);
  const onMorning = () => {
    setMorning(!morning);
    setNotice(!morning ? '已开启每日晨报提醒 · 每天 8:00' : '已关闭每日晨报提醒 · 不会在 8:00 提醒');
  };
  const onWeekly = () => {
    setWeekly(!weekly);
    setNotice(!weekly ? '已开启每周备份提醒 · 周一 10:00' : '已关闭每周备份提醒 · 上次备份 10月24日');
  };
  const ok = notice && notice.startsWith('已开启');
  return (
    <div style={{flex:1, minHeight:0, overflow:'hidden', display:'flex', flexDirection:'column', position:'relative'}}>
      {/* 顶栏 */}
      <div style={{display:'flex', alignItems:'center', padding:'6px 8px 2px', flexShrink:0}}>
        <div onClick={()=>setToast('已返回首页（原型演示）')} style={{width:44, height:44, display:'flex',
          alignItems:'center', justifyContent:'center', cursor:'pointer', transform:'scaleX(-1)'}}>
          <Icon d={P.chevron} size={20} color={t.greenDeep}/>
        </div>
        <div style={{flex:1, textAlign:'center', fontSize:17, fontWeight:700, color:t.ink}}>我的</div>
        <div style={{width:44}}/>
      </div>
      {/* Editorial 头像头 */}
      <div style={{display:'flex', alignItems:'center', gap:14, padding:'10px 20px 14px', flexShrink:0}}>
        <div style={{width:64, height:64, borderRadius:32, background:t.greenTint, border:`1px solid ${t.hair}`,
          display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0}}>
          <Icon d={P.person} size={30} color={t.greenDeep}/>
        </div>
        <div>
          <div style={{fontFamily:SERIF, fontSize:23, fontWeight:700, color:t.ink, lineHeight:'30px'}}>你的小掌柜</div>
          <div style={{fontSize:12, color:t.ink3, lineHeight:'17px', marginTop:2}}>V3.9.2 (41) · 已使用 248 天</div>
        </div>
      </div>
      {/* 分组 1 · 提醒 */}
      <Section t={t} title="提醒" style={{margin:'2px 16px 0'}}>
        <Row t={t} icon={P.bell} title="每日晨报提醒" subtitle={morning? '每天 8:00' : '已关闭'}
          trailing={<Switch on={morning}/>} onClick={onMorning} style={{paddingTop:12, paddingBottom:12}}/>
        <Sep t={t}/>
        <Row t={t} icon={P.calendar} title="每周备份提醒" subtitle={weekly? '周一 10:00' : '已关闭 · 上次 10月24日'}
          trailing={<Switch on={weekly}/>} onClick={onWeekly} style={{paddingTop:12, paddingBottom:12}}/>
      </Section>
      {notice && (
        <div style={{margin:'8px 16px 0', display:'flex', alignItems:'center', gap:6, fontSize:12, lineHeight:'17px',
          color: ok? t.greenInk : t.ink3}}>
          <Icon d={ok? P.check : P.xmark} size={13} color={ok? t.greenInk : t.ink3}/>
          {notice}
        </div>
      )}
      {/* 分组 2 · 外观 */}
      <Section t={t} title="外观" style={{margin:'12px 16px 0'}}>
        <Row t={t} icon={P.sun} title="外观模式" value={mode}/>
        <Seg3 t={t} value={mode} onChange={(m)=>{ setMode(m); setToast('已切换「'+m+'」外观（原型演示）'); }}/>
        <Sep t={t}/>
        <Row t={t} icon={P.sparkles} title="强调色"
          trailing={<span style={{display:'flex', alignItems:'center', gap:6}}>
            <span style={{width:16, height:16, borderRadius:8, background:'#1FA971', flexShrink:0}}/>
            <span style={{fontSize:12, color:t.ink3}}>品牌绿 #1FA971</span>
          </span>}/>
      </Section>
      {/* 分组 3 · 数据 */}
      <Section t={t} title="数据" style={{margin:'12px 16px 0'}}>
        <Row t={t} icon={P.cube} title="数据备份" value="10月24日 已备份" onClick={()=>setToast('已导出备份文件（原型演示）')} style={{paddingTop:12, paddingBottom:12}}/>
        <Sep t={t}/>
        <Row t={t} icon={P.clock} title="恢复备份" value="先预览" valueColor={t.greenInk} onClick={()=>setSheet(true)} style={{paddingTop:12, paddingBottom:12}}/>
      </Section>
      {/* 分组 4 · 关于 */}
      <Section t={t} title="关于" style={{margin:'12px 16px 0'}}>
        <Row t={t} icon={P.gear} title="版本" value="V3.9.2 (41)"/>
        <Sep t={t}/>
        <Row t={t} icon={P.doc} title="隐私说明" onClick={()=>setToast('隐私说明（原型演示）')} style={{paddingTop:12, paddingBottom:12}}/>
      </Section>
      <div style={{flex:1}}/>
      <div style={{textAlign:'center', fontSize:11, color:t.ink3, padding:'10px 0 8px'}}>你的小掌柜 V4.0 · 融合原型</div>
      {sheet && <RestoreSheet t={t} onClose={()=>setSheet(false)}
        onConfirm={()=>{ setSheet(false); setToast('已恢复 12 条记录（原型演示）'); }}/>}
      {toast && (
        <div data-deco="1" style={{position:'absolute', left:14, right:14, bottom:16, zIndex:70, background:t.surface,
          border:`1px solid ${t.hair}`, borderRadius:10, padding:'9px 12px', fontSize:12, color:t.ink,
          textAlign:'center', boxShadow:'0 6px 18px rgba(0,0,0,0.16)', animation:'fadeIn 0.18s ease'}}>{toast}</div>
      )}
    </div>
  );
}

const PHONES = [
  { dark:false, scale:1.2,  tag:'Light · 主视图',   note:'Editorial 头像头 + 分组列表',  morning:true,  weekly:true,  mode:'跟随系统', sheet:false, notice:null },
  { dark:true,  scale:1.08, tag:'Dark · 深色外观',  note:'深色 token · 开关与分组',      morning:true,  weekly:true,  mode:'深色',     sheet:false, notice:null },
  { dark:false, scale:1,    tag:'Light · 恢复预览', note:'恢复为追加合并，不会删除现有数据', morning:true, weekly:true, mode:'跟随系统', sheet:true,  notice:null },
  { dark:false, scale:1,    tag:'Light · 提醒开关', note:'每周备份已关闭 · 状态行反馈',  morning:true,  weekly:false, mode:'浅色',     sheet:false, notice:'已关闭每周备份提醒 · 上次备份 10月24日' },
  { dark:false, scale:0.92, tag:'Light · 0.92×',    note:'小屏点按与字号底线',          morning:true,  weekly:true,  mode:'跟随系统', sheet:false, notice:null },
];

window.FusionPage = function App() {
  return (
    <React.Fragment>
      <style>{CSS}</style>
      <Board no="12" title="设置 · 我的" note="V3.9.2 (41) · 每日晨报 8:00 / 每周备份 周一 10:00 · 恢复为追加合并">
        {PHONES.map((s, i) => (
          <Phone key={i} dark={s.dark} scale={s.scale} tag={s.tag} tagNote={s.note}>
            <Screen spec={s}/>
          </Phone>
        ))}
      </Board>
    </React.Fragment>
  );
};
