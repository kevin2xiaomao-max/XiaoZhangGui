# PoC 真机一键验收脚本

`tools/poc-acceptance.sh` —— OPPO 手机 USB 连接电脑后，一键完成 V3.8 四个 PoC
（droplet / glass / morph / transition）的深链启动、录屏、Light/Dark 截图、
帧率采集，并生成 Markdown 验收报告。尽量零手动干预。

## 前置条件

- macOS 或 Linux；`adb` 在 PATH 中
  （macOS：`brew install android-platform-tools`；Linux：`apt install android-tools-adb`）
- 手机：开启「开发者选项 → USB 调试」，USB 连接电脑后在手机上点「允许 USB 调试」
- `python3`（帧率解析用；缺失则帧率项记 NOT RUN，录屏/截图不受影响）
- `gh`（可选；用于自动从 CI 拉取 debug APK。没有则用 `--apk` 指定本地 APK）

**注意**：release 构建会剔除 PoC，必须用 **debug APK**
（CI 产物名 `xiaozhanggui-android-debug-apk`，分支 `android/v3.8-sleepdown-coloros`）。

## 用法

```bash
# 零参数：自动从 CI 最新成功 run 下载 debug APK，安装，全量验收
tools/poc-acceptance.sh

# 指定本地 APK
tools/poc-acceptance.sh --apk ~/Downloads/app-debug.apk
# 或用环境变量：POC_APK=~/Downloads/app-debug.apk tools/poc-acceptance.sh

# 多台设备时指定 serial（或设 ANDROID_SERIAL 环境变量）
tools/poc-acceptance.sh --serial ABCD1234

# 只验收单个 PoC；APK 已装过时跳过安装
tools/poc-acceptance.sh --poc droplet --no-install

# 走查脚本逻辑（不碰真机，只打印将执行的命令）
tools/poc-acceptance.sh --dry-run

# --perf 性能验收模式（见下节）
tools/poc-acceptance.sh --perf --dry-run
tools/poc-acceptance.sh --perf --theme dark --perf-secs 20 --no-install

tools/poc-acceptance.sh --help
```

APK 来源优先级：`--apk` > `$POC_APK` > `gh` 从 CI 自动下载。

## 流程

1. **环境检查**：adb 是否存在 → `adb devices` 在线设备（多台则交互选择，或用
   `$ANDROID_SERIAL` / `--serial`）→ 输出设备型号 / Android 版本
2. **安装**：按优先级解析 APK → `adb install -r`（覆盖安装保留数据）
3. **逐 PoC 验收**（droplet / glass / morph）：
   - `force-stop` → 深链启动（`xzg://poc/<name>`）→ 等待 3s
   - Light 截图 → normal 录屏 20s → `?speed=slow` 慢放录屏 20s
   - 帧率：`dumpsys gfxinfo reset` → 前台 10s → `framestats` → 本地解析
     p50 / p95 / >16.7ms 占比 → fps ≈ 1000/p50，≥55fps 判 PASS
   - Dark 截图（`cmd uimode night yes/no` 切换）
   - transition（PoC-4）是静态探测报告页：**只截图，不录屏、不测帧率**（设计如此）
4. **Reduce Motion**（仅 droplet）：`animator_duration_scale=0` → 截图+录屏 15s → 恢复原值
5. **报告**：生成 `poc-acceptance-report-<时间戳>.md`，含设备信息、逐项结论表、
   帧率口径说明、失败/NOT RUN 清单、产物文件清单

## --perf 性能验收模式（P0，逐帧 vsync 间隔口径，动画期间实测）

用户批评：只采样静态页面的帧率不能作为动画达标证据。`--perf` 是一个独立模式
（替代默认的录屏/截图/旧帧率流程，现有默认流程不动），只做帧率实测，
且**采样窗口即为动画窗口**。

核心机制：**autodrive 自动交互驱动**（debug only）。深链
`xzg://poc/<name>?autodrive=true` 进入后，PoC 屏自动循环执行关键动画，
无需触摸；`--perf` 的 `screenrecord` 录像 + `dumpsys gfxinfo framestats`
的 reset→dump 窗口都在动画进行中完成。

