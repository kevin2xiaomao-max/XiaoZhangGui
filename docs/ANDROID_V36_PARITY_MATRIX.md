# 你的小掌柜 Android V3.6 — Parity Matrix

> iOS Source of Truth：`kevin2xiaomao-max/XiaoZhangGui` 分支 `feature/v3.6-ui-ai-expansion`
> iOS V3.6 HEAD SHA：`335981badfa7163ad56063662bf0d7b5d2a78451`（2026-09-22）
> Android branch：`android/v3.6`（基于上述 iOS SHA 创建，无既有 Android branch）
> 审计基线日期：2026-10-02
> 禁止事项：不使用 `feature/v3.6.1-reference-home`；不移植 V3.6.1 首页视觉（Revenue Hero 改版 / Quick Actions）；不覆盖 iOS 分支。
>
> 本文档逐项列出 iOS V3.6 Production 功能 → iOS Source → Android Target → 数据模型 → Repository/业务逻辑 → UI 状态 → Interaction → Android 实现状态 → Test 状态。
> Android 实现状态图例：⬜ 未开始 / 🟡 进行中 / 🟢 已完成 / ⏭️ 平台差异（见 ANDROID_V36_PLATFORM_DIFFERENCES.md）

---

## 0. 全局技术栈映射

| 层 | iOS V3.6 | Android V3.6 |
|---|---|---|
| 语言 | Swift 5 | Kotlin |
| UI | SwiftUI | Jetpack Compose（Material3 为实现工具，视觉以 iOS V3.6 为准，不套默认 Material Dashboard 风格）|
| 状态 | @Observable / @State / @Query | ViewModel + StateFlow / collectAsState |
| 持久化 | SwiftData（7 @Model） | Room（7 Entity + DAO） |
| 键值 | UserDefaults | DataStore Preferences |
| 图片 | @Attribute(.externalStorage) | App files dir 外部文件 + Room 存路径/引用 |
| 通知 | UNUserNotificationCenter | AlarmManager 精确闹钟 + NotificationManager / WorkManager |
| 后台任务 | — | WorkManager |
| 语音识别 | SFSpeechRecognizer + AVAudioEngine | android.speech.SpeechRecognizer（云 ASR 降级链见差异文档）|
| 深链接 | xzg:// Scheme | AndroidManifest intent-filter（scheme=xzg）|
| 备份 | JSON 文件经 UIActivityViewController 分享 | JSON 文件经 ACTION_SEND / FileProvider 分享（格式 v2 互读）|
| Widget | WidgetKit | AppWidgetProvider + Glance（锁屏 accessory 无等价，见差异文档）|
| 实况 | LiveActivityManager | 持续性通知 ongoing notification（见差异文档）|
| 快捷指令 | AppIntents × 3 | App Actions（actions.xml）/ App Shortcuts |

**数据模型总表（7 实体，字段 1:1，见审计报告 B_data.md §1）：**

| iOS @Model | Android Entity（表名） | 关键字段摘要 |
|---|---|---|
| Todo | TodoEntity（todos） | title/detail/dueDate(Long?)/priority(Int 0低1中2高)/imageData(外部文件)/isCompleted/completedAt(Long?)/createdAt/notificationID(UUID)。**无 updatedAt（有意）** |
| ExpiryItem | ExpiryItemEntity（expiry_items） | name/category/quantity/productionDate?/expiryDate/remindDaysBefore(默认7)/note/imageData/createdAt/returnStatus("待处理"/"已退货")/returnedAt?/notificationID |
| CustomerRequest | CustomerRequestEntity（customer_requests） | customer(**xzg-delivery-v1: base64 编码串**，内含 deliveryTime/note/legacyCustomer)/roomOrAddress/phone/content/status("待处理"→"配送中"→"已完成")/imageData/createdAt/updatedAt/notificationID |
| Goods | GoodsEntity（goods） | name/category(默认"其他")/barcode/stock/minStock/purchasePrice/salePrice/productionDate?/shelfLifeDays/expiryDate?/note/imageData/createdAt/updatedAt |
| Memo | MemoEntity（memos） | title/content/imageData/createdAt/updatedAt |
| Performance | PerformanceEntity（performances） | amount/note/date(业务日期)/fingerprint/paymentMethod/orderNo/importSource/incomeSource("门店"/"美团"/"其他") |
| Expense | ExpenseEntity（expenses） | amount/category(进货/房租/水电/人工/其他)/note/date/createdAt |

