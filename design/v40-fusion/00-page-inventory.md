# V4.0 全功能页面与交互清单（初稿 v1）

> 来源：对本地工作树三个子代理的只读梳理（首页/AI/语音/我的、经营类、待办/日历/备忘/Widget）。
> 状态：**初稿**。以 GitHub `ios/v392-integration @ a6bfced`（V3.9.2 (41)）为最终基线，待基线树 diff 后修订，差异将单列。
> 原则：V4.0 保留全部业务功能与数据逻辑；只改视觉/导航/组件，不删入口、不改业务语义（需求 5）。

## 0. 全局外壳（RootView）
- 原生 TabView 4 Tab：首页 house.fill / 待办 checkmark.circle / 日历 calendar / 经营 chart.bar.fill；每 Tab 一个 NavigationStack。
- AI 不是 Tab：`xzg://ai` 深链 + 首页入口 → AIChatView sheet（.large，隐藏 tabBar）；`xzg://voice` → VoiceView sheet；`xzg://quickrecord` → QuickRecordSheet。
- 我的（Profile）：首页右上角头像 push 进入。
- 组件语言：v371Canvas + SectionHeader + GroupSurface + V371Divider（发丝线）。

## 1. 工作台（首页 HomeView）— Tab
自上而下 5 块：
1. 大日期头（自绘）：64pt 日号 +「10月 星期六」+「经营时间线」灰字；右上天气按钮（→ WeatherDetailSheet medium）、头像（→ push 我的）。
2. Revenue Hero（**全页唯一视觉重点**）：深墨绿卡 `Color(0.11,0.29,0.24)` 圆角 20，「今日营业额」+ 54pt rounded 金额 +「较昨日 ±x.x%」+「月目标 xx%」；点击 → 经营页。
3. 问小掌柜 AI 胶囊：收起 56pt「问小掌柜…」+ chevron.up；展开 170pt 玻璃 +「告诉小掌柜你想查询或记录什么…」+ 发送箭头 → AI sheet。
4. 快捷操作行：两胶囊并排——「快速记一笔」（展开 3 项：记收入/记支出/写备忘，深色面板）与独立「写备忘」；均开 QuickRecordSheet。
5. 今日事项：最多 3 条（HomeInbox limit 3）：图标（urgent 红 / hourglass 橙 / checklist 蓝 / circle 灰）+ 标题 + 副标题 + 时间 + chevron；空态「今天暂无安排」。
- 已否决不复活：「今日最重要」「最近记录」确认已不存在；首页无抽屉（V35DrawerContainer 是死代码，重构删除）。
- 交互状态：AI 胶囊与快捷菜单展开互斥。

## 2. AI 对话（AIChatView）— sheet
- 顶栏「小掌柜」inline；右上 ⋯ 菜单：新对话 / 清空当前对话(destructive) / AI 设置（唯一入口，Profile 里没有）。
- 头部说明「说句话，帮你记账、派单、备忘」+ 徽标：Key 已保存(绿) / 本地模式(灰) / 演示模式(橙)。
- 空态「我是小掌柜」+「说句话或点个例子，我先整理成确认卡，你确认后才记录。」+「试试这样说」4 例：今天美团680 / 明天下两箱可乐 / 记一下供应商周五来 / 今晚8点给302送两箱怡宝。
- 消息流：用户蓝底白字右对齐 max300；助手浅灰底+描边左对齐 max320，Markdown，出错变红+「重试」；处理中 TypingIndicator。
- 确认卡（ActionCard）：头 = 圆图标 + 标题（记录营业额/新建待办/新建备忘/新建配送/查询经营记录）+ 状态说明 + StatusBadge；字段行 label 宽 56；isPreviewOnly 橙条「预览版：点击确认也不会真实保存…」；三键 确认记录/修改/不记录；徽标 待你确认·预览/正在保存…/已保存/已跳过/失败/已取消。
- 业务边界：只有 4 个 CREATE 工具（记录营业额/新建待办/新建备忘/新建配送）参数校验通过且幂等指纹未用时出卡；searchRecords 是 READ 直接本机回答不出卡。
- 输入条：＋菜单(选图/选文件) + 麦克风 + 多行框（占位「问小掌柜…」1–4 行）+ 发送箭头；ultraThinMaterial。
- 语音面板（ShortVoicePanel）：脉动圆 + mic +「正在听…说一件事，例如：今晚8点给302送两箱怡宝」+ 停止/取消；失败态「保存失败，请重试：{原因}」+「已保留：{转写}」。
- 清空弹窗：「清空此对话？」/ 取消 / 清空(destructive) /「只删除聊天记录，不会删除已经保存的营业额、待办、备忘或配送记录。」

