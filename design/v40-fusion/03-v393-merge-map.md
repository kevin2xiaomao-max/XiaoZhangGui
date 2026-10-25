# 03 · V3.9.3 功能合并映射（V4.0 设计 → 代码落地映射）

基线：`xiaozhanggui-v40` @ `a6bfced`（ios/v392-integration，用户指定的已验证 V3.9.2）。本文档把每个 V4.0 设计决策映射到基线代码事实，并标注 Muse V3.9.3 线的状态。**设计层面文档，不涉及实际代码合并。**

## 1. 已并入基线的功能（V4.0 保留 + 融合重设计）

| # | 功能 | 基线代码 | V4.0 设计处理 |
|---|---|---|---|
| 1 | 掌柜晨报 | `Features/Home/V39/MorningBrief.swift`(495 行) + `V39HomeSections.swift`(386) + `V39Style.swift`(61)，PR-I 本地规则引擎零云端，入口 = 首页晨报卡 → MorningBriefSheet(.large)，通知 8:00 | 首页保留晨报卡与 sheet 信息架构；视觉融合 A 账页基因：headline 衬线数字（昨日营业额）、纸面卡、发丝线，主按钮 #146B52 |
| 2 | 日历密度网格 | `Features/Schedule/V38/V38ScheduleLayout.swift`(119) + `V38ScheduleStyle.swift`，PR-K 月/周 density chips + 金圆今日 + 金环选中 | 保留月/周 chips 交互；PR-K 香槟金视觉**已定案保留**（2026-10-25 用户确认）：今日 `#D4A017` 实心圆 + 深墨字、选中环 `#B8860B`、密度 chips 金底深墨字；token 与对比度见 01 §9 |
| 3 | 待办两段式勾选 | `Features/Todo/V38/V38TodoToggleFlow.swift` + `V38TodoStyle.swift` + `TodoNavigationState.swift`(21 行) | 保留完整流转（转圈→成功绿勾+删除线+0.7s 移出；失败红角标+重试）；与 Editorial 进度头（32pt 衬线数字+4pt 进度条）合并为待办页骨架 |
| 4 | 经营趋势切换 + 月报 | `Features/Performance/V38/V38ChipSelector.swift` + `V38TrendBarChart.swift`(236) + `V38SourceSummary.swift` + `V39/MonthlyReport.swift`(303) | 保留日/周/月 chips 与月报内容结构；金额全部 serif tabular（A 基因）；月报「较上月同期」口径徽标 P0-1 必须保留原文案 |
| 5 | AI 高清回退日志（vision draft） | `Features/Assistant/AI/Core/VisionDraftParser.swift` + `Tests/V392VisionDraftTests.swift`(13 行) + `UserFacingAIError.swift`(10 行) + `ProviderChain.swift` + `AIProviderSettingsSheet.swift`（5247ec0 second batch） | V4.0 AI 页「运行三步」第三步文案对应此链路；不改变错误文案语义 |
| 6 | MoneyEditor 分段 | `Features/Performance/MoneyEditorSheet.swift`(241) 收入来源（门店/美团/其他）+ 支出分类（进货/房租/水电/人工/其他）、34pt 金额、行内红字校验、脏离开 alert | 设计系统组件规范直接覆盖，文案原样保留 |
| 7 | Profile 新提醒行 | `Features/Profile/ProfileView.swift`(1406) 每周备份（周一 10:00）/ 每日晨报（每天 8:00）、恢复预览「恢复为追加合并，不会删除现有数据」 | 设置页原型覆盖此两行；恢复文案原样保留 |
| 8 | 首页快捷操作行 / 四宫格 | 已删除（2026-10-23 用户否决；Home 源码 L9-10 注释禁恢复） | **V4.0 不复活**（用户要求 ⑧） |
| 9 | 「今日最重要」「最近记录」 | 全仓零命中 | 不引入 |
| 10 | Widget / Intents | `XiaoZhangGuiWidget/TodayStatsWidget.swift` + `WidgetWorkbench.swift`、`XZGAppIntents.swift`：V3.9.2 无改动，显示名「小掌柜工作台」 | Widget 沿用基线，视觉规范按新 token 微调（低风险） |

