> 当前状态（2026-10-27）：以下起点表格保留为交接历史。已完成的实现与回归见 BATCH-02-AI、BATCH-03-DELIVERY、BATCH-04-BUSINESS、BATCH-05-08-WORKFLOWS、BATCH-09-CONSENT；最终验收以 Docs/V400/FINAL-REPORT.md 及 outputs/V400-最终开发与验收报告.md 为准。旧沙箱限制已解除，本轮由 Codex 直接执行本地构建/测试。成功卡折叠已实现，纸面 Dark 已依据原型修正。RunStrip 仍按用户允许的安全降级保留真实 ThinkingIndicator。

# V4.0 设计与实现对照

核对起点：feature/v400-native-ui-integration @ 2febf6493273775e98fc20e4c3ec6270a7afe5f9。
设计：design/v40-full-ui-evolution @ cde375c2a424c3112b40e8592e1445869274a402。
原始依据：Muse prep/V400-TOKEN-MAP.md、prep/V400-PAGE-MAP.md、STATUS-2026-10-25.md；均已完整读取。本文为 Codex 对照结果，不能替代或冒充原始文件。

## 原始映射时效

原始映射基于 b4a540d；集成基线 a2d83ca 与 b4a540d 内容一致。V4 HEAD 在此基础上仅改 7 文件，+137/-34。旧日志早期“C–F 未提交”“V4 未创建”已被后续记录取代。设计 03 §2 的 cost guard 未并入结论不适用于当前基线，不重复引入功能。页面清单以 00 §20 修订和当前代码为准。

## Token 对照

| 要求 | 起点当前实现 | 剩余任务 | 验证方式 |
|---|---|---|---|
| 间距 4/8/12/16/20/24/32、圆角 8/10/12/16 | 既有 Tokens 可复用 | 逐页核实用途，保留主题纪律 | 原生截图、大字体 |
| 日历 #D4A017/#B8860B/#1A1D21 | dayCell 已采用 | chips/今天/操作色逐项核对，禁全局换金 | V392ScheduleContractTests、布局测试、截图 |
| brandGreen/greenInk/primaryButton 分流 | V400Tokens 已有 | 逐页替换；保留业务语义色 | Light/Dark 对比度与状态 |
| Georgia 动态字体金额 | 首页 5 处和确认卡金额已有 | 经营、报表、待办数字等 | 计算结果回归、极端字体截图 |
| 页面底/卡片/纸面 | token 已有，非全局应用 | 默认主题与用户主题/壁纸兼容 | ThemeStore 相关回归 |
| Dark 纸面 | #2C2C2E，Muse 推导 | 原型源码 #131815；第一批先不改变既有纸面，待截图比较 | 两个背景对文本、描边的对比度和截图 |
| 用户气泡/发送蓝 | #0A6ED1 已有 | 不重复实现；记录原型 Dark #0A5FD9 差异 | AI Light/Dark 截图 |
| Reduce Motion | 旧 V32Motion.fade/spring 仍短淡入 | V4 新调用点直接 nil，避免全局回归 | 系统 Reduce Motion 下 UI |

## 页面矩阵

表中“已有”只表示起点源码事实，不等于整页 V4 已验收。

| 原型/页面 | 当前代码落点 | 已有实现 | 剩余任务 | 测试方式 |
|---|---|---|---|---|
| fusion-home | Home/HomeView、V39/MorningBrief、V39HomeSections | 金额 5 处衬线、晨报/四 chips/四 Tab 保留 | 晨报数值和页面 token、主题、数据刷新动效 | 首页 UI、晨报行动单测、Light/Dark |
| fusion-ai | AIChatView、ActionCardView、ChatInputBar、CompositeActionCardGroupView | 蓝气泡、主按钮绿、金额衬线、虚线、纸面、蓝发送 | 印章、VoiceOrb、完成态展示；RunStrip 按真实事件方案 | ProductionGuard、PendingAction、V393SmartOperations、ThinkingIndicator |
| fusion-voice | Voice/VoiceView、Assistant/AI/UI/ShortVoicePanel | 两条独立语音流程 | 共享 VoiceOrb 视觉，不改保存 | AIVoiceDock、语音 UI、权限与失败回填 |
| fusion-business | PerformanceView、V38、V39/MonthlyReport、TransactionHistoryView、MoneyEditorSheet | 与 V3.9.3 一致 | Hero/统计/交易/编辑器衬线和 token | 经营计算、筛选编辑、390pt ImageRenderer 实测 |
| fusion-todo | TodoView、V38、TodoNavigationState | 两段式完成、五分组、进度头 | 数字/完成样式；评审与日历/备忘关系 | 完成失败与重试、首页逾期跳转、同源状态 |
| fusion-customer | Customer/CustomerView | 原三状态配送 | 层级、Badge、时间和下一步操作 | 推进/编辑/失败、V393CompositeIntent |
| fusion-calendar | ScheduleView、V38ScheduleLayout、V38ScheduleStyle | dayCell 定案金、密度网格、ghost | 其余金色、重复信息审查 | 日历契约、ghost 位移、同源完成 |
| fusion-goods | Goods/GoodsView | 商品与库存业务 | 售价衬线、低库存徽标、统一 token | 搜索分类、编辑删除；不新增进货 |
| fusion-expiry | Expiry/ExpiryView | pending/returned 二态 | 样式和语义色，禁抄三态和虚构批次金额 | 退货恢复、统计与边界日期 |
| fusion-memo | Memo/MemoView | 独立信息保存 | 列表层级/时间/编辑，审查任务关系 | 搜索编辑；不自动生成任务 |
| fusion-report | DailyReportSheet/Builder、MonthlyReport | 日报和月报独立 | 衬线、分享图与 token | 真实统计口径、390pt 导出 |
| fusion-settings | Profile/ProfileView | 8:00/周一10:00提醒、追加恢复 | 视觉统一，不新增 AI 设置入口 | 备份预览/追加恢复/提醒 UI |
| fusion-widget | TodayStatsWidget、WidgetWorkbench、BusinessLiveActivityWidget、XZGAppIntents | 原深链与交互 | 小范围 token/字体，保留状态与入口 | Widget 构建；主屏/锁屏/StandBy 真机 NOT RUN |
| 原型外页面 | QuickRecord、Import、PaymentCode、Weather、AIProviderSettings | 原功能保留 | 导航和二级页全面覆盖 | 导入防重、二维码、天气状态、费用/Provider 路由 |

