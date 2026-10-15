# Android V3.8 `ui/motion/` + `ui/poc/` 代码审查报告

- 审查人：Worker E（只读审查，未改任何代码）
- 审查基线：分支 `android/v3.8-sleepdown-coloros` @ `e8593e9`（Phase 2 完成态）
- 审查日期：2026-10-16
- 审查对象：
  - `android/app/src/main/java/com/xiaozhanggui/app/ui/motion/`（8 文件：MotionSpec / MotionPolicy / MotionContext / Capability / FrameRateMonitor / FrameRateSampling / ReduceMotion / OplusTransitionProbe）
  - `android/app/src/main/java/com/xiaozhanggui/app/ui/poc/`（21 文件：PocGate / PocNav / PocMotionMath + droplet 5 / glass 7 / morph 4 / transition 2）
  - 附带核验：`ui/components/V38MotionDeclarations.kt`（23 条生产 Spec 注册表）、`XzgMotionWiring.kt`（生产接线）、`ui/theme/ReduceMotion.kt`（系统开关接线）、`build.gradle.kts`（POC_ENABLED）、`XzgNavGraph.kt` / `XzgDeepLink.kt`（隔离接线）
- 设计依据：`docs/ANDROID_V38_DESIGN_SYSTEM.md` §2（规格）、§4（评审检查表）、§5（具名失败）；`docs/ANDROID_V38_ROADMAP.md`（冻结声明、PoC 合入标准、许可证红线）

> 说明：审查时工作区正处于 coordinator 的 V3.7.1 cherry-pick 中（commit `c685da7`，3 个 Screen 文件有冲突未解决）。本审查只针对已提交基线 `e8593e9`，未触碰任何冲突文件；另有并行 Phase 3 准备 track 的未跟踪文件 `ui/poc/prep/`（PrepGate/PrepSwitches/四页 Prep + 测试），**不在本次审查基线内**，仅在此声明存在。

---

## 1. 架构审查

### 1.1 模块划分：清晰 ✅

| 文件 | 职责 | 评价 |
|---|---|---|
| `MotionSpec.kt` | 动效声明（设计意图 + 预声明降级路径） | ✅ `fallbackKind` 无默认值，构造强制传入——编译期强制而非文档约定 |
| `MotionPolicy.kt` | 纯函数决议器（0→5 优先级降级链） | ✅ 单例 object，`resolve` 纯函数，JVM 可测 |
| `MotionContext.kt` | 运行时上下文（值语义） | ✅ 只消费档位不决定档位（PerfTier 判定明确归 Phase 3） |
| `Capability.kt` | 能力探测（密封接口） | ✅ 无裸 Boolean，`Ok` / `Unsupported(reason)` 具名 |
| `FrameRateMonitor.kt` + `FrameRateSampling.kt` | 核心采样逻辑（纯 Kotlin，时钟可注入）与 Choreographer 接线分离 | ✅ 平台相关只在接线层 |
| `ReduceMotion.kt` | `ANIMATOR_DURATION_SCALE → Bool` 纯函数 | ✅ 判定逻辑收敛一处，`ui.theme` 只做取值 |
| `OplusTransitionProbe.kt` | PoC-4 探测纯函数（输入全注入） | ✅ 零反射调用，类存在性只做 `Class.forName` |
| `PocMotionMath.kt` | PoC 共享纯运动数学 | ✅ smoothstep / phaseProgress / singleOvershoot，端点精确 |

### 1.2 职责边界：清晰 ✅

- **Spec 声明 → Policy 决议 → 调用方只按"是否降级"分支**：`XzgMotionWiring.xzgPressFeedback` 的实现是范本——`val motionOn = enabled && resolved.downgradeReason == null`，调用点不重复实现降级逻辑。
- **Phase 1 生产声明与 PoC 声明物理分离**：`XzgMotionSpecs.all`（23 条，测试强制全 FADE）vs `DropletSpecs` / `MorphSpecs`（独立存放，注释明确"不进 Phase 1 注册表"，随 PoC 受 `PocGate` 编译门约束）。
- **旧系统零侵入**：`ResolvedMotion.baseMotion` 复用 `V371Motion.resolve`，旧 `when (baseMotion)` 调用方零改动；新字段只做加法。符合 Roadmap"V371 只做加法"冻结要求。

