# 04 · SwiftUI 实现规范（V4.0 Fusion → SwiftUI）

> 状态：框架已定，逐页细节待六页原型验收后补全。本规范只作用于设计层，**不在本任务中改动任何 SwiftUI 工程**；实现者按此规范落地到 V3.9.2 基线代码。

## 1. 硬性约束（继承用户指令 m00323）
- 基线 = ios/v392-integration @ a6bfced；不修改 main / V3.9.2 稳定分支 / Muse 的 V3.9.3 分支；不合并未完成功能。
- 不删入口、不隐藏功能、不改业务语义；被否决项（快捷操作行、四宫格、今日最重要、最近记录）不得复活。

## 2. Token 映射（HTML 原型 → SwiftUI）
| 语义 | Light | Dark | SwiftUI 落点 |
|---|---|---|---|
| textPrimary/ink | #1A1D21 | #F5F5F7 | `Color(.label)` 语义或 ThemeStore token |
| textSecondary/ink2 | #3A3F47 | #C7C7CC | `.secondaryLabel` |
| textTertiary/ink3 | **#5F646E**（原 #6E7380 在 #F3F8F5 上仅 4.42，不达标） | #8E8E93 | `.tertiaryLabel` 兜底 |
| textQuaternary/ink4 | #B0B4BC | #636366 | 仅占位/禁用，禁作正文 |
| background | #F3F8F5 | #0B0F0D | ThemeStore 页面底色 |
| backgroundSecondary | #EAF3EE | #101614 | grouped 底 |
| surfacePrimary | #FFFFFF | #1C1C1E | 卡片/纸面 |
| surfaceElevated | #FFFFFF | #2C2C2E | sheet/浮层 |
| divider | rgba(30,35,40,.08) | rgba(255,255,255,.08) | `.separator` |
| brandGreen | #1FA971 | #1FA971 | **仅图表/选中/图形**，禁大面积 |
| primaryButtonBg | **#146B52** | **#146B52** | 主按钮实心（白字 6.45/暗 4.53 达标） |
| greenInk（绿字） | #146B52 | #2FBF71 | 绿色文本专用 |
| greenTint | rgba(31,169,113,.10) | rgba(31,169,113,.14) | 大区块绿底唯一允许形态 |
| bubble 蓝 | #0A6ED1 | 系统蓝暗色 | 用户聊天气泡（原 #0A84FF 白字 4.0 不达标） |
| danger 文本 | #D03028 | 系统红 | 白底 4.94 达标 |
| warning | #FF9F0A | #FF9F0A | 仅图标/点 |
- 每个 token 的对比度实测值见 `01-design-system.md`，实现时不得回退到未达标色值。

## 3. 字体与数字
- UI 正文：SF Pro Text / PingFang SC，动态字体（`.body` 等语义样式，不写死 pt）。
- **金额与统计数字：衬线 tabular-nums**（Georgia / Songti SC 数字），用于 Hero、确认卡金额、报表、进度头 32pt 数字——这是 A 方向基因的落点。
- 最小字号 ≥ 11pt（caption2 下限）；可点目标 ≥ 44pt（iOS HIG）。

## 4. 动效（V32Motion，全部保留）
- quick 0.18s / standard 0.28s / slow 0.42s；保存/完成轻 fade，无整页庆祝；AI processing 只表达状态（运行三步条）。
- 两段式勾选：转圈 0.6s → 成功绿勾 + 删除线 + 0.55 透明 + 0.7s 后移出；失败抖动 + 行内重试。

## 5. 组件约定（原型组件 → SwiftUI）
| 原型组件 | SwiftUI 落点 |
|---|---|
| TabBar 4-tab | 既有 `RootView` TabView，tint = accent |
| ReceiptCard（收据确认卡） | `ActionCardView` 改造：纸面容器 + 发丝虚线 + 衬线金额 + 印章「已记」+ 主按钮 #146B52 |
| VoiceOrb | `ShortVoicePanel`/`VoiceView` 语音球视觉（品牌绿径向渐变 + 同心环） |
| RunStrip | AI processing 运行三步条 |
| MorningBriefSheet | 已有 sheet 重设计（衬线 headline 数字） |
| Segmented | 原生 segmented（日/周/月、待办分组） |
| 密度网格 | 保留 V38ScheduleLayout 结构，视觉沿用 PR-K 金色（**已定案**：`goldToday #D4A017` / `goldRing #B8860B` / `goldInk #1A1D21`，细则见 01 §9） |

