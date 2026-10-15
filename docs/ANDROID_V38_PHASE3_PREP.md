# Android V3.8 Phase 3 接入准备报告

**状态：** Phase 3 准备 track 交付（**只做准备，不接线生产页面**）
**分支：** `android/v3.8-sleepdown-coloros`
**设计依据：** `docs/ANDROID_V38_DESIGN_SYSTEM.md` §3（四页面升级提案）
**动效机制：** `ui/motion/`（MotionSpec / MotionPolicy / 具名降级 / Reduce Motion / masterEnabled 总开关）
**PoC 参考：** `ui/poc/`（PoC-1 液滴 / PoC-2 玻璃 / PoC-3 形变 / PoC-4 转场探测）

## 范围声明

- 本报告 + `ui/poc/prep/` 下的 Spec 草案代码 + `*Prep*Test` 测试草案 = 本次交付的**全部**。
  **没有**修改任何生产页面（`HomeScreen` / `TodoScreen` / `CalendarScreen` /
  `PerformanceScreen`）、**没有**改 Room / Repository / AI 执行链、
  **没有**改 `XzgMotionSpecs.all` 注册表（Phase 1 硬约束 transitionKind 一律 FADE，
  准备草案独立存放，不进入注册表）。
- 草案代码隔离规则：只放在 `ui/poc/prep/`（纯声明 + 纯函数数学），不引用生产页面组件，
  不被生产代码引用（grep 门禁：生产页禁止引用 `ui.poc` 下任何符号，见 PoC 报告）；
  随 PoC 代码一起受 `PocGate` 编译门约束（release 构建 PoC 不可达）。
- 数值独立标定：相位分数 / 过冲幅度 / 错峰步长均为本包独立推导，
  **未复制 SleepDown 的 260ms / 2.2% / 3.5% / 6组×18ms 等数值**（许可证红线）。
- 验收诚实标注：所有「录屏 / 真机帧率」验收项标 **NOT RUN**（§8）。

---

## 1. 首页（Home）——AICommandEntry → AI Sheet 液滴展开

### 1.1 升级点

`HomeScreen` 的 `AICommandEntry` 点击后，AI Sheet 从入口控件位置做液滴式展开
（SHARED_ANCHOR，Design System §2.2 六层动作）；收起时反向回到入口。
当前生产行为：Root 级 ModalBottomSheet 瞬现，与入口控件无视觉关联（"凭空出现"）。

### 1.2 MotionSpec 声明草案

| 项 | 值 |
|---|---|
| id | `v38.prep.home.ai-sheet-expand` |
| TransitionKind | `SHARED_ANCHOR`（仅 §2.2 批准的锚点展开场景） |
| DurationTier | `STANDARD`（280ms；§2.2 Phase C 纵向展开档） |
| fallbackKind | `FADE`（显式声明，无默认值） |
| 具名降级路径 | `no-anchor`（Phase A 无可见锚点）→ `reduce-motion` → `perf-tier-essential` → `dense-list` → `capability-unsupported:<reason>` → `frame-rate-below-55fps`；全部 → FADE |
| 独立开关名 | `prep.motion.home.ai-sheet-expand`（→ `MotionSpec.enabled`） |
| 过冲 | `CONTENT_ONLY`（Sheet 是浮层内容层；"内容可过冲、页面必单调"） |
| interruptible | true（展开中途收起反向续播，速度连续） |

材质声明草案（§2.1）：`Glass/T1`，Backdrop-Domain `home-feed`（采样首页静态内容域，
自采样在设计评审阶段拦截），Role `floating-sheet`，Fallback `T2 -> T3`。
背景静止时预构建一次 10dp 模糊快照（显隐只改 alpha，不按帧重建）；背景动态时降 T2。

草案代码：`ui/poc/prep/HomeAiSheetPrep.kt`（`EXPAND` / `AI_SHEET_GLASS` /
`resolveExpand(spec, ctx, anchor)` / 相位数学复用 PoC-1 已验证的 `DropletPhases`）。

### 1.3 §3.1 验收标准逐项

