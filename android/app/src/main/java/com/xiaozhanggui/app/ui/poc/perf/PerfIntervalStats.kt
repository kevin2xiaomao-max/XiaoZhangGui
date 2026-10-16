package com.xiaozhanggui.app.ui.poc.perf

import kotlin.math.ceil

/**
 * Choreographer 帧间隔统计（V3.8 口径审计 · Worker B；debug only）。
 *
 * 纯 Kotlin，无 Android 依赖，JVM 可单测（见 `PerfIntervalStatsTest`）。
 * 输入为 [PerfIntervalCollector] 采集的 frameTimeNanos 序列（ns）。
 *
 * 判定口径（用户审核结论，唯一判定依据）：
 * - ≥55fps ⇔ **帧间隔** p95 ≤ 1000/55 ≈ 18.18ms；
 * - FrameMetrics TOTAL_DURATION 是**渲染耗时**（绘制一帧花费的时间），
 *   不是帧间隔，**不得用于 PASS 判定**，仅作参考信息展示。
 *
 * 口径定义速查：
 * - 渲染耗时（FrameMetrics）：一帧绘制花费的时间；参考信息，不判定。
 * - 刷新率（Display）：屏幕物理刷新 Hz；用于推导 vsync 预期（假设）。
 * - 帧间隔（Choreographer frameTimeNanos 差分）：两帧相隔时间；判定依据。
 * - 卡顿率：帧间隔 > 2×vsync 预期的占比（vsync 预期=1000/刷新率Hz，
 *   取不到刷新率时按 60Hz 假设，摘要中明确标注）。
 */
object PerfIntervalStats {

    /** ≥55fps 判定阈值：1000/55 ≈ 18.1818ms（与 [PerfStats.FRAME_BUDGET_55FPS_MS] 同值）。 */
    const val FRAME_BUDGET_55FPS_MS = 1000.0 / 55.0

    /** 取不到显示刷新率时的默认假设（60Hz），摘要中明确标注为假设。 */
    const val DEFAULT_REFRESH_RATE_HZ = 60.0

    /** 有效间隔上限：1s（剔除页面静置断档，与 --perf 的 1000ms 上限一致）。 */
    const val MAX_VALID_INTERVAL_NS = 1_000_000_000L

    /** 帧间隔判定（唯一判定依据）。 */
    enum class Verdict {
        /** 帧间隔 p95 ≤ 18.18ms：达到 ≥55fps。 */
        PASS,

        /** 帧间隔 p95 > 18.18ms：未达标。 */
        FAIL,

        /** 无有效帧间隔（采集失败/退后台/无 vsync）：不判通过。 */
        NO_DATA,
    }

    /** 单个 PoC stage 的帧间隔摘要。 */
    data class IntervalSummary(
        val stageId: String,
        val stageName: String,
        /** 采集到的 frameTimeNanos 点数。 */
        val frameCount: Int,
        /** 有效间隔数（0 < dt ≤ 1s）。 */
        val intervalCount: Int,
        /** 实际采集时长（秒）。 */
        val durationSec: Double,
        val p50Ms: Double,
        val p95Ms: Double,
        /** 卡顿数：间隔 > 2×vsync 预期。 */
        val jankCount: Long,
        /** 卡顿率 0..1。 */
        val jankRate: Double,
        /** 由中位间隔换算的真实 fps = 1000/p50。 */
        val fpsMedian: Double,
        /** 计算卡顿时采用的刷新率假设（Hz）；实际取值见 [assumedRefreshRate]。 */
        val refreshRateHz: Double,
        /** refreshRateHz 是否为实际显示刷新率（false=取不到，按 60Hz 假设）。 */
        val assumedRefreshRate: Boolean,
        val verdict: Verdict,
    )

