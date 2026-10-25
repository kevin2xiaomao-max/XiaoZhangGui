// fusion-voice.jsx — 「你的小掌柜」iOS V4.0 融合设计 · 语音记账（C 基因主打 + A 收据确认）
// 状态机 idle → recording → transcribing → confirm → done；依据 00-page-inventory.md §3
const { T, FONT, SERIF, P, Icon, RunStrip, ReceiptCard, VoiceOrb, Phone, Board } = window.FusionKit;
const { useState, useEffect } = window.React;

const CSS = `
@keyframes vmWave { 0%,100% { transform: scaleY(0.35) } 50% { transform: scaleY(1) } }
@keyframes vmSheetUp { from { opacity: 0; transform: translateY(24px) } to { opacity: 1; transform: none } }
`;

// 聆听区：15 根波形
const BARS = [6, 10, 14, 9, 16, 12, 20, 14, 22, 16, 12, 18, 10, 15, 7];
function Wave({ t }) {
  return (
    <div data-deco="1" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4, height: 40 }}>
      {BARS.map((h, i) => (
        <div key={i} data-deco="1" style={{ width: 3, height: h, borderRadius: 2, background: t.green,
          opacity: 0.7, transformOrigin: 'center', animation: `vmWave ${0.9 + (i % 5) * 0.12}s ease-in-out ${i * 0.06}s infinite` }}/>
      ))}
    </div>
  );
}

// 大字转写：金额用 A 基因衬线
function Transcript({ t }) {
  return (
    <div style={{ fontSize: 24, fontWeight: 700, color: t.ink, lineHeight: '34px', padding: '0 24px', textAlign: 'center' }}>
      今天美团<span style={{ color: t.ink3 }}>……</span>
      <span style={{ fontFamily: SERIF, color: t.greenInk }}>六百八十</span>
    </div>
  );
}

// 转写下方的三枚信息 chip（密度点：金额 / 日期 / 时间，独立元素）
function MetaChips({ t, time }) {
  return (
    <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginTop: 12, flexWrap: 'wrap' }}>
      <span style={{ fontSize: 12, fontWeight: 700, color: t.greenInk, fontFamily: SERIF, background: t.surface, borderRadius: 6, padding: '4px 8px' }}>¥680.00</span>
      <span style={{ fontSize: 12, color: t.ink3, background: t.surface, borderRadius: 6, padding: '4px 8px' }}>今天 10月25日</span>
      <span style={{ fontSize: 12, color: t.ink3, background: t.surface, borderRadius: 6, padding: '4px 8px', fontVariantNumeric: 'tabular-nums' }}>{time}</span>
    </div>
  );
}

const SUBTITLES = {
  idle: '点击麦克风开始', recording: '正在听…', transcribing: '正在整理…',
  confirm: '请确认将保存的内容', done: '已记录',
};

