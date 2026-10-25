// fusion-memo.jsx — 「你的小掌柜」iOS V4.0 融合设计 · 备忘/记录（B 原生列表 + A 衬线日期）
// 状态机 list → detail → edit；依据 00-page-inventory.md §10（标题「记录」）
const { T, FONT, SERIF, P, Icon, Badge, TabBar, Phone, Board } = window.FusionKit;
const { useState, useEffect } = window.React;

const CSS = `
@keyframes mmFadeIn { from { opacity: 0; transform: translateY(6px) } to { opacity: 1; transform: none } }
`;

const MEMOS = [
  { id: 1, g: '本周', time: '10月25日 09:12', title: '302 便利店换成 550ml 怡宝', badge: ['进货', 'green'],  body: '302 把水换成 550ml 怡宝，一件 18 元，明天起送货，先订 20 件。' },
  { id: 2, g: '本周', time: '10月24日 18:40', title: '美团骑手说西区没人接单',   badge: ['客户', 'blue'],   body: '晚上 8 点前的西区单没人接，问一下美团经理怎么回事。' },
  { id: 3, g: '本周', time: '10月23日 16:20', title: '供应商老王周五结货款',     badge: ['货款', 'orange'], body: '老王这周五来店里结货款，共 ¥2,340，现金，记得留好收据。' },
  { id: 4, g: '更早', time: '10月18日 14:32', title: '张姐要一箱雪花纯生',       badge: ['客户', 'blue'],   body: '张姐下周要来取一箱雪花纯生，先留库存。' },
  { id: 5, g: '更早', time: '10月15日 08:55', title: '可乐进价涨了 2 块',        badge: ['进货', 'green'],  body: '可乐一件进价涨了 2 块，先不进货，卖完再说。' },
  { id: 6, g: '更早', time: '10月12日 19:47', title: '门口灯箱 11 月要换新',     badge: ['其他', 'gray'],   body: '灯箱店说 11 月有新款，换一个亮一点的。' },
];

const BAR_COLOR = { orange: 'warn', blue: 'info', green: 'green', gray: 'ink4' };