## 3. 语音记账（VoiceView）— sheet .large
- 顶栏自绘「语音记账」+ 状态副标题（已记录 绿 / 出错了，点击重试 红）；右上 xmark。
- 状态机 idle→listening→recognized→parsing→preview→saving，旁支 error / textFallback；statusText：点击麦克风开始/正在听…/正在整理…/请确认将保存的内容/正在保存…/手动输入内容。
- 聆听区：15 根波形 + 居中转写；主按钮 停止识别(红)/开始说话(蓝)/重试；textFallback 占位「例如：明天下午三点联系饮料供应商」。
- 预览区：转写大字（空则「（未识别到文字）」）+「解析结果」字段（金额/商品/临期还有N天/客户/数量/备忘/事项/时间）+ 类型 segmented（待办·营业记录·支出·记录·临期退货·客户配送）+「确认保存」+「取消」。
- 确认后写 6 个 Repository：Performance(note「语音记录」)/Expense/Expiry/Memo/Customer/Todo，成功 0.8s 自动 dismiss。

## 4. 经营（PerformanceView）— Tab
- 顶栏「经营数据」inline；右：商品按钮(shippingbox)→商品页；＋记一笔 Menu → 记收入/记支出/扫呗导入/记录/今日经营日报。
- ①Hero 金额区（非卡片，编辑风）：「本月营业额」+ ¥1,234.00 大数字；下排「今日」+ ¥ + 涨跌胶囊「↑12.3% 较昨日」（涨绿跌红，无昨日→「暂无昨日对比」）；36pt 迷你趋势线（近 7 天，无坐标轴）。口径固定：本月+今日+近 7 天，**无日/周/月切换器**。
- ②月目标：营收/目标 ¥X + 完成 % + 蓝色胶囊进度条；本年累计 ¥X。
- ③收入来源：门店/美团/其他 三行（图标+渠道+「占 62%」+金额），仅列金额>0。
- ④近期记录：近 30 天倒序前 12 条；「查看全部」→ push 交易明细。
- 交互：点行=编辑 sheet；行尾删除→「删除这条经营记录？」；空态「暂无收入」「记录第一笔收入开始统计」/「暂无交易记录」+「记一笔」。
- 交易明细（push「全部交易」）：搜索「搜索交易或来源」；List 不分组全量倒序；行=图标/标题/「2026年3月1日 18:30 · 来源」/蓝 +¥、红 -¥；空态「暂无交易」。
- 记一笔 sheet 四态（记/编辑 × 收入/支出）：金额 ¥+34pt（非法禁用保存）→ 明细（备注「备注（选填，如：进了两箱可乐）」+日期）→ 支出分段（进货/房租/水电/人工/其他）或收入来源分段（门店/美团/其他）。
- 今日经营日报（sheet）：Hero 今日营业额 + 对比文案；明细 已完成待办/未完成待办/配送待处理/临期待处理；CTA 复制文本/分享；分享模板【今日经营日报】10月25日／今日营业额：¥X／较昨日增长 12.3%…。

