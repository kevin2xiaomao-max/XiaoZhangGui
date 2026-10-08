# 你的小掌柜 V3.7.1 精修实施与验收计划

> 基于审查 HEAD：`1eba796cde0eb47a5e393abdc419fd41827770a7`
>
> 状态：**仅计划，尚未实施**
>
> 原则：继续 V371DesignSystem；不重做视觉品牌；不改变 SwiftData、Repository、业务模型、日期 / 统计、AI 执行、通知、提醒、备份语义。

## 1. 目标结果

完成后应形成一套更安静、可验证的 V3.7.1：营业额仍是首页主焦点；快速记录、AI、今日重点各有唯一职责；Todo 与 Memo 使用同一种编辑式分组行；Dock 经过系统方案对比后再决策；日历首屏先呈现“今天该做什么”；所有核心操作在 Light/Dark、Dynamic Type、VoiceOver、Reduce Motion 与失败重试下可自动或人工复验。

实施遵循“小步、可回退、每阶段单独验收”。不得把清理冗余表现扩大成删除功能、数据、设置或目的地。

## 2. 先决策：App Shell 方案对比，不直接替换

| 维度 | 方案 A：系统 TabView 可见（推荐验证优先） | 方案 B：保留 FloatingTabDock |
|---|---|---|
| Native Interaction | 系统角色、safe area、键盘、VoiceOver、选中态默认正确 | 需自行维护全部行为 |
| Soft Frosted 外观 | 可用系统原生呈现，定制空间较少 | 最接近当前 S3 frosted 视觉 |
| Navigation | push / pop 与 tab bar 规则更可预测 | 必须明确根页显示、二级页隐藏或保留 |
| Dynamic Type | 系统适配更稳 | 10pt label、横向四等分需自适应布局 |
| Reduce Motion | 系统负责大部分切换 | 必须接入 V371 Motion token |
| 风险 | 视觉与现稿有差异 | 安全区、辅助语义、未来 OS 行为维护成本更高 |

决策门槛：两个最小原型都必须在同一 seeded 数据、同一设备矩阵下完成截图、VoiceOver、AX5、Reduce Motion、键盘与返回导航测试。没有测试证据时保持现状，不在主分支直接替换。

## 3. 分阶段实施

### Phase 0 · 修复验收入口与建立保护网

#### P0-1 更新 CI 与 UI 测试导航

- **文件位置**：`.github/workflows/build.yml`；`Tests/UITests/XiaoZhangGuiUISmokeTests.swift`；`project.yml`。
- **现状**：当前分支不自动触发；UI 测试依赖不存在的 AI Tab；版本名仍停留在 3.5 / 3.6。
- **用户影响**：后续任何视觉结论都缺乏可信回归信号。
- **建议**：先让 CI 监听目标分支 / PR；UI 测试从首页 `AICommandEntry` 进入；给四 Tab、主要入口、列表行和 Sheet 加稳定 accessibility identifiers；版本更新由发布负责人单独提交。
- **风险等级**：**P0**。
- **验收标准**：干净 runner 完成 simulator build、unit、UI；失败截图与 xcresult 上传；测试不依赖显示文案寻找关键路由。

#### P0-2 建立 Production route manifest

- **文件位置**：`RootView.swift`、`HomeView.swift`、`ProfileView.swift`、`PerformanceView.swift`、`V35SideUtilityDrawer.swift`、`PaymentCodeView.swift`。
- **现状**：商品、日报、收款码等目的地孤立，旧 Drawer 文件仍编译。
- **用户影响**：精简入口时可能误删功能，或继续保留“幽灵页面”。
- **建议**：新增测试侧 route manifest，列出所有正式页面、入口、返回路径与产品归属；先恢复 / 确认入口，再决定旧 Drawer 表现层是否可移除。
- **风险等级**：**P0**。
- **验收标准**：每个 KEEP 目的地有一条真实 UI 导航用例；孤立项归零，或有明确签字说明为 deep-link-only / 暂存功能。

