# B 部分：数据层 / 模型 / 工具 审计报告

> 审计基线：`feature/v3.6-ui-ai-expansion`（iOS 仓库 kevin2xiaomao-max/XiaoZhangGui）
> 审计工作区只读路径：`~/workspace/xzg-v36-audit`
> 报告目标：为 Android V3.6 迁移提供完整实体-字段映射、Repository 行为、枚举状态机、备份格式、设置键与 iOS-only API 清单。

---

## 0. SwiftData 实体总览（共 7 个 @Model）

| # | 实体 | 文件 | 行 | 对应 Room 表建议名 |
|---|------|------|----|--------------------|
| 1 | `Todo` | `XiaoZhangGui/Models/Todo.swift` | 7-54 | `todos` |
| 2 | `ExpiryItem` | `XiaoZhangGui/Models/ExpiryItem.swift` | 8-52 | `expiry_items` |
| 3 | `CustomerRequest` | `XiaoZhangGui/Models/ExpiryItem.swift` | 63-102 | `customer_requests` |
| 4 | `Goods` | `XiaoZhangGui/Models/Goods.swift` | 8-50 | `goods` |
| 5 | `Memo` | `XiaoZhangGui/Models/Memo.swift` | 7-19 | `memos` |
| 6 | `Performance` | `XiaoZhangGui/Models/Money.swift` | 10-35 | `performances` |
| 7 | `Expense` | `XiaoZhangGui/Models/Money.swift` | 39-55 | `expenses` |

注意：
- 非 SwiftData 模型（`ExecutionJournal.swift:6` 注释明确写了"不改 7 个 @Model"），与上述 7 个一致，无遗漏。
- `@Attribute(.externalStorage)` 用在 4 个实体的图片字段（见各表），表示大图片存外部文件。
- **注意**：`SaobeiParsedRow`、`PaymentCode`、`WeatherSnapshot` 等**不是** SwiftData @Model（见 §3）。

---

## 1. 实体-字段映射表

### 1.1 Todo（待办）— `Models/Todo.swift:7`

| 字段 | Swift 类型 | 默认值 | 语义说明 | Room 类型建议 |
|------|-----------|--------|----------|---------------|
| title | String | `""` | 标题 | TEXT NOT NULL |
| detail | String | `""` | 备注 | TEXT NOT NULL |
| dueDate | Date? | nil | 截止时间，nil=无截止 | INTEGER（epoch millis，可空） |
| priority | Int | 0 | 0 低 / 1 中 / 2 高（见 `TodoPriority`） | INTEGER |
| imageData | Data? | nil | 附件图片，`@Attribute(.externalStorage)` | BLOB（外部文件存储） |
| isCompleted | Bool | false | 完成态 | INTEGER(0/1) |
| createdAt | Date | Date() | 创建时间 | INTEGER NOT NULL |
| completedAt | Date? | nil | 完成时间，toggle 时写/清（`AppRepository.swift:31`） | INTEGER（可空） |
| notificationID | String | `UUID().uuidString` | 通知稳定标识，UUID v4，旧数据懒填充（`Todo.swift:12-16`） | TEXT NOT NULL |

### 1.2 ExpiryItem（临期/退货商品）— `Models/ExpiryItem.swift:8`

| 字段 | Swift 类型 | 默认值 | 语义说明 | Room 类型建议 |
|------|-----------|--------|----------|---------------|
| name | String | `""` | 商品名 | TEXT NOT NULL |
| category | String | `""` | 分类 | TEXT NOT NULL |
| quantity | Int | 1 | 件数 | INTEGER |
| productionDate | Date? | nil | 生产日期（可选） | INTEGER（可空） |
| expiryDate | Date | Date() | 到期日（到期日 0 点计算 daysLeft） | INTEGER NOT NULL |
| remindDaysBefore | Int | 7 | 提前提醒天数 | INTEGER |
| note | String | `""` | 备注 | TEXT NOT NULL |
| imageData | Data? | nil | 图片（externalStorage） | BLOB（外部） |
| createdAt | Date | Date() | 创建时间 | INTEGER NOT NULL |
| returnStatus | String | `ReturnStatus.pending.rawValue` = "待处理" | 退货状态字符串（见 §5.2） | TEXT NOT NULL |
| returnedAt | Date? | nil | 标记已退货时写入当前时间（`ExpiryItem.swift:74-80`） | INTEGER（可空） |
| notificationID | String | UUID v4 | 通知稳定标识 | TEXT NOT NULL |

### 1.3 CustomerRequest（客户需求）— `Models/ExpiryItem.swift:63`

| 字段 | Swift 类型 | 默认值 | 语义说明 | Room 类型建议 |
|------|-----------|--------|----------|---------------|
| customer | String | `""` | **编码串**：`CustomerDeliveryStorage` 编码，格式 `xzg-delivery-v1:<base64(JSON)>`；JSON 内 `deliveryTime` / `note` / `legacyCustomer`（`Features/Customer/CustomerEditorSheet.swift:198-226`）。纯旧数据为明文客户名。 | TEXT NOT NULL |
| roomOrAddress | String | `""` | 房号/地址 | TEXT NOT NULL |
| phone | String | `""` | 电话 | TEXT NOT NULL |
| content | String | `""` | 需求内容（必填，init 无默认值） | TEXT NOT NULL |
| status | String | `CustomerStatus.pending.rawValue` = "待处理" | 状态字符串（见 §5.3） | TEXT NOT NULL |
| imageData | Data? | nil | 图片（externalStorage） | BLOB（外部） |
| createdAt | Date | Date() | 创建时间 | INTEGER NOT NULL |
| updatedAt | Date | Date() | 更新时间；`update()`/`advanceStatus()` 都会刷新（`AppRepository.swift:263-286`） | INTEGER NOT NULL |
| notificationID | String | UUID v4 | 通知稳定标识 | TEXT NOT NULL |

