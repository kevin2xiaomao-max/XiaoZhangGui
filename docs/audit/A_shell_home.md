# A 部分审计报告：App 壳 / 导航 / 首页 / 抽屉 / 我的 / 设计系统

> 审计范围：`XiaoZhangGui/App/`、`XiaoZhangGui/Features/Home/`、`XiaoZhangGui/Features/Profile/`、`XiaoZhangGui/DesignSystem/`（含 V32/Theme）、`XiaoZhangGui/Components/`
> 分支：`feature/v3.6-ui-ai-expansion` @ `335981badfa7163ad56063662bf0d7b5d2a78451`
> 审计日期：2026-10-02 | 只读审计，未修改任何代码

---

## 0. 总览结论

1. **Tab 结构（5 个，固定）**：首页 / 日程 / 小掌柜 / 待办 / 我的（`RootView.swift:19-41`，`FloatingDock.swift:7-30` AppTab 枚举）。
2. **首页是 V3.6「Home 1.4 Compact」收口形态**（ReleaseNotes.swift:24）：Revenue Hero 为 `V35HomeRevenueHero`（48pt 圆体大数字 + 右侧火花线 + 本月/目标/完成三指标 + 3pt 进度条）。**未发现 V3.6.1 新增视觉**（全仓无 `V36` 前缀文件、无 `QuickAction` 文件，Hero 结构与 ReleaseNotes 描述的 1.4 Compact 一致）。
3. **`HeroPrototypeGallery.swift` 与 `V35ThemeLabView.swift` 为 `#if DEBUG` 独立原型**（均未被生产视图树引用，见文件头注释），Android 迁移时**不需要移植**，但可作为视觉参考。
4. 设计系统是双代并存：V21（遗留，仅 BusinessComponents / GlassSurface / V21FAB 等部分复用）+ **V32 为当前唯一事实标准**（所有生产页面走 V32 token）。
5. 主题系统：`ThemeStore`（@Observable 单例，UserDefaults 持久化）+ 6 套 AccentTheme + 6 套 BackgroundTheme + 壁纸（文件落盘 Application Support，支持原图/柔和/模糊三档 + 轻/中/强三档遮罩）。
6. 深链接：`xzg://` 自定义 Scheme，4 条路由（voice / quickrecord / ai / ai?mode=voice），`AppDeepLink.route` 为纯函数（可单测）。
7. 测试缺口：ProfileView / AppearanceSettingsView / V35HomeRevenueHero / HomeStats **零测试覆盖**（Tests/ 无任何引用）。

---

## 1. App 壳（XiaoZhangGui/App/）

### 1.1 XiaoZhangGuiApp.swift

**启动流程**（`XiaoZhangGuiApp.swift:29-59`）：

```
App init()
├─ 单元测试宿主（NSClassFromString("XCTestCase")）→ container = nil，渲染 Color.clear（body:62-65）
├─ #if DEBUG && UITestMode（launch args 含 --ui-testing）→ 内存 ModelContainer + UITestSeed 种子数据（32-44）
├─ PaymentCodeBrightnessGuard.applyStartupRecovery()（V3.3 Lite 收款码亮度恢复，46 行）
└─ AppDatabase.makeContainer() → 真实 SwiftData 持久容器；失败则 container=nil + 保留 databaseError（47-57）

body
├─ 测试宿主 → Color.clear
├─ container 存在 → RootView().id(demo.sessionID)
│    .modelContainer(demo 启用 ? DemoCatalog.container : container)
│    .environment(AppSettings.shared) / .environment(ThemeStore.shared)
│    .tint(V32.brand) / .preferredColorScheme(settings.colorScheme)
│    .task { NotificationManager.requestAuthorization(); 构建 SnapshotSyncManager 快照并落盘; WidgetCenter.reloadAllTimelines(); LiveActivityManager.startIfNeeded }
└─ container 为 nil（P0-2）→ ContentUnavailableView("数据存储暂不可用"，externaldrive.badge.exclamationmark) + 错误描述（85-92）

scenePhase 变化（active / background）→ 重新 buildSnapshot 并落盘、刷新 Widget，active 时尝试启动 Live Activity（95-105）
```

**关键语义（Android 必须保留）**：
- P0-2：持久化失败**绝不静默回退 in-memory**，显式报错页（`XiaoZhangGuiApp.swift:23-25, 84-92`）。
- P1-4：快照构建失败时**保留上一次有效快照**，不覆盖（`XiaoZhangGuiApp.swift:70-74, 101-103`）。
- DemoMode 切换时 `.id(demo.sessionID)` 强制重建整个 RootView 树（62 行），Demo 数据走独立 `DemoCatalog.container`。

### 1.2 RootView.swift — 5 Tab 导航壳

**UI 结构**（`RootView.swift:16-58`）：
```
TabView(selection: $tab)
├─ Tab("首页", house) → NavigationStack → HomeView(tab/showVoice/showQuickRecord/showsVoiceButton 绑定下传)
├─ Tab("日程", calendar) → NavigationStack → ScheduleView()
├─ Tab("小掌柜", sparkles) → NavigationStack → AIChatView(voiceDeepLink: $showAIVoice)
├─ Tab("待办", checkmark.circle) → NavigationStack → TodoView()
└─ Tab("我的", person) → NavigationStack → ProfileView(tab/showVoice/showsVoiceButton)
.tint(V32.brand)
RootTabBarBehavior(): iOS 26+ → .tabBarMinimizeBehavior(.onScrollDown)，低版本无此行为（63-71）
.sheet(QuickRecordSheet) / .sheet(VoiceView, detents [.height(260), .height(340)], 圆角 28)
.onOpenURL → handleDeepLink
```

**深链接路由**（`RootView.swift:74-87` + `Features/Assistant/AI/Core/AppDeepLink.swift`）：
| URL | 行为 |
|---|---|
| `xzg://voice` | 打开语音 Sheet（showVoice=true） |
| `xzg://quickrecord` / `xzg://quick` | 打开快速记录 Sheet |
| `xzg://ai` | tab 切到小掌柜 |
| `xzg://ai?mode=voice` | tab 切到小掌柜 + 拉起短语音面板（showAIVoice→AIChatView.voiceDeepLink） |
| 未知 host | 忽略，不崩溃 |

