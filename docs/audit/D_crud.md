# D 部分：业务 CRUD 模块审计（iOS V3.6，HEAD 335981b）

> 审计范围：`XiaoZhangGui/Features/{Todo,Customer,Memo,Expiry,Goods,Performance,Calendar,Schedule,DailyReport}`
> 分支 `feature/v3.6-ui-ai-expansion`。只读审计，未改动任何代码。
> 约定：行号引用格式 `路径:行号`，路径相对 `XiaoZhangGui/Features/`（另注除外）。

---

## D1. Todo（待办）

**文件**：`Todo/TodoView.swift`（424 行）、`Todo/TodoModel.swift`（80 行）、`Todo/TodoEditorSheet.swift`（184 行）；模型 `Models/Todo.swift`（86 行）；Repository 见 `Repositories/AppRepository.swift:13-51`（`TodoRepository`）。

### ① 页面 UI 结构树（TodoView.swift）

```
TodoView（ScrollView）
├─ tabPicker：V32SegmentedPicker（5 tab）
├─ statsCard（tab ≠ 备忘 时显示）：3 统计格
│ ├─ 待办（todayCount，icon sun.max，品牌色）
│ ├─ 已完成（doneCount，icon checkmark.circle）
│ └─ 逾期（overdueCount，icon exclamationmark.circle，>0 时 amber）
├─ content（tab ==.records → recordsContent，否则分组列表）
│ └─ ForEach(groups)：分组标题（上午/下午/晚上/待安排）
│ └─ TodoListRow
│ ├─ V32Checkbox（点击切换完成）
│ ├─ Button→onEdit：标题（2 行，完成后灰色+删除线）+ 副标题
│ ├─ 右侧 timeText（DayTimeLabel：无日期显示"待安排"）
│ └─ 删除按钮（trash，icon only）
└─ recordsContent（"备忘" tab）：Memo 两列 LazyVGrid（MemoCard），按 updatedAt 倒序
工具栏：右上 + 按钮（备忘 tab 时 a11y "新增备忘"，否则 "新增待办"）
导航标题："待办"，inline。
```

- toolbar `+` 行为（`TodoView.swift:72-80`）：records tab → 打开 `MemoEditorSheet`；否则打开 `TodoEditorSheet`。注意 `RecordEditorSheet`（`TodoView.swift:355-408`，私有，T11 备注）**已无调用方**（`showNewRecord` 声明后未被置 true）——残留死代码。
- `editingMemo` 状态（`TodoView.swift:281`）在 records tab 打开 `MemoEditorSheet`；`deleteMemo` 删除备忘（`TodoView.swift:283-286`）。

### ② TodoEditorSheet 全部表单字段（TodoEditorSheet.swift）

| 卡片 | 字段 | 控件 | 校验/约束 |
|---|---|---|---|
| 标题 | 标题（必填，placeholder "要做什么？"） | TextField | 保存要求 trim 后非空（`TodoEditorSheet.swift:17-19`） |
| 标题 | 补充说明（可选） | TextField axis vertical，lineLimit 3...6 | 无 |
| 时间 | "设置截止时间" 开关 + DatePicker（日期+时分） | Toggle + DatePicker | 关闭开关 → dueDate=nil；新增时默认今日 9:00（`TodoEditorSheet.swift:144-146`） |
| 优先级 | 低优先级/中优先级/高优先级 | V32SegmentedPicker（复用 TodoView 内声明，`TodoView.swift:306-341`） | 默认 low |
| 图片 | 图片 | PhotoPickerField | 可选 |

- 保存按钮：标题不为空才可点（disabled + opacity 0.5）。
- 失败弹窗：「保存失败」/"内容未保存，请重试。"，按钮"重试"/"取消"（`TodoEditorSheet.swift:49-52`）。
- 新增/编辑：同一 Sheet，`todo == nil` 为新增；编辑回填（`TodoEditorSheet.swift:141-154`）。

### ③ 列表排序/分组/筛选（TodoModel.swift）

- Tab 定义（`TodoModel.swift:7-14`）：今天 / 明天 / 逾期 / 已完成 / 备忘。
- 过滤规则（`TodoModel.swift:18-45`，`TodoFilter.todos`）：
- 今天：未完成 且（dueDate 为 nil 或落在今天起止内）；按 dueDate 升序（nil 视为 `.distantFuture` 排最后）。
- 明天：未完成 且 dueDate 落在明天起止内；按 dueDate 升序。
- 逾期：未完成 且 dueDate!= nil 且早于今天 0 点；按 dueDate 升序。
- 已完成：isCompleted；按 `(completedAt?? createdAt)` 倒序。
- 备忘：返回空（内容独立渲染 Memo）。
- 时间轴分组（`TodoModel.swift:49-73`，`TodoFilter.grouped`）：按 `due.dayPeriod` 分 上午/下午/晚上/待安排（无日期）；非空组才显示。
- 备忘（records tab）排序：`updatedAt` 倒序（`TodoView.swift:254`）。

### ④ 状态机与交互

- 完成/取消完成：`V32Checkbox` 点击 → `toggle(_:)`（`TodoView.swift:289-307`）。**立即写库**（`TodoRepository.toggleComplete` 设置 `completedAt=Date()`，未完成则 nil，`AppRepository.swift:33-43`）；视觉上行在 `finishingIDs` 中暂留约 0.3s 做 fade/收缩后移出（`TodoView.swift:22-24, 302-306`）；防重复点击（`togglingIDs`，同一项动画窗口内忽略）。完成→Haptic.success，未完成→Haptic.light。
- **无滑动删除/滑动操作**：只有显式 trash 按钮 → `confirmationDialog`「删除这条待办？」→ destructive 确认（`TodoView.swift:92-103`）；删除失败 alert「删除失败」/"待办未删除，请重试。"。
- 编辑：点行 → `TodoEditorSheet`（`TodoListRow` 的 Button，`TodoView.swift:355-370`）。
- **无长按**交互。
- 优先级语义（`Models/Todo.swift:46-62`）：`TodoPriority` low=0/medium=1/high=2，label "低优先级"/"中优先级"/"高优先级"。行副标题规则（`TodoView.swift:381-385`）：detail 非空显示 detail，否则显示 `priorityLevel.label`。**高优先级且未完成时副标题 amber 色**（`TodoView.swift:370`）。
- 过期行：`isOverdueTab` 时时间文字 amber（`TodoView.swift:374`）。

### ⑤ 空状态/错误状态文案

- `TodoFilter.emptyText`（`TodoModel.swift:75-83`）：今天 "今天没有待办，去休息一下吧"；明天 "明天暂无待办"；逾期 "没有逾期事项，真棒"；已完成 "还没有已完成的任务"；备忘 "暂无备忘"。备忘空（`MemoView`）另见 D3。
- 错误文案：`deleteError` "待办未删除，请重试。"，`stateActionError` "待办状态未改变，请重试。"（`TodoView.swift:103-110`）。

