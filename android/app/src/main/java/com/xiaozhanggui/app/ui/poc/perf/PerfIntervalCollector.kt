package com.xiaozhanggui.app.ui.poc.perf

import android.os.Looper
import android.view.Choreographer

/**
 * Choreographer 真实帧间隔采集器（V3.8 口径审计 · Worker B；debug only）。
 *
 * 为什么需要它（审计结论）：FrameMetrics 的 TOTAL_DURATION 是**渲染耗时**
 * （绘制一帧花了多久），不是**帧间隔**（两帧相隔多久）。绘制耗时小
 * 但两帧之间若等待 vsync / 主线程休眠，间隔依然大——p95 渲染耗时 ≤18.18ms
 * **不能**直接证明实际 FPS ≥ 55。≥55fps 判定只能基于本采集器的帧间隔序列。
 *
 * 实现：`Choreographer.postFrameCallback` 循环采集每帧的 `frameTimeNanos`
 * （纳秒时间戳，`System.nanoTime()` 时基；该值是帧对应的 vsync 时刻，
 * 相邻差分即真实帧间隔）。
 *
 * 依赖评估：`android.view.Choreographer` 为框架公开 API，零新增依赖，
 * release DEX 零增量；全程无反射（PoC-4 零反射红线同样适用）。
 *
 * 生命周期语义：复用 Worker A 的 `CollectOutcome`/`CollectReason` 思想；
 * A 的类型尚未合入时此处先自备一套兼容命名（[IntervalOutcome]/[IntervalReason]），
 * 合入后由 coordinator 统一替换，行为语义保持一致。
 *
 * 用法（单 stage 一次，主线程调用）：
 * ```
 * val c = PerfIntervalCollector()
 * if (c.start()) {
 *     // ……动画期间（回调随 vsync 持续触发）……
 *     val frameTimesNs: List<Long> = c.stop()
 * }
 * ```
 * 回调期间 App 在前台即可产出帧间隔；退后台/无 vsync 时序列为空，
 * 调用方按 [IntervalOutcome.NO_DATA] 处理。
 */
class PerfIntervalCollector {

    /**
     * 采集结果语义（与 Worker A 的 CollectOutcome 对齐）：
     * - [COLLECTED]：拿到 ≥1 个 frameTimeNanos 时间戳；
     * - [NO_DATA]：0 个时间戳，不判通过（调用方见 [IntervalReason]）。
     */
    enum class IntervalOutcome { COLLECTED, NO_DATA }

    /**
     * 生命周期原因（与 Worker A 的 CollectReason 对齐）。
     */
    enum class IntervalReason {
        /** start→stop 正常采集，序列非空。 */
        STOPPED_AFTER_START,

        /** stop 时从未调用 start。 */
        NEVER_STARTED,

        /** start 不在主线程（Choreographer 要求主 Looper），采集未开始。 */
        NOT_ON_MAIN_THREAD,

        /** 已 start 但回调从未触发（退后台/窗口无 vsync 等）。 */
        CALLBACK_TIMEOUT_NO_VSYNC,

        /** stop 期间移除回调抛异常（系统级），序列按已采集部分返回。 */
        STOP_ABORTED,
    }

    private val lock = Any()
    private val frameTimesNs = mutableListOf<Long>()
    private var started = false
    private var outcome = IntervalOutcome.NO_DATA
    private var reason = IntervalReason.NEVER_STARTED

    /** 采集到的回调：记录时间戳并为下一帧重新注册。 */
    private val frameCallback = Choreographer.FrameCallback { frameTimeNanos ->
        synchronized(lock) {
            if (started) {
                frameTimesNs.add(frameTimeNanos)
            }
        }
        // 继续下一帧：只要还在采集期就循环；stop() 会移除本回调，
        // 此处重注册的是一次性回调，不会泄漏。
        synchronized(lock) {
            if (started) {
                postCallback()
            }
        }
    }

    /**
     * 开始采集。**必须主线程调用**（Choreographer 绑定主 Looper）。
     * @return true=已注册帧回调；false=不在主线程，采集未开始。
     */
    fun start(): Boolean {
        synchronized(lock) {
            frameTimesNs.clear()
            started = false
            outcome = IntervalOutcome.NO_DATA
            reason = IntervalReason.NEVER_STARTED
        }
        if (Looper.myLooper() != Looper.getMainLooper()) {
            synchronized(lock) { reason = IntervalReason.NOT_ON_MAIN_THREAD }
            return false
        }
        synchronized(lock) {
            started = true
            postCallback()
        }
        return true
    }

    /**
     * 停止采集并返回 frameTimeNanos 序列（ns，升序）。
     * 空序列表示无有效帧间隔（见 [reason]），调用方记 NO_DATA。
     * 可重复调用；stop 前未 start 返回空列表且 reason=NEVER_STARTED。
     */
    fun stop(): List<Long> {
        val snapshot: List<Long>
        synchronized(lock) {
            if (!started) {
                // 从未 start（或已 stop 过）：reason 保持 NEVER_STARTED
                outcome = IntervalOutcome.NO_DATA
                return emptyList()
            }
            started = false
            snapshot = frameTimesNs.toList()
            frameTimesNs.clear()
        }
        try {
            Choreographer.getInstance().removeFrameCallback(frameCallback)
        } catch (e: Exception) {
            // 系统级移除失败：序列已快照，照常返回
            synchronized(lock) { reason = IntervalReason.STOP_ABORTED }
        }
        synchronized(lock) {
            if (reason != IntervalReason.STOP_ABORTED) {
                if (snapshot.isEmpty()) {
                    outcome = IntervalOutcome.NO_DATA
                    reason = IntervalReason.CALLBACK_TIMEOUT_NO_VSYNC
                } else {
                    outcome = IntervalOutcome.COLLECTED
                    reason = IntervalReason.STOPPED_AFTER_START
                }
            } else {
                outcome = if (snapshot.isEmpty()) {
                    IntervalOutcome.NO_DATA
                } else {
                    IntervalOutcome.COLLECTED
                }
            }
        }
        return snapshot
    }

    /** 最近一次 stop()/start() 的生命周期结果（只读）。 */
    val lastOutcome: IntervalOutcome
        get() = synchronized(lock) { outcome }

    /** 最近一次 stop()/start() 的生命周期原因（只读）。 */
    val lastReason: IntervalReason
        get() = synchronized(lock) { reason }

    /** 主线程执行：Choreographer 实例绑定调用线程 Looper。 */
    private fun postCallback() {
        Choreographer.getInstance().postFrameCallback(frameCallback)
    }
}