---

## 1. App 壳 / 导航

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| App 启动三路 | App/XiaoZhangGuiApp.swift:29-59 | MainActivity + XzgApplication | — | 单元测试宿主→空；UI 测试→内存 DB + 种子；生产→Room 真实库；**失败显式报错页，绝不静默回退内存库**（P0-2） | 启动态/错误页 | — | ✅ | ⬜ |
| 5 Tab 导航 | App/RootView.swift:19-41 | NavHost + 底部导航栏 | — | tab 状态 + lastContentTab | home/schedule/assistant/todo/profile | Tab 点击切换；iOS 26 下滑隐藏 tab bar → Android nestedScroll 等价 | ✅ | ⬜ |
| 深链接 xzg:// | RootView.swift:74-87, Assistant/AI/Core/AppDeepLink.swift | Manifest intent-filter + onNewIntent | — | voice→语音 sheet；quickrecord/quick→速记 sheet；ai→小掌柜 tab；ai?mode=voice→小掌柜+语音面板；未知 host 忽略 | — | 外部唤起 | ✅ | ⬜ |
| 全局 Sheet（语音/速记） | RootView.swift:46-56 | ModalBottomSheet（圆角 28，固定高度 260/340） | — | — | showVoice/showQuickRecord | 全局可唤起 | 🟡 | ⬜ |
| Demo Mode | Demo/DemoMode.swift | DataStore xzg_demo_mode_enabled + 内存 Room | DemoCatalog 种子 | 切换强制重建 UI 树；演示数据独立内存库 | 开关 + 重置按钮 | Toggle | ⬜ | ⬜ |

---

## 2. 首页

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 问候 header | Features/Home/HomeView.swift:145-194 | HomeScreen Header | AppSettings(shopName/ownerName) | Greeting.phrase：<11 早上好/<14 中午好/<18 下午好/else 晚上好；日期 "M月d日 星期X" | — | 天气按钮→天气 sheet | ✅ | ⬜ |
| Revenue Hero | Features/Home/V35HomeRevenueHero.swift | HomeRevenueHero（Compose Canvas 火花线） | Performance ✅ | 今日求和；涨跌=(今-昨)/昨（昨日0不显示）；本月/目标/完成；进度=月累计/月目标钳制0..1 | 点击→经营数据页 | 点击跳转 | ✅ | ⬜ |
| weekRail | HomeView.swift:197-215 | WeekRail | — | 本周7天周一起始；今天高亮 | — | 无 | ✅ | ⬜ |
| 今日事项 | V35HomeFocusSection.swift + HomeInbox（DisplayLogic.swift:135-222） | FocusSection | Todo/CustomerRequest/ExpiryItem | rank 排序（高优待办1/配送中2/普通配送3/普通待办4），limit=3；待办勾选→toggleComplete | 空态"今天暂无待处理事项" | 勾选/点击跳转 | ✅ | ⬜ |
| 最近备忘 | V35HomeRecentMemo.swift | RecentMemo | Memo | 前2（updatedAt 倒序） | 仅非空显示 | 点击→备忘页 | ✅ | ⬜ |
| 概览三格 | V35HomeOverviewGrid.swift | OverviewGrid | Todo/Customer/Expiry | 待办/配送/临期计数 | — | 点击→待办 tab/客户页/临期页 | ✅ | ⬜ |
| 抽屉 | V35SideUtilityDrawer.swift | UtilityDrawer（ModalNavigationDrawer 自绘或定制） | — | 8 目的地（5 push + 3 sheet） | 开/关；手势阈值 0.32 | 左缘右滑/背景点按/xmark/左滑关闭 | ✅ | ⬜ |
| 今日经营报告 | DailyReport/DailyReportSheet.swift | DailyReportSheet | 6 表聚合 | DailyReport.build 口径；shareText 模板（含"临时商品待处理"文案照搬） | — | 复制/分享 | ✅ | ⬜ |

---

## 3. 日程 / 日历

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 日程页 | Features/Schedule/ScheduleView.swift | ScheduleScreen | 复用 CalendarAgenda | ScheduleAgenda.make：timedEvents（真实钟点）/全天（无钟点+临期+备忘）；仅今天注入无截止待办；收支只聚合摘要 | weekStrip（周一起始）/时间轴/全天/当日经营 | 今天按钮；日历图标→日历页；临期行展开；待办勾选 | ✅ | ⬜ |
| 日历页 | Features/Calendar/CalendarView.swift | CalendarScreen（日程内二级入口） | CalendarAgenda.dayData/eventFlags | 周日首列；状态点5色；详情行（营业额/待办/记录/临期/客户） | 月导航 | 月切换 | ✅ | ⬜ |

