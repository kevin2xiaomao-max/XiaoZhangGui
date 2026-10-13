# Android V3.7.1 差异审计（V3.6 → V3.7.1）

> iOS Source of Truth：`integration/v371-grok-thinking-fixes @ d238ff00`（3.7.1 / build 37，只读，**严禁修改**）
> Android 基线：`android/v3.6 @ b97e801` → 开发分支 `android/v3.7.1-oppo-port`（**复用升级，不从零做**）
>
> 本文档为 Phase 0 审计结论，供 Phase 1–4 实施使用。用户三条强制要求贯穿全文：① 数据兼容性 ② R01–R29 验收基线（见 `ANDROID_V371_PARITY_MATRIX.md`）③ 持久签名（见 `ANDROID_V371_OPPO_VERIFICATION.md` 签名方案节）。

---

## 1. 结构差异（导航/信息架构）

| # | V3.6（Android 现状） | V3.7.1（iOS 基线） | Android 改造点 | 阶段 |
|---|---|---|---|---|
| 1 | 五 Tab：首页 / 日程 / 小掌柜 / 待办 / 我的（`ui/navigation/XzgTab.kt`） | 四 Tab：首页（house.fill）/ 待办（checkmark.circle）/ 日历（calendar）/ 经营（chart.bar.fill），原生 TabView | 重写 `XzgTab.kt` 四 Tab；删除「小掌柜」Tab；「日程」改名「日历」 | Phase 2 |
| 2 | AI = 独立 Tab（`AIChatScreen.kt`）；深链 `xzg://ai` → `OpenAssistantTab` | AI 不再是 Tab：首页 `AICommandEntry`（thinMaterial，「问小掌柜」+ 副标题 + chevron，点击 `showAI=true`，a11y `home.ai`）弹 AI Sheet；深链 `xzg://ai[?mode=voice]` 进 AI Sheet，`mode=voice` 同步拉起 `ShortVoicePanel` | 新建 AI Sheet 容器 + `AICommandEntry` 组件；`XzgDeepLink.kt` 中 `OpenAssistantTab`/`OpenAssistantVoice` 语义改为开 Sheet；新增短语音面板（V3.6 无此组件） | Phase 2 |
| 3 | 「我的」为独立 Tab（`ProfileScreen.kt`） | 「我的」走首页右上角头像（person.crop.circle.fill，a11y「个人中心」`home.profile`）→ `navigationDestination` 进 Profile | 首页 header 加头像按钮；Profile 改为导航目的地（非 Tab） | Phase 2 |
| 4 | 首页 Hero 为蓝色大卡片（V32 口径） | 首页平面 Editorial：Header（日期 + 天气按钮 / 记一笔胶囊 + 头像；第二行大问候）→ `heroFlat`（「今日营业额」+ ¥54pt 大数字 +「较昨日 ±x.x% · 月目标 xx%」，可点击进经营）→ AICommandEntry →「今日重点」（GroupSurface 三 WorkRow：客户配送 / 今日待办 / 临期退货，行间 hairline）→「接下来」（TimedRow 最多 3 项，彩色 accent 条；空则 EmptyState） | 首页重构为 Editorial 布局；Hero 去蓝化 | Phase 2 |
| 5 | 设计 token V32 口径（`Color.kt` / `Type.kt` / `Dimens.kt` / `Motion.kt` / components/） | V371 token：S0 页面底 Light `#F4F4F7` / Dark `#08080B`；S1 分组面 Light `#FFFFFF` / Dark 深灰黑（圆角 24 solid，**禁用 material**）；S1 GroupSecondary 嵌套小块；S2 蓝渐变 `#4A9CFF→#2B6EF2`（**仅**天气详情 sheet 用，首页/日历禁用）；S3 仅 Dock / AI command 允许 ultraThinMaterial；状态色 蓝 `#2E75F5` / 绿 `#21A359` / 橙 `#E8910D` / 红 `#E6474D` / 黄 `#C99900`（Dark 提亮）；Typography（heroNumber 44 bold rounded 等宽 / heroTitle 15 semibold / sectionTitle 17 semibold / rowTitle 16 medium / rowSubtitle 13 regular / time 13 semibold 等宽 / badge 12 semibold / quickAction 12 medium）；Space（page 16 / section 20 / rowGap 12 / rowPadding 14）；Radius（control 12 / tile 20 / group 24 / hero 28 / pill 999）；Shadow（hero 蓝 0.25 alpha r18 y8 / floating 黑 0.10 r16 y6）；Motion（instant 0.10 / fast 0.18 / standard 0.28 / emphasized 0.42s，spring 复用 V32Motion，pressScale 0.97，Reduce Motion 全走 V32Motion.resolve）；Haptic 唯一定义点 FloatingDock | 新建 V371 设计系统（与 V32 并存或替换，Phase 2 决策）；11 Primitives 对齐：HeroMetric、GroupSurface、SectionHeader、WorkRow（36×36 图标圆 + 标题/副标题 + trailing，最小高 60）、TimedRow（左侧 4pt 彩色条 + 时间列）、StatusBadge、QuickAction/QuickActionRow、EmptyState、FloatingTabDock、AICommandEntry | Phase 2 |
| 6 | 备忘入口在待办 Tab「备忘」segment | 备忘（R13）入口迁至经营 Tab menu →「记录」→ navigationDestination；编辑器（R14）仍为 sheet | 备忘导航入口迁移 | Phase 2 |
| 7 | （无短语音面板） | AI 页语音按钮拉起 `ShortVoicePanel`（R28） | 新建短语音面板组件 | Phase 2 |

