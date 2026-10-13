# Android V3.7.1 路由对等矩阵（R01–R29 / E01–E07）

> 基线：iOS `integration/v371-grok-thinking-fixes @ d238ff00`（3.7.1 / build 37，只读审计区 `~/workspace/xzg-v371-audit`，**严禁修改**）
> Android 现状：分支 `android/v3.7.1-oppo-port`（工作区 `~/workspace/xzg-android-v371`），Phase 2 已完成：四 Tab（首页/待办/日历/经营）+ 首页 Editorial + V371 DesignTokens + R01–R29 路由全部落地（HEAD 见 git log）。
>
> 状态定义：✅ 已实现并对等 / 🟡 部分实现 / ⬜ 待实现 / ⏭️ 平台差异（不追求逐像素对等）/ **NOT RUN** = 未运行验证（不虚报：OPPO PKJ110 真机项一律 NOT RUN）。
> 本文档为 Phase 2 同步文档：测试列只写已存在的真实测试文件；CI（JVM 单元 + Paparazzi record/verify + 模拟器 E2E）全绿为 ✅ 前提，真机未测一律标注 NOT RUN。

---

## 1. R01–R29 生产路由（iOS 验收基线，逐行列可达路径与返回路径）

iOS 路由清单 R01–R29 全部页面文件存在于基线源码（注意审计清单路径省略了 `Features/` 前缀）。

