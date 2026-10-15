package com.xiaozhanggui.app.ui.poc.prep

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.PerfTier
import com.xiaozhanggui.app.ui.motion.TransitionKind
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 经营数字滚动 Spec 草案测试（Phase 3 接入准备；JVM）。
 *
 * 覆盖：Spec 声明字段、插值端点精确/单调/方向一致、涨跌语义、
 * 时长验收区间数学、Reduce Motion 直接终值语义。
 * 数字滚动录屏与涨跌取色验证 NOT RUN（见 `docs/ANDROID_V38_PHASE3_PREP.md`）。
 */
class PerformanceNumberPrepTest {

    @After
    fun restoreMasterSwitch() {
        MotionPolicy.masterEnabled = true
    }

    // ── Spec 声明字段 ──

    @Test
    fun `spec declares numeric roll with standard tier and no overshoot`() {
        val s = PerformanceNumberPrep.NUMBER_ROLL
        assertEquals("v38.prep.performance.number-roll", s.id)
        assertEquals(TransitionKind.FADE, s.transitionKind)
        assertEquals(DurationTier.STANDARD, s.durationTier)
        assertEquals(280, s.durationTier.ms)
        // 数字滚动无过冲：过冲会读出错误金额
        assertEquals(Overshoot.NONE, s.overshoot)
        assertEquals(TransitionKind.FADE, s.fallbackKind)
        assertTrue(s.interruptible)
        assertTrue(s.enabled)
    }

    // ── 插值：端点精确 + 单调 + 方向一致 ──

    @Test
    fun `roll endpoints are exact`() {
        assertEquals(0.0, PerformanceNumberPrep.rolledValue(0f, 0.0, 1234.56), 0.0)
        assertEquals(1234.56, PerformanceNumberPrep.rolledValue(1f, 0.0, 1234.56), 1e-9)
        assertEquals(500.0, PerformanceNumberPrep.rolledValue(1f, 800.0, 500.0), 1e-9)
    }

    @Test
    fun `roll up is monotone increasing`() {
        var prev = -1.0
        for (i in 0..100) {
            val v = PerformanceNumberPrep.rolledValue(i / 100f, 0.0, 9999.99)
            assertTrue("not monotone at p=${i / 100f}", v >= prev)
            prev = v
        }
    }

    @Test
    fun `roll down is monotone decreasing`() {
        var prev = Double.MAX_VALUE
        for (i in 0..100) {
            val v = PerformanceNumberPrep.rolledValue(i / 100f, 9999.99, 0.0)
            assertTrue("not monotone at p=${i / 100f}", v <= prev)
            prev = v
        }
    }

    @Test
    fun `roll is clamped outside 0-1`() {
        assertEquals(0.0, PerformanceNumberPrep.rolledValue(-1f, 0.0, 100.0), 0.0)
        assertEquals(100.0, PerformanceNumberPrep.rolledValue(2f, 0.0, 100.0), 1e-9)
    }

    // ── 涨跌语义 ──

    @Test
    fun `trend classification up down flat`() {
        assertEquals(
            PerformanceNumberPrep.Trend.UP,
            PerformanceNumberPrep.trendOf(100.0, 120.0),
        )
        assertEquals(
            PerformanceNumberPrep.Trend.DOWN,
            PerformanceNumberPrep.trendOf(120.0, 100.0),
        )
        assertEquals(
            PerformanceNumberPrep.Trend.FLAT,
            PerformanceNumberPrep.trendOf(100.0, 100.0),
        )
    }

    @Test
    fun `trend respects epsilon threshold`() {
        assertEquals(
            PerformanceNumberPrep.Trend.FLAT,
            PerformanceNumberPrep.trendOf(100.0, 100.004, epsilon = 0.01),
        )
        assertEquals(
            PerformanceNumberPrep.Trend.UP,
            PerformanceNumberPrep.trendOf(100.0, 100.02, epsilon = 0.01),
        )
    }

    // ── 时长验收区间 ──

    @Test
    fun `standard duration accept range is 280ms plus-minus 20pct`() {
        val range = PerformanceNumberPrep.standardDurationAcceptRangeMs()
        assertEquals(224, range.start)
        assertEquals(336, range.endInclusive)
    }

    // ── 降级分支 ──

    @Test
    fun `full ctx resolves without downgrade`() {
        val r = PerformanceNumberPrep.resolveNumber(ctx = MotionContext())
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.STANDARD, r.durationTier)
        assertEquals(null, r.downgradeReason)
    }

    @Test
    fun `reduce motion shows end value per existing numeric semantics`() {
        // 既有语义锚点：V371Motion.resolve(NUMERIC, reduceMotion=true) == NONE
        // （见 MotionResolveTest 回归测试）；调用方读到 NONE 立即应用终值。
        assertTrue(PerformanceNumberPrep.reduceMotionShowsEndValue())
        val r = PerformanceNumberPrep.resolveNumber(ctx = MotionContext(reduceMotion = true))
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
    }

    @Test
    fun `perf tier essential keeps fade roll without overshoot`() {
        val r = PerformanceNumberPrep.resolveNumber(
            ctx = MotionContext(perfTier = PerfTier.ESSENTIAL),
        )
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    @Test
    fun `independent switch off returns V371 instant behavior`() {
        val off = PerformanceNumberPrep.NUMBER_ROLL.copy(enabled = false)
        val r = PerformanceNumberPrep.resolveNumber(spec = off, ctx = MotionContext())
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        assertEquals(DurationTier.INSTANT, r.durationTier)
    }
}
