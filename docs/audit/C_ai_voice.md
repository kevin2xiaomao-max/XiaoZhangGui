# C 部分审计报告：AI 助手 / 语音 / 快速记录

> 只读审计，不修改任何代码。
> iOS 源码分支：`feature/v3.6-ui-ai-expansion`，HEAD SHA：`335981b`（`335981badfa7163ad56063662bf0d7b5d2a78451`）
> 审计工作区：`~/workspace/xzg-v36-audit`（只读）
> 审计范围：`XiaoZhangGui/Features/Assistant/`（49 个文件：`AI/` 子目录 45 文件 + `BusinessAssistantEngine.swift` + `Integration/` 3 文件）、`XiaoZhangGui/Features/Voice/`（4 文件）、`XiaoZhangGui/Features/QuickRecord/`（3 文件）、`XiaoZhangGui/Features/Intents/XZGAppIntents.swift`——C 范围共 57 文件，全部只读逐字审计
> 报告文件：`~/workspace/xzg-android/audit/C_ai_voice.md`

---

## 一、AI 可执行的全部业务动作清单（action 名 | 参数 | 写入目标 | 确认机制）

### 1.1 注册工具（`AI/Tools/ToolCatalog.swift:12-18`，`liteTools` 顺序固定，共 5 个）

权限分级：`AI/Core/AIDTO.swift:57-65`（`ToolName.permission`）、`AIDTO.swift:82-84`（`ToolPermission`：`read` / `create`）。

| 工具名（中文名） | 参数（字段名+类型+必填） | 真实写入目标 | 确认机制 |
|---|---|---|---|
| `searchRecords`（查询经营记录） | `kinds`: `[BusinessRecordKind]` **必填**（枚举 `AIDTO.swift:129-135`：`revenueToday` / `todoToday` / `recentMemo` / `expiringGoods` / `delivery`）；`query`: `String` 可选。必填规则 `ToolCatalog.swift:48` | **只读，不写入**。经 `BusinessContextProvider` 聚合 + `ContextRedactor` 脱敏后本地回答 | permission=`read` → **自动执行、不确认**。执行点 `AgentCore.swift:508-531`（`handleToolCall` 中 `call.name == .searchRecords` 分支，直接本地聚合回答，不出 ActionCard） |
| `recordRevenue`（记录营业额） | `amount`: `Double` **必填**；`source`: `String` 可选（美团/饿了么/现金/微信…）；`date`: ISO8601 `String` 可选；`note`: `String` 可选。必填规则 `ToolCatalog.swift:44`；参数结构 `AIDTO.swift:89-95` | `PerformanceRepository.add(amount:note:date:incomeSource:)` → SwiftData **`Performance`** 模型（`Integration/RepositoryToolExecutor.swift:78-97`，`add` 调用在 L88） | permission=`create` → **必须 ActionCard 用户确认**（见 §1.3） |
| `createTodo`（新建待办） | `title`: `String` **必填**；`detail`: `String` 可选；`dueDate`: ISO8601 可选；`priority`: `Int` 可选（0 普通/1 重要/2 紧急，对齐 `Todo.priority`）。必填规则 `ToolCatalog.swift:45`；结构 `AIDTO.swift:97-103` | `TodoRepository.add(title:detail:dueDate:priority:)` → **`Todo`** 模型（`RepositoryToolExecutor.swift:99-114`，`add` 在 L105） | **必须确认** |
| `createMemo`（新建备忘） | `title`: `String` **必填**；`content`: `String` **必填**。规则 `ToolCatalog.swift:46`；结构 `AIDTO.swift:105-108` | `MemoRepository.add(title:content:)` → **`Memo`** 模型（`RepositoryToolExecutor.swift:116-128`，`add` 在 L124） | **必须确认** |
| `createDelivery`（新建配送） | 必填项**无**（`ToolCatalog.swift:47` 返回 `[]`）；`customer` / `roomOrAddress` / `phone` / `content` / `goodsName` / `quantity` / `deliveryTime`(ISO8601) / `deliveryTimeText` / `amount`(`Double`) / `note` 均为可选。结构 `AIDTO.swift:110-127`。注意底线：客户与商品全空时 `ToolArgumentValidator` 拒绝（`AI/Tools/ToolExecutor.swift:63-67` 报「缺少配送客户 / 房号或商品」） | `CustomerRepository.add(customer:roomOrAddress:phone:content:)` → **`CustomerRequest`** 模型（`RepositoryToolExecutor.swift:130-165`，`add` 在 L159） | **必须确认** |

**不注册**：`addExpiry` / `update` / `delete` 明确不注册（`ToolCatalog.swift:5-8` 注释：V3.4+ 再议，且需更高级确认）。Android 迁移时同样只实现这 5 个工具。

**执行入口行号**：
- `AI/Tools/ToolExecutor.swift` 内只有预览执行器：`PreviewToolExecutor.execute`（L29-32）恒返回 `.previewNotPersisted`（L15），**绝不落库**。`ToolExecuting` 协议定义 L24-26。
- 真实执行器 `RepositoryToolExecutor.execute`（`Integration/RepositoryToolExecutor.swift:23`）；幂等预检 L25-31（toolCallID + fingerprint，只认 `executed` 状态）；四个分发 `executeRevenue` L78 / `executeTodo` L99 / `executeMemo` L116 / `executeDelivery` L130。
- 参数校验：`ToolArgumentValidator.validate`（`AI/Tools/ToolExecutor.swift:38-72`）；幂等指纹：`ToolIdempotency.fingerprint`（`AI/Tools/ToolIdempotency.swift:15-33`）；`newCallID`（L12，`call_<UUID>`，`AIDTO.swift:168`）。

### 1.2 ToolExecutor 与 RepositoryToolExecutor 分工

- `ToolExecutor`（`AI/Tools/ToolExecutor.swift`，AI 目录内）——协议/调度概念层：定义 `ToolExecuting` 协议与写闸门（preview/live），不接触 ModelContext。
- `RepositoryToolExecutor`（`Integration/RepositoryToolExecutor.swift:11-179`）——**唯一允许写业务库的真实执行器**：实现 `ToolExecuting.execute(_:)`（L23）；执行前**双重幂等预检**——toolCallID 与业务指纹 `ToolIdempotency.fingerprint`，只认 executed 状态（L24-32）；`ToolArgumentValidator` 防御性校验（L35）；分发到既有 `PerformanceRepository`/`TodoRepository`/`MemoRepository`/`CustomerRepository`（L88/105/121/140），不写第二套保存逻辑；成功后 `journal.markExecuted` 推进账本（L48-54）；`searchRecords` 到达此层直接 `.failed("查询类操作不经过写库执行器")`（L71-72，只支持 4 个 CREATE）。

### 1.3 确认流程（PendingActionStore → ActionCardView）

1. `AgentCore.handleToolCall`（`AgentCore.swift:508`）：注册检查 → 参数校验 → `journal.isFingerprintUsed` 防重（L546-551）→ 生成 `ActionProposal`（`isPreviewOnly = (gate == .preview)`，L553）→ `pending.upsert`（L554，落盘 `pending-actions.json`）→ `journal.append` pending 条目（L555-557）→ 助手消息挂 `proposalID`（ActionCard 渲染）。
2. 用户点「确认记录」→ `AgentCore.confirm(proposalID:)`（`AgentCore.swift:575`）：preview 门 → 只置 `previewAcknowledged`（L581-585，不写库）；live 门 → 状态 `confirmed` → `toolExecutor.execute`（L592）→ 按结果置 `executed`/`duplicate`/`failed` 并 `journal.markExecuted`（L593-607）。
3. 用户点删除 → `cancel`（L616，状态 `cancelled`）；点「修改」→ `modify`（L623）取消旧卡并回填上一条用户原文。
4. `PendingActionStore` 协议（`AI/Conversation/PendingActionStore.swift:10-19`）；文件实现 `FilePendingActionStore`（L22-76），落盘 `Application Support/AI/pending-actions.json`（L40），损坏隔离重命名（L48-52），原子写入。
5. UI 路径（经 `AIConversationViewModel` L145-171）：`confirm(id)`（L145-151）→ `agent.confirm` → status `.executed` 触发 `Haptic.success()`（L149）；`cancelCard(id)`（L154-159）→ `agent.cancel` → proposal 移除 → `refresh()`；`modifyCard(id)`（L162-170）→ `agent.modify` 返回原文填回输入框（L166），proposal 移除，用户改写后重发。

ActionCardView UI（`AI/UI/ActionCardView.swift`，174 行）：`V32FieldGroup` 卡片（L16）；header = 图标泡（按工具取 SF Symbol：recordRevenue `yensign.circle.fill` 等，L139-147）+ 标题 + 状态副标题（L28-44）；`fields` 逐行 label/value（L48-68，`arguments.fieldRows`）；预览模式琥珀色横幅「预览版：点击确认也不会真实保存」（L75-86）；result 行（L89-97）；底部按钮区（L100-116）：主按钮确认 + 「修改」「不记录」；iOS 26+ 玻璃拟态按钮区（L154-165）。状态→文案（L119-137）：pending→"待你确认"（预览"Foundation 预览·不写库"）/confirmed→"正在保存…"/executed→"已保存"/duplicate→"重复，已跳过"/failed→"失败，可重试"/cancelled→"已取消"；按钮标题 pending/failed 时可点（L100，已决则禁用置灰）。

### 1.4 IntentRouter 意图分类清单与路由规则（`AI/Core/IntentRouter.swift`）

**7 个 intent case**（L13-25）：

| case | 含义 |
|---|---|
| `localZeroToken` | 本地可直接处理（Lite 预留） |
| `businessAction(ToolName)` | 经营写动作（CREATE，必须确认） |
| `businessQuery(BusinessRecordKind)` | 经营读问答（READ，隐私裁剪） |
| `worldChat` | 普通聊天 / 世界知识（不带经营数据） |
| `weatherQuery` | 实时外部信息查询（天气；本版无天气工具，本地明确告知） |
| `goodsQuery(String)` | 店内商品 READ，不生成 ActionCard |
| `businessInsight(BusinessInsightKind)` | 店铺经营分析（除 `advice` 外均本地 0-token 回答） |

`BusinessInsightKind`（`AI/Context/BusinessContextProvider.swift:77-84`）：`overview` / `comparison` / `sevenDayTrend` / `inventory` / `advice` / `period(BusinessPeriod)`。

