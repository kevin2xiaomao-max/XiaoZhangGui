# 你的小掌柜 V3.7.1 UI/UX 精修审查

> 审查日期：2026-10-08
>
> Repo：`kevin2xiaomao-max/XiaoZhangGui`
>
> Branch：`feature/v3.7.1-muse-rebuild`
>
> 远端 HEAD：`1eba796cde0eb47a5e393abdc419fd41827770a7`
>
> 用户给定基线：`1eba796cde0eb47a5e393abdc419fd41827770a7`
>
> 结论：远端 HEAD 与给定基线完全一致，无新增提交差异。

## 1. 审查边界与结论

本轮只做源码、导航图、测试资产和 CI 配置的静态审查；没有改动 Swift 业务代码、数据模型、Repository、AI 执行链、通知、提醒或备份行为，也没有 commit / push。

总体方向正确：四 Tab IA、首页营业额 Hero、S0–S3、V371 token、原生编辑 Form、显式编辑保存失败、Light/Dark 动态色和主要 Reduce Motion 分支都已建立。当前不建议重新换肤。

但在开始视觉精修前应先解决或确认 3 个验收阻断项：

1. 当前分支不在 CI 的 push 触发列表内；现有 XCUITest 仍查找已移除的“AI 第 5 Tab”，与现有四 Tab + AI Sheet 架构冲突。
2. `GoodsView`、`DailyReportSheet`、`PaymentCodeView` 等已编译 Production 目的地当前无可达入口；个人中心的语音测试入口也因常量 Binding / 默认参数而不可用。不得把这些误判为可删除功能。
3. 本审查环境为 Linux，未安装 Xcode、iOS Simulator、`xcodebuild`、`xcrun` 或 Swift 工具链。本轮没有实际编译、运行、截图、VoiceOver 或真机验证，静态测试文件的存在不等于通过。

因此，本轮审查结论为：**设计方向可继续，实施前先修复验收入口与测试基线；当前不具备“真机通过”结论。**

## 2. 现有设计资产：KEEP

| 资产 | 证据 | 审查结论 |
|---|---|---|
| 首页营业额主焦点 | `HomeView.swift:159-187` 使用 `HeroMetric`；`V371Primitives.swift:21-83` 定义唯一 S2 Hero | KEEP；不拆分、不降级成普通卡片 |
| S0–S3 Surface | `V371DesignSystem.swift:4-12, 18-46` 明确定义 Canvas / Group / Hero / Floating | KEEP；后续只收敛误用，不另建视觉体系 |
| 四主 Tab | `RootView.swift:25-58` 为首页、待办、日历、经营 | KEEP；AI 继续独立于 Tab |
| AI 独立职责 | `RootView.swift:68-74, 86-94` 以 Sheet / deep link 打开；`AIChatView.swift:115-122` 保留真实 Agent 注入 | KEEP |
| 快速记录 Local First | `QuickRecordSheet.swift:5-17, 349-393` 明确本地解析、Repository 写入和失败反馈 | KEEP；与 AI 文案和入口职责进一步区分 |
| 原生编辑 Form | Todo / Memo / Customer / Expiry / Money Editor 均使用 `Form` 与系统 toolbar | KEEP |
| 编辑保存失败可见、可重试 | `SaveReliabilityTests.swift:3-33` 覆盖 5 个核心编辑器；对应 Sheet 都有 `saveError` / “重试” | KEEP，但需补真实失败注入 UI 测试 |
| 数据与业务行为 | `XiaoZhangGuiApp.swift:17-58` 显式存储失败；Repository、SwiftData、AI、通知、Widget / Live Activity 均仍在 | KEEP，不进入本轮表现层重构 |
| Light/Dark 动态色 | `V371DesignSystem.swift:156-238` 使用 trait-aware UIColor | KEEP，并用自动截图验证对比度 |
| Reduce Motion 基础 | `V371DesignSystem.swift:102-153` 与 `V32Motion` 提供统一解析 | KEEP，但调用覆盖仍需补齐 |

## 3. 问题清单

风险等级定义：P0 = 验收阻断或功能不可达；P1 = 主流程明显体验 / 辅助功能风险；P2 = 视觉一致性或次要流程风险。