### 1.3 降级链单向只降不升 ✅

- `MotionPolicy.resolve`：0→5 优先级，`costRank()`（NATIVE 0 < FADE 1 < SHARED_ANCHOR 2）单调降；任何降级路径把 `overshoot` 强制压到 `NONE`（"页面必单调"）；命中多条时 `downgradeReason` 记录优先级最高者。
- `FrameRateMonitor`：`downgraded` 一旦置 true 同一前台会话不再升回；`reset()` 只在回到前台时恢复。
- `GlassMaterialDeclaration.init` 用 `require(fallback.zipWithNext()...)` 在构造期强制 fallback 单向。
- **未发现任何"升级"路径。**

### 1.4 无裸 Boolean 探测 ✅

- `CapabilityResult` 密封接口：所有探测（玻璃/转场/Oplus 7 项/ PoC-2 低内存分支）返回 `Ok` 或 `Unsupported("具名原因")`，原因可直接写日志、可单测断言。
- 唯一例外是 `FrameRateMonitor` 内部状态（非探测）和 `MotionContext` 默认值，均非"探测"，不违规。

---

## 2. 正确性审查

### 2.1 FrameRateMonitor 边界条件 ✅（无 bug）

- `fps = (frameTimes.size - 1) * 1000.0 / spanMs`：`size < 2` 提前 return；`spanMs < 1000` 不判定 → **无除零可能**（突发同 ms 多帧时 `spanMs=0` 走 `< lowDurationMs` 分支返回）。
- 阈值语义与文档逐字对齐：`fps < 55.0`（恰 55.0 不触发）；`now - lowSince >= 1000`（持续满 1s）。
- 低帧率恢复时清零 `lowSinceMs` 但已降档位不升回（单向）；`downgraded=true` 后 `else if (!downgraded && ...)` 保证会话内只降一次。
- `reset()`：恢复上限、清空窗口；`foreground-reset` 事件只在确实降过档时记录，不触发 `onDowngrade`（已文档化，不对称是有意的）。

### 2.2 Reduce Motion 全覆盖 ✅（实现完整，见 P2 备注）

- 系统信号：`Settings.Global.ANIMATOR_DURATION_SCALE`，`ContentObserver` 实时响应开关变化（含注册后重读防竞态）。
- 判定收敛：`ui.motion.isReduceMotionEnabled(scale)` 纯函数，`ui.theme` 只做取值，不分叉；JVM 单测覆盖。
- 接线点：`MotionPolicy` step 1（→FAST 短淡入/无位移无过冲）、`GlassResolve` step 0（→T3）、`DropletResolver`（经 Policy）、`xzgPressFeedback` / `XzgDropdownMenu` / `XzgAlertDialog` / `rememberXzgModalBottomSheetState`（Reduce Motion 时初始值 Expanded 直接呈现）。
- P2 备注：只检查了 `ANIMATOR_DURATION_SCALE`，未查 `TRANSITION_ANIMATION_SCALE` / `WINDOW_ANIMATION_SCALE`；Dialog/DropdownMenu 的平台侧动画依赖框架服从系统缩放（已在 KDoc 中声明为设计假设）。

### 2.3 fallbackKind 全声明 ✅