### Phase 1 · 首页与备忘 P1 精修

#### P1-1 首页唯一入口模型

- **文件位置**：`HomeView.swift:50-59, 192-275`；`HomeQuickEntryAuditTests.swift`。
- **现状**：快速记录、AI、客户、临期均有重复入口 / 状态。
- **用户影响**：首屏冗余、职责模糊、Hero 焦点下降。
- **建议**：删除表现层 `QuickActionRow`（优先方案）；toolbar 麦克风只负责本地快速记录；`AICommandEntry` 只负责 AI 对话；今日重点负责业务总览；接下来只负责具体下一项。用 route / identifier 级测试替换字符串计数测试。
- **风险等级**：**P1**。
- **验收标准**：同一入口 / 状态只出现一次；快速记录与 AI 的首屏 label、hint、打开目的地完全不同；所有原业务目的地仍可达；首页首屏视觉 diff 通过。

#### P1-2 Todo / Memo 共用分组行

- **文件位置**：`TodoView.swift:197-212`；`MemoView.swift:133-174, 224-288`。
- **现状**：Todo 双列卡、Memo 单列分组行。
- **用户影响**：大字号与长内容下不一致、难扫读。
- **建议**：抽取不持有 Repository 的纯呈现 `MemoListRow`；两个宿主自行注入 edit / delete action，保持排序和删除流程。图片只显示小型存在提示或缩略图，不恢复卡片墙。
- **风险等级**：**P1**。
- **验收标准**：两入口视觉一致；排序、编辑、删除语义和 Repository 调用不变；0 / 1 / 50 条、长标题、长正文、有图 / 无图、AX5 全覆盖。

### Phase 2 · 组件、辅助功能与动效

#### P2-1 拆分静态 WorkRow 与动作行

- **文件位置**：`V371Primitives.swift:128-263` 及全部 `WorkRow` 调用点。
- **现状**：静态 / 按钮复用同一 Button，存在禁用按钮和嵌套按钮。
- **用户影响**：误触、朗读丢失、焦点不稳定。
- **建议**：建立 `WorkRowContent`、`WorkRow`、`WorkActionRow` 三层；多动作行采用 sibling Buttons；统一 row label / value / hint API。
- **风险等级**：**P1**。
- **验收标准**：无 Button 嵌套；静态行无 button trait；44pt 命中；VoiceOver 动作独立；现有编辑 / 完成 / 删除行为不变。

#### P2-2 稳定标识与控件 token

- **文件位置**：`V371Primitives.swift:267-335`；`V371DesignSystem.swift:48-153`。
- **现状**：QuickAction UUID 不稳定；字体、行距、控件高度、状态色在部分页面仍直接写值。
- **用户影响**：focus / diff 不稳，页面节奏不统一。
- **建议**：若保留 QuickAction 使用 enum key；补充 control min size、line spacing、section rhythm、semantic status color、icon size token；禁止页面自写新视觉常量。
- **风险等级**：**P2**。
- **验收标准**：重复 render identity 稳定；静态扫描不再新增任意 radius / duration / 状态色；所有控件最小 44pt。

#### P2-3 Dynamic Type / VoiceOver / Reduce Motion 全链路

- **文件位置**：`V371DesignSystem.swift`、`V371Primitives.swift`、Home / Todo / Schedule / Performance / Profile / AI UI。
- **现状**：固定字号、lineLimit、简化 accessibility label 和局部未接入 motion token。
- **用户影响**：辅助字号截断、VoiceOver 信息不足、Reduce Motion 仍有装饰动画。
- **建议**：Typography 使用相对 text style；AX 类别切换横向布局；合成 row value / hint；月历点转可读状态；所有 animation 从 `V371.Motion` 解析。
- **风险等级**：**P1**。
- **验收标准**：见第 5 节无障碍矩阵；Reduce Motion 开启时无 spring / scale / numeric / 长位移；VoiceOver 无无名按钮或重复焦点。