function Screen({ spec, st, setSt }) {
  const t = spec.dark ? T.dark : T.light;
  return (
    <div style={{ flex: 1, minHeight: 0, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      {/* 顶栏：语音记账 + 状态副标题 + 关闭 */}
      <div style={{ display: 'flex', alignItems: 'center', padding: '10px 12px 8px 16px' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 17, fontWeight: 700, color: t.ink, lineHeight: '22px' }}>语音记账</div>
          <div style={{ fontSize: 12, color: st === 'done' ? t.greenInk : t.ink3, lineHeight: '16px', marginTop: 1 }}>{SUBTITLES[st]}</div>
        </div>
        <div onClick={() => setSt('idle')} style={{ width: 42, height: 42, flexShrink: 0, display: 'flex',
          alignItems: 'center', justifyContent: 'center', cursor: 'pointer', borderRadius: 10 }}>
          <Icon d={P.xmark} size={20} color={t.ink3}/>
        </div>
      </div>

      {st === 'idle' && (
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', alignItems: 'center',
          padding: '14px 24px 26px', textAlign: 'center' }}>
          <div style={{ fontSize: 26, fontWeight: 700, color: t.ink, lineHeight: '36px' }}>说一句，就记好了</div>
          <div style={{ fontSize: 13, color: t.ink3, lineHeight: '18px', marginTop: 6 }}>自动识别金额、类型与时间，确认后写入账本</div>
          <div style={{ flex: 1, minHeight: 10 }}/>
          <VoiceOrb t={t} size={150} onClick={() => setSt('recording')}/>
          <div onClick={() => setSt('recording')} style={{ marginTop: 22, fontSize: 14, fontWeight: 600,
            color: t.ink2, lineHeight: '20px', padding: '11px 18px', cursor: 'pointer' }}>点一下，说完就记</div>
          <div style={{ marginTop: 26, display: 'flex', gap: 8, flexWrap: 'wrap', justifyContent: 'center' }}>
            {['今天美团680', '明天下两箱可乐', '今晚8点给302送两箱怡宝'].map((s) => (
              <div key={s} onClick={() => setSt('recording')} style={{ background: t.fill, color: t.greenInk,
                fontSize: 12.5, fontWeight: 600, lineHeight: '18px', padding: '12px 14px', borderRadius: 20,
                cursor: 'pointer', whiteSpace: 'nowrap' }}>{s}</div>
            ))}
          </div>
          <div style={{ marginTop: 24, fontSize: 12.5, color: t.ink3, lineHeight: '18px' }}>今日 10月25日 · 已记 2 笔 · 营业额 ¥1,120</div>
        </div>
      )}

      {st === 'recording' && (
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', alignItems: 'center',
          justifyContent: 'center', padding: '0 24px 30px', textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: t.ink3, lineHeight: '18px' }}>正在听… 说完会自动整理</div>
          <div style={{ marginTop: 14 }}><Wave t={t}/></div>
          <div style={{ marginTop: 16 }}><Transcript t={t}/></div>
          <div style={{ marginTop: 8, fontSize: 12.5, color: t.ink3, lineHeight: '18px' }}>第 3 笔 · 识别为 营业收入</div>
          <MetaChips t={t} time="12:03"/>
          <div onClick={() => setSt('transcribing')} style={{ marginTop: 20, background: t.surface,
            border: `1px solid ${t.hair}`, color: t.dangerText, fontSize: 14, fontWeight: 600, lineHeight: '20px',
            padding: '12px 26px', borderRadius: 23, cursor: 'pointer' }}>停止识别</div>
        </div>
      )}

      {st === 'transcribing' && (
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', alignItems: 'center',
          justifyContent: 'center', padding: '0 24px 30px', textAlign: 'center' }}>
          <div style={{ width: '100%', maxWidth: 280 }}>
            <RunStrip t={t} steps={['听取语音', '整理内容', '生成确认卡']} done={1}/>
          </div>
          <div style={{ marginTop: 18 }}><Transcript t={t}/></div>
          <div style={{ marginTop: 8, fontSize: 12.5, color: t.ink3, lineHeight: '18px' }}>第 3 笔 · 识别为 营业收入</div>
          <MetaChips t={t} time="12:03"/>
          <div onClick={() => setSt('confirm')} style={{ marginTop: 18, fontSize: 12.5, color: t.infoText,
            lineHeight: '18px', padding: '12px 14px', cursor: 'pointer' }}>识别不出？手动输入</div>
        </div>
      )}

      {st === 'confirm' && (
        <React.Fragment>
          <div data-deco="1" style={{ position: 'absolute', left: 0, top: 0, right: 0, bottom: 0,
            background: spec.dark ? 'rgba(0,0,0,0.45)' : 'rgba(16,56,42,0.35)' }}/>
          <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0,
            background: spec.dark ? 'rgba(28,28,30,0.94)' : 'rgba(255,255,255,0.94)',
            backdropFilter: 'blur(20px)', borderRadius: '18px 18px 0 0', borderTop: `1px solid ${t.hair}`,
            padding: '10px 16px 16px', animation: 'vmSheetUp 0.28s ease-out' }}>
            <div data-deco="1" style={{ width: 36, height: 4, borderRadius: 2, background: t.sep, margin: '0 auto 10px' }}/>
            <div style={{ fontSize: 12.5, color: t.ink3, textAlign: 'center', marginBottom: 4 }}>请确认将保存的内容</div>
            <ReceiptCard t={t}
              title="营业收入 · 美团"
              rows={[
                { k: '时间', v: '今天 10月25日 12:04' },
                { k: '笔数', v: '本日第 3 笔' },
                { k: '写入位置', v: '营业 · 今日营业额' },
                { k: '上一笔', v: '10月18日 ¥660' },
              ]}
              amount="¥680.00"
              note="识别自语音：「今天美团680」"
              stamp="待确认"
              actions={[{ l: '确认记录', primary: true }, { l: '不记录' }]}
              onAction={(a) => setSt(a.l === '确认记录' ? 'done' : 'idle')}/>
          </div>
        </React.Fragment>
      )}

      {st === 'done' && (
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', alignItems: 'center',
          justifyContent: 'center', padding: '0 24px 40px', textAlign: 'center' }}>
          <div data-deco="1" style={{ width: 64, height: 64, borderRadius: 32, border: `2px solid ${t.green}`,
            transform: 'rotate(-6deg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon d={P.check} size={30} color={t.greenInk} strokeWidth={2}/>
          </div>
          <div style={{ marginTop: 16, fontSize: 20, fontWeight: 700, color: t.ink, lineHeight: '28px' }}>已记录</div>
          <div style={{ fontFamily: SERIF, fontSize: 30, fontWeight: 700, color: t.ink, lineHeight: '38px',
            marginTop: 2, fontVariantNumeric: 'tabular-nums' }}>12:04</div>
          <div style={{ marginTop: 10, fontSize: 12.5, color: t.ink3, lineHeight: '18px' }}>营业 · 今日营业额</div>
          <div style={{ marginTop: 8, display: 'flex', gap: 8 }}>
            <span style={{ fontSize: 12, fontWeight: 700, color: t.greenInk, background: t.surface, borderRadius: 6, padding: '4px 8px' }}>今日 3 笔</span>
            <span style={{ fontSize: 12, fontWeight: 700, color: t.greenInk, background: t.surface, borderRadius: 6, padding: '4px 8px', fontFamily: SERIF }}>¥1,800</span>
          </div>
          <div onClick={() => setSt('idle')} style={{ marginTop: 22, background: '#146B52', color: '#FFFFFF',
            fontSize: 14, fontWeight: 600, lineHeight: '20px', padding: '12px 34px', borderRadius: 23, cursor: 'pointer' }}>再记一笔</div>
        </div>
      )}
    </div>
  );
}