---

## 4. 小掌柜 AI

（审计来源：docs/audit/C_ai_voice.md 全 10 节，593 行）

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| AI 聊天页 | AI/UI/AIChatView.swift（314 行） | ui/screens/ai/AIChatScreen | ConversationStore（单会话；json 落盘） | AgentCore 对话编排；**无 SSE 流式**（单次 complete；UI 仅 isProcessing+processingLabel 二元态） | 头部说明+Key 状态 pill；emptyState 4 范例句；消息气泡（用户右/助手左+Markdown）；ActionCard；TypingIndicator；语音遮罩面板 | 发送/语音/图片/文件/+菜单/右上 Menu（新对话/清空/AI 设置） | ✅ | ⬜ |
| 业务动作 5 工具 | AI/Tools/ToolCatalog.swift（liteTools 固定顺序） | domain/ai/AiTools.kt | — | searchRecords（只读，read 权限→自动执行不确认）；recordRevenue/createTodo/createMemo/createDelivery（create 权限→**必须 ActionCard 确认**）；addExpiry/update/delete **不注册** | ActionCard 五态：pending/confirmed/executed/duplicate/failed/cancelled；预览模式琥珀横幅"不会真实保存" | 确认记录/修改（回填原文）/不记录；失败可重试 | ✅ | ✅ |
| 执行器与幂等 | Integration/RepositoryToolExecutor.swift（唯一写库执行器） | data/ai/RepositoryToolExecutor | ExecutionJournal（json 落盘，损坏隔离重命名） | 双键幂等：toolCallID（call_<UUID>）+ 业务指纹（rev/todo/memo/del/search 规则）；校验顺序：注册→参数→幂等→Repository 写入→journal markExecuted | — | — | ✅ | ✅ |
| 确认流程 | AI/Core/AgentCore.swift:508-623 | data/ai/AgentCore + domain/ai/PendingAction | PendingActionStore（pending-actions.json，原子写入） | handleToolCall→pending.upsert→ActionCard；confirm→preview 门只置 acknowledged / live 门真实执行；cancel→cancelled；modify→取消旧卡回填原文 | — | — | ✅ | ✅ |
| 意图路由 | AI/Core/IntentRouter.swift（7 case，9 步顺序） | domain/ai/IntentRouter.kt | — | 天气优先→经营分析→商品查询→经营读问答优先（问句绝不落 CREATE）→记账→配送→备忘先于待办→待办→兜底 worldChat；纯规则 0 Token | — | — | ✅ | ✅ |
| 本地解析 | AI/Providers/LocalBusinessParser.swift（Free First 0-Token） | domain/ai/LocalBusinessParser.kt | — | **无 Key 时本地 CREATE 照常工作**；8 示例规则（金额/房号/人名/商品/歧义时钟追问绝不静默回落） | clarify 追问 | — | ✅ | ✅ |
| Provider 配置 | AI/Core/AISettings.swift | data/ai/AiSettings + OpenAiCompatProvider | — | 默认 DeepSeek（https://api.deepseek.com，deepseek-flash/deepseek-v4-pro）；temperature 0.2 硬编码；**无流式/SSE**；ProviderChain 只跳 1 次（401/403 不换链）；Key 只进 Keychain→Android Keystore | 设置页 tier 三档/主备 baseURL+模型+Key/搜索 provider 四档；连接测试状态胶囊（仅真实成功才绿） | 配置/测试连接 | ✅ | ⬜ |
| 旧引擎 | Features/Assistant/BusinessAssistantEngine.swift | 首页摘要本地计算 | BusinessAssistantInput（6 模型快照） | 本地纯规则只读；退化为首页每日摘要/洞察计算；聊天页真正引擎是 AgentCore | — | — | ✅ | ⬜ |
| 短语音 | AI/Voice/ShortVoiceSession.swift + ShortVoicePanel | AIChatScreen onVoice→VoiceSheetContent（复用语音链路） | — | 复用 SpeechService；3 秒静音收尾；final 为空→failed；转写后走相同 send 流程；失败保留转写填回输入框 | idle/listening/finalizing/failed；三种取消（按钮/遮罩/失败关闭） | 语音输入 | ✅ | ⬜ |
| 能力 | AI/Capabilities/（Vision/Document/URLReading/WebSearch） | data/ai/Skills.kt | — | 均为只读不产生 ActionCard；Vision/Document 经 OpenAI 兼容 chat/completions；WebSearch 三档（Tavily/JSON 代理/免费优先，默认 disabled）；**上云 context 恒空**（经营数据不随云端 CREATE 外发） | — | — | ✅ | ⬜ |
| 技能 | AI/Skills/（GoodsLookup/MetaReply/Weather） | domain/ai/ | — | 商品本地查询/元问题固定回复/本地天气回答（降雨≥60% 追加配送提示） | — | — | ✅ | ⬜ |