### Phase 3 · 日历与次级页面

#### P3-1 日历首屏降噪

- **文件位置**：`ScheduleView.swift:88-116, 429-671`。
- **现状**：月历详情重复日程与经营摘要。
- **用户影响**：滚动长、优先级平、当天行动不突出。
- **建议**：masthead → timed / all-day → compact business summary → month；删除重复 dayDetail 呈现，或仅在跨日选择时按需展开。只改 View composition，不改 `CalendarAgenda / ScheduleAgenda`。
- **风险等级**：**P1**。
- **验收标准**：现有日期与统计单测输出字节级一致；同一事实不重复；月历与详情仍可达；截图覆盖空日、繁忙日、跨月、历史完成项。

#### P3-2 次级页面统一与孤立功能归位

- **文件位置**：Goods / PaymentCode / DailyReport / Profile / TransactionHistory / Voice。
- **现状**：视觉大多已迁到 V371，但入口归属不完整，部分说明 / badge 过多。
- **用户影响**：功能难找，信息密度不一致。
- **建议**：按 route manifest 恢复唯一入口；只清理重复呈现；原生 Form 与系统面板保持原生，不强制卡片化。
- **风险等级**：**P1**。
- **验收标准**：全部 Production route 可达、可返回；不新增重复入口；用户数据、设置、导航目的地完整保留。

### Phase 4 · 可靠性缺口

#### P4-1 状态操作失败可见、可重试

- **文件位置**：`CustomerView.swift:136-147`；`ExpiryView.swift:121-125`；`GoodsView.swift:256-261`；`TodoView.swift:378-468`。
- **现状**：部分操作使用 `try?`，失败后仍成功反馈或 dismiss。
- **用户影响**：用户误以为修改已保存。
- **建议**：先增加可控 Repository failure injection，再把成功反馈移入成功分支、失败显示重试；保持 Repository API 和业务状态机不变。
- **风险等级**：**P1**。
- **验收标准**：失败时不改变数据、不 dismiss、不发 success；重试只写一次；冷启动后状态正确。

## 4. Light / Dark 自动截图方案

### 4.1 固定测试数据与场景

扩展 `UITestSeed`，使用固定时钟、固定 locale `zh_CN`、固定 timezone、禁用网络天气波动并给出本地 snapshot。至少建立以下场景：

1. Home：空态、正常营业、长店名、今日事项繁忙。
2. Todo：今日 / 已完成 / 逾期 / 备忘；含长标题、图片、50 条。
3. Calendar：空日、繁忙日、跨月、全天 + timed、正负净额。
4. Business：无数据、有目标、多收入来源、长交易标题。
5. 二级页：Customer、Expiry、Memo、Goods、Transaction、Profile、PaymentCode。
6. Sheet：QuickRecord、AI Chat / ActionCard、五个核心 Editor、Import、Weather、DailyReport、Profile 设置。
7. Widget / Live Activity：Widget 各 family、空 / 正常 / 紧急数据、Lock Screen 与 Dynamic Island 各状态；使用独立的 Widget snapshot / preview 测试，不与 App 截图混为一组。

### 4.2 执行矩阵

- 设备：当前最低尺寸 iPhone、主流 6.1/6.3 英寸 iPhone、最大 iPhone；另选至少一台无 Home Indicator 的受支持模拟器（若 iOS 18 runtime 可用）。
- 外观：`xcrun simctl ui <udid> appearance light|dark` 后冷启动。
- 字号：默认与 AX5；完整字号矩阵见第 5 节。
- 截图：XCUITest 用 `XCUIScreen.main.screenshot()`，附件名包含 `screen/scenario/device/appearance/contentSize/reduceMotion`。
- 产物：从 `.xcresult` 导出 PNG 和 JSON manifest，记录 commit、Xcode、runtime、device、locale、scale。