| 路由 | iOS 页面文件 | iOS 可达路径 | iOS 返回路径 | Android 实现文件（现状） | Android 可达路径（四 Tab 改造后） | Android 返回路径 | 数据/交互等价标准 | 测试 | 状态 |
|---|---|---|---|---|---|---|---|---|---|
| R01 Home | `App/RootView.swift` + `Features/Home/HomeView.swift` | App 启动直达 | —（根 Tab） | `ui/screens/home/HomeScreen.kt`（四 Tab 首页 Editorial） | 四 Tab「首页」tab（house.fill），启动直达 | —（根 Tab） | Header（日期/天气按钮/记一笔胶囊/头像）→ heroFlat 今日营业额（可点进经营）→ AICommandEntry →「今日重点」三 WorkRow →「接下来」TimedRow；点击行为与 iOS 一致 | `PagesScreenshotTest`（homeLight/Dark）+ `HomeContentTest` + `NavSmokeTest`（homeEntries 导航） | ✅（CI 绿；真机视觉 NOT RUN） |
| R02 Todo | `Features/Todo/TodoView.swift` | 待办 Tab | —（根 Tab） | `ui/screens/todo/TodoScreen.kt`（五 Tab 中为待办 Tab） | 四 Tab「待办」tab（checkmark.circle） | —（根 Tab） | 列表/新增/编辑/完成/删除语义与 iOS 一致 | `TodoFlowTest` + `PagesScreenshotTest`（todoLight/Dark） | ✅（CI 绿；真机 NOT RUN） |
| R03 Calendar | `Features/Schedule/ScheduleView.swift` | 日历 Tab | —（根 Tab） | `ui/screens/schedule/CalendarScreen.kt`（V3.6 称「日程」） | 四 Tab「日历」tab（calendar） | —（根 Tab） | 日程周条周一起始（firstWeekday=2），月历网格周日起始（firstWeekday=1）；日口径聚合规则（见 §2） | `DataSemanticsTest`（JVM：日口径聚合 + 周起始语义）+ `ScheduleProfileAiScreenshotTest`（schedule/calendar） | ✅（CI 绿；真机 NOT RUN） |
| R04 Business | `Features/Performance/PerformanceView.swift` | 经营 Tab | —（根 Tab） | `ui/screens/performance/PerformanceScreen.kt` | 四 Tab「经营」tab（chart.bar.fill） | —（根 Tab） | `incomeSource` 字段展示/统计与 iOS 一致（Phase 1 数据变更） | `IncomeSourceTest` + `MigrationSqlTest`（Phase 1 ✅）+ `BusinessScreenshotTest`（performance）+ `MoneyEditorSheetTest` | ✅（CI 绿；真机 NOT RUN） |
| R05 Profile | `Features/Profile/ProfileView.swift` | 首页右上角头像 → `navigationDestination` | 返回键回首页 | `ui/screens/profile/ProfileScreen.kt`（「我的」Tab 已取消；入口为首页头像） | 首页 header 头像按钮（a11y「个人中心」`home.profile`）→ 导航进 Profile | 返回键回首页 | 「我的」Tab 取消；入口仅首页头像；各设置行与 iOS 一致 | `ScheduleProfileAiScreenshotTest`（profileLight/Dark）+ `NavSmokeTest`（homeEntries：头像 → Profile）+ `ThemeSwitchTest` | ✅（CI 绿；真机 NOT RUN） |
| R06 Customer | （首页「今日重点」客户配送行） | 首页「今日重点」客户配送行 | 返回键回首页 | `ui/screens/customer/CustomerScreen.kt` + `CustomerEditorSheet.kt` | 首页「今日重点」客户配送行 → 导航进客户页 | 返回键回首页 | 客户跟进通知取消/重排规则与 iOS 一致（离开 pending 立即取消；delivering 不重排；update 统一重排） | `NotificationSideEffectsTest`（Phase 1 ✅）+ `CustomerStatusTest` + `CustomerFollowupJourneyTest`（Phase 3：PendingIntent 真实调度 ✅）+ `BusinessScreenshotTest`（customer） | ✅（CI 绿；真机通知 NOT RUN） |
| R07 Expiry | （首页「今日重点」临期退货行） | 首页「今日重点」临期退货行 | 返回键回首页 | `ui/screens/expiry/ExpiryScreen.kt` + `ExpiryEditorSheet.kt` | 首页「今日重点」临期退货行 → 导航进临期页 | 返回键回首页 | 提醒日 9:00 = 到期日 − remindDaysBefore；退货取消通知，恢复重排 | `NotificationSideEffectsTest`（部分）+ `ExpiryToggleTest` + `ExpiryReminderJourneyTest`（Phase 3：PendingIntent 真实调度 ✅）+ `BusinessScreenshotTest`（expiry） | ✅（CI 绿；真机通知 NOT RUN） |
| R08 QuickRecord | 首页 header「记一笔」胶囊 → `showQuickRecord` | 首页 header「记一笔」胶囊按钮 → sheet | 关闭 sheet 回首页 | `ui/screens/quickrecord/QuickRecordSheet.kt` | 首页 header「记一笔」胶囊按钮 → sheet | 关闭 sheet 回首页 | 独立 `LocalQuickRecordParser`：不支持 Expense；缺金额写 0；备忘 title prefix(20)；直写无确认 | `QuickRecordParserTest` + `QuickRecordParserBoundaryTest` + `DeepLinkParseTest`（xzg://quickrecord）+ `SheetScreenshotTest`（quickRecordLight/Dark） | ✅（CI 绿；真机 NOT RUN） |
| R09 AI Chat | `Features/Assistant/AI/UI/AIChatView.swift` | **首页 AICommandEntry → `showAI` sheet（非 Tab）** | 关闭 sheet 回到当前页 | `ui/screens/ai/AISheet.kt`（Root 级 Sheet，内容复用 `AIChatScreen`；独立 Tab 已取消） | **首页 AICommandEntry → AI Sheet** | 关闭 Sheet 回到当前页 | AI Tab 取消；5 tools 不变（`searchRecords` READ 自动 / `recordRevenue` / `createTodo` / `createMemo` / `createDelivery` 需确认）；架构升级见 DELTA 文档 | `AiPhase1ArchitectureTest`（26 项）+ `ai/AiIdempotencyTest` + `ai/ToolIdempotencyTest` + `ai/LocalBusinessParserTest` + `DeepLinkAiJourneyTest` + `SheetScreenshotTest`（aiSheetLight/Dark） | ✅（CI 绿；ASR 真机 NOT RUN） |
| R10 Weather | `Features/Weather/WeatherViews.swift` | 首页 header 天气按钮 → medium sheet | 下滑关闭回首页 | `ui/screens/home/WeatherSheet.kt`（V3.6 占位实现） | 首页 header 天气按钮 → medium sheet | 下滑关闭回首页 | 天气占位实现延续（V3.6 结论：🟡 占位；待真实 API 后补） | `WeatherSheetTest`（instrumented：标题/--° 占位/Phase 5 说明断言；Paparazzi 下 ModalBottomSheet 首帧为空白，已移除截图用例） | 🟡 占位（真实 API 待 Phase 5） |
| R11 Goods | （经营页） | 经营 Tab toolbar「商品」按钮 | 返回键回经营 | `ui/screens/goods/GoodsScreen.kt` | 经营 Tab toolbar「商品」按钮 → 导航 | 返回键回经营 | 删除加 `confirmationDialog`（"删除后无法恢复"）+ 失败显式提示；新增/编辑保存失败静默（保持 iOS 口径） | `GoodsStateTest` + `BusinessScreenshotTest`（goodsLight/Dark） | ✅（CI 绿；真机 NOT RUN） |
| R12 GoodsEditor | （商品页内） | 商品页 +/行 → sheet | 关闭 sheet 回商品页 | `ui/screens/goods/GoodsEditorSheet.kt` | 商品页 +/行 → sheet | 关闭 sheet 回商品页 | 同 R11 | `SheetScreenshotTest`（goodsEditorLight/Dark） | ✅（CI 绿；真机 NOT RUN） |
| R13 Memo | （经营页 menu） | 经营 Tab menu →「记录」→ `navigationDestination` | 返回键回经营 | `ui/screens/todo/MemoScreen.kt`（V3.6 在待办 Tab「备忘」segment） | 经营 Tab menu →「记录」→ 导航 | 返回键回经营 | 入口迁移：V3.6 待办 Tab segment → V3.7.1 经营 Tab menu；备忘 title prefix(20) | `MemoFilterTest` + `PagesScreenshotTest`（memoLight/Dark） | ✅（CI 绿；真机 NOT RUN） |
| R14 MemoEditor | （备忘页） | 备忘 +/行 → sheet | 关闭 sheet 回备忘页 | `ui/screens/todo/MemoEditorSheet.kt` | 备忘页 +/行 → sheet | 关闭 sheet 回备忘页 | 同 R13 | `SheetScreenshotTest`（memoEditorLight/Dark） | ✅（CI 绿；真机 NOT RUN） |
| R15 DailyReport | （经营页 menu） | 经营 Tab menu →「今日经营日报」→ sheet | 关闭 sheet 回经营 | `ui/screens/home/DailyReportSheet.kt` | 经营 Tab menu →「今日经营日报」→ sheet | 关闭 sheet 回经营 | 日报口径与 iOS 一致 | `DataSemanticsTest`（部分）；`DailyReportSheet` 无截图（VM 绑定，待补） | 🟡（UI 截图待补） |
| R16 Saobei | （经营页 menu） | 经营 Tab menu →「扫呗导入」→ sheet | 关闭 sheet 回经营 | `ui/screens/imp/SaobeiImportSheet.kt` + `SaobeiParser.kt` | 经营 Tab menu →「扫呗导入」→ sheet | 关闭 sheet 回经营 | 导入按 paymentMethod 派生 `incomeSource`；库内 + 文件内双重 fingerprint 去重 | `SaobeiImportTest`（Phase 1 ✅：双重去重 + incomeSource 派生） | ✅（CI 绿；真机导入 NOT RUN） |
| R17 MoneyEditor | （经营页 menu） | 经营 Tab menu → 记收入/记支出 → sheet | 关闭 sheet 回经营 | `ui/screens/performance/MoneyEditorSheet.kt` | 经营 Tab menu → 记收入/记支出 → sheet | 关闭 sheet 回经营 | `PerformanceRepository.add` 新增 `incomeSource` 参数（默认 `.store`）；记收入/支出对应来源写入 | `MoneyEditorSheetTest` + Phase 1 ✅（`add(incomeSource: IncomeSource = .STORE)`）+ `SheetScreenshotTest`（moneyEditorLight/Dark） | ✅（CI 绿；真机 NOT RUN） |
| R18 Transaction | （经营页） | 经营页「查看全部交易」 | 返回键回经营 | `ui/screens/performance/TransactionHistoryScreen.kt` | 经营页「查看全部交易」→ 导航 | 返回键回经营 | 交易列表/筛选口径一致 | `TransactionFilterTest`（JVM）+ `e2e/RevenueJourneyTest`（旅程） | 🟡（无专用 UI 截图；真机 NOT RUN） |
| R19 PaymentCode | （首页→Profile） | 首页 → Profile → 收款码行 | 返回键回 Profile | `ui/screens/paymentcode/PaymentCodeScreen.kt` | 首页 header 头像 → Profile → 收款码行 → 导航 | 返回键回 Profile | 同 iOS 流程 | 无专用测试（待补） | 🟡（UI 存在；验证待补） |
| R20 PaymentCodeEditor | （收款码页内，私有内嵌） | 收款码页 +/行 → sheet | 关闭 sheet 回收款码页 | `ui/screens/paymentcode/PaymentCodeEditorSheet.kt` | 收款码页 +/行 → sheet | 关闭 sheet 回收款码页 | 同 iOS | 无专用测试（待补） | 🟡（UI 存在；验证待补） |
| R21 PaymentCodeFullScreen | （收款码页，fullScreenCover） | 收款码页 → 全屏展示 | 关闭回收款码页 | `ui/screens/paymentcode/PaymentCodeFullScreen.kt` | 收款码页 → 全屏展示 | 关闭回收款码页 | 同 iOS | 无专用测试（待补） | 🟡（UI 存在；验证待补） |
| R22 外观/主题/壁纸 | （Profile 内） | Profile 对应行 → sheet | 关闭 sheet 回 Profile | `ui/screens/profile/ProfileSheets.kt`（主题设置） | Profile 对应行 → sheet | 关闭 sheet 回 Profile | V371 S0–S3 token 新设计系统（Phase 2 新建） | `V371TokensTest` + `ThemeSettingsTest` + `ThemeSwitchTest` | ✅（CI 绿；真机 NOT RUN） |
| R23 店铺/目标/提醒设置 | （Profile 内） | Profile 对应行 → sheet | 关闭 sheet 回 Profile | `ui/screens/profile/ProfileSheets.kt`（推断，待核实） | Profile 对应行 → sheet | 关闭 sheet 回 Profile | 同 iOS；提醒设置 sheet 新增：POST_NOTIFICATIONS 拒绝降级说明（"通知未授权，提醒仅在应用内显示"）+ 提醒精度诚实行（精确/非精确，不得误报）；`USE_EXACT_ALARM` 合规移除（见 `ANDROID_V371_OPPO_VERIFICATION.md` §3.6） | `ThemeSettingsTest`（部分）+ `ReminderCapabilityTest`（JVM，4 用例 ✅） | 🟡（店铺/目标设置无专用测试，待补；提醒状态行已有 JVM 测试） |
| R24 语音输入设置 | （Profile「语音输入」行，私有 VoiceSettingsSheet） | Profile「语音输入」行 → sheet | 关闭 sheet 回 Profile | `ui/screens/voice/VoiceView.kt` + `VoiceViewModel.kt` | Profile「语音输入」行 → sheet | 关闭 sheet 回 Profile | VoiceParser 独立：支持 expense（关键词"进货/支出/花了"）；缺金额报错（收入→"请补充收入金额"，支出→"请补充支出金额"）；直写无确认卡 | `VoiceParserTest` + `VoiceParserBoundaryTest` | ✅（CI 绿；ASR 真机 NOT RUN） |
| R25 原始语音测试 | `Features/Voice/VoiceView.swift` | Profile → 语音输入 → 测试语音 → sheet | 关闭 sheet 逐级返回 | `ui/screens/voice/VoiceView.kt`（同 R24） | Profile → 语音输入 → 测试语音 → sheet | 关闭 sheet 逐级返回 | 同 R24 | `VoiceParserTest` + `VoiceParserBoundaryTest` | ✅（CI 绿；ASR 真机 NOT RUN） |
| R26 备份/恢复/缓存/关于/隐私 | （Profile 内） | Profile 对应行 → 各 sheet/流程 | 关闭 sheet 回 Profile | `ui/screens/profile/ProfileScreen.kt` + `ProfileSheets.kt` + `BackupService`/`BackupCodec.kt` | Profile 对应行 → 各 sheet/流程 | 关闭 sheet 回 Profile | 备份 JSON：`xiao-zhang-gui-backup.json`（每次覆盖）；顶层 app/version=2/exportedAt 毫秒/records（每条含 type）；日期全毫秒时间戳；图片 imageBase64；`xzg-delivery-v1` 编码串原样 round-trip；恢复=追加不清空（不走 Repository，直接构造实体 + 单次 save）；恢复后重建三类通知 + 快照刷新；v1 兼容 | `BackupCodecTest`（JVM）+ `BackupRestoreSemanticsTest`（instrumented：追加/通知重建/快照刷新） | ✅（CI 绿；真机 NOT RUN） |
| R27 AI Provider 设置 | （AI 页内） | AI 页 toolbar menu → AI 设置 → sheet | 关闭 sheet 回 AI 页 | `ui/screens/ai/AIProviderSettingsSheet.kt` | **首页 AICommandEntry → AI Sheet** → toolbar menu → AI 设置 → sheet | 关闭 Sheet 回到当前页 | 主 Provider 固定 DeepSeek（api.deepseek.com）；模型仅 `deepseek-flash`（默认）/`deepseek-v4-pro`（旧值自动迁移）；备=用户自定义 OpenAI 兼容端点（端点+模型+Key 齐全才启用）；ProviderChain 只 failover 1 次（仅网络/超时/429/5xx，401/403 不换链）；连接测试发最小 chat（"ping"，不带工具/数据）；密钥只存 Android Keystore（EncryptedSharedPreferences/security-crypto），绝不进 DataStore 明文/日志；搜索默认 disabled；INTERNET 权限 Phase 1 已补（数据层 worker） | `AiPhase1ArchitectureTest`（Phase 1 新增 26 项：迁移 6/密钥 4/failover 7/http 映射 1/白名单 1/ping 5/装配 2） | ✅（CI 绿；真机 NOT RUN） |
| R28 AI 短语音面板 | `Features/Assistant/AI/UI/ShortVoicePanel.swift`（审计路径省略了 Assistant/AI/UI 前缀，按实际文件为准） | AI 页语音按钮（深链 `xzg://ai?mode=voice` 自动拉起） | 关闭回 AI 页 | `ui/screens/ai/ShortVoicePanel.kt` + `data/voice/ShortVoiceSession.kt` ✅ | **首页 AICommandEntry → AI Sheet** → 语音按钮（深链 `xzg://ai?mode=voice` 自动拉起短语音面板） | 关闭 Sheet 回到当前页 | 新增组件；ASR 前必查 `SpeechRecognizer.isRecognitionAvailable()`，无 GMS 降级为文字输入（OPPO 专项） | `SheetScreenshotTest`（shortVoicePanelLight/Dark + shortVoiceFailedLight/Dark）+ `DeepLinkAiJourneyTest`（deepLinkAiVoice_opensAISheet） | ✅（CI 绿；ASR 真机 NOT RUN） |
| R29 Storage 不可用态 | （App 层） | container 初始化失败自动呈现 | 恢复后回正常页 | `ui/navigation/ColdStartPlan.kt`（fail-closed 装配）✅ | container 初始化失败自动呈现 | 恢复后回正常页 | fail-closed 装配：误装 Preview 配置直接抛错（与 iOS 对齐） | `ColdStartPlanTest` | ✅（CI 绿） |