---

## 5. 待办

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 待办列表 | Features/Todo/TodoView.swift | TodoScreen | TodoEntity ✅ | ✅ 5 tab 过滤（今天/明天/逾期/已完成/备忘）；时间轴分组（上午/下午/晚上/待安排）；排序规则 | statsCard；空态文案5种 | 勾选完成（0.3s 动画后移出）；trash→确认删除；点行→编辑 | ✅ | ⬜ |
| 待办编辑器 | TodoEditorSheet.swift | TodoEditorSheet | TodoEntity ✅ | ✅ 标题必填；截止开关（默认今日9:00）；优先级低/中/高；图片 | 保存 disabled 态 | 保存/取消 | ✅ | ✅ |
| 备忘 tab | TodoView.swift records | （同待办页内） | MemoEntity ✅ | ✅ updatedAt 倒序两列 grid | — | 同 Memo 交互 | ✅ | ⬜ |

---

## 6. 客户配送

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 客户列表 | Features/Customer/CustomerView.swift | CustomerScreen | CustomerRequestEntity ✅ | ✅ 筛选（全部/待处理/配送中/已完成）+createdAt 倒序；displayTitle 隐藏编码串 | 空态2种；完成 toast | 右滑推进（pending→delivering→done）；长按菜单（编辑/复制地址/删除）；行内推进按钮 | ✅ | ⬜ |
| 客户编辑器 | CustomerEditorSheet.swift | CustomerEditorSheet | CustomerRequestEntity ✅ | ✅ 内容+地址双必填；配送时间开关；备注；customer 字段编解码（xzg-delivery-v1:） | — | 保存/取消 | ✅ | ✅ |

---

## 7. 临期退货

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 临期列表 | Features/Expiry/ExpiryView.swift | ExpiryScreen | ExpiryItemEntity ✅ | ✅ 分组（已过期/3天内/7天内/30天内/30天外/已退货）；daysLeft 按0点算；三格统计 | badge 文案（还剩N天/已过期N天/已退货） | 退货/恢复按钮（无确认）；trash→确认删除；点行→编辑 | ✅ | ⬜ |
| 临期编辑器 | ExpiryEditorSheet.swift | ExpiryEditorSheet | ExpiryItemEntity ✅ | ✅ 名称必填+数量>0；到期日不可选过去；提前提醒3/7/15天（仅通知用，不参与分组） | — | 保存/取消 | ✅ | ⬜ |

---

## 8. 商品（临时商品）

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 商品列表 | Features/Goods/GoodsView.swift | GoodsScreen | GoodsEntity ✅ | ✅ 搜索（名称/条码）+分类筛选；状态判定（已过期>即将到期>库存不足>正常）；统计4格 | 导航标题"临时商品"；空态无新增按钮 | 整卡→编辑；pencil→编辑；trash→直接删除无确认 | ✅ | ⬜ |
| 商品编辑器 | GoodsEditorSheet.swift | GoodsEditorSheet | GoodsEntity ✅ | ✅ 名称必填；分类5选；库存/价格/条码/生产日期/保质期/到期日/备注/图片 | — | 保存/取消（失败静默） | ✅ | ⬜ |

---