### A01 · 自动验收基线已过时且当前分支不自动跑 CI

- **文件位置**：`.github/workflows/build.yml:1-8, 272-289`；`Tests/UITests/XiaoZhangGuiUISmokeTests.swift:26-28, 92-96`；`RootView.swift:25-58`。
- **现状**：CI 名称仍为“3.5”，push 分支列表不含 `feature/v3.7.1-muse-rebuild`。10 个 XCUITest 中，启动和所有 AI 流程仍通过 `app.tabBars.buttons["小掌柜"]` 进入 AI；现代码只有四个 Tab，AI 由首页入口打开。当前仓库另有 418 个 unit test，但本环境未执行。
- **用户影响**：当前分支可能在未自动构建 / 未跑 UI 测试时继续迭代；XCUITest 即使执行也会在入口处失败，不能证明 V3.7.1 可用。
- **建议**：先更新 CI 触发分支和 UI 测试导航，使测试从首页唯一 AI 入口进入；将四 Tab 数量、AI 非 Tab、返回路径作为显式断言。CI 名称与版本元数据一并校准。
- **风险等级**：**P0**。
- **验收标准**：目标分支 push 或 PR 必跑 simulator build、418+ unit tests、更新后的 UI tests；日志出现精确的 0 failure 汇总；UI test 不再查询“AI Tab”，并验证只有首页 / 待办 / 日历 / 经营四个 Tab。

### A02 · 已编译 Production 功能存在不可达或失效入口

- **文件位置**：`V35SideUtilityDrawer.swift:4-110`；`HomeView.swift:50-105`；`ProfileView.swift:15-23, 98-100, 1015-1048`；`PaymentCodeView.swift:13-78`。
- **现状**：`V35DrawerContainer` 没有调用点，因此仅由该 Drawer 提供的商品、日报等目的地失去入口；全仓没有 `PaymentCodeView()` 调用；`ProfileView()` 默认得到 `.constant(false)` 且 `showsVoiceButton` 固定为 false，语音设置里的“测试语音”不会出现。Voice 目前只可由 deep link 打开。
- **用户影响**：已有功能、设置或用户数据可能“还在但找不到”，与“不得删除现有导航目的地”冲突；静态文件存在会掩盖可达性回归。
- **建议**：在实施前由产品确认每个目的地的新归属，再恢复单一、非重复入口；不要为了清理旧 Drawer 而删除功能或模型。建议经营页承接交易 / 导入 / 商品，个人中心承接收款码设置，日报作为经营摘要的单一深入口；最终 IA 需产品确认。
- **风险等级**：**P0**。
- **验收标准**：建立并自动遍历 Production route map；每个保留目的地从冷启动最多 3 次操作可达、可返回，且不存在仅靠 deep link 才能使用的用户功能（明确设计为 deep-link-only 者除外）。

### A03 · 首页入口与同一业务状态重复展示

- **文件位置**：`HomeView.swift:50-59, 69-88, 192-235, 258-275`；`HomeQuickEntryAuditTests.swift:27-41`。
- **现状**：客户配送和临期退货同时出现在四快捷入口与“今日重点”；快速记录同时在右上角和快捷入口；AI 同时为快捷入口“小掌柜”和底部 `AICommandEntry`。现有源码审计测试只统计 `AICommandEntry`，没有识别 `QuickActionItem(title: "小掌柜")`，所以“唯一 AI 入口”测试是假阳性。“接下来”还可能再次呈现同一 Todo / 配送 / 临期事实。
- **用户影响**：首屏被重复入口和重复状态占据，营业额焦点被稀释；用户难以理解“麦克风快速记录”和“AI 对话”的职责差异。
- **建议**：保留 Hero；保留右上角快速记录作为本地结构化采集；保留底部 AI Command 作为对话 / 分析 / 复杂指令入口；移除四快捷入口中重复的快速记录与 AI。优先方案是整体移除 `QuickActionRow`，由始终可见的“今日重点”承接客户 / 待办 / 临期导航；“接下来”只显示具体下一项，不再重复总量和状态说明。
- **风险等级**：**P1**。
- **验收标准**：首页任一业务目的地最多一个主要入口；快速记录仅一处，AI 仅一处；客户 / 临期的汇总状态不在首屏展示两遍；Hero 在标准 iPhone 首屏保持首要视觉权重；所有原目的地仍可达。

