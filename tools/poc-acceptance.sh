#!/usr/bin/env bash
###############################################################################
# 你的小掌柜 Android V3.8 — PoC 真机一键验收脚本
#
# 用途：OPPO 手机经 USB 连接电脑后，一键完成四个 PoC
#      （droplet / glass / morph / transition）的深链启动、录屏、
#      截图（Light / Dark）、帧率采集，并生成 Markdown 验收报告。
#
# 深链契约（Worker A 实现，见 ui/poc/PocNav.kt + AndroidManifest xzg://poc）：
#   xzg://poc/droplet  xzg://poc/glass  xzg://poc/morph  xzg://poc/transition
#   ?speed=slow  → 4x 慢放
#   启动：adb shell am start -a android.intent.action.VIEW -d "xzg://poc/droplet" com.xiaozhanggui.app
#
# 设计原则：
#   - 不 root、不改系统分区，只用 adb shell 合法命令
#   - 单项失败记 FAIL 继续跑，不中断整体流程（set -u，不用 set -e）
#   - 真机未测 / 采不到数据的项如实标 NOT RUN，不虚报
#   - Ctrl+C 时尽力清理：停掉设备侧 screenrecord、恢复系统设置
#   - 所有提示中文
#
# 依赖：adb（Android platform-tools，必须）
#      python3（帧率解析用；缺失则帧率项记 NOT RUN，不致命）
#      gh（可选：自动从 CI 拉取 debug APK；没有则用 --apk 或 $POC_APK）
###############################################################################

set -uo pipefail

# ------------------------------- 常量 ---------------------------------------
PKG="com.xiaozhanggui.app"
REPO="kevin2xiaomao-max/XiaoZhangGui"
BRANCH="android/v3.8-sleepdown-coloros"
ARTIFACT_NAME="xiaozhanggui-android-debug-apk"
POCS_ALL="droplet glass morph transition"
FPS_MIN=55              # 帧率门槛：p50 换算 fps >= 55 判 PASS
FPS_MIN_FRAMES=30       # 有效帧数下限；低于此记 NOT RUN（数据不足不判）
REC_SECS=20             # 常规录屏时长（秒）
RM_REC_SECS=15          # Reduce Motion 录屏时长（秒）
FPS_WINDOW_SECS=10      # 帧率采集窗口（秒）
PERF_FPS_MIN=55         # --perf 判定门槛：55fps
PERF_MIN_INTERVALS=30   # --perf 有效间隔数下限；低于此记 NOT RUN（数据不足不判）
PERF_MS_55=18.18        # 55fps 对应帧间隔（毫秒），--perf 判定用
PERF_MS_60=16.67        # 60fps 对应帧间隔（毫秒），仅参考

# --------------------------- 参数（可被覆盖）----------------------------------
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="./poc-acceptance-${TS}"
DRY_RUN=0
APK_ARG=""
NO_INSTALL=0
ONLY_POC="all"
SERIAL="${ANDROID_SERIAL:-}"
PERF_MODE=0             # --perf：逐帧 vsync 间隔口径的性能验收模式
THEME="both"            # --perf 主题：light | dark | both（默认 both）
PERF_SECS=15            # --perf 单次前台采集时长（秒）

# --------------------------- 运行时状态 --------------------------------------
REPORT=""
RESULTS_TSV=""
FAIL_COUNT=0
NOTRUN_COUNT=0
APK_PATH=""
APK_SOURCE=""
MODEL=""
ANDROID_VER=""
SDK=""
APP_VER=""
NIGHT_WAS="unknown"     # yes / no / unknown（脚本开始时的深色模式状态）
ANIM_WAS=""             # 脚本开始时的 animator_duration_scale
CLEANED=0
FPS_SUMMARY=""
DISPLAY_ID=""           # ro.build.display.id（--perf 环境存档）
FINGERPRINT=""          # ro.build.fingerprint（--perf 环境存档）
REFRESH_RATE=""         # 屏幕刷新率 Hz（--perf 环境存档）
PERF_TSV=""             # --perf 结构化结果表
PERF_SUMMARY=""         # --perf 单次测量的统计文本

usage() {
  cat <<'EOF'
用法：tools/poc-acceptance.sh [选项]

OPPO 手机 USB 连接电脑并开启 USB 调试后，一键运行：
  环境检查 → 安装 debug APK → 逐 PoC 深链启动/录屏/截图(Light/Dark)/帧率采集
  → Reduce Motion 抽查 → 生成 Markdown 验收报告。

选项：
  --apk <路径>      指定本地 APK（优先级最高）
  --serial <号>     指定设备 serial（默认用 $ANDROID_SERIAL；多台设备时交互选择）
  --poc <名>        只跑单个 PoC：droplet | glass | morph | transition（默认 all）
  --out <目录>      产物目录（默认 ./poc-acceptance-<时间戳>/）
  --no-install      跳过安装（APK 已装过时复用，节省时间）
  --perf            性能验收模式：用逐帧 vsync 间隔分布测真实帧率
                    （droplet/glass/morph × normal+slow × light/dark），
                    报告单独成节；transition 为静态探测页，按设计跳过
  --theme <t>       --perf 的主题：light | dark | both（默认 both；仅 --perf 有效）
  --perf-secs <秒>   --perf 单次前台采集时长（默认 15，最小 5；仅 --perf 有效）
  --dry-run         只打印将执行的命令，不真跑（用于走查脚本逻辑）
  -h, --help        显示本帮助

APK 来源优先级：① --apk ② 环境变量 $POC_APK ③ gh 从 CI 最新成功 run
自动下载产物 xiaozhanggui-android-debug-apk（分支 android/v3.8-sleepdown-coloros）。
注意：release 构建会剔除 PoC，必须用 debug APK。

环境要求：adb 在 PATH 中；python3（帧率解析用，缺失则帧率项记 NOT RUN）；
          gh（自动下载 APK 用，可选）。

退出码：0 = 脚本跑完并生成报告（即使有 FAIL 项，结论见报告）；
        非 0 = 环境/安装等致命错误，未完成验收。

示例：
  tools/poc-acceptance.sh
  tools/poc-acceptance.sh --apk ~/Downloads/app-debug.apk
  ANDROID_SERIAL=ABCD1234 tools/poc-acceptance.sh --poc droplet --no-install
  tools/poc-acceptance.sh --dry-run
  tools/poc-acceptance.sh --perf --dry-run
  tools/poc-acceptance.sh --perf --theme dark --perf-secs 20 --no-install
EOF
}