⚠️ **关键语义陷阱**：`customer` 字段内嵌了配送时间与备注编码（`CustomerDeliveryStorage.decode($0.customer).deliveryTime`，见 `Features/Calendar/CalendarModel.swift:41-44`）。日历按**配送时间**（解码出）聚类客户需求，无配送时间则 fallback 到 createdAt。`DisplayLogic.DisplayText.isEncoded`（`Utilities/DisplayLogic.swift:17-29`）专门过滤此类编码串不显示。

### 1.4 Goods（临时商品）— `Models/Goods.swift:8`

| 字段 | Swift 类型 | 默认值 | 语义说明 | Room 类型建议 |
|------|-----------|--------|----------|---------------|
| name | String | `""` | 商品名 | TEXT NOT NULL |
| category | String | "其他" | 分类，已知分类：饮料/零食/日用品/烟酒/其他（`Features/Goods/GoodsModel.swift:10`） | TEXT NOT NULL |
| barcode | String | `""` | 条码 | TEXT NOT NULL |
| stock | Int | 0 | 当前库存 | INTEGER |
| minStock | Int | 0 | 最小库存预警线；`isLowStock = stock <= minStock`（`Goods.swift:53-55`） | INTEGER |
| purchasePrice | Double | 0 | 进货价 | REAL |
| salePrice | Double | 0 | 售价 | REAL |
| productionDate | Date? | nil | 生产日期 | INTEGER（可空） |
| shelfLifeDays | Int | 0 | 保质期天数 | INTEGER |
| expiryDate | Date? | nil | 到期日 | INTEGER（可空） |
| note | String | `""` | 备注 | TEXT NOT NULL |
| imageData | Data? | nil | 图片（externalStorage） | BLOB（外部） |
| createdAt | Date | Date() | 创建时间 | INTEGER NOT NULL |
| updatedAt | Date | Date() | 更新时间；`update()` 刷新（`AppRepository.swift:302`） | INTEGER NOT NULL |

### 1.5 Memo（备忘）— `Models/Memo.swift:7`

| 字段 | Swift 类型 | 默认值 | 语义说明 | Room 类型建议 |
|------|-----------|--------|----------|---------------|
| title | String | `""` | 标题 | TEXT NOT NULL |
| content | String | `""` | 内容 | TEXT NOT NULL |
| imageData | Data? | nil | 图片（externalStorage） | BLOB（外部） |
| createdAt | Date | Date() | 创建时间（卡片色条索引基于它：`Int(createdAt.timeIntervalSince1970.magnitude) % 3`，`Features/Memo/MemoModel.swift:37-39`） | INTEGER NOT NULL |
| updatedAt | Date | Date() | 更新时间；排序按 updatedAt 倒序（`MemoModel.swift:33`）；`update()` 刷新 | INTEGER NOT NULL |

### 1.6 Performance（营业额记录）— `Models/Money.swift:10`

| 字段 | Swift 类型 | 默认值 | 语义说明 | Room 类型建议 |
|------|-----------|--------|----------|---------------|
| amount | Double | 0 | 金额 | REAL |
| note | String | `""` | 备注；空则显示"营业额"（`PerformanceModel.swift:188`）；旧记录的收入来源派生依据 | TEXT NOT NULL |
| date | Date | Date() | 发生日期（非 createdAt） | INTEGER NOT NULL |
| fingerprint | String | `""` | 扫呗防重复指纹；空字符串=手工记录（`Money.swift:13`） | TEXT NOT NULL |
| paymentMethod | String | `""` | 支付方式（如"美团"/"扫呗"）；P0-3 收入来源派生第二依据 | TEXT NOT NULL |
| orderNo | String | `""` | 订单号 | TEXT NOT NULL |
| importSource | String | `""` | 导入源，扫呗导入为 "saobei"（`AppRepository.swift:129`） | TEXT NOT NULL |
| incomeSource | String | `""` | P0-3 新增独立收入来源字段；`IncomeSource` 枚举 rawValue（门店/美团/其他）；空则 fallback note 关键词派生（`PerformanceModel.swift:120-143`） | TEXT NOT NULL |

### 1.7 Expense（支出记录）— `Models/Money.swift:39`

| 字段 | Swift 类型 | 默认值 | 语义说明 | Room 类型建议 |
|------|-----------|--------|----------|---------------|
| amount | Double | 0 | 金额 | REAL |
| category | String | "其他" | 支出分类；编辑器可选：进货/房租/水电/人工/其他（`Features/Performance/MoneyEditorSheet.swift:27`） | TEXT NOT NULL |
| note | String | `""` | 备注；合并记录行标题：note 空则用 category（`PerformanceModel.swift:192`） | TEXT NOT NULL |
| date | Date | Date() | 发生日期 | INTEGER NOT NULL |
| createdAt | Date | Date() | 创建时间 | INTEGER NOT
...[truncated 21932 chars]
---

## 3. 非 SwiftData 的数据结构（Android 需单独建模）