### A04 · Todo 备忘仍为双列卡片，且复用层级不正确

- **文件位置**：`TodoView.swift:197-212`；`MemoView.swift:133-174, 224-288`。
- **现状**：Todo 的“备忘”分段使用两列 `LazyVGrid + MemoCard`；独立 Memo 页使用 `GroupSurface + WorkRow + hairline`。`MemoCard` 定义在 `MemoView.swift`，却主要为 Todo 分段复用，形成两种视觉和嵌套按钮结构。
- **用户影响**：同一备忘数据在不同入口呈现完全不同；双列在大字号、长标题、图片场景可读性差，触摸与 VoiceOver 顺序也更复杂。
- **建议**：抽取共享的 `MemoListRow` / 行内容，在 Todo 与 MemoView 共用分组列表视觉；Todo 仍按 `updatedAt` 倒序，编辑仍点行，删除继续保持当前宿主既有语义，本阶段不改数据与排序规则。
- **风险等级**：**P1**。
- **验收标准**：两个入口在相同数据下标题、摘要、时间、图片提示和状态色一致；Todo 仍严格按 `updatedAt` 倒序；新增、编辑、删除调用原 Repository；不得改变两个宿主已有的删除确认决策，除非另有产品批准。

### A05 · 自定义 FloatingTabDock 尚未达到系统 TabView 的安全区与辅助控制保障

- **文件位置**：`RootView.swift:25-58`；`V371Primitives.swift:395-438`；`V371DesignSystem.swift:252-264`。
- **现状**：系统 TabBar 被隐藏，自定义 Dock 用根视图 `.overlay(alignment: .bottom)` 覆盖；页面用固定 `safeAreaPadding(.bottom, 104)` 避让。Dock 切换使用未读取 Reduce Motion 的 `V32Motion.quick`；虽然按钮有 label 和 selected trait，但不具备系统 TabBar 的容器语义、系统滚动到顶 / 定制 / 适配行为。根 overlay 在 push 到二级页面时仍存在，而多个二级页面也加了 Dock inset。
- **用户影响**：不同设备、横竖屏、键盘和辅助字号下可能遮挡或产生过量底部空白；返回导航时 Dock 可能与二级操作竞争；VoiceOver 用户无法获得完整原生 Tab 体验。
- **建议**：先做 A/B 试验：A 为可见的系统 `TabView` / 原生辅助控制；B 为保留 Soft Frosted 外观但改用 `safeAreaInset`、明确 tab 容器语义、只在根层显示并响应 Reduce Motion。未取得截图、VoiceOver 和真机结果前不替换现 Dock。
- **风险等级**：**P1**。
- **验收标准**：至少在无 Home Indicator / 有 Home Indicator、最小与最大支持 iPhone、键盘开启、AX5 字号、Light/Dark、Reduce Motion 两态验证；push 二级页时返回手势和底部内容无冲突；VoiceOver 能按四个 Tab 顺序朗读名称与选中态；重复点当前 Tab 的预期行为有测试。

### A06 · WorkRow 同时充当静态行和按钮，产生禁用行与嵌套交互

- **文件位置**：`V371Primitives.swift:128-187`；`TodoView.swift:296-309`；`MemoView.swift:151-173`；`PerformanceView.swift:231-247`。
- **现状**：`WorkRow` 无论有无 action 都构造 `Button`，无 action 时 `.disabled(true)`；带 action 的行又经常在 trailing 内放完成、删除等 Button，形成按钮内按钮。静态收入来源行被暴露为禁用按钮。统一 `.accessibilityLabel(title)` 还会吞掉副标题、金额、状态和 trailing 信息。
- **用户影响**：命中区域、按钮优先级和 VoiceOver 朗读不稳定；静态数据可能被宣布为“已变暗”；用户可能误触编辑而不是完成 / 删除。
- **建议**：拆成纯布局 `WorkRowContent`、静态 `WorkRow`、整行按钮 `WorkActionRow`；多动作行只让明确区域成为独立 Button，整行编辑动作使用不与子按钮嵌套的布局。为每种行提供完整 label / value / hint。
- **风险等级**：**P1**。
- **验收标准**：SwiftUI 层级无 Button 嵌套；静态行不带 button / disabled trait；每个交互命中区至少 44×44pt；VoiceOver 能分别聚焦“编辑 / 完成 / 删除”并朗读当前状态。