function PhoneBox({ spec }) {
  const [st, setSt] = useState(spec.state);
  // 主视图（auto）：录制 → 整理 → 确认卡，演示状态链
  useEffect(() => {
    if (!spec.auto) return;
    if (st === 'recording') { const id = setTimeout(() => setSt('transcribing'), 500); return () => clearTimeout(id); }
    if (st === 'transcribing') { const id = setTimeout(() => setSt('confirm'), 600); return () => clearTimeout(id); }
  }, [st, spec.auto]);
  return (
    <Phone dark={spec.dark} scale={spec.scale} tag={spec.tag} tagNote={spec.note}>
      <Screen spec={spec} st={st} setSt={setSt}/>
    </Phone>
  );
}

const PHONES = [
  { dark: false, scale: 1.2,  tag: 'Light · 空闲',   note: '主视图 · 点击演示',      state: 'idle', auto: true },
  { dark: true,  scale: 1.08, tag: 'Dark · 正在整理', note: '运行三步 · 手动输入兜底', state: 'transcribing' },
  { dark: false, scale: 1,    tag: '确认卡',         note: '收据式 · 玻璃 sheet',    state: 'confirm' },
  { dark: false, scale: 1,    tag: '已记录',         note: '印章完成标记',          state: 'done' },
  { dark: false, scale: 0.92, tag: '0.92× 小屏',     note: '正在听 · 波形',          state: 'recording' },
];

window.FusionPage = function App() {
  // DOM 顺序把主视图放最后：drive.mjs 按文本点击取文档序最后一个匹配，保证点中主视图
  const order = [1, 2, 3, 4, 0];
  return (
    <React.Fragment>
      <style>{CSS}</style>
      <Board no="07" title="语音记账" note="C 基因主打：留白 + 语音球 + 大字转写，A 收据式确认卡收尾；状态机 空闲 → 正在听 → 整理 → 确认 → 已记录（主视图点击演示）。">
        {order.map((idx) => {
          const s = PHONES[idx];
          return <div key={idx} style={{ order: idx === 0 ? -1 : 0 }}><PhoneBox spec={s}/></div>;
        })}
      </Board>
    </React.Fragment>
  );
};
