# ColorOS 17 转场能力探测报告（PoC-4）

> 分支 `android/v3.8-sleepdown-coloros` · V3.8 Phase 2 Worker C
> 设计依据：`ANDROID_V38_DESIGN_SYSTEM.md` §1.5（转场系统）/ §2.3 / §5.2、
> `ANDROID_V38_ROADMAP.md` §3 PoC-4
> 代码：`ui/motion/OplusTransitionProbe.kt`（纯函数探测逻辑）、
> `ui/poc/transition/OplusProbeCollector.kt`（Android 只读采集）、
> `ui/poc/transition/TransitionPocScreen.kt`（`poc/transition` 报告页）

## 0. 结论先行

1. **本轮零反射调用**：探测只用 `Class.forName` 存在性检查 +
   公开 `Build.*` 字段 + 公开 Activity 窗口模式 API；
   **未使用 `java.lang.reflect` 调用任何私有 API**（无用户授权，不做）。
2. **降级链已声明**：全部 7 组探测项的等效公开 API 降级路径一律为
   **FADE**（App 侧独立实现的 Compose NavHost FADE 转场，
   Phase 1 已由 `MotionPolicy` + `XzgMotionSpecs.NAV_PAGE_FADE` 接入生产导航，
   不依赖任何 OEM 私有能力）。
3. **真机证据为零**：下表「PKJ110 / ColorOS 17 真机」列**全部标 NOT VERIFIED**；
   模拟器/CI 列为依据探测逻辑的**预期值**（采集器尚未在模拟器上实际执行，
   纯探测逻辑已有 JVM 单元测试覆盖，见 §4）。
4. `OplusSeamlessBackend`（跨 Activity + 反射私有 API）**不搬用**：
   小掌柜是单 Activity + NavHost 架构，该方案无着陆点（Design System §1.5）；
   只借鉴其「具名失败 / 显式降级链」思想，本报告即该思想的产物。

## 1. 探测方法

| 手段 | 说明 | 是否反射私有 API |
|---|---|---|
| `Class.forName` 候选类名 | 只判断类是否存在；不获取方法/字段、不调用 | 否（公开 API 的存在性检查，任务书明确允许） |
| `Build.VERSION.SDK_INT` / `Build.MANUFACTURER` / `Build.DISPLAY` | 只读公开字段 | 否 |
| `Activity.isInMultiWindowMode` / `isInPictureInPictureMode` | 公开 API | 否 |
| 预测性返回的**系统级**开关 | **无公开 API 可读** → 采集为 null，探测项具名为 `predictive-back-system-state-unknown`，**不猜测** | 否 |

候选类名（`OPLUS_CLASS_CANDIDATES_UNVERIFIED`，**未验证候选**）：
`com.oplus.content.OplusFeatureConfigManager`、
`com.oplus.os.OplusBuild`。
其存在性是「Oplus 私有转场 API 路径可达」的前置条件；
类名本身未经真机验证，真机探测时以实际存在性为准。

`Build.DISPLAY` 解析 ColorOS 主版本号是启发式
（正则 `(?:ColorOS|V)[\s_]?(\d+)`，大小写不敏感）；
解析不到时具名为 `coloros-version-unparseable`，不猜测、不回退默认值。

## 2. 探测项 × 具名结果

> 图例：✅=Ok（预期/断言通过）；❌=具名 Unsupported；
> **NOT VERIFIED** = 无真机证据；「预期」= 依据探测逻辑推导，采集器尚未在该环境实际执行。