### ⑥ iOS-only API

- `PhotosPickerItem` / `PhotosUI`（`TodoView.swift:3, 365`）：`PhotoPickerField` 内部用 PhotosPicker 选图（定义位置：`XiaoZhangGui/Components/PhotoPickerField.swift`，审计组 C 范围）。
- `withAnimation`/`Haptic`（自封装，UINotificationFeedbackGenerator / UIImpactFeedbackGenerator）——Android 用 Vibrator/系统震动等价。

### ⑦ Tests 覆盖

- `Tests/DisplayLogicTests.swift:testTodoGroupsByPeriod`（上午/下午/晚上/待安排分组）。
- `Tests/DayTimeLabelTests.swift`（行时间文案规则：00:00→全天、nil→"待安排"）。
- `Tests/CompletedItemsTests.swift`（完成计数口径：`testTodoCompletedTodayButDueTomorrowCountedTodayAndTrackableInSchedule` 等 7 个）。
- `Tests/ScheduleAgendaTests.swift`（dueDate 形态分类）。
- 无 UI 测试覆盖 TodoView 页面（UITests 目录无 TodoView 用例）。

---

## D2. Customer（客户配送）

**文件**：`Customer/CustomerView.swift`（392 行）、`Customer/CustomerEditorSheet.swift`（226 行）；模型 `Models/ExpiryItem.swift:78-114`（`CustomerRequest`）+ `:117-140`（`CustomerStatus`）；Repository `AppRepository.swift:243-295`（`CustomerRepository`）。

### ① 页面 UI 结构树（CustomerView.swift）

```
CustomerView（ScrollView）
├─ V32SegmentedPicker：全部 / 待处理 / 配送中 / 已完成（CustomerFilter:372-387）
├─ 空：全部为空 → icon shippingbox「暂无客户需求」/「可以先新增一条配送需求」+「新增配送」按钮
│ 筛选无结果 → icon line.3.horizontal.decrease.circle「当前筛选暂无结果」/「可以切换筛选查看其他需求」
└─ V32SwipeRow 包裹 CustomerRow（每个行）
├─ V32IconBubble（状态图标：pending clock/amber；delivering bicycle/brand；done checkmark/neutral）
├─ Button→onEdit：displayTitle（2行）+ displaySubtitle（1行）
├─ imageData 时显示 ImageThumb 44 缩略图（CustomerView.swift:219-221）
├─ V32StatusPill（状态文本：待处理/配送中/已完成）
└─ 状态 ≠ done 时行内推进按钮（bicycle 或 checkmark 圆按钮）
└─ contextMenu（长按）：编辑 / 复制地址（有地址才显示）/ 删除（destructive）
工具栏：右上 + → CustomerEditorSheet（CustomerView.swift:113-119）
完成 toast：底部胶囊「✓ 已完成配送」，2s 自动消失（CustomerView.swift:121-132, 158-164）
导航标题："客户配送"，inline。
```

### ② CustomerEditorSheet 全部表单字段（CustomerEditorSheet.swift）

| 卡片 | 字段 | 控件 | 校验/约束 |
|---|---|---|---|
| 购买内容 | 内容（必填，例 "矿泉水2箱、啤酒10瓶、纸巾2包"） | TextField vertical，3...6 行 | 必填（trim 非空） |
| 地址与联系 | 配送地址（必填，例 "清泉八街24号"） | TextField | 必填（trim 非空） |
| 地址与联系 | 联系电话（选填） | TextField，keyboardType.phonePad | 选填，保存时 trim |
| 配送时间 | "设置配送时间" 开关 + DatePicker | Toggle + DatePicker（默认日期+时间） | 关闭 → 不存 deliveryTime |
| 备注 | 备注（例 "到了打电话 / 放门口 / 晚上8点送"） | TextField vertical，2...5 行 | 选填，保存 trim |
| 图片 | 图片 | PhotoPickerField | 选填 |

- 保存条件（`CustomerEditorSheet.swift:21-25`）：**内容和地址同时非空**（双必填）。
- 保存失败 alert：「保存失败」/"配送需求未保存，请重试。"（`CustomerEditorSheet.swift:51-54`）。
- 编辑回填：地址/电话/内容直接读字段；配送时间/备注从 `CustomerDeliveryStorage.decode(request.customer)` 解出（`CustomerEditorSheet.swift:163-176`）。**`customer` 字段是封装串**：前缀 `xzg-delivery-v1:` + JSON（deliveryTime/note/legacyCustomer）base64（`CustomerEditorSheet.swift:203-226`）；旧数据（无前缀）→ legacyCustomer 兜底（`CustomerView.swift:330-334`）。

### ③ 列表排序/分组/筛选

- 筛选：按 `CustomerFilter`（全部/待处理/配送中/已完成），状态过滤后按 `createdAt` 倒序（`CustomerView.swift:20-24`）。**无额外分组**。
- 注意 `CustomerFilter`（CustomerView.swift 定义，rawValue 即中文）与 `CustomerStatus`（模型层）各自独立，用 `filter.status` 映射。

### ④ 状态机与交互

- 状态机：`待处理 → 配送中 → 已完成`（`CustomerStatus.next`，`Models/ExpiryItem.swift:133-138`）；done 到达终点（next 返回自身）。
- 推进方式（3 处等价）：
1. **右滑**：`V32SwipeRow` 自绘 swipe（`CustomerView.swift:307-392`）——pending 右滑露出「开始配送」（bicycle 图标），delivering 右滑露出「完成」（checkmark）；**done actions 为空，不允许 swipe 且不拦截滚动**（`CustomerView.swift:358-371`）。仅允许左滑方向（代码里是 offset 向负方向，实际是露出右侧按钮），DragGesture 最小距离 14，中点吸附（`CustomerView.swift:369-384`）。
2. 行内主操作按钮（状态 ≠ done，`CustomerView.swift:229-236`）。
3. 无其他入口。
- `advance()`（`CustomerView.swift:153-166`）：`CustomerRepository.advanceStatus` 写库（`statusEnum.next`，`AppRepository.swift:271-287`）；推进到完成 → toast「✓ 已完成配送」+ Haptic.success；pending→delivering 离开 pending 时**取消跟进通知**（`NotificationManager.cancelCustomer`），delivering 不重排、done 不安排通知（`AppRepository.swift:277-285`）。
- 复制地址：`copyAddress`（`CustomerView.swift:168-173`）——`UIPasteboard.general.string = address`（仅在有地址时，行 contextMenu 也调用）。
- 删除：contextMenu 「删除」→ confirmationDialog「删除这条客户需求？」→ destructive 确认（`CustomerView.swift:133-148`）。
- **编辑入口**：点行 title 区 → `CustomerEditorSheet`（`CustomerView.swift:212-224`）。
- **电话拨打**：⚠️ **本模块未实现**——`phone` 字段只收集，不显示、不拨打；全文 grep `tel:`/`openURL` 在 Customer/Todo/Expiry 均为 0 命中。**这是 parity 注意点**：iOS V3.6 无电话拨打功能。