| 结构 | 类型 | 文件 | 存储位置 | Android 映射 |
|------|------|------|----------|--------------|
| `SaobeiParsedRow` | struct（Codable 无，Equatable/Identifiable） | `Features/Import/SaobeiModels.swift:3` | 内存态导入管线 | 内存 data class |
| `SaobeiParseResult` | struct | `SaobeiModels.swift:13` | 内存 | 内存 data class |
| `SaobeiImportCommitResult` | struct | `SaobeiModels.swift:21` | 内存 | 内存 data class |
| `SaobeiImportError` | enum | `SaobeiModels.swift:28` | — | 异常 |
| `PaymentCode` | struct（Identifiable/Codable/Equatable） | `Features/PaymentCode/PaymentCodeModel.swift:48` | UserDefaults JSON（metadata）+ 图片在 Application Support/PaymentCodes/ | DataStore（JSON）+ app 文件目录 |
| `WeatherSnapshot` / `WeatherDayForecast` / `WeatherForecast` | struct（Codable/Equatable/Sendable） | `Features/Weather/WeatherModel.swift:4/26/33` | 内存 + 缓存文件（iOS） | 内存 + 缓存文件 |
| `JournalEntry` | struct（Codable/Sendable/Equatable） | `Features/Assistant/AI/Tools/ExecutionJournal.swift:9` | Application Support/AI（JSON 账本） | app 文件目录 JSON |
| `CustomerDeliveryInfo` | struct（Codable） | `Features/Customer/CustomerEditorSheet.swift:198` | 嵌入 `CustomerRequest.customer` 字段 | 嵌入 Entity 字段（base64 JSON） |
| `HomeInboxItem` | struct（Identifiable/Equatable） | `Utilities/DisplayLogic.swift:116` | 内存派生 | 内存 data class |

**SaobeiParsedRow 完整字段**（`SaobeiModels.swift:3-11`）：`id`（=fingerprint 计算属性）、`date: Date`、`amount: Double`、`status: String`、`orderNo: String`、`paymentMethod: String`、`fingerprint: String`、`isSuccess: Bool`、`rawLine: String`。

**PaymentCode 完整字段**（`PaymentCodeModel.swift:48-56`）：`id: UUID`、`name: String`、`kind: PaymentCodeKind`（wechat/alipay/custom；显示名 微信收款码/支付宝收款码/自定义二维码）、`fileName: String`（仅文件名）、`createdAt: Date`、`order: Int`（从 0 追加顺序，UI 按 order 升序）。

**WeatherSnapshot 字段**（`WeatherModel.swift:4-24`）：`temperature: Double`、`feelsLike: Double?`、`condition: String`、`conditionCode: String`、`city: String`、`precipitationProbability: Double?`、`maxTemperature: Double?`、`minTemperature: Double?`、`observedAt: Date`、`isStale: Bool`（var）；派生 `isRaining`（conditionCode 含 rain/drizzle/thunderstorm）、`symbolName`。

**Saobei 列键**（`SaobeiColumn`，`SaobeiModels.swift:36-52`）：dateKeys=交易时间/交易日期/完成时间/支付时间/交易完成时间/时间；amountKeys=收款金额/实收金额/交易金额/订单金额/支付金额/金额；statusKeys=交易状态/订单状态/状态/支付状态；orderKeys=订单号/商户订单号/流水号/交易单号/平台订单号/商户单号；payKeys=支付方式/支付类型/付款方式/渠道。successStatuses=成功/支付成功/已支付/已完成/交易成功/success/SUCCESS/完成；failedStatuses=退款/已退款/失败/关闭/已取消/已关闭/撤销/fail。**Android CSV 解析需逐字复用这些键**。

**Expense 分类**（`Features/Performance/MoneyEditorSheet.swift:27`）：进货 / 房租 / 水电 / 人工 / 其他。

**Todo 逾期/时间轴分组**（`Features/Todo/TodoModel.swift:6-14`）：Tab = 今天/明天/逾期/已完成/备忘（records Tab 目前返回空列表）。时间轴分组（`TodoModel.swift:38-57`）：上午 0-12 / 下午 12-18 / 晚上 18-24（`DateExt.swift:48-58`），"待安排"兜底。

---

## 4. Repository 全方法清单（`XiaoZhangGui/Repositories/AppRepository.swift`，317 行）

> 统一副作用（`AppRepository.swift:8-13` 注释）：**每次**增/改/删/完成/状态推进成功后调用 `SnapshotSyncManager.refreshAll(context:)`（同步 BusinessSnapshot / Widget Timeline / Live Activity）。**Todo/Expiry/Customer 的增/改/删/状态推进还伴随 NotificationManager 调度/取消**（UserNotifications）。

### 4.1 TodoRepository（`AppRepository.swift:14-55`）

| 方法 | 输入 | 输出/副作用 |
|------|------|-------------|
| `add(title:detail:dueDate:priority:imageData:)` | 同名参数 | insert + save；**scheduleTodo**（见 §8.1）；refreshAll |
| `update(_ todo:)` | Todo（已变异） | save（Todo 无 updatedAt 字段，保持 Android 字段对齐）；**cancelTodo + scheduleTodo**（重排）；refreshAll |
| `toggleComplete(_ todo:)` | Todo | `isCompleted.toggle()`；completedAt=完成时 now/取消时 nil；save；完成→**cancelTodo**，取消完成→**scheduleTodo**；refreshAll |
| `delete(_ todo:)` | Todo | **cancelTodo**；delete + save；refreshAll |

### 4.2 MemoRepository（`AppRepository.swift:57-78`）

| 方法 | 输入 | 输出/副作用 |
|------|------|-------------|
| `add(title:content:imageData:)` | 同名参数 | insert + save；refreshAll（无通知） |
| `update(_ memo:)` | Memo（已变异） | updatedAt=now；save；refreshAll |
| `delete(_ memo:)` | Memo | delete + save；refreshAll |

### 4.3 PerformanceRepository（`AppRepository.swift:80-165`）