**iOS 基线冲突注意**（以当前基线源码为准，不以旧审计文档为准）：
- 设计系统版 `AICommandEntry` / `QuickActionRow` / `FloatingTabDock` 在 iOS 基线零调用（首页用私有 `AICommandEntry` 变体；RootView 用原生 TabView，悬浮 dock 已退役）——Android 移植时**按实际调用形态实现**，不照抄零调用的设计系统版。
- S2 蓝 Hero 仅天气详情 sheet 用，首页/日历名存实亡——Android 同样禁用。
- `HomeRoute.memo` 是死分支；死代码忽略清单：`V35SideUtilityDrawer` / `V35DrawerDestination`、`MemoCard`、TodoView 私有 `RecordEditorSheet`——**不移植**。
- `V371_PRODUCTION_UI_AUDIT.md` 是 ui-redesign 分支的旧审计，与当前基线多处冲突，**以当前基线源码为准**。

---

## 2. 数据语义差异

| # | 差异 | iOS 基线行为 | Android 现状 | Android 改造点 | 阶段 |
|---|---|---|---|---|---|
| 1 | `Performance.incomeSource` **新增字段** | 默认空字符串；旧记录 fallback 从 note 关键词派生；`PerformanceRepository.add` 新增 `incomeSource: IncomeSource = .store` 参数；扫呗导入按 paymentMethod 派生 incomeSource，库内 + 文件内双重 fingerprint 去重；统计仍按业务 date | 无此字段；扫呗去重仅 fingerprint（`SaobeiImportTest`） | Room Entity 加字段 + **Migration**（见 §5 破坏性风险）；Repository.add 加参数；扫呗导入派生 incomeSource + 双重去重 | Phase 1 |
| 2 | Goods 删除确认 | `confirmationDialog`（"删除后无法恢复"）+ 失败显式提示；新增/编辑保存失败仍静默；QuickRecord 缺名标题回退"临时商品" | 删除无确认（V3.6 行为） | 商品删除加确认对话框 + 失败提示；QuickRecord 缺名回退"临时商品" | Phase 1 |
| 3 | Customer 通知取消规则 | 离开 pending 立即取消跟进通知；delivering 不重排；update 统一重排 | 待核实（`NotificationSideEffectsTest` 覆盖 V3.6 规则） | 对齐三条规则 | Phase 1 |
| 4 | 通知标识 | 统一为 `notificationID`（UUID v4） | `expiry_items` 有 `notificationId`；其他实体待核实 | 全实体统一 notificationID（UUID v4） | Phase 1 |
| 5 | 备份恢复 | 恢复后重建三类通知 + 快照刷新；恢复=追加不清空（不走 Repository，直接构造实体 + 单次 save）；v1 兼容 | `BackupCodec.kt` + `BackupService`（formatVersion=2，epoch millis，图片 base64，坏记录跳过）；恢复后行为待核实 | 对齐恢复语义（追加/直接构造/单次 save/通知重建/快照刷新） | Phase 1 |