| # | 标准 | 验证方式（准备阶段） | 状态 |
|---|---|---|---|
| 1 | 录屏逐帧：Phase B–F 顺序正确，无"收缩播完才位移"、无"内容先出现" | JVM：`moveProgress(0.125)>0`（同起）、`contentAlpha(0.25)==0`（不抢跑）、相位边界精确 | ✅ JVM 草案通过；录屏逐帧 **NOT RUN** |
| 2 | Light/Dark 各 1 张展开中途截图 + 1 张稳定态截图，稳定态几何与现有 Sheet 一致 | JVM：`anchorScale(0/1)==1`、`cornerT(1)==1`、`panelOvershoot(1)==1`（稳定态释放临时形变）；截图对比 **NOT RUN** | 🟡 数学侧就绪，截图 NOT RUN |
| 3 | Reduce Motion 开启时退化为 FAST 短淡入 | JVM：`resolveExpandReduceMotion` → FADE + FAST + `reduce-motion` | ✅ JVM 草案通过；录屏验证 NOT RUN |
| 4 | 低端档（T3/ESSENTIAL）下为 FADE 无液滴，具名降级日志可查 | JVM：perfTier=ESSENTIAL → FADE + `perf-tier-essential` | ✅ JVM 草案通过；真机日志 NOT RUN |

### 1.4 回退开关设计

- `MotionPolicy.masterEnabled=false` → 全 App 回到 V3.7.1 瞬切（`motion-disabled`）；
- `EXPAND.enabled=false`（绑定 `prep.motion.home.ai-sheet-expand`）→ 仅 AI Sheet 展开回瞬切，
  其余三页动效不受影响；
- Phase A 无锚点 → 自动 FADE（`no-anchor`），不需要人工开关。

### 1.5 预计风险

1. **锚点几何获取时机**：`AICommandEntry` 的 `boundsInRoot` 需在点击时已布局；
   若在列表滚动中点击，锚点可能过期 → 已用 `no-anchor` 降级兜底，但频繁降级会让体验退化为普通淡入，
   Phase 3 接线时需加埋点统计降级率。
2. **Sheet 背景动态**：若 AI Sheet 展开时首页背景在动（如天气刷新），T1 快照语义不成立 →
   降级链已声明 `T2 -> T3`，但"背景动态"的判定逻辑 Phase 3 需接线（当前未定义）。
3. **ModalBottomSheet 锚点展开的手势冲突**：Sheet 的拖拽关闭手势与液滴收起动画可能打架；
   Phase 3 接线时建议：拖拽手势优先，动画 `interruptible` 反向续播已声明，需真机验证。
4. **真机帧率**：液滴六层动作 + T1 模糊在 ColorOS 17 真机上的帧率 NOT RUN，
   按 Roadmap §2 硬门槛，未达 ≥55fps 不得进生产（用户 2026-10-16 02:37 指令）。

---

## 2. 待办（Todo）——勾选的触感 + 状态动画

### 2.1 升级点

`TodoScreen` 的 `V32Checkbox` 行：① 按压瞬间触感反馈（Haptic，V371 唯一定义点）；
② 勾选框 ✓ 绘制动画（FAST 180ms，打钩路径动画）；③ 行内文字同步变为"已完成"样式
（删除线淡入，非瞬切）；④ 取消勾选反向播放。
图标语义冻结：完成=实心态（CheckCircle）、未完成=空心态——动画只表达过渡，
不改变图标语义（与 V3.7.1 验收修复轮 ScheduleTimelineRow 口径统一）。
当前生产行为：瞬切 + 无反馈 + 文字样式瞬切。

### 2.2 MotionSpec 声明草案

| 项 | 值 |
|---|---|
| id | `v38.prep.todo.toggle` |
| TransitionKind | `FADE` |
| DurationTier | `FAST`（180ms；§3.2 验收指定 FAST） |
| fallbackKind | `FADE`（本身即 FADE；降级 = 时长压档/清零过冲） |
| 具名降级路径 | `reduce-motion`（视觉直达终态，**触感保留**）→ `dense-list` → `frame-rate-below-55fps`；`motion-disabled`（开关关闭） |
| 独立开关名 | `prep.motion.todo.toggle`（→ `MotionSpec.enabled`） |
| 过冲 | `NONE`（行状态切换无过冲） |
| interruptible | true（绘制中途反向：勾选→取消反向播放） |

