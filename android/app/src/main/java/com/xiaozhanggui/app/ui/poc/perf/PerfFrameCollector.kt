package com.xiaozhanggui.app.ui.poc.perf

import android.app.Activity
import android.util.SparseIntArray
import androidx.core.app.FrameMetricsAggregator

/**
 * FrameMetrics 公开 API 帧采集器（V3.8 真机验收补强 · Worker 3；debug only）。
 *
 * 依赖评估（任务要求注明理由）：
 * - 任务建议的 `androidx.metrics:metrics-performance` **不包含**
 *   `FrameMetricsAggregator`——该类实际位于 `androidx.core.app`
 *   （artifact `androidx.core:core`）；metrics-performance 提供的是
 *   JankStats / PerformanceMetricsState（另一套 API，与任务点名的类名不符）。
 * - `androidx.core:core:1.15.0` 已是 app 的 `implementation` 依赖，
 *   本类符号在所有变体编译期均已存在：**零新增依赖、release DEX 零增量**，
 *   以最强形式满足"release 产物不受影响"，故不引入 metrics-performance。
 * - 全程公开 API（`add` / `getMetrics` / `stop`），无反射
 *   （PoC-4 零反射红线同样适用）；minSdk 26 ≥ API 24，
 *   `Window.OnFrameMetricsAvailableListener` 可用，低版本为系统级 no-op。
 *
 * 下标语义（AOSP，P0 根因记录）：
 * - `FrameMetricsAggregator(FrameMetricsAggregator.TOTAL_DURATION)` 的构造器
 *   参数是 bit flag（TOTAL_DURATION = 1），表示"启用 TOTAL_DURATION 指标"；
 * - `getMetrics()` 返回的数组按 `*_INDEX` 下标寻址，TOTAL_INDEX = 0。
 *   旧代码误用 `getOrNull(TOTAL_DURATION)`（下标 1）→ 恒 null → 真机 0 帧；
 *   已修正为 [FrameMetricsAggregator.TOTAL_INDEX]（见 [extractTotalBuckets]）。
 *
 * 用法（单 stage 一次）：
 * ```
 * val c = PerfFrameCollector()
 * if (c.start(activity)) {
 *     // ……动画期间……
 *     when (val outcome = c.stop()) {
 *         is CollectOutcome.Ok -> use(outcome.buckets) // ms → 帧数
 *         is CollectOutcome.Failed -> show(outcome.reason) // 按原因分别展示
 *     }
 * }
 * ```
 * 分桶 key 为整数 ms（舍入方式未验证，边界视为近似）；原始分桶随报告导出可审计。
 */