## 6. 逐页规范
### 6.1 工作台（HomeView）
- 结构树：DateHeader（右上 plus 记一笔）→ RevenueHero（衬线金额，numericText 滚动）→ ChipStrip（待办2/逾期1/临期3/配送2；逾期点按写 `TodoNavigationState.requestedTab` 并注记「直达待办 · 逾期筛选」）→ TrendCard（近7日柱 + 收入来源三色条）→ MorningBriefCard（弹 MorningBriefSheet：headlineCard+今日重点+今日概览+月目标+建议；未读点读）→ AiCapsule（问小掌柜 → `xzg://ai`）→ TodaySection（今日事项3条）→ TabBar。
- 交互状态：晨报 sheet 开/关；chips 选中态；plus → QuickRecordSheet。
- token：Hero/晨报数字衬线；柱图 #1FA971（图表专用）；卡片 surfacePrimary；页底 #F3F8F5。
- vs V3.9.2：Hero 金额衬线（重设计）；无快捷操作行（禁）；晨报结构保留。

### 6.2 AI 对话（AIChatView）
- 结构树：StatusBadge（Key 已保存/本地模式）→ 空态（我是小掌柜+4 例）→ 线程（用户气泡 #0A6ED1 白字；助手 group 底+divider）→ ReceiptCard（纸面+虚线+衬线金额+印章「已记」+主按钮 #146B52）→ RunStrip（三步+draw-in 对勾+时长+失败重试）→ ChatInputBar（material、图标 40pt 点按区、占位「问小掌柜…」）。
- 交互状态：send→running（1.15s）→pending（确认卡）；确认→0.4s 确认态→折叠状态行+今日 N 笔计数；不记录=undo；修改→MoneyEditor（原型占位，未验证）。
- token：气泡蓝 #0A6ED1；主按钮 #146B52；greenInk 绿字。
- vs V3.9.2：确认卡收据化（A）；输入条 material（B）；语音球（C）；确认折叠（affectUI 定案）。

### 6.3 经营（PerformanceView）
- 结构树：Hero（本月营业额衬线）→ V38ChipSelector（日/周/月，glide 指示）→ TrendBarChart → SourceBar（门店/美团/其他）→ MonthGoal → RecentRecords（衬线金额 5 条）→ ⋯菜单 → MonthlyReportSheet（掌柜的月报 + 较上月同期 ↑12% + 金底分享）。
- 交互状态：period 切换刷新图表；月报 sheet；分享→ImageRenderer 390pt 生成（原型为触发态占位）。
- token：金额衬线；图表 #1FA971；徽标底 t.fill（对比度修正）。
- vs V3.9.2：chips 原生化（V38ChipSelector 已有）；金额衬线；「较上月同期」口径不变。

### 6.4 待办（TodoView）
- 结构树：Segmented（今天/明天/逾期/已完成/备忘）→ EditorialProgressHeader（32pt 衬线数字+4pt 条，仅非备忘 tab）→ 分组（上午/下午/晚上/待安排）→ 行（勾选+标题+时间）→ 空态文案（「今天没有待办，去休息一下吧」/「没有逾期事项，真棒」）。
- 交互状态：两段式勾选（转圈 0.6s→成功绿勾+删除线+0.55 透明+0.7s 移出；失败红标+抖动+行内「保存失败，可重试」+重试/放弃+alert「待办状态未改变，请重试。」）；Tab 切换消费 `TodoNavigationState`。
- token：done 圆 #146B52 白✓（暗色恒用）；失败文本 dangerText。
- vs V3.9.2：结构全保留；done 底色对比度修正；移出动画归一 V32Motion slow。

### 6.5 客户配送（CustomerView）
- 结构树：大标题+筛选 chips → 列表（名称+地址+状态 Badge+pending 行加今日时间）→ 详情（信息+配送状态推进）。
- 交互状态：四态推进（待配送→开始配送→配送中（蓝点+预计 18:20）→确认送达→绿勾签收）。
- token：Badge 组件化（green/red/orange/blue 映射见 01 文档）；状态行语义色。
- vs V3.9.2：Badge 对比度修正；pending 行加时间（密度）；电话/导航为占位。

### 6.6 日历（ScheduleView）
- 结构树：masthead（月份箭头）→ 当日时间 → 全天事项 → 密度 chips（月/周）+ 网格（V38ScheduleLayout：今日金圆 #D4A017 深墨字、选中金环 #B8860B）→ 当日详情 3 条 → 当日经营（¥3,480/¥1,220/3 笔）。
- 交互状态：密度切换；选日；ghost 行沉降动画（V38 已有，保留）。
- token：今日 `goldToday #D4A017` 实心圆 + 深墨字（7.12）、选中 `goldRing #B8860B`（3.03–3.25 非文字达标）、密度 chips 金底深墨字；浅底金圆必须带 1pt 金环（**已定案保留 PR-K 金色**，2026-10-25 用户确认，细则见 01 §9）。
- vs V3.9.2：结构全保留，视觉不变；选中环 matchedGeometryEffect 滑移保留。