### A07 · QuickActionItem 使用每次重建都会变化的 UUID

- **文件位置**：`V371Primitives.swift:288-335`；`HomeView.swift:192-200`。
- **现状**：`QuickActionItem.id = UUID()`，而 `quickActions` 是计算属性；任何 HomeView 重算都会生成新标识，SwiftUI 会把四项视为全新节点。
- **用户影响**：可能导致焦点丢失、非预期 transition、UI 测试定位不稳，也不利于未来对快捷入口做 diff。
- **建议**：若最终保留快捷入口，使用稳定 enum / route key 作为 `id`；若按 A03 移除整行，则删除该表现层模型前先确认没有其他调用。
- **风险等级**：**P2**。
- **验收标准**：连续状态刷新时 identity 不变；VoiceOver 焦点不跳；对应单元测试验证相同业务动作产生相同 ID。

### A08 · 日历默认首屏信息过多，月历详情与当日日程重复

- **文件位置**：`ScheduleView.swift:88-116, 207-310, 429-671`；`ScheduleAgenda.swift:63-120`。
- **现状**：页面依次显示 masthead、时间轴、全天事项、完整月历、月历内 `dayDetail`、当日经营摘要。`dayDetail` 再次汇总当天 Todo、Memo、临期、客户与收支，和上方时间轴 / 全天事项及下方经营摘要重复。
- **用户影响**：默认首屏不能快速回答“今天下一件事是什么”；滚动长度大，信息权重平均化；相同事实在一页出现两次。
- **建议**：保留所有能力和 `CalendarAgenda / ScheduleAgenda` 逻辑；默认顺序调整为日期 masthead → 当日时间 / 全天事项 → 紧凑经营摘要 → 月历。移除月历内重复的 `dayDetail`，或仅在用户选择非当前日期时用一个按需展开的摘要承接；月历状态点降权。
- **风险等级**：**P1**。
- **验收标准**：日期归属、00:00 = 全天、完成日归属、收入 / 支出 / 净额计算的现有单测全绿；同一事件正文在页面只出现一次；首屏至少能看到日期选择和第一组当天事项；月历、全天事项、时间轴与经营摘要仍可达。

### A09 · Dynamic Type 与 VoiceOver 仅有局部适配，核心固定字号和截断会失真

- **文件位置**：`V371DesignSystem.swift:72-91`；`V371Primitives.swift:43-59, 164-186, 409-427`；`HomeView.swift:117-122`；`ScheduleView.swift:175-204, 700-750`。
- **现状**：Typography 多为固定 point size，Home 问候、Hero、Dock 也固定字号；大量 `.lineLimit(1)` 与 7 列固定日历格。Hero 的默认无障碍 label 不含趋势 / 目标，WorkRow 默认只读标题，月历日期 cell 不读事件状态点。当前可访问性测试大多是源码字符串断言，不是实际可访问性树。
- **用户影响**：AX 大字号下截断、重叠或信息缺失；VoiceOver 用户听不到金额、状态、到期信息与动作结果。
- **建议**：token 改为 `relativeTo` 的 scaled metric / text style；对 AX 类别切换布局（Dock、快捷行、统计三列、日历头）；为 row 提供 label + value + hint；状态点合成为“有收入 / 待办 / 临期…”文本；只隐藏纯装饰。
- **风险等级**：**P1**。
- **验收标准**：XS、默认、XXXL、AX3、AX5 截图无文字互压 / 关键截断；VoiceOver rotor 顺序符合视觉顺序；所有可操作元素有名称、角色、状态、提示；不依赖颜色表达唯一状态。

### A10 · Reduce Motion 与动效 token 尚未全链路统一