**交互**：tab 切换记录 lastContentTab（57-59）；语音按钮可用性由 `SpeechService.canInitializeRecognizer` 静态决定（14 行）。

### 1.3 UITestMode.swift / ReleaseNotes.swift

- `UITestMode.isEnabled`：仅 DEBUG，launch args 含 `--ui-testing`；`--ui-testing-id <token>` 决定隔离存储目录（`UITestMode.swift:7-29`）。
- `UITestSeed.seed`：预置 百威啤酒/可口可乐 商品、1 条待办、1 条 ¥680 美团营业额（31-42）。
- `ReleaseNotes.current`：V3.6 更新说明内容（营销文案，Android「关于」页需 1:1 移植文案）；`versionDisplay` = `V3.6.0（36）`（`ReleaseNotes.swift:17-19`）。注意 AboutSheet 内按钮文案为 "V3.5 新变化"（ProfileView.swift:928）——**历史文案残留，非功能 bug**。

---

## 2. 首页（XiaoZhangGui/Features/Home/）

### 2.1 数据模型

**TodaySummary**（`TodaySummary.swift:4-39`，纯 struct，`build(performances:todos:customers:expiryItems:now:)`）：
- `revenue`：当日 Performance 求和
- `yesterdayRevenue`：昨日求和 → `changePercent`（昨日为 0 时为 nil，不显示涨跌）
- `todos`：未完成 且（无截止 或 截止为今天），按 dueDate 升序
- `deliveries`：statusEnum != .done 的客户需求
- `pendingExpiry`：status == .pending 的临期项
- `trend`：`PerformanceTrend.last7Days`（7 日火花线数据）

**HomeStats**（`HomeModel.swift:4-48`）：含 `urgentExpiryCount`（7 天内到期且 pending）、`goalProgressPercent`（今日营业额 ÷ 月目标/30）。**注意：HomeView 当前实际未使用 HomeStats**（HomeView 用的是 TodaySummary + 自算 monthRevenue/monthGoal），文件头注释称「对齐 Android HomeViewModel 计算逻辑」——是跨平台对齐用的共享口径，Android 应直接采用其公式。

**HomeInboxItem**（`Utilities/DisplayLogic.swift:119-137`）+ `HomeInbox.items`（同文件 139-190）：
- 字段：id（`todo-<notificationID>` / `delivery-<notificationID>` / 临期）、date、rank、time、title、subtitle、tone（normal/accent/warning/urgent）、route（todo/customer/expiry）
- rank：高优先级待办=1、配送中=2、普通配送=3、普通待办=4；**limit=3**（HomeView:50 传 3），DisplayLogicTests 断言上限 4 且紧急优先（`DisplayLogicTests.swift:41`）。

### 2.2 HomeView — 页面结构树（`HomeView.swift:7-250`）

```
HomeView（ScrollView，scrollIndicators 隐藏，v32PageBackground，顶部 safeAreaPadding 12）
├─ VStack(spacing: 24)，horizontal padding 20，top 6
│  ├─ ① header（HStack，145-176）
│  │   ├─ 左：问候语（subheadline/medium，textSecondary）
│  │   │     "早上好/中午好/下午好/晚上好"（按本地小时：<11/<14/<18，其余晚上好；178-184）
│  │   ├─ 左：店主名（30pt bold rounded，textPrimary，空→"老板"；187-194）
│  │   ├─ 左：日期（footnote/medium，textTertiary，格式 "M月d日 星期X"，zh_CN；163-166）
│  │   └─ 右：weatherButton（mic 无；点击 → showWeatherSheet）
│  │        图标（cloud.sun 默认，16pt）+ 温度（subheadline/semibold/等宽数字）/ textSecondary
│  │        .task → weatherModel.loadIfNeeded()（217）
│  ├─ ② V35HomeRevenueHero（见 2.3；点击 → route=.performance）
│  ├─ ③ weekRail（HStack spacing 6，197-215）
│  │     本周 7 天（周一起始，符号 一..日）；每格：星期符号（caption2/medium）+ 日期数字（subheadline/semibold/等宽）
│  │     今天：背景 accentPalette.accent 圆角 14，文字 onAccent；其余 textSecondary；minHeight 48
│  ├─ ④ V35HomeFocusSection("今日事项"，见 2.4；待办勾选 → toggleTodo 走 TodoRepository.toggleComplete）
│  ├─ ⑤ V35HomeRecentMemo（仅 memos 非空时，取前 2；点击 → route=.memo）
│  └─ ⑥ V35HomeOverviewGrid（待办/配送/临期 三格；点击 → tab=.todo / route=.customer / route=.expiry）
├─ Toolbar
│   ├─ topBarLeading：line.3.horizontal → showUtilityDrawer=true（"打开经营快捷中心"）
│   └─ topBarTrailing：mic.fill → showQuickRecord=true（"一句话快速记录"）
├─ .toolbar(showUtilityDrawer ? .hidden : .visible, for: .navigationBar)（抽屉打开时隐藏导航栏）
├─ navigationDestination(HomeRoute): customer→CustomerView / expiry→ExpiryView / performance→PerformanceView / memo→MemoView（199-207）
├─ .sheet → WeatherDetailSheet（.medium detent）
├─ .overlay → V35DrawerContainer（showUtilityDrawer 时，zIndex 100）
└─ .overlay(alignment:.leading) → 左边缘 26pt 透明热区：右滑手势（minimumDistance 12）→ V35DrawerGestureLogic.shouldOpen 则开抽屉（219-240）

入场动画：各 section V32HomeEntrance（opacity 0→1 + y 8，delay 0/0.04/0.06/0.08；Reduce Motion 仅短淡入）（252-268）
错误处理：stateActionError → "操作失败" alert（108-110）
```