| 方法 | 输入 | 输出/副作用 |
|------|------|-------------|
| `add(amount:note:date:incomeSource:)` | Double/String/Date/IncomeSource=.store | 手工记录：fingerprint=""、paymentMethod/orderNo/importSource=""、incomeSource=rawValue；insert + save；refreshAll |
| `addImported(_ row: SaobeiParsedRow)` | SaobeiParsedRow | note=paymentMethod 空?"扫呗":"扫呗 · <paymentMethod>"；fingerprint/paymentMethod/orderNo/importSource="saobei" 按行填充；incomeSource=IncomeSource.from(note: row.paymentMethod)；insert + save；refreshAll |
| `importSaobei(_ rows:skippedFailed:)` → `SaobeiImportCommitResult` | [SaobeiParsedRow], Int | P1-3 语义：① 用 DB 全量非空 fingerprint 初始化 seen 集；② 文件内重复（同一 fingerprint）只计 duplicates 不落库；③ 批量 insert + **单次** save + **单次** refreshAll；④ 全重复时返回 inserted=0。返回 (inserted, duplicates, skippedFailed) |
| `update(_ performance:)` | Performance（已变异） | save；refreshAll |
| `delete(_ performance:)` | Performance | delete + save；refreshAll |

### 4.4 ExpenseRepository（`AppRepository.swift:167-188`）

`add(amount:category="其他":note:date:)` / `update` / `delete`：insert-or-mutate + save + refreshAll，无通知副作用。

### 4.5 ExpiryRepository（`AppRepository.swift:190-233`）

| 方法 | 输入 | 输出/副作用 |
|------|------|-------------|
| `add(name:category:quantity:productionDate:expiryDate:remindDaysBefore=7:note:imageData:)` | 同名参数 | insert + save；**scheduleExpiry**（§8.1）；refreshAll |
| `update(_ item:)` | ExpiryItem（已变异） | save；**cancelExpiry + scheduleExpiry**（重排）；refreshAll |
| `toggleReturn(_ item:)` | ExpiryItem | status 在 pending↔returned 切换（触发 returnedAt 写/清）；save；已退货→**cancelExpiry**，恢复待处理→**scheduleExpiry**；refreshAll |
| `delete(_ item:)` | ExpiryItem | **cancelExpiry**；delete + save；refreshAll |

### 4.6 CustomerRepository（`AppRepository.swift:235-292`）

| 方法 | 输入 | 输出/副作用 |
|------|------|-------------|
| `add(customer:roomOrAddress:phone:content:imageData:)` | 同名参数（customer 传已 encode 的串） | insert + save；**rescheduleCustomer**（§8.1）；refreshAll |
| `update(_ request:)` | CustomerRequest（已变异） | updatedAt=now；save；**rescheduleCustomer**（P1-5：编辑后统一重排，pending→delivering 时取消）；refreshAll |
| `advanceStatus(_ request:)` | CustomerRequest | status=next.rawValue，updatedAt=now；save；prev==pending→**cancelCustomer**；done 不排通知（delivering/pending 异常保持一致注释）；refreshAll |
| `delete(_ request:)` | CustomerRequest | **cancelCustomer**（全部后缀 id）；delete + save；refreshAll |

### 4.7 GoodsRepository（`AppRepository.swift:294-317`）

`add(_ goods:)` / `update(_ goods:)`（updatedAt=now）/ `delete(_ goods:)`：insert-or-mutate + save + refreshAll，无通知副作用。

### 4.8 其他写入口（不在 Repositories 目录但改变数据）

- `BackupService.restore`（`Data/BackupService.swift:200-293`）：绕过 Repository，直接构造 @Model 批量 insert + 单次 save；随后统一重建所有通知、一次 refreshAll。
- `DemoCatalog.seed`（`Demo/DemoMode.swift:50-57`）：仅写入内存容器（`isStoredInMemoryOnly`），不碰生产 DB。
- AI 工具执行器（`Features/Assistant/AI/Tools/`）：通过 Repository 写入真实数据（B 部分只列出口，细节见 AI 审计）。
- `PaymentCodeMetadataStore.save`（`PaymentCodeModel.swift:96-99`）：UserDefaults JSON；`PaymentCodeImageStore` 写文件系统图片。
- 语音解析落库：`VoiceDraft` → 由 ViewModel 映射到各 Repository 的 add 方法（映射规则见 §7）。

---

## 5. 枚举全清单与状态机

### 5.1 TodoPriority（`Models/Todo.swift:56`）

Int 枚举：low=0（"低优先级"/"低"）、medium=1、high=2。`Todo.priority` 存 Int。

### 5.2 ReturnStatus（`Models/ExpiryItem.swift:56`）

String 枚举：`pending="待处理"`、`returned="已退货"`。**转换**：`ExpiryRepository.toggleReturn` 在两者间切换；置 .returned 时 `returnedAt=now`，置 .pending 时 `returnedAt=nil`（`ExpiryItem.swift:74-80`）。

### 5.3 CustomerStatus（`Models/ExpiryItem.swift:105`）

String 枚举：`pending="待处理"` → `delivering="配送中"` → `done="已完成"`。
- `next` 属性（`ExpiryItem.swift:118-126`）：pending→delivering，delivering→done，done→done（终点自环）。
- UI 颜色：pending=警告黄（V21.warning）、delivering=蓝色（V21.info）、done=品牌绿（V21.brandGreen）。
- **转换副作用**（`AppRepository.swift:270-286`）：pending→delivering 立即取消跟进通知；进入 done 不排通知。

### 5.4 IncomeSource（`Features/Performance/PerformanceModel.swift:107`）