---

## 3. AI 架构差异（5 tools 不变，架构升级）

| # | 差异 | iOS 基线行为 | Android 现状 | Android 改造点 | 阶段 |
|---|---|---|---|---|---|
| 1 | Tool 数量 | **5 tools 不变**：`searchRecords`（READ 自动）/ `recordRevenue` / `createTodo` / `createMemo` / `createDelivery`（后四个 CREATE，需确认），`ToolCatalog.swift` liteTools | 5 tools，`ToolName` wireName 与 iOS 1:1 ✅ | 保持 5 tools，不增不减 | — |
| 2 | 执行桥 | 唯一执行桥 `RepositoryToolExecutor`（AI 目录外；AI 目录内零 `context.insert/delete`） | 已有 `RepositoryToolExecutor`（走 4 Repository，无 DAO 直接调用）✅ | 复用；审计确认 AI 目录内无直接 DAO 调用 | Phase 1 |
| 3 | PendingAction 持久化 | 持久化到 Application Support/AI/`pending-actions.json`，不进数据库 | 持久化到 `filesDir/AI`，不进 Room ✅ | 复用；对齐状态机（pending/confirmed/executed/duplicate/failed/cancelled） | Phase 1 |
| 4 | 防重放 | `ExecutionJournal` 业务指纹防重放 | 已有 `ExecutionJournal`（toolCallId + 指纹）✅ | 复用 | Phase 1 |
| 5 | 装配 | fail-closed 装配（误装 Preview 直接抛错）；`ToolCatalog` JSON Schema | 待核实 fail-closed 装配 | 补 fail-closed 装配检查 | Phase 1 |
| 6 | 主 Provider | 固定 **DeepSeek**（api.deepseek.com）；模型 Picker 仅 `deepseek-flash`（默认）/ `deepseek-v4-pro`（旧值自动迁移） | `OpenAiCompatProvider`（OkHttp）+ `ProviderChain`；当前配置待核实 | 主 Provider 固定 DeepSeek；模型二选一 + 旧值迁移 | Phase 1 |
| 7 | 备用 Provider | 用户自定义 OpenAI 兼容端点（端点 + 模型 + Key 齐全才启用） | 待核实 | 对齐启用条件 | Phase 1 |
| 8 | Failover | ProviderChain 只 failover **1 次**（仅网络/超时/429/5xx；401/403 不换链） | `ProviderChain` 已有；failover 次数/条件待核实 | 对齐 1 次 + 条件白名单 | Phase 1 |
| 9 | 连接测试 | 发最小 chat（"ping"，不带工具/数据） | 有连接测试；**Manifest 缺 INTERNET，当前无法联网** | **Phase 1 必补 INTERNET 权限**；对齐 ping 语义 | Phase 1 |
| 10 | 密钥存储 | 只存 Keychain（`kSecAttrAccessibleAfterFirstUnlock`），绝不进 UserDefaults/日志；搜索默认 disabled | security-crypto 1.1.0 已引入；存储位置待核实 | 密钥只存 Android Keystore（EncryptedSharedPreferences）；绝不进 DataStore 明文/日志；搜索默认 disabled | Phase 1 |
| 11 | `createMemo` 解析 | 本地解析器 title prefix(20) | 待核实 | 对齐 prefix(20) | Phase 1 |
| 12 | `createDelivery` 编码 | **不走** `xzg-delivery-v1` 编码（deliveryTimeText 只拼进 content 文本）；只有手工编辑器走编码 | 待核实（`CustomerDeliveryCodecTest` 覆盖编码本身） | **如实保留**：AI 创建不走编码，手工编辑器走编码 | Phase 1 |