**`classify` 路由顺序**（L56-93，纯规则、0 Token）：
1. **天气优先**（L62）：`isWeatherQuery` 命中天气词且无 CREATE 词 → `weatherQuery`。如「明天恩平什么天气啊，帮我查下」→ READ，不是「明天+新建待办」。
2. **经营分析**（L64）：`classifyBusinessInsight`（L210）→ `businessInsight`（周期词+生意词、今天vs昨天比较、`结合…建议`→`advice`、`库存+风险词`→`inventory`、`7天/趋势`→`sevenDayTrend` 等）。
3. **商品查询**（L66）：`isGoodsQuery`（L174，排除「什么是/怎么计算」等解释类，命中「多少钱/进价/售价/库存/毛利/有没有/还有多少」且不含天气/配送/待办/临期等词）。
4. **经营读问答优先**（L69）：`classifyQuery`（L185）——问句先判，避免「今天还有几单配送」被当成新建配送。映射：营业额/卖了/收入/营收→`revenueToday`；配送/送货/送水/几单→`delivery`；临期/过期/到期/保质期/退货→`expiringGoods`；待办/事项/要做/任务→`todoToday`；备忘/记过/笔记→`recentMemo`。是问句但非经营实体→`worldChat`，且此时**绝不落入 CREATE**（P0-1/P0-4 防线）。
5. **记账**（L74）：`revenueKeywords`（L35-38）命中且（有金额 `hasAmount` L106，支持中文数字 `ChineseNumber`）或有收款动作词 → `businessAction(.recordRevenue)`。只有来源词无金额（如「美团怎么开店」）不算记账。
6. **配送**（L80）：`isDelivery`（L119）——含「送」语义且找到房号（`roomRegex` L28，2~5 位数字）、街道地址（`streetAddressRegex` L113-116，如「送到幸福路9号」）、或「给阿东送」人名模式。
7. **备忘先于待办**（L85）：`memoKeywords`（L41：「记一下/记录一下/备忘/备注/供应商/记一笔」）→ `createMemo`。
8. **待办**（L90）：`isTodo`（L142）——动作词（记得/提醒/进货/补货/联系…）或未来时间词（纯时间词「明天下午3点」单独出现不算）。
9. **兜底**（L92）：`worldChat`。

### 1.5 ExecutionJournal / ToolIdempotency 机制

- **去重双键**（`AI/Tools/ToolIdempotency.swift`）：`toolCallID`（每次 `ToolCall` 生成即固定 `call_<UUID>`，L12，重试复用同一 ID）+ **业务指纹** `fingerprint(for:)`（L15-33）：
  - 营业额：`rev|<金额2位>|<日期yyyyMMdd>|<来源>|<备注>`
  - 待办：`todo|<标题>|<到期分钟yyyyMMddHHmm>|<优先级>`
  - 备忘：`memo|<标题>`
  - 配送：`del|<客户>|<房号地址>|<分钟>|<商品名>|<数量>|<金额>`
  - 查询类：`search|<kinds排序>|<query>`（仅日志去重，不产生写入）
- **重试**：失败（`failed`）不丢 ActionCard，可重试；`confirm` 中 `.failed(reason)` 回写 `resultText`（`AgentCore.swift:604-606`）；`pending()` 同时返回 `pending` 和 `failed` 状态卡（`PendingActionStore.swift:26-30`）。
- **审计日志落盘**：`Application Support/AI/execution-journal.json`（`FileExecutionJournal`，`ExecutionJournal.swift:62`；目录 `AIStorage.directory()` L112-122）。`JournalEntry`（L9-17）：`toolCallID` / `fingerprint` / `toolName` / `status`（pending/executed/failed/duplicate/cancelled）/ `recordID?` / `createdAt`。`markExecuted` 为 upsert（L48-55，替换 pending / 追加），保证崩溃恢复可查到 `executed`。文件损坏时隔离重命名为 `*.corrupt-<timestamp>` 并以空账本启动，绝不崩溃（L79-87）；写入 `.atomic`（L106-109）。
- 校验顺序（真实路径）：权限（`ToolCatalog.isRegistered` L24-26）→ 参数（`ToolArgumentValidator` L38）→ 幂等（journal，`RepositoryToolExecutor.swift:25-31`）→ Repository 写入 → journal `markExecuted`。
- Android 迁移映射：指纹规则与 journal 落盘语义需 1:1 实现（Room 表或 JSON 文件），确认卡的 pending/executed/duplicate/failed/cancelled 五态保留。

### 1.6 AgentCore 对话循环（`AI/Core/AgentCore.swift`）

- **入口**：`@MainActor final class AgentCore`（L183），依赖经 `AgentEnvironment` 注入（L39-120）。`send(_:)`（L191）：trim → **用户原文先持久化**（L196，失败不丢话）→ `runTurn`（L260）→ 异常统一 fail-closed 映射（L199-219，`AgentError` / `UserFacingAIError` 转中文，不暴露原始错误）。
- **流式输出：无。** 本分支没有 `AsyncStream` / SSE 实现；`remoteTurn`（L450）是单次 `await env.provider.complete(request)` 返回 `ProviderTurn.text` 或 `ProviderTurn.toolCall`（L495-506），一次整段返回。多轮纠正时把最后一条用户消息替换为剥掉纠正话术的 `workingText`（L473-482），原文保留在本地会话。
- **多轮上下文管理**：`ConversationStore`（`AI/Conversation/ConversationStore.swift`），`FileConversationStore` 落盘 `Application Support/AI/conversation.json`（L67），`append` 即持久化（L77-83），`clearConversation` 清空消息+待确认卡但**刻意不清 ExecutionJournal**（`AgentCore.swift:562-565`）。会话为单会话精简版（无 50 篇/30 天/全文索引，L1-6 注释）。
- **system prompt 组装位置**：在 Providers 适配层 `OpenAICompatProvider.systemPrompt`（L238-247）：6 条规则（一次至多一个工具、缺失信息追问不编造、禁止未注册工具/删改、searchRecords 只查 5 类、时间词不等于建待办、天气走本地能力）。
- **对话编排骨架**（`runTurn` L260 → `handleIntent` L361）：
  - P0-6：客户订单「未收款」语义（`CustomerPaymentIntent.isUnpaidCustomerOrder`，`CorrectionParser.swift:203`）→ 只告知、**不降级为 Todo/Memo、不写库**（`AgentCore.swift:263-267`）。
  - Capability 通道（L268-291）：仅当无 pending 卡时；`AICapabilityRouter.request`（L6）→ urlReading / webSearch 执行，**不带经营上下文、不给 ToolExecuting/SwiftData**。
  - 单 pending 卡字段修正（L293-320）：`PendingFieldCorrectionParser.parse`（`CorrectionParser.swift:131`）支持取消（「不要了」等）、金额/来源改值、待办时间改期、歧义追问；只改参数不重新解析。
  - 多轮纠正（L322-354）：`CorrectionParser.detect`（L39，句首强信号「不是/不对/改成/没有…」）→ 旧 pending 全部 `cancelled` → 剥话术 → 重分类（可被点名目标工具覆盖）。
  - `businessAction`：先走 **Free First 本地解析** `LocalBusinessParser`（`AgentCore.swift:186,373-383`，0 Token 出卡/追问），无把握才 `remoteTurn` 上云；上云时 `context` 恒空（Lite 不把经营数据随云端 CREATE/聊天外发，L444-446 注释）。
  - `businessQuery`：全部本地聚合回答（L386-397，preview 门下为固定说明）；`weatherQuery` 无 weatherService 时固定告知（L399-401）；`goodsQuery` 本地 `GoodsLookupSkill`；`businessInsight` 除 `advice` 本地模板回答外，`advice` 经脱敏 `GroundingPack` 上云（L428-442）。

### 1.7 Capabilities（每个能力与触发条件）

`AICapability` 枚举（`AI/Capabilities/AICapability.swift:17-23`）：`generalAssistant` / `webSearch` / `urlReading` / `vision` / `documentUnderstanding`。Foundation 注册表（L95-101）：普通问答 live、**联网搜索 notConfigured**、网页阅读 live、图片理解 foundationOnly、文件理解 foundationOnly。

| 能力 | 触发条件 | 实现 |
|---|---|---|
| VisionCapability（`VisionCapability.swift:31-57`） | `analyzeImage`（`AgentCore.swift:226`）；校验图片非空 + `mimeType` 以 `image/` 开头；默认 `UnconfiguredVisionProvider` 抛 `notConfigured` | `OpenAICompatibleVisionProvider`（`LiveCapabilityProviders.swift:140-147`）：OpenAI 兼容 `chat/completions`，图片以 `data:<mime>;base64,…` 内联 `image_url` 发送，`temperature: 0.2` |
| DocumentCapability（`DocumentCapability.swift:32-61`） | `analyzeDocument`（`AgentCore.swift:243`）；校验数据+文件名非空 | `OpenAICompatibleDocumentProvider`（`LiveCapabilityProviders.swift:159-166`）：先 `LocalDocumentTextExtractor.extract`（L220-233）本地抽文本——PDF 用 **PDFKit** `PDFDocument(data:).string`，其他按 UTF-8 文本——再以纯文本 prompt 调 `chat/completions` |
| URLReadingCapability（`URLReadingCapability.swift:25-48`） | `AICapabilityRouter.firstURL`（`AICapabilityRouter.swift:17`，`NSDataDetector` 链接检测，仅 http/https） | `URLSession.shared` GET（`FoundationURLFetcher` L11-17，User-Agent `你的小掌柜/3.6`，超时 15s），接受 200..<400；`HTMLTextExtractor`（L52-89）去 script/style/noscript/标签+解 HTML 实体，正文截前 1800 字；结果附来源链接 Markdown |
| WebSearchCapability（`WebSearchCapability.swift:215-241`） | `looksLikeWebSearch`（`AICapabilityRouter.swift:27-49`，「搜索一下/网上查/最新消息/新闻/实时…」等词，但含经营词或天气词时排除） | 三档 provider（`LiveCapabilityProviders.swift`）：`TavilyWebSearchProvider`（L5-71，POST `https://api.tavily.com/search`，`api_key`+`query`，`search_depth: basic`，`include_answer: true`，`max_results: 5`）；`JSONWebSearchProvider`（L93-140，通用 `{answer, results[{title,content,sourceURL}]}` POST Bearer 代理适配器）；`FreeFirstWebSearchProvider`（L142-179，只用用户明确勾选「免费优先可用」的候选，自动故障转移）。装配点 `WebSearchProviderFactory.makeCapability(settings:)`（L87-100），由 `AISettings.searchProviderSelection`（默认 `disabled`）决定 |

共同约束：四个外部能力均为**只读**，不产生 ActionCard（`AgentCore.swift:220-225` 注释）；图片/文件字节不进 SwiftData、不进聊天存储，只追加占位文本。

### 1.8 BusinessAssistantEngine 与新 AI 引擎的关系

**共存，但职责完全分离；当前聊天页真正用的引擎是 `AgentCore`。**