### 4.3 Diff 规则

- 基线目录按版本和设备分层，不用人工覆盖旧基线。
- 先做 exact layout mask，再做 perceptual diff；日期、天气等动态区域必须由 seed 固定，不能用大面积 mask 掩盖。
- 建议门槛：关键文字 / 控件区域不允许结构差异；全图 perceptual pixel ratio 初始阈值 0.5%，之后按页面校准。
- 失败时上传 baseline、actual、diff 三图；任何基线更新必须在 PR 中人工审阅。
- 截图只能证明视觉，不代替交互、VoiceOver 或真机验收。

## 5. Dynamic Type、VoiceOver、Reduce Motion 检查方案

### 5.1 Dynamic Type

- 自动覆盖：XS、L（默认）、XXXL、AX3、AX5。
- runner 支持时使用 `xcrun simctl ui <udid> content_size <category>`；执行前以该 Xcode 的 `simctl ui help` 校验命令和 category 名称，不硬编码未经验证的别名。
- 断言：关键按钮存在且 hittable；标题 / 金额未被其他元素覆盖；ScrollView 能到达最后一项；横向四等分、三统计格、7 列日历在 AX 类别启用替代布局。

### 5.2 VoiceOver

- 自动层：用 XCUI 查询每个可交互元素的 identifier、label、value、selected / enabled 状态与顺序；对 Tab、Todo row、Memo row、Calendar cell、AI ActionCard 做专项断言。
- 人工层：在 Accessibility Inspector 与至少一台真机开启 VoiceOver，检查从冷启动到新增 / 编辑 / 完成 / 删除 / 返回；验证 Rotor、两指 scrub、弹窗焦点、Sheet dismiss、键盘和系统权限弹窗。
- 朗读准则：静态行不说“按钮 / 已变暗”；状态不只靠颜色；日期格朗读日期、选中态和事件类型；多动作行分别读“编辑、完成、删除”。
- VoiceOver 真机手测不能被源码字符串测试替代。

### 5.3 Reduce Motion

- 自动两态：执行前用该 runner 的 `simctl ui help` 确认 Reduce Motion 控制接口；不支持时由 App 的 DEBUG-only launch override 注入环境值，但 Production 继续读取系统环境。
- 对比 Tab 切换、Todo 完成、日历选日、临期展开、Profile toast、AI voice panel。
- 开启时：无 scale / spring / 长位移 / numeric transition / repeatForever；状态立即替换或短 fade。
- 关闭时：仅局部响应，不做全页面漂移；录屏作为验收附件。

## 6. 真实新增、编辑、完成、删除、失败重试自动测试

### 6.1 测试基础设施

- UI 测试继续使用独立 SwiftData container，但每个 test 采用固定 ID 与可重启目录，允许验证 relaunch 后持久化。
- 在 DEBUG + `--ui-testing` 下提供一次性故障注入：按 Repository、operation、record ID 指定“下一次 add / update / toggle / delete 抛错”。Release 完全不编译该入口。
- 测试必须通过真实 UI 和真实 Repository；禁止直接改 `@Query` 数组或只断言 toast 文案。
- 为创建、保存、完成、删除、重试、列表行和错误 alert 设置稳定 identifier。

### 6.2 流程矩阵

| 领域 | 新增 | 编辑 | 完成 / 状态 | 删除 | 失败重试 |
|---|---|---|---|---|---|
| Todo | 新增标题 / 时间 / 优先级 | 改标题与时间 | 完成、撤销完成 | 确认删除 | add / update / toggle / delete 各失败一次后重试 |
| Memo | 标题 / 正文 / 图片 | 编辑并保持排序 | 不适用 | 按宿主既有语义 | add / update / delete |
| Customer | 新增配送 | 编辑地址 / 时间 | pending → delivering → done | 确认删除 | advance / update / delete |
| Expiry | 新增商品 | 编辑日期 / 数量 | 退货 / 恢复 | 确认删除 | toggle / update / delete |
| Performance | 新增收入与支出 | 编辑金额 / 日期 | 不适用 | 确认删除 | add / update / delete |
| QuickRecord | 五种 draft 各一条 | 改识别类型 | 不适用 | 不适用 | 保存失败保留输入，重试一次写入 |
| AI ActionCard | 产生 proposal | 修改 proposal | confirm executed | cancel 不写入 | executor 失败后重试且幂等 |

