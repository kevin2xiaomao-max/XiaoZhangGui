# 你的小掌柜 iOS V3.6 → Android 完整迁移审计报告

> 报告性质：Phase 0 收尾交付。只审计、未进入 Phase 1 正式迁移。
> 报告日期：2026-10-02
> 审计方式：5 路并行只读审计（A/B/C/D/E）+ AI 引擎补充审计，共 6 份报告，约 2800 行，全部文件+行号引用。

---

## 1. 基线与分支

| 项 | 值 |
|---|---|
| iOS Source of Truth | `kevin2xiaomao-max/XiaoZhangGui` 分支 `feature/v3.6-ui-ai-expansion` |
| V3.6 Source SHA | `335981badfa7163ad56063662bf0d7b5d2a78451`（`feat(v3.6): generalize web search providers`） |
| iOS 版本 | 3.6.0 / build 36（project.yml） |
| iOS Production Swift 文件 | 157 个；Tests 65 个 |
| Android branch | `android/v3.6`（基于上述 iOS SHA 创建，iOS 文件零改动） |
| Android HEAD | `5601ce8`（`docs(android/v3.6): 补齐 Parity Matrix §4 AI 引擎细节`） |
| 前序 commit | `acc3ea8`（Phase 0 审计与 parity 基线） |
| worktree | `~/workspace/xzg-android`（upstream 已修正为 `origin/android/v3.6`） |
| iOS 只读审计区 | `~/workspace/xzg-v36-audit`（detached HEAD 335981b，未动） |

**V3.6.1 污染检查**：全仓零 `V36` 前缀文件、零 `QuickAction` 文件；首页为 V3.6 `Home 1.4 Compact` + `V35HomeRevenueHero`；`HeroPrototypeGallery` / `V35ThemeLabView` 均为 `#if DEBUG` 未接入生产树。**未发现 V3.6.1 视觉污染。**

---

## 2. 旧 Android 成果核查结论

用户记忆中曾有 Android 版本/分支。2026-10-02 执行彻底核查：

| 核查项 | 方法 | 结果 |
|---|---|---|
| 本地分支 | `git branch -a` | 仅 `android/v3.6`（今日创建），无其他 |
| 远端分支 | `git branch -a` + GitHub API 全量分支列表 | 远端仅 `android/v3.6`（今日推送）；API 按名过滤 `android`/`kotlin` 零命中其他 |
| 历史提交 | `git log --all --grep=android` | 仅今日 2 个 docs commit |
| 历史文件 | `git log --all --diff-filter=A --name-only` 过滤 `.kt`/`.kts` | **全历史零 Kotlin 文件** |
| reflog | `git reflog --all` 过滤 android | 仅今日 branch 创建/push/commit 记录 |
| stash / tags | `git stash list` / `git tag` | 无相关 |
| 磁盘目录 | 全 workspace 搜索 `*android*` | 仅 `~/workspace/xzg-android`（今日 worktree）+ SDK/JDK 工具目录 |

**结论：仓库内、远端、磁盘上均无历史 Android 成果。** Matrix 原文"无既有 Android branch"属实。若用户曾在其他机器/Mac 或其他仓库做过，请提供位置；否则按"从零新建"推进。

**当前未提交状态**：`android/` 目录有 Phase 1 代理生成的 Gradle 骨架（未提交、保留未删、未 reset）；HEAD 保持 `5601ce8` clean（除该 untracked 目录外）。

---

## 3. 完整 Production 功能清单（数量）

### 3.1 导航与页面（5 Tab + 11 业务页）