### ⑤ 空状态/错误状态文案

- 空列表：icon `shippingbox`，「暂无客户需求」/"可以先新增一条配送需求" + 「新增配送」按钮；筛选无结果：icon `line.3.horizontal.decrease.circle`，「当前筛选暂无结果」/"可以切换筛选查看其他需求"（`CustomerView.swift:37-52`）。
- 删除失败：「删除失败」/"客户需求未删除，请重试。"（`CustomerView.swift:149-151`）。

### ⑥ iOS-only API

- `UIPasteboard.general.string`（复制地址，`CustomerView.swift:170`）→ Android 用 ClipboardManager。
- `contextMenu`（长按菜单，`CustomerView.swift:242-248`）→ Android 无直接等价，按 Material 风格用长按弹窗或更多按钮。
- `confirmationDialog`/`alert` → BottomSheetDialog / AlertDialog。

### ⑦ Tests 覆盖

- `Tests/DisplayLogicTests.swift:testDisplayTextHidesDeliveryPayload`（displayText 隐藏 `xzg-delivery-v1:` 封装串）。
- `Tests/CompletedItemsTests.swift:testCompletedDeliveriesAttributedByUpdatedAt` / `testCompletedDeliveriesForDayDeduplicatesAndBackfills` / `testHomeCountMatchesScheduleTrackableItems`（done 口径与日程一致性）。
- `Tests/ScheduleAgendaTests.swift:testDoneDeliveryRetainedInTimedEvents` / `testDoneDeliveryRetainedInAllDay`。
- 无 swipe 交互 UI 测试。

---

## D3. Memo（备忘/记录）

**文件**：`Memo/MemoView.swift`（183 行）、`Memo/MemoModel.swift`（41 行）、`Memo/MemoEditorSheet.swift`（123 行）；模型 `Models/Memo.swift`（19 行）：`final class Memo` 字段 `title/content/imageData(@Attribute(.externalStorage))/createdAt/updatedAt`（`Models/Memo.swift:6-17`）。

### ① 页面 UI 结构树（MemoView.swift）

```
MemoView（ScrollView）导航标题："记录"（注意导航标题叫「记录」）
├─ V32SearchField（placeholder "搜索记录…"）
├─ V32PillBar：全部 / 文字 / 图片 / 语音（MemoFilter）
├─ MemoCard 列表（垂直 list，图片时显示 120 高大图）
│ └─ MemoCard：图片（可选）→ 左色条（3px）+ 标题（空则"无标题"）→ 内容（3行）→ 时间 + trash 按钮
└─ 工具栏右上 square.and.pencil → MemoEditorSheet
```

- **mock 预览分支**：`RuntimeMode.allowsMockData` 为 true 时显示 4 张写死卡片（`MemoView.swift:44-49`）；Android 无 mock 需求时应走真实分支。另注意 TodoView 的 "备忘" tab 用两列 grid 渲染同 MemoCard（`TodoView.swift:252-258`）。
- MemoCard 在 `MemoView.swift:107-181`（public struct，被 TodoView 复用）。
- 空标题显示 "无标题"（`MemoView.swift:138`）。

### ② MemoEditorSheet 全部表单字段（MemoEditorSheet.swift）

| 卡片 | 字段 | 控件 | 校验/约束 |
|---|---|---|---|
| 标题 | 记录标题 | TextField | 选填 |
| 内容 | 内容（"记点什么…"） | TextField vertical，4...8 行 | 选填 |
| 图片 | 图片 | PhotoPickerField | 选填 |

- 保存条件：**标题或内容任一非空**（`MemoEditorSheet.swift:18-21`）。
- **长度上限**：标题 ≤100 字符、内容 ≤2000 字符（保存时 `prefix` 截断，`MemoEditorSheet.swift:113-114`）。**不弹窗提示，静默截断**。
- 编辑更新 `updatedAt = Date()`（`AppRepository.swift:62-66`）。保存失败：/alert「保存失败」/"备忘未保存，请重试。"。

### ③ 排序/分组/筛选（MemoModel.swift）

- `MemoSearch.filtered`（`MemoModel.swift:11-30`）：搜索（title/content 大小写不敏感匹配）+ 过滤：全部 / 文字（无图）/ 图片（有图）/ **语音恒为空**（`memo.imageData == nil` 等价，voice → false）。结果按 `updatedAt` 倒序。**无分组**。
- TodoView 的备忘 tab 同样按 `updatedAt` 倒序。

### ④ 状态机与交互

- 无状态机（无完成/推进概念）。
- 编辑：点卡片 → `MemoEditorSheet`；删除：卡片右下 trash 按钮（plain 按钮）→ confirmationDialog「删除这条备忘？」→ destructive 确认（`MemoView.swift:72-83`）。
- 左侧色条：`accentIndex(for:)` = `Int(createdAt.timeIntervalSince1970.magnitude) % 3`，映射 绿(brand)/橙(amber)/蓝(info)（`MemoModel.swift:34-37`，`MemoView.swift:112-118`）——**创建时间决定的稳定颜色**，Android 需复刻同一算法。

### ⑤ 空状态/错误状态文案

- `MemoSearch.emptyText = "暂无记录，点击右下角添加"`（`MemoModel.swift:32`）——⚠️ 注意文案说"右下角"，但实际新增按钮在**顶部 toolbar**（历史遗留文案，parity 时照搬或标注差异）。

### ⑥ iOS-only API

- PhotosPicker（图片字段），与 Todo 相同。
- 无其他特殊 API。

### ⑦ Tests 覆盖

- 模型/搜索层无专用测试文件；DisplayLogic 等未覆盖 MemoSearch。⚠️ **MemoSearch/MemoFilter 无测试**。

---

## D4. Expiry（临期退货）

**文件**：`Expiry/ExpiryView.swift`（197 行）、`Expiry/ExpiryModel.swift`（98 行）、`Expiry/ExpiryEditorSheet.swift`（194 行）；模型 `Models/ExpiryItem.swift:7-75`（`ExpiryItem`）+ `:58-75`（`ReturnStatus`/`daysLeft`）；Repository `AppRepository.swift:187-233`（`ExpiryRepository`）。

### ① 页面 UI 结构树（ExpiryView.swift）

```
ExpiryView（ScrollView）导航标题："临期提醒"
├─ statCard（三格）：3天内到期(danger) / 7天内到期(amber) / 30天内到期(brand)
├─ 空 → icon shippingbox「暂无临期商品」/「可以新增一条临期记录」+「新增临期商品」按钮
└─ ForEach(stats.groups)：分组标题（已过期 / 紧急·3天内 / 注意·7天内 / 安全·30天内 / 较远·30天外 / 已退货）
└─ V32FieldGroup 包裹 ExpiryRow 列表
└─ ExpiryRow：V32IconBubble(clock.badge.exclamationmark) + 「名称 ×数量」+「到期 M月d日」
+ V32StatusPill（还剩 X 天 / 已过期 X 天 / 已退货）
+ 退货/恢复按钮（arrow.uturn.left）+ 删除按钮（trash）
工具栏右上 + → ExpiryEditorSheet
```

