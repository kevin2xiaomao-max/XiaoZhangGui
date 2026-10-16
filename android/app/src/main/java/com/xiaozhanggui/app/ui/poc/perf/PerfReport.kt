package com.xiaozhanggui.app.ui.poc.perf

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.Display
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 性能测试报告：设备信息采集 + Markdown 生成 + 导出（V3.8 真机验收补强 · Worker 3；debug only）。
 *
 * - 只读设备信息（`Build` / `DisplayManager` 公开 API），不写库、
 *   不碰 Room / Repository / AI；
 * - 导出二选一：① 系统分享（`ACTION_SEND`，纯文本 markdown）；
 *   ② 保存到 Download 目录（`MediaStore.Downloads`，API 29+，免权限）；
 * - API < 29 不申请 `WRITE_EXTERNAL_STORAGE`（免动 Manifest），
 *   直接返回 [SaveResult.ApiTooLow] 提示改用分享。
 */
object PerfReport {

    /** 报告头用设备信息（只读）。 */
    data class DeviceInfo(
        val model: String,
        val androidVersion: String,
        val apiLevel: Int,
        /** 屏幕刷新率 Hz；取不到为 0。 */
        val refreshRateHz: Float,
        val reduceMotion: Boolean,
    )

    /** 保存到 Download 的结果。 */
    sealed interface SaveResult {
        /** 成功：[uri] 为 MediaStore 条目。 */
        data class Saved(val uri: Uri) : SaveResult

        /** API < 29：MediaStore.Downloads 不可用，请用分享导出。 */
        data object ApiTooLow : SaveResult

        /** 写入失败（存储不可用等）。 */
        data object Failed : SaveResult
    }

    /** 采集设备信息（公开 API，无反射）。 */
    fun collectDeviceInfo(context: Context, reduceMotion: Boolean): DeviceInfo {
        val dm = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display: Display? = dm.getDisplay(Display.DEFAULT_DISPLAY)
        return DeviceInfo(
            model = "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            androidVersion = Build.VERSION.RELEASE ?: "unknown",
            apiLevel = Build.VERSION.SDK_INT,
            refreshRateHz = display?.refreshRate ?: 0f,
            reduceMotion = reduceMotion,
        )
    }

    /** 报告文件名：`xzg-v38-poc-perf-20261016-173000.md`。 */
    fun fileName(now: Date = Date()): String {
        val ts = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(now)
        return "xzg-v38-poc-perf-$ts.md"
    }