## 5. 待办（TodoView）— Tab
- 顶栏「待办」inline；右上＋（备忘 tab 时标签「新增备忘」）；无排序/刷新/搜索。
- 胶囊分段器 5 段：今天/明天/逾期/已完成/备忘（44 高）。
- 统计行 3 格：待办/已完成/逾期（24pt rounded；逾期>0 才橙色；备忘 tab 隐藏统计保留分段器）。
- 分组：先按 tab 过滤，再按钟点分桶 上午/下午/晚上/待安排；已完成 tab 单组。
- 行：24pt 圆勾（未完成 circle 按优先级红/橙/灰；完成 checkmark.circle.fill 绿）→ 标题 semibold 两行（完成加删除线转灰）→ 元信息（优先级 flag · 时间 · 副标题）→ ellipsis 菜单（编辑/删除 destructive）；行高≥68；无 dueDate 或 00:00 →「待安排」；逾期时间橙色。
- 完成交互：点圆立即写库 + spring 动画，视觉滞留 300ms 移出；失败「操作失败／待办状态未改变，请重试」；删除 confirmationDialog「删除这条待办？」。
- 空态：checkmark.circle +「今天没有待办，去休息一下吧」/「明天暂无待办」/「没有逾期事项，真棒」/「还没有已完成的任务」+「新的安排会清晰地出现在这里」。
- 备忘 tab：双列 LazyVGrid MemoCard（3px 色条蓝/橙/黄、120 图、标题 2 行、内容 3 行、时间+trash）。
- 编辑 sheet：标题（要做什么？/补充说明（可选））→ 时间（Toggle 截止 + DatePicker 默认今天 9:00）→ 优先级 segmented（低/中/高优先级）→ 图片；标题空禁用保存。

## 6. 日历（ScheduleView）— Tab
- 单页纵向五段；顶栏只有「日历」，**无新建按钮**（事件全部来自 Todo/客户/临期/备忘）。
- ①masthead：30pt「10月25日」+「星期六」+ 右侧「今天」胶囊（thinMaterial）。
- ②当日时间：TimedRow = 时间 + 标题 + 副标题（待办 detail 否则优先级；配送=客户名·地址·状态）；尾部待办可勾选，配送 chevron → push 客户页。
- ③全天事项：「N 项」；顺序 待办（高优先级副标）→ 配送 → 临期（hourglass 橙「名称 × 数量」「今天临期/N 天后到期/已临期 N 天」，点击旋转展开备注+140pt 图）→ 记录。皆空时 sun.max「该日期暂无事项 / 这一天还没有安排」。
- ④月历：‹ 2026年10月 › 44pt 圆按钮；星期头 日一二三四五六（周日起始）；7 列方格，今日蓝实心圆白字，选中浅底+蓝描边；格底最多 5 个 4pt 点（绿=收支 蓝=待办 橙=临期 灰=配送 浅灰=记录）；点格换日 fade+触感；大字号自动切纵向日期列表。
- ⑤当日详情：五行「圆点+名称+前 2 条摘要+右侧金额」：营业额/收支（收入 N 笔·支出 N 笔/¥总额）、待办事项、记录、临期提醒、客户需求（时间+地址，无时间「未设配送时间」）；空「当天暂无经营记录」。
- ⑥当日经营：chart.bar.fill 绿「收支概览」收入 ¥x·支出 ¥y 右侧「¥净额/净额」→ push 经营页。
- 与 Todo 同源：勾选即 toggleComplete；定时判定 hasClock（时或分非 0）；当天完成的待办与配送按 completedAt/updatedAt 补进当天；流水只聚合不逐笔。手势仅点按。

## 7. 客户配送（CustomerView）— push
- 「客户配送」；右＋。顶部分段筛选：全部/待处理/配送中/已完成；按状态分组（空组不显示，组头带计数）。
- 行：圆形图标（clock 橙/bicycle 蓝/checkmark 灰）+ 标题（需求内容，空则客户名或「客户配送」）+「10月25日 18:30 · 客户名 · 房号/地址」+ 状态徽标 + 44pt 缩略图 + 推进圆按钮。
- 交互：点按钮或左滑 → 开始配送/完成，toast「✓ 已完成配送」；长按 = 编辑/复制地址/删除。
- 空态「暂无客户需求」+「新增配送」；筛选空「当前筛选暂无结果」；错误「配送状态未改变，请重试。」
- 模型：CustomerRequest 状态 待处理→配送中→已完成 单向。
- 编辑器：购买内容「例：矿泉水2箱、啤酒10瓶、纸巾2包」→ 地址与联系（配送地址/别墅地址，例：清泉八街24号 + 联系电话（选填））→ 配送时间（开关+送达时间）→ 备注「例：到了打电话 / 放门口 / 晚上8点送」→ 图片。保存需内容+地址非空。

