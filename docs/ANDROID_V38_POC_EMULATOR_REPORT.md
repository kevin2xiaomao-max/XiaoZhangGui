# Android V3.8 PoC 模拟器自动验证报告

> Worker B 交付。用户要求：JVM 假时钟不能替代运行帧率；
> 本报告所有帧率数据只认模拟器 `dumpsys gfxinfo` 实测，不达标就写不达标；
> 真机项诚实标 NOT RUN。

- 分支：`android/v3.8-sleepdown-coloros`
- 验证脚本：`tools/poc-emulator-validate.sh`（自包含；CI 一行调用，本地连模拟器可复用）
- CI job：`.github/workflows/android.yml` → `poc-emulator-validation`
  （api-level 30 / x86_64 / target default / `disable-animations: false`，
  emulator-options 与 E2E 一致）
- 产物 artifact：`xzg-v38-poc-emulator-evidence`

## 状态

- CI run：`38799737124`（2026-10-15；build/test/lint ✅ / E2E ✅ / release ✅ / poc-emulator-validation 证据已采集）
- 脚本+job+报告框架提交：`ad7f385`；robustness 修复：`5e253f3`（轮询+anim-scale 归一化）、`4b52443`（前台检查为主门槛）
- 真实数据回填：2026-10-16（本轮）

## 1. 帧率（dumpsys gfxinfo 实测）

判定口径：55fps ≈ 平均帧耗时 ≤18.18ms；按任务要求用 **p50** 判定；
`>16.7ms 占比` 取自 gfxinfo `Janky frames` 百分比。

| PoC | total_frames | p50 | p95 | >16.7ms 占比 | ≥55fps（p50≤18.18ms） | 原始数据 |
|-----|--------------|-----|-----|--------------|----------------------|----------|
| droplet（PoC-1 液滴按钮菜单） | 25 | 25ms | 1250ms | 100% | 未达标（模拟器） | `gfxinfo/poc-droplet-gfxinfo.txt` |
| glass（PoC-2 玻璃三档） | 20 | 24ms | 800ms | 95% | 未达标（模拟器） | `gfxinfo/poc-glass-gfxinfo.txt` |
| morph（PoC-3 连续形变） | 30 | 19ms | 850ms | 93.3% | 未达标（模拟器） | `gfxinfo/poc-morph-gfxinfo.txt` |
| transition（PoC-4 转场探测） | —（静态报告页，不测帧率） | — | — | — | — | — |

> **诚实声明**：以上是 API 30 x86_64 模拟器（SwiftShader 软件渲染）的实测数据。
> 软渲染下 ~40fps（p50 19–25ms）是预期表现，**不代表真机性能**，也不得用于判定
> ≥55fps 门槛。≥55fps 硬门槛以 OPPO PKJ110 真机实测为准（`tools/poc-acceptance.sh`）。
> JVM 侧的 MotionSpec/PoC 逻辑测试（Phase 1/2 已全绿）是假时钟/纯逻辑，不得冒充上表。

## 2. 录屏清单

| 文件 | 内容 | 状态 |
|------|------|------|
| `poc-droplet-normal.mp4` | PoC-1 正常速度 20s | ✅ 已采集（CI artifact） |
| `poc-droplet-slow.mp4` | PoC-1 4x 慢放（`?speed=slow`）20s | ✅ 已采集 |
| `poc-glass-normal.mp4` | PoC-2 正常速度 20s | ✅ 已采集 |
| `poc-glass-slow.mp4` | PoC-2 4x 慢放 20s | ✅ 已采集 |
| `poc-morph-normal.mp4` | PoC-3 正常速度 20s | ✅ 已采集 |
| `poc-morph-slow.mp4` | PoC-3 4x 慢放 20s | ✅ 已采集 |
| `poc-droplet-reducemotion.mp4` | Reduce Motion（`animator_duration_scale=0`）10s | ✅ 已采集 |

## 3. Light / Dark 截图清单

| 文件 | 内容 | 状态 |
|------|------|------|
| `poc-droplet-light.png` / `poc-droplet-dark.png` | PoC-1 浅色/深色 | ✅ 已采集 |
| `poc-glass-light.png` / `poc-glass-dark.png` | PoC-2 浅色/深色 | ✅ 已采集 |
| `poc-morph-light.png` / `poc-morph-dark.png` | PoC-3 浅色/深色 | ✅ 已采集 |
| `poc-transition-light.png` / `poc-transition-dark.png` | PoC-4 浅色/深色 | ✅ 已采集 |
| `poc-droplet-reducemotion.png` | Reduce Motion 截图 | ✅ 已采集 |
| `poc-droplet-perf-essential.png` | `?perf=essential` 截图 | ✅ 已采集 |

## 4. Reduce Motion / 性能降级证据

- Reduce Motion：脚本将 `animator_duration_scale` 置 0 后重跑 droplet
  （录屏 + 截图），结束恢复为 1。**本轮 PASS**（`reduce-motion :: video/screenshot/restore`
  全部 PASS；`anim-scales` 校验 0→1 恢复正常）。
  动画退化效果以 `poc-droplet-reducemotion.mp4`/`.png` 人工对比为准；
  MotionPolicy 具名降级逻辑见 JVM 测试（Phase 1）。
- 性能降级：`xzg://poc/droplet?perf=essential` 深链尝试 + 截图。
  **本轮 PASS**（截图已采集；`?perf=` 参数透传已记录，是否生效待截图人工比对；
  `PerfTier` 档位判定按路线图留 Phase 3 接线）。

## 5. NOT RUN 清单（真机，未跑，不虚报）

- OPPO PKJ110 / ColorOS 17 真机帧率（≥55fps 真机硬门槛）
- 真机录屏（正常速度 / 慢放）
- 真机 Light / Dark、Reduce Motion、性能降级表现

## 6. 方法与诚实声明

1. 模拟器以 `disable-animations: false` 启动；脚本校验
   `animator_duration_scale=1`（Reduce Motion 段除外）。
2. 帧率采集流程：`dumpsys gfxinfo <pkg> reset` → 深链启动 →
   动画运行 15s → `dumpsys gfxinfo` 解析 percentiles。
   原始文本保留在 `gfxinfo/`，解析值见 `results.json` / `SUMMARY.md`。
3. 深链投递验证：以 `mFocusedApp` 前台检查为主门槛（`singleTask` 冷启动时
   dumpsys intent 数据显现不稳定）；页面渲染以截图/录屏人工确认为准。
4. 单项失败不中断整体；每项 PASS/FAIL/SKIP 记入 `results.json`。
5. 本报告不引用任何 JVM 假时钟数据作为运行帧率。
6. **模拟器帧率 ≠ 验收结论**：SwiftShader 软渲染的 ~40fps 是环境上限，
   不得用于判定 ≥55fps 门槛；真机验收以 `tools/poc-acceptance.sh` 实测为准。