Voice / QuickRecord 双解析器**与 V3.6 一致，无需改动**（复用）：
- `VoiceParser`：独立，支持 expense（关键词"进货/支出/花了"），缺金额报错（收入→"请补充收入金额"，支出→"请补充支出金额"），直写无确认卡（`VoiceParserTest`）。
- `QuickRecordParser`：独立，不支持 Expense（performance/todo/customer/expiry/memo 五类），缺金额写 0，备忘 title prefix(20)，直写无确认（`QuickRecordParserTest`）。

---

## 4. 其他语义差异

| # | 差异 | 说明 | 阶段 |
|---|---|---|---|
| 1 | 日历周起始 | 日程周条周一起始（firstWeekday=2），月历网格周日起始（firstWeekday=1）；Android 现状待核实 | Phase 1（`DataSemanticsTest` 扩展） |
| 2 | 版本号 | versionCode 36 / versionName 3.6.0 → **versionCode 37 / versionName 3.7.1** | Phase 1（构建配置） |
| 3 | Manifest | **INTERNET 未声明（Phase 1 必补）**；已声明 RECORD_AUDIO / POST_NOTIFICATIONS / SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM / RECEIVE_BOOT_COMPLETED / FOREGROUND_SERVICE；深链接 scheme `xzg`，host=ai/voice/quickrecord/quick/todo（todo 为 Android 扩展，保留） | Phase 1 |
| 4 | R29 Storage 不可用态 | iOS：container 初始化失败自动呈现；Android V3.6 无此态 | Phase 1（fail-closed 装配） |

无 V3.8 / SleepDown 实验设计混入（已核查）。

---

## 5. 破坏性风险（独立小节）

> 用户强制要求①：Room 数据兼容性保留，**禁止 `fallbackToDestructiveMigration`**，优先验证覆盖安装和数据升级。

### 5.1 禁止项

- **禁止在任何 Database Builder 上调用 `fallbackToDestructiveMigration()`**（含 `fallbackToDestructiveMigrationOnDowngrade`）。Phase 1 起全库 grep 门禁，CI 可加 lint 规则。
- 禁止"清空重建"式数据修复：备份恢复 = 追加不清空（见 §2.5）；Demo Mode 切换清的是内存库，不碰磁盘真实数据（V3.6 已验证）。

### 5.2 Schema 变更必须走 Migration

- V3.7.1 已知的 schema 变更候选：`Performance.incomeSource` 新增字段；通知标识统一 `notificationID`（如需落库）。
- 任何 Entity 字段增删改必须编写 Room `Migration`（版本号递增），并配套 **Migration 测试**（`MigrationTestHelper`，验证旧库 → 新库数据不丢、默认值正确）。
- 变更冻结 7 Entity 语义（V3.6 结论延续）：todos / memos / customer_requests / performances / expiry_items / goods / payment_codes 的业务语义不变，只做加法。

### 5.3 数据升级回归测试（Phase 1 已落实）

回归测试：`android/app/src/androidTest/java/com/xiaozhanggui/app/migration/DataUpgradeRegressionTest.kt`
（fixture：同目录 `V1Schema.kt`，手写 v1 建表 SQL，逐字对应 Room 2.6.1 生成格式；
Room 打开时 `validateMigration` 自校验 SQL 正确性）：