**State/绑定**（`HomeView.swift:9-27`）：
- `@Binding tab/showVoice/showQuickRecord`（RootView 下传）；`@Query` 全量：todos、performances、expiryItems、customers、memos（updatedAt 倒序）
- `monthRevenue`：本月 Performance 求和（Demo 模式走 DemoCatalog.monthlyRevenue；31-37）；`monthGoal`：Demo 走 DemoCatalog.monthlyGoal 否则 settings.monthGoal（39-41）
- `toggleTodo`：仅 route==.todo 的行；TodoRepository.toggleComplete，成功 Haptic（success/light），失败 → stateActionError 弹窗（223-232）

### 2.3 V35HomeRevenueHero（`V35HomeRevenueHero.swift:1-36`）

```
Button（整卡可点，plain 样式；a11y："今日营业额 X，点击查看经营数据"）
└─ VStack(spacing 10)，padding H22/V15，背景：accentPalette.heroStart→heroEnd 对角渐变，圆角 18
   ├─ HStack(top)
   │   ├─ 左 VStack(spacing 4)
   │   │   ├─ "今日营业额"（subheadline/medium，textOnHeroSecondary）
   │   │   ├─ "¥<千分位>"（48pt bold rounded，monospacedDigit，textOnHero；minScaleFactor 0.56；contentTransition numericText）
   │   │   └─ 涨跌 Label（可选）："±X.X% 较昨日"（caption/semibold，brandOnHero；↑ arrow.up.right / ↓ arrow.down.right）
   │   └─ 右：HomeSparkline（7 日趋势，92×26，仅当有 >0 数据点；颜色 accentPalette.chartAccent）
   ├─ Divider（dividerOnHero 0.7）
   ├─ HStack(spacing 18)：本月 / 目标 / 完成（caption + subheadline semibold 等宽数字）
   └─ GeometryReader 进度条：高 3pt 胶囊，底 textOnHero 0.16，填充 secondaryAccent，宽 = progress（月目标>0 时 monthRevenue/monthGoal 钳制 0..1）
```

### 2.4 V35HomeFocusSection / HomeActionRow（`V35HomeFocusSection.swift` + `HomeView.swift:271-322`）

```
V35HomeFocusSection（"今日事项" V32SectionHeader）
├─ 空态：Label("今天暂无待处理事项"，checkmark；subheadline，textTertiary）
└─ 非空：VStack（取前 3）
    HomeActionRow（HStack spacing 14，vertical padding 14，minHeight 64；整行可点）
    ├─ leading：待办→V32Checkbox（26pt 圆；未勾选）/ 客户→box.truck.fill（brand）/ 临期→hourglass（amber），28×28
    ├─ 中：标题（v32Text .title，2 行）+ 副标题（.caption，textTertiary，1 行，可空）
    ├─ 右：time（.caption，textTertiary）+ chevron.right（11pt semibold，textQuaternary）
    └─ 第 1 行后 Divider（leading 48）
待办行勾选 → onTodoToggle；整行点击 → open(route)：todo→tab=.todo / customer→route=.customer / expiry→route=.expiry
```

### 2.5 V35HomeOverviewGrid（`V35HomeOverviewGrid.swift:1-65`）

```
HStack（上下 Divider 0.6，vertical padding 12）
├─ 待办：checkmark.circle（brand）| "待办" caption2/textTertiary | 数量 subheadline semibold 等宽 | insight（可选，如"今天到期"）
├─ 竖线（1×24，divider 0.7）
├─ 配送：box.truck（info）| 同结构（insight 如"待配送"）
├─ 竖线
└─ 临期：clock.badge.exclamationmark（amber）| 同结构（insight 如"≤3天"）
每格 Button（plain），minHeight 44；a11y："今天<标题><N>项" + hint "打开<标题>"
```

### 2.6 V35HomeRecentMemo（`V35HomeRecentMemo.swift:1-59`）

```
"最近备忘"（V32SectionHeader）→ 整块 Button（plain）→ route=.memo
每行（HStack firstTextBaseline spacing 10，vertical 11，minHeight 44）：
├─ 图标：note.text（无图）/ photo（有图），caption/semibold，info 色，宽 18
├─ 中：标题（subheadline/semibold，1 行；空标题→内容/无标题）+ 内容（caption，textTertiary，仅标题非空且内容非空）
└─ 右：Fmt.memoTime(updatedAt)（caption2，textQuaternary）
行间 Divider（leading 28）
```

### 2.7 V35SideUtilityDrawer（抽屉，`V35SideUtilityDrawer.swift:1-111`）

```
V35DrawerContainer（isPresented 绑定；zIndex 100 覆盖层）
├─ GeometryReader：宽 = clamp(屏宽×0.84, 300, 380)
├─ 背景：Color.black 0.23 全屏（点按关闭）
├─ 抽屉体：ScrollView + VStack，背景 V32.cardElevated，右侧圆角 32（topTrailing/bottomTrailing），ignoresSafeArea
│   ├─ 顶部：右上 xmark 关闭钮（34×34 圆形，subtleTint 底）
│   ├─ "经营"：交易记录（list.bullet.rectangle）/ 今日经营报告（doc.text.magnifyingglass）/ 客户需求（person.2）/ 临期退货（clock.badge.exclamationmark）
│   ├─ "工具"：商品（shippingbox）/ 备忘（note.text）
│   └─ "快捷操作"：快速记一笔（plus.circle）/ 扫呗导入（square.and.arrow.down）
├─ 行样式：图标（body/semibold，accent 色，宽 26）+ 标题（body，textPrimary），vertical 10，minHeight 44；分组标题 caption/semibold tracking 1.1 大写
├─ 打开手势：HomeView 左缘 26pt 热区右滑 → V35DrawerGestureLogic.shouldOpen（translation/predicted > 宽×0.32）
├─ 关闭：背景点按 / xmark / 左滑手势（shouldClose，同阈值）/ 抽屉出现时 Haptic.light
└─ 打开动画：spring(response 0.34, damping 0.88)；Reduce Motion → easeOut 0.16
```

**目的地路由**（`V35DrawerDestination.swift:4-27`，8 个）：
| 目的地 | 导航方式 |
|---|---|
| 交易记录 | NavigationLink → TransactionHistoryView（关闭抽屉，simultaneousGesture） |
| 客户需求 | NavigationLink → CustomerView |
| 临期退货 | NavigationLink → ExpiryView |
| 商品 | NavigationLink → GoodsView |
| 备忘 | NavigationLink → MemoView |
| 今日经营报告 | Sheet → DailyReportSheet（Report.build：performances/todos/customers/expiryItems） |
| 快速记一笔 | Sheet → QuickRecordSheet |
| 扫呗导入 | Sheet → SaobeiImportSheet |