触感语义草案：`HAPTIC_TIMING = "press-instant"`——按压瞬间触发一次，与视觉绘制进度解耦；
触感不是视觉动效，Reduce Motion 下**仍保留**（§3.2 验收 #4）。

草案代码：`ui/poc/prep/TodoTogglePrep.kt`（`TOGGLE` / `checkDrawProgress` /
`strikeAlpha` / `titleDimT` / `reduceMotionSemantics`）。

### 2.3 §3.2 验收标准逐项

| # | 标准 | 验证方式（准备阶段） | 状态 |
|---|---|---|---|
| 1 | 勾选/取消各 10 次，触感每次触发 | JVM：`HAPTIC_TIMING="press-instant"` 语义常量；模拟器日志断言为 E2E 草案（§6.2） | 🟡 语义已声明；模拟器/真机 NOT RUN |
| 2 | 慢放录屏确认打钩路径动画完整播放、无跳帧 | JVM：`checkDrawProgress` 端点精确（0→0、1→1）+ 全区间单调（逐帧只向前绘制） | ✅ JVM 草案通过；慢放录屏 NOT RUN |
| 3 | 与日历/首页任务行的完成态图标语义一致（截图三处并排对比） | 草案不改变图标语义（只做过渡动画）；三处并排截图 NOT RUN | 🟡 语义冻结已声明；截图 NOT RUN |
| 4 | Reduce Motion 下：无绘制动画，直接切换终态（仍保留触感） | JVM：`reduceMotionSemantics` → `visualJumpsToEndState=true`、`hapticKept=true`（恒真） | ✅ JVM 草案通过 |

### 2.4 回退开关设计

- `TOGGLE.enabled=false`（绑定 `prep.motion.todo.toggle`）→ 勾选回到瞬切（V3.7.1 行为）；
- Reduce Motion 下自动直达终态，无需人工开关；触感独立于开关（系统级 Haptic 设置控制）。

### 2.5 预计风险

1. **300ms 防抖窗口**：`TodoScreen` 现有注释提到"300ms 防抖窗口内的点击在回调里直接忽略"；
   180ms 绘制动画 + 防抖窗口叠加时，快速连点可能出现"动画播完但第二次点击被吞"的主观卡顿感。
   Phase 3 接线时需把防抖与动画时长统一口径（建议防抖窗口 ≥ 动画时长）。
2. **触感与无障碍**：TalkBack 开启时系统可能已有操作反馈，叠加 Haptic 会不会冗余？
   Phase 3 需确认：无障碍模式下是否降级触感（倾向：保留，由系统 Haptic 设置统一控制）。
3. **删除线淡入的文字可读性**：删除线 + 灰色 + 淡入三重过渡在小字号下可能闪烁感；
   需 Light/Dark 截图评审（NOT RUN）。

---

## 3. 日历（Calendar）——周切换的双轨运动

### 3.1 升级点

`CalendarScreen` 周视图左右切换：页面容器周做单调滑动（无过冲，"页面必单调"），
日期格内容做分组错峰淡入（7 列每列一组，组间步长 12ms 独立标定）；
连续快速滑动时中途反转保持速度续播（解决动画排队卡顿——当前瞬切方案加入动画后
最可能引入的新问题，提前用规则堵住）。
当前生产行为：周切换瞬切（无动画）。

### 3.2 MotionSpec 声明草案（双轨）