# ------------------------------- 基础函数 ------------------------------------
log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { log "警告：$*"; }
die()  { log "错误：$*"; exit 1; }

pause() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] sleep %s\n' "$1" >&2
    return 0
  fi
  sleep "$1"
}

# 统一走这个函数调 adb（自动带 -s serial；dry-run 只打印到 stderr，
# 避免污染命令替换捕获的 stdout）
adb_() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] adb -s %s %s\n' "${SERIAL:-<serial>}" "$*" >&2
    return 0
  fi
  adb -s "$SERIAL" "$@"
}

# 记一条结果：mark <poc> <项目> <PASS|FAIL|NOT RUN> <说明>
mark() {
  printf '%s | %s | %s | %s\n' "$1" "$2" "$3" "$4" >> "$RESULTS_TSV"
  case "$3" in
    PASS)    log "  ✓ [$1] $2：通过" ;;
    FAIL)    log "  ✗ [$1] $2：失败（$4）"; FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    "NOT RUN") log "  ○ [$1] $2：NOT RUN（$4）"; NOTRUN_COUNT=$((NOTRUN_COUNT + 1)) ;;
  esac
}

rep() { printf '%s\n' "$*" >> "$REPORT"; }

# --------------------------- 清理（Ctrl+C / 正常结束）-------------------------
save_initial_state() {
  [ "$DRY_RUN" -eq 1 ] && return 0
  local nm ad
  nm="$(adb_ shell settings get secure ui_night_mode 2>/dev/null | tr -d '\r')"
  case "$nm" in
    2) NIGHT_WAS="yes" ;;
    1) NIGHT_WAS="no" ;;
    *) NIGHT_WAS="unknown" ;;
  esac
  ad="$(adb_ shell settings get global animator_duration_scale 2>/dev/null | tr -d '\r')"
  ANIM_WAS="${ad:-1.0}"
  log "已记录初始系统状态：深色模式=${NIGHT_WAS}，animator_duration_scale=${ANIM_WAS}"
}

restore_settings() {
  [ "$DRY_RUN" -eq 1 ] && return 0
  [ -z "${SERIAL:-}" ] && return 0
  case "$NIGHT_WAS" in
    yes) adb -s "$SERIAL" shell cmd uimode night yes >/dev/null 2>&1 || true ;;
    no)  adb -s "$SERIAL" shell cmd uimode night no  >/dev/null 2>&1 || true ;;
  esac
  if [ -n "$ANIM_WAS" ]; then
    adb -s "$SERIAL" shell settings put global animator_duration_scale "$ANIM_WAS" >/dev/null 2>&1 || true
  fi
}

cleanup() {
  [ "$CLEANED" -eq 1 ] && return 0
  CLEANED=1
  log "正在清理…"
  # 停掉设备侧残留的 screenrecord（SIGINT 会让它正常收尾 mp4）
  if [ "$DRY_RUN" -eq 0 ] && [ -n "${SERIAL:-}" ]; then
    adb -s "$SERIAL" shell 'pkill -INT -f screenrecord 2>/dev/null || killall -INT screenrecord 2>/dev/null' >/dev/null 2>&1 || true
  fi
  restore_settings
  # 杀本地后台任务
  local pids
  pids="$(jobs -p 2>/dev/null || true)"
  if [ -n "$pids" ]; then kill $pids 2>/dev/null || true; fi
  log "清理完成"
}
trap 'cleanup; exit 130' INT TERM

# ------------------------------- 参数解析 ------------------------------------
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --apk)    [ $# -ge 2 ] || die "--apk 需要一个路径参数"; APK_ARG="$2"; shift 2 ;;
      --serial) [ $# -ge 2 ] || die "--serial 需要一个参数"; SERIAL="$2"; shift 2 ;;
      --poc)    [ $# -ge 2 ] || die "--poc 需要一个参数"; ONLY_POC="$2"; shift 2 ;;
      --out)    [ $# -ge 2 ] || die "--out 需要一个目录"; OUT_DIR="$2"; shift 2 ;;
      --no-install) NO_INSTALL=1; shift ;;
      --perf)       PERF_MODE=1; shift ;;
      --theme)      [ $# -ge 2 ] || die "--theme 需要一个参数"; THEME="$2"; THEME_SET=1; shift 2 ;;
      --perf-secs)  [ $# -ge 2 ] || die "--perf-secs 需要一个秒数"; PERF_SECS="$2"; PERF_SECS_SET=1; shift 2 ;;
      --dry-run)    DRY_RUN=1; shift ;;
      -h|--help)    usage; exit 0 ;;
      *) die "未知参数：$1（用 --help 查看用法）" ;;
    esac
  done
  case "$ONLY_POC" in
    all|droplet|glass|morph|transition) ;;
    *) die "--poc 参数无效：$ONLY_POC（可选 droplet|glass|morph|transition|all）" ;;
  esac
  case "$THEME" in
    light|dark|both) ;;
    *) die "--theme 参数无效：$THEME（可选 light|dark|both）" ;;
  esac
  case "$PERF_SECS" in
    ''|*[!0-9]*) die "--perf-secs 必须是正整数秒数：$PERF_SECS" ;;
  esac
  [ "$PERF_SECS" -ge 5 ] || die "--perf-secs 太小（至少 5 秒）：$PERF_SECS"
  if [ "$PERF_MODE" -eq 0 ]; then
    [ -n "${THEME_SET:-}" ] && warn "--theme 仅在 --perf 模式下有效，已忽略"
    [ -n "${PERF_SECS_SET:-}" ] && warn "--perf-secs 仅在 --perf 模式下有效，已忽略"
  fi
}