**注意**：抽屉内的 NavigationLink 依赖外层 HomeView 的 NavigationStack 上下文；抽屉本身是 overlay 浮层。

### 2.8 非生产文件（不需迁移）

- `HeroPrototypeGallery.swift`（625 行，`#if DEBUG`）：Hero A/B/C 三套视觉原型 + `HeroA3HomePreview` 完整 Home 上下文预览；文件头明确 "not referenced by the app's production view tree"（3 行）。
- `V35ThemeLabView.swift`（184 行，`#if DEBUG`）："Fixed preview data only; never connected to HomeView"；含主题实验室导航标题 "主题实验室"。

---

## 3. 我的（XiaoZhangGui/Features/Profile/）

### 3.1 ProfileView — 页面结构树（`ProfileView.swift:1-1175`）

```
ProfileView（ScrollView；v32PageBackground；navigationTitle "我的"，inline；padding H=pageMargin(22)，top 8）
├─ ① profileHero（Button → shopDialog；117-151）
│    storefront.fill（20pt semibold，brand，宽 28）
│    店名（v32 .section，textPrimary，空→"我的小店"）/ "店主名 · 你的小掌柜"（v32 .subhead，textTertiary，空→"老板"）
│    chevron.right（12pt semibold，textQuaternary）
├─ ② personalSection「个性化」
│    显示模式（circle.lefthalf.filled，info）值=themeModeLabel → themeDialog（ThemeChoiceSheet）
│    外观（paintpalette，brand）值=accentTheme.displayName → appearanceSheet（AppearanceSettingsView）
│    背景风格（square.on.square，neutral）值=backgroundTheme.displayName → backgroundSheet（BackgroundThemeSheet）
│    壁纸（photo，amber）值=已设置/未设置 → wallpaperSheet（WallpaperSheet）
├─ ③ businessSection「经营」
│    月营业目标（scope，brand）值=千分位整数 → goalDialog（GoalEditSheet）
│    提醒设置（bell，amber）值=已开启/已关闭（任一提醒开） → reminderDialog（ReminderSettingsSheet）
├─ ④ demoSection「演示」（Demo Mode Toggle）
│    Demo Mode（wand.and.stars，info，Toggle，tint brand）
│    启用时：琥珀提示文案 + "重置演示数据"（arrow.clockwise，"独立内存"，无 chevron）→ demo.resetDemoData() + toast
├─ ⑤ dataSection「数据与应用」
│    数据备份（square.and.arrow.down，neutral，"JSON 文件"，无 chevron）→ BackupService.exportFileURL → ShareSheet 系统分享
│    数据恢复（arrow.clockwise，neutral，"JSON"，无 chevron）→ fileImporter(.json) → BackupService.restore → toast "已恢复 N 条记录"
│    清理缓存（paintbrush）→ confirmationDialog（仅清 URLCache，不删业务数据）
│    关于你的小掌柜（info.circle，info）→ aboutDialog（AboutSheet）
│    隐私说明（lock.shield）→ privacyDialog（InfoSheet，文案见 153-155 行）
└─ ⑥ 底部居中："v<CFBundleShortVersionString>"（.caption，textQuaternary）
行通用样式：ProfileRow（图标 16pt medium，tone 色，宽 24；标题 v32 .title；右侧值 .caption/textTertiary；chevron 11pt；minHeight 54；按压 V32PressButtonStyle；点击 Haptic.light）
分组样式：settingsGroup（标题 .caption/textTertiary，leading 4；行间 divider leading 48）
toast：底部 overlay，胶囊卡片，2 秒自动消失（227-241）
navigationDestination(toolRoute 字符串路由)：calendar/performance/customer/expiry/goods/paymentCode → 对应 View（当前 ProfileView 内无入口触发 toolRoute，路由为历史保留）
```

**Sheets 清单**（全部 `V32SheetChrome` 容器：标题居中 + 右上 完成/关闭 + `.v32Sheet(detents)` + v32PageBackground）：
| Sheet | 内容 |
|---|---|
| ShopEditSheet | 店铺名称 + 店主称呼 两个 TextField；均非空才可保存（trim 后判空） |
| GoalEditSheet | ¥ + 金额 TextField（decimalPad）；Double>0 才可保存 |
| ThemeChoiceSheet | 跟随系统/浅色/深色 三行选择（V32IconBubble + checkmark） |
| AppearanceSettingsView | 见 3.2（独立文件） |
| AccentThemeSheet | 6 主题色列表（色圆 28pt + 名称 + 选中 checkmark）；底部说明"仅影响点缀色，Hero 深墨绿与临期/危险色固定不变" |
| BackgroundThemeSheet | 6 背景风格列表（三层同心圆预览 + 名称）；底部说明 |
| WallpaperSheet | 见下 |
| VoiceSettingsSheet | 识别语言分段选择（普通话/粤语，V32SegmentedPicker）；说明"录音仅用于实时识别不保存"；若 showsVoiceButton 则"测试语音"主按钮（dismiss 后打开 VoiceView） |
| ReminderSettingsSheet | 待办提醒 Toggle + 临期退货提醒 Toggle |
| AboutSheet | 图标泡 64pt + "你的小掌柜" + 版本号 + 更新说明卡（headline + "V3.5 新变化"按钮 → ReleaseNotesSheet 大 sheet）+ 关闭钮 |
| InfoSheet（隐私说明） | 纯文本卡 |
| ShareSheet | UIActivityViewController 包真正的 .json 文件 URL（`ProfileView.swift:287-295`） |