### ② ExpiryEditorSheet 全部表单字段（ExpiryEditorSheet.swift）

| 卡片 | 字段 | 控件 | 校验/约束 |
|---|---|---|---|
| 商品名称 | 名称（必填，例 "牛奶 250ml"） | TextField | 必填；保存时截断 ≤100 |
| 数量 | 数量 | Stepper 1...9999 + TextField（numberPad，数字过滤） | **必须 > 0**（`Int(quantityText.filter(\.isNumber))?? 0 > 0`，`ExpiryEditorSheet.swift:18-24`） |
| 到期日期 | 到期日 | DatePicker graphical（范围 `Date()...`，即**不允许选过去日期**，`ExpiryEditorSheet.swift:117-124`） | 必填（默认今天） |
| 提前提醒 | 提前提醒 | V32SegmentedPicker：3天 / 7天 / 15天，默认 7（`ExpiryEditorSheet.swift:26`） | 三选一 |
| 备注 | 备注（供应商、批次等） | TextField | 选填，保存截断 ≤200 |
| 图片 | 图片 | PhotoPickerField | 选填 |

- 保存条件：名称非空 且 数量>0；失败 alert「保存失败」/"临期记录未保存，请重试。"。
- 注意：编辑器**没有 productionDate 字段**（模型有 `productionDate` 字段但编辑器不提供；`ExpiryEditorSheet.swift` 无 productionCard）。

### ③ 临期判定规则（ExpiryModel.swift + Models/ExpiryItem.swift:68-75）

- `daysLeft(from:)`：从「参考日 0 点」到「到期日 0 点」的日历天数差，负数=已过期。
- 分组（`ExpiryStats.init`，`ExpiryModel.swift:38-72`）：仅待处理项按 expiryDate 升序，桶：
- 已过期：daysLeft < 0
- 紧急·3天内：0...3
- 注意·7天内：4...7
- 安全·30天内：8...30
- 较远·30天外：> 30
- 已退货：status==returned，按 `(returnedAt?? expiryDate)` 倒序
- 三格统计：urgentCount(0...3) / warningCount(4...7) / safeCount(8...30)，**仅待处理**（`ExpiryModel.swift:65-67`）。
- `remindDaysBefore`（3/7/15）：**仅用于通知调度**（`NotificationManager.scheduleExpiry`），不参与分组判定；**分组硬编码 3/7/30 阈值**（`ExpiryModel.swift:47-57`）。⚠️ parity 注意：用户选的提前提醒天数 ≠ 列表分组阈值。
- badge 文案 `ExpiryBadge.text`（`ExpiryModel.swift:77-83`）：已退货→"已退货"；days>=0→"还剩 N 天"；<0→"已过期 N 天"。

### ④ 状态机与交互

- 状态：`ReturnStatus.pending="待处理"` / `.returned="已退货"`（`Models/ExpiryItem.swift:58-61`）。`status` setter：设为 returned → `returnedAt=Date()`；恢复 pending → `returnedAt=nil`（`Models/ExpiryItem.swift:63-67`）。
- 退货标记：行内「退货」按钮（amber，icon arrow.uturn.left）→ `toggleReturn` → `ExpiryRepository.toggleReturn` 翻转；已退货时按钮变为「恢复」(arrow.counterclockwise)。退货 → Haptic.success，取消 → 通知调度（`AppRepository.swift:223-233`）。**无滑动交互**，无 confirmationDialog（直接切换）。
- 删除：trash → confirmationDialog「删除这条临期记录？」→ destructive 确认（`ExpiryView.swift:107-116`）。
- 编辑：点行标题区 → `ExpiryEditorSheet`。

### ⑤ 空状态/错误状态文案

- 空：icon `shippingbox`，「暂无临期商品」/"可以新增一条临期记录" + 「新增临期商品」按钮（`ExpiryView.swift:34-42`）。
- 删除失败：「删除失败」/"临期记录未删除，请重试。"。

### ⑥ iOS-only API

- `DatePicker` graphical style（`ExpiryEditorSheet.swift:121`）→ Android 用 DatePickerDialog/MaterialDatePicker。
- PhotosPicker（图片字段）。
- 通知：`NotificationManager.scheduleExpiry/cancelExpiry`（`AppRepository.swift:212,218-219,227-230`）→ Android Notification/WorkManager 等价（属 A 组/通知组范围，此处仅记录接线点）。

### ⑦ Tests 覆盖

- ⚠️ **无 Expiry 专用测试**（Tests 下无 ExpiryStats/ExpiryGroup/ExpiryBadge/ExpiryRepository 测试）。分组阈值是回归风险点。

---

## D5. Goods（商品/临时商品）

**文件**：`Goods/GoodsView.swift`（223 行）、`Goods/GoodsModel.swift`（76 行）、`Goods/GoodsEditorSheet.swift`（300 行）；模型 `Models/Goods.swift`（58 行，字段见②表）；Repository `AppRepository.swift:297-317`（`GoodsRepository`，纯 CRUD，无通知）。

### ① 页面 UI 结构树（GoodsView.swift）

```
GoodsView（ScrollView）导航标题："临时商品"（⚠️ 标题叫"临时商品"，不是"商品"）
├─ V32SearchField（placeholder "搜索商品 / 条码"）
├─ statCard：全部商品(brand) / 库存不足(amber) / 临期(amber) / 总库存(灰)
├─ V32PillBar：全部 / 饮料 / 零食 / 日用品 / 烟酒 / 其他（GoodsCategory.filters）
├─ GoodsCard（逐个纵排，非 lazy）
│ ├─ 缩略图（52，有图则 ImageThumb，否则 shippingbox 图标按状态色）
│ ├─ 名称 + V32StatusPill（状态：已过期/即将到期/库存不足/正常）
│ ├─ 条码（"码 XXX"，可选）
│ ├─ "库存 n · 最低 m"
│ ├─ 分隔线
│ ├─ "进价 ¥a · 售价 ¥b · 毛利 ¥c"
│ ├─ 到期日（可选，按状态色）
│ └─ 右下：编辑（pencil，品牌色圆按钮）/ 删除（trash，灰圆按钮）；整卡可点→编辑
└─ 工具栏右上 + → GoodsEditorSheet
```

- **mock 预览分支**：`RuntimeMode.allowsMockData` 时 5 张写死行（`GoodsView.swift:37-41`）。
- 删除：无确认框，直接 `Haptic.warning()` + `try? GoodsRepository.delete`（**静默失败**，`GoodsView.swift:99-102`）——⚠️ 与其他模块确认框风格不一致。