| # | 页面 | iOS Source | 说明 |
|---|---|---|---|
| T1 | 首页 | Features/Home/HomeView.swift | Header+RevenueHero+weekRail+今日事项+最近备忘+概览三格+抽屉 |
| T2 | 日程 | Features/Schedule/ScheduleView.swift | 周条+时间轴+全天+当日经营；toolbar 进日历 |
| T3 | 小掌柜 | AI/UI/AIChatView.swift | AI 聊天（见 §6） |
| T4 | 待办 | Features/Todo/TodoView.swift | 5 tab（今天/明天/逾期/已完成/备忘） |
| T5 | 我的 | Features/Profile/ProfileView.swift | 6 分组，12 sheet |
| P1 | 日历 | Features/Calendar/CalendarView.swift | 日程二级入口，月网格，周日首列 |
| P2 | 客户需求 | Features/Customer/CustomerView.swift | 状态机 pending→delivering→done |
| P3 | 临期退货 | Features/Expiry/ExpiryView.swift | 6 分组 |
| P4 | 临时商品 | Features/Goods/GoodsView.swift | 搜索+分类+状态判定 |
| P5 | 经营数据 | Features/Performance/PerformanceView.swift | Hero+指标+占比+流水 |
| P6 | 交易记录 | TransactionHistoryView.swift | 只读+搜索 |
| P7 | 记录（备忘） | Features/Memo/MemoView.swift | 搜索+筛选 |
| P8 | 收款码 | Features/PaymentCode/PaymentCodeView.swift | 列表+全屏展示 |
| P9 | 外观设置 | AppearanceSettingsView.swift | 显示/Accent/背景/壁纸 |
| P10 | 天气详情 | WeatherDetailSheet | 首页 header 按钮进入 |
| P11 | 扫呗导入 | Features/Import/SaobeiImportSheet.swift | 经营数据页进入 |

### 3.2 Sheet（17）

DailyReportSheet（今日经营报告）/ QuickRecordSheet（快速记一笔）/ VoiceSheet（语音记一笔）/ TodoEditorSheet / CustomerEditorSheet / ExpiryEditorSheet / GoodsEditorSheet / MoneyEditorSheet（4 模式：新收入/新支出/编辑收入/编辑支出）/ MemoEditorSheet / PaymentCodeEditorSheet / ReminderSettingsSheet（提醒设置）/ AIProviderSettingsSheet（AI 设置）/ ShortVoicePanel（AI 内语音面板）/ 全局 Sheet×2（RootView：语音/速记，detents 260/340）/ PaymentCode 全屏（fullScreenCover）/ Demo 模式相关

### 3.3 抽屉（8 固定目的地）

交易记录（push）/ 今日经营报告（sheet）/ 客户需求（push）/ 临期退货（push）/ 商品（push）/ 备忘（push）/ 快速记一笔（sheet）/ 扫呗导入（sheet）。左缘 26pt 热区右滑，阈值 0.32。

### 3.4 其他

- 深链接 4 路由：`xzg://voice` / `xzg://quickrecord|quick` / `xzg://ai` / `xzg://ai?mode=voice`
- App Intents ×3：新增待办 / 记录营业额 / 记记录
- 通知 3 类：待办截止 / 临期退货 / 客户跟进（全本地，无远程推送）
- Widget：主屏 Small/Medium + 锁屏 3 尺寸；Live Activity（当日实况+灵动岛）
- 扫呗导入 3 输入路径：CSV / XLSX / 截图 OCR
- 天气（WeatherAPI.com）、备份/恢复（JSON v2）、Demo Mode、主题系统（3 正交维度）

**功能总数口径**：5 Tab + 11 业务页 + 17 Sheet + 8 抽屉目的地 + 4 深链接 + 3 Intents + 3 通知 + Widget/LiveActivity + 导入/天气/备份/主题 ≈ **55 个可数功能点**（157 Production 文件）。

---

## 4. 7 Entity 数据映射

