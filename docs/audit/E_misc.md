# E 部分审计报告：杂项生产模块与系统服务

> 审计基线：`feature/v3.6-ui-ai-expansion` @ `335981b`（审计工作区 `~/workspace/xzg-v36-audit`，只读）
> 审计范围：PaymentCode（6 文件）、Import 扫呗（8 文件）、Weather（4 文件）、Services（5 文件）、XiaoZhangGuiWidget、SharedKernel、project.yml、entitlements
> 报告日期：2026-10-02

---

## 目录

1. [收款码 PaymentCode](#1-收款码-paymentcode)
2. [扫呗导入 Import](#2-扫呗导入-import)
3. [天气 Weather](#3-天气-weather)
4. [系统服务 Services](#4-系统服务-services)
5. [通知全表](#5-通知全表)
6. [Widget / LiveActivity 内容](#6-widget--liveactivity-内容)
7. [扫呗去重与字段映射规则](#7-扫呗去重与字段映射规则)
8. [entitlements capabilities 与 Android 等价方案](#8-entitlements-capabilities-与-android-等价方案)
9. [iOS-only API 清单与 Android 等价](#9-ios-only-api-清单与-android-等价)
10. [Tests 覆盖情况](#10-tests-覆盖情况)
11. [Android 迁移风险点汇总](#11-android-迁移风险点汇总)

---

## 1. 收款码 PaymentCode

路径：`XiaoZhangGui/Features/PaymentCode/`（6 文件）
UI 入口：`XiaoZhangGui/Features/Profile/ProfileView.swift:72` ——「我的 → 工具 → 收款码」`navigationDestination(item: $toolRoute)` 分支 `case "paymentCode": PaymentCodeView()`

### 1.1 用户流程

1. **列表页** `PaymentCodeView.swift`（入口 `PaymentCodeView.body`）：从 `PaymentCodeStore.shared.codes` 按 `order` 升序展示；空态（`emptyState`）显示 V32EmptyState +「添加收款码」按钮；每行 52×52 缩略图圆角 12、名称 + 类型副标题、右上角 `ellipsis.circle` 菜单（重命名/替换图片、删除）；底部常驻隐私脚注「图片仅保存在本设备，不会上传服务器或发送给任何服务」。
2. **新增/编辑 Sheet** `PaymentCodeEditorSheet`（`PaymentCodeView.swift` 尾部）：类型三选（微信/支付宝/自定义，`PaymentCodeKind.allCases`）、名称输入框（空则回退 `kind.displayName`，见 `PaymentCodeStore.resolvedName`）、PhotosPicker 选图（`matching: .images`，`handlePickedItem` 校验 `UIImage(data:)` 可解码，否则报错「无法读取该图片，请换一张试试」）、180 高预览卡、「保存」按钮（新增要求已选图；编辑可只改名）。
3. **删除**：`confirmationDialog`「删除这张收款码？」「将同时删除本机保存的收款码图片，此操作不可撤销。」→ `store.delete(id:)` + `Haptic.warning()`。
4. **全屏展示** `PaymentCodeFullScreenView.swift`：点击行打开 `fullScreenCover`；多张码 `TabView(.page)` 左右滑动；黑底 + 隐藏状态栏（`.statusBar(hidden: true)` + `.persistentSystemOverlays(.hidden)`）；顶部仅关闭键（`xmark.circle.fill` 30pt）、底部码名称 +「类型 · n/N」页码；图片缺失显示占位（`photo.badge.exclamationmark`「图片不可用」「可返回列表后重新替换该收款码图片」）；进入全屏亮度拉高，退出/后台/来电恢复。

### 1.2 数据与存储设计（关键不变量，Android 必须遵守）

- **metadata 轻量持久化** `PaymentCodeModel.swift`：`PaymentCodeMetadataStore`，key `xzg.paymentCodes.metadata.v1`，UserDefaults JSON（ISO8601），只存 id/name/kind/fileName/order/createdAt。损坏的 metadata 返回空列表（不崩）。
- **图片本体** `PaymentCodeImageStorage.swift`：`Application Support/PaymentCodes/payment-code-<UUID>.<ext>`，`.atomic` 写入；扩展名按魔数推断（PNG/HEIC/JPEG/`.img`，`fileExtension(for:)`）；**绝不扫描目录批量清理**，只删 metadata 指向的具体文件。
- **事务语义** `PaymentCodeStore.swift`：删除先删文件再更新 metadata；替换先落新文件+更新 metadata 再删旧文件（失败时旧图保留、无孤儿）；order 追加递增。

### 1.3 亮度保护 `PaymentCodeBrightnessGuard.swift`

- `begin()`（行 42）：保存当前亮度 → UserDefaults 落「提升中」标记（`xzg.paymentCode.brightness.active.v1=true` + `xzg.paymentCode.brightness.saved.v1`）→ 拉到 0.95（`presentationBrightness`）。重复进入不覆盖保存值。
- `end()`（行 53）：恢复亮度、清标记；未进入时无副作用。
- scenePhase 变化（`PaymentCodeFullScreenView.swift` `onChange(of: scenePhase)`）：inactive/background 立即恢复；active 再次拉高。
- `applyStartupRecovery()`（行 69）：App 启动时检查遗留标记（异常 kill 未执行退出回调时），恢复合法保存值（0…1）后清标记。

### 1.4 隐私边界（写在代码注释里的硬性约束）

`PaymentCodeModel.swift` 头部注释：原始图片 Data/base64 绝不进入 UserDefaults；不上传、不发网络请求、**不提供给 AI/Provider**。Sheet 底部提示「仅在本机展示你自己保存的收款码图片，不识别、不解析二维码内容。」

---

## 2. 扫呗导入 Import

路径：`XiaoZhangGui/Features/Import/`（8 文件）
UI 入口：`XiaoZhangGui/Features/Performance/PerformanceView.swift:68` —— 营业额页「扫呗导入」按钮 → `.sheet(isPresented: $showImport) { SaobeiImportSheet() }`

### 2.1 用户流程（`SaobeiImportSheet.swift`）

1. **选择文件**（`pickerCard`）：`fileImporter(allowedContentTypes: [.commaSeparatedText, .plainText, .data, csv, xlsx]，单选)`；或 PhotosPicker「从扫呗截图识别预览」；Demo 模式下还有「查看扫呗 Demo 预览」。
2. **异步解析**（`handlePick` 行 293）：`SaobeiImportWorker.parse` 在 `Task.detached(.userInitiated)` 后台解析（security-scoped resource 访问），UI 显示「正在解析…」。
3. **截图 OCR 路径**（`handleScreenshot` 行 329）：照片 → `SaobeiScreenshotOCR.recognize`（Vision 本地识别）→ 转 `SaobeiParsedRow`（status="成功"，paymentMethod 默认「扫呗截图」，fingerprint=`"ocr-" + sourceKey`），失败报错「截图无法识别，请确认日期和金额清晰后重试。」。
4. **预览概览**（`overviewCard` 行 166）：文件、文件记录笔数、有效交易笔数、重复笔数、新增笔数、新增金额（`Fmt.money` 高亮品牌色）；错误行另列「错误行」卡（最多 20 行）。
5. **「将写入业绩」卡**：前 5 条新增记录（金额 headline + 日期时间·支付方式·订单号 caption）；无新增时文案「没有新的成功交易。重复导入不会让营业额翻倍。」
6. **确认导入**（`commit` 行 347）：`PerformanceRepository.importSaobei(newRows, skippedFailed:)` 单次落库 → `SaobeiImportCommitResult`（新增/重复/未计入）→ 结果卡；Demo 模式下 fake commit 不写真实数据（文案「Demo 导入完成，真实数据未发生变化」）。

### 2.2 解析器

| 文件 | 职责 | 关键规则 |
|---|---|---|
| `SaobeiFileValidator.swift` | 入口校验 | `.csv/.txt` 要求首行含 `,`/`，`或「交易时间+收款金额」；`.xlsx` 要求 PK\x03\x04 魔数；拒绝伪装文件。`.xls`（旧二进制）明确不支持，提示另存 XLSX/CSV（`SaobeiXLSXParser.swift` 尾部 `SaobeiImporter.parse`）。 |
| `SaobeiCSVParser.swift` | CSV 解析 | 编码链：UTF-8（含 BOM 去除）→ UTF-16 → GB_18030_2000 → isoLatin1（`decodeText` 行 73）。表头按关键词匹配（`SaobeiModels.swift` `SaobeiColumn`：日期 6 个键、金额 6 个键、状态 4 个键、订单号 6 个键、支付方式 4 个键）。手写 CSV 解析器支持引号转义、`,`/`\t`/`，` 分隔（`parseCSVLine` 行 113）。金额清洗 `,`/`，`/`¥`/`￥` 且必须 > 0（`parseAmount` 行 140）。日期支持 8 种格式 + ISO8601（`SaobeiDateParser` 行 164）。 |
| `SaobeiXLSXParser.swift` | XLSX 解析（自研） | 自研 MiniZip：EOCD 定位 → Central Directory 遍历；`Compression` framework raw DEFLATE 解压（回退 `NSData.decompressed(zlib)` / 手工包 zlib 头）。SAX（Foundation `XMLParser`）解析 workbook.xml+rels 找活动 sheet、sharedStrings（含 rich text 多 `<t>`）、sheet（支持 shared/inlineStr/number/日期/self-closing cell）。转 CSV 后复用 `SaobeiCSVParser`。 |
| `SaobeiScreenshotOCR.swift` | 截图 OCR | Vision `VNRecognizeTextRequest`（`.accurate`，`zh-Hans`/`en-US`）；正则抽日期（`20\d{2}[年./-]\d{1,2}[月./-]\d{1,2}` 可选时分）与金额（`¥|￥|金额|实收|收款` 前缀或小数点或 ≤10000）；就近日期关联行金额；支付方式窗口 ±1 行关键词匹配（微信/支付宝/扫呗/美团/饿了么/现金）；订单号正则 `(订单号\|订单\|流水号)\s*[:：#]?\s*([A-Za-z0-9-]{5,})`。confidence：显式标记 0.96 / 小数 0.9 / 其它 0.78。 |
| `SaobeiExporter.swift` | 导出 | CSV 导出（表头「交易时间,交易状态,订单号,支付方式,收款金额」）+ 真 XLSX 导出（自研 `XLSXWriter`：sharedStrings + ZIP Store 无压缩打包，CRC32 自实现；禁止 CSV 改扩展名冒充）。回环导入兼容。 |
| `SaobeiImportWorker.swift` | 线程接缝 | 文件读取/校验/解析放后台；UI 只在 MainActor 更新。 |

### 2.3 写入映射（`AppRepository.swift:113` `importSaobei`）

`SaobeiParsedRow` → `Performance`：`amount`→金额；`note`=`"扫呗"` 或 `"扫呗 · <paymentMethod>"`；`date`→日期；`fingerprint` 原样；`paymentMethod`→支付方式；`orderNo`→订单号；`importSource="saobei"`；`incomeSource=IncomeSource.from(note: row.paymentMethod)`（P0-3 按支付方式派生收入来源）。单次 `context.save()`，随后 `SnapshotSyncManager.refreshAll` 单次刷新快照/Widget/LiveActivity。

### 2.4 Demo 模式

`DemoMode.swift:233` `DemoImportPreview`：文件名「扫呗交易明细_2026-09-14.csv」；文件 328 笔 / 有效 316 / 重复 12 / 新增 304 / 金额 18628.50。预览行 5 条示例（9:02 28.00 等，fingerprint `demo-import-HHMM`）。

---

## 3. 天气 Weather

路径：`XiaoZhangGui/Features/Weather/`（4 文件）
UI 位置：**首页顶部问候区右侧** `HomeView.swift:181` `weatherButton`（图标 `snapshot.symbolName` + `roundedTemperature°`），点击弹 `WeatherDetailSheet`（`.medium` sheet：标题「当前天气」+ 关闭/刷新；hero 卡 40pt 图标 + 大字温度 +「天气状况 · 城市」；详情行：今日最高/最低、体感、降雨概率、离线缓存状态、定位未授权提示、数据来源「WeatherAPI.com」）。

### 3.1 数据来源

- **API**：`https://api.weatherapi.com/v1/forecast.json?key=...&q=<lat>,<lon>&days=1|3&aqi=no&alerts=no&lang=zh`（`WeatherService.swift` `WeatherAPIProvider`）。
- **API Key 注入链**：GitHub Secret `XZG_WEATHER_API_KEY` → CI xcodebuild 覆盖 build setting → `INFOPLIST_KEY_XZGWeatherAPIKey` → `WeatherConfiguration.current()`（仓库内默认空串，绝不进仓库）。
- **默认坐标**：恩平 22.183, 112.305（`WeatherConfiguration.current`；`XZGWeatherCity/Latitude/Longitude` 可覆盖）。
- 城市名规则（P1-2）：GPS 定位成功时 `city` 传空串 → 采用 API 返回的 `location.name` 真实城市名；定位失败 fallback 才用配置城市「恩平」。

### 3.2 缓存策略（`WeatherService` actor，UserDefaults）

- key：`xzg.weather.current.v1` / `xzg.weather.forecast.v1`。
- 30 分钟内直接返回缓存（`freshInterval`）；失败时 6 小时内返回标 `isStale=true` 的陈旧缓存（`staleFallbackInterval`）；无缓存且失败才抛错。
- 状态机 `WeatherViewState`：idle/loading/loaded/notConfigured/unavailable(network|api|unknown)；已有数据时失败保留旧快照（state 仍 loaded）。

### 3.3 LocationManager 权限流程（`LocationManager.swift`）

- `requestWhenInUseAuthorization()`（仅前台，不请求 Always），精度 `kCLLocationAccuracyKilometer`。
- `requestAuthorizationAndLocation()` 幂等：5 分钟内坐标直接复用；denied/restricted 直接返回 nil；4 秒超时保护（`Timer`）；`didFail` 返回 nil。
- 任何失败分支 → `WeatherViewModel` fallback 到配置坐标（恩平），并置 `isLocationDenied=true`（拒绝时 UI 显示「定位未授权 · 使用默认城市」）。
- 拿到新坐标后重建 provider 再请求（`requestWithLocationFallback`）。

### 3.4 模型 `WeatherSnapshot`

temperature/feelsLike/condition/conditionCode/city/precipitationProbability/max/min/observedAt/isStale；`symbolName` 按 conditionCode 关键词映射 SF Symbol（thunderstorm→cloud.bolt.rain.fill 等）；`isRaining` 供经营逻辑使用。

---

## 4. 系统服务 Services

路径：`XiaoZhangGui/Services/`（5 文件）

### 4.1 NotificationManager（`NotificationManager.swift`）—— 本地通知全权

- 权限：`requestAuthorization()` 申请 `[.alert, .sound, .badge]`（`XiaoZhangGuiApp.swift:75` 在启动时调用）。
- 通知 ID 稳定规则：基于 SwiftData 模型 `notificationID`（UUID）；旧数据为空时用 FNV-1a 哈希种子拼伪 UUID（`stableID`/`deterministicUUID` 行 130–151）。
- 调用点：`AppRepository`（CRUD）、`XZGAppIntents`（AI 新增待办）、`BackupService` 恢复后重建全部。
- **完整通知表见第 5 节**。

### 4.2 SnapshotBuilder（`SnapshotBuilder.swift`）—— 纯计算，无副作用

`makeSnapshot(todos, performances, expiryItems, customers, now)`（行 13）产出 `BusinessSnapshot`：
- 今日营业额 = 当日 Performance 金额和；日目标达成率 = 今日营业额 / (月目标/30) × 100（整数 %）。
- 今日待办数（含无截止 = 今天可做）、逾期数（due < 今日 0 点）。
- 下一条待办：未来有截止的最早一条，无则取第一条 pending；标题需「有意义」（`isMeaningfulActionTitle` 行 160：排除「记录/待办/提醒/语音记录/新建待办」）；若无则 fallback 配送中客户需求（`roomOrAddress · content`）。
- 配送中客户需求数（按 updatedAt 倒序）。
- 7 天内临期（pending 且 0≤daysLeft≤7，按到期日升序）；最近一条的名称+剩余天数。
- **焦点事项**（Widget 2.0，`WidgetDashboard.selectFocusItems`）：优先级 逾期待办 → 今日待办 → 客户配送 → 紧急临期，**最多 2 条**，按稳定 id 跨类别去重；待办可勾选（completable=true），配送/临期仅展示。

### 4.3 SnapshotSyncManager（`SnapshotSyncManager.swift`）—— 同步中心

链路：SwiftData fetch → `SnapshotBuilder` 计算 → App Group UserDefaults（`business_snapshot_v1`）→ `WidgetCenter.shared.reloadAllTimelines()` → `LiveActivityManager.update`。
- 失败语义：任一 fetch 失败 → `buildSnapshot` 返回 nil → `commit` **保留旧快照，绝不用空快照清零**。
- 调用点：App scenePhase 变化（`XiaoZhangGuiApp.swift:80,102`）、Repository 每次写库后、Backup 恢复后、App Intents 写入后。

### 4.4 LiveActivityManager（`LiveActivityManager.swift`）

- `startIfNeeded`：App 进入前台时启动/复用**当日**活动（`activityID = "today-YYYY-M-D"`，跨天自动结束旧活动）；`ActivityAuthorizationInfo().areActivitiesEnabled` 门控；staleDate = 次日 0 点；需 Info.plist `NSSupportsLiveActivities=YES`。
- `update`：快照变化时更新所有运行中活动。
- state 内容：nextTodoTitle（过滤含「的天气」的标题、空标题）、nextTodoTime、todoCount（今日+逾期）、deliveringCustomerCount、urgentExpiryCount、updatedAt。
- `endAll()` 预留（设置页可提供开关——目前未接 UI）。

### 4.5 WidgetTodoCompletion（`WidgetTodoCompletion.swift`）—— Widget 勾选待办

`complete(todoID, context)`：按 `Todo.notificationID` 查找 → **只置完成不 toggle**（幂等，已完成则保持首次 completedAt 不变）→ `context.save()` → 撤销该待办通知（与 `TodoRepository.toggleComplete` 完成分支一致）→ 用 `SnapshotBuilder` 重建快照返回。找不到 ID 抛 `todoNotFound`（Widget 显示失败，不假成功）。

---

## 5. 通知全表

| 类型 | 触发条件（调度） | 内容模板 | 取消条件 |
|---|---|---|---|
| 待办截止提醒 | `scheduleTodo`：设置 `todo_reminder` 开启（默认 true）**且** 有 dueDate **且** due > 现在 **且** 未完成。触发器：`UNCalendarNotificationTrigger` 精确到年月日时分（`NotificationManager.swift:22`） | 标题「待办提醒」/ 正文=待办标题 / 默认声音 | `cancelTodo`：待办完成、删除、dueDate 被清空/改为过去（`AppRepository.swift:28,38,46`）；ID：`todo-<notificationID>` |
| 临期退货提醒 | `scheduleExpiry`：设置 `expiry_reminder` 开启（默认 true）**且** `status == .pending`。触发时间：到期日前 `remindDaysBefore` 天 **9:00**；若计算出的触发时间已过去则不调度（`NotificationManager.swift:47`） | 标题「临期退货提醒」/ 正文：「「<名称>」还有 <N> 天到期（<数量> 件）」或已到期版「「<名称>」已到期，尽快处理（<数量> 件）」/ 默认声音 | `cancelExpiry`：状态离开 pending（处理/删除）、到期日/提前天数修改后重排（`AppRepository.swift:218,228,236`）；ID：`expiry-<notificationID>` |
| 客户需求跟进 | `scheduleCustomerFollowUp`：**仅 pending 状态**，新增时安排「1 小时后」提醒。触发器：`UNTimeIntervalNotificationTrigger(3600)`（`NotificationManager.swift:87`） | 标题「配送需求待跟进」/ 正文=`content` + `roomOrAddress` 以「 · 」连接（去空）/ 默认声音 | `rescheduleCustomer` 先取消全部后缀（-followup/-delivery/-custom）再按当前状态重排；离开 pending 立即取消（`NotificationManager.swift:81,100`；`AppRepository.swift:256,265,278`）；ID：`customer-<notificationID>-followup` |

调度入口汇总：`AppRepository` 各 CRUD（行 20/28/29/38/40/46、212/218/219/228/230/236、256/261/265/278）、`XZGAppIntents.swift:44`（AI 建待办后）、`BackupService.swift:331–335`（数据恢复后重建全部通知）。

---

## 6. Widget / LiveActivity 内容

### 6.1 主屏 Widget `TodayStatsWidget`（`XiaoZhangGuiWidget/TodayStatsWidget.swift`）

- 数据源：App Group UserDefaults `business_snapshot_v1`（JSON ISO8601），Timeline 在当日 0 点与次日 0 点各刷新（跨天归零），主 App 数据变化时 `reloadAllTimelines` 主动推。
- `systemSmall`「快捷工作台」：顶部「你的小掌柜」品牌行 → 「问小掌柜」大按钮（深链 `xzg://ai`）→ 「语音记录」大按钮（深链 `xzg://voice`）→ 底部状态行（`WidgetDashboard.statusLine`：逾期 N 个 > 今日 N 个 > 配送 N 个 > 临期 N 件，优先级；全无→「今天都安排好了」）。
- `systemMedium`：左列「今日营业额 ¥<千分位>」；右列最多 2 条焦点事项（待办圆圈可点 AppIntent 勾选完成；配送/临期仅展示）+ 右下「问小掌柜」「语音记录」胶囊。
- 锁屏：`accessoryInline`「¥X · 待办N 临期M」单行；`accessoryCircular`「今日」+ 大数字（≥10000 显示 x.x万）；`accessoryRectangular`「你的小掌柜」+「今日 ¥X · 待办 N」+ 下一行（下一件事 / 临期：X 还剩N天 / 临期 N 件）。
- 视觉：`.thinMaterial` 系统材质底、`.primary/.secondary` 语义色、自适应 Light/Dark/Tinted/Clear/Dynamic Type；品牌色内联 `#3A70B7`（注释说明 App Group 主题同步未验证前用 fallback）。
- Deep Link（`SharedKernel/WidgetFocusItem.swift` 尾部 `XZGWidgetLink`）：`xzg://ai` → AI 输入页（切 assistant Tab）、`xzg://voice` → VoiceView（onAppear 即开始监听）。URL scheme `xzg` 在 project.yml 注册（`INFOPLIST_KEY_CFBundleURLTypes`）。

### 6.2 Live Activity（`XiaoZhangGuiWidget/BusinessLiveActivityWidget.swift`）

- 锁屏卡片：深色实体底；头部品牌砖（storefront.fill 渐变绿）+「今日经营」+ 更新时间；焦点卡（「下一件」+ 标题 + 时间胶囊，无待办时「今日事项已清空 / 辛苦啦，记得盘点营业额」）；底部指标条：待办 / 配送 / 临期三指标。
- 灵动岛：compactLeading 店铺图标；compactTrailing 按优先级显示单一指标（临期⚠琥珀 > 配送中绿 > 待办数）；expanded：左「待办 N 件」、中店铺图标+「今日经营」、右「配送中 N 单」+ 临期警告、底部「下一件：<标题><时间>」或「今天暂无待办」；minimal 店铺图标。

### 6.3 App Intent（`XiaoZhangGuiWidget/Intent/CompleteTodoIntent.swift`）

Widget 上点待办圆圈 → `CompleteTodoIntent(todoID:)` 在扩展进程内直接打开**同一 App Group SwiftData store**（`WidgetIntentStore` 缓存容器）→ `WidgetTodoCompletion.complete` 写库 → 快照 save → `reloadAllTimelines` → LiveActivity 更新。App Group 不可用时显式抛 `sharedStoreUnavailable`。

---

## 7. 扫呗去重与字段映射规则

### 7.1 fingerprint 生成（`SaobeiCSVParser.swift:189` `SaobeiFingerprint.make`）

```
有订单号：  basis = "saobei|<orderNo>|<cents>"            （cents = round(amount*100)）
无订单号：  basis = "saobei|<unix秒>|<cents>|<paymentMethod>|<rawLine>"
fingerprint = SHA256(basis) hex
```
- **同一文件内**去重与**跨文件**去重统一走 fingerprint：`SaobeiImportSheet.existing` = 全库 Performance.fingerprint 非空集合；`newRows` 过滤已存在；`duplicateCount` 计数。
- commit 阶段（`AppRepository.swift:113`）再做一次集合检查：库中已存在或**本批次内重复**（`seen` 集合）→ duplicates+1 跳过；仅新增落库。
- OCR 行：fingerprint = `"ocr-" + sourceKey`，其中 sourceKey = `"<unix时间>|<金额文本>|<行上下文>|line-<行号>"`（同一截图重导稳定去重）。
- Demo 行：`demo-import-HHMM`。

### 7.2 字段映射

| 扫呗列（关键词匹配） | SaobeiParsedRow | Performance 落库 |
|---|---|---|
| 交易时间/交易日期/完成时间/支付时间/交易完成时间/时间 | date（8 种格式+ISO8601，`TimeZone.current`） | date |
| 收款金额/实收金额/交易金额/订单金额/支付金额/金额 | amount（清洗 `,，¥￥`，必须 > 0） | amount |
| 交易状态/订单状态/状态/支付状态 | status；`isSuccess` 判定：含失败关键词（退款/已退款/失败/关闭/已取消/已关闭/撤销/fail）→ false；含成功关键词（成功/支付成功/已支付/已完成/交易成功/success/SUCCESS/完成）→ true；**状态为空 → 视为成功**；未知 → false（未计入 skipped） | ——（仅成功行写入） |
| 订单号/商户订单号/流水号/交易单号/平台订单号/商户单号 | orderNo | orderNo |
| 支付方式/支付类型/付款方式/渠道 | paymentMethod | paymentMethod；note = "扫呗" 或 "扫呗 · <支付方式>"；incomeSource = `IncomeSource.from(note: paymentMethod)` |
| —— | fingerprint | fingerprint；importSource = "saobei" |

- 非成功行不进入 `rows`，计入 `skipped`（文案「第 N 行未计入（<状态>）」）；解析失败行计入 `errors`（「第 N 行无法解析」）。
- 导出回环：`SaobeiExporter.exportCSV` 表头固定「交易时间,交易状态,订单号,支付方式,收款金额」，可被同一解析器重新导入（`SaobeiRoundTripTests` 覆盖）。

---

## 8. entitlements capabilities 与 Android 等价方案

### 8.1 主 App `XiaoZhangGui/XiaoZhangGui.entitlements`（唯一 capability）

| capability | 说明 | Android 等价 |
|---|---|---|
| `com.apple.security.application-groups` = `group.com.xiaozhanggui.ios.shared` | App 与 Widget Extension 共享 UserDefaults（快照）与 SwiftData store | 无需等价：Android 单进程/单 App 内 Room + DataStore 直接共享；Widget（AppWidgetProvider）与主 App 同 UID 可直接读同一数据库。注意 iOS 靠 App Group 跨**进程**，Android Widget 同进程直接访问即可 |

**没有** iCloud（`com.apple.developer.icloud-*` 缺失）、**没有**推送 entitlement（`aps-environment` 缺失 —— 通知全是本地 `UNUserNotificationCenter`，无远程推送）、**没有** HealthKit、Siri、Associated Domains。

### 8.2 Widget Extension `XiaoZhangGuiWidget/XiaoZhangGuiWidgetExtension.entitlements`

仅 App Group（同上）。Android 等价：App Widget 直接读 Room，无需跨进程方案。

### 8.3 project.yml 声明的其它系统能力（非 entitlement，但在 Info.plist / 构建链中）

| 能力 | 位置 | Android 等价 |
|---|---|---|
| 麦克风 `NSMicrophoneUsageDescription`「语音记一笔时需要使用麦克风进行识别」 | project.yml:37 | `RECORD_AUDIO` 运行时权限 + `SpeechRecognizer` |
| 语音识别 `NSSpeechRecognitionUsageDescription`「用于将你的语音转换为经营记录」 | project.yml:38 | `SpeechRecognizer`（Google 语音服务；注意国内设备可能缺失，需降级方案） |
| 定位 `NSLocationWhenInUseUsageDescription`「用于显示本地天气，仅在前台使用，不会上传位置」 | project.yml:39 | `ACCESS_COARSE_LOCATION`（精度要求仅 km 级，对应 `kCLLocationAccuracyKilometer`） |
| Live Activities `NSSupportsLiveActivities: YES` | project.yml:43 | 无系统等价：可用**持续性通知**（ongoing notification + 自定义布局）模拟锁屏/状态栏实况；或桌面小组件承担 |
| URL scheme `xzg://`（ai / voice 深链） | project.yml:INFOPLIST_KEY_CFBundleURLTypes | App Links / Deep Link intent-filter（`xzg://ai`、`xzg://voice`） |
| 天气 API Key 构建注入 `XZGWeatherAPIKey` | project.yml:45–48 | BuildConfig / local.properties 注入，不进仓库 |

---

## 9. iOS-only API 清单与 Android 等价

| iOS API | 用途（文件） | Android 等价方案 |
|---|---|---|
| `UIScreen.main.brightness`（可写） | 收款码全屏拉高亮度 `PaymentCodeBrightnessGuard.swift` | `WindowManager.LayoutParams.screenBrightness`（Activity window attributes，0–1；退出恢复；kill 兜底用 DataStore 标记 + Application.onCreate 恢复） |
| `UNUserNotificationCenter` / `UNCalendarNotificationTrigger` / `UNTimeIntervalNotificationTrigger` | 本地通知 `NotificationManager.swift` | `AlarmManager.setExactAndAllowWhileIdle`（精确日历触发）+ `NotificationManagerCompat`；`WorkManager` 做一次性延时（1 小时跟进）；Android 12+ 需 `SCHEDULE_EXACT_ALARM` 权限，注意 OEM 电池优化 |
| `WidgetKit` Timeline / `StaticConfiguration` / accessory families | 主屏/锁屏小组件 `TodayStatsWidget.swift` | `AppWidgetProvider` + RemoteViews；锁屏小组件 Android 不支持锁屏 widget（Android 5+ 已移除），accessoryInline/Circular/Rectangular 无直接等价 → 用通知或标准小组件尺寸替代 |
| `ActivityKit` / `Activity.request` / DynamicIsland | 灵动岛/锁屏实况 `LiveActivityManager.swift`、`BusinessLiveActivityWidget.swift` | 无等价；用**持续性通知**（ongoing + 自定义 RemoteViews 布局 + 定期更新）近似；Pixel 的 Live Updates（Android 16）可评估但非全机型 |
| `AppIntents`（`CompleteTodoIntent`） | Widget 上直接勾选待办 `Intent/CompleteTodoIntent.swift` | 小组件按钮 → `PendingIntent` → BroadcastReceiver/Service 直接写 Room（同进程，无需跨进程容器） |
| App Group（`UserDefaults(suiteName:)` + 共享 SwiftData store） | 跨进程数据共享 `SharedKernel/AppGroup.swift`、`CompleteTodoIntent.swift` | 不需要：同 UID 直接共享 Room/DataStore |
| `PhotosPicker` / `PhotosPickerItem.loadTransferable` | 收款码选图、扫呗截图选择 `PaymentCodeView.swift`、`SaobeiImportSheet.swift` | `ActivityResultContracts.PickVisualMedia` / `GetContent`；security-scoped resource 对应 `ContentResolver.takePersistableUriPermission` |
| `fileImporter(allowedContentTypes:)` | 扫呗文件选择 `SaobeiImportSheet.swift` | `ActivityResultContracts.OpenDocument`（`*/*` + mimeType 过滤） |
| Vision `VNRecognizeTextRequest` | 截图 OCR `SaobeiScreenshotOCR.swift` | ML Kit Text Recognition（`com.google.mlkit:text-recognition-chinese` 中文模型；离线可用，需打包模型体积评估） |
| `Compression` framework（raw DEFLATE） | XLSX 解压 `SaobeiXLSXParser.swift` | `java.util.zip.Inflater`（nowrap=true = raw DEFLATE）+ `ZipInputStream`；自研 MiniZip 可整体替换为标准库 |
| `CLLocationManager` / `requestWhenInUseAuthorization` | 天气定位 `LocationManager.swift` | `FusedLocationProviderClient.getCurrentLocation`（`PRIORITY_BALANCED_POWER_ACCURACY`，对应 km 级精度）+ `ACCESS_COARSE_LOCATION`；4 秒超时用协程 `withTimeout` |
| `SFSpeechRecognizer` / 语音（Speech 权限文案存在） | 语音识别（Voice Feature，权限在 project.yml:37–38） | `SpeechRecognizer` + `RECORD_AUDIO` |
| CryptoKit `SHA256` | 扫呗 fingerprint `SaobeiCSVParser.swift:189` | `java.security.MessageDigest("SHA-256")` |
| `JSONEncoder.iso8601` / `JSONDecoder.iso8601` | 快照/metadata 序列化 | kotlinx.serialization（`@Serializable` + ISO-8601）或 Gson |
| `NumberFormatter`（千分位） | Widget 金额格式化 `SharedKernel/WidgetFocusItem.swift` `WidgetDashboard.formatRevenue` | `java.text.NumberFormat.getNumberInstance(Locale.CHINA)` |
| `XMLParser` (SAX) | XLSX 解析 `SaobeiXLSXParser.swift` | `javax.xml.parsers.SAXParser`（Android 内置） |
| `NSRegularExpression` / ICU 正则 | OCR 日期/金额提取 | `java.util.regex`（注意 `\d` 与 Unicode 数字差异，中文语境建议显式 `[0-9]`） |

---

## 10. Tests 覆盖情况

`Tests/`（unit-test target，`Tests/UITests` 除外）。与 E 部分相关的测试文件：

| 测试文件 | 行数 | 覆盖内容 |
|---|---|---|
| `Tests/PaymentCodeTests.swift` | 274 | metadata 空加载/round-trip/顺序保持（53–94）；增删改查：图片落盘+order 递增、空名回退类型名、删除同时删文件、删一条不影响其它、替换删旧文件、非法图片保留旧图、缺失/损坏文件返回 nil 不崩、重命名持久化（94–181）；亮度守卫：begin 保存并拉高、end 恢复清标记、重复 begin 不覆盖、end 无 begin 无副作用、启动恢复（遗留标记恢复合法值/无标记不动/非法值只清标记）（183–248） |
| `Tests/SaobeiImportTests.swift` | 102 | 同文件重复行只插入一次、库内+文件内重复都计数、全 distinct 插入且 skippedFailed 透传、全重复时零插入不落库（30–90） |
| `Tests/SaobeiImporterTests.swift` | 44 | CSV 成功行解析、重导 fingerprint 稳定、缺表头失败、金额去货币符号、状态判定（5–39） |
| `Tests/SaobeiRoundTripTests.swift` | 72 | XLSX/CSV 导出→导入字段保留、XLSX 非 CSV 伪装（17–63） |
| `Tests/WeatherAPIProviderTests.swift` | 145 | stub URLProtocol：GPS 成功用 API 真实城市名（即使默认配置是恩平）、fallback 保留配置城市、茂名等真实城市名解析、3 天预报解码含天气状况（33–66） |
| `Tests/Widget2Tests.swift` | 295 | 焦点优先级（逾期→今日→配送→临期）、无待办时 fallback、最多 2 条、跨类别按稳定 id 去重、类别内保序、limit=0、长标题不截断、状态行优先级、金额格式化、深链常量精确路由、旧 JSON 无 focusItems 解码兼容、focusItems round-trip、Widget 勾选完成重建快照、幂等不 reopen、未知 ID 抛错不假成功、空快照对 Widget 安全（17–275） |
| `Tests/SnapshotSafetyTests.swift` | 89 | 真实数据构建快照成功、fetch 失败返回 nil、commit(nil) 保留旧快照（16–60） |

**未覆盖（缺口）**：
- `NotificationManager` 无直接单元测试（调度/取消规则仅靠 `AppRepository` 集成路径与人工验证；无通知内容模板断言）。
- `LiveActivityManager` 无测试（注释明确「需 Mac/Xcode 真机验证」）。
- `LocationManager` 授权/超时分支无测试。
- `SaobeiScreenshotOCR.candidates(from:)` 纯函数可测但无测试文件。
- `SaobeiXLSXParser` 的 MiniZip/解压路径仅靠 RoundTrip 间接覆盖。
- `PaymentCodeFullScreenView` 的 scenePhase 亮度恢复无 UI 测试。

---

## 11. Android 迁移风险点汇总

1. **亮度控制权限差异**：iOS `UIScreen.brightness` 任意设置；Android `screenBrightness` 需在 Activity window 上设置（`Settings.System.WRITE_SETTINGS` 仅用于全局），退出/异常 kill 的恢复标记需自己实现（DataStore + Application 启动检查）。
2. **精确闹钟权限**：待办/临期通知依赖精确时间触发；Android 12+ `SCHEDULE_EXACT_ALARM` 为特殊权限、用户可撤销，小米/华为等 OEM 后台限制需引导用户加白名单，否则通知延迟或丢失。
3. **无灵动岛/锁屏小组件**：LiveActivity + 锁屏 accessory families 在 Android 无系统等价；建议降级为持续性通知 + 主屏小组件，并在 `ANDROID_V36_PLATFORM_DIFFERENCES.md` 明确记录行为差异。
4. **Widget 跨进程简化**：iOS 为跨进程做了 App Group + 双 target 编译复用；Android 同进程，`CompleteTodoIntent` 的整套容器复用逻辑可删除，直接 Room 写库。
5. **OCR 模型体积**：ML Kit 中文识别模型需随包或动态下载；iOS Vision 为系统内置零体积。
6. **XLSX 自研解析器可丢弃**：Android 有 `java.util.zip` 标准库 + SAXParser，MiniZip/`Compression` hack 整段可替换为标准实现，但**字段映射/去重规则必须逐字保留**。
7. **扫呗状态语义**：「状态为空视为成功」「未知状态视为未计入」是反直觉但有意的业务规则（`SaobeiCSVParser.isSuccess` 行 151），迁移时不要「修正」。
8. **天气 Key 注入链**：CI secret → BuildConfig 注入，不进仓库；沿用现有链路设计。
9. **通知 ID 稳定性**：iOS 用 `notificationID`（UUID，存于 SwiftData 模型）做通知标识；Android Room 实体需保留同名字段，AlarmManager 的 PendingIntent requestCode 需从该 UUID 稳定派生（不能用自增 int）。
10. **隐私硬约束**：收款码图片绝不进 AI/网络（`PaymentCodeModel.swift` 头部注释为硬性约束）；Android 迁移需在 Repository 层同样隔离，并在 parity matrix 标注。

---

*报告完。共审计 36 个源文件（PaymentCode 6 / Import 8 / Weather 4 / Services 5 / Widget 6 含 Intent / SharedKernel 4 / project.yml / entitlements 2）。未修改任何代码。*