- `MotionSpec.fallbackKind` 无默认值——编译器强制每条声明显式传入。
- 逐条核验：`XzgMotionSpecs.all` 23 条（1 button + 5 menu + 16 dialog + 1 nav）全 FADE、全带 `fallbackKind = FADE`（`V38MotionSpecTest.every spec declares a fade fallback kind` 强制）；PoC 2 条（`DropletSpecs.MENU_EXPAND` SHARED_ANCHOR→FADE、`MorphSpecs.CARD_MORPH` FADE→FADE）全声明。
- `DropletResolver` 正确处理了 `MotionPolicy` 的 motion-disabled 陷阱（见 §6 P2-1）：disabled 时 Policy 返回的 kind 仍是声明值，必须同时检查 `downgradeReason`——Resolver 做了，注释写清了原因。

### 2.4 masterEnabled 总开关 ⚠️（P1，见 §6 P1-2）

- 语义正确：`@Volatile` 跨线程可见；关闭时 `resolve` 返回 `baseMotion=NONE` + `tier=INSTANT` + 具名 `motion-disabled`，`xzgPressFeedback` 按 `downgradeReason != null` 关动画 → 技术上确实一键回退到 V3.7.1 行为。
- **但无生产接线**：全仓库只有 `MotionPolicy.kt` 自身读写它（测试除外），无设置页/远程配置/开发者选项入口。当前"一键回退"只能靠改代码重编。

---

## 3. 隔离审查

### 3.1 生产页对 `ui/poc` 的引用：干净 ✅

`grep -rln "ui\.poc\|PocGate\|pocGraph\|PocRoutes" main源`（排除 `ui/poc/` 自身）仅命中两处：

1. `ui/navigation/XzgNavGraph.kt`——**批准的隔离接线**：`if (BuildConfig.POC_ENABLED) pocGraph(navController)` 注册 route；冷/热启动深链导航同样被 `BuildConfig.POC_ENABLED` 守卫。
2. `ui/motion/OplusTransitionProbe.kt:14`——**KDoc 注释**中提到 `ui.poc.transition.OplusProbeCollector`，非代码引用。

生产 Screen（`ui/screens/**`）**零引用**。`PocGate.enabled` 目前未被生产代码引用（XzgNavGraph 直接用 `BuildConfig.POC_ENABLED`），属轻微冗余（P2-7）。

### 3.2 release 构建剔除：基本成立，有措辞缺口（P2-6）

- `build.gradle.kts`：`debug` 默认 `POC_ENABLED=true`；`release` 覆盖 `POC_ENABLED=false`。
- `POC_ENABLED=false` 时：`pocGraph` 不注册 route、深链 `xzg://poc` 在 `XzgDeepLink.route(pocEnabled=false)` → `Ignore`、冷/热启动均不导航。
- **缺口**：PoC 代码在 main source set 内，`isMinifyEnabled=false`（无 R8），PoC 类仍会打包进 release dex——"不从任何生产路径可达"成立，但"剔除"字面不精确。建议改措辞为"隔离/不可达"，或 Phase 3 将 PoC 移入 debug source set。

---

## 4. 冻结审查 ✅

`git diff c2dc042..HEAD -- data/ domain/`（V3.7.1 基线 → Phase 2 完成）：

- `data/db/`、`data/repository/`、`domain/ai/`、`data/ai/`：**零改动**（diff 为空）。
- 整个 `data/` + `domain/` 树：**零改动**。
- 有改动的文件全部落在 `ui/`（motion/poc/components/screens/navigation/theme）、`build.gradle.kts`、`.github/workflows`、测试与 `docs/`——符合"V371 只做加法、冻结区零改动"的 Roadmap 要求。

---

## 5. 许可证审查 ✅（未发现复制嫌疑）