## 9. 经营数据 / 交易记录

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 经营数据页 | Features/Performance/PerformanceView.swift | PerformanceScreen | Performance/Expense Entity ✅ | ✅ Hero（本月+今日+昨日对比+7天趋势）；关键指标（昨日/今年）；收入来源占比；近30天流水前12 | — | +菜单（记收入/记支出/扫呗导入）；行点击→编辑；trash→确认删除 | ✅ | ✅ |
| 记一笔编辑器 | MoneyEditorSheet.swift | MoneyEditorSheet | Performance/Expense ✅ | ✅ 金额>0 必填；收入来源3选；支出分类5选；日期 | 4 模式（新收入/新支出/编辑收入/编辑支出） | 保存/取消 | ✅ | ⬜ |
| 交易记录 | TransactionHistoryView.swift | TransactionHistoryScreen | Performance/Expense ✅ | ✅ insetGrouped 风格；搜索；只读无编辑/删除 | 空态 | 搜索 | ✅ | ⬜ |
| 扫呗导入 | Features/Import/SaobeiImportSheet.swift | SaobeiImportScreen | SaobeiParsedRow→Performance ✅ | ✅ CSV/XLSX/截图OCR 解析；fingerprint 去重；单次落库；Demo 假提交 | 解析中/预览/结果卡 | 选文件/截图/确认导入 | ✅ | ⬜ |

---

## 10. 备忘（记录）

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 备忘列表 | Features/Memo/MemoView.swift | MemoScreen | MemoEntity ✅ | ✅ 搜索+筛选（全部/文字/图片/语音恒空）；updatedAt 倒序；色条=createdAt 秒%3 | 导航标题"记录"；空态 | 点卡→编辑；trash→确认删除 | ✅ | ⬜ |
| 备忘编辑器 | MemoEditorSheet.swift | MemoEditorSheet | MemoEntity ✅ | ✅ 标题或内容任一必填；标题≤100/内容≤2000 静默截断 | — | 保存/取消 | ✅ | ✅ |

---

## 11. 快速记录 / 语音

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 快速记录 | Features/QuickRecord/QuickRecordSheet.swift | QuickRecordSheet | 各 Entity | QuickRecordParser 分流（营业额→备忘→待办→配送→临期→兜底备忘）；金额缺失写0（与语音链路不一致，待产品确认） | 识别结果卡；类型覆盖菜单 | 输入/语音/确认保存 | ✅ | ✅ |
| 语音记一笔 | Features/Voice/VoiceView.swift | VoiceSheet | 各 Entity | VoiceParser（独立规则，有 expense）；静音3s 自动结束；金额缺失报错；textFallback | 8 态状态机；装饰波形 | 录音/停止/类型覆盖/确认保存 | ✅ | ✅ |

---

## 12. 收款码

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 收款码列表 | Features/PaymentCode/PaymentCodeView.swift | PaymentCodeScreen（我的→工具） | PaymentCode metadata（DataStore JSON）+ 图片文件 | order 追加；删除先删文件；替换先落新后删旧 | 空态；隐私脚注 | 新增/重命名/替换/删除（确认） | ✅ | ⬜ |
| 全屏展示 | PaymentCodeFullScreenView.swift | FullscreenPaymentCode | — | 亮度拉高0.95+退出/后台/异常kill恢复；**图片绝不进 AI/网络** | 黑底；页码；关闭键 | 点击行→全屏；多码滑动 | ✅ | ⬜ |

---

## 13. 天气

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 天气按钮+详情 | Features/Weather/（首页 header） | WeatherButton + WeatherDetailSheet | WeatherSnapshot（内存+缓存） | WeatherAPI.com；Key 经 BuildConfig 注入；30分钟缓存/6小时陈旧降级；定位失败 fallback 恩平 | idle/loading/loaded/notConfigured/unavailable | 点击→详情 sheet；刷新 | 🟡 | ⬜ |

---

## 14. 我的 / 设置

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 我的页 | Features/Profile/ProfileView.swift | ProfileScreen | AppSettings/ThemeStore/DemoMode | 6 分组行项（见 A 报告 §3.1） | toast；版本号 | 12 sheet + 分享/导入/确认框 | ✅ | ⬜ |
| 外观设置 | AppearanceSettingsView.swift | AppearanceScreen | ThemeStore | 显示模式3选；Accent 6；Background 6；壁纸（相册/文件+效果3档+遮罩3档） | — | 选择即时生效 | ✅ | ⬜ |
| 提醒设置 | ReminderSettingsSheet | （Profile 内） | todo_reminder/expiry_reminder | 两 Toggle | — | Toggle | ✅ | ⬜ |
| 数据备份/恢复 | Data/BackupService.swift | （Profile 内） | 7 Entity→JSON v2 | 导出分享真实文件；恢复追加+单次 save+通知重建；v1 兼容 | toast | 分享/选文件/确认 | ✅ | ⬜ |

---

## 15. 通知 / Widget / 快捷指令