String 枚举：`store="门店"`、`meituan="美团"`、`other="其他"`。
- `from(note:)`：note 含"美团"→美团；含"门店"/"到店"→门店；其余→其他（大小写无关，trim 后判）。
- `from(performance:)`（P0-3，`PerformanceModel.swift:130-143`）：① incomeSource 字段非空且匹配枚举→直接用；② 为空时查 paymentMethod（"美团"/"meituan"→美团；"门店"/"store"→门店）；③ 仍为空→`from(note:)`。
- 用途：业绩页收入来源占比（`IncomeSourceSummary.compute`）、记录行标签（`RecordSourceLabel.display`）。

### 5.5 ExpiryGroup（`Features/Expiry/ExpiryModel.swift:4`）

临期分组（`ExpiryStats.init`，`ExpiryModel.swift:47-91`）：按 `daysLeft()`（到期日 0 点减参考日 0 点，`ExpiryItem.swift:83-89`）：
- `expired` 已过期：days<0（待处理）
- `urgent3` 紧急·3天内：0...3
- `urgent7` 注意·7天内：4...7
- `safe30` 安全·30天内：8...30
- `later` 较远·30天外：>30
- `returned` 已退货：独立组，按 returnedAt 倒序
- 统计三格：urgentCount(0...3)/warningCount(4...7)/safeCount(8...30)；副标题 7 天内件数（0...7）。

### 5.6 GoodsState（`Features/Goods/GoodsModel.swift:40`）

`expired`（expiryDate<now）→`expiringSoon`（7 天内）→`lowStock`（stock<=minStock）→`normal`，按此优先级判定（`GoodsModel.swift:56-64`）。

### 5.7 TodoTab（`Features/Todo/TodoModel.swift:6`）

today（今天）/tomorrow（明天）/overdue（逾期）/done（已完成）/records（备忘→空列表）。过滤语义见 `TodoFilter.todos`（`TodoModel.swift:15-36`）：today=未完成且（无截止或截止在今日区间）；overdue=未完成且截止<今日 0 点；done 按 completedAt 倒序。

### 5.8 PerformancePeriod / PerformanceChartPeriod（`PerformanceModel.swift:8/124`）

今日/本周/自定义：week=近 7 天（today-6 天到今日终点，对齐 Android minusDays(6)）；month=本月 1 日 0 点到下月 1 日 -1 秒；custom=起止日。图表周期：日/周→7 天趋势，月→30 天趋势。`PeriodComparison`：当前区间与等长上一区间的收入变化百分比（上期为 0 则 nil）。

### 5.9 VoicePhase / VoiceRecordType（`Features/Voice/VoiceModel.swift:7/29`）

- 状态机：idle→listening→recognized→parsing→preview→saving；异常分支 error(String) / textFallback（02 文档规定的 8 态，`VoiceModel.swift:3` 注释）。
- 记录类型：todo(待办)/revenue(营业记录)/expense(支出)/memo(记录)/expiry(临期退货)/customer(客户配送)。（"记录"=备忘）

### 5.10 PaymentCodeKind（`Features/PaymentCode/PaymentCodeModel.swift:15`）

wechat（微信收款码）/alipay（支付宝收款码）/custom（自定义二维码）。

### 5.11 MemoFilter（`Features/Memo/MemoModel.swift:12`）

all（全部）/text（文字，无图）/image（图片，有图）/voice（语音→恒为空列表，占位）。

### 5.12 WeatherViewState / WeatherFailureReason（`Features/Weather/WeatherModel.swift:39/47`）

idle/loading/loaded/notConfigured/unavailable(WeatherFailureReason)。失败原因：network（URLSession 层）/api（非 2xx 或解析失败）/unknown。

---

## 6. 备份文件格式（`XiaoZhangGui/Data/BackupService.swift`，390 行）

- **文件**：`xiao-zhang-gui-backup.json`，`formatVersion=2`，顶层结构：
```json
{
  "app": "xiao-zhang-gui",
  "version": 2,
  "exportedAt": <epoch millis>,
  "records": [ { "type": "todo"|"memo"|"performance"|"expense"|"expiry"|"customer"|"goods", ... }, ... ]
}
```
- **时间**：全部为 epoch 毫秒（`millis` = `timeIntervalSince1970*1000`，`BackupService.swift:296-298`）。
- **图片**：`imageBase64` 键，base64 字符串；恢复 `Data(base64Encoded:)`。
- **类型字段对照**（导出 `BackupService.swift:72-181`）：
  - todo: title/detail/priority/isCompleted/createdAt + 可选 dueDate/completedAt/imageBase64
  - memo: title/content/createdAt/updatedAt + 可选 imageBase64
  - performance: amount/note/date/fingerprint/paymentMethod/orderNo/importSource/incomeSource（全必填）
  - expense: amount/category/note/date/createdAt
  - expiry: name/category/quantity/expiryDate/remindDaysBefore/note/returnStatus/createdAt + 可选 productionDate/returnedAt/imageBase64
  - customer: customer（含 deliveryTime 编码串，round-trip 保留）/roomOrAddress/phone/content/status/createdAt/updatedAt + 可选 imageBase64
  - goods: name/category/barcode/stock/minStock/purchasePrice/salePrice/shelfLifeDays/note/createdAt/updatedAt + 可选 productionDate/expiryDate/imageBase64
- **恢复语义**（`BackupService.swift:203-204`）：**追加**（不清空现有数据）；单次 `context.save()`；通知重建；一次快照刷新；容忍 v1 备份（缺字段→安全默认：todo.completedAt 缺时用 exportedAt 补；performance.incomeSource 非法→"门店"；expense/goods.category 空→"其他"；expiry.returnStatus 非法→"待处理"；customer.status 非法→"待处理"）。
- **错误**：`BackupError.invalidFile`（无法解析 JSON）、`invalidRecords`（缺 records）、`writeFailed`（`BackupService.swift:17-29`）。
- Android 建议：`WorkManager`/后台协程生成同结构 JSON；导入时实现同等容错逻辑，保证与 iOS 备份文件**可互读**（跨平台需求应在差异文档声明）。