| 项 | 容器轨 | 内容轨 |
|---|---|---|
| id | `v38.prep.calendar.week-container-slide` | `v38.prep.calendar.week-content-stagger` |
| TransitionKind | `FADE`（位移分量走滑动） | `FADE` |
| DurationTier | `FAST`（180ms；周切换高频手势） | `FAST`（与容器同窗 180ms） |
| fallbackKind | `FADE` | `FADE` |
| 具名降级路径 | `reduce-motion` → `dense-list` → `frame-rate-below-55fps` | 同左；`dense-list` 时内容错峰**退化为整面单调**（§1.4 借鉴 4.2） |
| 独立开关名 | `prep.motion.calendar.week-switch`（双轨共用一开关） | 同左 |
| 过冲 | `NONE`（铁律） | `NONE`（淡入不需要过冲） |
| interruptible | true（中途反转速度连续） | true |

错峰数学草案：`GROUP_COUNT=7`（周视图 7 日期列），`STAGGER_STEP_MS=12f`
（独立标定，**未复制 SleepDown 的 6组×18ms**；7×12=72ms < 180ms 窗，
最后一组启动后留 108ms 淡入）；`groupAlpha(p, g)` 在 `[delay, 1]` 窗口内 smoothstep。
中途反转：`tweenVelocity(p)=6p(1−p)`（smoothstep 一阶导数），
反转时新动画初速度取当前速度播种，无"急停再起"。

草案代码：`ui/poc/prep/CalendarWeekPrep.kt`（`CONTAINER_SLIDE` / `CONTENT_STAGGER` /
`groupDelayMs` / `groupAlpha` / `slideProgress` / `tweenVelocity` /
`resolveContainer` / `resolveContent`）。

### 3.3 §3.3 验收标准逐项

| # | 标准 | 验证方式（准备阶段） | 状态 |
|---|---|---|---|
| 1 | 慢/快两种速度滑动录屏：容器轨无过冲（逐帧位移单调），内容轨有可见错峰 | JVM：`slideProgress` 全区间单调；`groupAlpha(0.1, 0)>0` 且 `groupAlpha(0.1, 6)==0`（错峰可见） | ✅ JVM 草案通过；录屏 NOT RUN |
| 2 | 快速连滑 5 次无动画堆积、无卡顿（帧率 ≥55fps） | JVM：`interruptible=true` + 速度包络数学；帧率 NOT RUN | 🟡 数学侧就绪；真机帧率 NOT RUN |
| 3 | 中途反向滑动时速度连续（无"急停再起"） | JVM：`tweenVelocity(0.4)>0`（反转播种速度非零）；`v(0)=v(1)=0`、`v(0.5)=1.5` | ✅ JVM 草案通过；手势真机 NOT RUN |
| 4 | 标题「日程」vs Tab「日历」的不一致随本次一并收敛 | **归属 V3.7.1 验收修复轮口径**，V3.8 合并时确认；本准备包不碰 | ⏭️ 非本包范围 |

### 3.4 回退开关设计

- 双轨共用 `prep.motion.calendar.week-switch`：关闭 → 周切换回瞬切；
- `denseList=true`（当周事件卡片 > 10，由调用方在布局后计算传入）→ 内容轨自动退化为整面单调，
  具名 `dense-list`（无需人工开关）。

### 3.5 预计风险

1. **手势与动画的归属**：周切换是手势驱动（HorizontalPager 还是按钮？）——
   生产 `CalendarScreen` 当前是月视图 + 周标题行，**周视图左右切换手势在生产页尚无对应实现**。
   Phase 3 接线前必须先确认：是新增 WeekPager 手势，还是按钮切换？这决定动画是跟手还是程序化。
   **本草案按"程序化滑动 + 可中断"准备；若最终是跟手 pager，`tweenVelocity` 播种逻辑需重做。**
2. **12ms 步长的体感**：7 组 × 12ms 在 180ms 窗内是否"有可见错峰"而不显拖沓，
   只能真机/录屏判定（NOT RUN）；准备了 `STAGGER_STEP_MS` 单一常量，接线时可调。
3. **密集列表阈值**："卡片 > 10"的阈值是 Design System 借鉴值，未经真机测定；
   Phase 3 需按真机帧率实测调整（Roadmap §2 要求）。

---

## 4. 经营（Business）——数字的 Motion 呈现