### 6.7 扩展页（语音/备忘/商品/临期退货/报表/设置/Widget）
- **语音（VoiceView sheet .large）**：idle（大标题+VoiceOrb+「点一下，说完就记」+示例 pill）→recording（正在听+大字转写「今天美团……六百八十」+波形）→confirm（glass sheet 确认卡：营业收入·美团/¥680.00/本日第 3 笔/写入位置/上一笔/确认记录+不记录）→done（✓ 已记录 12:04）。token：VoiceOrb 径向渐变 #3FC98A→#1FA971→#146B52；glass rgba(255,255,255,0.94)（SwiftUI 落点 .ultraThinMaterial）。差异：确认卡收据化（A 基因）。
- **备忘（MemoView）**：大标题「记录」+搜索条+分组（本周/更早）+行（标题+时间「10月18日 14:32」+Badge 货款/客户/进货）+统计「共 12 条 · 本周 3 条」；详情→编辑（预填+保存）。差异：行内时间密度；Badge 组件化。
- **商品（GoodsView）**：大标题+搜索条+分类 chips（全部/饮料/零食/日用）+行（名称/规格/售价衬线/库存「剩 12 件」/低库存 Badge）+统计「共 23 种 · 低库存 3」；详情+进货 sheet。差异：售价衬线；低库存 Badge 橙色。
- **临期退货（ExpiryView）**：统计头（「3 批 · 合计 ¥1,860」衬线）+分组（今天到期/3 天内/7 天内）+行（名称/批号/数量/进货日期/「还剩 3 天」Badge：今天 red、3 天 orange、7 天 blue）+退货状态机（待退货→已联系供应商→已退回，统计头联动）。差异：Badge 分级色；统计头衬线联动。
- **报表（今日经营日报）**：日期头→总览 Hero（营业额 ¥3,480 ↑19% 衬线+支出 ¥1,220+净额 ¥2,260）→渠道明细（门店 ¥2,150/美团 ¥1,120/其他 ¥210+占比条）→时段趋势（早/午/晚/夜）→金底「分享今日日报」（点击→「已生成分享图」状态行）。差异：A 基因衬线金额；分享=ImageRenderer 390pt（未验证，占位）。
- **设置（ProfileView）**：头像+店名+V3.9.2 (41)→提醒（每日晨报「每天 8:00」开关、每周备份「周一 10:00」开关，真实切换）→外观（跟随系统/浅色/深色、强调色品牌绿）→数据（备份、恢复备份→sheet「恢复为追加合并，不会删除现有数据」）→关于（版本/隐私）。差异：保留 V3.9.2 新增提醒行与恢复文案。
- **Widget**：中号「今日营业」（¥3,480 ↑19% · 3 笔 · 待办 2，点击切换营业额/净额）+中号「待办」（2 条+逾期 1）+小号「＋ 记一笔」；Light/Dark 各一套；圆角 22；角标「小掌柜工作台」。差异：V3.9.2 无改动保持；卡片点击为原型演示，真 Widget 用 widgetURL 深链。

## 7. 动效增强落地配方（affectUI 参考定案 → SwiftUI 实现，细则见 06 文档）
- **统一约定**：`@Environment(\.accessibilityReduceMotion)` 为 true 时一律 `.animation(nil, value:)` 直接终态；曲线用 `.easeOut(duration: V32Motion.standard)`。
- **相位标签**（AI 运行三步）：`ZStack` + 旧标签 `.offset(y:-8).opacity(0)` 与新标签 `.offset(y:8→0)` 交错，用 `.id(step)` 触发 transition（opacity .18s / offset .28s）。
- **三步行 + 时长**：步骤行 = draw-in 对勾（`Trim` stroke 动画 0.36s + 0.12s 延迟）+ 步骤名 + mono 时长 + 失败行内「重试」。
- **确认折叠**：ActionCard 确认后 0.4s 确认态（绿底 checkmark）→ 内容折叠为单行状态 + 「今日 N 笔」计数 `ContentTransition.numericText`；「不记录」= undo 回到可操作态。不实现倒计时。
- **数字滚动**：仅数据刷新时（非首现）对金额用 `contentTransition(.numericText(value:))` + `.animation(.easeOut(duration: 0.9), value: amount)`；首屏与 Reduce Motion 一律静态。
- **共享 shimmer**：单一 `LinearGradient` 以 `mask` 盖住全部骨架块，`offset` 横扫（2s linear 循环）；Reduce Motion 切静态骨架。
- **指示 glide**：分段器/chips 选中指示 = `matchedGeometryEffect` + 拉伸回弹（`.spring(response: 0.3, dampingFraction: 0.8)`）；不实现横扫拖拽（用原生 segmented）。
- 禁止：Reaction Bar、Grid Background、Text Reveal、倒计时审批、入场全屏庆祝。