- 用 `SQLiteOpenHelper`（version=1）手工构造 **V3.6 旧版本数据库文件**
  （7 表代表性数据：performances 2 条含扫呗导入记录、todos 2 条、
  customer_requests 1 条、expiry_items 1 条、goods 1 条、memos 1 条、expenses 1 条；
  注：收款码在 DataStore 不在 Room，不在 7 表内），
- 用新 App（V3.7.1 schema + `MIGRATION_1_2`）`Room.databaseBuilder(...).addMigrations(...)` 打开，
- 断言：7 表数据**零丢失**（行数 + 关键字段，含扫呗 fingerprint）；
  `incomeSource`：列已存在→值保留（真实 V3.6 设备路径），缺列→`ADD COLUMN` 默认 `""`
  且 `IncomeSource.fromPerformance` 回退派生正确；
  通知可重建：todo/expiry/customer 的 notificationId 跨升级保持有效 UUID v4；
  备份 round-trip：升级后库导出→解码记录数一致；
  版本号升至 2；全程无 destructive migration（数据存在即证明）。
- 双场景：`upgrade_v1_with_incomeSource_column_keeps_all_data` /
  `upgrade_v1_missing_incomeSource_column_gets_default_and_derivation`。
- 该测试在 CI 的 `e2e` job（`connectedDebugAndroidTest`，真 SQLite）中运行，
  是 Phase 1 的门禁项。

### 5.4 其他破坏性风险

| # | 风险 | 缓解 |
|---|---|---|
| 1 | 五 Tab → 四 Tab 导航大改：旧导航状态/深链缓存导致启动崩溃 | `XzgNavGraph` 重写后做冷启动三路测试（正常/深链/恢复）；E2E 覆盖 `xzg://ai`、`xzg://voice`、`xzg://quickrecord` |
| 2 | 深链接语义变更：`xzg://ai` 从"跳 AI Tab"变为"开 AI Sheet"；旧版本 App 的 intent-filter 缓存 | `XzgDeepLink.kt` 语义切换 + `DeepLinkParseTest` 更新；冷启动深链 E2E（V3.6 修过冷启动深链崩溃，回归） |
| 3 | AI Tab 删除：用户在旧版本停留在 AI Tab 时升级 | 升级后默认落首页；AI 会话历史保留（不进 Room 的 pending-actions.json 不受影响） |
| 4 | 覆盖安装签名冲突：CI 临时签名与用户侧载包签名不一致导致无法覆盖安装 | Phase 4 启用**持久签名证书**后统一签名（见 `ANDROID_V371_OPPO_VERIFICATION.md` 签名方案节）；过渡期用 `applicationIdSuffix` 并存方案 |
| 5 | Provider 切换：DeepSeek 固定主 Provider，旧自定义端点配置迁移 | 旧值自动迁移（`deepseek-v4-pro` 保留）；自定义端点配置保留，需用户确认后启用 |

---

## 6. 实现次序

- **Phase 1 数据/AI**：INTERNET 权限；versionCode 37 / versionName 3.7.1；`incomeSource` + Migration + 数据升级回归测试；Goods 删除确认；Customer 通知规则；notificationID 统一；AI Provider（DeepSeek 固定/模型二选一/failover 1 次/ping 测试/Keystore）；`createMemo` prefix(20) / `createDelivery` 不走编码；R29 fail-closed；备份恢复语义对齐。
- **Phase 2 四 Tab/UI**：四 Tab 导航重写；AI Tab → AI Sheet（`AICommandEntry` + 短语音面板）；我的 → 首页头像；首页 Editorial 重构 + V371 S0–S3 设计系统 + 11 Primitives；备忘入口迁移；Paparazzi 截图基线更新。
- **Phase 3 OPPO 专项**：见 `ANDROID_V371_OPPO_VERIFICATION.md`（ASR/通知/后台/性能/权限真机验证）。
- **Phase 4 签名/APK/交付**：持久签名证书启用；release APK 构建 + aapt 校验；验收报告（R01–R29 五项全绿）；安装说明。