function ListScreen({ t, onOpen, onToast }) {
  return (
    <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '8px 16px 6px', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div style={{ flex: 1, minWidth: 0, fontSize: 28, fontWeight: 700, color: t.ink, lineHeight: '36px' }}>记录</div>
          <div onClick={() => onToast('新建记录（演示）')} style={{ width: 42, height: 42, flexShrink: 0, display: 'flex',
            alignItems: 'center', justifyContent: 'center', background: t.fill, borderRadius: 10, cursor: 'pointer' }}>
            <Icon d={P.doc} size={20} color={t.greenInk}/>
          </div>
        </div>
        <div style={{ fontSize: 12.5, color: t.ink3, lineHeight: '18px', marginTop: 4, fontVariantNumeric: 'tabular-nums' }}>共 12 条 · 本周 3 条</div>
        <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 8, background: t.fill, borderRadius: 10, padding: '8px 12px' }}>
          <Icon d={P.doc} size={16} color={t.ink4}/>
          <span style={{ fontSize: 13, color: t.ink3, lineHeight: '18px' }}>搜索记录…</span>
        </div>
      </div>
      {['本周', '更早'].map((g) => (
        <div key={g}>
          <div style={{ padding: '10px 16px 4px', fontSize: 12, fontWeight: 700, color: t.ink3, lineHeight: '16px', letterSpacing: 1 }}>{g}</div>
          {MEMOS.filter((m) => m.g === g).map((m) => (
            <div key={m.id} onClick={() => onOpen(m.id)} style={{ display: 'flex', alignItems: 'center', gap: 12,
              padding: '10px 16px', cursor: 'pointer' }}>
              <div data-deco="1" style={{ width: 3, height: 34, borderRadius: 2, background: t[BAR_COLOR[m.badge[1]]], flexShrink: 0 }}/>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
                  <span style={{ fontSize: 14.5, fontWeight: 600, color: t.ink, lineHeight: '20px',
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.title}</span>
                  <Badge tone={m.badge[1]} t={t}>{m.badge[0]}</Badge>
                </div>
                <div style={{ fontSize: 12.5, color: t.ink3, lineHeight: '18px', marginTop: 1,
                  overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.body}</div>
              </div>
              <div style={{ fontSize: 12.5, color: t.ink3, whiteSpace: 'nowrap', fontFamily: SERIF, flexShrink: 0,
                fontVariantNumeric: 'tabular-nums' }}>{m.time}</div>
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

function DetailScreen({ t, m, onBack, onEdit, onToast }) {
  return (
    <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', padding: '4px 16px 0', flexShrink: 0 }}>
        <div onClick={onBack} style={{ width: 42, height: 42, display: 'flex', alignItems: 'center',
          justifyContent: 'center', cursor: 'pointer' }}>
          <Icon d={P.chevron} size={18} color={t.ink3} style={{ transform: 'rotate(180deg)' }}/>
        </div>
        <div style={{ flex: 1, fontSize: 16, fontWeight: 700, color: t.ink, textAlign: 'center' }}>记录详情</div>
        <div style={{ width: 42, height: 42 }}/>
      </div>
      <div style={{ padding: '10px 16px 0' }}>
        <div style={{ fontSize: 20, fontWeight: 700, color: t.ink, lineHeight: '28px' }}>{m.title}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6 }}>
          <span style={{ fontSize: 12.5, color: t.ink3, fontFamily: SERIF, fontVariantNumeric: 'tabular-nums' }}>{m.time}</span>
          <Badge tone={m.badge[1]} t={t}>{m.badge[0]}</Badge>
        </div>
        <div style={{ fontSize: 14.5, color: t.ink2, lineHeight: '24px', marginTop: 10 }}>{m.body}</div>
        <div style={{ marginTop: 12, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 12, fontWeight: 700, color: t.greenInk, background: t.fill, borderRadius: 6, padding: '4px 8px' }}>本周 3 笔待结</span>
          <span style={{ fontSize: 12, fontWeight: 700, color: t.greenInk, background: t.fill, borderRadius: 6, padding: '4px 8px', fontFamily: SERIF }}>¥2,340</span>
        </div>
      </div>
      <div style={{ flex: 1 }}/>
      <div style={{ display: 'flex', gap: 10, padding: '0 16px 16px', flexShrink: 0 }}>
        <div onClick={() => onToast('已删除「' + m.title + '」（演示）')} style={{ flex: 1, height: 44, display: 'flex',
          alignItems: 'center', justifyContent: 'center', background: t.surface, border: `1px solid ${t.hair}`,
          borderRadius: 12, fontSize: 14, fontWeight: 600, color: t.dangerText, cursor: 'pointer' }}>删除</div>
        <div onClick={onEdit} style={{ flex: 1, height: 44, display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: '#146B52', borderRadius: 12, fontSize: 14, fontWeight: 600, color: '#FFFFFF', cursor: 'pointer' }}>编辑</div>
      </div>
    </div>
  );
}

function EditScreen({ t, m, onBack, onToast }) {
  return (
    <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', padding: '4px 16px 0', flexShrink: 0 }}>
        <div onClick={onBack} style={{ width: 42, height: 42, display: 'flex', alignItems: 'center',
          justifyContent: 'center', cursor: 'pointer' }}>
          <Icon d={P.xmark} size={18} color={t.ink3}/>
        </div>
        <div style={{ flex: 1, fontSize: 16, fontWeight: 700, color: t.ink, textAlign: 'center' }}>编辑记录</div>
        <div style={{ width: 42, height: 42 }}/>
      </div>
      <div style={{ padding: '12px 16px 0' }}>
        <div style={{ fontSize: 12.5, color: t.ink3, lineHeight: '18px', marginBottom: 6 }}>标题</div>
        <input defaultValue={m.title} style={{ width: '100%', boxSizing: 'border-box', background: t.surface,
          border: `1px solid ${t.hair}`, borderRadius: 10, padding: '11px 12px', fontSize: 14, color: t.ink,
          fontFamily: FONT, outline: 'none' }}/>
        <div style={{ fontSize: 12.5, color: t.ink3, lineHeight: '18px', margin: '12px 0 6px' }}>内容</div>
        <textarea defaultValue={m.body} rows={5} style={{ width: '100%', boxSizing: 'border-box', background: t.surface,
          border: `1px solid ${t.hair}`, borderRadius: 10, padding: '11px 12px', fontSize: 14, color: t.ink,
          fontFamily: FONT, outline: 'none', resize: 'none', lineHeight: '20px' }}/>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 12, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 12, color: t.ink3, fontFamily: SERIF, fontVariantNumeric: 'tabular-nums' }}>{m.time}</span>
          <span style={{ fontSize: 12, color: t.ink3 }}>·</span>
          <span style={{ fontSize: 12, color: t.ink3 }}>本周 3 笔待结</span>
          <span style={{ fontSize: 12, color: t.ink3 }}>·</span>
          <span style={{ fontSize: 12, fontWeight: 700, color: t.greenInk, fontFamily: SERIF }}>¥2,340</span>
        </div>
      </div>
      <div style={{ flex: 1 }}/>
      <div style={{ display: 'flex', gap: 10, padding: '0 16px 16px', flexShrink: 0 }}>
        <div onClick={onBack} style={{ flex: 1, height: 44, display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: t.surface, border: `1px solid ${t.hair}`, borderRadius: 12, fontSize: 14, fontWeight: 600,
          color: t.ink2, cursor: 'pointer' }}>取消</div>
        <div onClick={() => { onToast('已保存（演示）'); onBack(); }} style={{ flex: 1, height: 44, display: 'flex',
          alignItems: 'center', justifyContent: 'center', background: '#146B52', borderRadius: 12, fontSize: 14,
          fontWeight: 600, color: '#FFFFFF', cursor: 'pointer' }}>保存</div>
      </div>
    </div>
  );
}

function PhoneBox({ spec }) {
  const t = spec.dark ? T.dark : T.light;
  const [st, setSt] = useState(spec.state);
  const [sel, setSel] = useState(spec.sel || null);
  const [toast, setToast] = useState(null);
  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(null), 1600);
    return () => clearTimeout(id);
  }, [toast]);
  const memo = sel ? MEMOS.find((m) => m.id === sel) : null;
  const TAB_NAMES = { home: '首页', todo: '待办', calendar: '日历', biz: '经营' };
  return (
    <Phone dark={spec.dark} scale={spec.scale} tag={spec.tag} tagNote={spec.note}>
      {st === 'list' && <ListScreen t={t} onOpen={(id) => { setSel(id); setSt('detail'); }} onToast={setToast}/>}
      {st === 'detail' && memo && <DetailScreen t={t} m={memo} onBack={() => setSt('list')} onEdit={() => setSt('edit')} onToast={setToast}/>}
      {st === 'edit' && memo && <EditScreen t={t} m={memo} onBack={() => setSt('detail')} onToast={setToast}/>}
      {toast && <div data-deco="1" style={{ position: 'absolute', right: 14, bottom: 56, zIndex: 70, background: t.surface,
        border: `1px solid ${t.hair}`, borderRadius: 10, padding: '8px 12px', fontSize: 12, color: t.ink,
        boxShadow: '0 6px 18px rgba(0,0,0,0.16)', animation: 'mmFadeIn 0.18s ease' }}>{toast}</div>}
      <TabBar t={t} active="todo" onChange={(k) => setToast('已切换至「' + TAB_NAMES[k] + '」（原型演示）')}/>
    </Phone>
  );
}

const PHONES = [
  { dark: false, scale: 1.2,  tag: 'Light · 列表', note: '主视图 · 点击演示',     state: 'list' },
  { dark: true,  scale: 1.08, tag: 'Dark · 列表',  note: '深色模式',            state: 'list' },
  { dark: false, scale: 1,    tag: '详情',         note: '全文 · 编辑 / 删除',    state: 'detail', sel: 3 },
  { dark: false, scale: 1,    tag: '编辑',         note: '输入框预填 · 保存',     state: 'edit', sel: 3 },
  { dark: false, scale: 0.92, tag: '0.92× 小屏',   note: '分组列表',            state: 'list' },
];

window.FusionPage = function App() {
  // DOM 顺序把主视图放最后：drive.mjs 按文本点击取文档序最后一个匹配，保证点中主视图
  const order = [1, 2, 3, 4, 0];
  return (
    <React.Fragment>
      <style>{CSS}</style>
      <Board no="08" title="记录" note="B 原生分组列表 + A 衬线日期：每条备忘带时间与标签（货款/客户/进货），状态机 列表 → 详情 → 编辑（主视图点击演示）。">
        {order.map((idx) => {
          const s = PHONES[idx];
          return <div key={idx} style={{ order: idx === 0 ? -1 : 0 }}><PhoneBox spec={s}/></div>;
        })}
      </Board>
    </React.Fragment>
  );
};