### §2 日口径聚合规则（R03 / R15 / heroFlat 共用）

- 营业额/支出按业务 `date`；待办按 `dueDate`（仅未完成）；临期按 `expiryDate`（仅待处理）；客户按 `deliveryTime ?? createdAt`；备忘按 `createdAt`。
- "当天完成"：Todo = `isCompleted && completedAt` 同日；Customer = `status=done && updatedAt` 同日。
- 配送聚合：有真实 `deliveryTime` → 定时事件；无 → `createdAt` 当天全天事件。

---

## 2. E01–E07 深链接/系统集成

| 入口 | iOS 行为 | Android 现状 | Android 改造后可达路径 | 状态 |
|---|---|---|---|---|
| E01 `xzg://voice` | 语音输入 | `XzgDeepLink.kt` host=voice → `OpenVoice` ✅ | 不变（Phase 1 补 INTERNET 不影响） | ✅（`DeepLinkParseTest` 含解析边界）NOT RUN 真机 |
| E02 `xzg://quickrecord`（别名 `quick`） | 记一笔 | `XzgDeepLink.kt` host=quickrecord/quick → `OpenQuickRecord` ✅ | 不变 | ✅（`DeepLinkParseTest` 含解析边界）NOT RUN 真机 |
| E03 `xzg://ai[?mode=voice]` | AI sheet；`mode=voice` 同步拉起 ShortVoicePanel | `XzgNavGraph.kt` → Root 级 `RootSheet.AI(voiceDeepLink)`（`DeepLinkAction.OpenAISheet` / `OpenAISheetVoice`）✅ | **首页 AICommandEntry → AI Sheet**；`mode=voice` 同步拉起短语音面板 | ✅（`DeepLinkParseTest` + `DeepLinkAiJourneyTest.deepLinkAiVoice_opensAISheet`；NOT RUN 真机） |
| E04 Today Stats Widget | iOS Widget | ⏭️ Android AppWidget（平台差异：实现形态不同） | 待 Phase 2/3 评估是否移植 | ⏭️ 平台差异 |
| E05 Todo Widget 交互 | iOS 交互式 Widget | ⏭️ Android AppWidget + RemoteViews 限制 | 待 Phase 2/3 评估 | ⏭️ 平台差异 |
| E06 Business Live Activity | iOS Live Activity | ⏭️ Android 无等价 API（通知/快捷设置磁贴替代方案） | 待 Phase 3 评估降级方案 | ⏭️ 平台差异 |
| E07 App Intents（Siri/Shortcuts：新增待办/记录营业额/记记录） | iOS App Intents | ⏭️ Android App Actions / 快捷方式（Shortcuts） | 待 Phase 3 评估：Android 快捷方式 + 语音快捷指令映射 | ⏭️ 平台差异（`IntentRouterTest` 为 V3.6 深链接路由测试，非 App Intents 对等） |