---

## 7. 可复用模块（V3.6 直接复用，不重写）

- 7 Repository（含写后副作用：通知 schedule/cancel + `SnapshotRefresher.refreshAll()`）
- 双解析器：`VoiceParser`（`VoiceParserTest`）、`QuickRecordParser`（`QuickRecordParserTest`）
- 备份：`BackupCodec.kt` + `BackupService`（`BackupCodecTest`）
- 通知调度器（`NotificationSideEffectsTest`）
- AI 执行链：`RepositoryToolExecutor` + PendingAction（filesDir/AI）+ `ExecutionJournal`（`AiIdempotencyTest` / `ToolIdempotencyTest`）
- 深链接解析：`XzgDeepLink.kt`（`DeepLinkParseTest`；仅改 `ai` host 语义）
- 扫呗解析：`SaobeiParser.kt`（`SaobeiImportTest`；加 incomeSource 派生）
- Paparazzi 截图基建（`BusinessScreenshotTest` / `PagesScreenshotTest` / `SheetScreenshotTest` / `ScheduleProfileAiScreenshotTest` / `XzgScreenshotTest`）
- Demo Mode（`DemoCatalogTest`）

---

## 8. 死代码忽略清单（不移植）

`V35SideUtilityDrawer` / `V35DrawerDestination`、`MemoCard`（iOS 侧）、TodoView 私有 `RecordEditorSheet`、`HomeRoute.memo` 死分支、设计系统版零调用 `AICommandEntry` / `QuickActionRow` / `FloatingTabDock`（按首页实际私有变体实现）。

---

## 9. SleepDown-derived candidate ideas（P0 文档归档，不影响移植进度）

> **许可证红线**：SleepDown 的 `LICENSE.md` 是自定义"署名非商业、源码可见 1.1"许可，**不是**宽松开源许可（研究报告 §4）。本节仅归档可学习的**交互原则 / 运动参数 / 架构思路**；**禁止直接复制** SleepDown 的 Kotlin / 着色器 / 资源 / 界面代码。如未来确需复用，必须先梳理第三方许可并独立实现。

- **已具备**（小掌柜已有，无需做）：
  - AI 五工具 + 确认卡（Pending Action）/ 写库门禁 / 幂等日志：`AgentCore` → Pending Action → 确认 → `RepositoryToolExecutor` → Repository → 幂等日志（Delta §7 可复用模块；**禁止重写已验收的业务执行链**）。
  - Compose + Room + DataStore 架构底座；通知调度（`NotificationSideEffectsTest`）；语音降级路径。
- **建议下一期（P1）**（首个 APK 交付后评估；只立项不实现）：
  - Android 自有 MotionSpec / MotionPolicy（本节 §10 立项）。
  - 非线性模糊强度滑杆映射（研究报告 §1 发现 3；仅当小掌柜已有壁纸 / 玻璃强度设置需优化时借鉴）。
  - 材质性能分级思路（研究报告 §1 发现 5）。
- **不可直接搬用**（架构不匹配）：
  - `OplusSeamlessBackend` 跨 Activity 转场 vs 小掌柜单 Activity NavHost（研究报告 §2）。
  - SleepDown 课程表复杂计划 vs 小掌柜店铺业务工具（研究报告 §3 P2 AI 审计）。
- **真机待验证**（PKJ110 + 当前 ColorOS 17 固件未验证前一律 `NOT VERIFIED`）：
  - Oplus 私有转场能力；端侧 ASR 可用性；精确闹钟行为。

---

## 10. P1 立项：Android 自有 MotionSpec / MotionPolicy（只立项，不实现）