## 8. 商品（GoodsView）— push
- 「临时商品」；右＋。搜索「搜索商品 / 条码」→ 四格统计（全部商品/库存不足/7天内临期/总库存）→ 分类分段（全部/饮料/零食/日用品/烟酒/其他）→「商品」列表（带数量）。
- 行：图标+名称(2行)+「库存 3 · 最低 5 · 到期 2026年3月1日」+ 状态徽标（已过期红/即将到期/库存不足橙/正常蓝）+ 售价 ¥ + 删除。
- 库存预警 = 最低库存阈值 + 橙色徽标；临期仅行内徽标，**无独立临期/退货入口**。空态「还没有商品」；删除确认「删除商品“可乐”？」。
- 编辑器：名称「例如：农夫山泉 550ml」→ 分类 → 条码（可选）→ 库存（当前/最低）→ 价格（进货价/销售价）→ 生产日期开关 → 保质期天数（可选）→ 到期日期开关 → 备注 → 图片。

## 9. 临期退货（ExpiryView）— push
- 「临期提醒」；右＋。三格统计 0–3 天(红)/4–7 天(橙)/8–30 天(蓝)。
- 6 组：已过期／紧急·3天内／注意·7天内／安全·30天内／较远·30天外／已退货。
- 行：图标 +「牛奶 ×2」+「到期 2026年1月1日」+ 徽标「还剩 3 天」「已过期 2 天」「已退货」+「退货」按钮（arrow.uturn.left；已退货→「恢复」）+ 删除。
- 退货语义：pending 翻转 returned，不改数量不删除，移出统计进「已退货」组，可恢复。空态「暂无临期商品」；错误「退货状态未改变，请重试。」
- 编辑器：名称「例如：牛奶 250ml」→ 数量 Stepper 1–9999 → 到期日期 → 提前提醒（3/7/15 天）→ 备注「供应商、批次等」→ 图片。

## 10. 备忘/记录（MemoView）— push（标题「记录」）
- 右上 square.and.pencil 新建。搜索「搜索记录…」（有内容出 xmark）→ segmented 全部/文字/图片/语音（语音恒空）→「记录」+ 数量。
- 行：note.text/photo 图标 + 色条（蓝/橙/黄 createdAt%3）+ 标题（空「无标题」）+ 内容 + 时间 + trash（「删除这条备忘？」）。
- 空态「暂无记录，点击右上角新建」。编辑器：标题/内容/图片，任一非空可存；标题 100 字、内容 2000 字截断。

## 11. 报表（今日经营日报）— sheet（见 §4 经营）
另：PerformanceView 近 7 天趋势 + 收入来源占比 = 经营页内嵌报表；无独立报表 Tab。

## 12. 设置（ProfileView「我的」）— push
- 店铺信息：storefront.fill + 店名（缺省「我的小店」）+「{老板} · 你的小掌柜」→「个人资料」sheet。
- 个性化：显示模式（themeModeLabel）→ sheet；外观（主题名）→ AppearanceSettingsView；背景风格 → sheet；壁纸（已设置/未设置）→ sheet；语音输入（语言）→「语音输入设置」sheet。
- 经营：月营业目标 → sheet；提醒设置（已开启/已关闭）→ sheet（待办提醒/临期退货提醒两开关）。
- 工具：收款码 → push PaymentCodeView。
- 演示：Demo Mode 开关（开启时橙提示「当前页面和 AI 使用演示数据，导入不会写入真实数据。」）+ 重置演示数据。
- 数据与应用：数据备份（JSON 文件，系统分享）/ 数据恢复（JSON，fileImporter）/ 清理缓存（「清理缓存？」「仅删除图片加载缓存和临时文件，不会删除商品、待办、客户或营业额数据。」）/ 关于你的小掌柜 / 隐私说明。
- 页脚 v{version}。toast：缓存已清理/演示数据已重置/已恢复 N 条记录/备份失败：…/恢复失败：…。
- 外观 sheet：显示模式三按钮（跟随系统/浅色/深色）+ 选择主题两列 ThemePreviewCard（主题名 + mini Hero「今日营业额 ¥2,680」渐变 + checkmark）。
- 收款码：行=52pt 缩略图+名称+类型（微信/支付宝/自定义二维码）+ ⋯（重命名/替换图片/删除）；脚注「图片仅保存在本设备…」；全屏码 fullScreenCover 纯黑分页。

