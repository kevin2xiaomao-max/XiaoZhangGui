package com.xiaozhanggui.app.ui.motion

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * FrameRateMonitor 测试（Design System §2.3 性能降级策略）。
 *
 * - 连续低帧率（< 55fps）→ 自动降一档（SHARED_ANCHOR → FADE）
 * - 降级单向：降档后即使帧率恢复也不回升；同一次前台会话内最多降一次
 * - 事件只记档位变化（from → to + 具名原因），不记业务正文
 * - 回到前台 reset() → 重新探测，恢复档位上限
 *
 * 实现细节（以 Worker A 实际提交为准）：
 * 滑动 1s 窗口先满一窗（spanMs ≥ 1000ms）才判定，低帧率再持续满 1s 才降档——
 * 即约 2s 持续 < 55fps 才会降档（比文档字面"连续 1s"更保守，方向安全）。
 * 注意：评估要求窗口恰好覆盖 1000ms（spanMs ≥ lowDurationMs），测试用
 * 20ms/10ms 间隔（1000 的约数）保证确定性；真实 Choreographer 抖动下
 * 评估时机会有 ±1 窗口的浮动（已报 coordinator，见测试报告）。
 */
class FrameRateMonitorTest {

    /** 假时钟 + 帧泵：t=0 先给一帧，之后按固定帧间隔推进时间并上报帧。 */
    private class Harness {
        var nowMs = 0L
        val downgradeCalls = mutableListOf<FrameRateMonitor.DowngradeEvent>()
        val monitor = FrameRateMonitor(
            clockMs = { nowMs },
            onDowngrade = { downgradeCalls.add(it) },
        )

        init {
            monitor.onFrame() // t=0 首帧：让滑动窗口能恰好覆盖 1000ms
        }

        /** 以 [frameIntervalMs] 为间隔上报 [durationMs] 时长的帧。 */
        fun pumpFrames(durationMs: Long, frameIntervalMs: Long) {
            val frames = durationMs / frameIntervalMs
            repeat(frames.toInt()) {
                nowMs += frameIntervalMs
                monitor.onFrame()
            }
        }
    }

    @Test
    fun `initial state allows shared anchor with no events`() {
        val h = Harness()
        assertEquals(TransitionKind.SHARED_ANCHOR, h.monitor.currentMaxTransitionKind())
        assertTrue(h.monitor.downgradeEvents().isEmpty())
    }