### 4.1 升级点

`PerformanceScreen` 核心数字（Hero 卡本月营业额等）：① 数字变化时滚动递增/递减
（STANDARD 280ms，numeric 语义）；② 涨跌颜色只用状态色（涨/跌各一套，
不混用正文色体系，Design DNA 1.4）；③ 首次进入页面时数字从 0 滚动到实际值
（仅首次进入，非每次可见——避免廉价感）。
当前生产行为：数字瞬切。

### 4.2 MotionSpec 声明草案

| 项 | 值 |
|---|---|
| id | `v38.prep.performance.number-roll` |
| TransitionKind | `FADE`（numeric 滚动取最小公分母 FADE） |
| DurationTier | `STANDARD`（280ms；§3.4 验收 #1：时长落在 STANDARD ±20% 内） |
| fallbackKind | `FADE` |
| 具名降级路径 | `reduce-motion`（直接终值）→ `frame-rate-below-55fps`；`motion-disabled`（开关关闭） |
| 独立开关名 | `prep.motion.performance.number-roll`（→ `MotionSpec.enabled`） |
| 过冲 | `NONE`（过冲会读出错误金额——数字语义硬约束） |
| interruptible | true（数字连续变化时中途打断续播，不排队） |

涨跌语义草案：`trendOf(from, to, epsilon)` → `UP / DOWN / FLAT`（纯语义，
调用方映射到 V371 状态色 token；本包不引用颜色 token）。
时长验收换算：`standardDurationAcceptRangeMs()` = 224..336ms。

草案代码：`ui/poc/prep/PerformanceNumberPrep.kt`（`NUMBER_ROLL` / `rolledValue` /
`trendOf` / `standardDurationAcceptRangeMs` / `resolveNumber` /
`reduceMotionShowsEndValue`）。

### 4.3 §3.4 验收标准逐项

| # | 标准 | 验证方式（准备阶段） | 状态 |
|---|---|---|---|
| 1 | 数字从 0→目标值滚动过程录屏，时长落在 STANDARD 档 ±20% 内 | JVM：`standardDurationAcceptRangeMs()` = 224..336ms 区间数学；`rolledValue` 端点精确 + 单调 | ✅ JVM 草案通过；录屏 NOT RUN |
| 2 | 涨/跌/持平三种状态截图，颜色分别唯一对应状态色（取色验证） | JVM：`trendOf` UP/DOWN/FLAT（含 epsilon 阈值）；颜色映射是调用方职责，取色验证 NOT RUN | 🟡 语义侧就绪；截图/取色 NOT RUN |
| 3 | 二次进入页面无重播 | "仅首次进入"是调用方状态机职责（草案未包含页面状态机）；E2E 草案覆盖（§6.2） | 🟡 草案未覆盖，需 Phase 3 接线实现 |
| 4 | Reduce Motion 下直接显示终值 | JVM：`reduceMotionShowsEndValue()` 锚定既有语义 `V371Motion.resolve(NUMERIC, true)==NONE`（`MotionResolveTest` 回归） | ✅ JVM 草案通过 |

### 4.4 回退开关设计

- `NUMBER_ROLL.enabled=false`（绑定 `prep.motion.performance.number-roll`）→ 数字回瞬切；
- Reduce Motion 下调用方读到 `NONE` 立即应用终值（既有 `V371Motion.resolve` 语义，零新增）。

### 4.5 预计风险

1. **金额精度**：`rolledValue` 用 Double 插值，显示时需按金额格式取整/保留 2 位小数；
   插值中途的"¥12,345.678"式中间态必须格式化——这是调用方职责，草案只保证端点精确。
   Phase 3 接线时必须复用现有金额格式化（禁各处手写格式）。
2. **"首次进入"的状态机**：草案未包含（页面级状态，非动效数学）；
   Phase 3 需在 `PerformanceScreen`（或其 ViewModel）维护 `hasRolledOnce` 标志，
   注意进程重建/导航返回时的语义（返回页面不算"首次进入"）。