## 13. 快捷记录（QuickRecordSheet）— sheet
- 「快速记录」/ 取消；仅文本+语音，无相机。打开自动听（静音 3 秒自动结束）。
- 监听态卡：正在听…说一件事 / 正在识别 + 实时转写 + 停止/取消；权限拒绝「麦克风 / 语音识别权限未开启，可直接打字」。
- 输入框「例如：今天美团680」+「本地规则识别，不经过 AI、不需要 API Key；识别不了的内容也会存为备忘。」
- 识别结果卡：类型 Menu（营业额/待办/配送/临时商品/备忘）+ 内容 + 金额 + 时间；「确认保存」52 高蓝；唯一闸门=文本非空；成功「已保存到：X」0.6s 关闭。
- 落库五类：营业额（金额/备注/日期）、待办（标题/截止）、配送（客户/内容）、临时商品（名称/数量/到期）、备忘（标题/content）。

## 14. 天气（WeatherDetailSheet）— medium sheet
- 左关闭，右刷新（ProgressView，未配置或刷新中禁用）。HeroMetric 城市+23°+图标+描述。
- 明细：今日最高/最低、体感、降雨概率 %、状态「离线缓存」、定位「未授权 · 使用默认城市」、数据来源「WeatherAPI.com」。
- 空态四分支：未配置天气服务/网络连接失败，请检查网络后重试/天气服务请求失败，请稍后重试/天气暂不可用 + 重试。状态机 idle/loading/loaded/notConfigured/unavailable(network|api|unknown)。

## 15. 扫呗导入（SaobeiImportSheet）— sheet（经营→记一笔→扫呗导入）
- 选文件（CSV/XLSX，「旧版 XLS 请另存为 XLSX 或 CSV」）或截图识别 → 解析中 → 文件概览（文件/记录 N 笔/有效 N 笔/重复 N 笔/新增 N 笔/新增金额/X 行无法解析）→ 错误行前 20 →「将写入业绩」预览前 5 行 → 确认导入/完成。
- 无字段映射 UI（表头自动识别）；空「没有新的成功交易。重复导入不会让营业额翻倍。」

## 16. Widget（XiaoZhangGuiWidget）
- TodayStatsWidget「小掌柜工作台」+ Live Activity；.thinMaterial 底 .primary/.secondary 文字，Light/Dark/Tinted/Clear 自适应。
- systemSmall 155×155：sparkles+「你的小掌柜」+ 两枚大按钮「问小掌柜」（强调）/「语音记录」+ 底部状态行（逾期/今日待办/配送/临期择优）；无快照「轻点同步今日经营」；全清「今天都安排好了」。
- systemMedium 329×155：左「今日营业额」¥ 28pt；右最多 2 条焦点事项（待办圆圈可完成，逾期橙）；右下两胶囊「问小掌柜」「语音记录」。
- accessoryInline「¥2,680 · 待办2 临期4」；accessoryCircular「今日」+ 短金额（≥1 万「1.2万」）；accessoryRectangular 绿点+「你的小掌柜」/「今日 ¥x · 待办 n」/「下一件事：xxx」。
- 时间线：两 entry（当前+次日 00:00）policy .atEnd；快照写后 refreshAll 主动 reload。
- Live Activity：锁屏卡 + 灵动岛。展开：待办 N 件/今日经营/配送中 N 单+临期 N/「下一件：xxx 时间」或「今天暂无待办」；紧凑：storefront + 临期>配送>待办 一个数字；minimal 仅图标。

## 17. App Intents（XZGAppIntents）
- AddTodoIntent「新增待办」（内容/优先级 0低1中2高/今天 bool）；RecordRevenueIntent「记录营业额」（金额>0/备注默认「Siri 快捷指令」）；AddMemoIntent「记记录」（标题/内容）。openAppWhenRun=false，写库后刷快照。

