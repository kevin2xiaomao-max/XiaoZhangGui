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

## 产物

默认目录 `./poc-acceptance-<时间戳>/`（可用 `--out` 指定）：

| 文件 | 说明 |
| ---- | ---- |
| `poc-acceptance-report-<ts>.md` | 验收报告 |
| `poc-<name>-normal.mp4` / `poc-<name>-slow.mp4` | normal / 慢放录屏 |
| `poc-<name>-light.png` / `poc-<name>-dark.png` | Light / Dark 截图 |
| `poc-droplet-reducemotion.mp4` / `.png` | Reduce Motion 抽查 |
| `poc-<name>-framestats.txt` | 帧率原始数据（可复核） |

## 结论口径（不虚报）

- **PASS / FAIL / NOT RUN** 三态；单项失败记 FAIL 继续跑，不中断整体
- 帧率：有效帧 < 30 或解析失败 → **NOT RUN**（数据不足不判）
- transition 的录屏/帧率 → **NOT RUN**（静态页，按设计跳过）
- 录屏期间页面前台静置、未做点击；帧率反映 10 秒窗口内页面静置/自有动画
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