3. **连续快速变化**：金额在 280ms 内多次变化（如同步中）→ `interruptible` 续播，
   但频繁打断可能让数字"永远到不了终值"；Phase 3 需加"静默 300ms 后对齐终值"的兜底
   （当前草案未含，为已知缺口，见 §9）。

---

## 5. 草案代码清单

`android/app/src/main/java/com/xiaozhanggui/app/ui/poc/prep/`（新建包）：

| 文件 | 内容 |
|---|---|
| `PrepGate.kt` | 包级隔离声明：声明草案 + 纯函数，不接线生产页；`DECLARATION_ONLY=true` |
| `PrepSwitches.kt` | 四个独立开关名常量（`prep.motion.*`） |
| `PrepGlassMaterial.kt` | 玻璃材质声明载体（tier / backdropDomain / role / fallbackChain；自采样构造时拦截） |
| `HomeAiSheetPrep.kt` | §3.1：`EXPAND` Spec + `AI_SHEET_GLASS` + `resolveExpand`（Phase A no-anchor）+ 相位数学（复用 `DropletPhases`） |
| `TodoTogglePrep.kt` | §3.2：`TOGGLE` Spec + `checkDrawProgress` + `strikeAlpha` + `titleDimT` + `reduceMotionSemantics` |
| `CalendarWeekPrep.kt` | §3.3：`CONTAINER_SLIDE` / `CONTENT_STAGGER` 双轨 Spec + `groupDelayMs` / `groupAlpha` / `slideProgress` / `tweenVelocity` |
| `PerformanceNumberPrep.kt` | §3.4：`NUMBER_ROLL` Spec + `rolledValue` / `trendOf` / `standardDurationAcceptRangeMs` / `reduceMotionShowsEndValue` |

隔离审计：`grep -rn "screens\.\(home\|todo\|schedule\|performance\)" ui/poc/prep/` 应为零命中
（本包不引用生产页面）；`grep -rn "ui\.poc" ui/screens/` 应为零命中（生产页不引用本包）。

## 6. 测试草案

### 6.1 JVM 单元测试草案（`android/app/src/test/java/com/xiaozhanggui/app/ui/poc/prep/`）

| 文件 | 用例数 | 覆盖 |
|---|---|---|
| `HomeAiSheetPrepTest.kt` | 16 | Spec 字段；no-anchor/零尺寸锚点具名降级；reduce-motion/perf-essential/dense-list/frame-rate/master-off 五级分支；锚点收缩端点；位移同起（反例拦截）；纵向先行；内容不抢跑；过冲单峰<3%且回 1；圆角回 token；假时钟 60fps 不降档 |
| `TodoTogglePrepTest.kt` | 11 | Spec 字段；触感语义常量；绘制端点精确/单调/钳制；删除线不抢跑；标题同窗；无降级解析；Reduce Motion 终态+触感保留；独立开关关闭；dense-list |
| `CalendarWeekPrepTest.kt` | 14 | 双轨 Spec 字段；滑动单调；组延迟严格递增；错峰窗适配（108ms 余量）；小 p 错峰可见；全组 p=1 精确；逐组单调；速度包络零点/峰值/非负；反转播种速度；双轨无降级；dense-list 退化；reduce-motion；独立开关关闭 |
| `PerformanceNumberPrepTest.kt` | 12 | Spec 字段；插值端点精确/递增单调/递减单调/钳制；trend UP/DOWN/FLAT + epsilon；时长区间 224..336ms；无降级解析；Reduce Motion 终值语义锚定；perf-essential；独立开关关闭 |

合计 53 个用例。**本地执行状态：NOT RUN**（本机无 Java/Gradle；CI `testDebugUnitTest` 执行，
预期 0 失败）。`masterEnabled` 全局开关在每个用例后恢复（`@After`），不污染其他测试。

### 6.2 E2E 草案（Given / When / Then；设备执行，全部 NOT RUN）