- **文件位置**：`V371Primitives.swift:401-408`；`HomeView.swift:159-165`；`ScheduleView.swift:88-100`；`Phase52AccessibilityMotionTests.swift:9-20`。
- **现状**：Dock 直接 `withAnimation(V32Motion.quick)`；Home Hero 的 numeric transition 使用 fade 分支而非 `V371.Motion.resolve(.numeric)`；Schedule 把动画挂到整个内容 VStack 的 `selectedDate` 上。静态测试只搜索少量字符串，且还检查已不可达 Drawer。
- **用户影响**：开启 Reduce Motion 后仍可能出现不必要的数字 / 全页动画；关闭时页面大范围重绘可能造成视觉漂移。
- **建议**：所有交互只从 V371 semantic motion token 取值；Reduce Motion 下装饰性 scale / move / numeric 全部关闭，仅保留必要的短 fade 或直接状态替换；动画绑定到最小变化节点。
- **风险等级**：**P2**。
- **验收标准**：Reduce Motion 开启时无 spring、scale、长位移、数字滚动和无限动画；关闭时只对被操作控件产生动画；录屏 / XCTest duration 断言覆盖 Tab、完成、日期、展开、AI voice panel。

### A11 · 部分状态操作仍静默吞错，现有“显式失败”测试存在盲区

- **文件位置**：`CustomerView.swift:136-147`；`ExpiryView.swift:121-125`；`GoodsView.swift:256-261`；`TodoView.swift:378-468`；`FlowConsistencyTests.swift:29-43`。
- **现状**：客户状态推进、临期退货切换和商品删除使用 `try?`，随后仍播放成功 / 轻触反馈；Todo 私有 `RecordEditorSheet` 保存也使用 `try?` 后直接 dismiss。现有 FlowConsistency 测试只检查文件里是否同时出现 Repository 字符串和某个反馈字符串，没有验证成功反馈位于 `try` 成功分支。
- **用户影响**：数据库失败时用户可能收到“成功”反馈，界面稍后回滚；不符合“显式保存失败反馈”的产品原则。
- **建议**：列入后续可靠性修复，但不在本轮直接改业务；先确认 `RecordEditorSheet` 是否死代码。所有真实状态动作统一 `do/catch`、失败可见且可重试，成功反馈只在 Repository 成功后发出。
- **风险等级**：**P1**。
- **验收标准**：故障注入下数据不变、无成功 haptic / toast、显示明确重试入口；重试成功后仅写一次；源码审计升级为行为测试。

### A12 · 状态徽章和说明文字仍有可精简空间

- **文件位置**：`HomeView.swift:208-233`；`QuickRecordSheet.swift:105-119`；`AIChatView.swift:160-170`；`PerformanceView.swift:143-159`。
- **现状**：首页“今日重点”标题 / 副标题 / 数量徽章常表达同一件事；快速记录首屏长期显示完整机制说明；AI Header 同时显示 Key / Demo 状态徽章；无昨日数据也占用一个徽章位。
- **用户影响**：形成轻度“徽章墙”和解释性 UI，削弱 Editorial Typography 的主次。
- **建议**：保留会改变决策的信息；数量并入 subtitle 或 accessibility value；快速记录用短标签“本地快速记录”替代常驻长说明，隐私细节放帮助 / 首次提示；AI 配置异常才显示状态，正常态不占视觉位。
- **风险等级**：**P2**。
- **验收标准**：每个 badge 都对应独立状态；移除 badge 后信息仍可由正文或 VoiceOver 获得；正常态不展示装饰性“已配置”提示；失败 / 风险状态仍醒目。

### A13 · 版本与测试资产命名未随 V3.7.1 同步

- **文件位置**：`project.yml:31-33, 86-88`；`.github/workflows/build.yml:1`。
- **现状**：App 与 Widget 的 `MARKETING_VERSION` 仍为 `3.6.0`、build 36，workflow 仍名为“3.5 构建”。
- **用户影响**：截图、构建产物、测试报告与发布审查容易误标版本，无法可靠追溯 V3.7.1 基线。
- **建议**：在正式实施 / 发布阶段由版本负责人统一更新，不在本轮只读审查中修改。
- **风险等级**：**P2**。
- **验收标准**：App、Widget、Release Notes、CI artifact、截图 manifest 使用同一 V3.7.1 版本 / build 标识。

