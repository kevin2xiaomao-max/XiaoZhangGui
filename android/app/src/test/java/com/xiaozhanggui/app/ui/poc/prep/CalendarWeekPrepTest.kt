package com.xiaozhanggui.app.ui.poc.prep

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.TransitionKind
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日历周切换双轨 Spec 草案测试（Phase 3 接入准备；JVM）。
 *
 * 覆盖：双轨 Spec 声明、容器单调无过冲、内容错峰顺序/边界、
 * 中途反转速度连续（速度包络）、密集列表退化。
 * 慢/快速滑动录屏与 ≥55fps 真机验证 NOT RUN（见 `docs/ANDROID_V38_PHASE3_PREP.md`）。
 */
class CalendarWeekPrepTest {

    @After
    fun restoreMasterSwitch() {
        MotionPolicy.masterEnabled = true
    }

    // ── 双轨 Spec 声明 ──

    @Test
    fun `container spec is monotone with no overshoot`() {
        val s = CalendarWeekPrep.CONTAINER_SLIDE
        assertEquals("v38.prep.calendar.week-container-slide", s.id)
        assertEquals(TransitionKind.FADE, s.transitionKind)
        assertEquals(DurationTier.FAST, s.durationTier)
        assertEquals(Overshoot.NONE, s.overshoot) // 「页面必单调」铁律
        assertTrue(s.interruptible)
        assertEquals(TransitionKind.FADE, s.fallbackKind)
        assertTrue(s.enabled)
    }

    @Test
    fun `content stagger spec shares window with container`() {
        val s = CalendarWeekPrep.CONTENT_STAGGER
        assertEquals("v38.prep.calendar.week-content-stagger", s.id)
        assertEquals(TransitionKind.FADE, s.transitionKind)
        assertEquals(DurationTier.FAST, s.durationTier) // 与容器同窗 180ms
        assertEquals(Overshoot.NONE, s.overshoot)
        assertEquals(7, CalendarWeekPrep.GROUP_COUNT)
    }

    // ── 容器轨：单调 ──

    @Test
    fun `slide progress is monotone increasing`() {
        var prev = -1f
        for (i in 0..100) {
            val v = CalendarWeekPrep.slideProgress(i / 100f)
            assertTrue("not monotone at p=${i / 100f}", v >= prev)
            prev = v
        }
        assertEquals(0f, CalendarWeekPrep.slideProgress(0f), 0f)
        assertEquals(1f, CalendarWeekPrep.slideProgress(1f), 0f)
    }

    // ── 内容轨：错峰顺序 ──

    @Test
    fun `group delays are strictly increasing`() {
        var prev = -1f
        for (g in 0 until CalendarWeekPrep.GROUP_COUNT) {
            val d = CalendarWeekPrep.groupDelayMs(g)
            assertTrue("group $g delay $d not increasing", d > prev)
            prev = d
        }
        assertEquals(0f, CalendarWeekPrep.groupDelayMs(0), 0f)
        assertEquals(
            6 * CalendarWeekPrep.STAGGER_STEP_MS,
            CalendarWeekPrep.groupDelayMs(6),
            0f,
        )
    }

    @Test
    fun `stagger fits inside the fast window`() {
        // 最后一组启动后仍留 ≥100ms 做淡入（180 − 6×12 = 108）
        val lastDelay = CalendarWeekPrep.groupDelayMs(CalendarWeekPrep.GROUP_COUNT - 1)
        assertTrue(lastDelay <= DurationTier.FAST.ms - 100f)
    }

    @Test
    fun `later groups lag behind at small p`() {
        // p=0.1 时：第 0 组已启动，第 6 组仍为 0（错峰可见，§3.3 验收 #1）
        assertTrue(CalendarWeekPrep.groupAlpha(0.1f, 0) > 0f)
        assertEquals(0f, CalendarWeekPrep.groupAlpha(0.1f, 6), 0f)
    }

    @Test
    fun `all groups reach exactly 1 at p=1`() {
        for (g in 0 until CalendarWeekPrep.GROUP_COUNT) {
            assertEquals(1f, CalendarWeekPrep.groupAlpha(1f, g), 0f)
            assertEquals(0f, CalendarWeekPrep.groupAlpha(0f, g), 0f)
        }
    }

    @Test
    fun `group alpha is monotone per group`() {
        for (g in 0 until CalendarWeekPrep.GROUP_COUNT) {
            var prev = -1f
            for (i in 0..50) {
                val v = CalendarWeekPrep.groupAlpha(i / 50f, g)
                assertTrue("group $g not monotone at p=${i / 50f}", v >= prev)
                prev = v
            }
        }
    }

    // ── 中途反转：速度连续 ──

    @Test
    fun `velocity envelope is zero at rest and peaks mid-flight`() {
        assertEquals(0f, CalendarWeekPrep.tweenVelocity(0f), 0f)
        assertEquals(0f, CalendarWeekPrep.tweenVelocity(1f), 0f)
        assertEquals(1.5f, CalendarWeekPrep.tweenVelocity(0.5f), 1e-5f)
    }

    @Test
    fun `velocity envelope is non-negative everywhere`() {
        for (i in 0..100) {
            assertTrue(CalendarWeekPrep.tweenVelocity(i / 100f) >= 0f)
        }
    }

    @Test
    fun `interrupt seeds reverse animation with current velocity`() {
        // 中途反转（§3.3 验收 #3）：p=0.4 处反转，新动画初速度 = v(0.4) > 0，
        // 无「急停再起」（v=0 再起步会被此断言拦截）
        val v = CalendarWeekPrep.tweenVelocity(0.4f)
        assertTrue(v > 0f)
        assertEquals(6f * 0.4f * 0.6f, v, 1e-5f)
    }

    // ── 降级分支 ──

    @Test
    fun `full ctx resolves both tracks without downgrade`() {
        val c = CalendarWeekPrep.resolveContainer(ctx = MotionContext())
        val g = CalendarWeekPrep.resolveContent(ctx = MotionContext())
        assertEquals(null, c.downgradeReason)
        assertEquals(null, g.downgradeReason)
    }

    @Test
    fun `dense list collapses stagger to monotone with named reason`() {
        val r = CalendarWeekPrep.resolveContent(ctx = MotionContext(denseList = true))
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(MotionDowngradeReasons.DENSE_LIST, r.downgradeReason)
    }

    @Test
    fun `reduce motion shortens both tracks to fast fade`() {
        val ctx = MotionContext(reduceMotion = true)
        val c = CalendarWeekPrep.resolveContainer(ctx = ctx)
        val g = CalendarWeekPrep.resolveContent(ctx = ctx)
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, c.downgradeReason)
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, g.downgradeReason)
        assertEquals(DurationTier.FAST, c.durationTier)
    }

    @Test
    fun `independent switch off returns V371 instant behavior`() {
        val offContainer = CalendarWeekPrep.CONTAINER_SLIDE.copy(enabled = false)
        val offContent = CalendarWeekPrep.CONTENT_STAGGER.copy(enabled = false)
        val c = CalendarWeekPrep.resolveContainer(spec = offContainer, ctx = MotionContext())
        val g = CalendarWeekPrep.resolveContent(spec = offContent, ctx = MotionContext())
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, c.downgradeReason)
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, g.downgradeReason)
        assertEquals(DurationTier.INSTANT, c.durationTier)
    }
}