# ------------------------------- ① 环境检查 ----------------------------------
check_env() {
  log "① 环境检查"
  if [ "$DRY_RUN" -eq 1 ]; then
    SERIAL="DRYRUN123456"
    MODEL="DryRun设备"; ANDROID_VER="99"; SDK="99"
    log "dry-run：跳过真机检查，使用假 serial=${SERIAL}"
    return 0
  fi
  command -v adb >/dev/null 2>&1 \
    || die "找不到 adb。请先安装 Android platform-tools（macOS：brew install android-platform-tools；Linux：apt install android-tools-adb），并确保 adb 在 PATH 中。"
  adb start-server >/dev/null 2>&1 || true

  local devlist n
  devlist="$(mktemp)"
  adb devices | awk '$2=="device" {print $1}' > "$devlist"
  n="$(wc -l < "$devlist" | tr -d ' ')"
  if [ "$n" -eq 0 ]; then
    rm -f "$devlist"
    die "未检测到在线设备。请确认：① USB 已连接 ② 手机已开启「开发者选项 → USB 调试」③ 已在手机上点「允许 USB 调试」（电脑 RSA 指纹授权）。"
  fi
  if [ -n "$SERIAL" ]; then
    grep -qx "$SERIAL" "$devlist" \
      || { rm -f "$devlist"; die "指定的 serial 不在线：$SERIAL"; }
    log "使用指定设备：$SERIAL（来自 --serial 或 \$ANDROID_SERIAL）"
  elif [ "$n" -eq 1 ]; then
    SERIAL="$(cat "$devlist")"
    log "检测到 1 台设备：$SERIAL"
  else
    log "检测到 ${n} 台在线设备："
    local i=1 s m
    while read -r s; do
      m="$(adb -s "$s" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
      printf '  [%d] %s  （%s）\n' "$i" "$s" "${m:-未知型号}"
      i=$((i + 1))
    done < "$devlist"
    local pick=""
    read -rp "请输入序号 [1]: " pick
    pick="${pick:-1}"
    SERIAL="$(sed -n "${pick}p" "$devlist")"
    rm -f "$devlist"
    [ -n "$SERIAL" ] || die "序号无效：$pick"
    log "已选择设备：$SERIAL"
  fi
  rm -f "$devlist"

  MODEL="$(adb_ shell getprop ro.product.model | tr -d '\r')"
  ANDROID_VER="$(adb_ shell getprop ro.build.version.release | tr -d '\r')"
  SDK="$(adb_ shell getprop ro.build.version.sdk | tr -d '\r')"
  log "设备：${MODEL:-未知}（Android ${ANDROID_VER:-未知} / SDK ${SDK:-未知}），serial=${SERIAL}"
  command -v python3 >/dev/null 2>&1 \
    || warn "本机无 python3：帧率解析不可用，相关项将记 NOT RUN（录屏/截图不受影响）"
}

# ------------------------------- ② 解析 APK ----------------------------------
download_apk_from_ci() {
  # 从分支最新成功的 CI run 下载产物；输出本地 APK 路径（失败返回非 0）
  local tmp ids id apk
  tmp="$(mktemp -d)"
  ids="$(gh run list --repo "$REPO" --branch "$BRANCH" --limit 20 \
           --json databaseId,conclusion \
           -q '[.[] | select(.conclusion=="success") | .databaseId][0:5][]' 2>/dev/null)"
  if [ -z "$ids" ]; then
    warn "在分支 $BRANCH 上没找到结论为 success 的 CI run"
    rm -rf "$tmp"
    return 1
  fi
  for id in $ids; do
    log "尝试从 run ${id} 下载产物 ${ARTIFACT_NAME} …"
    if gh run download "$id" --repo "$REPO" -n "$ARTIFACT_NAME" -D "$tmp/$id" >/dev/null 2>&1; then
      apk="$(find "$tmp/$id" -name '*.apk' | head -1)"
      if [ -n "$apk" ]; then
        APK_SOURCE="CI run ${id}（分支 ${BRANCH}，产物 ${ARTIFACT_NAME}）"
        printf '%s\n' "$apk"
        return 0
      fi
    fi
  done
  warn "最近 5 个成功的 run 里都没找到产物 ${ARTIFACT_NAME}"
  rm -rf "$tmp"
  return 1
}

resolve_apk() {
  log "③ 解析 APK"
  if [ "$DRY_RUN" -eq 1 ]; then
    APK_PATH="/dry-run/app-debug.apk"
    APK_SOURCE="dry-run 假路径"
    log "dry-run：APK=${APK_PATH}"
    return 0
  fi
  if [ -n "$APK_ARG" ]; then
    [ -f "$APK_ARG" ] || die "--apk 指定的文件不存在：$APK_ARG"
    APK_PATH="$APK_ARG"
    APK_SOURCE="命令行参数 --apk ${APK_ARG}"
  elif [ -n "${POC_APK:-}" ]; then
    [ -f "$POC_APK" ] || die "环境变量 POC_APK 指向的文件不存在：$POC_APK"
    APK_PATH="$POC_APK"
    APK_SOURCE="环境变量 POC_APK=${POC_APK}"
  else
    command -v gh >/dev/null 2>&1 \
      || die "未指定 --apk，也找不到 gh。请手动从 GitHub CI 下载产物 ${ARTIFACT_NAME} 后，用 --apk <路径> 重跑。"
    local dl
    dl="$(download_apk_from_ci)" || die "从 CI 自动下载 APK 失败，请手动下载后用 --apk 指定。"
    APK_PATH="$dl"
  fi
  log "APK：$APK_PATH"
  log "来源：$APK_SOURCE"
}

