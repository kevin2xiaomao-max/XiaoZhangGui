# Android V3.8 技术路线图（SleepDown-Schedule 设计语言 + Liquid Glass + Droplet Morph + ColorOS 17 原生交互 + AI 增强）

**状态：** Phase 0 路线图
**分支：** `android/v3.8-sleepdown-coloros`（基于 V3.7.1 `c2dc042`）
**配套规格：** `docs/ANDROID_V38_DESIGN_SYSTEM.md`

---

## 1. 愿景与非目标

### 1.1 愿景

V3.8 让「你的小掌柜」Android 版在**不改业务语义**的前提下，获得一套自己的 Motion 与材质语言：

- **SleepDown-Schedule 设计语言**：层级清楚、留白连续、材质有来源、前景成套、运动有来处（原理借鉴，独立实现）；
- **Liquid Glass**：三档玻璃材质（质感/性能/超级性能），Android 平台能力范围内的独立实现；
- **Droplet Morph**：锚点驱动的液滴式展开/收起，首批只用于 AI Sheet 与待办快捷菜单；
- **ColorOS 17 原生交互**：在 OPPO PKJ110 真机上验证可用的系统级交互（跟手返回、触感、系统动画节奏对齐），私有 API 能力只做探测与具名降级；
- **AI 增强**：只做**展示层**增强（确认卡的逐字段 before/after + 四色语义），**不碰执行链**。

### 1.2 非目标（明确写死，防止范围蔓延）

1. **不是 iOS V3.8 A+B 70/30 融合**：Android V3.8 走自己的 SleepDown-Schedule + ColorOS 路线，不跟随 iOS V3.8 的 A/B 融合方案。
2. **不复制 SleepDown 代码**：只学习原理（分层思想、降级链、具名失败），所有数值、实现、资源独立推导；详见 §5 许可证声明。
3. **不动 Room schema / Repository / AI 执行链**：V3.7.1 已验收的数据层与 AI 链路冻结（AgentCore→…→ExecutionJournal 五 tools 链路只做确认卡展示层升级）。
4. **不改信息架构**：四 Tab（首页/待办/日历/经营）不动；`FloatingTabDock` 是否启用是独立决策，不在本路线图内。
5. **不做 WebView、不做破坏性 migration**：延续 V3.7.1 红线。
6. **SleepDown 的 `OplusSeamlessBackend` 不搬用**：跨 Activity + 反射 OEM 私有 API 的方案在小掌柜单 Activity + NavHost 架构下无着陆点；只做 PoC-4 的能力探测。

---

## 2. Phase 1→4 划分

> 每个动效/材质必须有**回退开关**：MotionSpec 中预先声明降级路径 + 运行时可关闭。无回退开关的动效不允许合入生产页面。

### Phase 1：地基（MotionSpec 框架 + 材质声明 + 能力探测）

- **目标**：把 Design System §2.3 的 MotionSpec/MotionPolicy、§2.1 的材质声明、三档降级链变成可运行的基础设施；零视觉变化。
- **交付物**：
  1. `MotionSpec` 数据类 + `MotionPolicy.resolve()`（transitionKind/时长档/降级链/具名失败原因）；
  2. `probeGlassCapability()` / `probeTransitionCapability()`（返回具名失败原因，非 Boolean）；
  3. 运行时帧率采样 + 自动降档（单向降级，只降不升）；
  4. Reduce Motion 全链路复核（`ANIMATOR_DURATION_SCALE==0` 时所有新动效退化）；
  5. 设计评审检查表（Design System §4）纳入合入流程。
- **验收标准**：JVM 单元测试覆盖 resolve() 的全部降级分支（含具名失败原因断言）；现有 E2E 0 回归；无任何像素变化（Paparazzi 基线对比 0 diff）。
- **回退开关**：`MotionPolicy` 全局总开关（关闭 → 全 App 回到 V3.7.1 行为：瞬切+无玻璃）；各 MotionSpec 独立开关。

