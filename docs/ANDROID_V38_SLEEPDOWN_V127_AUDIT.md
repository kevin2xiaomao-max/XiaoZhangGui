# SleepDown v1.2.7 正式版增量技术审计

> 审计范围：`v1.2.7_beta5-r1` → `v1.2.7`（2026-10-15 发布）的增量 diff（新增 169 / 修改 178 / 删除 18 个 Kotlin 文件）。
> 方法：纯静态只读分析。**未复制 SleepDown 任何源码、参数数值、资源文件；未修改小掌柜任何生产代码。**
> 许可证：SleepDown 为自定义非商业许可，本报告只描述架构原理与设计思路，不含受限实现细节。

---

## 重点1：ColorOS 凝光材质（`platform/coloros/`）

### 新增内容
全新包 `platform/coloros/`（约 27 个 Kotlin 文件 + 10 个测试文件），构成"厂商材质后端"：能力探测 → 材质/控件提供 → 逐组件降级。beta5 无此目录。

### 源码证据（文件路径+行号+原理）
- `platform/coloros/ColorOsVisualCapability.kt`：`supportsColorOsGlow()` 为纯函数，多条件**全部满足**才返回 true，任一失败返回 false。条件包括：编译期实验开关门控、Android 版本门槛、厂商归属（OPPO/一加/realme 系）、ColorOS 主版本门槛（经系统属性读取，读不到则判 false）。`isColorOsGlowDevice()` 只是把参数绑定到真机值——这是**静态资格预审**，非最终可用性结论。
- `platform/coloros/ColorOsNativeUi.kt`：运行时真实探测。按序尝试系统应用包（设置/联系人/文件管理类系统包），要求为 system 级应用，用 `createPackageContext(INCLUDE_CODE | IGNORE_SECURITY)` 建类加载器，再校验能加载 COUI 框架类（含特定方法签名）且对应主题资源存在。任一步失败 → 整个后端不可用。另有单组件 `prepare(operation, block)` 兜底：每个组件构造独立 try/catch，捕获异常/链接错误后记日志返回 null，该组件单独回退。
- `platform/coloros/ColorOsMaterialProvider.kt`：`ProvideColorOsMaterials(enabled)` 不直接绘制，而是把一组 ColorOs 实现装进设计系统的 CompositionLocal 契约槽；`enabled=false` 时注入全空默认实现。业务组件**从不直接引用 coloros 包**，只读设计系统的 renderer CompositionLocal。
- `model/VisualEffectMode.kt` + `app/ui/ProvideVisualEffects.kt`：用户偏好（DataStore）→ `effectiveVisualEffectMode` 生效折算（选了凝光但不可用 → 强制回 LiquidGlass）→ 整包探测 → 注入，全链装配。
- 测试：`app/src/test/.../platform/coloros/` 10 个文件，覆盖偏好折算矩阵、能力检测矩阵、弹窗几何、圆角分类、触摸门控等；**反射加载系统 COUI 类的真实路径不可被 JVM/Robolectric 覆盖**，测试只覆盖到"探测失败→回退"的纯函数部分。

### 适配价值
凝光材质实现本身**不可搬**（依赖 ColorOS 私有框架 + 反射，违反小掌柜"只用公开 API"红线）。但其"**偏好 → 生效折算 → 运行时探测 → 逐组件兜底 → 业务回退**"的四层能力门控模式值得参考——小掌柜 MotionPolicy 的具名降级链与之思想同构，可对照查漏。

### 风险
- 深度依赖未公开的类名/方法签名/私有字段与系统属性，ColorOS 大版本升级可致**静默失效**（try/catch 保护不崩，但无声回退）；
- 反射路径在自动化测试中不可覆盖，回归只能靠真机；
- 整个后端被实验开关门控、默认关闭，作者自己也视为不稳定特性。

### 推荐阶段
**仅参考，不采用实现**（Phase 不适用）。降级链思想可在 Phase 3 代码审查时对照。

