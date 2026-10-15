package com.xiaozhanggui.app.ui.motion

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * FrameRateMonitor：假时钟驱动，验证"连续 1s < 55fps → 降一档（单向）"。
 */
class FrameRateMonitorTest {

    private var nowMs = 0L
    private val fired = mutableListOf<FrameRateMonitor.DowngradeEvent>()
    private var callbackCount = 0

    private fun monitor() = FrameRateMonitor(
        clockMs = { nowMs },
        onDowngrade = { fired.add(it); callbackCount++ },
    )

    /** 按固定间隔推进假时钟并上报帧。 */
    private fun feedFrames(m: FrameRateMonitor, intervalMs: Long, count: Int) {
        repeat(count) {
            m.onFrame()
            nowMs += intervalMs
        }
    }

    @Test
    fun `steady 60fps never downgrades`() {
        val m = monitor()
        feedFrames(m, intervalMs = 16, count = 200) // ~3.2s @ ~62fps
        assertTrue(fired.isEmpty())
        assertEquals(TransitionKind.SHARED_ANCHOR, m.currentMaxTransitionKind())
    }

    @Test
    fun `sustained 30fps downgrades once after 1s`() {
        val m = monitor()
        feedFrames(m, intervalMs = 34, count = 70) // ~2.4s @ ~29fps
        assertEquals(1, fired.size)
        val e = fired.single()
        assertEquals(TransitionKind.SHARED_ANCHOR, e.from)
        assertEquals(TransitionKind.FADE, e.to)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, e.reason)
        assertEquals(1, callbackCount)
        assertEquals(TransitionKind.FADE, m.currentMaxTransitionKind())
    }

    @Test
    fun `downgrade is one-way within a foreground session`() {
        val m = monitor()
        feedFrames(m, intervalMs = 34, count = 70)
        assertEquals(1, fired.size)
        feedFrames(m, intervalMs = 34, count = 70) // 继续低帧率
        assertEquals(1, fired.size) // 不再触发，避免抖动
        assertEquals(1, callbackCount)
        assertEquals(TransitionKind.FADE, m.currentMaxTransitionKind())
    }

    @Test
    fun `fps recovering before 1s does not downgrade`() {
        val m = monitor()
        feedFrames(m, intervalMs = 34, count = 45) // ~1.5s 低帧率，未满持续 1s 判定
        feedFrames(m, intervalMs = 16, count = 100) // 恢复 60fps
        assertTrue(fired.isEmpty())
        assertEquals(TransitionKind.SHARED_ANCHOR, m.currentMaxTransitionKind())
    }

    @Test
    fun `reset on foreground restores tier and logs the change`() {
        val m = monitor()
        feedFrames(m, intervalMs = 34, count = 70)
        assertEquals(TransitionKind.FADE, m.currentMaxTransitionKind())

        m.reset() // 回到前台重新探测
        assertEquals(TransitionKind.SHARED_ANCHOR, m.currentMaxTransitionKind())
        assertEquals(1, fired.size) // reset 只记事件，不触发 onDowngrade 回调
        val events = m.downgradeEvents()
        assertEquals(2, events.size)
        assertEquals(FrameRateMonitor.FOREGROUND_RESET_REASON, events.last().reason)
        assertEquals(TransitionKind.FADE, events.last().from)
        assertEquals(TransitionKind.SHARED_ANCHOR, events.last().to)
    }

    @Test
    fun `reset without prior downgrade logs nothing`() {
        val m = monitor()
        feedFrames(m, intervalMs = 16, count = 100)
        m.reset()
        assertTrue(m.downgradeEvents().isEmpty())
    }

    @Test
    fun `downgrade events carry no business payload`() {
        val m = monitor()
        feedFrames(m, intervalMs = 34, count = 70)
        val e = m.downgradeEvents().single { it.reason == MotionDowngradeReasons.FRAME_RATE }
        // 只记档位变化 + 具名原因 + 时间戳
        assertEquals(TransitionKind.SHARED_ANCHOR, e.from)
        assertEquals(TransitionKind.FADE, e.to)
    }
}