## 18. 关键枚举速查
- TodoTab：今天/明天/逾期/已完成/备忘；TodoPriority：0 低 1 中 2 高；MemoFilter：全部/文字/图片/语音。
- Todo：title/detail/dueDate?/priority/imageData/isCompleted/createdAt/completedAt/notificationID。
- Memo：title/content/imageData/createdAt/updatedAt。
- MoneyRecord：kind income/expense, title, amount, date, source；IncomeSource：门店/美团/其他。
- CustomerRequest：待处理→配送中→已完成。
- Expiry：pending→returned。
- QuickRecordKind：performance/todo/customer/expiry/memo。
- WeatherSnapshot：temperature/feelsLike/condition/conditionCode/city/precipitationProbability/max/min/observedAt/isStale。

## 19. 已知代码债（重构时可清理，需 Muse 确认）
- `V35SideUtilityDrawer.swift` V35DrawerContainer 全仓无引用（死代码）。
- `HomeView.swift:364` toggleTodo 无调用点（失败 alert 不可达）。
- 「新对话」与「清空当前对话」共用同一弹窗文案；ProfileView「显示模式」行与外观 sheet 内重复。

---

# §20 V3.9.2 权威修订（2026-10-25，只读核对于 xiaozhanggui-v40 @a6bfced）

以下修正前面基于 3.7.1 树的描述，**以本节为准**（子代理 87d6e9fd 逐文件核实）：

## 首页 HomeView.swift（490 行）
- 自上而下：日期头（右上 plus=记一笔，id `v39.home.quickRecord`）→ 本月营业额 Hero → 四 chips（待办/逾期/临期/配送）→ 近7日趋势+收入来源 → **掌柜晨报卡片** → 问小掌柜胶囊 → 今日事项。
- **快捷操作行/四宫格已删除**（用户 2026-10-23 否决，源码 L9-10 注释明令不得恢复）。
- 「今日最重要」「最近记录」全仓 grep **零命中**——被否决区块不存在于当前代码，V4.0 亦不得新增。
- **掌柜晨报 MorningBrief.swift（495 行，PR-I「开店前30秒一站式总览」）**：纯本地规则引擎（MorningBriefBuilder.build()），零云端；输入=今日待办/逾期/临期≤7天/未完成配送/月目标/昨日营收。首页 briefSection「掌柜晨报」卡片（L317-335），轻点弹 MorningBriefSheet(.large)。Sheet 结构：headlineCard（早上好/下午好/晚上好，掌柜 + 昨日营业额 ¥X，较前日涨/跌 N%）→ 今日重点 → 今日概览 → 月目标（本月 N% · ¥A/¥B）→ 掌柜建议。建议优先级：逾期 > 临期 > 配送 > 目标落后 > 达成 > 默认；例句：「有 N 件事已逾期，今天先把它们清掉，心里才踏实。」「还有 N 单配送在路上，别忘了跟进。」未读点按 xzg.morningBrief.readOn(日期key) 跨天重置；可选每日 8:00 通知「掌柜晨报已就绪」。V39HomeSections.swift（386 行）=纯视图组件。

## 经营页 PerformanceView.swift（612 行）
- 顺序：Hero → 收入趋势 → 收入来源 → 月目标 → 近期记录（L77-95）。
- **趋势段新增日/周/月切换**（V38ChipSelector，PerformanceChartPeriod，L295-328），替代旧固定「本月+今日+近7天」；Hero 仍固定本月。
- V38TrendBarChart（236 行）：Swift Charts BarMark、Y 轴隐藏、nice ceiling、月档轴标签抽稀 7 个、点柱读数「M/d · ¥X」/「点按柱形，查看单日金额」、选中柱实色其余 30% 透明、空态「本期暂无收入数据」。
- **月度报表 MonthlyReport.swift（303 行）**：入口=经营页「更多」菜单第一项（id `v39.performance.monthlyReport`）→ MonthlyReportSheet。卡片「掌柜的月报」+月份+「↑/↓N% 较上月同期」徽标（口径固定「较上月同期」，P0-1 严禁「较上月」）+本月营业额+支出+近7日柱图+收入来源三色条+「待办完成 N%（全部历史待办）」；金底按钮「分享月报图片」（ImageRenderer 390pt）。