| iOS @Model | Android Entity（表名） | 关键字段 | 陷阱 |
|---|---|---|---|
| Todo | TodoEntity（todos） | title/detail/dueDate(Long?)/priority(Int 0低1中2高)/imagePath/isCompleted/completedAt?/createdAt/notificationID(UUID) | **无 updatedAt（有意）** |
| ExpiryItem | ExpiryItemEntity（expiry_items） | name/category/quantity/productionDate?/expiryDate/remindDaysBefore(默认7)/note/imagePath/createdAt/returnStatus("待处理"/"已退货")/returnedAt?/notificationID | remindDaysBefore 只用于通知，不参与列表分组 |
| CustomerRequest | CustomerRequestEntity（customer_requests） | customer/**编码串**/roomOrAddress/phone/content/status/imagePath/createdAt/updatedAt/notificationID | `customer` = `xzg-delivery-v1:` + base64(JSON{deliveryTime,note,legacyCustomer})；展示层必须隐藏编码串；日历按解码 deliveryTime 聚合 |
| Goods | GoodsEntity（goods） | name/category(默认"其他")/barcode/stock/minStock/purchasePrice/salePrice/productionDate?/shelfLifeDays/expiryDate?/note/imagePath/createdAt/updatedAt | 删除无确认框（iOS 行为，保留差异） |
| Memo | MemoEntity（memos） | title/content/imagePath/createdAt/updatedAt | 标题≤100/内容≤2000 静默截断 |
| Performance | PerformanceEntity（performances） | amount/note/date(业务日期)/fingerprint/paymentMethod/orderNo/importSource/incomeSource("门店"/"美团"/"其他") | 统计必须按 `date` 而非 createdAt |
| Expense | ExpenseEntity（expenses） | amount/category(进货/房租/水电/人工/其他)/note/date/createdAt | 语音链路独有（QuickRecord 无 expense） |

类型映射：Date→Long epoch millis；UUID→String；`@Attribute(.externalStorage)` 图片→app files 相对路径 + Room 存路径。

---

## 5. AI Action 完整清单

### 5.1 注册工具（5 个，`AI/Tools/ToolCatalog.swift`，顺序固定）

| 工具 | 参数 | 写入目标 | 确认 |
|---|---|---|---|
| `searchRecords` | kinds（revenueToday/todoToday/recentMemo/expiringGoods/delivery）必填，query 可选 | 只读不写（本地聚合+脱敏回答） | 自动执行 |
| `recordRevenue` | amount 必填；source/date/note 可选 | Performance | **必须 ActionCard 确认** |
| `createTodo` | title 必填；detail/dueDate/priority(0普通/1重要/2紧急) 可选 | Todo | 必须确认 |
| `createMemo` | title + content 必填 | Memo | 必须确认 |
| `createDelivery` | 全可选（customer/roomOrAddress/phone/content/goodsName/quantity/deliveryTime/deliveryTimeText/amount/note）；客户与商品全空时拒绝 | CustomerRequest | 必须确认 |

**不注册**：`addExpiry` / `update` / `delete`（Android 同样不实现）。

### 5.2 确认机制

`AgentCore.handleToolCall` → 参数校验 → journal 防重 → `pending-actions.json` 落盘 → ActionCard 渲染。五态：pending（待你确认）/ confirmed（正在保存）/ executed（已保存）/ duplicate（重复已跳过）/ failed（失败可重试）/ cancelled（已取消）。预览模式琥珀横幅"点击确认也不会真实保存"。修改→取消旧卡回填原文。

### 5.3 幂等

双键：`toolCallID`（`call_<UUID>`，重试复用）+ 业务指纹：
- 营业额 `rev|<金额2位>|<日期>|<来源>|<备注>`
- 待办 `todo|<标题>|<到期分钟>|<优先级>`
- 备忘 `memo|<标题>`
- 配送 `del|<客户>|<房号>|<分钟>|<商品>|<数量>|<金额>`
`execution-journal.json` 落盘，损坏隔离重命名不崩溃。

### 5.4 Repository 写入路径

`RepositoryToolExecutor`（Integration 层**唯一允许写库的执行器**）→ 分发到既有 `PerformanceRepository` / `TodoRepository` / `MemoRepository` / `CustomerRepository`，不写第二套保存逻辑。校验顺序：注册→参数→幂等→写入→journal markExecuted。`searchRecords` 到此层直接拒绝（查询不经过写库执行器）。

### 5.5 Provider 与配置