### Phase 2：PoC 验证（四个 PoC，全部达标才允许进生产页面）

- **目标**：在隔离的 PoC 页面/ Demo 入口中验证四项高风险能力，输出**真实运行证据**（视频/截图/帧率数据）。
- **交付物**：PoC-1~PoC-4（清单与合入标准见 §3）。
- **验收标准**：每个 PoC 达到 §3 的合入标准；未达标的 PoC 不得进入 Phase 3，其对应的生产升级点从路线图中移除或延期（**不许"先合入再优化"**）。
- **回退开关**：PoC 代码与生产页面物理隔离（独立 navigation route，release 构建可编译开关剔除）。

### Phase 3：四页面升级落地

- **目标**：将达标的 PoC 按 Design System §3 的四页面提案逐页落地：首页 AI Sheet 液滴展开、待办勾选触感+动画、日历周切换双轨、经营数字 Motion。
- **交付物**：四页面的 MotionSpec 声明 + 实现 + 前后对比（录屏/Light-Dark 截图/帧率数据）。
- **验收标准**：
  1. 每个升级点满足 Design System §3 的验收标准；
  2. CI 全绿（JVM + E2E 0 失败）；
  3. R01–R29 可达/返回路径无变化（Matrix 复核）；
  4. OPPO 真机（PKJ110/ColorOS 17）实测：帧率、触感、Reduce Motion 行为；真机未测项标 NOT RUN。
- **回退开关**：每页独立的 MotionSpec 开关；线上问题可在不发版的情况下通过远程配置关闭单页动效（实现方式 Phase 3 定，降级路径 Phase 1 已预留）。

### Phase 4：AI 确认卡展示层 + 验收交付

- **目标**：AI 确认卡升级为逐字段 before/after + 四色语义（蓝移/红删/黄改名/绿新增）；全量验收与交付。
- **交付物**：
  1. 确认卡新展示层（**只动展示层**，ActionProposal→用户确认→执行的链路不动）；
  2. V3.8 验收报告（含 PoC 证据链、四页前后对比、真机 NOT RUN 清单）；
  3. 签名/APK 交付（沿用 V3.7.1 持久签名证书方案，**正式密钥不上仓库**）。
- **验收标准**：确认卡字段级对比在 5 tools 的提案类型上全覆盖；AI 执行链 E2E 0 回归；用户在真机上完成一次"提案→确认→执行"闭环。
- **回退开关**：确认卡展示层开关（关闭 → 回到 V3.7.1 确认卡样式，链路不变）。

---

## 3. PoC 清单（Phase 2）

| PoC | 内容 | 验证方法 | 合入标准（达到才允许进生产页面） |
|---|---|---|---|
| PoC-1 液滴按钮菜单 | 待办页 QuickAction 菜单从按钮锚点做液滴展开/收起（§2.2 六层动作） | ① 实际运行录屏（正常速+0.25 慢放）；② Light/Dark 展开中途+稳定态截图；③ 帧率数据（展开全程采样） | ① 慢放逐帧符合 Phase B–F 顺序，反例清单零命中；② 全程 ≥55fps（低端档降级为 FADE 时也 ≥55fps）；③ Reduce Motion 下为短淡入；④ 评审检查表全勾 |
| PoC-2 玻璃材质 | AI Sheet 背景的 T1/T2/T3 三档玻璃（静态模糊快照 / 低采样模糊 / 半透明+hairline） | ① 三档各 Light/Dark 截图共 6 张；② 对比度计算（三档文字对比度落在同一区间）；③ 帧率数据；④ 降级切换录屏（T1→T2→T3） | ① 三档几何（圆角/层级/间距）像素一致；② 对比度守恒达标；③ T1 在目标机型上 ≥55fps，否则该机型默认 T2；④ 降级链具名日志可查 |
| PoC-3 连续形变 | 一个独立 Demo：卡片在拖拽/展开中连续形变（圆角跟随运动包络、前缘锥度、末段一次过冲、稳定态释放） | ① 实际运行录屏；② 慢放检查圆角包络与过冲次数；③ 稳定态截图与标准 token 对比 | ① 过冲仅一次、幅度 <3%；② 动画结束 200ms 后圆角/裁切回到 token 标准值（截图取色+布局断言）；③ 无临时快照/离屏壳残留（内存断言或代码审查） |
| PoC-4 OPPO 私有转场验证 | 探测 ColorOS 17 单 Activity 内可用的转场能力（跟手返回、系统动画节奏）；**如涉及反射私有 API，需用户明确授权后才做** | ① 能力探测报告（具名成功/失败原因清单）；② 真机录屏（PKJ110）；③ 与 Compose NavHost FADE 转场的对比 | ① 输出《ColorOS 17 转场能力探测报告》（可用/不可用均具名）；② 凡反射私有 API 的路径必须有等效的公开 API 降级链；③ 未经用户授权不得合入任何反射调用——授权前 PoC-4 只输出探测报告 |