**WallpaperSheet**（壁纸设置，`ProfileView.swift:667-866`）：
```
预览卡（140pt 高：当前壁纸图 + 遮罩黑 0.6/0.35 + "当前壁纸 · 效果 · 遮罩" / 未设置占位）
选择来源卡：PhotosPicker（从相册选择，photo.on.rectangle）/ fileImporter(.image)（从文件选择，folder）
（壁纸启用时）效果档：原图/柔和/模糊（图标 sun.max/circle.lefthalf.filled/circle.dashed）
（壁纸启用时）遮罩强度：轻/中/强（图标 circle/circle.fill/circle.large.fill）
删除壁纸（V32SecondaryButton，trash）
错误文案（danger 色）；底部说明："壁纸降采样后落盘到 Application Support，原图不会保留。深色模式自动增强遮罩。"
```
图片处理链：PhotosPickerItem.loadTransferable(Data) / fileImporter → ThemeStore.applyWallpaperImage（降采样 2048/0.84 → 落盘 → 预渲染模糊版 1280/blur28/0.78 → 更新配置 → 删旧文件；失败保留旧壁纸，`ThemeStore.swift:116-164`）。

### 3.2 AppearanceSettingsView（`AppearanceSettingsView.swift:1-113`）

```
ScrollView（navigationTitle "外观"，large；右上"完成" dismiss）
├─ "显示模式"（title3/bold）：HStack 3 按钮（跟随系统 circle.lefthalf.filled / 浅色 sun.max / 深色 moon.stars）
│   选中：文字 brand 色 + 背景 brandSoft + 描边 brand 0.4；未选：textSecondary + card 底 + cardOutline；minHeight 68，圆角 14
└─ "选择主题"：LazyVGrid 2 列（spacing 12/14）
    ThemePreviewCard：主题名 + 选中 checkmark.circle.fill（accent 色）
    ├─ Hero 微缩预览：渐变 heroStart→heroEnd 圆角 12；"今日营业额" + "¥2,680"（22pt bold rounded，onAccent）+ 3pt chartAccent 胶囊
    └─ 中性区微缩：圆点 + "中性内容区域"（secondarySystemBackground 圆角 10）
    选中：描边 accent 2pt；未选：cardOutline 1pt；卡底 systemBackground 圆角 18
点击主题：withAnimation（easeInOut 0.2；Reduce Motion 0.12）+ themeStore.setAccent + Haptic.light
```

### 3.3 Profile 交互与数据绑定

- `@Bindable settings = AppSettings.shared` / `@Bindable demo = DemoMode.shared` / `@Environment(ThemeStore.self)` / `@Query performances`（备份用，P0-1 注释说明不再依赖页面 Query，`ProfileView.swift:20`）。
- 备份/恢复：`BackupService.exportFileURL(context:)` / `BackupService.restore(context:from:)`（单次 save，字段对称；`ProfileView.swift:244-286`）。
- 恢复走 `fileImporter` 安全域（startAccessingSecurityScopedResource）。
- 清理缓存：`URLCache.shared.removeAllCachedResponses()`（确认框，`ProfileView.swift:163-170`）。

---

## 4. 设计系统（XiaoZhangGui/DesignSystem/）

### 4.1 Token 总表

**V32（当前事实标准）**：
| 文件 | 内容 |
|---|---|
| `V32/V32Color.swift` | 语义色：pageBG/pageBGSecondary/card/cardElevated/cardInset/cardOutline/divider/textPrimary~Quaternary（可主题化→ThemeStore）；hero/heroGlow/brandOnHero/brandSoftOnHero/textOnHero/textOnHeroSecondary/dividerOnHero（Hero 固定）；brand/brandSoft（可主题化→accentPalette）；amber/amberSoft/amberOnHero/danger/dangerSoft/info/infoSoft（语义固定）；neutral/neutralSoft（可主题化） |
| `V32/V32Font.swift` | heroMoney 38 bold rounded 等宽 / metric 22 bold rounded 等宽 / metricSmall 15 semibold rounded 等宽 / display 32 bold / pageTitle 26 bold / section 20 bold / headline 16 semibold / title 15 semibold / body 15 regular / subhead 13 regular / caption 12 regular / pill 11 semibold；中文走系统字体（注释：数字用 SF Rounded + 等宽数字） |
| `V32/V32Layout.swift` | pageMargin 22 / sectionGap 26 / cardGap 12 / bottomPad 28 / pageBottomBreathing 12 / floatingTabBarReservation 72 / cardPad 16 / cardPadLarge 18 / heroPad 20 / rowMinHeight 56 / bubbleSmall 36 / bubbleRegular 42 / iconSmall 16 / iconRegular 19 / checkbox 26 / toolCircle 40 / toolIcon 18 / avatarSmall 38 / avatarLarge 64 |
| `V32/V32Radius.swift` | card 18 / cardLarge 24 / bubble 12 / pill 999 / sheet 28 / inset 14 |
| `V32/V32Motion.swift` | quick 0.18 / standard 0.28 / slow 0.42（easeOut）；softSpring(0.35, 0.86) / interactiveSpring(0.28, 0.82)；reducedFade 0.12；V32Motion.resolve(surface, reduceMotion) 纯函数；progressWidth：Reduce Motion 时直切 nil |
| `V32/V32PageBottomInset.swift` | `v32PageBottomInset()`：safeAreaInset bottom 插入 72+12 透明区（为浮动 Tab Bar 预留，禁止各页手写） |
| `V32/V32Font.swift` 另含 | `v32PageBackground()`（壁纸启用→V32WallpaperBackground 作页面背景层；禁用→pageBG）、`v32Sheet(detents)`（圆角 28 + 拖拽指示器） |

**关键色值（默认 warmCream + emerald，light/dark 双值，`V32ThemePalette.swift`）**：
- pageBG: #F4F1E8 / #16181A；card: #FFFFFF / #1F2220；textPrimary: #232623 / #F2F0E9；textSecondary: #60655E / #B8BDB4；textTertiary: #94988F / #898F87；textQuaternary: #AFB3AA / #6B7169
- brand(accent): #2F6B4F / #35D083；brandSoft: #E2EFE7 / #153225；onAccent: #FFFFFF / #0F1F18
- hero 固定: #1F2B24 / #1B2A22；heroGlow: #2C3E33 / #22352A；brandOnHero: #4FBF86 / #35D083；textOnHero: #FFFFFF / #EDF3EE
- amber: #C08A2E / #F2A93B；amberSoft: #F7EDD9 / #382C17；danger: #C9483E / #FF6359；dangerSoft: #F8E5E1 / #3A201D；info: #4A79A8 / #6AA9E0；infoSoft: #E6EEF6 / #182A3A
- Hero 渐变（emerald）：heroStart #234D3A/#173A2B → heroEnd #4C8767/#246B49；chartAccent #2F8A5C/#63D895
- divider/cardOutline: #232623 alpha 0.07-0.08 / #FFFFFF alpha 0.08