# ------------------------------- ③ 安装 --------------------------------------
install_apk() {
  if [ "$NO_INSTALL" -eq 1 ]; then
    log "④ 跳过安装（--no-install）"
    return 0
  fi
  log "④ 安装 APK（adb install -r，覆盖安装保留数据）"
  adb_ install -r "$APK_PATH" || die "安装失败"
  [ "$DRY_RUN" -eq 1 ] && { APP_VER="dry-run"; return 0; }
  adb_ shell pm list packages 2>/dev/null | tr -d '\r' | grep -q "package:${PKG}$" \
    || die "安装后找不到包 ${PKG}"
  APP_VER="$(adb_ shell dumpsys package "$PKG" 2>/dev/null | tr -d '\r' | grep -m1 'versionName=' | sed 's/.*versionName=//')"
  APP_VER="${APP_VER:-未知}"
  log "已安装：${PKG}（versionName=${APP_VER}）"
}

# ------------------------------- PoC 原子操作 ---------------------------------
# 深链启动：先 force-stop，再 am start（契约命令原样）
# 用法：launch_poc <name> [normal|slow]
launch_poc() {
  local name="$1" speed="${2:-normal}" uri="xzg://poc/${name}"
  [ "$speed" = "slow" ] && uri="${uri}?speed=slow"
  adb_ shell am force-stop "$PKG" >/dev/null 2>&1 || true
  pause 1
  if ! adb_ shell am start -a android.intent.action.VIEW -d "$uri" "$PKG" >/dev/null 2>&1; then
    warn "深链启动失败：$uri"
    return 1
  fi
  pause 3
  if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
  if [ -z "$(adb_ shell pidof "$PKG" 2>/dev/null | tr -d '\r')" ]; then
    warn "启动后进程不存在：$name"
    return 1
  fi
  return 0
}

# 录屏：用法 record_video <name> <tag> <秒>；成功输出本地路径
record_video() {
  local name="$1" tag="$2" secs="$3"
  local dev="/sdcard/poc-${name}-${tag}.mp4"
  local out="${OUT_DIR}/poc-${name}-${tag}.mp4"
  adb_ shell screenrecord --time-limit "$secs" "$dev" &
  local bg=$!
  pause $((secs + 2))
  wait "$bg" 2>/dev/null || true
  if [ "$DRY_RUN" -eq 1 ]; then printf '%s\n' "$out"; return 0; fi
  adb_ pull "$dev" "$out" >/dev/null 2>&1 || return 1
  adb_ shell rm -f "$dev" >/dev/null 2>&1 || true
  [ -s "$out" ] || return 1
  printf '%s\n' "$out"
}

# 截图：用法 take_shot <name> <tag>；成功输出本地路径
take_shot() {
  local name="$1" tag="$2"
  local dev="/sdcard/poc-${name}-${tag}.png"
  local out="${OUT_DIR}/poc-${name}-${tag}.png"
  adb_ shell screencap -p "$dev" >/dev/null 2>&1 || return 1
  if [ "$DRY_RUN" -eq 1 ]; then printf '%s\n' "$out"; return 0; fi
  adb_ pull "$dev" "$out" >/dev/null 2>&1 || return 1
  adb_ shell rm -f "$dev" >/dev/null 2>&1 || true
  [ -s "$out" ] || return 1
  printf '%s\n' "$out"
}

# 深色模式开关：set_night yes|no
set_night() {
  adb_ shell cmd uimode night "$1" >/dev/null 2>&1 || true
  pause 2
}

# 帧率采集：reset → 10s 窗口 → framestats → python3 解析
# 返回 0=PASS(>=55fps) 1=FAIL(<55fps) 2=NOT RUN；结论文本进 $FPS_SUMMARY
measure_fps() {
  local name="$1"
  local raw="${OUT_DIR}/poc-${name}-framestats.txt"
  launch_poc "$name" normal || return 2
  adb_ shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1 || true
  log "  正在采集 10 秒帧数据（${name}，normal 速度）…"
  pause "$FPS_WINDOW_SECS"
  if [ "$DRY_RUN" -eq 1 ]; then FPS_SUMMARY="dry-run 未实测"; return 2; fi
  adb_ shell dumpsys gfxinfo "$PKG" framestats 2>/dev/null | tr -d '\r' > "$raw"
  if ! command -v python3 >/dev/null 2>&1; then
    FPS_SUMMARY="本机无 python3，无法解析 framestats"
    return 2
  fi
  FPS_SUMMARY="$(python3 - "$raw" <<'PYEOF'
import sys
path = sys.argv[1]
iv_idx = fc_idx = None
durs = []
try:
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(',')]
            # 表头行定位列（不同 Android 版本列顺序可能变化，按名取列）
            if iv_idx is None and 'IntendedVsync' in parts and 'FrameCompleted' in parts:
                iv_idx = parts.index('IntendedVsync')
                fc_idx = parts.index('FrameCompleted')
                continue
            if iv_idx is None or len(parts) <= max(iv_idx, fc_idx):
                continue
            try:
                iv = int(parts[iv_idx]); fc = int(parts[fc_idx])
            except ValueError:
                continue
            if iv > 0 and fc > iv:
                ms = (fc - iv) / 1e6
                if 0 < ms < 1000:      #  sanity：剔除异常值
                    durs.append(ms)
except OSError:
    print('READ_ERROR'); sys.exit(0)
if not durs:
    print('NO_FRAMES'); sys.exit(0)
durs.sort()
n = len(durs)
p50 = durs[int(0.50 * (n - 1))]
p95 = durs[int(0.95 * (n - 1))]
jank = sum(1 for d in durs if d > 16.7) / n * 100.0
fps = 1000.0 / p50 if p50 > 0 else 0.0
print('frames=%d p50=%.2fms p95=%.2fms jank(>16.7ms)=%.1f%% fps~%.1f' % (n, p50, p95, jank, fps))
PYEOF
)"
  case "$FPS_SUMMARY" in
    frames=*) ;;
    *) return 2 ;;
  esac
  local frames fps
  frames="$(printf '%s' "$FPS_SUMMARY" | sed -n 's/.*frames=\([0-9][0-9]*\).*/\1/p')"
  fps="$(printf '%s' "$FPS_SUMMARY" | sed -n 's/.*fps~\([0-9][0-9.]*\).*/\1/p')"
  frames="${frames:-0}"; fps="${fps:-0}"
  if [ "$frames" -lt "$FPS_MIN_FRAMES" ]; then
    FPS_SUMMARY="${FPS_SUMMARY}（有效帧 ${frames} < ${FPS_MIN_FRAMES}，数据不足不判）"
    return 2
  fi
  if awk "BEGIN{exit !( $fps >= $FPS_MIN )}"; then
    return 0
  else
    return 1
  fi
}