- `BusinessAssistantEngine`（`Features/Assistant/BusinessAssistantEngine.swift`）：旧的**本地纯规则、只读**引擎。输入为不可变快照 `BusinessAssistantInput`（L3-110，从 `Performance/Expense/Todo/Memo/CustomerRequest/ExpiryItem` 六个 SwiftData 模型映射），`LocalBusinessAssistantProvider`（L160）经 `LocalDailyBusinessSummaryEngine`（L181，今日营业额/待办/配送/临期/备忘，最多 4 句）+ `LocalBusinessInsightEngine`（L243，逾期/重要待办/配送超时/临期/营收缺口/天气提醒，按优先级排序去重）产出首页用的每日摘要与洞察。它**不处理对话、不写库、不产 ActionCard**。仍在被新链路复用：`RepositoryBusinessContextReader.swift:89` 用它生成 `localSummary` 喂给 AI 的 `GroundingPack`。
- 新 AI 引擎 `AgentCore`（V3.3 Lite）：聊天页对话编排（意图→工具→确认卡）。`AIConversationViewModel.swift:30` 默认装配 `AgentCore(.foundationPreview())`（全 Mock 预览）；正式装配 `AIAssembly.makeLiveAgent` → `AgentCore(env)`（`Integration/AIAssembly.swift:18,74`，`makeLive` 拒绝 Mock/Preview 执行器混入，fail-closed），由 UI `aiAttachLive`（L114）切换。
- 结论：`BusinessAssistantEngine` 未被废弃，退化为「首页经营摘要的本地计算模块」；聊天页（`AIChatView`）的对话引擎是 `AgentCore`。两者无继承/委托关系。Android 迁移时两者都要实现：前者对应首页摘要 ViewModel 的本地计算，后者对应聊天页 Agent。

### 1.9 BusinessPeriodParser 自然语言时间解析规则（`AI/Context/BusinessPeriodParser.swift:10-29`）

先去空格再按顺序匹配（`bounds` 在 L30-57）：
1. 「三个月和这个月对比」/「3个月…本月…对比」→ `lastThreeMonthsComparedWithThisMonth`（三条件必须同时含「对比」）
2. 「这个月和上个月对比」/「本月…上月…对比」→ `thisMonthComparedWithLastMonth`
3. 「近半年」/「最近6个月」/「近6个月」→ `lastSixMonths`
4. 「最近3个月」/「近三个月」/「三个月」→ `lastThreeMonths`
5. 「上个月」/「上月」→ `lastMonth`
6. 「这个月」/「本月」→ `thisMonth`
7. 「最近7天」/「最近七天」/「最近一周」/「近一周」/「过去一周」/「这一周」/「本周」→ `lastSevenDays`（区间为今起倒推 6 天，共 7 天含今天，L44-46）
8. 「昨天」→ `yesterday`；「今天」→ `today`
9. 顺序敏感：对比类 > 半年 > 3个月 > 上月 > 本月 > 7天 > 昨天 > 今天；无命中返回 `nil`。

注意：`lastThreeMonths`/`lastThreeMonthsComparedWithThisMonth` 的 `bounds` 取「今天往前推 3 个月到今天」（L50-52），是滚动窗口而非自然月对齐。

---

## 二、AI 配置项（provider / baseURL / 模型 / Key 存储位置）

### 2.1 AISettings 全部可配字段（`AI/Core/AISettings.swift`）

UserDefaults 键（`private enum Keys`，L241-259）+ 4 个 Keychain 键：

| 字段 | 类型 | UserDefaults/Keychain 键 | 说明 |
|---|---|---|---|
| `tier` | `ModelTier` | `ai_model_tier` | 免费优先/自动/高质量三档，UI 最多只暴露这三项（L86-97） |
| `primaryKind` | String | `ai_primary_kind` | 主 Provider 类型标识，默认 `deepseek`（L77, L100） |
| `primaryBaseURL` | String | `ai_primary_base_url` | 用户自定义端点；留空→`resolvedPrimaryBaseURL` 回退 `https://api.deepseek.com`（L108, L177-181） |
| `primaryModel` | String | `ai_primary_model` | 只能是 `DeepSeekModel` 合法 ID（`deepseek-flash`/`deepseek-v4-pro`），初始化时旧值自动迁移到 flash（L113, L187-190, L236-246） |
| `fallbackKind/BaseURL/Model` | String | `ai_fallback_*` | 自定义 OpenAI 兼容端点（高级/自定义 Provider），三项全填才启用，否则禁用 fail-closed（L104-117, L214-222） |
| `primaryAPIKey/fallbackAPIKey` | String | Keychain `ai.primary.apiKey` / `ai.fallback.apiKey`（L249-250） | 只存 Keychain，绝不进 UserDefaults（L129-136） |
| `searchProviderSelection` | `SearchProviderSelection` | `ai_search_provider_selection` | disabled/automaticFreeFirst/tavily/customJSON（L138, L50-68） |
| `tavilySearchBaseURL` | String | `ai_search_tavily_base_url` | 默认 `https://api.tavily.com/search`（L141） |
| `customSearchBaseURL` | String | `ai_search_custom_json_base_url` | 如百炼/自建 Proxy（L144） |
| `tavilySearchFreeFirstEnabled` / `customSearchFreeFirstEnabled` | Bool | `ai_search_tavily_free_first_enabled` / `ai_search_custom_free_first_enabled` | 自动模式需用户显式勾选才允许使用（L150-155） |
| `tavilySearchAPIKey` / `customSearchAPIKey` | String | Keychain `ai.search.tavily.apiKey` / `ai.search.customJSON.apiKey`（L256-257） | 只存 Keychain（L157-165） |

**无 temperature / maxTokens / 超时秒数 / 流式开关字段**：`temperature: 0.2` 是 `OpenAICompatProvider.makeRequest`（L121-127）硬编码，`maxTokens: nil, topP: nil`；无 UI 暴露的温度/超时/流式配置项。Android 迁移时在设置页复刻相同字段（tier 三档、主/备 baseURL+模型+Key、搜索 provider 四档），Key 进 Android Keystore/EncryptedSharedPreferences。

### 2.2 AIProvider 协议（`AI/Providers/AIProvider.swift:51-55`）

```swift
protocol AIProvider: Sendable {
    var id: String { get }                                   // "mock-primary" / "primary-deepseek" / "chain" 等
    func complete(_ request: ProviderRequest) async throws -> ProviderTurn  // 单轮非流式
}
```

辅助类型：`ProviderTurn` = `.text(String)` | `.toolCall(ToolCall)`（L44-47，每轮至多一个工具调用）；`ProviderRequest` 含 messages/tools/route/context（L22-41）；`ProviderFailure` 七种错误 + `allowsFailover`（L57-81）。

### 2.3 OpenAICompatProvider（`AI/Providers/OpenAICompatProvider.swift`）

- **endpoint 格式**：LLMProviderKit 自动拼 `chat/completions`（注释 L75）；正式构造 `init(id:baseURL:apiKey:model:)`（L28-37），裸域 `https://api.deepseek.com`，请求头由 `LLMProviderConfiguration(name:baseURL:apiKey:defaultModel:)` 注入 Bearer（L32-36）。
- **SSE 流式解析：本分支没有**。`complete`（L48-64）经 `XZGChatCompleting.complete(LLMRequest) -> LLMResponse` 单次补全；`makeRequest`（L96-127）是纯请求构造，`mapResponse`（L143-151）取 `response.toolCalls.first` 或 `response.text`，空文本抛 `.decoding`。`LLMError.streamingError` 只被映射为 `.decoding`（L213）。无 SSE 解析代码。**Android 迁移同样用单次请求（OkHttp/Retrofit POST chat/completions），无需 SSE。**
- **tool calling**：`decodeToolCall`（L154-195）校验 `ToolName(rawValue:)` 在 `ToolCatalog` 注册，`JSONDecoder.aiTools` 解码 5 工具参数（日期兼容带/不带毫秒 ISO8601，L283-303）；searchRecords 的 `kinds` 缺省容错（L198-201）。`ToolCall` id 固定为 `"call_\(tc.id)"` 作为幂等第一键（L192）。

### 2.4 ModelRouter 路由规则（`AI/Core/ModelRouter.swift`）

`FreeFirstModelRouter.route(task:intent:tier:)`（L61-75）：
- `intentClassify` → `providerID:"local"`, `isLocalZeroToken:true`（L65-66）
- `toolCall` → `providerID:"primary"`, tier `.auto`（L67-68）
- 用户选 `.highQuality` → `providerID:"fallback"`（L70-72）
- 其余（chat/simpleExtraction/businessAnswer）→ `providerID:"primary"`, tier `.freeFirst`（L73-74）

### 2.5 ProviderChain fallback 顺序（`AI/Providers/ProviderChain.swift:21-34`）

`primary → fallback` **只允许跳 1 次**，不链式轮询；仅 `ProviderFailure.allowsFailover` 为真才跳（网络/offline/超时/5xx/429；401/403 鉴权错误不换链，`AIProvider.swift:71-81`）。fallback 的 route 被改写为 `providerID:"fallback"`。AgentError/CancellationError 不换链。

### 2.6 API Key 存储位置与机制（Keychain）

**Keychain，绝非 UserDefaults**：
- `AIProviderCredentialStore.swift:16-22`：`KeychainAIProviderCredentials.primaryAPIKey()` = `AIKeychain.read("ai.primary.apiKey")`，fallback 同理；`AIProviderCredentialStoring` 协议（L9-12）把「取 Key」抽象出来，测试用内存实现。
- Keychain 封装 `AIKeychain`（`AI/Core/AISettings.swift:360-394`）：`write`（L361：先 `SecItemDelete` 再 `SecItemAdd`，`kSecAttrAccessibleAfterFirstUnlock`，空值只删不写）、`read`（L375：`SecItemCopyMatching`）、`delete`（L388）。类 `kSecClassGenericPassword`，account 即 key 名。
- 设置页 `AIProviderSettingsSheet.swift` 的 `AISettingsDraft`（`AISettings.swift:263-357`）：打开即复制、保存才 `commit` 落盘（trim 后一次性写入，L316-356）；API Key 仍只进 Keychain，「新粘贴非空才覆盖、勾清除才删除」（L330-356）；输入框不回显已存 Key（L277-292 注释）。
- Android 等价：**Android Keystore + EncryptedSharedPreferences**（androidx.security:security-crypto），或 Credential Manager；绝不存普通 SharedPreferences/DataStore 明文。

### 2.7 ProviderConnectionTester 连通性测试（`AI/Providers/ProviderConnectionTester.swift`）