### ② GoodsEditorSheet 全部表单字段（GoodsEditorSheet.swift，10 个卡片）

| 卡片 | 字段 | 控件 | 校验/约束 |
|---|---|---|---|
| 商品名称 | 名称（必填，例 "农夫山泉 550ml"） | TextField | 保存要求非空（`GoodsEditorSheet.swift:24-26`） |
| 分类 | 分类 | V32SegmentedPicker：饮料/零食/日用品/烟酒/其他，默认"其他" | 必填单选 |
| 条码 | 条码（"扫码或输入（可选）"） | TextField，keyboardType numbersAndPunctuation | 选填，trim |
| 库存 | 当前库存 / 最低库存 | 双 numberField（numberPad，数字过滤） | 选填，解析失败→0 |
| 价格 | 进货价 / 销售价 | 双 numberField（decimalPad） | 选填，解析失败→0（`Double(purchaseText)?? 0`，注意**不做千分位/小数点以外的清洗**） |
| 生产日期 | 开关 + DatePicker（日期） | Toggle + DatePicker | 关闭→nil |
| 保质期 | 保质期天数（如 365） | TextField numberPad | 选填，数字过滤，失败→0 |
| 到期日期 | 开关 + DatePicker（日期，范围 `Date()...`） | Toggle + DatePicker | 关闭→nil |
| 备注 | 备注（可选） | TextField vertical 2...4 行 | 选填 trim |
| 商品图片 | 图片 | PhotoPickerField | 选填 |

- **无保存失败 alert**（catch 里只有 `Haptic.error()`，`GoodsEditorSheet.swift:284-286`）——失败时静默（Sheet 不关）。
- 模型字段（`Models/Goods.swift:7-21`）：name, category（默认"其他"）, barcode, stock, minStock, purchasePrice(Double), salePrice(Double), productionDate?, shelfLifeDays, expiryDate?, note, imageData(@Attribute(.externalStorage)), createdAt, updatedAt。

### ③ 排序/分组/筛选（GoodsModel.swift）

- `GoodsFilter.filtered`（`GoodsModel.swift:33-49`）：分类过滤（"全部"；"其他" = 分类为"其他"**或不在已知分类**）；搜索（名称大小写不敏感 或 条码包含，条码不大小写不敏感）；按 `createdAt` 倒序。**无分组**。
- 统计（`GoodsModel.swift:9-23`）：库存不足 = `stock <= minStock`（`isLowStock`，`Models/Goods.swift:57`）；临期 = 有 expiryDate 且落在 now...now+7d（注意含已过期边界：`expiryDate >= now`，已过期不计）；总库存 = max(stock,0) 求和。
- 状态判定 `GoodsState.of`（`GoodsModel.swift:66-75`）：优先级 **已过期（expiry < now）> 即将到期（expiry ≤ now+7d）> 库存不足（stock ≤ minStock）> 正常**。

### ④ 状态机与交互

- 无状态推进交互（库存/价格都是编辑器改）。
- 行交互：整卡 onTap → 编辑（`GoodsView.swift:218`）；行内 pencil 按钮 → 编辑；trash 按钮 → 直接删除（无确认，`GoodsView.swift:99-102`）。**无滑动删除、无长按**。

### ⑤ 空状态/错误状态文案

- 空：icon `shippingbox`，「还没有商品」，message nil（`GoodsView.swift:44-48`）。**空状态无新增按钮**（与其他模块不一致）。

### ⑥ iOS-only API

- PhotosPicker（图片）；decimalPad/numberPad（Android 用 inputType numberDecimal/number）；graphical DatePicker。

### ⑦ Tests 覆盖

- `Tests/DemoCatalogTests.swift`（部分涉及 Goods demo 数据）；`Tests/SaobeiImportTests.swift` 部分。⚠️ GoodsFilter/GoodsState/GoodsStats 无专用单测。

---

## D6. Performance（营业额/业绩）

**文件**：`Performance/PerformanceView.swift`（346 行）、`Performance/PerformanceModel.swift`（240 行）、`Performance/MoneyEditorSheet.swift`（229 行）、`Performance/TransactionHistoryView.swift`（59 行）。模型：`Performance`（amount/note/date/incomeSource/paymentMethod，定义在 Models，见②）、`Expense`（amount/category/note/date）。Repository：`PerformanceRepository`（`AppRepository.swift:75-...`，add 含 incomeSource 参数，`AppRepository.swift:79`）、`ExpenseRepository`。

### ① PerformanceView UI 结构树（PerformanceView.swift）

```
PerformanceView（ScrollView）导航标题："经营数据"
├─ performanceHero（渐变圆角 24 卡）
│ ├─ "本月营业额" + "经营数据" caption
│ ├─ 本月金额（46pt bold rounded，monospacedDigit）
│ └─ 今日金额 + changeBadge（较昨日 ±x.x%，昨日为 0 则"暂无昨日对比"）+ 近7天 TrendChart（宽120）
├─ secondaryMetrics「关键指标」：昨日 / 本年（Divider 上下）
├─ sourcesSection「收入来源」：本月按 IncomeSource 拆分（来源名 / 金额 / 占比%），无收入→"本月暂无收入"
└─ recordsSection「交易流水」：近30天合并记录前 12 条（PerformanceRecordRow）
├─ 空 → 「暂无交易记录」+ 「记一笔」按钮
└─ "查看全部" NavigationLink → TransactionHistoryView
工具栏：右上 + Menu：「记收入」/「记支出」/「扫呗导入」（PerformanceView.swift:100-110）
```

- `PerformanceRecordRow`（`PerformanceView.swift:283-333`）：图标气泡（收入 arrow.down.left/brand；支出 arrow.up.right/danger；来源"扫呗"时 qrcode/neutral）+ 标题（note 为空则 "营业额"/支出）+ 副标题（来源 · 时间）+ 金额（收入 +¥ 绿色、支出 -¥ 红色）+ trash 删除按钮。
- 点击行 → `MoneyEditorSheet(mode:.editPerformance/.editExpense)`；trash → confirmationDialog「删除这条经营记录？」。
- 聚合口径（`PerformanceView.swift:26-60`）：todayRevenue（isToday）、yesterdayRevenue、monthRevenue（本月1日 0 点→今日 23:59:59）、yearRevenue（年初→今日）。changePercent = (今-昨)/昨*100（`PerformanceView.swift:52-55`）。
- records 范围：近 30 天（`PerformanceView.swift:62-65`），合并收入+支出按日期倒序（`MoneyRecord.merged`，`PerformanceModel.swift:210-238`）。

### ② MoneyEditorSheet 全部表单字段（MoneyEditorSheet.swift）

- 4 种模式（`MoneyEditorSheet.swift:7-11`）：new(.income)/new(.expense)/editPerformance/editExpense；标题分别为 "记一笔收入"/"记一笔支出"/"编辑收入"/"编辑支出"。