**注意**：`xzg://todo` 为 Android 侧扩展（Phase 6 E2E 旅程需要直达待办页），iOS 无此 host；V3.7.1 保留。

---

## 3. 验收口径

- R01–R29 每行在 Phase 4 验收时必须给出：**可达路径 ✅ / 返回路径 ✅ / 数据等价 ✅ / 交互等价 ✅ / 测试 ✅**，五项缺一不可。
- AI 相关路由（R09 / R27 / R28 / E03）统一验收点：**AI 不占独立 Tab**，入口恒为「首页 AICommandEntry → AI Sheet」，返回恒为「关闭 Sheet 回到当前页」。
- Widget / LiveActivity / App Intents（E04–E07）按平台差异单独验收，不计入 R01–R29 通过率。
- 测试状态不许虚报：未运行 = NOT RUN；测试名只写已存在的真实测试文件，缺失一律标「待补 + 阶段」。

---

## 4. SleepDown-derived candidate ideas（P0 文档归档，不影响移植进度）

> **许可证红线**：SleepDown 的 `LICENSE.md` 是自定义"署名非商业、源码可见 1.1"许可，**不是**宽松开源许可（研究报告 §4）。本节仅归档可学习的**交互原则 / 运动参数 / 架构思路**；**禁止直接复制** SleepDown 的 Kotlin / 着色器 / 资源 / 界面代码。如未来确需复用，必须先梳理第三方许可并独立实现。