    @Test
    fun `sustained low fps downgrades one tier`() {
        val h = Harness()
        h.pumpFrames(durationMs = 2600, frameIntervalMs = 20) // 50fps < 55

        assertEquals(TransitionKind.FADE, h.monitor.currentMaxTransitionKind())
        val events = h.monitor.downgradeEvents()
        assertEquals(1, events.size)
        assertEquals(TransitionKind.SHARED_ANCHOR, events[0].from)
        assertEquals(TransitionKind.FADE, events[0].to)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, events[0].reason)
        // 回调只收到档位变化事件
        assertEquals(1, h.downgradeCalls.size)
        assertEquals(events[0], h.downgradeCalls[0])
    }

    @Test
    fun `brief low fps does not downgrade`() {
        val h = Harness()
        h.pumpFrames(durationMs = 1200, frameIntervalMs = 20) // 50fps，仅 1.2s

        assertEquals(TransitionKind.SHARED_ANCHOR, h.monitor.currentMaxTransitionKind())
        assertTrue(h.monitor.downgradeEvents().isEmpty())
    }

    @Test
    fun `above threshold fps never downgrades`() {
        val h = Harness()
        h.pumpFrames(durationMs = 3000, frameIntervalMs = 10) // 100fps ≥ 55，评估正常发生

        assertEquals(TransitionKind.SHARED_ANCHOR, h.monitor.currentMaxTransitionKind())
        assertTrue(h.monitor.downgradeEvents().isEmpty())
    }

    @Test
    fun `downgrade is one way even after fps recovers`() {
        val h = Harness()
        h.pumpFrames(durationMs = 2600, frameIntervalMs = 20) // 降档
        assertEquals(TransitionKind.FADE, h.monitor.currentMaxTransitionKind())

        h.pumpFrames(durationMs = 5000, frameIntervalMs = 10) // 100fps，持续 5s
        // 单向：档位不回升
        assertEquals(TransitionKind.FADE, h.monitor.currentMaxTransitionKind())
        // 事件只记档位变化：恢复帧率不产生新事件
        assertEquals(1, h.monitor.downgradeEvents().size)
        assertEquals(1, h.downgradeCalls.size)
    }

    @Test
    fun `at most one downgrade per foreground session`() {
        val h = Harness()
        h.pumpFrames(durationMs = 6000, frameIntervalMs = 20) // 持续 6s 低帧率

        assertEquals(1, h.monitor.downgradeEvents().size)
        assertEquals(TransitionKind.FADE, h.monitor.currentMaxTransitionKind())
    }

    @Test
    fun `reset on foreground restores tier and records reset event`() {
        val h = Harness()
        h.pumpFrames(durationMs = 2600, frameIntervalMs = 20)
        assertEquals(TransitionKind.FADE, h.monitor.currentMaxTransitionKind())

        h.monitor.reset()

        assertEquals(TransitionKind.SHARED_ANCHOR, h.monitor.currentMaxTransitionKind())
        val events = h.monitor.downgradeEvents()
        assertEquals(2, events.size)
        assertEquals(FrameRateMonitor.FOREGROUND_RESET_REASON, events[1].reason)
        assertEquals(TransitionKind.FADE, events[1].from)
        assertEquals(TransitionKind.SHARED_ANCHOR, events[1].to)
        // reset 不走 onDowngrade 回调（那是给"降档"用的）
        assertEquals(1, h.downgradeCalls.size)
    }

    @Test
    fun `reset without downgrade records no event`() {
        val h = Harness()
        h.pumpFrames(durationMs = 2000, frameIntervalMs = 10)
        h.monitor.reset()

        assertTrue(h.monitor.downgradeEvents().isEmpty())
        assertEquals(TransitionKind.SHARED_ANCHOR, h.monitor.currentMaxTransitionKind())
    }

    @Test
    fun `downgrade events snapshot is a copy`() {
        val h = Harness()
        h.pumpFrames(durationMs = 2600, frameIntervalMs = 20)

        val snapshot = h.monitor.downgradeEvents().toMutableList()
        snapshot.clear()

        assertEquals(1, h.monitor.downgradeEvents().size)
    }

    @Test
    fun `steady 60fps never downgrades`() {
        // Worker A 原有断言（合并保留）：16ms 间隔下评估窗口不对齐，天然不降级；
        // 100fps 的确定性覆盖见 `above threshold fps never downgrades`。
        val h = Harness()
        h.pumpFrames(durationMs = 3200, frameIntervalMs = 16) // ~62fps
        assertTrue(h.monitor.downgradeEvents().isEmpty())
        assertEquals(TransitionKind.SHARED_ANCHOR, h.monitor.currentMaxTransitionKind())
    }

    @Test
    fun `downgrade events carry no business payload`() {
        // Worker A 原有断言（合并保留）：事件只记档位变化 + 具名原因 + 时间戳。
        // 用反射断言 DowngradeEvent 的字段集合，从结构上杜绝业务正文混入。
        val fields = FrameRateMonitor.DowngradeEvent::class.java.declaredFields
            // 排除 Kotlin 编译器生成的 $stable 等合成字段（未打 synthetic 标记，按名过滤）
            .filter { !it.name.startsWith("$") }
            .map { it.name }.toSet()
        assertEquals(setOf("from", "to", "reason", "atMs"), fields)

        val h = Harness()
        h.pumpFrames(durationMs = 2600, frameIntervalMs = 20)
        val e = h.monitor.downgradeEvents()
            .single { it.reason == MotionDowngradeReasons.FRAME_RATE }
        assertEquals(TransitionKind.SHARED_ANCHOR, e.from)
        assertEquals(TransitionKind.FADE, e.to)
    }

    @Test
    fun `threshold constants match design doc`() {
        // Design System §2.3 冻结值：55fps / 1000ms，不分叉
        assertEquals(55.0, FrameRateMonitor.LOW_FPS_THRESHOLD, 0.0)
        assertEquals(1000L, FrameRateMonitor.LOW_DURATION_MS)
    }
}