**E2E-HOME-1 液滴展开**
- Given：首页已加载，`AICommandEntry` 可见；性能档 FULL；Reduce Motion 关闭。
- When：点击 `AICommandEntry`。
- Then：① AI Sheet 从入口位置展开（录屏逐帧：收缩与位移同起、内容在几何 1/4 后出现）；
  ② 稳定态 Sheet 几何与现有 ModalBottomSheet 一致（截图对比）；
  ③ 收起时反向回到入口。
- 断言点：`downgradeReason == null`（日志）；`no-anchor` 未触发。

**E2E-HOME-2 Reduce Motion**
- Given：系统"移除动画"开启。
- When：点击 `AICommandEntry`。
- Then：Sheet 以 FAST 短淡入出现，无位移/液滴；日志 `downgradeReason=reduce-motion`。

**E2E-HOME-3 低端档**
- Given：性能档 ESSENTIAL（或省电模式）。
- When：点击 `AICommandEntry`。
- Then：FADE 无液滴；玻璃为 T3（无模糊，半透明+hairline）；日志 `perf-tier-essential`。

**E2E-TODO-1 勾选**
- Given：待办页有一条未完成 Todo。
- When：点击其勾选框（重复 10 次勾选/取消）。
- Then：① 每次按压瞬间触感触发（模拟器用日志断言，真机手感）；
  ② 打钩路径 180ms 内完整绘制（慢放录屏无跳帧）；
  ③ 删除线在绘制 1/4 后淡入；④ 取消勾选反向播放。
- 断言点：完成态图标仍为 CheckCircle 实心（语义未变）。

**E2E-TODO-2 Reduce Motion**
- Given：系统"移除动画"开启。
- When：点击勾选框。
- Then：直接切换终态（无绘制动画），触感仍触发。

**E2E-CAL-1 周切换双轨**
- Given：日历页周视图。
- When：慢速滑动切换周；快速连续滑动 5 次。
- Then：① 容器滑动单调无过冲（慢放逐帧位移单调）；② 日期格有可见错峰；
  ③ 快速连滑无动画堆积；④ 帧率 ≥55fps（PoC 帧率数据口径）。
- 断言点：`dense-list` 未误触发（卡片 ≤10 时）。

**E2E-CAL-2 中途反转**
- Given：周切换滑动进行中。
- When：中途反向滑动。
- Then：速度连续，无"急停再起"（慢放逐帧速度曲线连续）。

**E2E-PERF-1 数字滚动**
- Given：经营页首次进入（`hasRolledOnce=false`）。
- When：页面加载完成。
- Then：① 核心数字从 0 滚动到实际值；② 录屏测滚动时长 ∈ [224, 336]ms；
  ③ 涨/跌/持平颜色唯一对应状态色（取色验证）。

**E2E-PERF-2 二次进入无重播**
- Given：经营页已滚动过一次。
- When：切到其他 Tab 再切回。
- Then：数字直接显示终值，无滚动重播。

**E2E-PERF-3 Reduce Motion**
- Given：系统"移除动画"开启。
- When：首次进入经营页。
- Then：数字直接显示终值，无滚动。

### 6.3 回退开关 E2E 草案

- Given：任一页面；When：将对应 `prep.motion.*` 开关置 false（或 `masterEnabled=false`）；
  Then：该动效回到 V3.7.1 行为（瞬切），其他页面动效不受影响；
  日志 `downgradeReason=motion-disabled`。

---

## 7. 回退开关总设计

```
masterEnabled（MotionPolicy 全局总开关）
 └─ false → 全 App 回到 V3.7.1（瞬切 + 无玻璃），downgradeReason=motion-disabled
prep.motion.home.ai-sheet-expand     → HomeAiSheetPrep.EXPAND.enabled
prep.motion.todo.toggle              → TodoTogglePrep.TOGGLE.enabled
prep.motion.calendar.week-switch     → CalendarWeekPrep.CONTAINER_SLIDE/CONTENT_STAGGER.enabled（双轨共用）
prep.motion.performance.number-roll  → PerformanceNumberPrep.NUMBER_ROLL.enabled
```