| 卡片 | 字段 | 控件 | 校验/约束 |
|---|---|---|---|
| 金额 | 金额（¥ 大字，heroMoney 字体） | TextField decimalPad | **必须 > 0**：去掉逗号后 `Double(cleaned) > 0`（`MoneyEditorSheet.swift:64-68`）；0/负数/空 → 保存按钮 disabled |
| 明细 | 备注（选填；支出 placeholder 例 "进了两箱可乐"） | TextField | 选填 |
| 明细 | 日期 | DatePicker（日期） | 默认今天，可选历史 |
| 分类（仅支出） | 分类 | V32SegmentedPicker：进货/房租/水电/人工/其他，默认"其他" | 必填单选 |
| 收入来源（仅收入） | 来源 | V32SegmentedPicker：门店/美团/其他，默认门店 | 必填单选 |

- 编辑回填（`MoneyEditorSheet.swift:172-193`）：金额整数则显示整数形式；收入来源用 `IncomeSource.from(performance:)`（已存值优先）；支出回填分类。
- 保存：新建 → `PerformanceRepository.add(amount:note:date:incomeSource:)` / `ExpenseRepository.add`；编辑收入可改 `incomeSource`（`MoneyEditorSheet.swift:210`）。
- 失败 alert：「保存失败」/"经营记录未保存，请重试。"。

### incomeSource 语义（PerformanceModel.swift:86-130）

- `IncomeSource`：store="门店" / meituan="美团" / other="其他"。
- `IncomeSource.from(performance:)` 解析优先级：① `performance.incomeSource` 字段非空且能匹配 → 直接用；② 为空时看 `paymentMethod`（扫呗导入兼容："美团"/"meituan"→美团，"门店"/"store"→门店）；③ fallback note 关键词（含"美团"→美团，含"门店"/"到店"→门店，否则其他）。
- `Performance` 模型字段（据 `PerformanceModel.swift` 引用与 `AppRepository.swift:79`）：amount, note, date, incomeSource（String，默认"门店"语义 `.store`）, paymentMethod（扫呗）。
- `IncomeSourceSummary.compute`：本月范围按来源汇总金额与占比（`PerformanceModel.swift:134-154`）。
- `MoneyRecord.source` 显示标签由 `RecordSourceLabel.display(performance:/expense:)` 决定（定义在别处，DisplayLogicTests 断言「RecordSourceNeverShowsOther」——来源绝不显示"其他"）。

### ③ TransactionHistoryView（全部交易）

- `List` + `.insetGrouped`，`searchable`（prompt "搜索交易或来源"，按 title/source 过滤，`TransactionHistoryView.swift:16-24`）。
- 空：`ContentUnavailableView("暂无交易", systemImage: "tray", description: "导入或记录交易后会显示在这里。")`（`TransactionHistoryView.swift:29-31`）。
- 行：`TransactionHistoryRow`——图标 + 标题 + 「yyyy年M月d日 HH:mm · 来源」 + 金额（+/- colored，monospacedDigit）。**只读：无编辑/删除入口**（与 PerformanceView 的 12 条不同）。
- ⚠️ **该页是 iOS 系统 `List` 风格**（insetGrouped），视觉迁移时需按 iOS V3.6 原样复刻而非默认 Material。

### ④ 状态机与交互

- 无状态机（金额记录只有增删改）。
- 删除：`PerformanceView` 记录行 trash → confirmationDialog（`PerformanceView.swift:112-124`）；`deleteRecord` 按类型分发到 Performance/Expense Repository（`PerformanceView.swift:275-279`）。
- 扫呗导入：toolbar Menu「扫呗导入」→ `SaobeiImportSheet()`（`PerformanceView.swift:107`，属扫呗组范围，此处仅记录入口）。

### ⑤ ⑥ iOS-only API / Tests

- 无特殊 Apple-only API（图表 `TrendChart` 为自绘，组 E/F 范围）。
- `Tests/IncomeSourceTests.swift`（6 个：已存来源优先、note fallback、paymentMethod 扫呗兼容、美团计入今日、来源拆分汇总、跨来源统计）。
- `Tests/DisplayLogicTests.swift:testRecordSourceNeverShowsOther`。
- 无 UI 测试。

---

## D7. Calendar（日历）

**文件**：`Calendar/CalendarView.swift`（339 行）、`Calendar/CalendarModel.swift`（75 行）。数据全部来自 `@Query` 全量 6 表，纯内存聚合。

### ① 页面 UI 结构树（CalendarView.swift）

```
CalendarView（ScrollView）导航标题："日历"
├─ monthNavigator：chevron.left / "2026年10月"（zh_CN wide month）/ chevron.right
├─ V32FieldGroup（月历卡）
│ ├─ weekdayHeader：日 一 二 三 四 五 六（周日首列，CalendarView.swift:14-18 显式 firstWeekday=1）
│ └─ monthGrid：7 列 LazyVGrid，首尾补 nil 空位（格数=7倍数）
│ └─ CalendarDayCell：日期数字（今日=深墨绿实心圆白字；选中=卡片色圆+描边）+ 状态点（最多5点）
└─ dayDetail：「M月d日 · 星期X」+ V32FieldGroup
└─ CalendarDetailRow（圆点+标签+副标题+右侧金额）：营业额/收支 / 待办事项 / 记录 / 临期提醒 / 客户需求
空 → 「当天暂无经营记录」
```

- 状态点颜色（`CalendarView.swift:290-300`）：营业额 绿(brand) / 待办 蓝(info) / 临期 橙(amber) / 客户 灰(neutral) / 备忘 三级灰。
- 月份切换：±1 月，fade 动画（`CalendarView.swift:90-104`）。

### ② 日历聚合规则（CalendarModel.swift，核心）

- `CalendarAgenda.dayData(date:todos:performances:expenses:expiryItems:customers:memos:)`（`CalendarModel.swift:22-47`）：
- todos：**未完成** 且 dueDate 同日
- revenues/expenses：date 同日
- expiry：status==pending 且 expiryDate 同日
- customers：`deliveryTime?? createdAt` 同日（deliveryTime 从 `CustomerDeliveryStorage.decode` 解）
- memos：createdAt 同日
- `eventFlags`（`CalendarModel.swift:53-74`）：同口径布尔（hasRevenue 含支出；hasTodo 不要求未完成——⚠️ **状态点 hasTodo 含已完成项**，与 dayData 的未完成口径不一致）。
- 详情行（`CalendarView.swift:199-246`）：营业额/收支（收入 n 笔 · 支出 n 笔，右侧 ¥整数分组）；待办（前2项："HH:mm 标题"，00:00/nil 显示"全天"）；记录（前2标题）；临期（前2 "名称 ×数量"）；客户需求（前2 "HH:mm 地址"，未设时间显示"未设配送时间"）。

### ③ 日历 vs 日程（Schedule）的关系（重点澄清）

