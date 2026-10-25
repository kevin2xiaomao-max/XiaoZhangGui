// fusion-ai.jsx — 第 2 页：AI 对话（B 导航与输入条 70% + C 留白/语音球 10% + A 收据确认卡 20%）
const {T, FONT, P, Icon, Money, Badge, Row, Section, Sep, EmptyState, Segmented, TabBar, ReceiptCard, VoiceOrb, RunStrip, Phone, Board} = window.FusionKit;

function AIScreen({t, mode='idle', onSend, status, onConfirm, onDismiss}) {
  const [text, setText] = React.useState('');
  const examples = [
    {l:'今天美团680', s:'记录营业额'},
    {l:'明天下两箱可乐', s:'新建待办'},
    {l:'记一下供应商周五来', s:'新建备忘'},
    {l:'今晚8点给302送两箱怡宝', s:'新建配送'}
  ];
  const steps = ['读取今日营业额：3 笔，共 ¥3,480', '匹配渠道「美团」历史 12 笔', '生成确认卡，等你确认'];
  const done = status==='done'? 3 : (status==='pending'? 3 : (status==='running'? 1 : 0));

  return <div style={{display:'flex', flexDirection:'column', height:'100%'}}>
    {/* 导航条（sheet 形态：小标题 + 菜单） */}
    <div style={{height:44, display:'flex', alignItems:'center', justifyContent:'center', position:'relative',
      borderBottom:`0.5px solid ${t.sep}`, flexShrink:0, background:t.nav, backdropFilter:'blur(14px)'}}>
      <div style={{fontSize:16, fontWeight:700}}>小掌柜</div>
      <div style={{position:'absolute', right:14, display:'flex', gap:14, alignItems:'center'}}>
        <Icon d={P.sparkles} size={19} color={t.greenDeep}/>
        <Icon d={P.gear} size={19} color={t.ink3}/>
      </div>
    </div>

    {/* 头部说明 + 状态徽标 + 当日摘要（高密度差异化信息） */}
    <div style={{padding:'10px 16px 4px', flexShrink:0, display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap:8}}>
      <div>
        <div style={{fontSize:12.5, color:t.ink3}}>说句话，帮你记账、派单、备忘</div>
        <div style={{marginTop:6, display:'flex', gap:6}}>
          <Badge tone="green" t={t}>Key 已保存</Badge>
          <Badge tone="gray" t={t}>本地模式</Badge>
        </div>
      </div>
      <div style={{textAlign:'right', paddingTop:2}}>
        <div style={{fontSize:13, fontWeight:700, color:t.greenInk, fontVariantNumeric:'tabular-nums'}}>今日 ¥3,480</div>
        <div style={{fontSize:11.5, color:t.ink3, marginTop:1}}>3 笔 · 待办 2</div>
      </div>
    </div>

    {/* 对话区 */}
    <div style={{flex:1, overflow:'hidden', padding:'8px 16px 0'}}>
      {status==='idle' ? <div style={{textAlign:'center', paddingTop:34}}>
        <Icon d={P.sparkles} size={30} color={t.greenDeep} style={{opacity:0.9}}/>
        <div style={{fontSize:19, fontWeight:700, marginTop:10}}>我是小掌柜</div>
        <div style={{fontSize:13, color:t.ink3, marginTop:6, lineHeight:1.5, maxWidth:300, margin:'6px auto 0'}}>
          说句话或点个例子，我先整理成确认卡，你确认后才记录。
        </div>
        <div style={{fontSize:12, color:t.ink3, marginTop:18, letterSpacing:1}}>试试这样说</div>
        <div style={{display:'flex', flexWrap:'wrap', gap:8, justifyContent:'center', marginTop:8}}>
          {examples.map(e => <div key={e.l} onClick={()=>onSend && onSend(e.l)} style={{padding:'10px 13px',
            background:t.fill, borderRadius:18, fontSize:13, color:t.ink2, cursor:'pointer',
            border:`0.5px solid ${t.sep}`}}>{e.l}</div>)}
        </div>
        <div style={{marginTop:20, display:'flex', flexDirection:'column', alignItems:'center', gap:8}}>
          <VoiceOrb t={t} size={88} active={false} onClick={onSend && (()=>onSend('voice'))}/>
          <div style={{fontSize:12, color:t.ink3}}>也可以按住说话</div>
        </div>
      </div> : <div>
        {/* 用户气泡 */}
        <div style={{display:'flex', justifyContent:'flex-end'}}>
          <div style={{background:t.bubble, color:t.bubbleInk, padding:'9px 13px', borderRadius:17,
            borderBottomRightRadius:5, fontSize:14, maxWidth:280}}>{text}</div>
        </div>
        {/* 助手 */}
        <div style={{display:'flex', gap:8, marginTop:10}}>
          <div style={{width:26, height:26, borderRadius:8, background:t.fill, color:t.greenInk,
            display:'flex', alignItems:'center', justifyContent:'center', fontSize:12, fontWeight:700, flexShrink:0}}>掌</div>
          <div style={{flex:1, maxWidth:300}}>
            {status==='running' && <RunStrip t={t} steps={steps} done={1}/>}
            {status==='pending' && <div>
              <RunStrip t={t} steps={steps} done={3}/>
              <ReceiptCard t={t} title="确认记录 · 营业收入"
                rows={[
                  {k:'渠道', v:'美团'},
                  {k:'日期', v:'10月25日 · 本日第 3 笔'},
                  {k:'写入位置', v:'营业 · 今日营业额'}
                ]}
                amount="¥680.00"
                note="上一笔美团：10月18日 ¥660。今天多 ¥20。"
                actions={[{l:'确认记录', primary:true},{l:'修改'},{l:'不记录'}]}
                onAction={(a)=>{ if(a.l==='确认记录') onConfirm&&onConfirm(); else onDismiss&&onDismiss(); }}/>
            </div>}
            {status==='done' && <div>
              <ReceiptCard t={t} title="营业收入 · 美团" stamp="已 记"
                rows={[
                  {k:'渠道', v:'美团'},
                  {k:'日期', v:'10月25日 12:04'},
                  {k:'写入位置', v:'营业 · 今日营业额'}
                ]}
                amount="¥680.00"
                note="✓ 已确认，写入完成。今日累计更新为 ¥4,160（4 笔）。"/>
            </div>}
          </div>
        </div>
      </div>}
    </div>

    {/* 输入条（material，44pt 点按区） */}
    <div style={{flexShrink:0, padding:'6px 12px 10px', background:t.nav, backdropFilter:'blur(14px)'}}>
      <div style={{display:'flex', alignItems:'center', gap:2, background:t.fill, borderRadius:26,
        border:`0.5px solid ${t.sep}`, padding:'3px 8px'}}>
        <div style={{width:40, height:40, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
          <Icon d={P.plus} size={21} color={t.ink3}/>
        </div>
        <div style={{width:40, height:40, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
          <Icon d={P.mic} size={21} color={t.greenDeep}/>
        </div>
        <div style={{flex:1, fontSize:14, color:t.ink3, padding:'0 6px'}}>问小掌柜…</div>
        <div style={{width:40, height:40, display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
          <div style={{width:27, height:27, borderRadius:'50%', background:'#146B52', color:'#fff',
            display:'flex', alignItems:'center', justifyContent:'center'}}>
            <Icon d={P.arrowUpRight} size={15} strokeWidth={2}/>
          </div>
        </div>
      </div>
    </div>
  </div>;
}

function AIPhone({dark, tag, note, mode}) {
  const t = dark? T.dark : T.light;
  const [status, setStatus] = React.useState(mode==='pending'? 'pending' : mode==='done'? 'done' : 'idle');
  const [txt, setTxt] = React.useState(mode==='pending'||mode==='done' ? '今天美团680' : '');
  const send = (x) => {
    setTxt(x);
    setStatus('running');
    setTimeout(()=>setStatus('pending'), 1150);
  };
  return <Phone dark={dark} tag={tag} tagNote={note}>
    <AIScreen t={t} status={status} text={txt} onSend={send} onConfirm={()=>setStatus('done')} onDismiss={()=>{setStatus('idle'); setTxt('');}}/>
  </Phone>;
}

function VoicePhone({tag, note}) {
  const t = T.light;
  const [rec, setRec] = React.useState(true);
  return <Phone tag={tag} tagNote={note}>
    <div style={{display:'flex', flexDirection:'column', height:'100%', alignItems:'center', justifyContent:'center', gap:26, padding:'0 28px'}}>
      <div style={{fontSize:12.5, fontWeight:700, letterSpacing:2, color:t.ink3}}>正在听 · 00:04</div>
      <div style={{fontSize:24, fontWeight:600, lineHeight:1.35, textAlign:'center'}}>今天美团……<br/>六百八十</div>
      <div style={{fontSize:12, color:t.ink3}}>第 3 笔 · 识别为 营业收入</div>
      <div style={{fontSize:12, color:t.ink3}}>金额 ¥680 · 写入 营业 · 今日营业额</div>
      <VoiceOrb t={t} size={116} active={rec}/>
      <div style={{display:'flex', gap:20, alignItems:'center'}}>
        <div style={{fontSize:13, color:'#D03028', fontWeight:600, cursor:'pointer', padding:'10px 14px'}}>取消</div>
        <div onClick={()=>setRec(false)} style={{width:54, height:54, borderRadius:'50%', background:'#146B52', color:'#fff',
          display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
          <Icon d={P.check} size={24}/>
        </div>
      </div>
      <div style={{fontSize:12, color:t.ink3, textAlign:'center'}}>说完点确认，我先整理成确认卡</div>
    </div>
  </Phone>;
}

function App() {
  return <Board no="AI 对话" title="问小掌柜 · 对话即记录"
    note="B：sheet 导航、material 输入条、运行三步（70%）。C：留白 + 品牌绿语音球 + 按住说话（10%）。A：确认卡收据化——发丝虚线、衬线金额、印章「已记」（20%）。点击例子可跑通 空态→处理中→确认卡→已记。">
    <AIPhone tag="AI 对话 · Light" note="空态 + 例子 + 语音球"/>
    <AIPhone dark tag="AI 对话 · Dark" note="暗色语义色 AA 达标"/>
    <AIPhone mode="pending" tag="确认卡态" note="点例子 → 运行三步 → 收据式确认卡"/>
    <AIPhone mode="done" tag="已记录态" note="确认后 → 印章「已记」"/>
    <VoicePhone tag="语音输入态" note="C 基因：实时转写大字"/>
  </Board>;
}

window.FusionPage = App;