---

## 7. AppSettings 全部键（`XiaoZhangGui/Utilities/AppSettings.swift`，74 行）

UserDefaults 标准区（`UserDefaults.standard`，`@Observable`，didSet 即时写）：

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `shop_name` | String | "天福便利店" | 店名（首页问候/标题） |
| `owner_name` | String | "掌柜" | 掌柜名（问候语） |
| `month_goal` | Double | 120000.0 | 月目标（首页目标完成度=今日收入/(月目标/30)*100，`HomeModel.swift:31-32`） |
| `theme_mode` | String | "system" | system/light/dark（唯一主题入口是 ThemeStore，旧 `app_theme_name` 已删除并迁移） |
| `todo_reminder` | Bool | true | 待办通知总开关（`NotificationManager.swift:23` 门控） |
| `expiry_reminder` | Bool | true | 临期通知总开关（`NotificationManager.swift:48` 门控） |
| `voice_language` | String | "普通话" | 语音语言 |
| `avatar_emoji` | String | "👨🏻‍💼" | 头像 emoji |
| `avatar_image_data` | Data? | nil | 头像图片（nil 时 removeObject） |

其他 UserDefaults 键（散落在各处，Android DataStore 需同步）：
- `xzg_demo_mode_enabled`（Bool，DemoMode 开关，`Demo/DemoMode.swift:9`）
- `xzg.paymentCodes.metadata.v1`（Data，收款码 metadata JSON，`PaymentCodeModel.swift:58`）
- `xzg.db.usedLocalFallback.v1` / `xzg.db.sharedFailure.v1` / `xzg.db.persistentFailure.v1`（数据库健康标记，`Data/ModelContainer.swift:99-103`）
- 旧主题迁移键在 ThemeStore 处理（T26，见 A 部分）

---

## 8. iOS-only API 与 Android 等价方案

| iOS API | 用途/位置 | Android 等价 |
|---------|-----------|--------------|
| SwiftData（`@Model`, `ModelContext`, `ModelContainer`, `Schema`, `@Attribute(.externalStorage)`） | 全部 7 实体持久化；容器 `Data/ModelContainer.swift` | Room：7 Entity + DAO + RoomDatabase；图片 BLOB→外部文件（app files dir）或 Room BLOB |
| `FileManager.containerURL(forSecurityApplicationGroupIdentifier: XZGShared.appGroupID)` | App Group 共享 store（Widget 共享，`ModelContainer.swift:61-67`） | 无等价需求：单 App 内部 Room 数据库即可（Android Widget 通过 ContentProvider/Room 直接读同一 DB） |
| UserDefaults | AppSettings、PaymentCode metadata、Demo 开关、DB 健康标记 | DataStore Preferences（建议）或 EncryptedSharedPreferences |
| UNUserNotificationCenter（`Services/NotificationManager.swift`） | §8.1 三类通知 | `android.app.NotificationManager` + AlarmManager 精确闹钟（或 WorkManager）；通知渠道 |
| `UNCalendarNotificationTrigger` / `UNTimeIntervalNotificationTrigger` | 定时触发 | AlarmManager.setExactAndAllowWhileIdle / WorkManager |
| SFSpeechRecognizer / AVAudioEngine（语音识别，见 D 部分） | 语音输入 | Android SpeechRecognizer / ML Kit |
| URLSession（`Features/Weather/` API Provider） | 天气网络请求 | OkHttp/Retrofit |
| NSRegularExpression / ICU 正则（`VoiceModel.swift` 大量 `#"..."#` 字面量） | 语音解析 | `java.util.regex`（注意中文数字范围 `\u4e00-\u9fa5` 写法移植） |
| NumberFormatter（`Utilities/Format.swift:6-22`） | 金额千分位/两位小数 | `java.text.NumberFormat` / `DecimalFormat("#,##0.00")` |
| `Date.formatted(.dateTime...)` + `Locale("zh_CN")` | 中文日期格式化 | `java.time.format.DateTimeFormatter` + Locale.CHINA |
| `JSONEncoder/Decoder`（iso8601） | PaymentCode metadata、deliveryTime 编码 | kotlinx.serialization / Gson（ISO-8601 日期） |
| OSLog Logger（`ModelContainer.swift:6`） | 日志 | android.util.Log / Timber |
| WidgetKit Timeline / Live Activity（`SnapshotSyncManager.refreshAll` 目标） | 小组件/灵动岛刷新 | Android AppWidget + Glance |
| App Intents（`ModelContainer.swift:71` 注释提及） | 快捷指令入口 | Android App Shortcuts / Slice |

### 8.1 通知调度规则（Repository 副作用，Android 必须 1:1 实现）

1. **待办**（`Services/NotificationManager.swift:22-37`）：条件 `todoReminderEnabled && dueDate != nil && dueDate > now && !isCompleted`；标题"待办提醒"，body=title；在截止时间的年月日时分触发（`UNCalendarNotificationTrigger` 非重复）。通知 ID：`"todo-<notificationID>"`。
2. **临期**（`NotificationManager.swift:47-70`）：条件 `expiryReminderEnabled && status==pending`；触发=(expiryDate - remindDaysBefore) 当天 9:00，且必须>now；标题"临期退货提醒"，body=「<name>」还有 <days> 天到期（<qty> 件）/ 已到期变体。通知 ID：`"expiry-<notificationID>"`。
3. **客户跟进**（`NotificationManager.swift:81-108`）：仅 pending 状态；新增/编辑后 3600 秒（1 小时）触发"配送需求待跟进"，body=content · roomOrAddress；通知 ID：`"customer-<notificationID>-followup"`；离开 pending 立即取消（cancel 全部后缀 `-followup/-delivery/-custom`）。