| PoC | autodrive 自动动作 |
| --- | ------------------ |
| droplet | 液滴展开 → 停留 → 收起 → 停留，无限循环 |
| glass | 三档 T1 / T2 / T3 循环聚焦切换（显隐只改 alpha 的真实动画帧） |
| morph | 拖拽扫动的程序化等效（右扫 → 左扫 → 松手回弹 → 200ms 释放）+ 展开/收起循环 |
| transition | 静态探测页，按设计跳过帧率，记 NOT RUN |

门控：`PocAutodrive.enabled` 只能由 PoC 深链 `?autodrive=` 置位；
release 构建（`POC_ENABLED=false`）导航层直接返回，永不置位；
离屏即取消循环；手动模式（`autodrive=false` / 无参数）行为零变化。
各屏在 autodrive 时会显示"autodrive 自动循环中"提示行（录像中可见）。

### 参数

| 参数 | 说明 |
| ---- | ---- |
| `--perf` | 开启性能验收模式 |
| `--theme light\|dark\|both` | 主题，默认 `both`（light + dark 各跑一遍；仅 `--perf` 有效） |
| `--perf-secs <秒>` | 单次动画窗口时长，默认 15，最小 5（仅 `--perf` 有效） |
| `--poc <名>` | 可联用，缩小到单个 PoC |

### 测量对象与方法

- **对象**：droplet / glass / morph × 速度（normal + `?speed=slow` 慢放）× 主题
  （light/dark）。transition 是静态探测页，**按设计跳过帧率**，记 NOT RUN。
- **方法**（每个 PoC × 每种速度 × 每种主题）：
  1. 深链启动（`xzg://poc/<name>?autodrive=true[&speed=slow]`，
     `cmd uimode night` 先切好主题）
  2. `dumpsys gfxinfo <pkg> reset`
  3. `screenrecord` 同步录像（`--time-limit <perf-secs>`）
  4. 动画持续循环 `--perf-secs` 秒（默认 15）
  5. `dumpsys gfxinfo <pkg> framestats`，原始文本按
     `poc-<name>-perf-<speed>-<theme>-framestats.txt` 存档，可复核；
     录像按 `poc-<name>-perf-<speed>-<theme>.mp4` 存档（动画过程证据）
- **解析**：取已完成帧（`FrameCompleted > IntendedVsync`）的 `IntendedVsync`
  时间戳序列（升序），相邻帧间隔 `interval[i] = vsync[i+1] − vsync[i]`（毫秒）。
  只统计 `0 < interval ≤ 1000ms` 的有效间隔（剔除页面静置断档）。
  解析细节：表头按列名定位（列顺序随 Android 版本变化）；数据行首列的
  `flags` 用值域判断剔除（`IntendedVsync` 是 >1e12 的纳秒时间戳，flags 是
  0~3 小整数），不依赖行长度比较。
- **统计**：n（有效间隔数）、p50、p95、≤18.18ms 占比（55fps 门槛）、
  ≤16.67ms 占比（60fps 参考）、**掉帧率**（帧间隔 >18.18ms 占比）、
  **严重掉帧**（帧间隔 >2×vsync 占比；vsync 取自设备刷新率，取不到回退
  16.67ms/60Hz）。
- **判定**：n ≥ 30 且 p95 ≤ 18.18ms → **PASS**；
  n ≥ 30 且 p95 > 18.18ms → **FAIL**；
  n < 30 或解析失败 → **NOT RUN**（数据不足不判，不虚报）。

### 环境标注

脚本开头自动采集并存档到产物目录 `device-info.txt`：

- `ro.product.model`、`ro.build.version.release`、`ro.build.version.sdk`
- `ro.build.display.id`、`ro.build.fingerprint`
- 屏幕刷新率（`dumpsys display` 解析，取不到标 `unknown`）

存档 `ro.build.display.id` / `ro.build.fingerprint` 的目的：帮后续性能调优时
解析系统版本差异（如 ColorOS 小版本行为变化），由脚本自动采集，
**用户无需手动提供**。报告中每个 `--perf` 结论都附带测试环境
（机型 / 系统 / 刷新率）；帧率结论只基于实测分布。