**PoC 通用规则**：
- PoC 与生产页面物理隔离（独立 route），release 可编译剔除；
- 每个 PoC 必须输出：1 段运行视频 + Light-Dark 截图 + 帧率数据 + 具名降级日志；
- 合入标准是硬门槛：**未达标 = 不进生产页面**，对应的四页面升级点延期或移除，不许"先合入再优化"；
- 真机（OPPO PKJ110）未跑过的 PoC 项标 NOT RUN。

---

## 4. 与 `android/v3.7.1-oppo-port` 验收修复轮的关系

1. **基线关系**：V3.8 分支 `android/v3.8-sleepdown-coloros` 从 V3.7.1 `c2dc042` 建出；V3.7.1 验收修复轮在 `android/v3.7.1-oppo-port` 上独立进行。
2. **合并策略**：验收修复轮的结论逐项评估后按需 cherry-pick/merge 到 V3.8（例如 ScheduleTimelineRow 图标 bug 修复、日历「日程」标题口径收敛）；合并时以"不破坏 V3.8 MotionSpec 声明"为前提，冲突处以验收修复（正确性）优先。
3. **冻结区**：Room schema、Repository、AI 执行链（AgentCore→…→ExecutionJournal）在 V3.8 全程冻结；V3.8 只做展示层与 Motion/材质层加法。
4. **签名与交付**：V3.8 最终 APK 沿用 V3.7.1 的持久签名证书方案（`~/workspace/xzg-signing/` 仓库外保管，正式密钥不上仓库）；CI 签名口径不变。

---

## 5. 许可证遵守声明

1. **只学习原理，不复制实现**：Phase 0 研究结论为原理转述（设计分层、降级链、具名失败、动作相位思想）；未复制 SleepDown 的任何源码、资源文件、数值参数或私有 API 调用方式。
2. **独立实现**：V3.8 的所有 Motion 数值基于 V371 时长档（100/180/280/420ms）重新标定；玻璃材质基于 Android 平台能力（RenderEffect/半透明/hairline）独立设计三档语义；转场系统基于 Compose NavHost 与单 Activity 架构独立设计。
3. **P2 实验代码隔离**：任何源自 SleepDown 原理验证的实验代码只存在于 PoC 隔离区（独立 route，release 可剔除），不进入生产页面；PoC 转正时按"独立实现"标准重写，不允许把实验草稿直接合入。
4. **OplusSeamlessBackend 不搬用**：跨 Activity 拦截 + 反射 OEM 私有 API 的方案与小掌柜架构无着陆点，仅借鉴"具名失败原因/降级链"思想；任何反射私有 API 的尝试需用户明确授权。
5. **后续义务**：如 V3.8 开发中发现需要参考 SleepDown 具体实现的情形，须先停下并向用户报告，由用户决定是否继续；不擅自扩大借鉴范围。

---

*文档版本：Phase 0 v1.0 ｜ 2026-10-15*