---

## 9. 派生计算与格式化规则（业务逻辑，不可丢失）

### 9.1 格式化（`Utilities/Format.swift`，80 行）

- `money(v)` → `¥1,234.00`（千分位+2 位小数）；`groupedInt(v)` → `11,500`（Hero 大数字）；`groupedAmount(v)` → 整数用 groupedInt，否则 money。
- 日期：`formatDate` → "2026年10月2日"（zh_CN）；`time` → "HH:mm"；`dateTime` → 年月日时分；`monthDayTime` → "X月X日 HH:mm"（待办截止）；`monthDay` → "X月X日"（全天）；`memoTime` → "MM月dd日 HH:mm"（备忘卡片）；`shortDateTime` → "MM-dd HH:mm"（客户需求行）；`yyyyMMdd` → "2026年10月02日"。

### 9.2 日期工具（`Utilities/DateExt.swift`，68 行）

startOfDay/endOfDay（23:59:59）/startOfMonth/isToday/isBeforeToday/isTomorrow/isSameDay/`days(from:)`（整天数差）/dayPeriod（上午 0-12/下午 12-18/晚上 18-24）。

### 9.3 展示逻辑（`Utilities/DisplayLogic.swift`，222 行）

- `DisplayText.visible(v, fallback)`：trim 后空或"编码串"→fallback；`isEncoded`：`xzg-` 前缀 / 含 `xzg-delivery-v1:` / ≥32 位纯 base64 字符 → 视为编码串隐藏。
- `Greeting.phrase(at:owner:)`：<11 点"早上好"，<14"中午好"，<18"下午好"，否则"晚上好"；+ "，" + owner。
- `DayTimeLabel.label(date, unscheduledText)`（`DisplayLogic.swift:46-58`）：nil→unscheduledText；有钟点→当天 "HH:mm" / 非当天 "M月d日 HH:mm"；无钟点（当天 00:00）→当天"全天"/非当天"M月d日"。全天判定单一来源 `ScheduleAgenda.hasClock`（`DisplayLogic.swift:41-43`）。
- `RecordSourceLabel.display(performance:)`：incomeSource 为门店/美团→直接显示；否则 importSource/paymentMethod/note/category 中含"扫呗"/"saobei"→"扫呗"；category 非 banned（""、其他、other、收入、营业额、支出）→category；"手动"/"门店"/"美团"→对应；默认"手动"。
- `HomeInbox.items`（`DisplayLogic.swift:135-222`）：首页待办收件箱，limit=4，rank 排序：临期过期/今天=0、高优先级待办=1、配送中=2、普通配送=3、普通待办=4、远期临期=5；同 rank 按日期升序。id 基于 notificationID（`"todo-<id>"`/`"delivery-<id>"`/`"expiry-<id>"`）。

### 9.4 首页统计（`Features/Home/HomeModel.swift`，51 行）

`HomeStats.compute`：todayRevenue（今日 Performance 求和）、todayTodos（未完成且无截止/截止今天）、urgentExpiryCount（待处理且 0≤daysLeft≤7）、goalProgressPercent=Int(todayRevenue/(monthGoal/30)*100)。

### 9.5 日历聚合（`Features/Calendar/CalendarModel.swift`，79 行）

`CalendarAgenda.dayData`：当日未完成待办（dueDate 同天）+ Performance + Expense（date 同天）+ 到期临期（pending 且 expiryDate 同天）+ 当日新增客户需求（deliveryTime 解码值或 createdAt 同天）+ 备忘（createdAt 同天）。`eventFlags` 日期状态点颜色：绿=有收入/支出、蓝=有待办、橙=有临期、灰=有客户。

### 9.6 业绩派生（`Features/Performance/PerformanceModel.swift`，208 行）

- `PerformanceStats.compute`：区间内收入/支出/净额（净额=收入-支出）。
- `IncomeSourceSummary.compute`：门店/美团/其他三档金额+占比。
- `PerformanceTrend.last7Days/last30Days`：按日聚合，label="M/d"。
- `MoneyRecord.merged`：收支合并按日期倒序；收入标题=note 空→"营业额"；支出标题=note 空→category；source=RecordSourceLabel。

### 9.7 语音解析（`Features/Voice/VoiceModel.swift`，294 行）→ Android 必须逐规则移植

- `isUnsupportedQuery`：含"天气"且无记录意图词→不支持查询。
- `detectType` 优先级：进货/支出/花了→expense；营业额/收入/卖了/收款/入账→revenue；过期/临期/到期→expiry；配送/送货/送到/客户，或"送"+数量/客户名→customer；记一下/备忘/客人→memo；默认→todo。
- `parseAmount`：先阿拉伯数字（含小数），后中文数字（`ChineseNumber.parse` 支持"三百二十五"式，`Utilities/ChineseNumber.swift:13-33`）。
- `parseDueTime`：今天/明天/后天 + 上午/下午/晚上 X点（中文数字点数支持）；中午→12:00；pm<12 则+12；仅有日期无时间→当天 0 点。
- `parseQuantity`：N 箱/件/瓶/袋/个/份/条/盒（阿拉伯或中文数字）。
- `parseCustomerName`：X姐/X哥/X老板/X总/X姨/X叔/X婶/女士/先生（1-4 汉字+称呼），或 XX店/XX别墅/XX房。
- `parseGoodsName`（仅 customer 类型）：去掉时间/动词/数量/客户名后的剩余。
- `parse` 落库映射：expiry 天数（"还有N天"/"N天后"正则）、customer 的 goodsName/customerName/quantity/due。
- `VoiceDraft` 字段：type/title/detail/amount?/dueAt?/expiryDays?/customerName?/quantity?/goodsName?/original。
- `QuickCaptureSemantic`（`Features/QuickRecord/QuickCaptureSemantic.swift:4-13`）：listening="正在听…"、processing="正在整理…"、ready="请确认将保存的内容"、saving="正在保存…"、saved="已保存"、failed="保存失败，请重试"、savedMessage="已保存到：<dest>"。