**V21（遗留，部分仍在用）**：`V21Color.swift`（brandGreen #1FA971 等；注释声明 AppTheme 旧链路已删除）、`V21Font.swift`（V21TextStyle 13 档 + AppTypography）、`V21Spacing.swift`（pageMargin 20、FAB 48pt 等）、`V21Components.swift`（GlassSurface、PillTabRow、V21FAB、EmptyStateView、bottomDockPadding）。

### 4.2 V32 可复用组件清单（`V32/V32Components.swift`，528 行）

| 组件 | 用途 |
|---|---|
| V32PressButtonStyle | 按压缩放 0.98 + 透明度 0.82（Reduce Motion 仅透明度） |
| V32PageHeader | 二级页头：返回圆钮（40pt，pageBGSecondary 底）+ pageTitle 26 + subtitle + trailing |
| V32ToolButton | 深色圆形工具钮（40pt，hero 底，白图标） |
| V32SearchField | 搜索框（V32Card 包裹，46pt 高，magnifyingglass + 清除钮） |
| V32PillBar | 横向分类胶囊（选中 brand 字 + brandSoft 底） |
| V32Card | 白卡：padding 16，圆角 18，cardOutline 1pt 描边 |
| V32FieldGroup | 轻量字段组（无卡片样式） |
| V32HeroCard | 深墨绿 hero 卡（hero→heroGlow 渐变 + 右上柔光，圆角 24） |
| V32Status / V32StatusPill | 状态胶囊（pending/delivering/done/expiry/info；圆点 6pt + pill 11 semibold） |
| V32BubbleTone / V32IconBubble | 图标泡（brand/amber/danger/info/neutral 五 tone；42pt 圆角 12，可圆形） |
| V32MetricCell | 指标格（caption 标签 + metric 22 数字 + caption 说明） |
| V32SectionHeader | 区块标题（section 20 bold + trailing） |
| V32SectionAction | 尾部动作（"全部 ›" subhead textTertiary） |
| V32Checkbox | 圆形勾选 26pt（选中 brand 底白勾；Reduce Motion 无缩放） |
| V32EmptyState | 空状态（56pt 圆形图标泡 + headline + subhead 说明） |
| V32PrimaryButton / V32SecondaryButton | 胶囊主/次按钮（全宽，vertical 14，headline；主=brand 底白字） |
| V32ProgressBar | 进度条（高 7pt；hero 模式品牌绿亮色；Reduce Motion 直切） |
| V32SegmentedPicker | （Profile 语音设置用；定义在别处，被引用） |

### 4.3 主题系统（`V32/Theme/`）

- `V32ThemeModels.swift`：AccentTheme 6 套（emerald 墨绿/blue 霁蓝/purple 紫罗兰/coral 珊瑚/graphite 石墨/rose 玫瑰；默认 blue——注：ThemeStore 迁移默认组合 warmCream+emerald 等同 b27，`ThemeStore.swift:20`）；BackgroundTheme 6 套（warmCream 暖米默认/pureWhite/sageGreen/hazeBlue/neutralGray/softLilac）；WallpaperEffect（original/soft/blurred）/ WallpaperMaskStrength（light/medium/strong）；WallpaperConfig（Codable，isEnabled + 文件名 + 效果 + 遮罩）
- `ThemeStore.swift`：@Observable 单例；UserDefaults 键 `v32.theme.accent / .background / .wallpaper` + 一次性迁移标记 `v32_theme_migrated`（旧 `app_theme_name` → 新组合，`ThemeMigration.map`）；切换即时全局生效
- `V32Wallpaper.swift`：WallpaperStorage（Application Support/Appearance 落盘 JPEG，blurred 预渲染版，purgeAll）、ImageCodec（降采样/模糊预渲染，CoreGraphics）、V32WallpaperBackground（页面背景层：blurred 预渲染优先 → 回退 .blur；深色模式增强遮罩）
- `V32ThemeEnvironment.swift`：`v32ThemeStore` EnvironmentKey（实际注入走 `.environment(ThemeStore.shared)`，App 入口）

### 4.4 AppSettings（`Utilities/AppSettings.swift`，Profile/首页共用）

| 字段 | UserDefaults 键 | 默认值 |
|---|---|---|
| shopName | shop_name | "天福便利店" |
| ownerName | owner_name | "掌柜" |
| monthGoal | month_goal | 120000.0 |
| themeMode | theme_mode | "system"（system/light/dark） |
| todoReminderEnabled | todo_reminder | true |
| expiryReminderEnabled | expiry_reminder | true |
| voiceLanguage | voice_language | "普通话" |
| avatarEmoji | avatar_image_data | "👨🏻‍💼" |
| avatarImageData | avatar_image_data | nil |

`colorScheme`：themeMode→ColorScheme? 映射（跟随系统→nil），`themeModeLabel` 供 Profile 显示。

### 4.5 FloatingDock.swift / Haptic

- `AppTab`：home/schedule/assistant/todo/profile，title（首页/日程/小掌柜/待办/我的），icon（house.fill/calendar/checkmark/sparkles/person.fill）（`FloatingDock.swift:7-30`）
- `Haptic`：light/medium（UIImpactFeedbackGenerator）、success/warning（UINotificationFeedbackGenerator）（31-38）；`Haptic.error()` 扩展定义在 `Features/Performance/MoneyEditorSheet.swift:227-229`
- 注：本文件已无 Floating Dock UI 本体（仅剩 Tab 标识 + 触感），"Dock" 为历史命名。

### 4.6 Components/

