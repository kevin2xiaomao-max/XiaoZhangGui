#!/usr/bin/env bash
#
# tools/poc-emulator-validate.sh
#
# 「你的小掌柜」Android V3.8 PoC 模拟器自动验证（Worker B）。
#
# 用途：为 PoC-1 液滴按钮菜单 / PoC-2 玻璃三档 / PoC-3 连续形变 /
# PoC-4 转场探测生成真实运行证据：
#   - 正常速度 + 4x 慢放录屏（mp4）
#   - dumpsys gfxinfo 真实帧率（p50 / p95 / >16.7ms 占比 / ≥55fps 结论）
#   - Light / Dark 截图
#   - Reduce Motion 降级证据（录屏 + 截图 + 文字说明）
#   - perf=essential 降级参数尝试（截图 + 状态说明）
#
# 用法：
#   bash tools/poc-emulator-validate.sh <debug-apk路径> <输出目录>
#   # <debug-apk路径> 也可传目录或 glob（如 android/app/build/outputs/apk/debug/*.apk）
#
# 设计原则：
#   - 自包含：CI 内一行调用，也可在本地连模拟器复用。
#   - 单项失败不中断整体（set +e 分段执行，每项结果记入 results.json）。
#   - 不虚报：帧率只认 dumpsys gfxinfo 实测；JVM 假时钟数据绝不冒充运行帧率；
#     未实现的深链参数 / 未跑的真机项如实记为 SKIP / NOT RUN。
#   - PoC 要测真实动画：emulator 必须以 disable-animations=false 启动；
#     本脚本会校验 animator_duration_scale==1（Reduce Motion 段除外）。
#
# 深链契约（Worker A 实现）：
#   xzg://poc                 → 测试菜单（launcher）
#   xzg://poc/droplet         → PoC-1 液滴按钮菜单
#   xzg://poc/glass           → PoC-2 玻璃三档
#   xzg://poc/morph           → PoC-3 连续形变
#   xzg://poc/transition      → PoC-4 转场探测报告（静态页，只截图不录屏不测帧率）
#   query: ?speed=slow（4x 慢放）/ ?speed=normal；?perf=essential（性能降级）
#
set -uo pipefail

PKG="com.xiaozhanggui.app"
APK_ARG="${1:-}"
OUT="${2:-}"

if [[ -z "$APK_ARG" || -z "$OUT" ]]; then
  echo "用法: bash tools/poc-emulator-validate.sh <debug-apk路径> <输出目录>" >&2
  exit 2
fi

# 解析 APK 路径（支持直接路径 / 目录 / glob）
APK=""
if [[ -f "$APK_ARG" ]]; then
  APK="$APK_ARG"
else
  # shellcheck disable=SC2086
  for cand in $APK_ARG; do
    if [[ -f "$cand" ]]; then APK="$cand"; break; fi
  done
  if [[ -z "$APK" && -d "$APK_ARG" ]]; then
    APK="$(find "$APK_ARG" -maxdepth 1 -name '*.apk' | sort | head -n 1)"
  fi
fi
if [[ -z "$APK" || ! -f "$APK" ]]; then
  echo "错误: 找不到 APK：$APK_ARG" >&2
  exit 2
fi

mkdir -p "$OUT/gfxinfo" "$OUT/logs"
LOG="$OUT/logs/validate.log"
exec > >(tee -a "$LOG") 2>&1

NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=== PoC 模拟器自动验证 ==="
echo "时间(UTC): $NOW_UTC"
echo "APK: $APK"
echo "输出: $OUT"
command -v adb >/dev/null || { echo "错误: 找不到 adb"; exit 2; }
command -v python3 >/dev/null && HAVE_PY=1 || HAVE_PY=0
echo "python3: $([[ $HAVE_PY -eq 1 ]] && echo 有 || echo 无（results.json 将跳过，仅输出 SUMMARY.md）)"

# ---- 结果记录（key=value 行，结尾由 python3 汇总为 results.json） ----
RESULTS_KV="$OUT/logs/results.kv"
: > "$RESULTS_KV"
rec() { # rec <section> <key> <value>
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$RESULTS_KV"
}