## 日历页 ScheduleView.swift（实为 1011 行）
- 六段保留但「当日详情」并入月历段：masthead → 当日时间 → 全天事项 → 月历（月份导航+月/周密度 chips+周头+网格+divider+**当日详情**）→ 当日经营（收支概览：收入 ¥X · 支出 ¥Y / ¥净额 单行）。
- V38ScheduleLayout（119 行）：月/周密度纯函数网格，gridDates 周日起始 nil 补位（与 3.7.1 同算法）、ghost 行锚定选中格（切换位移≤1pt）、settled 后二次沉降消第 5 周约 190pt 空白。
- PR-K 视觉：今日格=香槟金实心圆+深墨字、选中=金环 matchedGeometryEffect 滑移；density chips 金底深墨字（id `v38.schedule.density.month/week`）。

## 待办页
- 分段器仍 今天/明天/逾期/已完成/备忘（TodoModel.swift L5-13）。
- 结构：分段器 → **Editorial 进度头**（今日待办/已完成/逾期 32pt 数字 + 4pt 进度条，仅非备忘 tab）→ 上午/下午/晚上/待安排分组。
- 空态分 tab：「今天没有待办，去休息一下吧」「没有逾期事项，真棒」。
- **V38TodoToggleFlow（67 行）两段式勾选**：点按→保存中转圈（不先显完成）→写库成功才绿对勾+删除线+0.55 透明+停留 0.7s 移出；失败=红点角标+抖动+行内「保存失败，可重试」+「重试/放弃」+alert「待办状态未改变，请重试。」。
- **TodoNavigationState（21 行）**：@Observable 单例，RootView 持有注入首页与待办页；首页 chips 写 requestedTab，待办页 onAppear/onChange 消费一次——首页点「逾期」直达待办逾期筛选。

## 我的 ProfileView.swift（1406 行，diff 9d151b9..a6bfced）
- 新增「每周备份提醒」（L317，bell.badge，周一 10:00，已开启/已关闭）、「每日晨报提醒」（L323，sun.horizon，每天 8:00）。
- 数据备份行尾=BackupReminder.statusText()（超 7 天提示）；数据恢复行尾改「先预览」+alert「恢复这份备份？」（预计新增 N 条，已存在跳过 N 条；恢复为追加合并，不会删除现有数据）。
- 通知被拒新增「通知未开启」alert+「去设置」；分享完成回调才 markBackedUp。
- **AI 设置入口未加入 Profile**（全文 grep 无；只有语音输入设置 L1160/提醒设置）。

## 记一笔 MoneyEditorSheet.swift（241 行）
- 原生 Form，Mode 三态（new 收入/支出、editPerformance/editExpense）。
- V3.9.2 新增：收入「收入来源」分段（门店/美团/其他）、支出「分类」分段（进货/房租/水电/人工/其他）；金额 34pt decimalPad+键盘栏「完成」；无效金额行内红字「请输入大于 0 的有效金额」；新建自动聚焦；脏离开 alert「放弃未保存的修改？」。

## Widget 与 Intents（V3.9.2 无改动）
- TodayStatsWidget（217 行）：systemSmall/systemMedium + accessoryInline/Circular/Rectangular；显示名「小掌柜工作台」、描述「一键问小掌柜、语音记录；今日营业额与现在最该做的两件事」。Small=问小掌柜+语音记录两意图深链+状态行；Medium=左今日营业额+右最多 2 条焦点事项（待办可勾选 CompleteTodoIntent，配送/临期仅展示）+右下两胶囊。
- XZGAppIntents（156 行）3 个：新增待办（内容/优先级/今天）、记录营业额（金额/备注）、记记录（标题/内容）；无晨报 Shortcut。

## 目录事实
- CalendarModel.swift 在 Features/Calendar/（非 Schedule/）；Todo V38 文件在 Todo/V38/。