每条用例同时断言：UI 状态、Repository 最终记录数 / 字段、成功反馈时机、错误文案、dismiss 行为、重启后的持久状态。删除和失败测试需确认原数据仍存在或按预期消失。

## 7. 自动编译、单元测试、UI 测试与 diff 校验

推荐 CI 顺序：

1. `xcodegen generate`，验证 scheme 与 target。
2. Simulator Debug build，主设备与最窄设备各一次。
3. Unit tests：执行全部测试，禁止 `|| true` 掩盖依赖解析以外的失败；校验发现数与源码清单一致。
4. UI functional tests：四 Tab、route manifest、CRUD、失败重试、AI / QuickRecord 分工。
5. UI accessibility matrix：默认 + AX5、Reduce Motion on / off。
6. Light / Dark screenshot suite 与 perceptual diff。
7. Generic iOS Release unsigned build；正式发布另走签名 archive。
8. 受保护行为 diff：对 Models、Repositories、AI Core / Tools、Services、Backup、Calendar / Schedule 计算层生成 diff 清单；表现层 PR 若触及这些路径必须阻断并人工批准。
9. `git diff --check`、无未跟踪截图垃圾、文档 / screenshot manifest 与 commit 一致。

建议把结果分成四个独立 required checks：`build-unit`、`ui-functional`、`ui-accessibility`、`visual-diff`，避免一个超长 job 隐藏失败归因。

## 8. 每阶段退出条件

| 阶段 | 必须通过 | 允许未完成 |
|---|---|---|
| Phase 0 | CI 可触发、UI 测试入口正确、route manifest 完整 | 尚未决定 Dock 最终方案 |
| Phase 1 | Home / Memo 视觉 diff、CRUD 回归、入口唯一性 | 次级页面微调 |
| Phase 2 | WorkRow 无嵌套、AX5 / VoiceOver / Reduce Motion 核心矩阵 | 非关键说明文案微调 |
| Phase 3 | Calendar 语义单测全绿、全 Production 路由可达 | 发布签名 |
| Phase 4 | 故障注入重试全绿、成功反馈时序正确 | 外部服务真实账号 smoke 可单列 |
| Release Gate | Debug / Release build、unit / UI、visual diff、真机关键路径 | 无；未验证项必须显式阻断或书面豁免 |

## 9. 明确仍未验证的事项

本计划未执行任何实现或测试。以下事项仍是待办，不得在审查结论中写成“通过”：

- Xcode 27 对当前源码的真实编译结果，以及 SwiftUI `Tab` API 在 deployment target iOS 18 下的行为。
- 更新前 418 个 unit tests、10 个 UI tests 的真实结果；已知 UI tests 与现 IA 冲突。
- 两个 Dock 方案的实际 A/B 截图、VoiceOver、Dynamic Type、键盘和返回导航结果。
- 所有 Light / Dark baseline 与 perceptual diff 阈值。
- VoiceOver 真机、Reduce Motion 真机、麦克风 / 通知 / 定位 / 相册 / 文件权限。
- 真实持久化故障注入、磁盘失败、备份恢复、收款码亮度恢复。
- Widget / Live Activity、App Intent、deep link 在 Release 构建中的回归。
- App / Widget 3.7.1 版本号、签名、天气 Key、archive / IPA。

只有以上证据进入 CI artifact / 验收记录后，才能把“静态符合”升级为“模拟器通过”或“真机通过”。
