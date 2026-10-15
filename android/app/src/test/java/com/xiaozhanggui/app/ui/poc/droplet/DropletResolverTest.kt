package com.xiaozhanggui.app.ui.poc.droplet

import com.xiaozhanggui.app.ui.motion.CapabilityResult
import com.xiaozhanggui.app.ui.motion.CapabilitySnapshot
import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.PerfTier
import com.xiaozhanggui.app.ui.motion.TransitionKind
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-1 降级分支测试：具名原因断言（Design System §2.3）。
 *
 * - 无锚点 → `no-anchor`（Phase A）；
 * - Reduce Motion → `reduce-motion`（FAST 短淡入）；
 * - 低端档 → `perf-tier-essential`（FADE）；
 * - 总开关关闭 → `motion-disabled`（陷阱：MotionPolicy 此时透传
 *   kind=SHARED_ANCHOR，必须同时检查 reason，否则仍会跑液滴）。
 */
class DropletResolverTest {

    @After
    fun resetMasterSwitch() {
        MotionPolicy.masterEnabled = true
    }

    private fun anchor() = AnchorRect(
        left = 100f, top = 500f, right = 260f, bottom = 552f, cornerRadiusPx = 12f,
    )

    @Test
    fun `null anchor degrades to standard fade with no-anchor reason`() {
        val r = resolveDropletMenu(null, MotionContext())
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.STANDARD, r.durationTier) // 标准淡入
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(DropletDowngradeReasons.NO_ANCHOR, r.downgradeReason)
        assertFalse(r.runDropletPhases)
    }

    @Test
    fun `zero-size anchor counts as no anchor`() {
        val invisible = AnchorRect(10f, 10f, 10f, 10f, 0f)
        assertFalse(invisible.isVisible)
        val r = resolveDropletMenu(invisible, MotionContext())
        assertEquals(DropletDowngradeReasons.NO_ANCHOR, r.downgradeReason)
        assertFalse(r.runDropletPhases)
    }

    @Test
    fun `normal case runs all six droplet phases`() {
        val r = resolveDropletMenu(anchor(), MotionContext())
        assertEquals(TransitionKind.SHARED_ANCHOR, r.transitionKind)
        assertEquals(DurationTier.STANDARD, r.durationTier)
        assertEquals(Overshoot.CONTENT_ONLY, r.overshoot)
        assertNull(r.downgradeReason)
        assertTrue(r.runDropletPhases)
    }

    @Test
    fun `reduce motion degrades to FAST short fade`() {
        val r = resolveDropletMenu(anchor(), MotionContext(reduceMotion = true))
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.FAST, r.durationTier)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
        assertFalse(r.runDropletPhases)
    }

    @Test
    fun `essential perf tier degrades to FADE`() {
        val r = resolveDropletMenu(anchor(), MotionContext(perfTier = PerfTier.ESSENTIAL))
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(MotionDowngradeReasons.PERF_TIER_ESSENTIAL, r.downgradeReason)
        assertFalse(r.runDropletPhases)
    }

    @Test
    fun `master switch off never runs droplet even though kind passes through`() {
        MotionPolicy.masterEnabled = false
        val r = resolveDropletMenu(anchor(), MotionContext())
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        assertFalse(r.runDropletPhases)
    }

    @Test
    fun `spec disabled never runs droplet`() {
        val spec = DropletSpecs.MENU_EXPAND.copy(enabled = false)
        val r = resolveDropletMenu(anchor(), MotionContext(), spec)
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        assertFalse(r.runDropletPhases)
    }

    @Test
    fun `frame-rate runtime cap degrades to FADE with named reason`() {
        val ctx = MotionContext(runtimeMaxTransitionKind = TransitionKind.FADE)
        val r = resolveDropletMenu(anchor(), ctx)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, r.downgradeReason)
        assertFalse(r.runDropletPhases)
    }

    @Test
    fun `spec declaration is complete - kind tier overshoot fallback`() {
        val spec = DropletSpecs.MENU_EXPAND
        assertEquals(TransitionKind.SHARED_ANCHOR, spec.transitionKind)
        assertEquals(DurationTier.STANDARD, spec.durationTier)
        assertEquals(Overshoot.CONTENT_ONLY, spec.overshoot)
        assertEquals(TransitionKind.FADE, spec.fallbackKind)
        assertTrue(spec.interruptible)
        assertTrue(spec.enabled)
    }

    @Test
    fun `capability probe failure follows declared fallback`() {
        val ctx = MotionContext(
            capabilities = CapabilitySnapshot(
                transition = CapabilityResult.Unsupported(
                    "transition-requires-hardware-acceleration",
                ),
            ),
        )
        val r = resolveDropletMenu(anchor(), ctx)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertTrue(r.downgradeReason!!.startsWith("capability-unsupported:"))
        assertFalse(r.runDropletPhases)
    }
}