class PerfFrameCollector internal constructor(
    private val backend: CollectorBackend = RealCollectorBackend(),
) {

    /**
     * 可注入的采集后端：生产走真实 FrameMetricsAggregator，测试走伪造实现。
     * internal：公开 API 仍为无参构造 + start/stop。
     */
    internal interface CollectorBackend {
        /** 把聚合器挂到窗口；失败抛异常。 */
        @Throws(Exception::class)
        fun attach(activity: Activity): MetricsSource
    }

    /** 单次采集的数据源：快照 + 释放。 */
    internal interface MetricsSource {
        /** 读取 `getMetrics()` 形态数组；失败抛异常。 */
        @Throws(Exception::class)
        fun snapshot(): Array<SparseIntArray?>?

        /** 释放（`aggregator.stop()`）；自身不抛异常。 */
        fun release()
    }

    private class RealCollectorBackend : CollectorBackend {
        override fun attach(activity: Activity): MetricsSource {
            val agg = FrameMetricsAggregator(FrameMetricsAggregator.TOTAL_DURATION)
            return try {
                agg.add(activity)
                RealMetricsSource(agg)
            } catch (e: Exception) {
                try {
                    agg.stop()
                } catch (_: Exception) {
                    // 忽略：已处于失败路径
                }
                throw e
            }
        }
    }

    private class RealMetricsSource(private val agg: FrameMetricsAggregator) : MetricsSource {
        override fun snapshot(): Array<SparseIntArray?>? = agg.getMetrics()
        override fun release() {
            try {
                agg.stop()
            } catch (_: Exception) {
                // 忽略：已处于收尾路径
            }
        }
    }

    private var source: MetricsSource? = null

    /**
     * start 抛异常的粘滞标记：随后的 [stop] 报告
     * [CollectReason.START_EXCEPTION]（而非 [CollectReason.METRICS_NULL]）。
     */
    private var startFailed = false

    /**
     * 开始采集（主线程调用）。
     *
     * 注：core 1.15.0 的 `add(Activity)` 返回 void（非 boolean），
     * 失败仅以异常体现。
     * @return false 仅表示 attach 抛异常（窗口不可用等系统级失败）；
     *         此时随后的 [stop] 返回 [CollectOutcome.Failed]
     *         （[CollectReason.START_EXCEPTION]），不再静默记空数据。
     */
    fun start(activity: Activity): Boolean {
        clear()
        return try {
            source = backend.attach(activity)
            true
        } catch (e: Exception) {
            startFailed = true
            false
        }
    }

    /**
     * 停止采集并返回显式结果（不再静默吞故障）。
     *
     * - [CollectOutcome.Ok]：TOTAL_DURATION 分桶（整数 ms → 帧数）；
     * - [CollectOutcome.Failed]：[CollectReason] 说明具体原因，
     *   调用方（[PerfTestScreen]）按原因分别展示。
     */
    fun stop(): CollectOutcome {
        val src = source
        val failed = startFailed
        clear()
        if (src == null) {
            // 未 start，或 start 抛异常。
            return CollectOutcome.Failed(
                if (failed) CollectReason.START_EXCEPTION else CollectReason.METRICS_NULL,
            )
        }
        val metrics = try {
            src.snapshot()
        } catch (e: Exception) {
            src.release()
            return CollectOutcome.Failed(CollectReason.STOP_EXCEPTION)
        }
        src.release()
        if (metrics == null) return CollectOutcome.Failed(CollectReason.METRICS_NULL)
        if (metrics.getOrNull(FrameMetricsAggregator.TOTAL_INDEX) == null) {
            return CollectOutcome.Failed(CollectReason.INDEX_MISSING)
        }
        val buckets = extractTotalBuckets(metrics)
        if (buckets.isEmpty()) return CollectOutcome.Failed(CollectReason.ZERO_FRAMES)
        return CollectOutcome.Ok(buckets)
    }

    private fun clear() {
        source = null
        startFailed = false
    }

    companion object {
        /**
         * 从 `getMetrics()` 形态数组抽取 TOTAL_DURATION 分桶（可测纯函数）。
         *
         * 数组按 `*_INDEX` 下标寻址：TOTAL_DURATION 指标位于
         * [FrameMetricsAggregator.TOTAL_INDEX]（= 0）；注意构造器参数
         * [FrameMetricsAggregator.TOTAL_DURATION]（= 1）是 bit flag，
         * 不可作下标（P0 根因：旧代码误用下标 1 → 恒 null → 真机 0 帧）。
         *
         * @return 整数 ms → 帧数；metrics 为 null / 数组过短 / 下标无数据返回空 map。
         */
        fun extractTotalBuckets(metrics: Array<SparseIntArray?>?): Map<Int, Long> {
            // P0 根因回归锚点：此处必须为 TOTAL_INDEX（= 0）；
            // TOTAL_DURATION（= 1）是构造器 bit flag，不可作下标。
            val totals = metrics?.getOrNull(FrameMetricsAggregator.TOTAL_INDEX) ?: return emptyMap()
            val out = LinkedHashMap<Int, Long>(totals.size())
            for (i in 0 until totals.size()) {
                out[totals.keyAt(i)] = totals.valueAt(i).toLong()
            }
            return out
        }
    }
}

/**
 * [PerfFrameCollector.stop] 的显式结果：不再静默吞故障，
 * 调用方按 [CollectReason] 分别展示/处理。
 */
sealed interface CollectOutcome {
    /** 采集成功：[buckets] 为 TOTAL_DURATION 分桶（整数 ms → 帧数）。 */
    data class Ok(val buckets: Map<Int, Long>) : CollectOutcome

    /** 采集失败：[reason] 说明具体原因。 */
    data class Failed(val reason: CollectReason) : CollectOutcome
}

/** 采集失败原因（[CollectOutcome.Failed]）。 */
enum class CollectReason {
    /** start 抛异常（窗口不可用等系统级失败）。 */
    START_EXCEPTION,

    /** `getMetrics()` 返回 null（或 stop 前无有效采集源）。 */
    METRICS_NULL,

    /** 指标数组在 TOTAL_INDEX 下标无数据。 */
    INDEX_MISSING,

    /** TOTAL 分桶为空（动画期间 0 帧产出）。 */
    ZERO_FRAMES,

    /** stop 期间读取快照抛异常。 */
    STOP_EXCEPTION,
}