- 状态机 `ProviderConnectionStatus`（L10-32）：`notConfigured`（无 Key）/ `unverified`（Key 已存未验证）/ `testing` / `success` / `failure(String)`；文案 `text`（L25-32）。
- `test(_:model:)`（L61-85）：对真实端点发一次**最小 chat 请求**——`messages:[.user("ping")]`，**不带 tools、不带经营数据**（L63-68）；非空文本 → `.success`，空文本 → 失败，意外 toolCall → "服务响应异常"；错误经 `UserFacingAIError.message` 转中文，不上抛（L84）。
- `synchronize(hasEffectiveKey:)`（L46-51）：只同步初始态，不覆盖进行中/已成功测试。
- 设置页连接逻辑（`AIProviderSettingsSheet.swift`）：`testConnection()`（L398-417）用 draft 的 baseURL/Key/模型经 `XZGAIProviderAdapter.makePrimary(baseURL:apiKey:model:)` 构造后测试（草稿未保存也能验证）；`connectionPillStatus`（L377-387）——只有 `.success` 显示绿色（`V32Status.delivering`），testing/unverified 中性灰，失败/未配置琥珀色。注释明确「只有真实测试成功才允许绿色」。Android 设置页复刻此状态胶囊语义。

### 2.8 LLMProviderKit 引用情况

**有引用，但高度隔离**：
- 唯一 `import` 点：`AI/Providers/OpenAICompatProvider.swift:2-3`：`import LLMProviderKit`、`import LLMProviderKitOpenAI`。文件头注释（L7-9）明示「全工程唯一允许 import 的业务文件，第三方类型不得出现在本文件之外」。
- 注释提及（非代码）：`AI/Core/AISettings.swift:75`（"LLMProviderKit 自动拼 chat/completions"）、`AI/Providers/AIProvider.swift:5`（"第三方库（LLMProviderKit 等）一律经 XZGAIProviderAdapter 适配"）、`AI/Providers/XZGAIProviderAdapter.swift:6-8`（F0 Spike 结论：MIT、零依赖、iOS16+、SPM 精确锁版，只链接 core/OpenAI）。
- **Package 依赖声明：无法验证**——审计快照中**不存在 Package.swift / Package.resolved**（`find` maxdepth 3 无结果）。只能确认代码层面的 import，用到的 API：`LLMProviderConfiguration(name:baseURL:apiKey:defaultModel:)`（L32-36）、`OpenAIProvider(configuration:)`（L32）+ `extension OpenAIProvider: XZGChatCompleting`（L18）、`LLMRequest(model:messages:temperature:maxTokens:topP:tools:)`（L121-127）、`LLMMessage.system/.user/.assistant`（L97, L131-140）、`LLMToolDefinition(name:description:parameters:)`（L114-118）、`LLMResponse.text` / `LLMResponse.toolCalls`（L144-150）、`LLMToolCall.name` / `.arguments` / `.id`（L154-195）、`LLMError.httpError/.networkError/.invalidResponse/.streamingError/.invalidRequest/.providerError/.unsupportedOperation/.unknownProvider`（L198-220，全部映射为工程内 `ProviderFailure`）。
- Android 迁移：无 LLMProviderKit 等价库，直接用 OkHttp/Retrofit 手写 OpenAI-compatible `chat/completions` 客户端（含 tool_calls 解码），隔离在单一 `OpenAiCompatProvider` 类中，遵循同样的「第三方类型不出该文件」边界。

### 2.9 Mock / 本地解析：无网络/无 Key 时行为

- `MockAIProvider`（`AI/Providers/MockAIProvider.swift:14-55`）：确定性、无网络、无 Key、不写库；`id` 默认 `"mock-primary"`；可注入 `failure`/`latency` 做故障演练。普通聊天返回明确标注「（预览版内置回复）」的 canned 文案（L52-54），不伪装联网 AI。注释（L18-20）：**仅允许 DEBUG/预览/测试/Foundation 预览装配；Release 的 live 环境禁止回落到本类**（`AgentEnvironment.live` 与 `ProductionGuardTests` 约束）。
- `MockBusinessParser`（`AI/Providers/MockBusinessParser.swift:9-23`）：仅是 `LocalBusinessParser` 的适配包装；businessAction 委托同一套规则；businessQuery 返回固定澄清文案（L19）："预览版还没有接入你的经营数据……"。
- `LocalBusinessParser`（`AI/Providers/LocalBusinessParser.swift`）：Free First 0-Token 本地层。`parse`（L49-66）**只处理 `businessAction`**（recordRevenue/createTodo/createMemo/createDelivery），其余意图返回 nil → 才允许上云。**无 Key 时本地 CREATE 照常工作**（文件头注释）——Android 迁移时离线本地解析必须同样可用。

**离线本地意图解析规则（摘 8 示例）**：
1. 「今天美团680」→ `parseRevenue`（L68-79）：`AmountPhraseParser` 抽金额；来源命中 `revenueSources` 14 个渠道词（美团/饿了么/抖音/…/拼多多，L10-13）；缺金额 → `.clarify("记营业额需要金额，例如「今天美团680」。")`（L77）。
2. 「明天下两箱可乐」→ `parseTodo`（L84-131）：先归一化「今晚→今天晚上」；「明天3点」这类裸数字点 → `ambiguousClock` 追问「凌晨3点还是下午3点」，绝不静默回落当前时间（L97-102，P0-3）；标题剥掉时间原文与功能词（L109-124）；空标题 → `.clarify("待办内容是什么？例如「明天下两箱可乐」。")`（L125）。
3. 「帮我记一下供应商周五来」→ `parseMemo`（L134-146）：剥 9 种前缀（"帮我记一下/帮我记录一下/记录一下/记一下/记一笔/备忘/备注/帮我记/记个"，L137-138），标题截 20 字；空 → `.clarify("备忘内容是什么？例如「记一下供应商周五来」。")`（L140）。
4. 「今晚8点给302送两箱怡宝」→ `parseDelivery`（L149-199）：配送时间同样不允许歧义回落（L156-163，P0-2）。
5. 手机号：正则 `1\d{10}`（L18）；金额：`(?:一共|共|合计)?\s*(\d+(?:\.\d+)?)\s*(?:元|块|块钱)`，注释明示只认真钱、不把「8点」「3杯」「9号」当金额（L22-23）。
6. 房号严格区分：`给(\d{2,5})送`（L25）vs `送到302室/送至12栋`（L27-28）vs 街道地址经 `router.streetAddress`；纯数字房号历史行为同时作客户标识（L172-181）。
7. 中文人名：`给阿东送` → namedCustomer 正则（L30-31）；customer 只接受明确人名，无名留空（L176）。
8. 商品：`百年糊涂×2 / 王老吉 x3` 式 crossItem（L36-37）；`3杯/两箱/12瓶` itemWithUnit（L33-34，「杯」为 P0-2 真机词）；只在「送」之后正文抽取防误抓（L209-217）。缺地址和商品 → `.clarify("配送需要地址或商品，例如「今晚8点送3杯珍珠奶茶到幸福路9号，一共45元」。")`（L194）。

### 2.10 AIChatView 页面结构（`AI/UI/AIChatView.swift`，314 行）

```
ZStack(alignment:.bottom)                                   // L27
├─ VStack
│  └─ ScrollViewReader → ScrollView                         // L29-30
│     └─ VStack(spacing:12)
│        ├─ 头部说明区：Text"说句话，帮你记账、派单、备忘"      // L33-35
│        │  + V32StatusPill("Key 已保存"/"未配置")             // L39-41
│        │  + DemoMode "演示模式"提示                         // L42-48
│        ├─ emptyState（messages 为空）：V32EmptyState + 4 个范例按钮 // L178-210
│        │   （"今天美团680"/"明天下两箱可乐"/"记一下供应商周五来"/"今晚8点给302送两箱怡宝"，L19-24；点击直接 model.send(example)）
│        └─ ForEach(messages) → messageRow                  // L58-60
│           └─ messageRow（L212-231）
│              ├─ bubble（L233）：用户=右对齐品牌色圆角气泡(maxWidth 300)；助手=左对齐卡片(maxWidth 320)+Markdown渲染+错误态"重试"按钮（L240-254）
│              └─ ActionCardView（若 message.proposalID 有对应 proposal，L219-230）
│           └─ TypingIndicator（isProcessing 时，L62-65）
├─ .safeAreaInset(bottom): ChatInputBar                     // L83-92
├─ if showVoicePanel: voiceOverlay                         // L96-98 → L291-308
│  └─ 黑色遮罩（点击=取消）+ ShortVoicePanel
├─ .navigationTitle("小掌柜") .inline                       // L93-94
├─ .toolbar(showVoicePanel ? .hidden : .visible, for: .tabBar) // L102（语音时隐藏底部 Dock）
├─ .toolbar: 右上 Menu（新对话/清空当前对话/AI 设置）         // L103-122
├─ .sheet: AIProviderSettingsSheet                         // L136-138
├─ .photosPicker（图片→analyzeImage）                       // L139-149
├─ .fileImporter（PDF/文本/Markdown→analyzeDocument）       // L150-160
├─ .alert("清空此对话？"只删记录不删已保存数据)               // L161-167
└─ .aiAttachLive { model.attach(live:) }                   // L133-135（Integration 层注入 live Agent）
   + onChange(voiceDeepLink) → model.startVoice()          // L125-129（xzg://ai?mode=voice 深链）
```

ChatInputBar 全部交互（`AI/UI/ChatInputBar.swift`，108 行）：
- 左侧 `+` Menu（L20-27）：「选择图片」(onPhoto) / 「选择文件」(onFile)；处理中禁用（L29）
- 麦克风按钮（L32-41）：onVoice → `model.startVoice()`；`voiceAvailable` 为 false 时置灰禁用（L40）
- TextField（L43-65）：占位「问小掌柜…（如：今天美团680）」，多行 1-4 行，`onSubmit` 发送，键盘工具栏「完成」收键盘；`accessibilityIdentifier("ai.input")`
- 发送按钮（L67-79）：`canSend` = 非空且非处理中（L87-89）；`sendAndDismiss` 先 onSend 再收键盘（L91-94）；`accessibilityIdentifier("ai.send")`
- **无快捷 chips**：ChatInputBar 本身没有 chips；快捷入口是空态的 4 个范例句子按钮（AIChatView L178-210）。

### 2.11 短语音模式（ShortVoicePanel × ShortVoiceSession）

