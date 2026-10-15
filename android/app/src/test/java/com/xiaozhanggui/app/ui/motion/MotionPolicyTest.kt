package com.xiaozhanggui.app.ui.motion

import com.xiaozhanggui.app.ui.theme.ResolvedMotion as LegacyResolvedMotion
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * MotionPolicy.resolve() 全降级分支覆盖（纯函数，JVM 可测）。
 *
 * 每个分支断言具名降级原因（Design System §2.3：原因可写日志、可断言）。
 */
class MotionPolicyTest {

    @After
    fun resetMasterSwitch() {
        MotionPolicy.masterEnabled = true
    }

    private fun anchorSpec() = MotionSpec(
        id = "ai.sheet.expand",
        transitionKind = TransitionKind.SHARED_ANCHOR,
        durationTier = DurationTier.STANDARD,
        overshoot = Overshoot.CONTENT_ONLY,
        fallbackKind = TransitionKind.FADE,
        description = "AI Sheet 液滴展开",
    )

    private fun fadeSpec() = MotionSpec(
        id = "home.tab.switch",
        transitionKind = TransitionKind.FADE,
        durationTier = DurationTier.FAST,
        fallbackKind = TransitionKind.FADE,
    )

    // ── 0. 未降级：原样通过 ──

    @Test
    fun `no downgrade passes spec through with null reason`() {
        val r = MotionPolicy.resolve(anchorSpec(), MotionContext())
        assertNull(r.downgradeReason)
        assertEquals(TransitionKind.SHARED_ANCHOR, r.transitionKind)
        assertEquals(DurationTier.STANDARD, r.durationTier)
        assertEquals(Overshoot.CONTENT_ONLY, r.overshoot)
        assertTrue(r.interruptible)
    }

    @Test
    fun `baseMotion reuses legacy resolveMotion mapping`() {
        // SHARED_ANCHOR → SPRING surface → SOFT_SPRING；FADE → QUICK：旧 when(baseMotion) 分支零改动
        val anchor = MotionPolicy.resolve(anchorSpec(), MotionContext())
        assertEquals(LegacyResolvedMotion.SOFT_SPRING, anchor.baseMotion)
        val fade = MotionPolicy.resolve(fadeSpec(), MotionContext())
        assertEquals(LegacyResolvedMotion.QUICK, fade.baseMotion)
    }

    @Test
    fun `duration tiers reuse V371 values without forking`() {
        assertEquals(100, DurationTier.INSTANT.ms)
        assertEquals(180, DurationTier.FAST.ms)
        assertEquals(280, DurationTier.STANDARD.ms)
        assertEquals(420, DurationTier.EMPHASIZED.ms)
    }

    // ── 1. 总开关 / 独立开关：motion-disabled ──

    @Test
    fun `master switch off returns V371 instant behavior`() {
        MotionPolicy.masterEnabled = false
        val r = MotionPolicy.resolve(anchorSpec(), MotionContext())
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        assertEquals(LegacyResolvedMotion.NONE, r.baseMotion) // 瞬切：调用方直接应用终值
        assertEquals(DurationTier.INSTANT, r.durationTier)
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    @Test
    fun `spec disabled returns V371 instant behavior`() {
        val r = MotionPolicy.resolve(anchorSpec().copy(enabled = false), MotionContext())
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        assertEquals(LegacyResolvedMotion.NONE, r.baseMotion)
    }

    // ── 2. Reduce Motion：reduce-motion ──

    @Test
    fun `reduce motion degrades to FAST short fade`() {
        val r = MotionPolicy.resolve(anchorSpec(), MotionContext(reduceMotion = true))
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.FAST, r.durationTier)
        assertEquals(Overshoot.NONE, r.overshoot) // 无位移/弹簧/过冲
        assertEquals(LegacyResolvedMotion.QUICK, r.baseMotion)
    }

