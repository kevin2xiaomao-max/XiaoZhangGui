# Android V3.7.1 路由对等矩阵（R01–R29 / E01–E07）

> 基线：iOS `integration/v371-grok-thinking-fixes @ d238ff00`（3.7.1 / build 37，只读审计区 `~/workspace/xzg-v371-audit`，**严禁修改**）
> Android 现状：分支 `android/v3.7.1-oppo-port`（工作区 `~/workspace/xzg-android-v371`），V3.6 五 Tab 代码库（applicationId `com.xiaozhanggui.app`），四 Tab 改造尚未开始。
>
> 状态定义：✅ 已实现并对等 / 🟡 部分实现 / ⬜ 待实现（四 Tab 改造后）/ ⏭️ 平台差异（不追求逐像素对等）/ **NOT RUN** = 未运行验证（Phase 0 不虚报）。
> 本文档为 Phase 0 审计文档：Android 侧全部 V3.7.1 新路由状态均为 **NOT RUN**，直到 Phase 1–4 实际实现并验证。

---

## 1. R01–R29 生产路由（iOS 验收基线，逐行列可达路径与返回路径）

iOS 路由清单 R01–R29 全部页面文件存在于基线源码（注意审计清单路径省略了 `Features/` 前缀）。

| 路由 | iOS 页面文件 | iOS 可达路径 | iOS 返回路径 | Android 实现文件（现状） | Android 可达路径（四 Tab 改造后） | Android 返回路径 | 数据/交互等价标准 | 测试 | 状态 |
|---|---|---|---|---|---|---|---|---|---|
| R01 Home | `App/RootView.swift` + `Features/Home/HomeView.swift` | App 启动直达 | —（根 Tab） | `ui/screens/home/HomeScreen.kt`（五 Tab 首页） | 四 Tab「首页」tab（house.fill），启动直达 | —（根 Tab） | Header（日期/天气按钮/记一笔胶囊/头像）→ heroFlat 今日营业额（可点进经营）→ AICommandEntry →「今日重点」三 WorkRow →「接下来」TimedRow；点击行为与 iOS 一致 | 待补 Phase 2（UI/导航） | ⬜ NOT RUN |
| R02 Todo | `Features/Todo/TodoView.swift` | 待办 Tab | —（根 Tab） | `ui/screens/todo/TodoScreen.kt`（五 Tab 中为待办 Tab） | 四 Tab「待办」tab（checkmark.circle） | —（根 Tab） | 列表/新增/编辑/完成/删除语义与 iOS 一致 | 待补 Phase 2 | ⬜ NOT RUN |
| R03 Calendar | `Features/Schedule/ScheduleView.swift` | 日历 Tab | —（根 Tab） | `ui/screens/schedule/CalendarScreen.kt`（V3.6 称「日程」） | 四 Tab「日历」tab（calendar） | —（根 Tab） | 日程周条周一起始（firstWeekday=2），月历网格周日起始（firstWeekday=1）；日口径聚合规则（见 §2） | `DataSemanticsTest`（日口径聚合 + 周起始语义 Phase 1 已覆盖）/ 待补 Phase 2（UI 层） | 🟡 NOT RUN（UI 层未改） |
| R04 Business | `Features/Performance/PerformanceView.swift` | 经营 Tab | —（根 Tab） | `ui/screens/performance/PerformanceScreen.kt` | 四 Tab「经营」tab（chart.bar.fill） | —（根 Tab） | `incomeSource` 字段展示/统计与 iOS 一致（Phase 1 数据变更） | 待补 Phase 1（`incomeSource` 语义）/ 待补 Phase 2 | ⬜ NOT RUN |
| R05 Profile | `Features/Profile/ProfileView.swift` | 首页右上角头像 → `navigationDestination` | 返回键回首页 | `ui/screens/profile/ProfileScreen.kt`（V3.6 为「我的」Tab） | 首页 header 头像按钮（a11y「个人中心」`home.profile`）→ 导航进 Profile | 返回键回首页 | 「我的」Tab 取消；入口仅首页头像；各设置行与 iOS 一致 | 待补 Phase 2 | ⬜ NOT RUN |
| R06 Customer | （首页「今日重点」客户配送行） | 首页「今日重点」客户配送行 | 返回键回首页 | `ui/screens/customer/CustomerScreen.kt` + `CustomerEditorSheet.kt` | 首页「今日重点」客户配送行 → 导航进客户页 | 返回键回首页 | 客户跟进通知取消/重排规则与 iOS 一致（离开 pending 立即取消；delivering 不重排；update 统一重排） | `NotificationSideEffectsTest`（部分）/ 待补 Phase 1 | ⬜ NOT RUN |
| R07 Expiry | （首页「今日重点」临期退货行） | 首页「今日重点」临期退货行 | 返回键回首页 | `ui/screens/expiry/ExpiryScreen.kt` + `ExpiryEditorSheet.kt` | 首页「今日重点」临期退货行 → 导航进临期页 | 返回键回首页 | 提醒日 9:00 = 到期日 − remindDaysBefore；退货取消通知，恢复重排 | `NotificationSideEffectsTest`（部分）/ 待补 Phase 1 | ⬜ NOT RUN |
| R08 QuickRecord | 首页 header「记一笔」胶囊 → `showQuickRecord` | 首页 header「记一笔」胶囊按钮 → sheet | 关闭 sheet 回首页 | `ui/screens/quickrecord/QuickRecordSheet.kt` | 首页 header「记一笔」胶囊按钮 → sheet | 关闭 sheet 回首页 | 独立 `LocalQuickRecordParser`：不支持 Expense；缺金额写 0；备忘 title prefix(20)；直写无确认 | `QuickRecordParserTest` + `QuickRecordParserBoundaryTest`（边界回归 Phase 1 补齐）/ 待补 Phase 2（Sheet UI） | 🟡 NOT RUN（Sheet UI 未重设计） |
| R09 AI Chat | `Features/Assistant/AI/UI/AIChatView.swift` | **首页 AICommandEntry → `showAI` sheet（非 Tab）** | 关闭 sheet 回到当前页 | `ui/screens/ai/AIChatScreen.kt`（V3.6 为「小掌柜」独立 Tab） | **首页 AICommandEntry → AI Sheet** | 关闭 Sheet 回到当前页 | AI Tab 取消；5 tools 不变（`searchRecords` READ 自动 / `recordRevenue` / `createTodo` / `createMemo` / `createDelivery` 需确认）；架构升级见 DELTA 文档 | `AiIdempotencyTest` / `ToolIdempotencyTest`（部分）/ `AiPhase1ArchitectureTest`（Phase 1 新增 26 项：迁移 6/密钥 4/failover 7/http 映射 1/白名单 1/ping 5/装配 2；UI Sheet 部分 Phase 2） | ⬜ NOT RUN |
| R10 Weather | `Features/Weather/WeatherViews.swift` | 首页 header 天气按钮 → medium sheet | 下滑关闭回首页 | `ui/screens/home/WeatherSheet.kt`（V3.6 占位实现） | 首页 header 天气按钮 → medium sheet | 下滑关闭回首页 | 天气占位实现延续（V3.6 结论：🟡 占位；待真实 API 后补） | 待补（真实 API 接入后） | 🟡 NOT RUN |
| R11 Goods | （经营页） | 经营 Tab toolbar「商品」按钮 | 返回键回经营 | `ui/screens/goods/GoodsScreen.kt` | 经营 Tab toolbar「商品」按钮 → 导航 | 返回键回经营 | 删除加 `confirmationDialog`（"删除后无法恢复"）+ 失败显式提示；新增/编辑保存失败静默（保持 iOS 口径） | `GoodsStateTest`（部分）/ 待补 Phase 1（删除确认语义） | ⬜ NOT RUN |
| R12 GoodsEditor | （商品页内） | 商品页 +/行 → sheet | 关闭 sheet 回商品页 | `ui/screens/goods/GoodsEditorSheet.kt` | 商品页 +/行 → sheet | 关闭 sheet 回商品页 | 同 R11 | 待补 Phase 1 | ⬜ NOT RUN |
| R13 Memo | （经营页 menu） | 经营 Tab menu →「记录」→ `navigationDestination` | 返回键回经营 | `ui/screens/todo/MemoScreen.kt`（V3.6 在待办 Tab「备忘」segment） | 经营 Tab menu →「记录」→ 导航 | 返回键回经营 | 入口迁移：V3.6 待办 Tab segment → V3.7.1 经营 Tab menu；备忘 title prefix(20) | `MemoFilterTest`（部分）/ 待补 Phase 2 | ⬜ NOT RUN |
| R14 MemoEditor | （备忘页） | 备忘 +/行 → sheet | 关闭 sheet 回备忘页 | `ui/screens/todo/MemoEditorSheet.kt` | 备忘页 +/行 → sheet | 关闭 sheet 回备忘页 | 同 R13 | 待补 Phase 2 | ⬜ NOT RUN |
| R15 DailyReport | （经营页 menu） | 经营 Tab menu →「今日经营日报」→ sheet | 关闭 sheet 回经营 | `ui/screens/home/DailyReportSheet.kt` | 经营 Tab menu →「今日经营日报」→ sheet | 关闭 sheet 回经营 | 日报口径与 iOS 一致 | `DataSemanticsTest`（部分）/ 待补 Phase 2 | ⬜ NOT RUN |
| R16 Saobei | （经营页 menu） | 经营 Tab menu →「扫呗导入」→ sheet | 关闭 sheet 回经营 | `ui/screens/imp/SaobeiImportSheet.kt` + `SaobeiParser.kt` | 经营 Tab menu →「扫呗导入」→ sheet | 关闭 sheet 回经营 | 导入按 paymentMethod 派生 `incomeSource`；库内 + 文件内双重 fingerprint 去重 | `SaobeiImportTest` / 待补 Phase 1（`incomeSource` 派生） | ⬜ NOT RUN |
| R17 MoneyEditor | （经营页 menu） | 经营 Tab menu → 记收入/记支出 → sheet | 关闭 sheet 回经营 | `ui/screens/performance/MoneyEditorSheet.kt` | 经营 Tab menu → 记收入/记支出 → sheet | 关闭 sheet 回经营 | `PerformanceRepository.add` 新增 `incomeSource` 参数（默认 `.store`）；记收入/支出对应来源写入 | 待补 Phase 1 | ⬜ NOT RUN |
| R18 Transaction | （经营页） | 经营页「查看全部交易」 | 返回键回经营 | `ui/screens/performance/TransactionHistoryScreen.kt` | 经营页「查看全部交易」→ 导航 | 返回键回经营 | 交易列表/筛选口径一致 | `TransactionFilterTest` / 待补 Phase 2 | 🟡 NOT RUN（UI 未重设计） |
| R19 PaymentCode | （首页→Profile） | 首页 → Profile → 收款码行 | 返回键回 Profile | `ui/screens/paymentcode/PaymentCodeScreen.kt` | 首页 header 头像 → Profile → 收款码行 → 导航 | 返回键回 Profile | 同 iOS 流程 | 待补 Phase 2 | 🟡 NOT RUN（UI 未重设计） |
| R20 PaymentCodeEditor | （收款码页内，私有内嵌） | 收款码页 +/行 → sheet | 关闭 sheet 回收款码页 | `ui/screens/paymentcode/PaymentCodeEditorSheet.kt` | 收款码页 +/行 → sheet | 关闭 sheet 回收款码页 | 同 iOS | 待补 Phase 2 | 🟡 NOT RUN（UI 未重设计） |
| R21 PaymentCodeFullScreen | （收款码页，fullScreenCover） | 收款码页 → 全屏展示 | 关闭回收款码页 | `ui/screens/paymentcode/PaymentCodeFullScreen.kt` | 收款码页 → 全屏展示 | 关闭回收款码页 | 同 iOS | 待补 Phase 2 | 🟡 NOT RUN（UI 未重设计） |
| R22 外观/主题/壁纸 | （Profile 内） | Profile 对应行 → sheet | 关闭 sheet 回 Profile | `ui/screens/profile/ProfileSheets.kt`（主题设置） | Profile 对应行 → sheet | 关闭 sheet 回 Profile | V371 S0–S3 token 新设计系统（Phase 2 新建） | `ThemeSettingsTest`（部分）/ 待补 Phase 2 | ⬜ NOT RUN |
| R23 店铺/目标/提醒设置 | （Profile 内） | Profile 对应行 → sheet | 关闭 sheet 回 Profile | `ui/screens/profile/ProfileSheets.kt`（推断，待核实） | Profile 对应行 → sheet | 关闭 sheet 回 Profile | 同 iOS | 待补 Phase 2 | ⬜ NOT RUN |
| R24 语音输入设置 | （Profile「语音输入」行，私有 VoiceSettingsSheet） | Profile「语音输入」行 → sheet | 关闭 sheet 回 Profile | `ui/screens/voice/VoiceView.kt` + `VoiceViewModel.kt` | Profile「语音输入」行 → sheet | 关闭 sheet 回 Profile | VoiceParser 独立：支持 expense（关键词"进货/支出/花了"）；缺金额报错（收入→"请补充收入金额"，支出→"请补充支出金额"）；直写无确认卡 | `VoiceParserTest` + `VoiceParserBoundaryTest`（边界回归 Phase 1 补齐）/ 待补 Phase 2（UI） | 🟡 NOT RUN（UI 未重设计） |
| R25 原始语音测试 | `Features/Voice/VoiceView.swift` | Profile → 语音输入 → 测试语音 → sheet | 关闭 sheet 逐级返回 | `ui/screens/voice/VoiceView.kt`（同 R24） | Profile → 语音输入 → 测试语音 → sheet | 关闭 sheet 逐级返回 | 同 R24 | `VoiceParserTest` + `VoiceParserBoundaryTest`（边界回归 Phase 1 补齐）/ 待补 Phase 2（UI） | 🟡 NOT RUN |
| R26 备份/恢复/缓存/关于/隐私 | （Profile 内） | Profile 对应行 → 各 sheet/流程 | 关闭 sheet 回 Profile | `ui/screens/profile/ProfileScreen.kt` + `ProfileSheets.kt` + `BackupService`/`BackupCodec.kt` | Profile 对应行 → 各 sheet/流程 | 关闭 sheet 回 Profile | 备份 JSON：`xiao-zhang-gui-backup.json`（每次覆盖）；顶层 app/version=2/exportedAt 毫秒/records（每条含 type）；日期全毫秒时间戳；图片 imageBase64；`xzg-delivery-v1` 编码串原样 round-trip；恢复=追加不清空（不走 Repository，直接构造实体 + 单次 save）；恢复后重建三类通知 + 快照刷新；v1 兼容 | `BackupCodecTest`（JVM 编解码）+ `BackupRestoreSemanticsTest`（instrumented：追加/通知重建/快照刷新 Phase 1 已覆盖）/ 待补 Phase 2（UI 流程） | 🟡 NOT RUN（UI 流程未验证） |
| R27 AI Provider 设置 | （AI 页内） | AI 页 toolbar menu → AI 设置 → sheet | 关闭 sheet 回 AI 页 | `ui/screens/ai/AIProviderSettingsSheet.kt` | **首页 AICommandEntry → AI Sheet** → toolbar menu → AI 设置 → sheet | 关闭 Sheet 回到当前页 | 主 Provider 固定 DeepSeek（api.deepseek.com）；模型仅 `deepseek-flash`（默认）/`deepseek-v4-pro`（旧值自动迁移）；备=用户自定义 OpenAI 兼容端点（端点+模型+Key 齐全才启用）；ProviderChain 只 failover 1 次（仅网络/超时/429/5xx，401/403 不换链）；连接测试发最小 chat（"ping"，不带工具/数据）；密钥只存 Android Keystore（EncryptedSharedPreferences/security-crypto），绝不进 DataStore 明文/日志；搜索默认 disabled；**Manifest 缺 INTERNET（Phase 1 必补）** | `LocalBusinessParserTest`（部分）/ `AiPhase1ArchitectureTest`（Phase 1 新增 26 项：迁移 6/密钥 4/failover 7/http 映射 1/白名单 1/ping 5/装配 2；INTERNET 权限由数据层 worker 补） | ⬜ NOT RUN |
| R28 AI 短语音面板 | `Features/Assistant/AI/UI/ShortVoicePanel.swift`（审计路径省略了 Assistant/AI/UI 前缀，按实际文件为准） | AI 页语音按钮（深链 `xzg://ai?mode=voice` 自动拉起） | 关闭回 AI 页 | ⬜ 无对应文件（V3.6 无短语音面板） | **首页 AICommandEntry → AI Sheet** → 语音按钮（深链 `xzg://ai?mode=voice` 自动拉起短语音面板） | 关闭 Sheet 回到当前页 | 新增组件；ASR 前必查 `SpeechRecognizer.isRecognitionAvailable()`，无 GMS 降级为文字输入（OPPO 专项） | 待补 Phase 1（解析器已有）/ 待补 Phase 2（面板 UI） | ⬜ NOT RUN |
| R29 Storage 不可用态 | （App 层） | container 初始化失败自动呈现 | 恢复后回正常页 | ⬜ 无对应实现（V3.6 无此态） | container 初始化失败自动呈现 | 恢复后回正常页 | fail-closed 装配：误装 Preview 配置直接抛错（与 iOS 对齐） | 待补 Phase 1 | ⬜ NOT RUN |

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
| E03 `xzg://ai[?mode=voice]` | AI sheet；`mode=voice` 同步拉起 ShortVoicePanel | 现状跳 **AI 独立 Tab**（`OpenAssistantTab` / `OpenAssistantVoice`）❌ | **首页 AICommandEntry → AI Sheet**；`mode=voice` 同步拉起短语音面板 | ⬜ 待改（四 Tab 改造必改项）NOT RUN |
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