## 4. 全 Production 页面与关键 Sheet 清单

“可达性”来自当前源码导航图，不代表真机验证。“孤立”表示编译进 Production target 但没有正常 UI 调用点，禁止直接删除。

### 4.1 页面 / 全屏目的地

| 页面 | 文件位置 | 当前入口 / 可达性 | KEEP | REDESIGN | REMOVE（仅呈现） |
|---|---|---|---|---|---|
| Root / App Shell | `App/RootView.swift` | 冷启动；可达 | 四 Tab、AI Sheet、deep link | Dock 方案对比、安全区、根 / 二级显示规则 | 固定避让与重复 overlay（方案验证后） |
| 首页 | `Features/Home/HomeView.swift` | 首页 Tab；可达 | 营业额 Hero、今日重点、天气、Profile | 入口去重、层级、AI / 快记职责 | 重复 QuickAction、重复说明 / badge |
| 待办 / 备忘分段 | `Features/Todo/TodoView.swift` | 待办 Tab；可达 | 筛选、统计、完成、编辑、删除 | 备忘改共享分组行、行交互拆分 | 双列 MemoCard 呈现 |
| 日历 | `Features/Schedule/ScheduleView.swift` | 日历 Tab；可达 | 日期、时间轴、全天、月历、经营摘要 | 首屏顺序、摘要降权 | 月历内重复 dayDetail 呈现 |
| 经营 | `Features/Performance/PerformanceView.swift` | 经营 Tab；可达 | 收入 / 支出、目标、来源、记录 | 静态行 / 动作行、空态组件统一 | 正常态无价值 badge / 文案 |
| 全部交易 | `Features/Performance/TransactionHistoryView.swift` | 经营 > 查看全部；可达 | 完整交易列表 | 与 V371 row / Dynamic Type 对齐 | 无 |
| 个人中心 | `Features/Profile/ProfileView.swift` | 首页头像；可达 | 全部设置、备份恢复、原生 Sheet | Dock inset、设置层级、语音 binding | 重复主题入口名称需产品确认后精简 |
| 客户配送 | `Features/Customer/CustomerView.swift` | 首页今日重点 / 日历；可达 | 状态、编辑、删除 | 状态推进失败反馈、WorkRow 交互 | 无功能移除 |
| 临期提醒 | `Features/Expiry/ExpiryView.swift` | 首页今日重点；可达 | 分组、编辑、退货、删除 | 状态失败反馈、字号 | 装饰性统计重复项按测试决定 |
| 记录 | `Features/Memo/MemoView.swift` | 日历事项；可达但入口较深 | 搜索、筛选、编辑、排序、确认删除 | 与 Todo 共享行 | 独立 MemoCard 视觉 |
| 商品 | `Features/Goods/GoodsView.swift` | 仅旧 Drawer；当前孤立 | 数据、编辑、分类 | 恢复单一入口、删除失败反馈 | 不删除功能 |
| 收款码 | `Features/PaymentCode/PaymentCodeView.swift` | 无调用点；当前孤立 | 本机图片、全屏亮度保护 | 恢复入口、辅助功能验证 | 不删除功能 / 数据 |
| 收款码全屏 | `Features/PaymentCode/PaymentCodeFullScreenView.swift` | 由孤立收款码页进入 | 全屏展示与亮度恢复 | VoiceOver / 返回 / 旋转验证 | 无 |
| AI 对话 | `Features/Assistant/AI/UI/AIChatView.swift` | 首页入口 / `xzg://ai`；可达 | AI 非 Tab、确认卡、输入能力 | 入口唯一性、状态 badge 降权 | 首页第二 AI 入口 |
| 存储不可用阻断页 | `App/XiaoZhangGuiApp.swift:86-94` | 持久容器创建失败时；条件可达 | 显式失败、不回退假存储 | 真机故障文案与恢复指引 | 无 |

### 4.2 关键 Sheet / 系统面板

