package com.xiaozhanggui.app.ui.poc

import com.xiaozhanggui.app.ui.motion.FrameRateMonitor
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons
import com.xiaozhanggui.app.ui.motion.TransitionKind
import com.xiaozhanggui.app.ui.poc.droplet.AnchorRect
import com.xiaozhanggui.app.ui.poc.droplet.resolveDropletMenu
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC 帧率采样接线测试（Design System §2.3 性能降级策略）。
 *
 * [FrameRateMonitor] 是 Phase 1 的纯 Kotlin 实现（时钟可注入）；
 * 这里验证 PoC 的接线语义：
 * - 健康帧率（60fps）下展开不触发降档（SHARED_ANCHOR 保持）；
 * - 持续低帧率（30fps）触发一次单向降档，具名 `frame-rate-below-55fps`，
 *   并经 [resolveDropletMenu] 把液滴降级为 FADE。
 *
 * 注意：这是 JVM 假时钟仿真；真机实际 fps 以 [FrameRateSampling]
 * 在设备上的采样为准（CI 环境 NOT RUN，见 PoC 报告）。
 */
class PocFrameRateSamplingTest {

    /** 假时钟驱动的 monitor：每帧推进 [stepMs]。 */
    private fun monitorWithFakeClock(): Pair<FrameRateMonitor, LongArray> {
        val now = longArrayOf(0L)
        val monitor = FrameRateMonitor(clockMs = { now[0] })
        return monitor to now
    }

    private fun feedFrames(
        monitor: FrameRateMonitor,
        now: LongArray,
        frames: Int,
        stepMs: Long,
    ) {
        repeat(frames) {
            now[0] += stepMs
            monitor.onFrame()
        }
    }

    @Test
    fun `healthy 100fps never downgrades the droplet`() {
        val (monitor, now) = monitorWithFakeClock()
        // 2.5s @ 100fps（10ms 步长：采样窗口恰好填满 1000ms 时触发判定，
        // fps=100 ≥ 55 → 健康）
        feedFrames(monitor, now, 250, 10L)
        assertTrue(monitor.downgradeEvents().isEmpty())
        assertEquals(TransitionKind.SHARED_ANCHOR, monitor.currentMaxTransitionKind())

        // 决议链：档位上限仍允许液滴
        val r = resolveDropletMenu(
            AnchorRect(0f, 0f, 100f, 50f, 12f),
            MotionContext(runtimeMaxTransitionKind = monitor.currentMaxTransitionKind()),
        )
        assertTrue(r.runDropletPhases)
    }

    @Test
    fun `sustained 40fps downgrades once with named reason`() {
        val (monitor, now) = monitorWithFakeClock()
        // 2.5s @ 40fps（25ms 步长：1000ms 判定窗口填满时 fps=40 < 55；
        // 再持续 1s → 触发一次单向降档）
        feedFrames(monitor, now, 100, 25L)
        val events = monitor.downgradeEvents()
        assertEquals(1, events.size)
        assertEquals(TransitionKind.SHARED_ANCHOR, events[0].from)
        assertEquals(TransitionKind.FADE, events[0].to)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, events[0].reason)
        assertEquals(TransitionKind.FADE, monitor.currentMaxTransitionKind())
    }

    @Test
    fun `frame-rate downgrade feeds the droplet resolver chain`() {
        val (monitor, now) = monitorWithFakeClock()
        feedFrames(monitor, now, 100, 25L)
        assertEquals(TransitionKind.FADE, monitor.currentMaxTransitionKind())

        val r = resolveDropletMenu(
            AnchorRect(0f, 0f, 100f, 50f, 12f),
            MotionContext(runtimeMaxTransitionKind = monitor.currentMaxTransitionKind()),
        )
        assertFalse(r.runDropletPhases)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, r.downgradeReason)
    }

    @Test
    fun `downgrade is one-way within a session`() {
        val (monitor, now) = monitorWithFakeClock()
        feedFrames(monitor, now, 100, 25L) // 降档
        feedFrames(monitor, now, 250, 10L) // 帧率恢复
        // 单向：已降的档位不升回；事件仍只有 1 条
        assertEquals(1, monitor.downgradeEvents().size)
        assertEquals(TransitionKind.FADE, monitor.currentMaxTransitionKind())
    }
}