    /**
     * 生成 Markdown 报告。
     *
     * 口径（V3.8 口径审计结论）：
     * - 唯一判定依据：**帧间隔**（Choreographer frameTimeNanos 差分），
     *   p95 ≤ 18.18ms → PASS；
     * - **渲染耗时**（FrameMetrics TOTAL_DURATION）是绘制一帧花费的时间，
     *   不是帧间隔，**不能证明 FPS**，仅作参考信息展示。
     *
     * @param device 设备信息；[results] 各 PoC stage 渲染耗时摘要（参考，顺序即测试顺序）；
     * @param intervalResults 各 PoC stage 帧间隔摘要（判定依据）；
     * @param rawBuckets 原始分桶（stageId → ms→帧数），审计用，可空。
     */
    fun buildMarkdown(
        device: DeviceInfo,
        results: List<PerfStats.StageSummary>,
        rawBuckets: Map<String, Map<Int, Long>> = emptyMap(),
        intervalResults: List<PerfIntervalStats.IntervalSummary> = emptyList(),
        generatedAt: Date = Date(),
    ): String {
        val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.CHINA).format(generatedAt)
        val budget = "%.2f".format(Locale.US, PerfIntervalStats.FRAME_BUDGET_55FPS_MS)
        val sb = StringBuilder()
        sb.appendLine("# V3.8 PoC 真机性能测试报告")
        sb.appendLine()
        sb.appendLine("- 生成时间：$time")
        sb.appendLine("- 机型：${device.model}")
        sb.appendLine("- 系统：Android ${device.androidVersion}（API ${device.apiLevel}）")
        sb.appendLine("- 屏幕刷新率：${"%.1f".format(Locale.US, device.refreshRateHz)} Hz")
        sb.appendLine(
            "- Reduce Motion：" +
                if (device.reduceMotion) "开（系统可能跳过动画，结果仅供参考）" else "关",
        )
        sb.appendLine(
            "- 采集方式：① Choreographer 帧回调（frameTimeNanos 序列→帧间隔，公开 API，无反射）；" +
                "② androidx.core.app.FrameMetricsAggregator（公开 API，无反射）TOTAL_DURATION（渲染耗时，参考）",
        )
        sb.appendLine(
            "- 判定标准（唯一）：≥55fps ⇔ **帧间隔 p95** ≤ ${budget}ms；" +
                "渲染耗时**不能**用于判定（渲染耗时≠帧率）",
        )
        sb.appendLine()
        sb.appendLine("## 帧间隔（判定依据 · Choreographer）")
        sb.appendLine()
        sb.appendLine(
            "| PoC | 采集时长(s) | 帧数 | 有效间隔数 | p50(ms) | p95(ms) | " +
                "真实fps(中位) | 卡顿数(>2×vsync) | 卡顿率 | 刷新率假设 | 判定 |",
        )
        sb.appendLine("|---|---|---|---|---|---|---|---|---|---|---|")
        for (r in intervalResults) {
            val hzNote = if (r.assumedRefreshRate) {
                "${"%.0f".format(Locale.US, r.refreshRateHz)}Hz(假设)"
            } else {
                "${"%.0f".format(Locale.US, r.refreshRateHz)}Hz"
            }
            sb.appendLine(
                "| ${r.stageName} | ${"%.1f".format(Locale.US, r.durationSec)} | " +
                    "${r.frameCount} | ${r.intervalCount} | ${fmtMs(r.p50Ms)} | " +
                    "${fmtMs(r.p95Ms)} | ${fmtFps(r.fpsMedian)} | ${r.jankCount} | " +
                    "${fmtPct(r.jankRate)} | $hzNote | ${intervalVerdictText(r.verdict)} |",
            )
        }
        sb.appendLine()
        sb.appendLine("## 渲染耗时（参考信息 · FrameMetrics）")
        sb.appendLine()
        sb.appendLine(
            "> ⚠️ 渲染耗时是**绘制一帧花费的时间**，不是两帧的间隔；" +
                "绘制耗时小但等待 vsync/主线程休眠时，实际帧率仍可能很低。" +
                "本节仅作参考，**不参与 PASS 判定**。",
        )
        sb.appendLine()
        sb.appendLine("| PoC | 帧数 | p50(ms) | p95(ms) | 掉帧数(>18.18ms) | 掉帧率 |")
        sb.appendLine("|---|---|---|---|---|---|")
        for (r in results) {
            sb.appendLine(
                "| ${r.stageName} | ${r.frameCount} | ${fmtMs(r.p50Ms)} | " +
                    "${fmtMs(r.p95Ms)} | ${r.droppedFrames} | ${fmtPct(r.dropRate)} |",
            )
        }
        sb.appendLine()
        sb.appendLine("## 原始数据摘要")
        sb.appendLine()
        if (rawBuckets.isEmpty()) {
            sb.appendLine("（无）")
        } else {
            for ((stageId, buckets) in rawBuckets) {
                val total = buckets.values.sum()
                val bucketStr = buckets.keys.sorted()
                    .joinToString(", ") { "${it}→${buckets.getValue(it)}" }
                sb.appendLine("- $stageId：共 $total 帧；分桶（整数ms→帧数）：$bucketStr")
            }
        }
        sb.appendLine()
        sb.appendLine("## 方法说明")
        sb.appendLine()
        sb.appendLine(
            "1. 判定口径（审计结论）：≥55fps **只能**基于帧间隔判定——" +
                "Choreographer frameTimeNanos 序列相邻差分，p95 ≤ 18.18ms→PASS，" +
                "否则 FAIL；无有效间隔记 NO_DATA；",
        )
        sb.appendLine(
            "2. FrameMetrics TOTAL_DURATION 是**渲染耗时**（绘制一帧花费的时间），" +
                "不是帧间隔，**不能直接证明 FPS**，本报告中仅作参考信息展示，不参与判定；",
        )
        sb.appendLine(
            "3. 有效间隔：0 < dt ≤ 1s（剔除重复/乱序时间戳与页面静置断档），" +
                "与 --perf framestats 口径一致；",
        )
        sb.appendLine(
            "4. 帧间隔百分位取 nearest-rank（rank=ceil(p/100·N)，原始 ns 值排序）；" +
                "真实 fps = 1000 / 中位间隔；",
        )
        sb.appendLine(
            "5. 卡顿=帧间隔 > 2×vsync 预期（vsync 预期=1000/显示刷新率；" +
                "取不到刷新率时按 60Hz 假设，表中标注\"假设\"）；",
        )
        sb.appendLine("6. 每 stage 同时跑两个采集器（Choreographer + FrameMetrics），互不干扰；")
        sb.appendLine("7. 测试期间强制 PocSpeed 正常速度（慢放档会被临时关闭并恢复）；")
        sb.appendLine("8. 本报告由 Debug 构建 PoC 隔离区生成，不涉及生产业务数据。")
        return sb.toString()
    }

    /** 系统分享（`ACTION_SEND` 纯文本；调用方传入 Activity context）。 */
    fun share(context: Context, markdown: String, name: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, name)
            putExtra(Intent.EXTRA_TEXT, markdown)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(Intent.createChooser(intent, "分享性能测试报告"))
    }

    /**
     * 保存到 Download 目录（`MediaStore.Downloads`，API 29+ 免权限）。
     * API < 29 返回 [SaveResult.ApiTooLow]（不申请 Manifest 权限）。
     */
    fun saveToDownloads(context: Context, markdown: String, name: String): SaveResult {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return SaveResult.ApiTooLow
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, "text/markdown")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return SaveResult.Failed
            resolver.openOutputStream(uri)?.use { out ->
                out.write(markdown.toByteArray(Charsets.UTF_8))
            } ?: return SaveResult.Failed
            SaveResult.Saved(uri)
        } catch (e: Exception) {
            SaveResult.Failed
        }
    }

    private fun fmtMs(v: Double): String =
        if (v.isNaN()) "—" else "%.1f".format(Locale.US, v)

    private fun fmtFps(v: Double): String =
        if (v.isNaN()) "—" else "%.1f".format(Locale.US, v)

    private fun fmtPct(v: Double): String =
        if (v.isNaN()) "—" else "%.1f%%".format(Locale.US, v * 100.0)

    private fun intervalVerdictText(v: PerfIntervalStats.Verdict): String = when (v) {
        PerfIntervalStats.Verdict.PASS -> "PASS"
        PerfIntervalStats.Verdict.FAIL -> "FAIL"
        PerfIntervalStats.Verdict.NO_DATA -> "NO_DATA"
    }
}