| Sheet / Panel | 文件位置 | 当前入口 / 可达性 | KEEP | REDESIGN | REMOVE（仅呈现） |
|---|---|---|---|---|---|
| 快速记录 | `QuickRecord/QuickRecordSheet.swift` | 首页 toolbar / deep link；可达 | Local First、自动听、类型确认、失败保留 | 短化说明、与 AI 文案区分 | 首页重复入口与常驻长说明 |
| 旧语音记账 | `Voice/VoiceView.swift` | `xzg://voice`；普通 UI 入口失效 | 现有解析 / 保存行为 | 确认产品归属并恢复可达性 | 不直接删除 |
| AI Provider 设置 | `Assistant/AI/UI/AIProviderSettingsSheet.swift` | AI 菜单；可达 | Keychain、连接测试、失败信息 | Dynamic Type / 说明层级 | 重复常驻说明按需折叠 |
| AI 短语音面板 | `Assistant/AI/UI/ShortVoicePanel.swift` | AI 输入栏；可达 | AI 语音职责 | Dock / safe area / Reduce Motion | 无 |
| Todo Editor | `Todo/TodoEditorSheet.swift` | 待办新增 / 编辑；可达 | 原生 Form、显式重试 | 截图 / AX 验证 | 无 |
| Todo 私有 Record Editor | `Todo/TodoView.swift:378-468` | `showNewRecord` 无置 true；当前死路径 | 未确认前保留 | 先确认用途；若保留补失败反馈 | 不直接删除 |
| Memo Editor | `Memo/MemoEditorSheet.swift` | Todo / Memo；可达 | 原生 Form、图片、重试 | 命名“记录 / 备忘”一致性 | 无 |
| Customer Editor | `Customer/CustomerEditorSheet.swift` | 客户配送；可达 | 原生 Form、重试 | AX / 键盘 | 无 |
| Expiry Editor | `Expiry/ExpiryEditorSheet.swift` | 临期页；可达 | 原生 Form、重试 | AX / 日期控件 | 无 |
| Money Editor | `Performance/MoneyEditorSheet.swift` | 经营；可达 | 收支编辑、重试 | AX / 金额输入 | 无 |
| Goods Editor | `Goods/GoodsEditorSheet.swift` | 孤立商品页 | 编辑语义 | 随商品入口恢复验证 | 无 |
| 扫呗导入 | `Import/SaobeiImportSheet.swift` | 经营菜单；可达 | CSV / XLSX / OCR、幂等 | 长流程层级 / AX | 重复入口只保留一处 |
| 天气详情 | `Weather/WeatherViews.swift` | 首页天气；可达 | 刷新、缓存与失败 | Light/Dark / 权限状态 | 无 |
| 今日经营日报 | `DailyReport/DailyReportSheet.swift` | 仅旧 Drawer；当前孤立 | 汇总、复制、分享 | 恢复经营内单一入口 | 不直接删除 |
| 店铺资料 | `Profile/ProfileView.swift:376-428` | 个人中心；可达 | 设置持久化 | 原生字段 / 失败可见性核对 | 无 |
| 月目标 | `Profile/ProfileView.swift:430-480` | 个人中心；可达 | 目标设置 | 数值输入 / AX | 无 |
| 提醒设置 | `Profile/ProfileView.swift:482-517` | 个人中心；可达 | 通知设置 | 权限状态说明 | 无 |
| 显示模式 | `Profile/ProfileView.swift:519-572` | 个人中心；可达 | 自动 / Light / Dark | 与“外观”命名区分 | 重复解释 |
| 外观预览 | `Profile/AppearanceSettingsView.swift` | 个人中心；可达 | 主题预览 | 与 Accent / Background 分工 | 重复入口待产品确认 |
| 主题色 | `Profile/ProfileView.swift:574-643` | 个人中心；可达 | 主题 token | 分组层级 | 重复说明 |
| 背景风格 | `Profile/ProfileView.swift:645-719` | 个人中心；可达 | 背景 token | 分组层级 | 重复说明 |
| 壁纸 | `Profile/ProfileView.swift:721-1011` | 个人中心；可达 | 持久化、遮罩 / 效果 | 预览 / AX / 大图失败 | 冗长常驻说明按需折叠 |
| 语音设置 | `Profile/ProfileView.swift:1015-1064` | 个人中心；可达；测试按钮隐藏 | 语言设置 | 修复 binding / 入口决策 | 不直接删除测试语音能力 |
| 关于 / 更新说明 / 信息 | `Profile/ProfileView.swift:1069-1260` | 个人中心；可达 | 版本、隐私 | 版本同步、层级 | 重复版本文案 |
| 备份分享 / 恢复导入 | `Profile/ProfileView.swift:115-127, 299-338` | 个人中心；可达 | 系统 Share / Import、数据完整性 | 失败与权限 UI 测试 | 无 |
| 收款码编辑 | `PaymentCode/PaymentCodeView.swift:228-460` | 孤立收款码页 | 本机图片语义 | 随入口恢复验证 | 无 |