    @Test
    fun `reduce motion keeps NATIVE kind but clears overshoot`() {
        val native = MotionSpec(
            id = "system.back.gesture",
            transitionKind = TransitionKind.NATIVE,
            durationTier = DurationTier.STANDARD,
            overshoot = Overshoot.CONTENT_ONLY,
            fallbackKind = TransitionKind.NATIVE,
        )
        val r = MotionPolicy.resolve(native, MotionContext(reduceMotion = true))
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
        assertEquals(TransitionKind.NATIVE, r.transitionKind) // 平台接管，不改 kind
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    // ── 3. 性能档 ESSENTIAL：perf-tier-essential ──

    @Test
    fun `essential perf tier bans SHARED_ANCHOR`() {
        val r = MotionPolicy.resolve(
            anchorSpec(),
            MotionContext(perfTier = PerfTier.ESSENTIAL),
        )
        assertEquals(MotionDowngradeReasons.PERF_TIER_ESSENTIAL, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(DurationTier.STANDARD, r.durationTier) // 时长档不变
    }

    @Test
    fun `essential perf tier leaves FADE untouched`() {
        val r = MotionPolicy.resolve(
            fadeSpec(),
            MotionContext(perfTier = PerfTier.ESSENTIAL),
        )
        assertNull(r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
    }

    // ── 4. 密集列表：dense-list ──

    @Test
    fun `dense list degrades stagger to monotone fade`() {
        val r = MotionPolicy.resolve(anchorSpec(), MotionContext(denseList = true))
        assertEquals(MotionDowngradeReasons.DENSE_LIST, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    // ── 5. 能力探测失败：走 fallbackKind，原因透传 ──

    @Test
    fun `unsupported transition capability falls back with named reason`() {
        val ctx = MotionContext(
            capabilities = CapabilitySnapshot(
                transition = CapabilityResult.Unsupported("no-backdrop-blur-on-api-29"),
            ),
        )
        val r = MotionPolicy.resolve(anchorSpec(), ctx)
        assertEquals(TransitionKind.FADE, r.transitionKind) // spec.fallbackKind
        assertEquals(
            "capability-unsupported:no-backdrop-blur-on-api-29",
            r.downgradeReason,
        )
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    // ── 优先级：只记最高优先级原因（单向只降不升） ──

    @Test
    fun `reduce motion wins over lower priority rules`() {
        val ctx = MotionContext(
            reduceMotion = true,
            perfTier = PerfTier.ESSENTIAL,
            denseList = true,
            capabilities = CapabilitySnapshot(
                transition = CapabilityResult.Unsupported("no-backdrop-blur-on-api-29"),
            ),
        )
        val r = MotionPolicy.resolve(anchorSpec(), ctx)
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
    }

    @Test
    fun `essential wins over dense list and capability`() {
        val ctx = MotionContext(
            perfTier = PerfTier.ESSENTIAL,
            denseList = true,
            capabilities = CapabilitySnapshot(
                transition = CapabilityResult.Unsupported("no-backdrop-blur-on-api-29"),
            ),
        )
        val r = MotionPolicy.resolve(anchorSpec(), ctx)
        assertEquals(MotionDowngradeReasons.PERF_TIER_ESSENTIAL, r.downgradeReason)
    }

    // ── 6. 运行时帧率档位上限：frame-rate-below-55fps ──

    @Test
    fun `frame rate cap downgrades SHARED_ANCHOR to FADE`() {
        val r = MotionPolicy.resolve(
            anchorSpec(),
            MotionContext(runtimeMaxTransitionKind = TransitionKind.FADE),
        )
        assertEquals(MotionDowngradeReasons.FRAME_RATE, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    @Test
    fun `frame rate cap does not touch NATIVE`() {
        val native = MotionSpec(
            id = "system.back.gesture",
            transitionKind = TransitionKind.NATIVE,
            durationTier = DurationTier.FAST,
            fallbackKind = TransitionKind.NATIVE,
        )
        val r = MotionPolicy.resolve(
            native,
            MotionContext(runtimeMaxTransitionKind = TransitionKind.FADE),
        )
        assertNull(r.downgradeReason)
        assertEquals(TransitionKind.NATIVE, r.transitionKind)
    }
}