- 开关粒度：每页独立；关闭任一开关只影响该页动效（降级单向、只降不升）。
- 接线位置（Phase 3）：设置页 / 远程配置 → 绑定到各 `MotionSpec.enabled`；
  准备阶段一律 `enabled=true`，不读任何外部配置。
- 运行时自动降级（无需人工开关）：reduce-motion / perf-tier-essential /
  dense-list / capability-unsupported / frame-rate-below-55fps / no-anchor，
  全部具名写日志，可单测断言。

## 8. NOT RUN 清单（诚实标注）

| # | 项 | 原因 |
|---|---|---|
| 1 | 全部录屏逐帧验证（§3.1#1、§3.2#2、§3.3#1/#3、§3.4#1） | 无真机/模拟器录屏环境 |
| 2 | 真机帧率 ≥55fps（§3.3#2、日历连滑、液滴+T1 模糊） | OPPO PKJ110 真机未接入；按用户 2026-10-16 02:37 指令，液滴 Morph/玻璃在真机通过前不得进生产页面 |
| 3 | Light/Dark 截图对比（§3.1#2、§3.2#3、§3.4#2 取色） | 无截图环境（Paparazzi 截图为 Phase 3 接线后事项） |
| 4 | 触感 10 次触发（§3.2#1） | 需模拟器日志/真机手感 |
| 5 | JVM 53 用例本地执行 | 本机无 Java/Gradle；CI 执行（预期 0 失败，待 CI run 确认） |
| 6 | `STAGGER_STEP_MS=12ms` 体感与密集阈值（卡片>10） | 待真机实测标定 |

## 9. 已知问题 / 缺口

1. **日历周切换手势归属未定**（§3.5 风险 1）：生产 `CalendarScreen` 当前是月视图，
   周视图左右切换手势在生产页尚无对应实现。草案按"程序化滑动 + 可中断"准备；
   若 Phase 3 确定为跟手 pager，`tweenVelocity` 播种逻辑需重做。这是本准备包最大的不确定项。
2. **经营"首次进入"状态机未在草案中**（§4.3#3 🟡）：`hasRolledOnce` 标志是页面级状态，
   Phase 3 接线时在 ViewModel/页面实现；进程重建与导航返回语义需定义。
3. **数字连续变化的终值对齐缺口**（§4.5 风险 3）：280ms 内多次变化可能"永远到不了终值"；
   草案未含"静默 300ms 后对齐终值"兜底，Phase 3 接线时补。
4. **AI Sheet 背景动态判定未定义**（§1.5 风险 2）：T1→T2 的"背景动态"触发条件 Phase 3 需接线定义。
5. **触感与无障碍叠加**（§2.5 风险 2）：TalkBack 下是否降级触感，Phase 3 需确认（倾向保留）。
6. **标题「日程」vs Tab「日历」**（§3.3#4）：归属 V3.7.1 验收修复轮，本包不碰，V3.8 合并时确认。

## 10. Phase 3 接线 Checklist（给接入 track）

- [ ] 确认日历周切换的手势方案（新增 WeekPager 跟手 / 按钮程序化），再定 `tweenVelocity` 去留；
- [ ] 四个 `MotionSpec.enabled` 绑定到 `PrepSwitches.*`（设置页/远程配置）；
- [ ] `HomeAiSheetPrep.resolveExpand` 的 `anchor` 参数接 `AICommandEntry` 的 `boundsInRoot`，
      加 `no-anchor` 降级率埋点；
- [ ] Todo 防抖窗口与 180ms 动画时长统一口径（防抖 ≥ 动画时长）；
- [ ] 经营 `hasRolledOnce` 状态机 + 金额格式化复用 + 静默对齐兜底；
- [ ] AI Sheet T1「背景动态」判定接线；
- [ ] Paparazzi 截图：四页 Light/Dark × 动效中途/稳定态（§3 验收 #2 类）；
- [ ] 真机 ≥55fps 验证（Roadmap §2 硬门槛）通过后，液滴/玻璃方可进生产页；
- [ ] 隔离审计：`ui/poc` 不被生产引用；`XzgMotionSpecs.all` 未被草案污染。