| | CalendarView（日历） | ScheduleView（日程） |
|---|---|---|
| Tab 位置 | **不是 Tab**，是日程页内的二级入口（"完整月历"） | **Tab 栏第 2 个**（Tab 顺序见 B 组） |
| 周起始 | 周日（firstWeekday=1，`CalendarView.swift:16`） | 周一（firstWeekday=2，`ScheduleView.swift:19`） |
| 视图 | 月网格 + 当日聚合详情 | 周条 + 当日时间轴 + 全天事项 + 当日经营摘要 |
| 数据层 | CalendarAgenda（dayData/eventFlags） | 复用 CalendarAgenda.dayData，再经 ScheduleAgenda.make 派生 |
| 导航 | 无 toolbar 入口（从日程进） | toolbar：「今天」按钮 + 日历图标 NavigationLink→CalendarView |

### ④ iOS-only / Tests

- `Locale(identifier: "zh_CN")` + `.dateTime.year().month(.wide)` 格式化（Android 用 java.time + Locale.CHINA）。
- `Tests/DayTimeLabelTests.swift`（时间标签规则）；`ScheduleAgendaTests` 覆盖 ScheduleAgenda；⚠️ **CalendarAgenda.dayData/eventFlags 本身无专用测试**（仅被 Schedule 测试间接覆盖）。

---

## D8. Schedule（日程）

**文件**：`Schedule/ScheduleView.swift`（537 行）、`Schedule/ScheduleAgenda.swift`（203 行）。

### ① 页面 UI 结构树（ScheduleView.swift）

```
ScheduleView（ScrollView）导航标题："日程"
├─ weekStrip：年月标题 + 月份左右箭头 + 周条（一~日 7 格，周一起始；选中=深墨绿圆角块，今日未选中时下方小圆点）
├─ timelineSection「时间」（有 timedEvents 才显示）
│ └─ timelineRow：左侧 HH:mm + 卡片（todo：图标+标题+副标题；delivery：NavigationLink→CustomerView 带 chevron）
├─ allDaySection「全天事项」（右上角 "n 项" 计数）
│ ├─ 空（且时间轴也空）→ icon sun.max「该日期暂无事项」/"这一天还没有安排"
│ └─ V32FieldGroup：全天 todos（V32Checkbox 可直接切换完成）/ deliveries（→CustomerView）/ expiry（可展开备注+照片）/ memos（→MemoView）
└─ summarySection「当日经营」：→PerformanceView，收入/支出/净额三格
工具栏：右上「今天」文字按钮 + 日历图标 → CalendarView（ScheduleView.swift:104-114）
```

- 临期行可展开：默认折叠，点击展开备注卡片 + 140 高图片（`ScheduleView.swift:416-464`，`expandedExpiry` 按 notificationID）。
- 已完成事项在时间线/全天均弱化（灰色+删除线，`ScheduleView.swift:326-334, 384-392`）。

### ② ScheduleAgenda 派生规则（ScheduleAgenda.swift，纯函数，可单测）

- `hasClock(date)`：hour/minute 任一非 0 → 有真实钟点（`ScheduleAgenda.swift:56-60`）。
- `make(from:dayData, undatedTodos:)`（`ScheduleAgenda.swift:70-117`）：
- timedEvents：① dueDate 含真实钟点的 Todo；② 有真实 deliveryTime 的配送（event 带 date）。
- 全天：dueDate 为 nil/当天 00:00 的 Todo；无配送时间的客户单（按 createdAt 落当天）；临期（expiryDate 同日）；备忘（createdAt 同日）。
- **仅查看"今天"时**：全部未完成且无截止时间的 Todo 注入今天全天。
- **Performance/Expense 永不逐笔进时间轴**，只聚合为 revenue/expense/net 摘要。
- 全天 todos 排序：优先级降序，同级 createdAt 升序（`ScheduleAgenda.swift:104-107`）。
- 「当天完成」口径（`ScheduleAgenda.swift:127-201`，与首页「今日已完成」同一事实源）：
- Todo：isCompleted 且 completedAt 同日；completedAt 缺失的历史数据仅在查看今天时归入。
- 配送：status==done 且 updatedAt 同日。
- 当天完成但 dueDate/deliveryTime 不在当天的项补入对应桶（去重），保证"首页计数点进来后每一项都能追踪到"。
- 日程页直接切换待办完成：`allDayTodoRow` 的 V32Checkbox → `TodoRepository.toggleComplete`，失败 alert「操作失败」/"事项状态未改变，请重试。"（`ScheduleView.swift:388-406`）。

### ③ Tests

- `Tests/ScheduleAgendaTests.swift`：8 个（无时间数据进全天、undated 仅今天注入、收支只聚合、真实钟点排序、hasClock 分类、完成项 timed/allday 分类不重复、done 配送保留在 timed/allday）。
- `Tests/CompletedItemsTests.swift`：7 个（首页-日程完成口径一致性）。

---

## D9. DailyReport（今日经营日报）

**文件**：`DailyReport/DailyReportBuilder.swift`（55 行）、`DailyReport/DailyReportSheet.swift`（97 行）。入口位置：调用方（首页，属 B 组范围）通过 `DailyReport.build(...)` 构造后弹出 `DailyReportSheet`。

### ① 内容结构（DailyReportBuilder.swift）

`DailyReport` 值类型字段：date / todayRevenue / yesterdayRevenue / completedTodos / pendingTodos / deliveries / pendingExpiry。

- 构建规则（`DailyReportBuilder.swift:36-53`）：
- todayRevenue：performance.date 同日求和；yesterdayRevenue 同理昨日。
- completedTodos：`completedAt` 同日计数（缺失 completedAt → 不计）。
- pendingTodos：未完成 且（dueDate 为 nil 或 dueDate 同日）。
- deliveries：客户需求 status!= done **总数**（不限日期）。
- pendingExpiry：临期 status==pending 总数（不限日期）。
- `changeText`：昨日为 0 → "昨日暂无营业额，无法对比"；|change|<0.05 → "与昨日基本持平"；否则 "较昨日增长/下降 x.x%"。
- `shareText`（分享文本模板，`DailyReportBuilder.swift:25-34`）：
```
M月d日
今日营业额：¥x,xxx
较昨日增长 x.x%
待办：完成 n 件，未完成 n 件
配送：待处理 n 单
临时商品待处理：n 件
```

### ② DailyReportSheet UI（DailyReportSheet.swift）

```
DailyReportSheet（ScrollView，sheet [.medium,.large]）
├─ header：「今日经营日报」+ 左上「关闭」
├─ summary：今日营业额（heroMoney 大字）+ changeText
├─ detailRows：已完成待办 n / 未完成待办 n / 配送待处理 n / 临期待处理 n（每行 48 高，分隔线）
└─ 底部按钮行：V32SecondaryButton「复制文本」(doc.on.doc) + V32PrimaryButton「分享」(square.and.arrow.up)
```