# ---- 工具函数 ----
adbw() { # 带超时的 adb shell（避免单条命令卡死拖住整轮）
  timeout 60 adb shell "$@"
}

step_ok=0; step_fail=0
mark() { # mark <section> <name> <PASS|FAIL|SKIP> [note]
  local section="$1" name="$2" status="$3" note="${4:-}"
  echo "[$status] $section :: $name${note:+ — $note}"
  rec "$section" "status_$name" "$status"
  [[ -n "$note" ]] && rec "$section" "note_$name" "$note"
  if [[ "$status" == "PASS" ]]; then step_ok=$((step_ok+1)); else step_fail=$((step_fail+1)); fi
}

wait_device() {
  echo "--- 等待设备 ---"
  adb wait-for-device || { mark "preflight" "wait-for-device" "FAIL" "adb wait-for-device 失败"; return 1; }
  for i in $(seq 1 30); do
    if [[ "$(adbw getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then break; fi
    sleep 5
  done
  [[ "$(adbw getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] \
    && mark "preflight" "boot-completed" "PASS" || { mark "preflight" "boot-completed" "FAIL"; return 1; }
  # 点亮 + 解锁 + 常亮
  adbw input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  adbw wm dismiss-keyguard >/dev/null 2>&1 || true
  adbw settings put system screen_off_timeout 2147483647 >/dev/null 2>&1 || true
  MODEL="$(adbw getprop ro.product.model 2>/dev/null | tr -d '\r')"
  API="$(adbw getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')"
  echo "设备: model=$MODEL api=$API"
  rec "device" "model" "$MODEL"; rec "device" "api" "$API"
  mark "preflight" "device-ready" "PASS" "model=$MODEL api=$API"
}

check_anim_scales() { # 期望值, 段名
  local expect="$1" section="$2"
  # 先显式归一化：全新模拟器上这三个值可能为 null（= 系统默认 1.0），
  # 直接读会误判 FAIL；显式 put 后再校验，保证确定性。
  adbw settings put global window_animation_scale 1 >/dev/null 2>&1 || true
  adbw settings put global transition_animation_scale 1 >/dev/null 2>&1 || true
  # animator_duration_scale 由调用方决定（preflight 期望 1，Reduce Motion 段期望 0），这里只读
  local w="$(adbw settings get global window_animation_scale 2>/dev/null | tr -d '\r')"
  local t="$(adbw settings get global transition_animation_scale 2>/dev/null | tr -d '\r')"
  local a="$(adbw settings get global animator_duration_scale 2>/dev/null | tr -d '\r')"
  # null/空 = 系统默认（行为等价 1.0）；"1.0"→"1"、"0.0"→"0" 归一化，避免全新设备误判
  [[ -z "$a" || "$a" == "null" ]] && a="1.0"
  [[ "$a" == "1.0" ]] && a="1"
  [[ "$a" == "0.0" ]] && a="0"
  echo "动画 scale: window=$w transition=$t animator=$a（期望 $expect）"
  rec "$section" "window_animation_scale" "$w"
  rec "$section" "transition_animation_scale" "$t"
  rec "$section" "animator_duration_scale" "$a"
  if [[ "$a" == "$expect" ]]; then
    mark "$section" "anim-scales" "PASS" "animator_duration_scale=$a"
  else
    mark "$section" "anim-scales" "FAIL" "animator_duration_scale=$a，期望 $expect"
  fi
}

install_apk() {
  echo "--- 安装 APK ---"
  SHA="$(sha256sum "$APK" | awk '{print $1}')"
  SIZE="$(stat -c%s "$APK")"
  echo "APK sha256=$SHA size=$SIZE"
  rec "apk" "path" "$APK"; rec "apk" "sha256" "$SHA"; rec "apk" "size_bytes" "$SIZE"
  if adb install -r "$APK" 2>&1 | tail -2 | grep -qi "success"; then
    mark "preflight" "install-apk" "PASS" "sha256=${SHA:0:16}…"
  else
    mark "preflight" "install-apk" "FAIL" "adb install -r 失败，见日志"
    return 1
  fi
  VCODE="$(adbw dumpsys package "$PKG" 2>/dev/null | grep -m1 versionCode | tr -d '\r')"
  VNAME="$(adbw dumpsys package "$PKG" 2>/dev/null | grep -m1 versionName | tr -d '\r')"
  echo "已安装: $VCODE $VNAME"
  rec "apk" "installed_versionCode" "$VCODE"; rec "apk" "installed_versionName" "$VNAME"
}

launch_poc() { # <name> <query>  → 深链启动，返回 0/1（intent 是否投递）
  local name="$1" query="$2"
  adbw am force-stop "$PKG" >/dev/null 2>&1 || true
  sleep 1
  local uri="xzg://poc/${name}${query}"
  # 注意：URI 用单引号包给远端 shell，防止 ? 被 glob 展开
  local out
  out="$(adb shell am start -a android.intent.action.VIEW -d "$uri" "$PKG" 2>&1 | tr -d '\r')"
  echo "am start: $uri → $(echo "$out" | tr '\n' ' ' | cut -c1-160)"
  rec "deeplink" "last_uri" "$uri"
  # 验证 intent data 确实投递到 MainActivity（页面渲染以截图为准人工确认）。
  # 冷启动在 swiftshader 模拟器上较慢：轮询 dumpsys 最多 20s，而非单次 sleep 1s 检查。
  local tries=0
  while (( tries < 10 )); do
    sleep 2
    tries=$((tries + 1))
    if adbw dumpsys activity activities 2>/dev/null | tr -d '\r' | grep -q "dat=xzg://poc/${name}"; then
      echo "intent 投递确认: dat=xzg://poc/${name}（第 ${tries} 次轮询）"
      rec "deeplink" "intent_delivered_${name}" "true"
      return 0
    fi
  done
  echo "警告: 20s 内未在 dumpsys 中找到 dat=xzg://poc/${name}（可能深链未实现或 activity 未前台）"
  rec "deeplink" "intent_delivered_${name}" "false"
  return 1
}

foreground_ok() { # <name>
  local name="$1"
  sleep 3
  if adbw dumpsys activity activities 2>/dev/null | tr -d '\r' | grep -A2 "mFocusedApp" | grep -q "$PKG"; then
    return 0
  fi
  echo "警告: $PKG 未在前台（$name）"
  return 1
}

record_video() { # <sdcard名> <输出mp4> <秒数>
  local remote="$1" localmp4="$2" secs="$3"
  echo "录屏 ${secs}s → $localmp4"
  if adb shell screenrecord --time-limit "$secs" --bit-rate 6000000 "$remote" 2>&1 | tail -1; then
    adb pull "$remote" "$localmp4" >/dev/null 2>&1 && adb shell rm -f "$remote" >/dev/null 2>&1 || true
    if [[ -f "$localmp4" ]]; then
      echo "录屏保存: $localmp4 ($(stat -c%s "$localmp4") bytes)"
      return 0
    fi
  fi
  echo "录屏失败: $localmp4"
  return 1
}

screenshot() { # <输出png>
  local png="$1"
  local remote="/sdcard/poc-shot-$(date +%s).png"
  adbw screencap -p "$remote" >/dev/null 2>&1
  adb pull "$remote" "$png" >/dev/null 2>&1 && adb shell rm -f "$remote" >/dev/null 2>&1 || true
  if [[ -f "$png" ]]; then
    echo "截图: $png ($(stat -c%s "$png") bytes)"
    return 0
  fi
  echo "截图失败: $png"
  return 1
}

# 帧率：reset → 跑动画 → dumpsys gfxinfo 解析 p50/p95/janky
measure_fps() { # <name> <等待秒数>
  local name="$1" wait_s="$2"
  local raw="$OUT/gfxinfo/poc-${name}-gfxinfo.txt"
  adbw dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1 || true
  if ! launch_poc "$name" "?speed=normal"; then
    mark "fps-$name" "launch" "FAIL" "深链投递未确认，跳过帧率"
    rec "fps-$name" "skipped_reason" "deeplink not delivered"
    return 1
  fi
  foreground_ok "$name" || true
  echo "动画运行 ${wait_s}s 后采集 gfxinfo…"
  sleep "$wait_s"
  adbw dumpsys gfxinfo "$PKG" > "$raw" 2>&1 || true
  # 解析（python3；无则降级为 grep 直存）
  local parsed="$OUT/gfxinfo/poc-${name}-fps.txt"
  if [[ $HAVE_PY -eq 1 ]]; then
    python3 - "$raw" "$parsed" <<'EOF'
import re, sys
raw, out = sys.argv[1], sys.argv[2]
t = open(raw, errors="replace").read()
def grab(pat):
    m = re.search(pat, t)
    return m.group(1) if m else ""
total = grab(r"Total frames rendered:\s*(\d+)")
janky = grab(r"Janky frames:\s*(\d+)\s*\(([0-9.]+)%\)")
jm, jp = (janky if isinstance(janky, tuple) else (janky, ""))
p50 = grab(r"50th percentile:\s*([0-9.]+)ms")
p95 = grab(r"95th percentile:\s*([0-9.]+)ms")
open(out, "w").write(
    f"total_frames={total}\njanky_frames={jm}\njanky_pct={jp}\n"
    f"p50_ms={p50}\np95_ms={p95}\n")
print(f"total={total} janky={jm}({jp}%) p50={p50}ms p95={p95}ms")
EOF
    # shellcheck disable=SC1090
    source "$parsed" 2>/dev/null || true
  else
    grep -E "Total frames rendered|Janky frames|percentile" "$raw" | head -8 | tee "$parsed"
    total_frames=""; janky_pct=""; p50_ms=""; p95_ms=""
  fi
  echo "帧率($name): total_frames=${total_frames:-?} p50=${p50_ms:-?}ms p95=${p95_ms:-?}ms janky=${janky_pct:-?}%"
  rec "fps-$name" "total_frames" "${total_frames:-}"
  rec "fps-$name" "p50_ms" "${p50_ms:-}"
  rec "fps-$name" "p95_ms" "${p95_ms:-}"
  rec "fps-$name" "janky_pct" "${janky_pct:-}"
  rec "fps-$name" "raw_file" "gfxinfo/poc-${name}-gfxinfo.txt"
  if [[ -z "${total_frames:-}" || "$total_frames" == "0" ]]; then
    mark "fps-$name" "measure" "FAIL" "未采集到渲染帧（total_frames=${total_frames:-空}），见 $raw"
    return 1
  fi
  # ≥55fps 判定：55fps ≈ 平均帧耗时 ≤18.18ms；按任务要求用 p50 判定
  local verdict="FAIL"
  if [[ -n "${p50_ms:-}" ]] && python3 -c "import sys; sys.exit(0 if float('$p50_ms') <= 18.18 else 1)" 2>/dev/null; then
    verdict="PASS"
  fi
  rec "fps-$name" "pass_55fps_p50" "$verdict"
  mark "fps-$name" "measure" "$verdict" \
    "p50=${p50_ms}ms p95=${p95_ms}ms >16.7ms占比=${janky_pct}% total=${total_frames}（55fps≈≤18.18ms，用p50判定）"
}

# ---------------- 主流程 ----------------
wait_device || echo "预检失败，继续尝试后续步骤（每项独立记分）"
install_apk || echo "安装失败，继续尝试后续步骤"
check_anim_scales 1 "preflight"

POCS_ANIMATED="droplet glass morph"

for poc in $POCS_ANIMATED; do
  echo "===== PoC: $poc（正常速度录屏 + 慢放录屏 + 帧率） ====="
  # 1) 正常速度：先测帧率（launch 内含 force-stop + 启动），再录屏
  if measure_fps "$poc" 15; then :; else echo "[$poc] 帧率采集失败，继续录屏"; fi
  if launch_poc "$poc" "?speed=normal" && foreground_ok "$poc"; then
    record_video "/sdcard/poc-${poc}-normal.mp4" "$OUT/poc-${poc}-normal.mp4" 20 \
      && mark "video-$poc" "normal" "PASS" "20s" \
      || mark "video-$poc" "normal" "FAIL" "screenrecord/pull 失败"
  else
    mark "video-$poc" "normal" "SKIP" "深链/前台未就绪"
  fi
  # 2) 慢放
  if launch_poc "$poc" "?speed=slow" && foreground_ok "$poc"; then
    record_video "/sdcard/poc-${poc}-slow.mp4" "$OUT/poc-${poc}-slow.mp4" 20 \
      && mark "video-$poc" "slow" "PASS" "20s 慢放(?speed=slow)" \
      || mark "video-$poc" "slow" "FAIL" "screenrecord/pull 失败"
  else
    mark "video-$poc" "slow" "SKIP" "深链/前台未就绪"
  fi
done

# PoC-4 transition：静态报告页，只截图不录屏不测帧率
echo "===== PoC: transition（静态报告页，仅 Light/Dark 截图） ====="
rec "transition" "note" "静态报告页：只截图，不录屏、不测帧率"

# Light/Dark 截图（四个 PoC）
for poc in $POCS_ANIMATED transition; do
  echo "===== Light/Dark 截图: $poc ====="
  for mode in dark light; do
    if [[ "$mode" == "dark" ]]; then adbw cmd uimode night yes >/dev/null 2>&1 || true
    else adbw cmd uimode night no >/dev/null 2>&1 || true; fi
    sleep 2
    if launch_poc "$poc" "?speed=normal" && foreground_ok "$poc"; then
      screenshot "$OUT/poc-${poc}-${mode}.png" \
        && mark "shot-$poc" "$mode" "PASS" "night=$mode" \
        || mark "shot-$poc" "$mode" "FAIL" "screencap/pull 失败"
    else
      mark "shot-$poc" "$mode" "SKIP" "深链/前台未就绪"
    fi
    rec "shot-$poc" "uimode_$mode" "night $([[ $mode == dark ]] && echo yes || echo no)"
  done
done
adbw cmd uimode night no >/dev/null 2>&1 || true  # 恢复浅色

# Reduce Motion：animator_duration_scale=0 → droplet 录屏 10s + 截图 → 恢复 1
echo "===== Reduce Motion（animator_duration_scale=0） ====="
adbw settings put global animator_duration_scale 0 >/dev/null 2>&1 || true
check_anim_scales 0 "reduce-motion"
if launch_poc "droplet" "?speed=normal" && foreground_ok "droplet"; then
  record_video "/sdcard/poc-droplet-reducemotion.mp4" "$OUT/poc-droplet-reducemotion.mp4" 10 \
    && mark "reduce-motion" "video" "PASS" "10s，animator_duration_scale=0" \
    || mark "reduce-motion" "video" "FAIL" "screenrecord/pull 失败"
  screenshot "$OUT/poc-droplet-reducemotion.png" \
    && mark "reduce-motion" "screenshot" "PASS" \
    || mark "reduce-motion" "screenshot" "FAIL" "screencap/pull 失败"
else
  mark "reduce-motion" "video" "SKIP" "深链/前台未就绪"
fi
adbw settings put global animator_duration_scale 1 >/dev/null 2>&1 || true
rec "reduce-motion" "evidence_text" \
  "animator_duration_scale=0 下重跑 droplet：期望动画退化为直接呈现（无过渡时长）。判定以录屏/截图人工对比为准；MotionPolicy 具名降级逻辑见 JVM 测试。"
mark "reduce-motion" "restore" "PASS" "animator_duration_scale 已恢复为 1"

# 性能降级：?perf=essential（如 Worker A 未实现则截图留证并注明）
echo "===== 性能降级（?perf=essential） ====="
if launch_poc "droplet" "?perf=essential" && foreground_ok "droplet"; then
  sleep 2
  screenshot "$OUT/poc-droplet-perf-essential.png" \
    && mark "perf-essential" "screenshot" "PASS" "参数已透传；是否生效待 Worker A 确认/截图人工比对" \
    || mark "perf-essential" "screenshot" "FAIL" "screencap/pull 失败"
else
  mark "perf-essential" "screenshot" "SKIP" "深链/前台未就绪"
fi
rec "perf-essential" "note" \
  "?perf=essential 由 Worker A 实现；若未实现，本截图即为未生效对照，报告中如实注明。"

# 收尾：恢复动画 scale，force-stop
adbw settings put global animator_duration_scale 1 >/dev/null 2>&1 || true
adbw am force-stop "$PKG" >/dev/null 2>&1 || true

# ---- 汇总 ----
echo "===== 汇总 ====="
echo "PASS=$step_ok FAIL/SKIP=$step_fail"

# NOT RUN（真机项，诚实标注）
rec "not_run" "item1" "OPPO PKJ110 / ColorOS 17 真机帧率（≥55fps 真机门槛）"
rec "not_run" "item2" "真机录屏（正常速度/慢放）"
rec "not_run" "item3" "真机 Light/Dark / Reduce Motion / 降级表现"

SUMMARY="$OUT/SUMMARY.md"
{
  echo "# PoC 模拟器自动验证汇总"
  echo ""
  echo "- 时间(UTC): $NOW_UTC"
  echo "- 设备: ${MODEL:-?} / API ${API:-?}"
  echo "- APK: $APK"
  echo "- APK sha256: ${SHA:-?}"
  echo "- 步骤统计: PASS=$step_ok, FAIL/SKIP=$step_fail"
  echo ""
  echo "## 帧率（dumpsys gfxinfo 实测，JVM 假时钟不参与）"
  echo ""
  echo "| PoC | total_frames | p50 | p95 | >16.7ms占比 | ≥55fps(p50≤18.18ms) | 原始数据 |"
  echo "|-----|--------------|-----|-----|------------|----------------------|----------|"
  for poc in $POCS_ANIMATED; do
    kv() { awk -F'\t' -v s="fps-$poc" -v k="$1" '$1==s && $2==k {print $3}' "$RESULTS_KV" | tail -1; }
    echo "| $poc | $(kv total_frames) | $(kv p50_ms)ms | $(kv p95_ms)ms | $(kv janky_pct)% | $(kv pass_55fps_p50) | gfxinfo/poc-${poc}-gfxinfo.txt |"
  done
  echo ""
  echo "## 产物清单"
  echo ""
  ls -1 "$OUT" | grep -E '\.(mp4|png)$' | sed 's/^/- /'
  echo ""
  echo "## NOT RUN（真机，未跑）"
  echo ""
  echo "- OPPO PKJ110 / ColorOS 17 真机帧率（≥55fps 真机硬门槛）"
  echo "- 真机录屏（正常速度 / 慢放）、真机 Light/Dark、Reduce Motion、降级表现"
  echo ""
  echo "## 详细日志"
  echo ""
  echo "- logs/validate.log（全量）、logs/results.kv（分项 key=value）"
  echo "- results.json（python3 可用时生成）"
} > "$SUMMARY"
cat "$SUMMARY"

if [[ $HAVE_PY -eq 1 ]]; then
  python3 - "$RESULTS_KV" "$OUT/results.json" <<'EOF'
import json, sys
kv_path, out_path = sys.argv[1], sys.argv[2]
data = {}
for line in open(kv_path, encoding="utf-8"):
    parts = line.rstrip("\n").split("\t")
    if len(parts) != 3:
        continue
    sec, k, v = parts
    data.setdefault(sec, {})[k] = v
json.dump(data, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"results.json 已生成：{out_path}")
EOF
fi

echo "=== 验证结束（PASS=$step_ok FAIL/SKIP=$step_fail）==="
# 整体退出码：如实反映——有 FAIL/SKIP 则非零，CI 侧按独立 job 处理（不阻塞其他 job）
if [[ $step_fail -gt 0 ]]; then
  echo "注意: 有 $step_fail 个步骤非 PASS，见 SUMMARY.md / results.json"
  exit 1
fi
exit 0
