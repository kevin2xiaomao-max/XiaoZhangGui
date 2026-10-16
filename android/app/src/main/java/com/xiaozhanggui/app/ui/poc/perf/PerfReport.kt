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
     * @param device 设备信息；[results] 各 PoC stage 摘要（顺序即测试顺序）；
     * @param rawBuckets 原始分桶（stageId → ms→帧数），审计用，可空。
     */
    fun buildMarkdown(
        device: DeviceInfo,
        results: List<PerfStats.StageSummary>,
        rawBuckets: Map<String, Map<Int, Long>> = emptyMap(),
        generatedAt: Date = Date(),
    ): String {
        val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.CHINA).format(generatedAt)
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
            "- 采集方式：androidx.core.app.FrameMetricsAggregator（公开 API，无反射）" +
                "TOTAL_DURATION",
        )
        sb.appendLine(
            "- 判定标准：≥55fps ⇔ p95 ≤ " +
                "${"%.2f".format(Locale.US, PerfStats.FRAME_BUDGET_55FPS_MS)}ms",
        )
        sb.appendLine()
        sb.appendLine("## 结果")
        sb.appendLine()
        sb.appendLine("| PoC | 采集时长(s) | 帧数 | p50(ms) | p95(ms) | 掉帧数(>18.18ms) | 掉帧率 | 判定 |")
        sb.appendLine("|---|---|---|---|---|---|---|---|")
        for (r in results) {
            sb.appendLine(
                "| ${r.stageName} | ${"%.1f".format(Locale.US, r.durationSec)} | " +
                    "${r.frameCount} | ${fmtMs(r.p50Ms)} | ${fmtMs(r.p95Ms)} | " +
                    "${r.droppedFrames} | ${fmtPct(r.dropRate)} | ${verdictText(r.verdict)} |",
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
            "1. 每 stage 独立创建 FrameMetricsAggregator，动画序列期间采集，" +
                "结束后读取 TOTAL_DURATION 分桶；",
        )
        sb.appendLine("2. 分桶 key 为整数 ms（向下取整，FrameMetrics 公开 API 固有粒度），" + "p50/p95/掉帧率为该精度的近似值；")
        sb.appendLine("3. 百分位取 nearest-rank（rank=ceil(p/100·N)）；")
        sb.appendLine("4. 掉帧=单帧>18.18ms；判定 p95≤18.18ms→PASS，否则 FAIL；0 帧记 NO_DATA；")
        sb.appendLine("5. 测试期间强制 PocSpeed 正常速度（慢放档会被临时关闭并恢复）；")
        sb.appendLine("6. 本报告由 Debug 构建 PoC 隔离区生成，不涉及生产业务数据。")
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

    private fun fmtPct(v: Double): String =
        if (v.isNaN()) "—" else "%.1f%%".format(Locale.US, v * 100.0)

    private fun verdictText(v: PerfStats.Verdict): String = when (v) {
        PerfStats.Verdict.PASS -> "PASS"
        PerfStats.Verdict.FAIL -> "FAIL"
        PerfStats.Verdict.NO_DATA -> "NO_DATA"
    }
}