# ------------------------------- ⑤ 逐 PoC 验收（默认模式） --------------------------
# transition 是静态探测报告页：只截图，不录屏、不测帧率（设计如此，脚本内注明）
accept_transition() {
  log "  注：transition 为静态探测报告页，只截图，不录屏、不测帧率。"
  set_night no
  local f
  if launch_poc transition normal; then
    if f="$(take_shot transition light)"; then
      mark transition "截图(Light)" PASS "$f"
    else
      mark transition "截图(Light)" FAIL "screencap/pull 失败"
    fi
  else
    mark transition "启动" FAIL "深链启动失败"
  fi
  set_night yes
  if f="$(take_shot transition dark)"; then
    mark transition "截图(Dark)" PASS "$f"
  else
    mark transition "截图(Dark)" FAIL "screencap/pull 失败"
  fi
  set_night no
  mark transition "录屏" "NOT RUN" "静态报告页，按设计跳过"
  mark transition "帧率" "NOT RUN" "静态报告页，按设计跳过"
}

accept_poc() {
  local name="$1" f
  log "⑤ PoC：$name"
  if [ "$name" = "transition" ]; then
    accept_transition
    return 0
  fi

  # ---- Light：截图 + normal 录屏 ----
  set_night no
  if launch_poc "$name" normal; then
    if f="$(take_shot "$name" light)"; then
      mark "$name" "截图(Light)" PASS "$f"
    else
      mark "$name" "截图(Light)" FAIL "screencap/pull 失败"
    fi
    if f="$(record_video "$name" normal "$REC_SECS")"; then
      mark "$name" "录屏(normal ${REC_SECS}s)" PASS "$f"
    else
      mark "$name" "录屏(normal)" FAIL "screenrecord/pull 失败"
    fi
  else
    mark "$name" "启动(normal)" FAIL "深链启动失败"
  fi

  # ---- 慢放（?speed=slow，4x） ----
  if launch_poc "$name" slow; then
    if f="$(record_video "$name" slow "$REC_SECS")"; then
      mark "$name" "录屏(slow 4x)" PASS "$f"
    else
      mark "$name" "录屏(slow)" FAIL "screenrecord/pull 失败"
    fi
  else
    mark "$name" "启动(slow)" FAIL "深链启动失败"
  fi

  # ---- 帧率（normal 速度，10s 窗口） ----
  local rc
  measure_fps "$name"; rc=$?
  if [ "$rc" -eq 0 ]; then
    mark "$name" "帧率(≥${FPS_MIN}fps)" PASS "$FPS_SUMMARY"
  elif [ "$rc" -eq 1 ]; then
    mark "$name" "帧率(≥${FPS_MIN}fps)" FAIL "$FPS_SUMMARY"
  else
    mark "$name" "帧率(≥${FPS_MIN}fps)" "NOT RUN" "${FPS_SUMMARY:-无数据}"
  fi

  # ---- Dark：截图 ----
  set_night yes
  if launch_poc "$name" normal; then
    if f="$(take_shot "$name" dark)"; then
      mark "$name" "截图(Dark)" PASS "$f"
    else
      mark "$name" "截图(Dark)" FAIL "screencap/pull 失败"
    fi
  else
    mark "$name" "启动(dark)" FAIL "深链启动失败"
  fi
  set_night no
}

# --------------------------- ⑥ Reduce Motion（默认模式） ---------------------------
reduce_motion_test() {
  log "⑥ Reduce Motion 抽查（droplet，animator_duration_scale=0）"
  if [ "$DRY_RUN" -eq 1 ]; then
    mark droplet "Reduce Motion 录屏+截图" "NOT RUN" "dry-run 未实测"
    return 0
  fi
  if ! adb_ shell settings put global animator_duration_scale 0 >/dev/null 2>&1; then
    mark droplet "Reduce Motion 设置" FAIL "animator_duration_scale 置 0 失败（可能被系统限制）"
    return 0
  fi
  pause 1
  local f
  if launch_poc droplet normal; then
    if f="$(take_shot droplet reducemotion)"; then
      mark droplet "截图(ReduceMotion)" PASS "$f"
    else
      mark droplet "截图(ReduceMotion)" FAIL "screencap/pull 失败"
    fi
    if f="$(record_video droplet reducemotion "$RM_REC_SECS")"; then
      mark droplet "录屏(ReduceMotion ${RM_REC_SECS}s)" PASS "$f"
    else
      mark droplet "录屏(ReduceMotion)" FAIL "screenrecord/pull 失败"
    fi
  else
    mark droplet "启动(ReduceMotion)" FAIL "深链启动失败"
  fi
  if adb_ shell settings put global animator_duration_scale "$ANIM_WAS" >/dev/null 2>&1; then
    log "  animator_duration_scale 已恢复为 ${ANIM_WAS}"
  else
    warn "animator_duration_scale 未能恢复为 ${ANIM_WAS}，请手动检查（settings get global animator_duration_scale）"
  fi
}

# --------------------------- ⑤ --perf 性能验收（--perf 模式） ----------------------
# 说明：--perf 模式替代上面的"⑤ 逐 PoC 验收（默认模式）"，两者二选一。
# 用户要求：用逐帧 vsync 时间戳计算真实帧间隔分布，
# 不许用"采样 N 秒数帧数"代替实际帧率。
# 测量对象：droplet / glass / morph × 速度(normal/slow) × 主题(light/dark)；
# transition 是静态探测页，按设计跳过帧率（脚本内注明，记 NOT RUN）。
# 判定：n ≥ 30 且 p95 ≤ 18.18ms → PASS；
#       n ≥ 30 但 p95 > 18.18ms → FAIL；
#       n < 30 或解析失败 → NOT RUN（数据不足不判）。