- 默认 DeepSeek：`https://api.deepseek.com`，模型 `deepseek-flash` / `deepseek-v4-pro`；`temperature: 0.2` 硬编码；**无 SSE/流式**（单次 `chat/completions`，UI 仅 isProcessing+processingLabel）。
- ProviderChain 只跳 1 次（primary→fallback；401/403 不换链）。
- API Key 只进 Keychain（`ai.primary.apiKey` 等 4 个键），绝不进 UserDefaults → Android 用 **Keystore + EncryptedSharedPreferences**。
- 设置页字段：tier 三档 / 主备 baseURL+模型+Key / 搜索 provider 四档（默认 disabled）/ 连接测试状态胶囊（仅真实成功才绿）。
- 无 Key 时 `LocalBusinessParser` 本地 CREATE 照常工作（离线可用）；Mock 仅 DEBUG。
- 意图路由：IntentRouter 7 case + 9 步顺序（天气优先→…→问句绝不落 CREATE→…→兜底 worldChat）；上云 context 恒空（经营数据不外发）。
- 能力：Vision/Document/URLReading/WebSearch 均为只读，不产生 ActionCard。
- 技能：GoodsLookup（本地商品查询）/ MetaReply（元问题固定回复）/ Weather（本地天气回答）。

---

## 6. Voice / QuickRecord

| | Voice（语音记一笔） | QuickRecord（快速记一笔） |
|---|---|---|
| 解析器 | `VoiceParser`（独立规则） | `QuickRecordParser`（独立规则，不完全相同） |
| 状态机 | 8 态：idle/listening/recognized/parsing/preview/saving/error/textFallback | 表单：唯一输入框+语音+类型覆盖+结果卡 |
| 写入类型 | 6 类：营业额/**支出**/临期/备忘/客户配送/待办 | 5 类：营业额/待办/客户配送/临期/备忘（**无支出**） |
| 金额缺失 | **报错**（不写库） | **写 0**（与语音链路不一致，待产品确认） |
| 静音收尾 | 3 秒自动结束 | — |
| 波形 | 装饰动画（非真实音量驱动） | — |
| Android 等价 | SpeechRecognizer（Google 服务；无 GMS 设备需降级）+ RECORD_AUDIO | 同左（输入为文字时无需权限） |

---

## 7. Notification

| 类型 | 调度规则 | 内容 | 取消 | Android 等价 |
|---|---|---|---|---|
| 待办提醒 | 设置 `todo_reminder` 开（默认 true）+ 有 dueDate + due>现在 + 未完成；精确到分 | 标题"待办提醒"/正文=标题 | 完成/删除/dueDate 清空或改过去 | AlarmManager 精确闹钟 |
| 临期提醒 | `expiry_reminder` 开 + status=pending；`(expiryDate - remindDaysBefore)` 当日 **9:00**；触发时间已过去则不调度 | "「<名称>」还有 N 天到期（M 件）"/已到期版 | 离开 pending/日期修改重排 | AlarmManager 精确闹钟 |
| 客户跟进 | 仅 pending；新增/编辑后 **1 小时** | 标题"配送需求待跟进"/正文=content·地址 | 离开 pending 立即取消 | WorkManager 一次性延时 |

通知 ID：`todo-<notificationID>` / `expiry-<notificationID>` / `customer-<notificationID>-followup`（UUID 稳定；Android 用 UUID hash 派生 requestCode）。
**风险**：Android 12+ `SCHEDULE_EXACT_ALARM` 可被用户撤销；国产 ROM 后台限制需引导加白名单。

---

## 8. Widget / Live Activity Android Equivalent

| iOS | Android 等价 | 差异 |
|---|---|---|
| WidgetKit Small（问小掌柜+语音记录，深链 xzg://ai / xzg://voice） | AppWidgetProvider 小尺寸 + intent 深链 | 可 1:1 |
| WidgetKit Medium（今日营业额+2 条焦点事项，待办可勾选） | AppWidgetProvider 中尺寸；勾选→BroadcastReceiver 直接写 Room | 可 1:1（跨进程逻辑可删除，同进程直写） |
| 锁屏 accessory（Inline/Circular/Rectangular） | **无等价**（Android 5+ 移除锁屏 widget） | → 持续性通知承担 |
| Live Activity + 灵动岛 | 持续性通知（ongoing + 自定义 RemoteViews + 定期更新） | 视觉形态不同，行为近似 |
| AppIntents（Widget 勾选待办） | PendingIntent → Receiver | 可 1:1（语义保留：只置完成不 toggle） |
| App Group 共享 | **不需要**（同 UID 直连 Room/DataStore） | 简化 |