### 报告

`--perf` 结果在报告中单独一节（节标题注明"动画期间实测"），表格列出
PoC / 速度 / 主题 / n / p50 / p95 / ≤18.18ms 占比 / ≤16.67ms 占比 /
**掉帧率** / **严重掉帧** / PASS-FAIL；
每组录像（`poc-<name>-perf-<speed>-<theme>.mp4`）与原始 framestats
（`poc-<name>-perf-<speed>-<theme>-framestats.txt`，原始时间戳文件）
分别存档，可复核；dry-run 的行全部标 NOT RUN 并注明未实测。

## 产物

默认目录 `./poc-acceptance-<时间戳>/`（可用 `--out` 指定）：

| 文件 | 说明 |
| ---- | ---- |
| `poc-acceptance-report-<ts>.md` | 验收报告 |
| `poc-<name>-normal.mp4` / `poc-<name>-slow.mp4` | normal / 慢放录屏 |
| `poc-<name>-light.png` / `poc-<name>-dark.png` | Light / Dark 截图 |
| `poc-droplet-reducemotion.mp4` / `.png` | Reduce Motion 抽查 |
| `poc-<name>-framestats.txt` | 帧率原始数据（默认模式，可复核） |
| `device-info.txt` | 设备环境存档（机型/系统/display.id/fingerprint/刷新率） |
| `poc-<name>-perf-<speed>-<theme>.mp4` | --perf 动画窗口录像（autodrive 动画过程证据） |
| `poc-<name>-perf-<speed>-<theme>-framestats.txt` | --perf 逐帧原始时间戳数据（可复核） |

## autodrive 深链参数

`xzg://poc/<droplet|glass|morph>?autodrive=true`（可与 `?speed=slow|normal`
联用，如 `xzg://poc/droplet?autodrive=true&speed=slow`）。transition 为静态
探测页，按设计跳过 autodrive。`autodrive=false` 或无参数 = 手动模式。
release 构建（`POC_ENABLED=false`）下 PoC route 不注册、深链被忽略，
autodrive 永不置位。

## 结论口径（不虚报）

- **PASS / FAIL / NOT RUN** 三态；单项失败记 FAIL 继续跑，不中断整体
- 帧率（默认模式）：有效帧 < 30 或解析失败 → **NOT RUN**（数据不足不判）
- 帧率（--perf 模式）：**动画期间实测**（autodrive 自动交互驱动）；
  有效间隔 n < 30 或解析失败 → **NOT RUN**（数据不足不判）；
  n ≥ 30 且 p95 ≤ 18.18ms → PASS，否则 FAIL
- transition 的录屏/帧率 → **NOT RUN**（静态页，按设计跳过；--perf 亦然）
- 录屏期间页面前台静置、未做点击；帧率反映采集窗口内页面静置/自有动画
  （默认模式 10 秒；--perf 模式见报告 --perf 节的 `--perf-secs`，
  此时页面由 autodrive 自动循环执行动画）
- Ctrl+C 会尽力清理：SIGINT 停掉设备侧 screenrecord（正常收尾 mp4）、恢复深色模式
  与 animator_duration_scale、杀本地后台任务

## 安全

不 root、不改系统分区，只用 `adb shell` 合法命令
（`am start/force-stop`、`screenrecord`、`screencap`、`dumpsys gfxinfo`、
`cmd uimode`、`settings put/get`）；设备侧临时文件拉取后删除。

## 故障排查

- `未检测到在线设备`：检查 USB 线/接口、手机 USB 调试开关、是否点了授权弹窗；
  可换 `adb kill-server && adb start-server` 重试
- `深链启动失败`：确认装的是 **debug** APK（release 版无 PoC 入口）；
  或 App 未完全安装成功，重跑一次安装
- 帧率全是 NOT RUN：确认 `python3` 存在；检查 framestats 原始文件是否有数据行
- `gh` 下载失败：确认 `gh auth status` 已登录且有 repo 读权限，或改用 `--apk`