| 项 | iOS Source | Android Target | 数据模型 | Repository/业务逻辑 | UI 状态 | Interaction | Android 实现 | Test |
|---|---|---|---|---|---|---|---|---|
| 待办提醒 | Services/NotificationManager.swift:22 | AlarmManager 精确闹钟 | TodoEntity ✅ | todo_reminder开+有dueDate+未完成；年月日时分触发；ID todo-<notificationID> | — | 点击→打开应用 | ✅(调度) | ⬜ |
| 临期提醒 | NotificationManager.swift:47 | 同上 | ExpiryItemEntity ✅ | expiry_reminder开+pending；(expiry-remindDays)当天9:00；过去不调度 | — | 点击→打开应用 | ✅(调度) | ⬜ |
| 客户跟进 | NotificationManager.swift:87 | WorkManager 延时 | CustomerRequestEntity ✅ | 仅 pending；1小时后；离开 pending 取消 | — | 点击→打开应用 | ✅(调度) | ⬜ |
| 主屏 Widget | XiaoZhangGuiWidget/TodayStatsWidget.swift | AppWidgetProvider | BusinessSnapshot ✅ | 今日营业额+焦点2条+问小掌柜/语音记录按钮（xzg://ai, xzg://voice） | 小/中尺寸 | 点击→deep link；待办勾选→直接写库 | ⏭️ | ⬜ |
| Live Activity | Services/LiveActivityManager.swift | 持续性通知 | BusinessSnapshot ✅ | 当日实况；次日0点过期 | 锁屏卡片 | — | ⏭️ | ⬜ |
| Siri 快捷指令×3 | Features/Intents/XZGAppIntents.swift | App Actions | Todo/Performance/Memo ✅ | 新增待办/记录营业额/记记录（后台写库） | — | 语音唤起 | ⏭️ | ⬜ |

---

## 16. 设计系统 / 主题

| 项 | iOS Source | Android Target | 说明 | Android 实现 | Test |
|---|---|---|---|---|---|
| 色板 | DesignSystem/V32/V32Color.swift + V32ThemePalette | theme/Color.kt（light/dark 双套 hex 直译） | Hero/amber/danger/info 固定不随主题；默认 warmCream+emerald | ✅ | ⬜ |
| 字体 | V32Font.swift | theme/Type.kt（字号/字重 1:1；数字等宽） | 中文系统字体；数字 SF Rounded→Android 用等宽数字字体 | ✅ | ⬜ |
| 间距/圆角 | V32Layout.swift / V32Radius.swift | theme/Dimens.kt | pageMargin 22 / card 18 / sheet 28 等 | ✅ | ⬜ |
| 组件库 | V32Components.swift（18 组件） | ui/components/（逐一 Compose 实现） | V32Card/V32Checkbox/V32EmptyState/按钮/进度条/分段选择等 | ✅ | ⬜ |
| 动效 | V32Motion.swift | Motion.kt | 时长/弹簧参数；Reduce Motion 降级 | 🟡 | ⬜ |

---

## 附：iOS V3.6 明确不迁移项

| 项 | 原因 |
|---|---|
| HeroPrototypeGallery.swift / V35ThemeLabView.swift | #if DEBUG 原型，未接入生产树 |
| RecordEditorSheet（TodoView 私有） | 已无调用方，死代码 |
| V3.6.1 的 Revenue Hero 改版 / Quick Actions | 非 V3.6，不属于 Source of Truth |

---

## 修订记录

- 2026-10-02：Phase 0 初版（基于 A/B/C/D/E 审计报告）。
- 2026-10-02：§4 AI 引擎细节补齐（C 报告终版 593 行：5 工具/ActionCard/幂等/IntentRouter/LocalBusinessParser/Provider 配置/短语音/能力/技能）。
- 2026-10-02：Phase 3 UI 落地——§1/§2/§5/§6/§7/§8/§9/§10/§12/§14/§16 共 36 行标 ✅（11 业务页 + 抽屉 + 深链接 + 收款码 + 我的/设置）；§11 快速记录/语音、§13 天气标 🟡（Phase 4/5 桩已接线）；§3 日程/日历、§4 AI 仍为 Phase 4。
- 2026-10-02：Phase 4 落地——§3 日程/日历（周一/周日开头区分）标 ✅；§4 小掌柜 AI 全部 11 行标 ✅（引擎层 37+28+QuickRecord 测试全绿，UI 文件待 CI 验证）；§11 快速记录/语音标 ✅（测试 ✅）。commit ce4a944。