    /**
     * 相邻差分求帧间隔：`dt[i] = t[i+1] − t[i]`。
     * 只保留 `0 < dt ≤ [MAX_VALID_INTERVAL_NS]` 的有效间隔
     * （剔除重复/乱序时间戳与页面静置断档）。
     */
    fun intervalsNs(frameTimesNs: List<Long>): List<Long> {
        if (frameTimesNs.size < 2) return emptyList()
        val out = ArrayList<Long>(frameTimesNs.size - 1)
        for (i in 0 until frameTimesNs.size - 1) {
            val dt = frameTimesNs[i + 1] - frameTimesNs[i]
            if (dt > 0 && dt <= MAX_VALID_INTERVAL_NS) out.add(dt)
        }
        return out
    }

    /**
     * nearest-rank 百分位（ms）：rank=ceil(p/100·N)，取排序后第 rank 个值。
     * 空输入返回 NaN。
     */
    fun percentileMs(intervalsNs: List<Long>, p: Double): Double {
        require(p in 0.0..100.0) { "p must be in 0..100, was $p" }
        if (intervalsNs.isEmpty()) return Double.NaN
        val sorted = intervalsNs.sorted()
        val rank = ceil(p / 100.0 * sorted.size).toInt().coerceAtLeast(1)
        return sorted[rank - 1] / 1_000_000.0
    }

    /** 由中位帧间隔（ms）换算真实 fps。 */
    fun fpsFromMedianIntervalMs(medianMs: Double): Double = 1000.0 / medianMs

    /** vsync 预期（ms）= 1000 / 刷新率Hz。 */
    fun vsyncExpectedMs(refreshRateHz: Double): Double = 1000.0 / refreshRateHz

    /**
     * 卡顿数：帧间隔 > 2×vsync 预期的个数。
     * @param vsyncExpectedMs 由显示刷新率或 60Hz 默认假设推导，调用方需标注假设。
     */
    fun jankCount(intervalsNs: List<Long>, vsyncExpectedMs: Double): Long {
        val thresholdNs = (2.0 * vsyncExpectedMs * 1_000_000.0).toLong()
        return intervalsNs.count { it > thresholdNs }.toLong()
    }

    /**
     * 由 frameTimeNanos 序列生成单 stage 摘要（含判定）。
     *
     * @param refreshRateHz 显示刷新率（Hz）；≤0 时按 [DEFAULT_REFRESH_RATE_HZ]
     *   假设并在摘要中标注 [IntervalSummary.assumedRefreshRate]=true。
     */
    fun summarize(
        stageId: String,
        stageName: String,
        frameTimesNs: List<Long>,
        durationSec: Double,
        refreshRateHz: Double = DEFAULT_REFRESH_RATE_HZ,
    ): IntervalSummary {
        val intervals = intervalsNs(frameTimesNs)
        val assumed = refreshRateHz <= 0.0
        val hz = if (assumed) DEFAULT_REFRESH_RATE_HZ else refreshRateHz
        if (intervals.isEmpty()) {
            return IntervalSummary(
                stageId = stageId,
                stageName = stageName,
                frameCount = frameTimesNs.size,
                intervalCount = 0,
                durationSec = durationSec,
                p50Ms = Double.NaN,
                p95Ms = Double.NaN,
                jankCount = 0L,
                jankRate = Double.NaN,
                fpsMedian = Double.NaN,
                refreshRateHz = hz,
                assumedRefreshRate = assumed,
                verdict = Verdict.NO_DATA,
            )
        }
        val p50 = percentileMs(intervals, 50.0)
        val p95 = percentileMs(intervals, 95.0)
        val vsyncMs = vsyncExpectedMs(hz)
        val jank = jankCount(intervals, vsyncMs)
        return IntervalSummary(
            stageId = stageId,
            stageName = stageName,
            frameCount = frameTimesNs.size,
            intervalCount = intervals.size,
            durationSec = durationSec,
            p50Ms = p50,
            p95Ms = p95,
            jankCount = jank,
            jankRate = jank.toDouble() / intervals.size,
            fpsMedian = fpsFromMedianIntervalMs(p50),
            refreshRateHz = hz,
            assumedRefreshRate = assumed,
            verdict = if (p95 <= FRAME_BUDGET_55FPS_MS) Verdict.PASS else Verdict.FAIL,
        )
    }
}