- 入口：`AIConversationViewModel.startVoice()`（L175-180）→ `showVoicePanel=true`，`voice.start(onFinal:)` 回调 `handleVoiceFinal` → `voice.finish()` + 关面板 + `send(text)`（L203-207）。
- `ShortVoiceSession`（`AI/Voice/ShortVoiceSession.swift`，127 行）：复用 `SpeechService`（zh-CN），**3 秒静音自动收尾**（L7 注释）、单事项 5-15 秒短语音；状态 `idle/listening/finalizing/failed(String)`（L14-20）。`start`（L40）：先检查识别器初始化 → 请求麦克风/语音识别权限（L48）→ partial 实时更新 `liveTranscript`（L55-65）→ final 非空进 `finalizing` 并回调，**final 为空 → failed("没有听清，请再试一次")**（L68-76）；error 时保留 partial 原文到 `lastRawTranscript`（L82）。
- **录音时长限制**：ShortVoiceSession 本层无显式秒数上限，依赖 SpeechService 的 3 秒静音自动收尾；不做长语音/多段合并（L10）。
- **取消方式**：① 面板左「取消语音」按钮（xmark，ShortVoicePanel L78-86）② 全屏黑色遮罩点击（AIChatView L294-296 `onTapGesture { model.cancelVoice() }` → `voice.cancel()` 清空转写、phase=idle，ViewModel L186-190）③ 失败态「关闭」按钮（ShortVoicePanel L119）。
- **转写后行为**：成功 final → 与文字输入走完全相同 `AgentCore.send` 流程；失败 → 面板切 failureContent（L104-121）：显示原因 + "已保留：…" + 「填入文字」（`retainVoiceTranscriptToInput`，ViewModel L193-198：`consumeRetainedTranscript()` 取回原文填入输入框改写重发，不丢话）。
- Android 迁移：面板用 ModalBottomSheet/全屏遮罩复刻；取消三种方式保留；失败保留转写填回输入框。

### 2.12 流式输出的 UI 渲染（结论：无真流式）

**本分支没有真正的 token 流式渲染。**
- `AIConversationViewModel`（`AI/UI/AIConversationViewModel.swift`，215 行）状态机是**二元**的：`isProcessing: Bool`（L15）+ `processingLabel: String`（L16），没有 idle/thinking/streaming/toolCalling/error 细分状态。
- `send()`（L56-93）：设置 processingLabel（按意图分类：businessInsight→"正在读取店铺数据" L62 / goodsQuery→"正在查询商品" L64 / weatherQuery→"正在查询天气" L66 / 默认"正在思考" L68 / 图片"正在分析图片" L97 / 文件"正在分析文件" L108）→ `isProcessing=true` → `await agent.send(content)` **一次性等待** → `refresh()` 全量拉回 messages（L47-52、L209-214）→ `isProcessing=false`。**无 token 拼接代码**。
- UI 侧：`isProcessing` 为真时在列表底部显示 `TypingIndicator(label: processingLabel)`（AIChatView L62-65），三圆点克制动画（`TypingIndicator.swift:13-32`），仅此而已。
- 竞态保护：`generation` 计数器（L23）——清空对话后旧请求返回被丢弃并再次清空（L71-82）；`generation += 1` 在 `clearConversation`（L133）。
- Android 迁移：用 `StateFlow<Boolean> isProcessing` + `processingLabel` 复刻，无需 SSE 流式；但若未来接流式，需在此处加 token 拼接。

### 2.13 AIAssembly 依赖装配图（`Integration/AIAssembly.swift`，117 行）

```
AIAssembly.makeLiveAgent(context: ModelContext)  [L15]
├─ 存储：FileExecutionJournal / FilePendingActionStore / FileConversationStore（文件版，崩溃可恢复；UITest 用独立目录）[L18-21]
├─ Provider：
│  ├─ primary：isPrimaryConfigured ? XZGAIProviderAdapter.makePrimary(settings)   // OpenAICompatProvider(DeepSeek)
│  │           : UnconfiguredRemoteProvider()   // 明确抛 notConfigured，绝不回落 Mock [L24-31]
│  └─ fallback：isFallbackConfigured ? makeFallback : nil（禁用而非伪造）[L33-35]
├─ 能力：WebSearchProviderFactory.makeCapability [L37]；VisionCapability/DocumentCapability（有 Key 才配 OpenAICompatible*Provider，否则空能力）[L39-59]
├─ contextProvider: RepositoryBusinessContextReader(context)   // 读
├─ toolExecutor:  RepositoryToolExecutor(context, journal)     // 写
└─ AgentEnvironment.makeLive(provider:fallback:contextProvider:toolExecutor:conversation:pending:journal:tier:webSearchCapability:visionCapability:documentCapability:) → AgentCore [L61-77]
    → .aiAttachLive 修饰符 [L114-116] → AIChatView.onAppear / .aiProviderConfigChanged 通知时替换 ViewModel.agent [L85-111, AIChatView L133-135]
```

关键边界：`ModelContext` 只出现在 Integration 层；AI 目录内 View 不 import SwiftData（AIChatView L131-132 注释）；设置保存后发 `.aiProviderConfigChanged` 通知触发重装配（`AIProviderSettingsSheet` L419-422）。Android 迁移：Hilt/Dagger 模块复刻此装配图，Repository 只在 data 层。

### 2.14 Skills 三个技能的作用与触发

1. **GoodsLookupSkill**（`AI/Skills/GoodsLookupSkill.swift`，87 行）：本地商品查询。`lookup(_:in:)`（L8-33）：先 `matchesGoods` 轻量匹配（剥意图词后子串/前缀匹配，L37-43）；0 命中→notFound、>1→clarify（返回候选名让用户选）；唯一命中后按关键词分流：含"进价"→报进价（L17-20）、"售价/卖多少"（L23-25）、"库存/还有多少/有没有"（L21-22，附"库存偏低"提示）、"毛利/毛利率"（L26-29），无关键词→汇总售价/进价/毛利/毛利率（L31-32）。**不调用模型、不把完整 Goods 对象带出本地上下文**（L36 注释）。对应 `IntentKind.goodsQuery`。
2. **MetaReply**（`AI/Skills/MetaReply.swift`，10 行）：元问题固定回复。命中「你能做什么/有什么用/有啥用/还要AI干嘛/小掌柜能做什么」（L5）→ 返回能力介绍文案（L6），引导问天气/商品/营业额或说「今天美团680」。
3. **WeatherSkill**（`AI/Skills/WeatherSkill.swift`，33 行）：本地天气回答。`answer(for:forecast:now:)`（L5-26）：按"后天/明天"取 offset 0/1/2 的预报日；拼「城市+今天/明天/后天：天气，温度范围」+ 降雨概率；数据 stale 标注「数据可能不是最新」，降雨概率 ≥60% 追加「有配送的话，出发前留意路况」（经营场景化提示）。对应 `IntentKind.weatherQuery`，systemPrompt 规则 6 要求"天气查询由本地天气能力优先处理"（`OpenAICompatProvider.swift:244`）。

---

## 三、语音链路：Apple API 与 Android 等价方案

### 3.1 链路总览（录音 → 识别 → 解析 → 预览 → 写入）

```
VoiceView（sheet）→ onAppear → VoiceViewModel.beginListening()
  → SpeechService.requestPermissions()            # SFSpeechRecognizer.requestAuthorization + AVAudioApplication.requestRecordPermission
  → SpeechService.start(...)                      # AVAudioEngine 采集 → SFSpeechAudioBufferRecognitionRequest（部分结果回传 transcript）
  → 静音 3 秒自动结束（DispatchWorkItem）
  → VoiceViewModel.handleRecognized → VoiceParser.parse（VoiceModel.swift，注意：不是 QuickRecordParser）
  → phase=.preview → 用户确认（类型可手动覆盖）
  → VoiceViewModel.save() → Repository 真实写入
```

另有一条并行链路：`QuickRecordSheet` 内嵌的 `QuickRecordVoiceRecorder`（QuickRecordSheet.swift L365–441），走同一 `SpeechService`，识别后走 `QuickRecordParser`（非 `VoiceParser`）。

### 3.2 每一步的 Apple API 与 Android 等价方案

| 步骤 | iOS 实现（文件:行号） | Apple API | Android 等价方案 |
|---|---|---|---|
| 语音识别器初始化 | `Voice/SpeechService.swift:31` | `SFSpeechRecognizer(locale: zh-CN)`；模拟器可能为 nil，`canInitializeRecognizer` 探针（L35）做闸 | `android.speech.SpeechRecognizer`（需 Google App/语音服务；华为/小米等可用厂商 ASR）；或自建：MediaRecorder 录音 + 云端 ASR（讯飞/阿里/腾讯） |
| 音频采集 | `SpeechService.swift:27,89-92` | `AVAudioEngine` + inputNode `installTap(onBus:0, bufferSize:1024)` | `android.media.AudioRecord`（PCM 流式采集）或 `MediaRecorder`（文件录制后送 ASR） |
| 识别请求 | `SpeechService.swift:82-84` | `SFSpeechAudioBufferRecognitionRequest`，`shouldReportPartialResults=true`，`taskHint=.dictation` | SpeechRecognizer `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` + `EXTRA_PARTIAL_RESULTS=true`；云 ASR 用 WebSocket 流式接口 |
| 音频会话 | `SpeechService.swift:79-80,143,167` | `AVAudioSession.setCategory(.record, mode:.measurement, options:.duckOthers)`；结束时 `setActive(false)` | `AudioManager` 音频焦点（`AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE`）；`AudioAttributes.USAGE_VOICE_COMMUNICATION` |
| 离线识别 | **不支持**（全文件无 `requiresOnDeviceRecognition`，走服务器端） | — | Android SpeechRecognizer 同样依赖服务端（GmsCore）；如需离线可用 Vosk 等本地模型 |
| 静音自动结束 | `SpeechService.swift:147-157` | `DispatchWorkItem` 3 秒超时 → `stop()` 等 final 结果 | Kotlin 协程 `delay(3000)` + `Job.cancel()`；或 `CountDownTimer` |
| 权限 | `SpeechService.swift:52-61` | `SFSpeechRecognizer.requestAuthorization`（withCheckedContinuation 桥接）→ `AVAudioApplication.requestRecordPermission()` | `RECORD_AUDIO` 运行时权限（ActivityResult API）；Android 13+ 通知权限另计 |
| 权限声明 | 由 `project.yml:37-38` 生成（无独立 Info.plist） | `NSMicrophoneUsageDescription`="语音记一笔时需要使用麦克风进行识别"；`NSSpeechRecognitionUsageDescription`="用于将你的语音转换为经营记录" | `AndroidManifest.xml`：`<uses-permission android:name="android.permission.RECORD_AUDIO"/>` + 前台服务类型（如后台录音） |
| 触感反馈 | `VoiceViewModel.swift` save 成功后 `Haptic.success()` | `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`（`DesignSystem/FloatingDock.swift:31-39`） | `Vibrator`/`VibrationEffect` 或 `View.performHapticFeedback()` |
| 状态管理 | `SpeechService`/`VoiceViewModel` 标 `@Observable` | Swift Observation 框架（`import Observation`） | Kotlin `StateFlow`/`MutableStateFlow` + Compose `collectAsState()` |

### 3.3 VoiceViewModel 状态机与 UI（`Voice/VoiceModel.swift:3-31`，`Voice/VoiceViewModel.swift`，`Voice/VoiceView.swift`）

状态：`idle / listening / recognized / parsing / preview / saving / error(String) / textFallback`。