- **独立标定声明**：`PocMotionMath` / `DropletPhases` / `MorphEnvelope` / `OplusTransitionProbe` 的 KDoc 均明确声明数值独立推导、未复制 SleepDown 的 260ms / 2.2% / 3.5% 等数值。
- **数值核验**：过冲幅度 0.025（2.5%，`singleOvershoot` 构造强制 ≤0.03）、相位边界为 280ms 内的无量纲分数（0.05/0.25/0.30/0.70/0.85/0.95…）、玻璃 alpha 0.42/0.62/0.82 严格单调、稳定态释放 200ms——均为圆整设计取值，与 SleepDown 公开讨论数值无对应关系。
- **实现核验**：`smoothstep` / `sin(πp)` 包络 / 相位子进度为通用数学，无特征性代码结构；`OplusSeamlessBackend`（反射私有 API）未被引用；PoC-4 明确"零反射调用私有 API"（`Class.forName` 仅存在性检查，有测试约束意图）。
- **局限**：SleepDown 源码不在工作区内，无法做逐行比对；以上结论基于"通用数学 + 圆整数值 + 无特征结构"的代码内证据。建议保留现有 KDoc 声明口径。

---

## 6. 问题清单

### P0（必须修）：0 个

未发现阻塞真机验收的正确性/架构问题。

### P1（建议修）：2 个

**P1-1：玻璃能力降级链在 API<31 设备上会停在不可用的 T2**

- 位置：`ui/poc/glass/GlassResolve.kt`（`resolveGlassTier` step 3）vs `ui/poc/glass/GlassTier.kt`（`T2_BALANCED` KDoc）
- 原因：`minSdk=26`。`probeGlassTierCapability` 在 API<31 / 无硬件加速 / 低内存时返回 `Unsupported`；但 `resolveGlassTier` step 3 只在 `tier == T1_FIDELITY` 时降一档到 T2，且注释声称"T2/T3 不需要 RenderEffect"。而 `GlassTier.T2_BALANCED` 的 KDoc 写明真机分支用 `RenderEffect`（缩放 0.5 + 8dp blur）——API<31 上 T2 同样不可用，正确终点应是 T3。降级链在 API 26–30 上停在"降了但还不可用"的档位。
- 建议：能力失败时若 `apiLevel < 31` 直接降到 T3；或明确 T2 在无 RenderEffect 时的等效实现（静态半透明 + 双层 hairline）并在 resolve 中表达该分支。目标机（ColorOS 17 / API 35）不受影响，不阻塞真机验收，但应在 Phase 3 真机接线前修复。

**P1-2：`masterEnabled` 总开关无生产接线，"一键回退"目前只能改代码重编**

- 位置：`ui/motion/MotionPolicy.kt:92`
- 原因：`@Volatile var masterEnabled` 语义正确（关闭 → `motion-disabled` 全回退），但全仓库无生产调用方可翻转它（只有测试）。"真能一键回退"在技术上成立、在操作上不成立。
- 建议：Phase 3 接线远程配置/设置页开关；过渡期至少提供 BuildConfig 或开发者选项入口，并在验收报告中如实标注当前状态。

### P2（可延后）：7 个

**P2-1：`MotionPolicy` motion-disabled 分支返回声明 kind，是调用方足陷阱**

- 位置：`ui/motion/MotionPolicy.kt:104-113`
- 原因：总开关关闭时返回 `transitionKind = spec.transitionKind`（可能为 `SHARED_ANCHOR`），调用方若只读 `transitionKind` 不读 `downgradeReason`，会误跑液滴相位。`DropletResolver` 已正确处理（注释 + 双条件检查），但 API 本身在"奖励"错误用法。
- 建议：disabled 时返回 `kind = FADE`（或新增显式 `motionDisabled: Boolean` 字段），让错误用法默认安全。

**P2-2：硬件加速探测被硬编码**

- 位置：`ui/poc/transition/OplusProbeCollector.kt:41`（`hardwareAccelerated = true`）；`XzgMotionWiring` 构造的 `MotionContext` 只传 `reduceMotion`，`perfTier`/`capabilities`/`runtimeMaxTransitionKind` 全用默认值
- 原因：降级链第 2/4/5 级在生产路径当前恒为"未触发"。属 Phase 3 接线范围，但应在 Phase 3 准备报告中列为前置项：`View.isHardwareAccelerated` / Window 标志的真实读取、PerfTier 判定（内存/SoC/省电模式）、FrameRateSampling 的全局（非仅动画期间）采样。