- **已具备**（小掌柜已有，无需做）：
  - AI 五工具 + 确认卡（Pending Action）/ 写库门禁 / 幂等日志：`AgentCore` → Pending Action → 确认 → `RepositoryToolExecutor` → Repository → 幂等日志。**禁止重写已验收的业务执行链**。
  - Compose + Room + DataStore 架构底座。
  - 通知调度（`NotificationSideEffectsTest`）。
  - 语音降级路径（ASR 不可用时文字回退；验收见 OPPO 验收文档 §2）。
- **建议下一期（P1）**（首个 APK 交付后评估）：
  - Android 自有 MotionSpec / MotionPolicy 与路由级 `transitionKind`（原生 / 淡入 / 共享锚点）、`performanceFallback`；立项见 `ANDROID_V371_DELTA_AUDIT.md` §10。
  - 非线性模糊强度滑杆映射（研究报告 §1 发现 3；仅当小掌柜已有壁纸 / 玻璃强度设置需优化时借鉴）。
  - 材质性能分级思路（质感 / 性能 / 超级性能，减少模糊 / 折射 / GPU 负担；研究报告 §1 发现 5）。
- **不可直接搬用**（架构不匹配）：
  - `OplusSeamlessBackend` 跨 Activity 转场 vs 小掌柜单 Activity NavHost：不能作为现有 Compose 路由的直接替换件（研究报告 §2）。
  - SleepDown 课程表复杂计划 vs 小掌柜店铺业务工具：`DAY_AGENT_RUNTIME` 的课程编辑计划不能照搬成店铺业务工具（研究报告 §3 P2 AI 审计）。
- **真机待验证**（PKJ110 + 当前 ColorOS 17 固件未验证前一律 `NOT VERIFIED`）：
  - Oplus 私有转场能力（研究报告 §1 纠偏 4：不能因 SleepDown 在 ColorOS 上实现过就认定 PKJ110 支持）。
  - 端侧 ASR 可用性、精确闹钟等能力探测（诊断分类见 OPPO 验收文档 §9.2）。