### 是否修改现有 PoC
**不要**。PoC-4 已坚持公开 API 探测路线；凝光材质的反射手段与现有 PoC 无关。

---

## 重点2：ControlMaterialRenderers（业务组件与渲染解耦）

### 新增内容
`core/ui/designsystem/` 新增 `ControlMaterialProvider.kt` + 9 个 `Native*Renderer.kt`（Alert/CapsuleButton/CourseCard/DialogSnapshot/FollowLight/MaterialSurface/Menu/ProgressiveBlur/ValueControls/PickerStyle），beta5 无。配套业务改造：`SleepDownDialog.kt` 等改为先问 renderer 再回退。

### 源码证据（文件路径+行号+原理）
- `designsystem/ControlMaterialProvider.kt`：`ControlMaterialRenderers`（`@Immutable` data class，约 12 个渲染槽位，默认全空）+ `ProvideControlMaterials(...)` 把每个槽位写进对应的 CompositionLocal。`LiquidGlass = ControlMaterialRenderers()` 即"全空后端"。
- 契约形状：每个可替换控件定义一个 `Native*Request` 数据类（纯 Compose 类型：Modifier/Shape/Color/Dp + 回调，不含任何 View/厂商类型）+ 一个可空的 `LocalNative*Renderer` CompositionLocal（`@Composable (Request) -> Boolean`）。
- 业务侧调用模式（`SleepDownDialog.kt` 典型）：`LocalNativeAlertRenderer.current?.invoke(request) == true` 则直接 return；null/false 则继续走原有 Compose 实现。**Boolean 返回值是"是否已接管"的交接信号**。
- 设计意图（代码注释原文思想）：designsystem 不依赖厂商特性包，由 app assembly 组装期注入（依赖倒置）；能力缺失时 Compose 接管渲染与输入（能力缺失安全）；几何/内容/采样留在 Compose，厂商只提供材质算子与触摸语义（职责边界）。
- 全仓库只有一处调用 `ProvideControlMaterials`——目前是**单后端架构**（ColorOs），插槽为未来/降级预留。

### 适配价值
整套接口**不采用**。其"用数据类描述渲染请求、能力缺失时 Compose 回退"的契约思想可作为参考，但小掌柜现有特性开关 + 条件分支在语义上已等价，无需另起接口层。

### 风险（若误搬）
- 大量 CompositionLocal 污染组合树语义，"谁注入了 renderer"难以追踪；
- Boolean 接管是隐式协议，业务侧漏检查会导致双重绘制；
- 单后端下所有 Request 数据类是为不存在的第二实现服务的抽象层，属过度设计。

### 推荐阶段
**不采用**。**评估结论：小掌柜不需要建立原生/Compose 双渲染接口**，理由：
1. 没有第二个后端——该接口存在的唯一前提是"同一控件有两种渲染实现"（SleepDown 为塞进 ColorOS 系统 COUI 原生控件）；小掌柜纯 Compose、无原生 View 后端、无系统级材质依赖，接口将永远只有一个空实现；
2. 降级需求已有覆盖——MotionPolicy 具名降级链 + PoC/生产隔离 + 三档性能模式已解决逐组件降级；
3. 引入成本为净负担——多槽位 × Request 数据类 × 十余个 CompositionLocal，每个调用点双分支模板代码，单后端现实下零收益。

### 是否修改现有 PoC
**不要**。PoC 隔离边界用现有开关机制已足够。

---

## 重点3：原生按钮 Motion 与 Compose 内容同步

### 新增内容
`platform/coloros/ColorOsCapsuleMotion.kt`（单一动画状态持有者 + 订阅原生动画器的绑定器）、`ColorOsCapsuleButton.kt`、`ColorOsMenuMotion.kt`，配套测试 `ColorOsCapsuleMotionTest.kt`（含"内容跟随原生 motion 且零重组"断言）。