- `TrendChart.swift`（32 行）：Swift Charts 折线（catmullRom 插值，线宽 2，圆角端点）；`hasValues` 为 false 时渲染空；参数 height/showsAxis/onHero
- `PhotoPickerField.swift`（78 行）：PhotosPicker → Data（经 ImageCodec.downscaled 降采样）→ 外部存储；64×64 圆角 14 预览 + 右上 xmark.circle.fill 删除；`ImageThumb` 40pt 列表缩略图

---

## 5. 导航关系总图

```
RootView（TabView，5 Tab）
├─ 首页 Tab → NavigationStack(HomeView)
│   ├─ toolbar 左：抽屉（V35DrawerContainer overlay）
│   │   ├─ NavigationLink → 交易记录/客户需求/临期退货/商品/备忘（push 进同一 NavigationStack）
│   │   └─ Sheet → 今日经营报告 / 快速记一笔 / 扫呗导入
│   ├─ toolbar 右 mic → Sheet(QuickRecordSheet)
│   ├─ 天气按钮 → Sheet(WeatherDetailSheet, .medium)
│   ├─ Hero 点击 → push PerformanceView
│   ├─ 今日事项行 → push CustomerView/ExpiryView 或 tab→待办
│   ├─ 最近备忘 → push MemoView
│   ├─ 概览三格 → tab→待办 / push CustomerView/ExpiryView
│   └─ 左缘右滑 → 抽屉
├─ 日程 Tab → NavigationStack(ScheduleView)
├─ 小掌柜 Tab → NavigationStack(AIChatView)（深链接 ai?mode=voice → 短语音面板）
├─ 待办 Tab → NavigationStack(TodoView)
├─ 我的 Tab → NavigationStack(ProfileView)
│   └─ 12 个 Sheet（见 3.1 表）+ fileImporter + ShareSheet + confirmationDialog
└─ 全局 Sheet（RootView 级）：QuickRecordSheet / VoiceView（detents 260/340，圆角 28）
```

---

## 6. iOS-only API 清单（需 Android 等价实现）

| # | iOS API | 位置 | Android 等价 |
|---|---|---|---|
| 1 | SwiftData `@Query` / ModelContainer / ModelContext | HomeView.swift:14-18, ProfileView.swift:20, XiaoZhangGuiApp.swift | Room + DAO + Flow/StateFlow（ViewModel 层） |
| 2 | Swift Charts（LineMark, catmullRom） | HomeView.swift:305-321（HomeSparkline）, Components/TrendChart.swift | Compose Canvas 自绘折线（推荐，避免引入图表库视觉偏差） |
| 3 | WidgetKit `WidgetCenter.reloadAllTimelines()` + LiveActivityManager | XiaoZhangGuiApp.swift:73,103,95-105 | Glance 小部件 + 常驻通知（Live Activity 无直接等价，需 PLATFORM_DIFFERENCES 说明） |
| 4 | `NotificationManager.requestAuthorization()`（UNUserNotificationCenter） | XiaoZhangGuiApp.swift:67 | POST_NOTIFICATIONS 运行时权限（Android 13+）+ NotificationChannel |
| 5 | UserDefaults（AppSettings/ThemeStore 持久化） | Utilities/AppSettings.swift, ThemeStore.swift | DataStore（Preferences/Proto） |
| 6 | PhotosPicker（PhotosUI） | ProfileView.swift:733-752（WallpaperSheet）, Components/PhotoPickerField.swift | ActivityResultLauncher + PickVisualMedia / GetContent |
| 7 | fileImporter（UTType .json/.image）+ startAccessingSecurityScopedResource | ProfileView.swift:172-174, 279-281, 762-764 | ActivityResultLauncher.OpenDocument（无需安全域概念） |
| 8 | UIActivityViewController（ShareSheet 分享真实 .json 文件） | ProfileView.swift:287-295 | ACTION_SEND / FileProvider 分享 Intent |
| 9 | Haptic（UIImpactFeedbackGenerator/UINotificationFeedbackGenerator） | FloatingDock.swift:33-38, MoneyEditorSheet.swift:228 | Vibrator / View.performHapticFeedback |
| 10 | `UIScreen.main.bounds`（抽屉宽度计算） | HomeView.swift:230 | WindowMetrics / LocalConfiguration（注意 UIScreen.main 已废弃语义） |
| 11 | `.tabBarMinimizeBehavior(.onScrollDown)`（iOS 26） | RootView.swift:66 | 下滑滚动隐藏底部导航（Compose 自行实现 nestedScroll 行为） |
| 12 | presentationDetents([.height(260),.height(340)]) / .medium / .large + presentationCornerRadius(28) + 拖拽指示器 | RootView.swift:49-56, HomeView.swift:213-217 | ModalBottomSheet（Material3）+ 自定义圆角/固定高度 |
| 13 | 自定义 URL Scheme `xzg://` + onOpenURL | RootView.swift:60-61, AppDeepLink.swift | AndroidManifest intent-filter（scheme="xzg"）+ onNewIntent 处理 |
| 14 | Launch args `--ui-testing` / `--ui-testing-id`（UITestMode） | UITestMode.swift, XiaoZhangGuiApp.swift:32 | BuildConfig / testInstrumentationRunnerArguments |
| 15 | SpeechService.canInitializeRecognizer（语音按钮门控） | RootView.swift:14, HomeView 透传 | SpeechRecognizer.isRecognitionAvailable / RecognizerIntent |
| 16 | CoreGraphics ImageCodec（降采样/blur 预渲染） | V32Wallpaper.swift:73-147 | BitmapFactory.Options(inSampleSize) + RenderEffect/RenderScript blur |
| 17 | Application Support/Appearance 壁纸文件落盘 | V32Wallpaper.swift:17-71, ThemeStore.swift:119-164 | Context.filesDir / noBackupFilesDir |
| 18 | `Color(UIColor { traitCollection })` 动态 trait 颜色 | V32Color.swift, V21Color.swift | isSystemInDarkTheme() + 双套色板（已有 light/dark hex，可直译） |
| 19 | `.contentTransition(.numericText)` 数字滚动 | V35HomeRevenueHero.swift:16 | Compose AnimatedContent / 数字滚动动画 |
| 20 | `.monospacedDigit()` | 多处 | FontFamily.Monospace / tabular figures |
| 21 | SF Symbols（house/sparkles/mic.fill/line.3.horizontal 等全部图标） | 全范围 | 需逐一映射 Material Symbols / 自绘（图标清单见各节 systemName） |
| 22 | `.glassEffect(.regular)`（iOS 26，GlassSurface） | V21Components.swift:11-14 | RenderEffect blur 降级方案（GlassSurface 当前生产引用少，低优先级） |
| 23 | Reduce Motion（accessibilityReduceMotion）分支 | V32Motion.swift, HomeView.swift:253-268 等 | Settings.Global.ANIMATOR_DURATION_SCALE / AccessibilityManager |
| 24 | Bundle.main CFBundleShortVersionString/Version | ReleaseNotes.swift:13-19, ProfileView.swift:223-225 | PackageManager versionName/versionCode |
| 25 | `.toolbar(..., for: .navigationBar)` 显隐导航栏 | HomeView.swift:195 | Compose TopAppBar AnimatedVisibility |
| 26 | safeAreaPadding / safeAreaInset / v32PageBottomInset | HomeView.swift:106, V32PageBottomInset.swift | WindowInsets（statusBars/navigationBars/ime）+ edge-to-edge |