## 第 3 步实现边界

- 印章依据 fusion-kit ReceiptCard：绿描边、greenInk 字、圆角 6、-8°；仅 executed 且非预览/非预览确认显示。
- VoiceOrb 依据原型的三个径向色值与同心环，采用静态真实阶段样式，禁止无限 pulse。不变更录音、停止、取消、转写回填或保存调用。
- ThinkingIndicator 保留 isProcessing/processingLabel 驱动与 ai.typing。当前无三步事件，不假装已读经营数据、匹配历史，不模拟耗时。
- RunStrip 后续可实施方案：单独增加只读的请求观察事件（开始、真实上下文完成、Provider 返回/本地返回、草稿就绪、失败/取消）；用单调时钟测量实际阶段。不同路径没有的阶段不显示完成。观察事件不得发请求或写业务库；逐阶段重试需复用既有重试能力，不可伪装支持。该方案尚未实施。
- 确认折叠只允许已成功卡的显示收起，保留真实结果与必要字段的展开能力；不记录仍只取消待确认卡，不能回滚已保存数据。多卡中的失败/待确认卡必须继续可操作。现阶段保留完整卡片，尚未实施折叠。
- 用户语义裁决优先：待办“今天/计划/已完成”仅待评审建议，不改筛选枚举或存储。三页面一条数据、多处引用，不重复创建。

## 验证与交付账本

- 起点本地 build.log 曾有 BUILD SUCCEEDED；不代表本轮改动通过。
- 历史 CI 40317286552 成功与 SHA 已核实；698 unit/68 UI(2 skip)为历史交接执行数，尚待独立提取 test.log。
- slow_server.py 未找回；慢请求成功/失败两个 ThinkingIndicator 用例 NOT RUN，skip 不计通过。
- 当前助手沙箱运行 xcodebuild：SwiftPM sandbox_apply: Operation not permitted。当前修改的编译、单测、UI、Light/Dark、Reduce Motion 验收均待本机终端实际执行。
- App/Widget 暂保留 3.9.3(42)。全部页面完成后再升 4.0.0，build 号核对后确定。
- 本地 Commit 在本批验证后执行；不得 Push/Merge/Release。真机相关全部待执行，不以模拟器或 CI 冒充。

## 原始证据补充（2026-10-26）

- 已独立下载 CI 40317286552 的 artifact 12650577759 并提取 test.log：698 unit / 0 failed；68 UI / 2 skipped / 0 failed，与 Muse 交接一致。两个 skip 不计通过。
- 本轮首个版本本机构建成功，Unit-20261026-223621.xcresult 和日志均确认 701 tests / 0 failed / 0 skipped，TEST SUCCEEDED。
- 首轮 Light UI 新增印章断言失败；同轮测试存储证实两卡均为 executed、非预览、非预览确认。确认汇总会触发滚至底部，且原卡容器未显式 contain 无障碍子元素。已补 contain 和回看卡片的 UI 操作，并增加显式 Dark 启动覆盖；修订版等待复验，不能沿用旧版单测/截图作整批通过。
- 安装 Build iOS Apps 后已读取 ios-simulator-browser 技能；预览将在本批验证结束后启动，镜像必须固定同一模拟器 UDID，保持终端存活，并确认实际画面后才报可用。
