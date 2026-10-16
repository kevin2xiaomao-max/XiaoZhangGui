package com.xiaozhanggui.app.ui.poc.perf

import android.app.Activity
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
 * 用法（单 stage 一次）：
 * ```
 * val c = PerfFrameCollector()
 * if (c.start(activity)) {
 *     // ……动画期间……
 *     val buckets: Map<Int, Long> = c.stop() // ms → 帧数
 * }
 * ```
 * 分桶 key 为整数 ms（向下取整，见 [PerfStats] 精度说明）。
 */
class PerfFrameCollector {

    private var aggregator: FrameMetricsAggregator? = null

    /**
     * 开始采集（主线程调用）。
     * @return false 表示窗口不可用等系统级失败，调用方应记 NO_DATA。
     */
    fun start(activity: Activity): Boolean {
        clear()
        val agg = FrameMetricsAggregator(FrameMetricsAggregator.TOTAL_DURATION)
        val ok = try {
            agg.add(activity)
        } catch (e: Exception) {
            false
        }
        if (ok) {
            aggregator = agg
        } else {
            try {
                agg.stop()
            } catch (_: Exception) {
                // 忽略：已处于失败路径
            }
        }
        return ok
    }

    /**
     * 停止采集并返回 TOTAL_DURATION 分桶（整数 ms → 帧数）。
     * 未 start / 采集失败返回空 map（调用方记 NO_DATA）。
     */
    fun stop(): Map<Int, Long> {
        val agg = aggregator
        clear()
        if (agg == null) return emptyMap()
        val result = mutableMapOf<Int, Long>()
        try {
            // getMetrics() 返回按 metric 常量索引的数组；
            // TOTAL_DURATION=0，桶 key=整数 ms → 计数。
            val totals = agg.getMetrics()?.getOrNull(FrameMetricsAggregator.TOTAL_DURATION)
            if (totals != null) {
                for (i in 0 until totals.size()) {
                    result[totals.keyAt(i)] = totals.valueAt(i).toLong()
                }
            }
        } catch (e: Exception) {
            // 采集异常 → 空数据，调用方记 NO_DATA
            result.clear()
        } finally {
            try {
                agg.stop()
            } catch (_: Exception) {
                // 忽略：已处于收尾路径
            }
        }
        return result
    }

    private fun clear() {
        aggregator = null
    }
}