### 源码证据（文件路径+行号+原理）
- **单一动画驱动源**：原生按钮的触摸动画是唯一的动画生产者。Binding 订阅该动画器已有的更新回调，从其变换通道读取每帧进度，写入唯一的 motion 状态对象——**不创建第二套动画器、不做帧轮询**（`ColorOsCapsuleMotion.kt`）。
- **文字与背景共享同一进度、零脱节**：Compose 文字行经 `Modifier.graphicsLayer { motion.applyTo(this) }` 把同一状态对象的变换应用到绘制层；graphicsLayer 只影响绘制不触发布局/重组，文字与原生背景严格同频。
- **防重组**：动画状态只在 graphicsLayer 的 layer block 内被读取，永不在组合作用域读取；测试用重组计数器断言 motion 更新后计数不变，但文字实测发生位移+缩放——"动了但没重组"。
- **减少无效工作**：易变回调经"最新值持有者"模式解耦，原生监听器只注册一次、内部读最新值；motion 与绑定用 remember 缓存；`AndroidView` update 回调做脏检查（enabled/accent 真变才调原生 setter，避免重应用预设覆盖材质）；`DisposableEffect` 解绑防泄漏；禁用态主动取消 pending 输入。

### 适配价值
高。**思想可学、手段不可搬**：其"同源订阅"依赖对 ColorOS 私有框架类的反射（与"只用公开 API"铁律冲突），但提炼出的通用原则可直接指导小掌柜的 Compose 动画实现。

### 实现原则（供小掌柜参考，与具体代码解耦）
1. **单动画源原则**：同一视觉元素的多个子部分（背景/文字/图标）必须由同一个动画进度驱动，禁止各维护一套状态再"尽量对齐"。
2. **绘制层消费原则**：动画帧高频状态只在绘制层（graphicsLayer 等）读取，绝不在组合/布局作用域读取——"零重组动画"的充要条件，可用重组计数断言做回归测试。
3. **监听器一次注册原则**：易变回调用"最新值持有者"模式解耦，平台监听器只注册一次，内部读最新值。
4. **原生 setter 脏检查原则**：调用平台 setter 前先比对，变化才调用（很多原生 setter 有重应用预设等副作用）。
5. **能力缺席即回退原则**：每个增强点可空，缺席静默回退纯 Compose 实现，调用方只关心"是否接管"的布尔值。

### 风险
- 其"同源订阅"的反射手段跨 ColorOS 大版本可失效，非 ColorOS 设备完全走 fallback；
- 原则 1–4 在纯 Compose 下可直接用，原则 5 小掌柜已有等价机制。

### 推荐阶段
**Phase 3**：纳入 Phase 3 代码审查 checklist；原则 2（重组计数断言）可加入 PoC/生产动画的回归测试。

### 是否修改现有 PoC
**现有 PoC 代码不要改**；测试建议见"PoC 测试补充建议清单"。

---

## 重点4：液滴菜单、弹窗、玻璃的稳定性改进

### 新增内容（相对 Beta5 的技术变化）
正式版的收敛是"材质渲染解耦 + 生命周期/几何回归测试"，而非新特效：
- **材质解耦**：`ControlMaterialProvider.kt`（各渲染槽独立可空）——从"整块替换"到"按能力逐槽降级"，针对"某控件在某机型原生材质崩溃拖累整页"的防御。
- **原生渐进模糊算子**：`NativeProgressiveBlur.kt`（fun interface）——"供应商只提供 blur 算子，采样仍归现有 glass 生产者"；`glass/ui/ProgressiveBlur.kt` 改为有原生算子则用、否则 legacy blur。
- **对话框稳定性三件套**：
  - `NativeDialogSnapshot.kt`：对话框快照注册表——仅存活的 app 自有 dialog 注册；IME resize 后重读当前坐标；弥补 PixelCopy 漏掉合成器 backdrop 层的问题；
  - `NativeDialogTouchGate.kt`：修复外部触摸关闭的坐标系 bug（rawX/rawY 含窗口偏移，不能直接与 decor 坐标系 rect 比较）；
  - `SleepDownDialog.kt`：优先走原生 Alert 渲染（接管成功直接 return）+ 新增 Cancel 动作样式与垂直排序。