# 设备环境采集：存档到产物目录 device-info.txt
collect_device_info() {
  log "② 设备环境信息采集（存档到 device-info.txt，供后续调优版本解析）"
  local info="${OUT_DIR}/device-info.txt"
  if [ "$DRY_RUN" -eq 1 ]; then
    DISPLAY_ID="dry-run-display-id"; FINGERPRINT="dry-run/fingerprint:0"
    REFRESH_RATE="120"
  else
    DISPLAY_ID="$(adb_ shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
    DISPLAY_ID="${DISPLAY_ID:-unknown}"
    FINGERPRINT="$(adb_ shell getprop ro.build.fingerprint 2>/dev/null | tr -d '\r')"
    FINGERPRINT="${FINGERPRINT:-unknown}"
    REFRESH_RATE="$(adb_ shell dumpsys display 2>/dev/null | tr -d '\r' \
      | grep -m1 -o 'refreshRate=[0-9][0-9.]*' | cut -d= -f2)"
    REFRESH_RATE="${REFRESH_RATE:-unknown}"
  fi
  {
    printf 'ro.product.model=%s\n' "${MODEL:-unknown}"
    printf 'ro.build.version.release=%s\n' "${ANDROID_VER:-unknown}"
    printf 'ro.build.version.sdk=%s\n' "${SDK:-unknown}"
    printf 'ro.build.display.id=%s\n' "$DISPLAY_ID"
    printf 'ro.build.fingerprint=%s\n' "$FINGERPRINT"
    printf 'refresh_rate_hz=%s\n' "$REFRESH_RATE"
    printf 'serial=%s\n' "${SERIAL:-unknown}"
    printf '采集时间=%s\n' "$TS"
    printf '说明：ro.build.display.id 与 ro.build.fingerprint 由脚本自动采集并存档，'
    printf '用于后续性能调优时解析系统版本差异（如 ColorOS 小版本行为变化），用户无需手动提供。\n'
  } > "$info"
  log "  已存档：$info（机型=${MODEL:-unknown}，Android=${ANDROID_VER:-unknown}，刷新率=${REFRESH_RATE}Hz）"
}

# 从 $PERF_SUMMARY 取字段：perf_field <前缀> [单位后缀]
perf_field() {
  printf '%s' "$PERF_SUMMARY" | awk -v pre="$1" -v suf="${2:-}" '
    {for(i=1;i<=NF;i++) if(index($i,pre)==1){v=substr($i,length(pre)+1); if(suf!="") sub(suf"$","",v); print v; exit}}'
}

# --perf 单次测量：深链启动 → reset → 前台 PERF_SECS 秒 → framestats
# 解析已完成帧的 IntendedVsync 时间戳序列，算相邻帧间隔分布。
# 返回 0=PASS 1=FAIL 2=NOT RUN；统计文本进 $PERF_SUMMARY
measure_perf() {
  local name="$1" speed="$2" theme_label="$3"
  local raw="${OUT_DIR}/poc-${name}-perf-${speed}-${theme_label}-framestats.txt"
  launch_poc "$name" "$speed" || return 2
  adb_ shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1 || true
  log "  正在采集 ${PERF_SECS} 秒逐帧数据（${name}，${speed}，${theme_label}）…"
  pause "$PERF_SECS"
  adb_ shell dumpsys gfxinfo "$PKG" framestats 2>/dev/null | tr -d '\r' > "$raw"
  if [ "$DRY_RUN" -eq 1 ]; then PERF_SUMMARY="dry-run 未实测"; return 2; fi
  if ! command -v python3 >/dev/null 2>&1; then
    PERF_SUMMARY="本机无 python3，无法解析 framestats"
    return 2
  fi
  PERF_SUMMARY="$(python3 - "$raw" <<'PYEOF'
import sys
path = sys.argv[1]
MS55 = 18.18   # 55fps 对应帧间隔（毫秒）
MS60 = 16.67   # 60fps 对应帧间隔（毫秒，参考）
header = None
iv_idx = fc_idx = -1
vsyncs = []

def to_int(s):
    try:
        return int(s)
    except (ValueError, TypeError):
        return None

try:
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('---') or line.startswith('Package:') \
               or line.startswith('Profile data'):
                continue
            parts = [p for p in (x.strip() for x in line.split(',')) if p != '']
            if 'IntendedVsync' in parts:   # 表头行（列顺序随 Android 版本变化，按名取列）
                header = parts
                iv_idx = header.index('IntendedVsync')
                fc_idx = header.index('FrameCompleted')
                continue
            if header is None or len(parts) <= max(iv_idx, fc_idx):
                continue
            # 对齐：数据行首列可能是 flags（0~3 的小整数），表头没有。
            # 不能靠"行长度 vs 表头长度"判断（trailing comma 的有无会改变长度），
            # 用值域判断：IntendedVsync 是纳秒时间戳（>1e12），flags 不可能是这么大的数。
            row = parts
            first = to_int(parts[0])
            second = to_int(parts[1]) if len(parts) > 1 else None
            if first is not None and 0 <= first <= 3 \
               and second is not None and second > 10**12:
                row = parts[1:]
                if len(row) <= max(iv_idx, fc_idx):
                    continue
            iv = to_int(row[iv_idx]); fc = to_int(row[fc_idx])
            if iv is None or fc is None:
                continue
            if iv > 0 and fc > iv:        # 只取已完成帧
                vsyncs.append(iv)
except OSError:
    print('READ_ERROR'); sys.exit(0)
if not vsyncs:
    print('NO_FRAMES'); sys.exit(0)
vsyncs.sort()
gaps = [(b - a) / 1e6 for a, b in zip(vsyncs, vsyncs[1:])]  # 相邻帧间隔（毫秒）
gaps = [g for g in gaps if 0 < g <= 1000]                  # sanity：剔除 >1s 的静置断档
n = len(gaps)
if n == 0:
    print('NO_INTERVALS'); sys.exit(0)
gaps.sort()
p50 = gaps[int(0.50 * (n - 1))]
p95 = gaps[int(0.95 * (n - 1))]
le55 = sum(1 for g in gaps if g <= MS55) / n * 100.0
le60 = sum(1 for g in gaps if g <= MS60) / n * 100.0
print('n=%d p50=%.2fms p95=%.2fms le18.18=%.1f%% le16.67=%.1f%%' % (n, p50, p95, le55, le60))
PYEOF
)"
  case "$PERF_SUMMARY" in
    n=*) ;;
    *) return 2 ;;
  esac
  local n p95
  n="$(perf_field 'n=')"; p95="$(perf_field 'p95=' 'ms')"
  n="${n:-0}"; p95="${p95:-9999}"
  if [ "$n" -lt "$PERF_MIN_INTERVALS" ]; then
    PERF_SUMMARY="${PERF_SUMMARY}（有效间隔 ${n} < ${PERF_MIN_INTERVALS}，数据不足不判）"
    return 2
  fi
  if awk -v v="$p95" -v t="$PERF_MS_55" 'BEGIN{exit !(v <= t)}'; then
    return 0
  else
    return 1
  fi
}