| # | 探测项 id | 具名结果（成功/失败原因） | 模拟器/CI（API 35 x86_64） | PKJ110 / ColorOS 17 真机 | 公开 API 降级链 |
|---|---|---|---|---|---|
| 1 | `hardware-acceleration` | `Ok` / `transition-requires-hardware-acceleration` | ✅ 预期 Ok | **NOT VERIFIED** | FADE |
| 2 | `api-level` | `Ok` / `oplus-api-level-below-33` | ✅ 预期 Ok（API 35） | **NOT VERIFIED** | FADE |
| 3 | `device-family` | `Ok` / `not-oplus-family-device` | ❌ 预期 `not-oplus-family-device`（模拟器 manufacturer 非 Oplus 系） | **NOT VERIFIED** | FADE |
| 4 | `coloros-version` | `Ok` / `coloros-version-unreadable` / `coloros-version-unparseable` / `coloros-below-17` | ❌ 预期 `coloros-version-unparseable`（模拟器 DISPLAY 无 ColorOS 标记） | **NOT VERIFIED** | FADE |
| 5 | `oplus-class:OplusFeatureConfigManager` | `Ok` / `oplus-class-missing:OplusFeatureConfigManager` | ❌ 预期 missing | **NOT VERIFIED** | FADE |
| 6 | `oplus-class:OplusBuild` | `Ok` / `oplus-class-missing:OplusBuild` | ❌ 预期 missing | **NOT VERIFIED** | FADE |
| 7 | `predictive-back` | `Ok` / `predictive-back-unsupported-below-api-33` / `predictive-back-disabled-by-system` / `predictive-back-system-state-unknown` | ❌ 预期 `predictive-back-system-state-unknown`（无公开 API 可读系统开关） | **NOT VERIFIED** | FADE |
| 8 | `window-mode` | `Ok` / `window-mode-freeform-no-gesture-transition` / `window-mode-pip-no-gesture-transition` | ✅ 预期 Ok（全屏） | **NOT VERIFIED** | FADE |

注：`predictive-back` 在 API 33+ 真机上即使系统支持，
当前采集也只能得到 `predictive-back-system-state-unknown`——
这是**诚实设计**，不是缺陷：无公开 API 可读就不声称可读。
若用户后续明确授权反射路径，可补测系统属性/私有 API 的方法级存在性，
但即便如此，生产转场仍走 FADE（Roadmap §3 PoC-4 合入标准②）。

## 3. 反射路径的降级链声明

凡涉及反射 Oplus 私有转场 API 的路径（**当前无授权、未实现、未合入**），
其等效公开 API 降级链声明如下（单源，`OplusProbeItem.fallback`）：

- 私有无缝转场（跟手/共享元素跨 Activity）→ **FADE**
  （`XzgMotionSpecs.NAV_PAGE_FADE`，Phase 1 已接入生产导航）；
- 预测性返回手势的系统级跟手效果 → **FADE** + 系统默认返回行为
  （不拦截、不自定义，做最小公分母）；
- 任何 OEM 私有转场能力缺失 → **FADE**，并以具名原因写日志
  （`MotionPolicy` 降级链思想，不静默）。

**授权声明**：未经用户明确授权，不得合入任何反射调用
（含 `Method.invoke`、`Field.get`、JNI 等一切形式）。
授权前 PoC-4 只输出本探测报告（Roadmap §3 PoC-4 合入标准③）。

## 4. 测试证据

`OplusTransitionProbeTest`（JVM，`ui.motion`）：
25 个测试，覆盖全部探测分支的具名原因断言——
含 `coloros-version-unreadable/unparseable/below-17`、
`predictive-back-system-state-unknown`（禁止猜测为可用）、
`oplus-class-missing:<SimpleName>`、窗口模式三态、
「每个探测项 fallback 恒为 FADE」、「结果类型禁止裸 boolean」。

## 5. NOT VERIFIED 清单（需真机/模拟器实测）

- [ ] PKJ110 / ColorOS 17 真机上经 `xzg://poc` → `poc/transition`
      实际运行采集器，记录 8 项真实结果（含 DISPLAY 实际格式、
      候选类真实存在性）——**NOT VERIFIED**
- [ ] 模拟器 connectedTest 中实际执行 `OplusProbeCollector.collect`
     （预期结果见 §2「模拟器/CI」列）——**NOT RUN**
- [ ] 真机录屏：Compose NavHost FADE 转场 vs 系统返回手势的对比——**NOT RUN**
- [ ] 反射私有 API 的方法级存在性探测——**未授权，不做**

## 6. 许可证声明

独立实现，未复制 SleepDown 任何源码；
仅借鉴其「具名失败 / 显式降级链」设计思想（Roadmap §5 许可证声明）。