### 4.3 Widget / Live Activity Production Surface

这些不是 App 内页面，但属于正式用户可见 UI，最终视觉与无障碍回归不能遗漏。

| Surface | 文件位置 | KEEP | REDESIGN / 验收重点 | REMOVE |
|---|---|---|---|---|
| 今日经营 Widget | `XiaoZhangGuiWidget/TodayStatsWidget.swift` | 快照口径、App Group | Light/Dark、三种 family、空态、deep link、AX label | 无 |
| Widget Workbench | `XiaoZhangGuiWidget/WidgetWorkbench.swift` | 现有组件与数据 | 与 V371 状态色、字体语义对齐 | 无信息装饰按截图决定 |
| Business Live Activity | `XiaoZhangGuiWidget/BusinessLiveActivityWidget.swift` | ActivityAttributes、更新逻辑 | Lock Screen / Dynamic Island 各状态、对比度、截断 | 无 |
| 交互式完成意图 | `XiaoZhangGuiWidget/Intent/CompleteTodoIntent.swift` | 幂等完成与快照更新 | 成功 / 已完成 / 未找到反馈 | 无功能移除 |

## 5. KEEP / REDESIGN / REMOVE 总体判定

- **KEEP**：业务模型、Repository、日期归属、统计口径、AI 确认执行链、通知提醒、备份、原生 Form、四 Tab、AI 非 Tab、V371 S0–S3、系统反馈。
- **REDESIGN**：首页入口架构、Todo 备忘呈现、WorkRow 类型、Dock 方案、日历首屏、Dynamic Type / VoiceOver、motion 调用、次级页面路由归属。
- **REMOVE（仅表现层）**：重复 QuickAction、重复状态汇总、月历内重复 day detail、正常态装饰 badge、无信息价值的常驻说明、双列 MemoCard 呈现。任何 REMOVE 都不得删除数据、模型、目的地或设置。

## 6. 当前已验证与未验证

### 已验证（静态）

- 远端目标分支 HEAD 与给定基线一致。
- 工作树审查前为 clean。
- 四 Tab、AI Sheet、V371 Surface / token、主要页面导航和 Sheet 调用关系已逐文件核对。
- 仓库当前包含 418 个 unit test case、10 个 UI test case；仅统计，未执行。
- 识别出 UI 测试入口过时、CI 分支缺失、孤立目的地、重复入口、Memo 双列和组件辅助功能风险。

### 仍未验证（不得宣称通过）

- Xcode 27 simulator / device 编译。
- 418 个 unit tests 与 10 个 UI tests 的真实结果。
- iPhone 最小 / 最大尺寸、横屏、Home Indicator、键盘安全区。
- Light / Dark 自动截图和视觉 diff。
- Dynamic Type XS–AX5。
- VoiceOver 实际焦点顺序、朗读、Rotor、Magic Tap。
- Reduce Motion 实际录屏和 transition 行为。
- 真机麦克风、语音权限、通知权限、定位权限、相册 / 文件导入、分享面板。
- SwiftData 持久化失败、磁盘满 / 无权限、Repository 故障后的真实重试。
- 收款码亮度恢复、Widget / Live Activity、备份恢复在真机上的完整回归。
- App Store / Release 构建、签名、天气 Key 注入与最终版本号。

详细实施与验收方案见 `V371_REFINEMENT_PLAN.md`。
