# V3.8 Phase 2 PoC 总报告（骨架）

> 分支 `android/v3.8-sleepdown-coloros` · V3.8 Phase 2
> 设计依据：`ANDROID_V38_DESIGN_SYSTEM.md`、`ANDROID_V38_ROADMAP.md` §2–§3
>
> 本文档为骨架：PoC-4（Worker C）已填；PoC-1/2（Worker A）、PoC-3（Worker B）
> 的达标情况由 coordinator 回填。

## 1. PoC 达标情况表

| PoC | Worker | 交付物 | 合入标准（Roadmap §3） | 状态 | 证据 |
|---|---|---|---|---|---|
| PoC-1 液滴按钮菜单 | A | ⏳ 待回填 | 慢放逐帧符合 Phase B–F；全程 ≥55fps；Reduce Motion 下短淡入；评审检查表全勾 | ⏳ 待 Worker A 回填 | — |
| PoC-2 玻璃材质三档 | A | ⏳ 待回填 | 三档几何像素一致；对比度守恒；T1 目标机型 ≥55fps；降级链具名日志 | ⏳ 待 Worker A 回填 | — |
| PoC-3 连续形变 | B | ⏳ 待回填 | 过冲仅一次且 <3%；200ms 后回到 token 标准值；无临时快照残留 | ⏳ 待 Worker B 回填 | — |
| PoC-4 OPPO 私有转场验证 | C | ✅ `ui/motion/OplusTransitionProbe.kt`、`ui/poc/transition/`（采集器+报告页）、`docs/ANDROID_V38_OPLUS_PROBE_REPORT.md` | ① 探测报告（可用/不可用均具名）；② 反射路径有公开 API 降级链；③ 未经授权不合入反射调用 | ✅ 探测报告已输出（本阶段只做探测，不反射调用） | `OplusTransitionProbeTest` 25 tests；`DeepLinkParseTest` +2、`ColdStartPlanTest` +1（PoC 门控） |

## 2. PoC 隔离性

- 独立 route：`poc/launcher`、`poc/droplet`、`poc/glass`、`poc/morph`、
  `poc/transition`（`ui/poc/PocRoutes`），与生产页物理隔离；
- 入口：仅 `xzg://poc` 深链（debug 构建）；生产页无任何引用；
- 编译开关：`BuildConfig.POC_ENABLED`（`build.gradle.kts`：
  默认 true，release 构建覆写为 false）——
  release 下 PoC route 不注册、PoC 深链映射为 `Ignore`；
- grep 门禁（生产代码禁止引用 `ui.poc`）：
  `grep -rn "ui\.poc" android/app/src/main --include="*.kt" | grep -v "ui/poc/"`
  应只命中 `XzgNavGraph.kt` 中被 `BuildConfig.POC_ENABLED` 保护的
  `pocGraph(navController)` 调用行；
- 真机/模拟器进入方式（debug 构建）：
  `adb shell am start -a android.intent.action.VIEW -d "xzg://poc"`。

## 3. NOT RUN 清单（四个 PoC 通用）

- [ ] 四个 PoC 在模拟器上的实际运行录屏/截图/帧率数据——**NOT RUN**
- [ ] 四个 PoC 在 OPPO PKJ110 / ColorOS 17 真机上的实测——**NOT RUN**
- [ ] Reduce Motion / 低性能降级的 PoC 实测——**NOT RUN**
- [ ] PoC-4 反射私有 API 的方法级存在性探测——**未获用户授权，不做**

## 4. 合入 Phase 3 的前提（Roadmap §2）

每个 PoC 达到 §3 合入标准才允许进生产页面；
未达标的 PoC 对应的生产升级点从路线图中移除或延期，
**不许「先合入再优化」**。