---

## 9. Parity Matrix / Platform Differences

- `docs/ANDROID_V36_PARITY_MATRIX.md`：16 大节逐项映射（功能→iOS Source→Android Target→数据模型→Repository→UI 状态→Interaction→实现/Test 状态）。
- `docs/ANDROID_V36_PLATFORM_DIFFERENCES.md`：10 节 Apple-only 等价方案（语音/通知/Widget/亮度/扫呗/天气/备份/深链/UI/数据层）。

---

## 10. Phase 1-N 实施计划

| Phase | 内容 | 关键交付 |
|---|---|---|
| Phase 1 | Architecture / data foundation | Gradle 工程（AGP 8.5.2/Kotlin 2.0.21/compileSdk 35/minSdk 26）+ 7 Entity + 7 DAO + XzgDatabase + DataStore keys + V32 主题（色板/字体/间距/动效）+ 5 Tab 导航骨架 + `assembleDebug` 通过 |
| Phase 2 | 核心业务数据与 Repository | 7 Repository（含通知调度副作用、SnapshotSync、xzg-delivery-v1 编解码、IncomeSource 派生链）+ 备份/恢复（JSON v2 互读）+ 单元测试 |
| Phase 3 | 全部 Production 页面 | 5 Tab + 11 业务页 + 17 Sheet + 抽屉（Compose 1:1 视觉，Light/Dark） |
| Phase 4 | AI / Voice / Quick Capture | AgentCore 移植（5 工具/ActionCard/幂等/IntentRouter/LocalBusinessParser）+ OpenAI 兼容 Provider + 语音/速记双解析器 + 短语音面板 |
| Phase 5 | 完整视觉 parity | 6 Accent × 6 Background × 壁纸 + SF Symbols 对照 + 动效/Reduce Motion + 全页面 Light/Dark 走查 |
| Phase 6 | 自动化测试 + regression | 单元测试（补 iOS 缺口：Expiry/MemoSearch/GoodsFilter/CalendarAgenda/DailyReport/NotificationManager）+ Compose UI Tests + E2E 脚本 |
| Phase 7 | Release Gate | clean build / unit / UI tests / lint 全绿 + release APK/AAB + GitHub Actions 全绿 + artifact 可下载 |

每 Phase 完成后 commit（用户要求：普通编译/测试问题自行修复，不逐阶段等待；仅数据破坏/Source 不明确/删除正式功能时暂停）。

---

## 11. 自动测试 / E2E 计划

**单元测试**（JUnit + Room 内存库 + Turbine）：7 Entity CRUD、Repository 副作用（通知调度/取消断言）、xzg-delivery-v1 编解码、扫呗 fingerprint 去重、IntentRouter 9 步路由、Voice/QuickRecord 解析器规则、备份 v2  round-trip、幂等指纹。

**Compose UI Tests**：启动→首页→新建/完成待办→客户需求→临期→备忘→记录营业额→日历→AI/快速记录→数据保存→杀 App→重启→数据仍存在；另测 Light/Dark、键盘、Back、底部导航、小屏/大屏。

**E2E（GitHub Actions 模拟器）**：`connectedCheck` 全流程；Release Gate 要求 APK/AAB 可下载、Actions 全绿。

**真机**：通知真实触发、语音识别、Widget、持续性通知、ML Kit OCR 需用户真机验证（Linux/CI 无法覆盖）。

---

## 12. 1:1 vs Android Equivalent