---

## 7. 测试覆盖情况（Tests/）

| 测试文件 | 覆盖的 A 范围内容 | 方法数 |
|---|---|---|
| Tests/AI/AppDeepLinkTests.swift | 深链接路由：voice/quickrecord/ai/ai?mode=voice/未知 host 忽略/纯函数入口 | 6 |
| HomeQuickEntryAuditTests.swift | 首页无重复小掌柜卡、header 保留 mic 快速记录入口、AIChatView TabBar 隐藏、快速记录保存门禁（源码审计型测试） | 4 |
| DisplayLogicTests.swift | 问候语时段、DisplayText、Todo 分组、Inbox 上限 4/紧急优先、TodaySummary.build | 6 |
| V35DrawerTests.swift | 抽屉 8 目的地标题/图标稳定、手势 progress/shouldOpen/shouldClose 阈值 | 2 |
| V32MotionTests.swift | 动效时长/弹簧参数/spec 对齐、Reduce Motion 降级、progressWidth | 6 |
| ThemeMigrationTests.swift | 旧 app_theme_name→新主题映射、迁移幂等、已有保存值优先 | 10 |
| ThemeSelectorTests.swift | 6 套主题枚举、rose 持久化、调色板互异 | 3 |
| WallpaperLifecycleTests.swift | 壁纸替换删旧留新、失败保留旧壁纸、清除删文件 | 3 |
| Phase52AccessibilityMotionTests.swift | Reduce Motion 分支显式、核心行可访问性命中区 | 3 |
| EmptyStateTests.swift | Customer/Expiry 空状态（部分相关） | 3 |
| UITests/XiaoZhangGuiUISmokeTests.swift | 启动 + AI 回复本地化等（10/10 XCUITest 门禁，ReleaseNotes 提及） | ~10 |

**零覆盖（缺口）**：
- `ProfileView`（1175 行，12 个 Sheet + 备份/恢复/壁纸）：Tests/ 无任何引用
- `AppearanceSettingsView`：无测试
- `V35HomeRevenueHero`：无测试
- `HomeStats.compute`：无测试（TodaySummary.build 有 DisplayLogicTests 间接覆盖）
- `V35HomeOverviewGrid` / `V35HomeRecentMemo` / `V35HomeFocusSection`：无测试
- `ReleaseNotes` 文案：无测试

---

## 8. V3.6.1 污染检查

**结论：未发现 V3.6.1 新增视觉。** 证据：
1. 全仓 `grep -rln "V36" XiaoZhangGui/` → 零命中（V3.6.1 分支的 V36 前缀组件不存在）。
2. 全仓 `grep -rln "QuickAction" XiaoZhangGui/` → 零命中（V3.6.1 的 Quick Actions 不存在）。
3. Revenue Hero 为 `V35HomeRevenueHero`（V35 前缀，48pt 数字 + 火花线 + 三指标 + 3pt 进度条），与 ReleaseNotes "Home 1.4 Compact 最终收口" 描述一致；V3.6.1 的 Revenue Hero 改版不在此分支。
4. 首页 Tab 顺序为 首页/日程/小掌柜/待办/我的（5 Tab，`RootView.swift:19-41`），无 V3.6.1 的改动痕迹。
5. 两个可疑文件（HeroPrototypeGallery / V35ThemeLabView）均为 `#if DEBUG` 且明确声明不接入生产树，不构成污染。

---

## 9. 给 Android 迁移的关键语义清单（本范围）

1. **首页数据口径**：今日营业额=当日 Performance 求和；涨跌=(今-昨)/昨（昨日为 0 不显示）；今日事项=未完成且（无截止/截止今天）；月进度=本月累计/月目标；日均目标=月目标/30（HomeStats 公式）。
2. **Inbox 上限 3**（首页今日事项），rank 排序：高优待办 > 配送中 > 普通配送 > 普通待办。
3. **抽屉 8 目的地固定**：交易记录/今日经营报告/客户需求/临期退货/商品/备忘/快速记一笔/扫呗导入；其中 5 个 push、3 个 sheet。
4. **主题三正交维度**：显示模式（跟随系统/浅色/深色）× Accent 6 套 × Background 6 套 × 壁纸（可选）；Hero/amber/danger/info 色**不随主题变**；默认 warmCream+emerald。
5. **设置默认值**：店名"天福便利店"、店主"掌柜"、月目标 120000、两类提醒默认开启、语音"普通话"。
6. **备份/恢复**：真实 .json 文件经系统分享面板；恢复单次 save；失败 toast 提示。
7. **P0-2/P1-4 安全语义**：存储失败显式报错不伪装；快照失败保留旧快照；壁纸替换失败保留旧壁纸。
8. **无障碍**：所有可点击行 minHeight 44-54；a11y label 全中文；Reduce Motion 全覆盖（淡入替代位移/弹簧）。
9. **深链接**：xzg://voice、xzg://quickrecord（quick 别名）、xzg://ai、xzg://ai?mode=voice；未知 host 忽略。