- **范围**：首个 V3.7.1 真实 APK 交付后评估。**本期只立项，不写任何生产/动画代码**。
- 建立 Android 自有的 `MotionSpec` / `MotionPolicy`（名称可自行决定），与页面路由对应：
  - 每条适用路由记录 `transitionKind`（原生 / 淡入 / 共享锚点）、`performanceFallback`（低端设备降级路径）和测试状态（NOT RUN / PASS / FAIL）。
  - **不是把 29 条 iOS 路由变成 29 个 Android Activity**（单 Activity NavHost 架构不变）。
- 硬约束（研究报告 §3 P1）：
  - 简单状态变动统一 Motion Token 与动效时长；复杂长列表整体移动，避免逐行加 blur / graphicsLayer；
  - 动效**不得**改变导航可达性、点击区域、返回行为或弹窗保存/取消的语义；
  - 支持系统 Reduce Motion（退化为直接显示/淡入）；
  - 拖拽删除可参考自适应触发阈值（按屏宽计算），但不改变 iOS 既定删除确认、安全规则和数据事务——**不得为动画引入误删**。
- **优先三条真实路径**：首页 → AI Sheet、首页 → 快速记一笔、经营 → 编辑表单。
- 验收：逐项 PASS / FAIL / NOT RUN；帧率与视觉连续性以真机实测为准，模拟器通过不替代真机。

---

## 11. P2 立项：隔离原型（只立项，不实现）

### 11.1 动效与 OPPO 私有转场隔离原型

- **范围**：独立实验；**未通过验证不得合入 V3.7.1 稳定版**。
- 液滴 Morph：胶囊 / 按钮 → 菜单的连续变形，参考 SleepDown `HomeDropletMotion` 动作分层（收缩 → 位移 → 纵横伸展 → 内容显现 → 回归锚点）；260/300ms 参考参数仅作初始标尺，需真机测帧率与视觉连续性。
- 玻璃效果：**仅限** AI 输入、底部浮层、选择器等控制面；列表、经营数字和任务内容保持清晰，**禁止全屏雾化或卡片墙**。
- OPPO 私有转场 PoC：独立、可禁用；先用具名失败诊断（`runtimeClassMissing` / `requiredApiMissing` / `unsupportedVersion` / `sourceNotReady` / `unsupportedWindowMode`）探测运行时类、所需方法、版本、窗口模式和真实锚点；失败立即回退 Compose 标准路径；**不引入隐藏 API 绕过或 root 强依赖**；无真机视频/日志不记为支持。
- 回退开关：若试验造成卡顿、动画尾帧残影、黑屏或点击丢失，**立即回退**到稳定转场，主 App 不受影响。

### 11.2 AI 对比审计（只立项，先出审计报告，不开新功能）

- 对照 SleepDown `DAY_AGENT_RUNTIME` 的阶段划分：事实读取 → 工具调用 → 参数/权限校验 → 操作计划/确认卡 → Repository 写入 → 回读验证；对照小掌柜既有链（`AgentCore` → Pending Action → 确认 → `RepositoryToolExecutor` → Repository → 幂等日志）。
- 逐项标注：`ALREADY EXISTS`（已具备：AI 五工具 / 写库确认门禁 / 幂等日志 / 确认卡）/ `GAP`（缺口，需评估：错误可诊断性、重复调用幂等、上下文缓存有效性、失败不丢消息、多轮修正、云端无 Key / 无法联网的本地能力）/ `FUTURE CANDIDATE`（下一期候选）。
- **铁律：暂时禁止重写已验收的业务执行链**（`AgentCore` → Pending Action → 确认 → `RepositoryToolExecutor` → Repository → 幂等日志）；禁止擅自扩展 CRUD 权限、批量删除或重写 AI 运行时（研究报告 §3 P2）。
- SleepDown 课程表课程编辑的复杂计划**不能照搬**成店铺业务工具；相关计划结构需另做业务审查。
- 许可证红线适用（本节 §9 开头）：独立实现审计，**禁止直接复制** SleepDown 代码；审计报告先行，功能实现后置。