# --perf 主循环：每个 PoC × 速度 × 主题独立采集
run_perf() {
  log "⑤ 性能验收（--perf：逐帧 vsync 间隔口径）"
  local pocs="$POCS_ALL"
  [ "$ONLY_POC" != "all" ] && pocs="$ONLY_POC"
  local themes="$THEME"
  [ "$THEME" = "both" ] && themes="light dark"
  PERF_TSV="${OUT_DIR}/.perf.tsv"
  : > "$PERF_TSV"

  local p t s mode rc verdict n p50 p95v le55 le60
  for p in $pocs; do
    if [ "$p" = "transition" ]; then
      log "  注：transition 为静态探测报告页，按设计跳过 --perf 帧率采集。"
      mark transition "帧率-perf" "NOT RUN" "静态探测页，按设计跳过"
      continue
    fi
    for t in $themes; do
      case "$t" in
        light) mode="no" ;;
        dark)  mode="yes" ;;
      esac
      set_night "$mode"
      for s in normal slow; do
        measure_perf "$p" "$s" "$t"; rc=$?
        n="$(perf_field 'n=')";      p50="$(perf_field 'p50=' 'ms')"
        p95v="$(perf_field 'p95=' 'ms')"
        le55="$(perf_field 'le18.18=' '%')"; le60="$(perf_field 'le16.67=' '%')"
        if [ "$rc" -eq 0 ]; then verdict="PASS"
        elif [ "$rc" -eq 1 ]; then verdict="FAIL"
        else verdict="NOT RUN"; fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$p" "$s" "$t" "${n:-—}" "${p50:-—}" "${p95v:-—}" "${le55:-—}" "${le60:-—}" "$verdict" >> "$PERF_TSV"
        mark "$p" "帧率-perf(${s}/${t})" "$verdict" "${PERF_SUMMARY:-无数据}"
      done
    done
  done
  set_night no
}