### 能真正 1:1 的
数据模型字段/默认值/状态机/排序/分组规则/空状态与确认框文案/备份 JSON v2 格式与互读/fingerprint 与去重规则/IntentRouter 路由顺序/幂等指纹/ActionCard 五态/通知调度规则/V32 色板 hex/字号字重/间距圆角/深链接路由/抽屉 8 目的地/扫呗"状态为空视为成功"等反直觉业务规则。

### 只能 Android Equivalent 的
语音识别引擎（SFSpeechRecognizer→SpeechRecognizer/GMS 降级链）/ 精确闹钟权限模型 / 锁屏 Widget 与灵动岛（→持续性通知）/ AppIntents→App Actions / 收款码亮度（系统级→窗口级）/ Vision OCR→ML Kit 中文模型 / XLSX 自研解压→标准库 / SF Symbols→Material Symbols/自绘 / Swift Charts→Compose Canvas / Keychain→Keystore / App Group→直连 / iOS26 tabBarMinimize→nestedScroll。

---

## 13. Autonomous Full Run 是否可行

**部分可行**，分三层：

| 层 | 自主可行 | 说明 |
|---|---|---|
| 构建/单测/Lint/CI | ✅ | Gradle + GitHub Actions 全自动；Linux 本机可跑 assemble/lint/unit（代理已配） |
| 模拟器 UI 测试/E2E | ⚠️ 条件可行 | 需在 CI 配 Android 模拟器（API 35 镜像）；本机 Linux 无 KVM 大概率跑不起模拟器，以 CI 为准 |
| 真机验证 | ❌ | 通知真实触发、语音、Widget 手感、OEM 后台、ML Kit 体积、截图视觉验收必须用户真机 |

**结论**：代码→CI→APK/AAB→artifact 可全自动；"用户装上能用"的最终确认必须留给真机。按用户口径纪律：CI 全绿 + artifact 可下载之前，不写"完成"。

---

## 14. Remaining Risks

1. **语音 ASR 不可控**：SpeechRecognizer 依赖 Google 服务；国内无 GMS 设备识别不可用，需降级链（云 ASR 或明确提示），体验与 iOS 不对等。
2. **通知到达率**：`SCHEDULE_EXACT_ALARM` 可被撤销 + 国产 ROM 杀后台；临期 9:00 提醒可能延迟/丢失，需应用内引导加白名单。
3. **ML Kit 中文模型**：APK 体积增加（数 MB）或首用下载；无 GMS 设备需替代方案。
4. **API Key 外部依赖**：天气 Key（CI secret）、DeepSeek Key（用户自备）——缺 Key 时对应功能降级，E2E 无法全覆盖。
5. **长任务一致性**：55 功能点跨 Phase 1-7，约数千文件/数万行；Parity Matrix 是唯一抓手，任一 Phase  drift 都需回查。
6. **iOS 语义基于静态审计**：部分动效细节、文案断行、真机手感无 iOS 真机对照；以代码为准，有歧义处以 Matrix 注释标记。
7. **QuickRecord 金额缺失写 0 vs Voice 报错**：iOS 两条链路行为不一致，现状是"照搬"，是否统一待产品确认（用户已授权超范围先确认）。
8. ** backup 互读**：JSON v2 格式已审计，但双向真实互读需真机/双端实测才能定论。

---

## 15. 交付物清单（本报告）

| 交付物 | 位置 | 状态 |
|---|---|---|
| A/B/C/D/E 审计报告 | `docs/audit/` | ✅ 已提交（`acc3ea8`） |
| Parity Matrix | `docs/ANDROID_V36_PARITY_MATRIX.md` | ✅ 已提交（含 §4 AI 细节，`5601ce8`） |
| Platform Differences | `docs/ANDROID_V36_PLATFORM_DIFFERENCES.md` | ✅ 已提交 |
| 本审计报告 | `docs/ANDROID_V36_MIGRATION_AUDIT_REPORT.md` | 本文件 |
| Phase 1 未提交骨架 | `android/`（untracked） | ⏸️ 保留，未 commit/未删/未 reset |

---

*报告完。Phase 0 收尾完毕，等用户审核后再决定是否进入 Phase 1。*
