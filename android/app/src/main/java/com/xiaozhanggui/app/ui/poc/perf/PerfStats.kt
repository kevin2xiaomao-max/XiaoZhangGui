package com.xiaozhanggui.app.ui.poc.perf

import kotlin.math.ceil

/**
 * 真机帧率统计（V3.8 真机验收补强 · Worker 3；debug only）。
 *
 * 纯 Kotlin，无 Android 依赖，JVM 可单测（见 `PerfStatsTest`）。
 * 输入为 [PerfFrameCollector] 采集的帧耗时分桶（ms → 帧数）。
 *
 * 判定口径（与 `tools/poc-acceptance.sh --perf` 一致）：
 * - ≥55fps ⇔ p95 帧耗时 ≤ 1000/55 ≈ 18.18ms；
 * - 掉帧：单帧耗时 > 18.18ms。
 *
 * 精度说明：[PerfFrameCollector] 的分桶 key 为整数 ms（FrameMetrics
 * 公开 API 的固有粒度，向下取整），p50/p95/掉帧率均为该精度的近似值；
 * 原始分桶随报告导出，可审计。
 */
object PerfStats {

    /** ≥55fps 判定阈值：1000/55 ≈ 18.1818ms。 */
    const val FRAME_BUDGET_55FPS_MS = 1000.0 / 55.0

    /** 单 stage 判定。 */
    enum class Verdict {
        /** p95 ≤ 18.18ms：达到 ≥55fps。 */
        PASS,

        /** p95 > 18.18ms：未达标。 */
        FAIL,

        /** 采集到 0 帧（采集器启动失败/窗口无帧产出）：不判通过。 */
        NO_DATA,
    }

    /** 单个 PoC stage 的统计摘要。 */
    data class StageSummary(
        val stageId: String,
        val stageName: String,
        val frameCount: Long,
        /** 实际采集时长（秒，含启动开销）。 */
        val durationSec: Double,
        val p50Ms: Double,
        val p95Ms: Double,
        val droppedFrames: Long,
        /** 掉帧率 0..1。 */
        val dropRate: Double,
        val verdict: Verdict,
    )

    /**
     * nearest-rank 百分位：rank=ceil(p/100·N)，取累积计数首次 ≥ rank 的桶 key。
     *
     * @param buckets 帧耗时分桶（整数 ms → 帧数）。
     * @param p 百分位，0..100。
     * @return 该百分位对应的桶 key（ms）；空输入返回 NaN。
     */
    fun percentileMs(buckets: Map<Int, Long>, p: Double): Double {
        require(p in 0.0..100.0) { "p must be in 0..100, was $p" }
        val total = buckets.values.sum()
        if (total <= 0L) return Double.NaN
        val rank = ceil(p / 100.0 * total).toLong().coerceAtLeast(1L)
        var acc = 0L
        for (key in buckets.keys.sorted()) {
            acc += buckets.getValue(key)
            if (acc >= rank) return key.toDouble()
        }
        // 理论不可达（rank ≤ total 必在某桶命中）；防御性返回最大桶。
        return buckets.keys.max().toDouble()
    }

    /**
     * 掉帧数：帧耗时 > [thresholdMs] 的帧数。
     * 整数 ms 分桶下即 key > threshold 的桶计数之和
     * （如 threshold=18.18 → key ≥ 19 的桶）。
     */
    fun droppedCount(
        buckets: Map<Int, Long>,
        thresholdMs: Double = FRAME_BUDGET_55FPS_MS,
    ): Long = buckets.entries.sumOf { (ms, count) ->
        if (ms > thresholdMs) count else 0L
    }

    /** 由分桶生成单 stage 摘要（含判定）。 */
    fun summarize(
        stageId: String,
        stageName: String,
        buckets: Map<Int, Long>,
        durationSec: Double,
    ): StageSummary {
        val total = buckets.values.sum()
        if (total <= 0L) {
            return StageSummary(
                stageId = stageId,
                stageName = stageName,
                frameCount = 0L,
                durationSec = durationSec,
                p50Ms = Double.NaN,
                p95Ms = Double.NaN,
                droppedFrames = 0L,
                dropRate = Double.NaN,
                verdict = Verdict.NO_DATA,
            )
        }
        val p50 = percentileMs(buckets, 50.0)
        val p95 = percentileMs(buckets, 95.0)
        val dropped = droppedCount(buckets)
        return StageSummary(
            stageId = stageId,
            stageName = stageName,
            frameCount = total,
            durationSec = durationSec,
            p50Ms = p50,
            p95Ms = p95,
            droppedFrames = dropped,
            dropRate = dropped.toDouble() / total,
            verdict = if (p95 <= FRAME_BUDGET_55FPS_MS) Verdict.PASS else Verdict.FAIL,
        )
    }
}