## 2. 未并入基线的 Muse V3.9.3 线（V4.0 只预留、不设计依赖）

| 分支 | 状态 | V4.0 处理 |
|---|---|---|
| `ios/v392-ai-cost-guard` @ 19a5f452（= tag `v3.9.2-handoff-2`） | **未并入** ios/v392-integration；且该分支 fork 早于 second-batch（缺 VisionDraft 系列 5 个文件改动，`git diff a6bfced 19a5f452` 显示 5 文件 −26 行）。即：cost guard 与 vision-draft 两线互相独立 | AI 页保留 StatusBadge（Key 已保存 / 本地模式）位置，为成本护栏状态指示预留 UI 位；**合并风险提示**：将来并入 cost guard 需先 reconcile VisionDraftParser 等 5 文件 |
| `ios/v392-pr-i-morning-brief` @ cfdb179c | 已并入（晨报在基线内） | 见 #1 |
| `ios/v392-pr-k-schedule-v39` @ afb41d3 | 已并入（密度网格在基线内） | 见 #2 |
| `ios/v392-second-batch-fixes` @ 5247ec0 | 已并入（a6bfced 的父提交） | 见 #5 |

## 3. V4.0 设计决策 → 实现清单（原型完成后的输出物）
- 设计系统 `01-design-system.md` 的 token 表 → `DesignSystem/Tokens.swift` / `V21Color.swift` 的色值替换清单（Light/Dark 双表，附对比度实测）。
- 组件规范 → SwiftUI 实现规范（`04-swiftui-spec.md`，随六页原型验收后产出）。
- 已否决项（原型验证后不得实现）：Dashboard 四宫格、全页 Glass、渐变背景、高饱和 accent、无限 pulse、Web 侧边栏替代 NavigationStack、合并 QuickRecord/Voice/AI 入口、快捷操作行复活。

## 4. 状态
- [x] 基线事实核对（a6bfced = 已验证提交，无漂移）
- [x] Muse 线与基线关系梳理（cost guard 未并入 + fork 分歧）
- [x] 逐页映射核对（13 页原型全部通过验收后完成，见 §4.1）

### 4.1 原型页 → 基线代码映射（2026-10-25 验收后）
| 原型页（13） | 基线代码 | 合并映射 # | 状态 |
|---|---|---|---|
| 工作台 | `Features/Home/HomeView.swift` + `V39/MorningBrief.swift` + `V39HomeSections.swift` | #1 #8 #9 | 通过 |
| AI 对话 | `Features/Assistant/AI/UI/AIChatView.swift` + `ActionCardView` + `ChatInputBar`；VisionDraft 链路 | #5 | 通过 |
| 语音记账 | `Features/Voice/VoiceView.swift` + `ShortVoicePanel`；确认卡=ActionCard 改造 | #6 | 通过 |
| 经营 | `Features/Performance/PerformanceView.swift` + `V38/*` + `V39/MonthlyReport.swift` | #4 #6 | 通过 |
| 待办 | `Features/Todo/TodoView.swift` + `V38/*` + `TodoNavigationState.swift` | #3 | 通过 |
| 日历 | `Features/Schedule/ScheduleView.swift` + `V38/V38ScheduleLayout.swift` | #2（金→绿待用户确认） | 通过 |
| 客户配送 | `Features/Customer/*` | —（V3.9.3 无改动） | 通过 |
| 商品 / 临期退货 / 备忘 | `Features/Goods/*` / `Features/Expiry/*` / `Features/Memo/*` | —（V3.9.3 无改动） | 通过 |
| 报表 | `Features/DailyReport/*` + MonthlyReport 分享链路 | #4 | 通过 |
| 设置 | `Features/Profile/ProfileView.swift`(1406) | #7 | 通过 |
| Widget | `XiaoZhangGuiWidget/TodayStatsWidget.swift` + `WidgetWorkbench.swift` | #10 | 通过 |