- **液滴菜单**：`feature/home/overlay/HomeAddMenuPanel.kt`（首页添加菜单，用 `derivedStateOf` 按条件保留 surface）。
- **玻璃 UI 整理**：新增 `GlassSurfaces.kt` / `PanelForeground.kt` / `CourseGlassCard.kt` / `GlassAccent.kt`；删除 beta5 的 `GlassUi.kt` 与 `LiquidGlassSettingsUi.kt`（设置页收敛为质感/性能/超级性能三档）。
- **Morph 泄漏修复**：`HomeAnchoredMorphOverlay.kt` 大改动中含快照 bitmap `finally { recycle() }`——位图泄漏修复；`HomeMorphGeometry.kt` 新增锚定 morph 几何。
- **回归测试网**：`NativePickerLifecycleTest`（resize 可逆无超调）、`QuickScheduleSheetLifecycleTest`（窗口退出前保留草稿、重开恢复内容+几何）、`ColorOsPopupGeometryTest`（RTL、边缘翻转）、`NativeDialogTouchGateTest`（外部点击只关闭一次）。

### 适配价值
正式版证明：液滴/玻璃类效果的量产门槛不在动画曲线，而在**坐标系、窗口生命周期、资源回收**三处的回归测试网。这正是小掌柜 PoC 测试最需要补的方向。

### 风险
- SleepDown 的"原生优先"策略使其稳定性结论与公开 API 路线不完全可比，具体断言阈值不可照搬；
- morph 叠加层量级改动说明复杂度极高，PoC-3 进生产页需同等量级生命周期测试。

### 推荐阶段
**Phase 3（测试补充）**：见下方 PoC 测试补充建议清单。

### 是否修改现有 PoC
**现有 PoC 实现不要改**；只补充测试（清单如下）。

---

## PoC 测试补充建议清单（对应 V3.8 四个 PoC）

> 背景：四个 PoC 的 JVM 逻辑测试已全过，缺的是运行证据。以下建议只加测试/证据，不改 PoC 实现。

### PoC-1 液滴按钮菜单
1. **弹出几何越界测试**（JVM 可做）：锚点靠近屏幕四边 / RTL 布局时，验证"先翻转再钳制"的落点计算。
2. **开关反复后的监听器泄漏测试**：连续打开/关闭 N 次，断言动画回调已解绑、无重复回调泄漏。
3. **模拟器录屏证据**：Reduce Motion 开/关各录一段，验证关闭态直接呈现、内容完整可点；Light/Dark 各一截。

### PoC-2 玻璃三档
1. **降级触发条件测试**（JVM/模拟器）：低性能/省电/Reduce Motion 下验证自动降档按具名策略执行，且当前档位可查询。
2. **三档渲染层一致性证据**：同一内容三档模拟器截图对比，断言文字对比度守恒（现有 JVM 对比度测试是数值层，缺渲染层）。
3. **模糊参数连续变化无闪烁**：模拟器上连续改变模糊半径，录屏抽帧检查无突变帧（档位切换不应重建采样链）。

### PoC-3 连续形变
1. **逆向/中断测试**（JVM 可做）：动画中途反向与取消，断言无超调、无闪烁、状态机回到稳定态。
2. **快照资源回收测试**：若用到位图快照，断言 morph 结束/取消后 bitmap 被回收。
3. **窗口变化后几何重算**：morph 过程中弹键盘/旋转，验证目标坐标重新计算而非使用过期快照。

