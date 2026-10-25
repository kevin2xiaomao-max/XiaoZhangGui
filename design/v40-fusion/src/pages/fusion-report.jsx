// fusion-report.jsx — 「你的小掌柜」V4.0 融合设计 · 今日经营日报（A 基因主打：衬线金额 + 发丝线）
const { T, FONT, SERIF, P, Icon, Money, Badge, Phone, Board } = window.FusionKit;
const { useState } = window.React;

const CSS = `
@keyframes fadeIn { from { opacity:0 } to { opacity:1 } }
`;

const CHANNELS = [
  { n:'门店', p:62, v:'¥2,150', c:'ink' },
  { n:'美团', p:32, v:'¥1,120', c:'green' },
  { n:'其他', p:6,  v:'¥210',   c:'gray' },
];

const SLOTS = [
  { l:'早市', range:'06-10时', val:920 },
  { l:'午市', range:'10-14时', val:1180 },
  { l:'晚市', range:'14-19时', val:980 },
  { l:'夜市', range:'19-24时', val:400 },
];
const SLOT_MAX = 1180;

function Screen({spec}) {
  const t = spec.dark ? T.dark : T.light;
  const [shared, setShared] = useState(!!spec.shared);
  const [slot, setSlot] = useState(spec.slot ?? 0);
  const s = SLOTS[slot];
  return (
    <div style={{flex:1, minHeight:0, overflow:'hidden', display:'flex', flexDirection:'column', position:'relative'}}>
      {/* 日期头 */}
      <div style={{display:'flex', alignItems:'flex-end', justifyContent:'space-between', padding:'12px 16px 2px'}}>
        <div>
          <div style={{fontFamily:SERIF, fontSize:26, fontWeight:700, color:t.ink, lineHeight:'32px'}}>10月25日 周日</div>
          <div style={{fontSize:12, color:t.ink3, lineHeight:'17px', marginTop:2}}>今日经营日报 · 营业时段 06:00 – 24:00</div>
        </div>
        <div data-deco="1" style={{border:`1.5px solid ${t.green}`, color:t.greenInk, fontSize:11, fontWeight:700,
          padding:'3px 7px', borderRadius:6, transform:'rotate(-8deg)', letterSpacing:1, marginBottom:2}}>今日日报</div>
      </div>
      {/* 总览 Hero（收据质感） */}
      <div style={{margin:'12px 16px 0', background:t.paper, border:`1px solid ${t.hair}`, borderRadius:14,
        padding:'14px 16px 12px', position:'relative', overflow:'hidden'}}>
        <div data-deco="1" style={{position:'absolute', left:0, top:0, bottom:0, width:3, background:t.green}}/>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
          <span style={{fontSize:13, color:t.ink3}}>今日营业额</span>
          <Badge tone="green" t={t}>↑19% 较昨日</Badge>
        </div>
        <div style={{lineHeight:'50px', marginTop:2}}><Money v="¥3,480" size={38} color={t.ink}/></div>
        <div style={{borderTop:`1px dashed ${t.hair}`, margin:'2px -16px 0', padding:'10px 16px 0', display:'flex', gap:10}}>
          <div style={{flex:1}}>
            <div style={{fontSize:12, color:t.ink3, lineHeight:'16px'}}>支出</div>
            <Money v="¥1,220" size={18} color={t.ink2}/>
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:12, color:t.ink3, lineHeight:'16px'}}>净额</div>
            <Money v="¥2,260" size={18} color={t.greenInk}/>
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:12, color:t.ink3, lineHeight:'16px'}}>本日 3 笔</div>
            <div style={{lineHeight:'26px'}}><Money v="¥1,160" size={13} color={t.ink2}/></div>
          </div>
        </div>
      </div>
      {/* 渠道明细 */}
      <div style={{margin:'12px 16px 0', background:t.surface, borderRadius:12, padding:'12px 16px 10px'}}>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:2}}>
          <span style={{fontSize:14, fontWeight:700, color:t.ink}}>渠道明细</span>
          <span style={{fontSize:12, color:t.ink3}}>合计 <Money v="¥3,480" size={12} serif={false} color={t.ink}/></span>
        </div>
        {CHANNELS.map((c) => (
          <div key={c.n}>
            <div style={{display:'flex', alignItems:'baseline', padding:'9px 0 6px'}}>
              <span style={{fontSize:14, color:t.ink, fontWeight:600, width:44}}>{c.n}</span>
              <span style={{fontSize:11, color:t.ink3, flex:1}}>占 {c.p}%</span>
              <Money v={c.v} size={17} color={t.ink}/>
            </div>
            <div style={{height:4, background:t.fill, borderRadius:2, overflow:'hidden'}}>
              <div data-deco="1" style={{width:c.p+'%', height:4, borderRadius:2,
                background: c.c==='ink'? t.greenInk : c.c==='green'? t.green : t.ink4}}/>
            </div>
          </div>
        ))}
      </div>
      {/* 今日时段趋势 */}
      <div style={{margin:'12px 16px 0', background:t.surface, borderRadius:12, padding:'12px 16px 10px'}}>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
          <span style={{fontSize:14, fontWeight:700, color:t.ink}}>今日时段趋势</span>
          <span style={{fontSize:12, color:t.ink3}}>共 <Money v="¥3,480" size={12} serif={false} color={t.ink}/></span>
        </div>
        <div style={{fontSize:11, color:t.greenInk, fontWeight:600, marginTop:4, lineHeight:'15px'}}>
          {s.l} {s.range} · <Money v={'¥'+s.val.toLocaleString()} size={11} serif={false} color={t.greenInk}/>
        </div>
        <div style={{display:'flex', gap:8, height:118, marginTop:2}}>
          {SLOTS.map((sl, i) => {
            const h = Math.round(sl.val / SLOT_MAX * 76);
            const sel = i === slot;
            return (
              <div key={sl.l} onClick={()=>setSlot(i)} style={{flex:1, position:'relative', height:118, cursor:'pointer'}}>
                <div style={{position:'absolute', top:0, left:0, right:0, textAlign:'center', lineHeight:'15px'}}>
                  <Money v={'¥'+sl.val.toLocaleString()} size={11} serif={false}
                    color={sel? t.greenInk : t.ink3}/>
                </div>
                <div data-deco="1" style={{position:'absolute', bottom:20, left:'50%', transform:'translateX(-50%)',
                  width:26, height:h, borderRadius:'6px 6px 2px 2px',
                  background: sel? t.greenInk : t.greenTint, transition:'height 0.35s, background 0.2s'}}/>
                <div style={{position:'absolute', bottom:0, left:0, right:0, textAlign:'center', fontSize:11, color:t.ink3, lineHeight:'15px'}}>{sl.l}</div>
              </div>
            );
          })}
        </div>
      </div>
      <div style={{flex:1}}/>
      {/* 分享（点击 → 已生成分享图 状态行） */}
      {shared ? (
        <div style={{margin:'14px 16px 6px', height:46, background:t.fill, borderRadius:12,
          display:'flex', alignItems:'center', justifyContent:'center', gap:6, animation:'fadeIn 0.18s ease'}}>
          <Icon d={P.check} size={15} color={t.greenInk} strokeWidth={2}/>
          <span style={{fontSize:13, fontWeight:700, color:t.greenInk}}>已生成分享图 · 已保存到相册</span>
        </div>
      ) : (
        <button onClick={()=>setShared(true)} style={{margin:'14px 16px 6px', height:46, border:'none', borderRadius:12,
          background:t.warn, color: t===T.light ? '#FFFFFF' : T.light.ink, fontSize:15, fontWeight:700,
          cursor:'pointer', fontFamily:FONT, transition:'background 0.2s'}}>分享今日日报</button>
      )}
    </div>
  );
}

const PHONES = [
  { dark:false, scale:1.2,  tag:'Light · 主视图',     note:'日期头 · Hero · 渠道 · 时段', shared:false, slot:0 },
  { dark:true,  scale:1.08, tag:'Dark · 深色',        note:'衬线金额与发丝线',           shared:false, slot:2 },
  { dark:false, scale:1,    tag:'Light · 分享完成',   note:'分享后状态行',               shared:true,  slot:0 },
  { dark:false, scale:1,    tag:'Light · 时段选中',   note:'午市 10-14时 读数',          shared:false, slot:1 },
  { dark:false, scale:0.92, tag:'Light · 0.92× 小屏', note:'小屏点按与字号底线',         shared:false, slot:0 },
];

window.FusionPage = function App() {
  return (
    <React.Fragment>
      <style>{CSS}</style>
      <Board no="11" title="今日经营日报" note="V3.9.2 · 今日营业额 ¥3,480 ↑19% · 渠道占比与时段趋势 · 分享日报">
        {PHONES.map((s, i) => (
          <Phone key={i} dark={s.dark} scale={s.scale} tag={s.tag} tagNote={s.note}>
            <Screen spec={s}/>
          </Phone>
        ))}
      </Board>
    </React.Fragment>
  );
};