- `beginListening()`（VoiceViewModel.swift:37-75）：模拟器 recognizer 为 nil 时静默返回（L39）；权限拒绝 → `phase=.error("麦克风/语音识别权限被拒绝")`；partial 结果实时写 `transcript`（L52-60）；错误统一映射——`SpeechService.mapError`（L184）对所有错误返回"没有听清，请再试一次"，**原始错误信息被丢弃**（Android 迁移时应保留错误码以便诊断）。
- `stopListening()`（L78-81）→ `phase=.recognized` 等 final。
- `handleRecognized(_:)`（L84-96）：空文本 → error；`VoiceParser.isUnsupportedQuery`（VoiceModel.swift:56-74，含"天气"且无记录意图词 → 拒绝）→ error；否则 `VoiceParser.parse` → `preview`。
- `textFallback`（L99-108）：识别不可用时的手动输入入口，**走同一解析链路**。
- `save()`（L111-171）：六分支真实写入（见 §3.4），成功 `Haptic.success()` + `didSave=true` → View 延迟 0.8s dismiss（VoiceView.swift:19-26）。

VoiceView（396 行）UI 要点：
- 顶部状态标题 + 关闭按钮（`stateTitle` L88）。
- **无真实音频波形**：`CompactVoiceWaveform`（L316-353）是 15 个 Capsule 的装饰性动画（`accessibilityHidden`），非麦克风音量驱动——Android 可直接用 Lottie/Compose Canvas 复刻装饰动画，或接 AudioRecord 做真波形（视觉以 iOS 为准）。
- 中央 60pt 按钮（L129-158）：listening → `stop.fill` 红色（V32.danger）；idle/error → `mic.fill` 品牌色；iOS 26 用 `.glassProminent`，低版本 Circle 兜底。
- `previewSection`（L186-211）：识别原文卡 + `parsedFields` 按类型展示（金额/商品/临期/客户/数量/备忘/事项/时间）+ 6 类 segmented 类型覆盖（改后 `Haptic.light()`）+ "确认保存"按钮（saving 显示 ProgressView 并禁用）。

### 3.4 语音链路真实写入表（VoiceViewModel.save，VoiceViewModel.swift:111-171）

| 草稿类型 | Repository 调用 | 参数语义 | 缺省/校验 |
|---|---|---|---|
| 营业/业绩 | `PerformanceRepository.add(amount:note:date:)`（L125） | 金额/备注/日期 | 金额缺失 → error"请补充收入金额"（**有校验**） |
| 支出 | `ExpenseRepository.add(amount:category:note:date:)`（L132） | category：含"进货"→"进货"否则"其他" | — |
| 临期 | `ExpiryRepository.add(name:quantity:expiryDate:remindDaysBefore:note:)`（L135） | remindDays 缺省 7，quantity 固定 1 | — |
| 备忘 | `MemoRepository.add(title:content:)`（L143） | — | — |
| 客户配送 | `CustomerRepository.add(customer:roomOrAddress:phone:content:)`（L145） | customer 缺省"客户"；content 为"商品 × 数量" | — |
| 待办 | `TodoRepository.add(title:detail:dueDate:priority:)`（L152） | priority 固定 0 | — |

**注意**：QuickRecord 链路（QuickRecordSheet.commit，QuickRecordSheet.swift:311-355）调用同样的 5 个 Repository（无支出），但**金额缺失不校验**（`draft.amount ?? 0`，L323），两条链路行为不一致——Android 迁移时应按产品决策统一（建议以 Voice 链路为准做校验，或明确记录差异）。

### 3.5 语音解析器 VoiceParser（`Voice/VoiceModel.swift:76-271`）——与 QuickRecordParser 独立

优先级 `detectType`（L129-141）：进货/支出/花了 → expense；营业额/收入/卖了/收款/入账 → revenue；过期/临期/到期 → expiry；配送词或"送"+数量/客户名 → customer；记一下/备忘/客人 → memo；默认 todo。
- 金额正则更宽松：`(\d+(?:\.\d+)?)`（无单位要求，L193）。
- 截止时间仅支持：今天/明天/后天 + 上午/下午/晚上 X点/中午（L208-250）。
- **零单元测试**（全仓无引用）——Android 迁移时建议补齐。

---

## 四、快速记录（QuickRecord）：表单、解析规则、语义

### 4.1 QuickRecordSheet 表单字段全表（`QuickRecord/QuickRecordSheet.swift`）

该 Sheet **不是传统多字段表单**——核心是唯一输入控件 + 只读识别结果卡 + 类型覆盖菜单：

| 字段 | 类型/控件 | 默认值 | 校验 | 行号 |
|---|---|---|---|---|
| 一句话输入 `text` | `@State String`，多行 TextField（3–6 行） | `""` | 保存闸门唯一条件：`QuickRecordSavePolicy.canSave`（L17–21）= trim 后非空；空则"确认保存"按钮 disabled + 半透明 | L24；输入卡 L129–141；按钮 L107–109 |
| 语音录制 `voice` | `@State QuickRecordVoiceRecorder`（状态机 idle/listening/denied/empty/failed，L368–376） | idle | 弹出即自动开始（`autoStartListening` L147–150，仅当 `canUseSpeech` 即识别器可初始化） | L33；recorder L365–441 |
| 类型覆盖 `overriddenKind` | `@State QuickRecordKind?`，Menu（5 类全列） | nil（跟随自动识别）；重新输入后重置为 nil | 无 | L29；kindRow L297–322；onChange 重置 L119–124 |
| 结果卡（只读展示） | 类型 / 内容(`note`) / 金额(`Fmt.money`) / 时间(`Fmt.dateTime`) | — | 金额/时间行为空时不渲染该行 | resultCard L277–295 |
| 保存 | `commit()` L311–355 | — | trim 非空即保存；parser 兜底备忘保证不丢；成功显示"已保存到：X" + 0.6s dismiss，失败显示 `QuickCaptureSemantic.failed` | L311–355 |

### 4.2 QuickRecordParser 自然语言解析规则全表（`QuickRecord/QuickRecordParser.swift`）

**分流顺序**（L39–100，V3.3 真机 hotfix 定稿）：①营业额 → ②显式备忘 → ③待办 → ④配送 → ⑤临期 → ⑥备忘兜底（非空必保存）。

| # | 规则 | 位置 | 输入 → 输出示例 |
|---|---|---|---|
| 1 | 营业额：金额非空 **且** 含营收信号词（`revenueSignals` L104–112：营业额/营收/收入/卖了/收款/入账/进账/美团/饿了么/抖音/团购/外卖/收钱吧） | L96–109 | "今天营业额2680" → {performance, amount:2680, title:"营业额", date:今天}；"今天美团680" → {performance, amount:680} |
| 2 | 显式备忘：含"记一下/记个备忘/备忘/记下来"（优先于待办词，避免"记一下，进货时带发票"被误判待办） | L122–124 | "记一下王老板交代的事" → {memo, title:前20字}；"记一下，进货时带发票" → memo |
| 3 | 待办：`todoSignals`（L114–120，约40词：联系/打电话/买/进货/进/拿货/订货/下单/补货/整理/盘点/对账/催/取货/寄/发货/维修/预约/交费/办理/准备/安排/检查/打印/报名/提醒…；**不含"送"**） | L117–120 | "明天下午3点联系饮料供应商" → {todo, date:明天15:00}；"明天进两箱水" → {todo} |
| 4 | 配送：含"配送/送货/送到/客户" **或** 正则 `给[^，。；\s]{0,12}送`（L131） | L126–132 | "后天张老板配送" → {customer, customer:"张老板"}；"今晚8点给302送两箱怡宝" → {customer, customer:"302"} |
| 5 | 临期：含"退货/临期/过期/到期"（L134–136）；商品名 = 去掉"退货/临期/月底/明天/后天"后的剩余（`expiryName` L154–166），空则"临时商品" | L134–166 | "月底两箱牛奶退货" → {expiry, title:"两箱牛奶", quantity:2} |
| 6 | 兜底：非空无法识别 → 备忘 | L94–103 | "卡卡卡卡卡卡" → {memo}；"供应商周五过来" → {memo} |
| 7 | 金额提取 `AmountPhraseParser`（L170–184）：①正则 `(\d+(?:\.\d+)?)(?:元\|块\|块钱)?` 取首个 > 0；②中文数字 `[一二三四五六七八九十百千万两零]+` → `ChineseNumber.parse` | L170–184 | "买牛奶50元" → 50；"六十八元" → 68；⚠️ 纯"50"无单位也能提取（**数字误伤风险**） |
| 8 | 数量提取 `QuantityPhraseParser`（L188–200）：`(\d+)\s*(箱\|件\|瓶\|袋\|个\|份)`；特殊"两箱" → 2（**只有"两箱"，无"三箱"等中文数字通用处理**） | L188–200 | "两箱怡宝" → 2 |
| 9 | 日期提取 `DatePhraseParser`（L204–242）：今天/明天/后天/月底（月末日）/周X（`weekdayOffset` L259–278：firstWeekday=周日，同周 → +7 天，即"周五"在周五说 = 下周五）/"N月N日"（L244–257：跨年回退 + 非法日期校验，"2月30日"被拒绝） | L204–278 | "月底" → 当月最后一天；"9月30日" → 当年/次年 9-30 |
| 10 | 时间提取 `parseTime`（L281–303）：`(上午\|下午\|晚上)?\s*(\d{1,2})(?:点\|:\|：)(\d{1,2})?`；下午/晚上 < 12 则 +12；上午 12 点 → 0 | L281–303 | "明天下午3点" → 15:00；"今晚8点" → 20:00 |
| 11 | 客户名提取 `customerName`（L138–152）：①`给\s*([^\s，。；]{1,12}?)\s*送`（房号/人称，0–12字）；②`([一-龥A-Za-z0-9]{1,8})(老板\|别墅\|房\|店)`；为空时填"客户" | L138–152 | "给302送" → "302"；"张老板配送" → "张老板" |
| 12 | AI 专用 `resolve()`（L318–368，V3.3 P0-3 纯新增，不改变 parse）：裸"N点"（1–11 点）无时段限定词 → `.ambiguousClock("3点")`（**必须追问澄清，禁止回落当前时间**）；12 点约定中午、13 点+ 视为 24 小时制无需澄清；只有日期 → `.date(当天零点)`；无时间词 → nil | L310–368 | "明天3点" → ambiguousClock；"明天下午3点" → 明天 15:00 |

**提取优先级**：金额 = 阿拉伯数字优先、中文数字其次；日期 = 相对日词 > 月底 > 周X > N月N日，再叠加时间；分流 = 金额 + 营收词最优先（"今天美团680"即使无"营业额"二字也判业绩）。

**双解析器差异提醒**：语音页用 `VoiceParser`（§3.5，有 expense 类型），QuickRecord 用 `QuickRecordParser`（无 expense kind）——两套独立实现、规则不同，Android 迁移时应**保留各自行为**或经产品确认后统一。