### PoC-4 OPPO 私有转场探测
1. **探测确定性测试**：同一设备/模拟器多次探测结果一致；探测超时或异常不阻塞启动、有具名失败原因。
2. **降级路径逐条走通**：每个"不可用"结论对应一条明确 fallback（纯 Compose），测试中逐条覆盖。
3. **跨版本能力矩阵**：在不同 ColorOS 大版本上记录探测结果，形成能力矩阵文档——私有 API 跨版本无契约，矩阵是唯一的真实依据（也是我们坚持公开 API 的根本原因）。

---

## 重点5：AI 明确操作授权、版本化草稿、分阶段验证、差异确认

### 新增内容
正式版为 AI 操作链新增四层"写数据之前"的安全机制：
- **明确操作授权** `feature/agent/AgentActionAuthorization.kt`（+ 5 个测试用例）：planner 执行操作前，调用独立只读意图分类器（LLM judge）；只有当分类器判定当前用户消息为显式操作请求、且返回的"请求原文引用"真实出现在当前用户消息中才放行；助手自提方案、历史旧提议一律不算授权；模型输出格式错误只拒绝不放行；传输失败抛异常（不静默视为同意）。
- **版本化草稿** `feature/importing/AiImportCheckpoint.kt`（+ `AiImportCheckpointPanel.kt`）：每次 AI 产出/人工编辑固化为不可变检查点（UUID、时间戳、AI/人工/基线三种来源标注），上限 32 个，可分叉、回退、重解析校验；检查点是"本地已校验的脱离产物"，不持有可变草稿引用。
- **分阶段验证**：AI 导入检查点流程 + `feature/schedule/autorefresh/AutoRefreshReviewStore.kt`（教务自动刷新的待审暂存 `PendingScheduleRefresh`）——不直接写库，用户可停止任务、补充要求、回答缺失信息后再继续。
- **差异确认** `domain/schedule/ScheduleRefreshReview.kt`：保存前计算新旧结构化差异（新增/变更/移除三类配对），用户逐条勾选或整体采用；SHA-256 摘要锁定核对基线，核对期间数据被改动则差异整体失效并要求重新核对；`feature/home/day/CourseEditConfirmationDialogs.kt` 另有课程编辑/删除三类确认框。

### 适配价值
四层机制把"AI 误执行"从模型自觉变为机制保证，且全部落在"写数据之前"——与小掌柜"AI 执行链冻结、写库安全第一"的立场同构。

### 风险
- 意图分类器本身是一次 LLM 调用：增加延迟与成本；分类错误会误拦（体验）或误放（安全）——SleepDown 采用"不确定时判查询（拒绝）"的保守默认；
- 差异摘要锁定在"核对期间后台自动刷新"场景会频繁触发失效，需考虑自动刷新与人工核对的互斥。

### 推荐阶段
**Phase 4 候选**（只列入清单，不修改现有 AgentCore）。

### 是否修改现有 PoC / AgentCore
**不要**。现有 AgentCore（Agent→Pending Action→确认→执行→幂等）冻结，Phase 4 只做展示层与独立评审。

## Phase 4 候选清单（AI 方向）
1. **独立意图授权门**：操作执行前由只读分类器验证"当前用户是否明确要求操作"，助手自提方案不构成授权。
2. **不可变版本化草稿**：AI 每次产出固化为带来源标注的不可变版本，可回退可审计。
3. **分阶段暂存**：AI 任务中途可暂停、可追问、可改要求，落库前永远有一次人工检查点。
4. **差异锁定确认**：落库前展示结构化 diff 并用摘要锁定基线，基线漂移则差异失效重算。

---

## 重点6：备份恢复互斥和原子化安全

