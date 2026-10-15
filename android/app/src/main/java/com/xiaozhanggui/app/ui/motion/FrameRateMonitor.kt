package com.xiaozhanggui.app.ui.motion

/**
 * 运行时帧率采样 + 自动降档（Design System §2.3 性能降级策略）。
 *
 * 纯 Kotlin 实现（时钟可注入），JVM 可单测；Android 侧的 Choreographer 接线见
 * `FrameRateSampling.kt`，只负责把 `onFrame()` 喂进来。
 *
 * 策略（与文档逐字对齐）：
 * - 采样帧率：连续 1s < 55fps → 自动降一档（SHARED_ANCHOR → FADE）；
 * - 降级**单向**（只降不升），避免档位抖动；同一次前台会话内最多降一次；
 * - 回到前台时调用 [reset] 重新探测（恢复档位上限）；
 * - 降级事件只记档位变化（from → to + 具名原因 + 时间戳），**不记业务正文**。
 *
 * 线程说明：[onFrame] 预期在主线程（Choreographer 回调线程）调用；
 * [downgradeEvents] 返回快照副本，可在任意线程读。
 *
 * @param lowFpsThresholdFps 低帧率阈值（默认 55fps，文档值，不分叉）
 * @param lowDurationMs 持续低帧率判定窗口（默认 1000ms，文档值）
 * @param clockMs 时钟（毫秒）；默认系统时钟，测试时注入假时钟
 * @param onDowngrade 降档回调（记日志/上报用；只收到档位变化事件）
 */
class FrameRateMonitor(
    private val lowFpsThresholdFps: Double = LOW_FPS_THRESHOLD,
    private val lowDurationMs: Long = LOW_DURATION_MS,
    private val clockMs: () -> Long = { System.nanoTime() / 1_000_000L },
    private val onDowngrade: (DowngradeEvent) -> Unit = {},
) {
    /**
     * 降级事件：只记档位变化，不记业务正文。
     *
     * @param from 降档前允许的最高转场类型
     * @param to 降档后允许的最高转场类型
     * @param reason 具名原因（[MotionDowngradeReasons.FRAME_RATE] / `"foreground-reset"`）
     * @param atMs 事件时间戳（[clockMs] 时钟域）
     */
    data class DowngradeEvent(
        val from: TransitionKind,
        val to: TransitionKind,
        val reason: String,
        val atMs: Long,
    )

    private val frameTimes = ArrayDeque<Long>()
    private var lowSinceMs: Long? = null
    private var downgraded = false
    private val events = mutableListOf<DowngradeEvent>()

    /**
     * 当前允许的最高转场类型（单调：前台会话内只降不升）。
     *
     * 供 [MotionContext.runtimeMaxTransitionKind] 消费；
     * 降档后为 [TransitionKind.FADE]（SHARED_ANCHOR 被禁）。
     */
    fun currentMaxTransitionKind(): TransitionKind =
        if (downgraded) TransitionKind.FADE else TransitionKind.SHARED_ANCHOR

    /** 降级事件快照（只读副本；只含档位变化）。 */
    fun downgradeEvents(): List<DowngradeEvent> = events.toList()

    /**
     * 上报一帧（Choreographer 每帧回调一次）。
     *
     * 滑动 1s 窗口统计帧率：窗口内平均帧率 < 阈值且持续满 1s → 触发一次降档。
     */
    fun onFrame() {
        val now = clockMs()
        frameTimes.addLast(now)
        while (frameTimes.isNotEmpty() && frameTimes.first() < now - lowDurationMs) {
            frameTimes.removeFirst()
        }
        if (frameTimes.size < 2) return

        val spanMs = now - frameTimes.first()
        if (spanMs < lowDurationMs) return // 窗口未满，不判定

        val fps = (frameTimes.size - 1) * 1000.0 / spanMs
        if (fps < lowFpsThresholdFps) {
            val lowSince = lowSinceMs
            if (lowSince == null) {
                lowSinceMs = now
            } else if (!downgraded && now - lowSince >= lowDurationMs) {
                downgraded = true
                lowSinceMs = null
                val event = DowngradeEvent(
                    from = TransitionKind.SHARED_ANCHOR,
                    to = TransitionKind.FADE,
                    reason = MotionDowngradeReasons.FRAME_RATE,
                    atMs = now,
                )
                events.add(event)
                onDowngrade(event)
            }
        } else {
            // 帧率恢复：清零计时，但已降的档位不升回（单向）
            lowSinceMs = null
        }
    }

    /**
     * 回到前台：重新探测。
     *
     * 恢复档位上限到 SHARED_ANCHOR、清空采样窗口；记一条 `foreground-reset`
     * 事件（档位变化可查），不触发 [onDowngrade]（那是给"降档"用的）。
     */
    fun reset() {
        val now = clockMs()
        val wasDowngraded = downgraded
        frameTimes.clear()
        lowSinceMs = null
        downgraded = false
        if (wasDowngraded) {
            events.add(
                DowngradeEvent(
                    from = TransitionKind.FADE,
                    to = TransitionKind.SHARED_ANCHOR,
                    reason = FOREGROUND_RESET_REASON,
                    atMs = now,
                )
            )
        }
    }

    companion object {
        /** 低帧率阈值：55fps（Design System §2.3，不分叉） */
        const val LOW_FPS_THRESHOLD = 55.0

        /** 持续低帧率判定窗口：1000ms（Design System §2.3，不分叉） */
        const val LOW_DURATION_MS = 1000L

        /** 回到前台重新探测的事件原因（记档位恢复，不记业务正文） */
        const val FOREGROUND_RESET_REASON = "foreground-reset"
    }
}