### 9.8 Demo 数据（`XiaoZhangGui/Demo/DemoMode.swift`，263 行）

- `DemoMode`：`@Observable` 开关，UserDefaults 键 `xzg_demo_mode_enabled`；**新安装默认关闭**（`DemoMode.swift:22-28`）；`RuntimeMode.allowsMockData`（`Utilities/RuntimeMode.swift:6-16`）仅在 DEBUG 模拟器 + `XCODE_RUNNING_FOR_PREVIEWS` 或 `XZG_UI_PREVIEW_DEMO=1` 时允许 Mock。
- `DemoCatalog`：内存容器种子——Performance（近 7 天 2180~3180/天 + 当天 13 条明细 + 历史 30 天）、Todo（21 条，含逾期/已完成）、CustomerRequest（9 条，pending/delivering/done 覆盖）、ExpiryItem（9 条，days 3/1/7/0/2/4/-3/-1/10，含已退货）、Memo（9 条）；monthlyRevenue=68_400.0，monthlyGoal=120_000.0。
- `DemoImportPreview`：假扫呗导入预览（文件名"扫呗交易明细_2026-09-14.csv"，328 行/316 有效/12 重复/304 插入/18628.50 元）——**仅预览 UI 用**。

---

## 10. Tests/ 数据层测试覆盖（共 65 个测试文件）

数据层相关测试文件及用例数（`~/workspace/xzg-v36-audit/Tests/`）：

| 文件 | 用例数 | 覆盖内容 |
|------|--------|----------|
| BackupServiceTests.swift | 3 | 备份导出/恢复 round-trip |
| SaobeiImportTests.swift | 4 | 扫呗导入（重复/计数） |
| SaobeiImporterTests.swift | 5 | 导入器解析 |
| SaobeiRoundTripTests.swift | 3 | 解析→导入往返 |
| IncomeSourceTests.swift | 6 | 收入来源派生（含 P0-3） |
| DemoCatalogTests.swift | 3 | Demo 种子数据 |
| DatabaseSafetyTests.swift | 3 | 容器失败必须抛错、禁止回退内存库 |
| SaveReliabilityTests.swift | — | 保存可靠性 |
| CustomerImageRoundTripTests.swift | — | 客户图片往返 |
| DisplayLogicTests.swift | 6 | 展示逻辑 |
| DayTimeLabelTests.swift | — | 全天/时间标签 |
| ScheduleAgendaTests.swift | — | 日程议程（含 hasClock） |
| QuickRecordParserTests.swift | — | 快速记录解析 |
| PaymentCodeTests.swift | — | 收款码 metadata |
| Widget2Tests.swift | — | 快照/Widget 数据 |
| SnapshotSafetyTests.swift | — | 快照安全 |
| FlowConsistencyTests.swift | — | 流程一致性 |
| DestructiveSafetyTests.swift | — | 破坏性操作安全 |
| Build34RepairTests.swift | — | 历史修复回归 |
| Phase41AutomatedAcceptanceTests.swift | — | 自动化验收 |

⚠️ **注意**：iOS Tests 覆盖主要集中在解析/备份/派生计算；**Repository 的增删改查/通知副作用/状态推进在 Tests/ 中无直接单测覆盖**（Repository 逻辑靠 Phase41 自动化验收与手工测试）。Android 迁移时应为 Repository 建立完整的单元+集成测试，这是 iOS 侧的覆盖缺口。

---

## 11. 给 Android 迁移的关键结论

1. **7 张表，字段已对齐**：所有 @Model 文件头注释均写明"对齐 Android XxxEntity"，字段名与 Android Entity 命名一致（Todo 无 updatedAt 是有意为之，`AppRepository.swift:22-25` P0-1 注释）。
2. **最大语义陷阱**：`CustomerRequest.customer` 是 base64 编码串（`xzg-delivery-v1:`），内含 deliveryTime/note/legacyCustomer；`DisplayText.isEncoded` 负责隐藏。Android 必须复刻 encode/decode（`CustomerEditorSheet.swift:204-226`）及日历按 deliveryTime 聚类的逻辑，否则客户需求配送时间会丢失。
3. **通知是数据层契约的一部分**：Repository 的增删改查都附带通知调度/取消（三种规则见 §8.1），Android 必须用 AlarmManager/WorkManager 1:1 实现。
4. **备份格式 v2 必须互读**：导出/恢复字段对称、图片 base64、v1 兼容；建议 Android 实现同结构 JSON 读写。
5. **语音解析是纯规则引擎**：`VoiceParser` 全部正则+中文数字解析，无 ML 依赖，可逐条移植到 Kotlin（注意 NSRegularExpression → java.util.regex 的转义差异）。
6. **iOS 无 Repository 单测**：Android 应补齐 Room/Repository/通知调度的测试覆盖。
7. **Expense 无通知、无状态机**；Todo/Memo 无 updatedAt/只有 Todo 有 completedAt；Performance/Expense 用 `date`（业务日期）而非 createdAt 做统计——Android DAO 查询必须按 `date` 字段过滤。