### 4.3 QuickCaptureSemantic（`QuickRecord/QuickCaptureSemantic.swift`，13 行）

共享文案枚举（注释明示：三个底层状态机保持独立，仅共享词汇）：
- `listening`="正在听…"，`processing`="正在整理…"，`ready`="请确认将保存的内容"，`saving`="正在保存…"，`saved`="已保存"，`failed`="保存失败，请重试"
- `savedMessage(destination:)` → "已保存到：\(destination)"
- 被 `VoicePhase.statusText`（VoiceModel.swift:13–22）、VoiceViewModel.save 失败分支、QuickRecordSheet commit 成功/失败、AI ShortVoicePanel 共用——Android 迁移时应抽取为共享字符串资源（各语义状态机独立，仅文案共享）。

### 4.4 QuickRecord 写入表（QuickRecordSheet.commit，QuickRecordSheet.swift:311–355）

与 §3.4 同 5 个 Repository（无支出分支）：PerformanceRepository.add（L323）、TodoRepository.add（L329，`detail:""`）、CustomerRepository.add（L335，content 为 `draft.title`——注意与语音链路"商品 × 数量"语义不同）、ExpiryRepository.add（L342，`quantity: draft.quantity ?? 1`）、MemoRepository.add（L348）。

---

## 五、深链接路由全表（xzg://）

### 5.1 Scheme 注册

`project.yml:51–54`：`CFBundleURLTypes` → `CFBundleURLName: com.xiaozhanggui.ios`，`CFBundleURLSchemes: [xzg]`。
Android 等价：`AndroidManifest.xml` 中为目标 Activity 声明 `<intent-filter>` + `<data android:scheme="xzg"/>`（App Links 如需 https 另配）。

### 5.2 路由表（`Assistant/AI/Core/AppDeepLink.swift`，host 小写比对 L28–35）

| URL | 解析（行号） | 目标（`RootView.handleDeepLink` L63–73） |
|---|---|---|
| `xzg://voice` | `case "voice"` → `.voice`（L28–29） | `showVoice=true` → sheet 弹出 `VoiceView()`（RootView L53–55；L54 以 `SpeechService.canInitializeRecognizer` 为闸，模拟器不开）→ onAppear 即 `beginListening()` |
| `xzg://quickrecord` / `xzg://quick` | `case "quickrecord","quick"` → `.quickRecord`（L30–31） | `showQuickRecord=true` → sheet 弹出 `QuickRecordSheet()`（L50–51）→ onAppear 即自动开始监听 |
| `xzg://ai` | `case "ai"` → `.ai(voiceMode:false)`（L32–35） | `tab = .assistant` 切到小掌柜 Tab（L71） |
| `xzg://ai?mode=voice` | 同上，query `mode=voice` → `.ai(voiceMode:true)`（L34） | 切 assistant Tab + `showAIVoice=true` → `AIChatView(voiceDeepLink:)` 拉起短语音面板 |
| 其他 host | `default` → nil，调用方忽略不崩溃（L36–38） | 无动作 |

### 5.3 Widget 入口

`SharedKernel/WidgetFocusItem.swift:123–128`：`XZGWidgetLink.ai = xzg://ai`、`XZGWidgetLink.voice = xzg://voice`，被 `XiaoZhangGuiWidget/WidgetWorkbench.swift:44/53/147/148`（"问小掌柜"/"语音记录" pill）使用。
Android 等价：桌面小部件（Glance）按钮 → PendingIntent 打开对应 deep link。

---

## 六、App Intent / 快捷指令（`Features/Intents/XZGAppIntents.swift`，144 行）

| Intent | 参数 | 执行逻辑 | Siri 快捷指令 |
|---|---|---|---|
| `AddTodoIntent`（L9–47）"新增待办" | title（待办内容）；priority（默认 1，0低/1中/2高，钳制 0–2）；dueToday（默认 false） | `openAppWhenRun=false`（后台运行）；title 为空 → dialog 报错；`AppDatabase.makeContainer()` 建 App Group 容器 → `ModelContext` → insert Todo（dueDate = dueToday ? 今日末 : nil）→ save → `NotificationManager.scheduleTodo(todo)` 排提醒 → `SnapshotSyncManager.refreshAll` 刷新小组件/Live Activity | ✅ `XZGAppShortcuts` 注册 3 条 Siri 短语："在[App]新增待办/用[App]记待办/添加[App]待办"（L105–114） |
| `RecordRevenueIntent`（L51–80）"记录营业额" | amount（金额）；note（默认"Siri 快捷指令"） | amount ≤ 0 → dialog 报错；`PerformanceRepository.add(amount:note:date:)` → refreshAll | ✅ 短语："在[App]记录营业额/用[App]记一笔营业额/[App]记收入"（L115–124） |
| `AddMemoIntent`（L84–110）"记记录" | title（记录标题）；content（默认 ""） | title 为空 → dialog 报错；`MemoRepository.add(title:content:)` → refreshAll | ✅ 短语："在[App]记记录/用[App]记一条记录"（L125–133） |

说明：
- 通过 `AppShortcutsProvider` 注册系统级 Siri 短语；**未使用显式的 donation API**（如 `donate()`），依赖系统对 AppShortcut 的自动发现。
- 写入的是 App Group 内 SwiftData 容器（`AppDatabase.makeContainer()`），与主 App 同库。
- 文件头注释：真机 Siri 短语注册与后台执行"需 Mac/Xcode"验证。
- Android 等价：Google Assistant **App Actions**（`actions.xml` + deep link，Android 6.0+，需 Play 审核）或 **App Shortcuts**（长按图标快捷方式）+ 桌面小部件；后台写入走 Room（无需 App Group 概念，同一进程/数据库）。

---

## 七、iOS-only API 清单（C 范围全量合并）

### 7.1 语音 / 速记 / Intents（D 组）

| 框架 | 用处 | 文件:行号 |
|---|---|---|
| Speech | `SFSpeechRecognizer`（zh-CN）、`SFSpeechAudioBufferRecognitionRequest`、`SFSpeechRecognitionTask`、`SFSpeechRecognizer.requestAuthorization` | Voice/SpeechService.swift: L2, L31, L35, L55, L82–84 |
| AVFoundation | `AVAudioEngine`、`AVAudioSession`（category .record/measurement/duckOthers）、`AVAudioApplication.requestRecordPermission` | Voice/SpeechService.swift: L3, L27, L78–80, L60 |
| AppIntents | `AppIntent`、`@Parameter`、`ParameterSummary`、`AppShortcutsProvider`、`AppShortcut`、`IntentDescription` | Features/Intents/XZGAppIntents.swift: L2, 全文件 |
| SwiftData | `ModelContext`（Intents 后台写入）、VoiceView 的 `@Environment(\.modelContext)` | XZGAppIntents.swift:39/68/99；Voice/VoiceView.swift:2/5 |
| SwiftUI | 全 UI | Voice/VoiceView.swift:1；QuickRecord/QuickRecordSheet.swift:1 |
| Observation | `@Observable`（SpeechService、VoiceViewModel、QuickRecordVoiceRecorder） | Voice/SpeechService.swift:4；Voice/VoiceViewModel.swift:3 |
| UIKit | `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`（Haptic 封装） | DesignSystem/FloatingDock.swift:31-39（import UIKit L31） |
| 间接 | UserNotifications（`NotificationManager.scheduleTodo`，Intents 调用）、WidgetKit（`SnapshotSyncManager.refreshAll` 刷新小组件；Widget extension 链路） | XZGAppIntents.swift:44/73/104 |

### 7.2 AI 引擎 / 工具链（A 组，全部只 `import Foundation`，外加以下）

| 框架 | 用处 | 位置 |
|---|---|---|
| **Observation** | `@Observable`（`AISettings`、`AISettingsDraft`） | `AI/Core/AISettings.swift:2` |
| **Security** | Keychain：`SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete`，`kSecAttrAccessibleAfterFirstUnlock`；API Key 唯一允许的存放处 | `AI/Core/AISettings.swift:3`，`AIKeychain`（L360-405） |
| **PDFKit** | `PDFDocument(data:).string` 抽取 PDF 文本（文档理解能力） | `AI/Capabilities/LiveCapabilityProviders.swift:2`，`LocalDocumentTextExtractor`（L220-233） |
| **NSDataDetector**（Apple 平台 Foundation） | 聊天文本中的链接检测（URL 阅读触发） | `AI/Capabilities/AICapabilityRouter.swift:17-24` |

其余均为跨平台 Foundation：`UserDefaults`、`FileManager.applicationSupportDirectory`、`URLSession`、`NSRegularExpression`、`JSONSerialization`、`DateFormatter`/`NumberFormatter`、`Calendar`/`DateInterval`、`UUID`。**A 组文件全程不 import SwiftData**（红线，`AIDTO.swift:1-9` 注释明确）；SF Symbols 仅以字符串形式出现（`BusinessAssistantEngine.swift` 的 `symbolName` 如 `clock.badge.exclamationmark`），不构成 API 调用。

### 7.3 AI Provider / UI（B 组）

| API | 位置 | 用途 |
|---|---|---|
| Security：`SecItemAdd/CopyMatching/Delete`，`kSecClassGenericPassword`，`kSecAttrAccessibleAfterFirstUnlock` | `AI/Core/AISettings.swift:361–393` | API Key 唯一存放处（同 §7.2） |
| Observation `@Observable` / `@MainActor` | AISettings、AISettingsDraft、AIConversationViewModel、ProviderConnectionTester、ShortVoiceSession | 状态管理 |
| PhotosUI：`photosPicker` + `PhotosPickerItem.loadTransferable` | `AI/UI/AIChatView.swift:139–149` | 图片选择→analyzeImage |
| `fileImporter` + `UTType`（UniformTypeIdentifiers）+ `startAccessingSecurityScopedResource` | `AI/UI/AIChatView.swift:150–160` | PDF/文本/Markdown 导入 |
| `glassEffect(.regular, in:)`（iOS 26+，`#available(iOS 26.0, *)` 分支） | ActionCardView L160–162、ChatInputBar L103–104、TypingIndicator L48–50 | 按钮区/输入栏/思考气泡玻璃拟态；均有 reduceTransparency 回退 |
| `UnevenRoundedRectangle` | ShortVoicePanel L45–57 | 语音面板顶部圆角 |
| `toolbar(_:for: .tabBar)` 显隐 | AIChatView L102 | 语音面板展示时隐藏底部 Tab 栏 |
| `AttributedString(markdown:)` | AIChatView L260–270 | 助手消息 Markdown 渲染 |
| `ISO8601DateFormatter`（带/不带毫秒双实例） | OpenAICompatProvider L268–280 | 工具参数日期解码 |
| `NSRegularExpression`（ICU 中文正则） | LocalBusinessParser L18–37 | 电话/金额/房号/人名/商品规则 |
| `NumberFormatter`（decimal） | RepositoryToolExecutor L173–179 | 金额格式化 |
| `scrollDismissesKeyboard(.interactively)`、`ScrollViewReader`、双参 `onChange`（iOS 17+）、`FocusState`、键盘 `ToolbarItemGroup`、`SecureField`、`Menu` | AIChatView / ChatInputBar | 聊天交互 |
| `NotificationCenter`（`.aiProviderConfigChanged`） | AIAssembly L80/L94、AIProviderSettingsSheet L421 | 设置保存→重装配 live Agent |