# ------------------------------- ⑦ 生成报告 ------------------------------------
write_report() {
  log "⑦ 生成验收报告"
  local pass_n fail_n notrun_n total
  pass_n="$(grep -c ' | PASS |' "$RESULTS_TSV" || true)"
  fail_n="$(grep -c ' | FAIL |' "$RESULTS_TSV" || true)"
  notrun_n="$(grep -c ' | NOT RUN |' "$RESULTS_TSV" || true)"
  total=$((pass_n + fail_n + notrun_n))

  rep "# PoC 真机验收报告"
  rep ""
  rep "- 时间：${TS}"
  rep "- 设备：${MODEL:-未知}（Android ${ANDROID_VER:-未知} / SDK ${SDK:-未知}，serial=${SERIAL:-未知}）"
  rep "- App：${PKG}（versionName=${APP_VER:-未知}）"
  rep "- APK 来源：${APK_SOURCE:-未知}"
  rep "- 分支：${BRANCH}；产物：${ARTIFACT_NAME}"
  rep "- 汇总：共 ${total} 项，PASS ${pass_n} / FAIL ${fail_n} / NOT RUN ${notrun_n}"
  rep ""
  rep "## 逐项结果"
  rep ""
  rep "| PoC | 项目 | 结论 | 说明 |"
  rep "| --- | ---- | ---- | ---- |"
  awk -F' \\| ' '{printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4}' "$RESULTS_TSV" >> "$REPORT"
  rep ""
  if [ "$PERF_MODE" -eq 0 ]; then
    rep "## 帧率口径"
    rep ""
    rep "- 命令：\`adb shell dumpsys gfxinfo ${PKG} reset\` → 前台展示 10 秒 → \`dumpsys gfxinfo ${PKG} framestats\`"
    rep "- 解析：取 framestats 表头定位 IntendedVsync / FrameCompleted 列，帧耗时 = (FrameCompleted − IntendedVsync) / 1e6（毫秒）"
    rep "- 统计：p50 / p95 / >16.7ms 占比（jank）；fps ≈ 1000 / p50(ms)"
    rep "- 结论：fps ≥ ${FPS_MIN} 判 PASS；有效帧 < ${FPS_MIN_FRAMES} 或解析失败记 NOT RUN（数据不足不判，不虚报）"
    rep "- 原始 framestats 文本保留在产物目录（poc-<name>-framestats.txt），可复核"
    rep ""
  fi
  if [ "$PERF_MODE" -eq 1 ]; then
    rep "## --perf 性能验收（逐帧 vsync 间隔口径）"
    rep ""
    rep "- 测试环境：${MODEL:-未知}（Android ${ANDROID_VER:-未知} / SDK ${SDK:-未知}，serial=${SERIAL:-未知}），屏幕刷新率 ${REFRESH_RATE:-unknown}Hz"
    rep "- 设备信息已存档到 \`device-info.txt\`（ro.product.model / ro.build.version.release / ro.build.version.sdk / ro.build.display.id / ro.build.fingerprint / 屏幕刷新率）。"
    rep "  display.id 与 fingerprint 由脚本自动采集存档，用于后续性能调优时解析系统版本差异，用户无需手动提供。"
    rep "- 方法：深链启动 → \`dumpsys gfxinfo ${PKG} reset\` → 前台 ${PERF_SECS}s → \`dumpsys gfxinfo ${PKG} framestats\`；每个 PoC × 速度（normal/slow）× 主题（light/dark）独立采集"
    rep "- 解析：取已完成帧（FrameCompleted > IntendedVsync）的 IntendedVsync 时间戳序列（升序），相邻帧间隔 interval[i] = vsync[i+1] − vsync[i]（毫秒）；只统计 0 < interval ≤ 1000ms 的有效间隔（剔除页面静置断档）"
    rep "- 统计：n（有效间隔数）、p50、p95、≤18.18ms 占比（55fps 门槛）、≤16.67ms 占比（60fps 参考）"
    rep "- 判定：n ≥ ${PERF_MIN_INTERVALS} 且 p95 ≤ ${PERF_MS_55}ms → PASS；n ≥ ${PERF_MIN_INTERVALS} 且 p95 > ${PERF_MS_55}ms → FAIL；n < ${PERF_MIN_INTERVALS} 或解析失败 → NOT RUN（数据不足不判，不虚报）"
    rep "- 帧率结论只基于实测间隔分布，不用「采样 N 秒数帧数」代替实际帧率"
    rep "- 原始 framestats 按 PoC/速度/主题分别保留（\`poc-<name>-perf-<speed>-<theme>-framestats.txt\`），可复核"
    rep "- transition 为静态探测页，按设计跳过 --perf 帧率采集，记 NOT RUN"
    rep ""
    rep "| PoC | 速度 | 主题 | n | p50(ms) | p95(ms) | ≤18.18ms | ≤16.67ms | 判定 |"
    rep "| --- | ---- | ---- | - | ------- | ------- | -------- | -------- | ---- |"
    if [ -s "$PERF_TSV" ]; then
      awk -F'\t' '{printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $1,$2,$3,$4,$5,$6,$7,$8,$9}' "$PERF_TSV" >> "$REPORT"
    else
      rep "（无 --perf 数据）"
    fi
    rep ""
  fi
  rep "## 说明与诚实标注"
  rep ""
  rep "- transition（PoC-4）为静态探测报告页：只截图，不录屏、不测帧率，属设计如此"
  rep "- Light/Dark 通过 \`adb shell cmd uimode night yes/no\` 切换，未重启 App；截图为系统深色模式实时渲染结果"
  rep "- Reduce Motion 通过 \`settings put global animator_duration_scale 0\` 生效（仅 droplet 抽查），结束后恢复原值"
  rep "- 录屏期间页面处于前台静置状态，未做点击交互；帧率反映的是页面静置/自有动画的采集窗口"
  if [ "$PERF_MODE" -eq 1 ]; then
    rep "  （--perf 模式：前台静置 ${PERF_SECS}s/次，深链启动后 reset 再采集；见上节 --perf 口径）"
  else
    rep "  （默认模式：10 秒窗口）"
  fi
  rep "- 本脚本不 root、不改系统分区；所有设备侧文件（/sdcard/poc-*）已拉取后删除"
  if [ "$DRY_RUN" -eq 1 ]; then
    rep "- **本次为 dry-run，未连接真机，所有 PASS 均为流程走查占位，不代表实测结论**"
  fi
  rep ""
  rep "## 失败 / NOT RUN 项"
  rep ""
  if [ "$fail_n" -eq 0 ] && [ "$notrun_n" -eq 0 ]; then
    rep "无。"
  else
    grep -E ' \| (FAIL|NOT RUN) \|' "$RESULTS_TSV" | awk -F' \\| ' '{printf "- [%s] %s：%s（%s）\n", $1, $2, $3, $4}' >> "$REPORT"
  fi
  rep ""
  rep "## 产物文件清单"
  rep ""
  rep '```'
  # 可移植写法（不用 GNU find -printf）：只列普通文件，跳过内部点文件
  local af asz
  for af in "$OUT_DIR"/*; do
    if [ -f "$af" ]; then
      asz="$(wc -c < "$af" | tr -d ' ')"
      printf '%s (%s bytes)\n' "$(basename "$af")" "$asz" >> "$REPORT"
    fi
  done
  rep '```'
  log "报告已生成：$REPORT"
}

# --------------------------------- 主流程 --------------------------------------
main() {
  parse_args "$@"

  mkdir -p "$OUT_DIR"
  REPORT="${OUT_DIR}/poc-acceptance-report-${TS}.md"
  RESULTS_TSV="${OUT_DIR}/.results.tsv"
  : > "$RESULTS_TSV"
  : > "$REPORT"

  if [ "$PERF_MODE" -eq 1 ]; then
    log "========== PoC 性能验收（--perf）开始（$TS）=========="
  else
    log "========== PoC 真机一键验收开始（$TS）=========="
  fi
  log "产物目录：$OUT_DIR"

  check_env
  collect_device_info
  save_initial_state
  resolve_apk
  install_apk

  if [ "$PERF_MODE" -eq 1 ]; then
    run_perf
  else
    local pocs="$POCS_ALL"
    [ "$ONLY_POC" != "all" ] && pocs="$ONLY_POC"
    local p
    for p in $pocs; do
      accept_poc "$p"
    done

    # Reduce Motion 只在 droplet 被选中时做
    case " $pocs " in
      *" droplet "*) reduce_motion_test ;;
      *) log "⑥ Reduce Motion：droplet 未被选中，跳过" ;;
    esac
  fi

  restore_settings
  write_report
  cleanup

  local absdir
  absdir="$(cd "$OUT_DIR" && pwd)"
  log "========== 验收完成 =========="
  log "汇总：FAIL ${FAIL_COUNT} 项，NOT RUN ${NOTRUN_COUNT} 项（详见报告）"
  printf '\n报告路径：%s\n产物目录：%s\n' "${absdir}/poc-acceptance-report-${TS}.md" "$absdir"
}

main "$@"