### 新增内容
- `feature/backup/BackupRestoreCoordinator.kt`：进程级互斥协调器——单 Kotlin Mutex；`restore` 用非阻塞 `tryLock`，已有恢复在跑则抛 `BackupRestoreInProgressException` **拒绝排队**（注释说明：排队重放会在首次操作删除 journal 后再次替换数据）；`recover`（启动恢复）用阻塞锁，确保 live restore 完全结束后才检查 journal。
- `BackupRestoreJournal.kt`：journal 写入从 `File.renameTo` 改为 `Files.move(ATOMIC_MOVE, REPLACE_EXISTING)` 真原子移动。
- `BackupRestoreService.kt`：恢复入口全流程走协调器；启动 `resumePending` 只恢复"已 journaled 且已确认"的操作；新恢复前检查 journal marker，非 FINALIZED 则拒绝复用其文件；恢复时校验 AI 提供商身份。
- 新增测试：`BackupRestoreCoordinatorTest`（4 用例：重复提交被拒绝而非排队、取消时持有所有权直到回滚完成、等待中的 recovery 不释放 live restore、失败释放所有权）、`BackupRestoreServiceConcurrencyTest`（9 用例）等。

### 适配价值
"校验 → 分阶段写入（journal 先行、原子落盘）→ 异常回滚（保留原数据）"的完整模式，可作为小掌柜后续数据可靠性审计的对照基线。

### 风险
- 该互斥是**单进程级**（Kotlin Mutex），防应用内并发；若备份文件可被外部进程触及，不在此保护范围——审计时需先确认威胁模型；
- "拒绝而非排队"要求 UI 层有明确的"稍后再试"提示，否则用户会误认为功能损坏。

### 推荐阶段
**后续数据可靠性审计候选**（不排入 Phase 3/4）。

### 是否修改 Room/Repository
**不要**。只列入审计候选，不动现有数据层。

## 数据可靠性审计候选清单
1. 恢复类"长时间写操作"是否以非阻塞抢锁拒绝并发提交（而非排队）——排队重放在 journal 清理后会导致数据被二次替换。
2. 崩溃恢复依赖的 journal 文件是否用原子移动写入（`ATOMIC_MOVE`），`renameTo` 在部分文件系统上非原子。
3. 新操作开始前是否检查遗留 journal 状态，非终态 journal 的中间文件是否禁止被复用。
4. App 启动自动恢复是否只限"已确认"的操作，未确认的中间态是否不自动重放。
5. 取消/失败时锁所有权是否保持到回滚完成（而非取消瞬间释放），防止 recovery 与 live restore 交错。

---

## 推荐阶段汇总

| 重点 | 推荐 | 说明 |
|---|---|---|
| 1. ColorOS 凝光材质 | 仅参考 | 降级链思想可参考；反射实现禁用（红线） |
| 2. ControlMaterialRenderers | 不采用 | 无第二后端；契约思想仅参考 |
| 3. Motion 同步原则 | Phase 3 | 纳入代码审查 checklist；重组计数断言进回归测试 |
| 4. 稳定性改进 | Phase 3（测试） | PoC 测试补充建议清单（上方）；不改 PoC 实现 |
| 5. AI 安全四机制 | Phase 4 候选 | 只列清单；不改 AgentCore |
| 6. 备份恢复原子化 | 未来审计候选 | 只列清单；不动 Room/Repository |

**未建议事项**：没有建议重新启动任何项目；V3.8 PoC 真机 ≥55fps 验收门槛保持不变；PoC-4 继续公开 API 路线，不授权私有反射。

---

## 合规声明

- 本审计为**纯静态只读分析**：研究区 `/tmp/sleepdown-v127`、`/tmp/sleepdown-beta5` 均为只读下载副本，未修改其中任何文件。
- **未复制** SleepDown 任何源码文本、具体参数数值、资源文件到小掌柜仓库或任何交付物；本报告仅描述架构原理与设计思路（文件路径+行号+行为描述）。
- **未修改**小掌柜任何生产代码（`~/workspace/xzg-android-v38` 仅新增本审计文档）。
- SleepDown 自定义非商业许可已遵守：只学习原理，不复制实现。
- 私有 API 反射：仅做静态架构研究，**未建议、未设计任何反射调用**；小掌柜 PoC-4 继续公开 API 路线。