**无 macOS/watchOS/tvOS 分支；无 AppKit/UIKit 直接调用；最低部署目标未在本次审计文件中声明。**

### 7.4 Android 等价替换总表

| iOS | Android |
|---|---|
| Speech（SFSpeechRecognizer） | `android.speech.SpeechRecognizer` / 厂商 ASR / 云 ASR（讯飞/阿里/腾讯） |
| AVAudioEngine/AVAudioSession | `AudioRecord` / `MediaRecorder` + `AudioManager` 音频焦点 |
| Keychain（Security） | Android Keystore + EncryptedSharedPreferences（androidx.security） |
| AppIntents / AppShortcutsProvider | App Actions（actions.xml）/ App Shortcuts / 小部件 |
| PDFKit | PdfRenderer / 云端文档解析 |
| NSDataDetector | `android.util.Patterns` + `Linkify` |
| PhotosUI photosPicker | `ActivityResultContracts.PickVisualMedia` |
| fileImporter/UTType | `ActivityResultContracts.OpenDocument` |
| UserDefaults（AISettings） | DataStore Preferences |
| FileManager.applicationSupportDirectory（journal/pending/conversation JSON） | `context.filesDir`（同名 JSON 落盘，语义 1:1） |
| URLSession | OkHttp / Retrofit |
| NSRegularExpression（ICU） | `java.util.regex`（注意中文正则行为差异，需用测试锁定） |
| LLMProviderKit | 无等价库，手写 OpenAI-compatible 客户端（隔离单文件） |
| Observation @Observable | StateFlow + Compose collectAsState |
| WidgetKit 小组件/pill | Glance 小部件 + PendingIntent deep link |

---

## 八、Tests 覆盖情况（AI / 语音 / 解析 / 意图 / 深链接）

| 测试文件 | 方法数 | 核心断言 |
|---|---|---|
| `Tests/QuickRecordParserTests.swift` | 14 | `LocalQuickRecordParser` 分流：营业额/待办+时间/配送/临期；"今天美团680" → performance；"给302送" → customer；显式备忘优先于待办词；无意义输入/陈述句兜底 memo；空白不可保存；N月N日跨年回退与非法日期（2月30日） |
| `Tests/QuickRecordVoiceUIAuditTests.swift` | 4 | **源码文本审计**（非运行时）：监听时头部 mic 不渲染、监听状态卡可见、禁 `repeatForever`/`scaleEffect`、所有结束路径（idle/empty/denied/failed）恢复非监听 UI |
| `Tests/AI/AppDeepLinkTests.swift` | 6 | `AppDeepLink.route` 全 case：voice/quickrecord/quick/ai/ai?mode=voice/未知 host → nil/纯函数入口 |
| `Tests/AI/AIVoiceDockTests.swift` | 3 | AI 短语音面板（`AIConversationViewModel`，非 Voice 链路）：面板展示时 Dock 隐藏，取消/填入文字后恢复 |
| `Tests/AI/IntentRouterTests.swift` | 14 | `IntentRouter.classify`（AI 意图分类，非 QuickRecordParser）：经营动作/查询/世界闲聊/配送判定/金额检测/经营周期短语 |
| `Tests/AI/IntentRouterExpiryTests.swift` | 3 | IntentRouter 临期相关 |
| `Tests/FlowConsistencyTests.swift` | 4 | 源码审计：VoiceViewModel.swift 含 `QuickCaptureSemantic.failed`；QuickRecordSheet 含 savedMessage/failed（L11 起） |
| `Tests/Phase41AutomatedAcceptanceTests.swift` | 5 | `VoicePhase.statusText` 与 QuickCaptureSemantic 一致性（L98–100）；LocalQuickRecordParser 临期日期回退 |
| `Tests/QuickCaptureSemanticTests.swift` | — | QuickCaptureSemantic 文案一致性（listening/processing/ready/saving/saved/failed/savedMessage） |
| `Tests/AI/` 其余（AI20GroundingTests、AI20MultiTurnTests、AI20RegressionCorpus、AIRealBusinessContextReaderTests、AIRealDeviceP0FixTests、AIRealToolExecutorIntegrationTests、AITestSupport、MockBusinessParserTests、OpenAICompatProviderTests、ProviderChainTests、UserFacingAIErrorTests） | — | Provider 链/错误映射/Mock 解析器/真实工具执行器集成（B 组确认存在，未逐项计数） |

**审计边界说明**：
1. 任务所列 Providers "12 文件"实为 10 个文件名，目录中也恰为这 10 个，已全部逐字读完。
2. `Package.swift` / `Package.resolved` 在审计快照中**不存在**，LLMProviderKit 的 SPM 声明位置无法核实（仅能确认 `OpenAICompatProvider.swift:2-3` 的 import 与注释中的选型结论）。
3. `AISettings.swift`（Core）与 `AI/Core/ModelRouter.swift`（Core）不在 B 组清单内，但配置项任务必需，已只读引用；`V32*` 设计系统在分配范围外，未深入。
4. 本分支**无流式 token 渲染**（`complete` 单次返回、UI 仅 `isProcessing + processingLabel`），不要按 "idle/thinking/streaming/toolCalling/error" 理解。

**覆盖缺口（无测试的链路）**：
1. `VoiceParser`（语音页解析器：`parse/detectType/parseAmount/parseDueTime/parseQuantity/parseCustomerName/parseGoodsName/isUnsupportedQuery`）——**零单元测试**，Tests 全仓无引用。
2. 语音录音链路（SpeechService start/stop/权限/3 秒静音）——无测试（真机依赖，可理解）。
3. `VoiceViewModel` 状态机与 `save()` 六分支写入——无测试。
4. `VoiceView` UI——无测试。
5. `QuickRecordVoiceRecorder` 状态机——仅有源码文本审计（UIAuditTests），无行为测试。
6. `XZGAppIntents` 三个 Intent 的 `perform()`（后台容器写入、金额/标题校验）——无测试。
7. `DatePhraseParser.resolve()` 的 ambiguousClock 澄清逻辑——无测试。
8. QuickRecordSheet 的 `commit()` 金额缺省写 0（§4.1 noted）——无测试锁定。

---

## 九、Android 迁移要点（C 部分汇总）

1. **双解析器**：`VoiceParser`（语音页）与 `QuickRecordParser`（速记页）独立实现、规则不同（前者有 expense 类型，后者无）。迁移时按各自行为 1:1 实现，或经产品确认统一。
2. **AI 引擎**：待 A/B 组报告补全动作清单、Provider 配置与确认机制后，形成完整 parity 依据。
3. **Apple-only 替换**：Speech → `android.speech.SpeechRecognizer` 或云 ASR；AVAudioEngine → `AudioRecord`；AppIntents → App Actions；Keychain（如 B 组确认）→ EncryptedSharedPreferences / Android Keystore。
4. **行为差异需产品确认**：QuickRecord 金额缺失写 0 vs Voice 链路报错；`mapError` 吞原始错误；"周五"在周五说 = 下周五（weekdayOffset 同周 +7）。
5. **深链接**：`xzg://` 四路由（voice/quickrecord|quick/ai/ai?mode=voice）在 Manifest intent-filter 中逐一实现。
6. **快捷指令**：3 个 Siri 短语 → Android App Actions（actions.xml）或长按快捷方式。

---

*报告状态：A 组（引擎/工具链/业务动作清单/意图路由/幂等/ Capabilities）、B 组（Provider/配置/Key/装配/UI/Skills）、D 组（语音/速记/Intents/深链接/测试）三组合并完成。C 范围共审计 57 个文件：Assistant 49 + Voice 4 + QuickRecord 3 + Intents 1。*

## 十、审计意见汇总（C 部分 → Android 迁移）

1. **AI 写链路是纵深结构**：「5 工具注册表 → 参数校验 → 双键幂等（toolCallID + 业务指纹）→ ActionCard 确认 → Repository 写入 → Journal 落盘」，preview/live 双门（`WriteGate`）与 fail-closed 语义一致。Android 必须 1:1 复刻：指纹格式、journal 落盘语义、五态确认卡（pending/executed/duplicate/failed/cancelled）。
2. **确认机制是硬性要求**：4 个 CREATE 工具（recordRevenue/createTodo/createMemo/createDelivery）必须经 ActionCard 用户确认；`searchRecords` 只读自动执行。`PreviewToolExecutor` 恒不落库；Release live 环境禁止回落 Mock（`ProductionGuardTests` 约束）。
3. **隐私红线**：上云 CREATE/聊天时 `context` 恒空（Lite 不把经营数据随云端外发）；`advice` 走脱敏 `GroundingPack`；读链路经聚合+脱敏不出设备。Android 同样遵守。
4. **需产品确认的差异点**：(a) `createDelivery` 的 JSON Schema 必填为空，仅靠 `ToolArgumentValidator` 兜底「客户与商品全空」；(b) QuickRecord 金额缺失写 0 vs Voice 链路报错"请补充收入金额"；(c) `SpeechService.mapError` 吞原始错误（Android 应保留错误码）；(d) 「周五」在周五说 = 下周五（weekdayOffset 同周 +7）；(e) 双解析器（VoiceParser 有 expense / QuickRecordParser 无）是否统一。
5. **无真流式**：不要为 Android 设计 SSE 流式 UI；`isProcessing + processingLabel` 二元状态机即可（若未来接流式再加 token 拼接）。
6. **离线能力必须保留**：`LocalBusinessParser` 无 Key 时本地 CREATE 照常工作；`QuickRecordParser` / `VoiceParser` / `BusinessPeriodParser` / `IntentRouter` 全部是 0-Token 本地规则，Android 用 `java.util.regex` 逐条移植并用回归测试锁定（注意 ICU 与 Java 正则在中文/Unicode 上的行为差异）。
7. **深链接与快捷指令**：`xzg://` 4 路由在 Manifest intent-filter 逐一实现；3 个 Siri 短语 → Android App Actions（actions.xml）或长按快捷方式 + Glance 小部件。
8. **Key 存储**：4 个 Keychain 键 → Android Keystore + EncryptedSharedPreferences；UserDefaults 配置 → DataStore；journal/pending/conversation 三个 JSON → `context.filesDir` 同名落盘。