- 复制：`UIPasteboard.general.string = report.shareText` + Haptic.success（`DailyReportSheet.swift:35-38`）。
- 分享：`UIActivityViewController(activityItems: [shareText])`，iPad popover 居中处理（`DailyReportSheet.swift:82-95`）。
- ⚠️ **注意文案**：shareText 里临期行写的是「临时商品待处理」（`DailyReportBuilder.swift:32`），与临期模块命名不一致，parity 时照搬。

### ③ iOS-only / Tests

- `UIPasteboard`（复制）→ Android ClipboardManager；`UIActivityViewController`（分享）→ Android Sharesheet（ACTION_SEND）。
- ⚠️ **DailyReport.build 无专用测试**。

---

## 跨模块汇总

### A. Editor Sheet 表单字段总表（保存校验）

| Sheet | 必填 | 校验失败表现 |
|---|---|---|
| TodoEditorSheet | 标题 | 保存按钮 disabled（opacity 0.5） |
| CustomerEditorSheet | 购买内容 + 配送地址（双必填） | 保存按钮 disabled |
| MemoEditorSheet | 标题或内容任一 | 保存按钮 disabled；标题≤100/内容≤2000 静默截断 |
| ExpiryEditorSheet | 名称 + 数量>0 | 保存按钮 disabled；名称≤100/备注≤200 静默截断；到期日不可选过去 |
| GoodsEditorSheet | 名称 | 保存按钮 disabled；失败时静默（无 alert） |
| MoneyEditorSheet | 金额>0 | 保存按钮 disabled；逗号清洗后 Double 解析 |
| RecordEditorSheet（TodoView 私有，**已无调用方**） | 内容 | disabled |

所有 Sheet 共通：左上"取消" + 居中标题 + 底部 `V32PrimaryButton("保存", checkmark)`；保存失败 alert 标题「保存失败」（Goods 除外，无 alert）。

### B. 删除交互总表

| 模块 | 删除入口 | 确认 |
|---|---|---|
| Todo | 行内 trash | confirmationDialog「删除这条待办？」 |
| Customer | 长按 contextMenu「删除」 | confirmationDialog「删除这条客户需求？」 |
| Memo | 卡片 trash | confirmationDialog「删除这条备忘？」 |
| Expiry | 行内 trash | confirmationDialog「删除这条临期记录？」 |
| Goods | 行内 trash | **无确认，直接删除，失败静默** |
| Performance 记录 | 行内 trash | confirmationDialog「删除这条经营记录？」 |
| TransactionHistory | — | 只读，无删除 |

**无一处使用 iOS 原生 swipe-to-delete**（`.onDelete`）；Customer 用自绘 `V32SwipeRow`（右滑露出推进操作，非删除）。Android 侧建议统一按此表实现，不要引入原生滑动删除。

### C. 空状态文案总表

| 页面 | icon | 标题 | message/附加 |
|---|---|---|---|
| Todo 今天 | checkmark.circle | 今天没有待办，去休息一下吧 | — |
| Todo 明天 | checkmark.circle | 明天暂无待办 | — |
| Todo 逾期 | checkmark.circle | 没有逾期事项，真棒 | — |
| Todo 已完成 | checkmark.circle | 还没有已完成的任务 | — |
| Customer 空 | shippingbox | 暂无客户需求 | 可以先新增一条配送需求 +「新增配送」按钮 |
| Customer 筛选空 | line.3.horizontal.decrease.circle | 当前筛选暂无结果 | 可以切换筛选查看其他需求 |
| Memo | square.and.pencil | 暂无记录，点击右下角添加 | （按钮实际在顶部 toolbar） |
| Expiry | shippingbox | 暂无临期商品 | 可以新增一条临期记录 +「新增临期商品」按钮 |
| Goods | shippingbox | 还没有商品 | 无按钮 |
| Performance 流水 | tray(Label) | 暂无交易记录 | +「记一笔」按钮 |
| TransactionHistory | tray | 暂无交易 | 导入或记录交易后会显示在这里。 |
| Schedule 当日空 | sun.max | 该日期暂无事项 | 这一天还没有安排 |
| Calendar 当日空 | — | 当天暂无经营记录 | — |

### D. iOS-only API 清单（D 范围内）

| API | 位置 | Android 等价 |
|---|---|---|
| PhotosPicker / PhotosUI | Todo/Customer/Memo/Expiry/Goods 各 EditorSheet 的 PhotoPickerField | ActivityResultContracts.PickVisualMedia |
| UIPasteboard | CustomerView.copyAddress（复制地址）；DailyReportSheet（复制文本） | ClipboardManager |
| contextMenu（长按） | CustomerRow | 长按弹窗菜单 / 更多按钮 |
| confirmationDialog / alert | 各 View 删除/失败 | BottomSheetDialog / AlertDialog |
| UIActivityViewController | DailyReportSheet.share | ACTION_SEND Sharesheet |
| DatePicker graphical | ExpiryEditorSheet | MaterialDatePicker / DatePickerDialog |
| decimalPad/numberPad keyboardType | Goods/Money 编辑器 | inputType numberDecimal/number |
| NotificationManager（schedule/cancel） | 各 Repository | NotificationManager + WorkManager/AlarmManager（A 组范围） |
| Haptic（自封装 UIKit 反馈） | 全模块 | Vibrator / HapticFeedbackConstants |

### E. Tests 覆盖矩阵（D 范围）

| 模块 | 有测试 | 无测试 |
|---|---|---|
| Todo 过滤/分组 | DisplayLogicTests.testTodoGroupsByPeriod；DayTimeLabelTests；CompletedItemsTests | TodoRepository CRUD 本体 |
| Customer | DisplayLogicTests（payload 隐藏）；CompletedItemsTests（done 口径）；ScheduleAgendaTests（done 配送） | CustomerRepository；V32SwipeRow 交互；筛选排序 |
| Memo | — | **MemoSearch/MemoFilter/MemoRepository 全部无测试** |
| Expiry | — | **ExpiryStats/分组阈值/ExpiryBadge/ExpiryRepository 全部无测试**（高风险） |
| Goods | DemoCatalogTests（部分） | **GoodsFilter/GoodsState/GoodsStats/GoodsRepository 无专用测试** |
| Performance | IncomeSourceTests（6）；DisplayLogicTests.testRecordSourceNeverShowsOther | PerformanceRepository/ExpenseRepository；MoneyRecord.merged |
| Calendar | DayTimeLabelTests（间接） | **CalendarAgenda.dayData/eventFlags 无专用测试** |
| Schedule | ScheduleAgendaTests（8）；CompletedItemsTests（7） | ScheduleView 页面 |
| DailyReport | — | **DailyReport.build/shareText 无测试** |

**结论**：纯函数派生层（ScheduleAgenda、IncomeSource、DayTimeLabel）测试较好；**Expiry、Memo、Goods、CalendarAgenda、DailyReport 派生逻辑零测试**，Android 迁移时建议把这些作为 Parser/Domain 单测优先补齐（正好对应 Phase 6 要求）。