**P2-3：`MorphRuntimeState.dragMaxPx` 默认 1f，传 0 会导致 NaN**

- 位置：`ui/poc/morph/MorphRuntimeState.kt:36-37`
- 原因：`dragProgress = abs(dragOffsetPx) / dragMaxPx`，`dragMaxPx=0` → NaN（虽被 `coerceIn` 钳制，NaN 比较恒 false 会原样漏出）。
- 建议：`require(dragMaxPx > 0f)` 或分母保底。PoC 内调用方可控，延后无妨。

**P2-4：`xzg://poc` 的 intent-filter 在 release 构建仍静态声明**

- 位置：`android/app/src/main/AndroidManifest.xml:54`
- 原因：release 下深链解析为 `Ignore`（无操作），无害，但外部仍可调起 App（空转）。如追求严格隔离，可用 manifest placeholder 按 buildType 移除。

**P2-5：`parseColorOsMajorVersion` 在真机 DISPLAY 格式上未验证**

- 位置：`ui/motion/OplusTransitionProbe.kt:parseColorOsMajorVersion`
- 原因：正则 `(?:ColorOS|V)[\s_]?(\d+)` 依赖 `Build.DISPLAY` 含版本串；OPPO 真机 DISPLAY 格式未经实测。若解析失败，PoC-4 在目标机上的 `coloros-version` 项将是具名失败而非 Ok——设计已诚实处理（不猜测），但真机验收时需先确认 DISPLAY 实际格式，必要时调整。

**P2-6：release"剔除"措辞不精确**（见 §3.2）——PoC 类仍打包进 dex（`isMinifyEnabled=false`）。建议改措辞或移入 debug source set。

**P2-7：`PocGate.enabled` 未被生产代码引用**（`ui/poc/PocGate.kt`）——XzgNavGraph 直接用 `BuildConfig.POC_ENABLED`。二选一收敛，避免双开关分叉。

---

## 7. 审查结论

**结论：达到可进真机验收标准。**

- 架构：模块划分与职责边界清晰，降级链单向只降不升，无裸 Boolean 探测；`fallbackKind` 编译期强制，23 条生产 Spec + 2 条 PoC Spec 逐条声明。
- 正确性：`FrameRateMonitor` 边界条件逐项核验无 bug（无除零、阈值语义与文档逐字对齐、单向降档）；Reduce Motion 接线完整（含 ContentObserver 实时响应）；冻结区（`data/`/`domain/` 全树）零改动；生产页对 `ui/poc` 零引用（仅批准的 NavGraph 接线）。
- 许可证：数值独立标定的文档主张与代码一致，未发现复制外部代码嫌疑。
- P0 为零；2 个 P1（API<31 玻璃降级缺口、总开关无生产接线）均不命中目标机（ColorOS 17 / API 35），建议 Phase 3 接线前修复，不阻塞真机验收；7 个 P2 可延后。
- 真机 NOT RUN 项保持诚实：≥55fps 真机帧率、PoC-4 目标机探测、玻璃 T1 真机渲染，均未在真机验证，本报告不替代真机结论。

---

## 附：核验命令（可复现）

```bash
# 冻结审查
git diff c2dc042..e8593e9 --stat -- android/app/src/main/java/com/xiaozhanggui/app/data android/app/src/main/java/com/xiaozhanggui/app/domain
# → 空（零改动）

# 隔离审查
grep -rln "ui\.poc\|PocGate\|pocGraph\|PocRoutes" android/app/src/main/java --include="*.kt" | grep -v "ui/poc/"
# → 仅 XzgNavGraph.kt（批准接线）+ OplusTransitionProbe.kt（KDoc 注释）

# Spec 全声明
grep -c "MotionSpec(" android/app/src/main/java/com/xiaozhanggui/app/ui/components/V38MotionDeclarations.kt
# → 23 条生产声明（测试 V38MotionSpecTest 强制全 FADE / fallback / enabled）
```
