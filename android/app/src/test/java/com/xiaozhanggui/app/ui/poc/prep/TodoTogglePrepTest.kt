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
 * 待办勾选 Spec 草案测试（Phase 3 接入准备；JVM）。
 *
 * 覆盖：Spec 声明字段、打钩绘制端点/单调性、删除线不抢跑、
 * Reduce Motion 终态语义（视觉直达终态 + 触感保留）。
 * 触感真机触发 10 次 NOT RUN（见 `docs/ANDROID_V38_PHASE3_PREP.md`）。
 */
class TodoTogglePrepTest {

    @After
    fun restoreMasterSwitch() {
        MotionPolicy.masterEnabled = true
    }

    // ── Spec 声明字段 ──

    @Test
    fun `spec declares fade with fast tier and no overshoot`() {
        val s = TodoTogglePrep.TOGGLE
        assertEquals("v38.prep.todo.toggle", s.id)
        assertEquals(TransitionKind.FADE, s.transitionKind)
        assertEquals(DurationTier.FAST, s.durationTier)
        assertEquals(180, s.durationTier.ms)
        assertEquals(Overshoot.NONE, s.overshoot)
        assertEquals(TransitionKind.FADE, s.fallbackKind)
        assertTrue(s.interruptible)
        assertTrue(s.enabled)
    }

    @Test
    fun `haptic fires at press instant independent of visual progress`() {
        // 触感语义常量：按压瞬间触发，与视觉动效解耦
        assertEquals("press-instant", TodoTogglePrep.HAPTIC_TIMING)
    }

    // ── 打钩绘制：端点精确 + 单调 ──

    @Test
    fun `check draw endpoints are exact`() {
        assertEquals(0f, TodoTogglePrep.checkDrawProgress(0f), 0f)
        assertEquals(1f, TodoTogglePrep.checkDrawProgress(1f), 0f)
    }

    @Test
    fun `check draw is monotone increasing`() {
        var prev = -1f
        for (i in 0..100) {
            val v = TodoTogglePrep.checkDrawProgress(i / 100f)
            assertTrue("not monotone at p=${i / 100f}: $v < $prev", v >= prev)
            prev = v
        }
    }

    @Test
    fun `check draw is clamped outside 0-1`() {
        assertEquals(0f, TodoTogglePrep.checkDrawProgress(-0.5f), 0f)
        assertEquals(1f, TodoTogglePrep.checkDrawProgress(1.5f), 0f)
    }

    // ── 删除线：不抢跑 ──

    @Test
    fun `strike does not lead the check draw`() {
        assertEquals(0f, TodoTogglePrep.strikeAlpha(0.2f), 0f)
        assertEquals(0f, TodoTogglePrep.strikeAlpha(0.25f), 0f)
        assertTrue(TodoTogglePrep.strikeAlpha(0.6f) > 0f)
        assertEquals(1f, TodoTogglePrep.strikeAlpha(1f), 0f)
    }

    @Test
    fun `title dim follows strike window`() {
        assertEquals(
            TodoTogglePrep.strikeAlpha(0.5f),
            TodoTogglePrep.titleDimT(0.5f),
            0f,
        )
    }

    // ── 降级分支 ──

    @Test
    fun `full ctx resolves without downgrade`() {
        val r = TodoTogglePrep.resolveToggle(ctx = MotionContext())
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.FAST, r.durationTier)
        assertEquals(null, r.downgradeReason)
    }

    @Test
    fun `reduce motion jumps visual to end state but keeps haptic`() {
        val sem = TodoTogglePrep.reduceMotionSemantics(MotionContext())
        assertTrue(sem.visualJumpsToEndState)
        assertTrue(sem.hapticKept) // 触感不是视觉动效，不降级（§3.2 验收 #4）
        val r = TodoTogglePrep.resolveToggle(ctx = MotionContext(reduceMotion = true))
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    @Test
    fun `independent switch off returns V371 instant behavior`() {
        val off = TodoTogglePrep.TOGGLE.copy(enabled = false)
        val r = TodoTogglePrep.resolveToggle(spec = off, ctx = MotionContext())
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        assertEquals(DurationTier.INSTANT, r.durationTier)
    }

    @Test
    fun `dense list keeps fade without overshoot`() {
        val r = TodoTogglePrep.resolveToggle(ctx = MotionContext(denseList = true))
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(MotionDowngradeReasons.DENSE_LIST, r.downgradeReason)
    }
}
