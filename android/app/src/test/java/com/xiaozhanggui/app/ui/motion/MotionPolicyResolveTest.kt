package com.xiaozhanggui.app.ui.motion

import com.xiaozhanggui.app.ui.theme.ResolvedMotion as LegacyResolvedMotion
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * MotionPolicy.resolve() 全降级分支测试（Design System §2.3 / Roadmap Phase 1 验收标准）。
 *
 * 每个分支断言具名降级原因（[MotionDowngradeReasons]），多条件叠加时断言优先级顺序：
 * reduce-motion > perf-tier-essential > dense-list > capability。
 * （运行时帧率档位上限 `frame-rate-below-55fps` 由 [FrameRateMonitor] 产生，
 *  在 resolve 内按"只在无更高优先级原因时记录"应用。）
 */
class MotionPolicyResolveTest {

    private fun sheetSpec() = MotionSpec(
        id = "test.sheet.expand",
        transitionKind = TransitionKind.SHARED_ANCHOR,
        durationTier = DurationTier.EMPHASIZED,
        overshoot = Overshoot.CONTENT_ONLY,
        fallbackKind = TransitionKind.FADE,
    )

    private fun pageSpec() = MotionSpec(
        id = "test.nav.page-fade",
        transitionKind = TransitionKind.FADE,
        durationTier = DurationTier.STANDARD,
        fallbackKind = TransitionKind.FADE,
    )

    @After
    fun restoreMasterSwitch() {
        // masterEnabled 是 @Volatile 全局开关：每个用例后必须恢复，避免污染其他测试。
        MotionPolicy.masterEnabled = true
    }

    // ── 0. 总开关 / 独立开关关闭 → motion-disabled（V3.7.1 瞬切行为） ──

    @Test
    fun `master disabled resolves to V371 instant behavior`() {
        MotionPolicy.masterEnabled = false
        val r = MotionPolicy.resolve(sheetSpec(), MotionContext())

        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        // V3.7.1 行为：调用方立即应用终值（baseMotion=NONE），无动效
        assertEquals(LegacyResolvedMotion.NONE, r.baseMotion)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(DurationTier.INSTANT, r.durationTier)
        assertTrue(r.interruptible)
    }

    @Test
    fun `spec disabled resolves to V371 instant behavior`() {
        val r = MotionPolicy.resolve(sheetSpec().copy(enabled = false), MotionContext())

        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        assertEquals(LegacyResolvedMotion.NONE, r.baseMotion)
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    @Test
    fun `motion-disabled wins over reduce motion`() {
        MotionPolicy.masterEnabled = false
        val r = MotionPolicy.resolve(
            sheetSpec(),
            MotionContext(reduceMotion = true, perfTier = PerfTier.ESSENTIAL, denseList = true),
        )
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
    }

    // ── 1. reduceMotion → reduce-motion：FAST 短淡入，无位移/弹簧/过冲/模糊 ──

    @Test
    fun `reduce motion degrades shared anchor to fast short fade`() {
        val r = MotionPolicy.resolve(sheetSpec(), MotionContext(reduceMotion = true))

        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.FAST, r.durationTier) // FAST = 180ms 短淡入
        assertEquals(180, r.durationTier.ms)
        assertEquals(Overshoot.NONE, r.overshoot) // 无过冲
        // 无位移/无弹簧：FADE surface + reduceMotion → 旧 token 为短淡入 QUICK
        assertEquals(LegacyResolvedMotion.QUICK, r.baseMotion)
    }

    @Test
    fun `reduce motion on fade page keeps fast fade`() {
        val r = MotionPolicy.resolve(pageSpec(), MotionContext(reduceMotion = true))

        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.FAST, r.durationTier)
    }

    @Test
    fun `reduce motion does not change NATIVE kind only clears overshoot`() {
        // NATIVE 是平台接管的系统级交互（跟手返回）：App 侧降级规则不改其 kind，仅清零过冲。
        val spec = MotionSpec(
            id = "test.system.back",
            transitionKind = TransitionKind.NATIVE,
            durationTier = DurationTier.INSTANT,
            overshoot = Overshoot.CONTENT_ONLY,
            fallbackKind = TransitionKind.FADE,
        )
        val r = MotionPolicy.resolve(spec, MotionContext(reduceMotion = true))

        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
        assertEquals(TransitionKind.NATIVE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
    }

    // ── 2. perfTier=ESSENTIAL → perf-tier-essential：SHARED_ANCHOR→FADE ──

    @Test
    fun `essential tier disables shared anchor`() {
        val r = MotionPolicy.resolve(
            sheetSpec(),
            MotionContext(perfTier = PerfTier.ESSENTIAL),
        )

        assertEquals(MotionDowngradeReasons.PERF_TIER_ESSENTIAL, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
        // 时长档保持声明值（只降 kind，不过度降级）
        assertEquals(DurationTier.EMPHASIZED, r.durationTier)
    }

    @Test
    fun `essential tier on fade spec records no downgrade`() {
        // Worker A 的 ResolvedMotion 未建模材质档：FADE 本就合规时 ESSENTIAL 不产生额外降级。
        val r = MotionPolicy.resolve(
            pageSpec(),
            MotionContext(perfTier = PerfTier.ESSENTIAL),
        )

        assertNull("FADE 在 ESSENTIAL 下本就合规，不应记录降级", r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
    }

    // ── 3. denseList → dense-list：内容错峰退化为整面单调 ──

    @Test
    fun `dense list degrades to monotone fade`() {
        val r = MotionPolicy.resolve(sheetSpec(), MotionContext(denseList = true))

        assertEquals(MotionDowngradeReasons.DENSE_LIST, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(DurationTier.EMPHASIZED, r.durationTier)
    }

    // ── 4. 能力探测失败 → 走 fallbackKind，具名原因透传 ──

    @Test
    fun `unsupported transition capability falls back with named reason`() {
        val probeReason = "predictive-back-unsupported-below-api-29"
        val ctx = MotionContext(
            capabilities = CapabilitySnapshot(
                transition = probeTransitionCapability(
                    apiLevel = 29,
                    predictiveBackRequested = true,
                ),
            ),
        )
        val r = MotionPolicy.resolve(sheetSpec(), ctx)

        assertEquals(TransitionKind.FADE, r.transitionKind) // 走声明的 fallbackKind
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(
            MotionDowngradeReasons.capability(probeReason),
            r.downgradeReason,
        )
        assertTrue(
            "具名原因必须透传原始探测原因",
            r.downgradeReason!!.contains(probeReason),
        )
    }

    @Test
    fun `glass capability failure is not consumed by motion policy`() {
        // Worker A 的 CapabilitySnapshot 文档明确：glass 能力（RenderEffect 实时模糊）
        // 由 Phase 2 PoC-2（材质）消费；MotionPolicy.resolve 只消费 transition 能力。
        // 因此玻璃探测失败不改变转场决议、不记录降级原因。
        val ctx = MotionContext(
            capabilities = CapabilitySnapshot(
                glass = probeGlassCapability(apiLevel = 29),
            ),
        )
        val r = MotionPolicy.resolve(sheetSpec(), ctx)

        assertEquals(TransitionKind.SHARED_ANCHOR, r.transitionKind)
        assertNull(
            "玻璃能力失败由 Phase 2 材质层消费，MotionPolicy 不记录降级",
            r.downgradeReason,
        )
    }

    // ── 5. 运行时帧率档位上限（FrameRateMonitor 单向降档） ──

    @Test
    fun `frame rate cap downgrades shared anchor to fade`() {
        val ctx = MotionContext(runtimeMaxTransitionKind = TransitionKind.FADE)
        val r = MotionPolicy.resolve(sheetSpec(), ctx)

        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, r.downgradeReason)
    }

    @Test
    fun `frame rate cap does not affect compliant kinds`() {
        val r = MotionPolicy.resolve(
            pageSpec(),
            MotionContext(runtimeMaxTransitionKind = TransitionKind.FADE),
        )
        assertNull(r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
    }

    @Test
    fun `frame rate cap never touches NATIVE`() {
        val spec = MotionSpec(
            id = "test.system.back",
            transitionKind = TransitionKind.NATIVE,
            durationTier = DurationTier.INSTANT,
            fallbackKind = TransitionKind.FADE,
        )
        val r = MotionPolicy.resolve(
            spec,
            MotionContext(runtimeMaxTransitionKind = TransitionKind.FADE),
        )
        assertEquals(TransitionKind.NATIVE, r.transitionKind)
        assertNull(r.downgradeReason)
    }

    // ── 未降级：按声明原样执行 ──

    @Test
    fun `no downgrade resolves as declared`() {
        val r = MotionPolicy.resolve(sheetSpec(), MotionContext())

        assertNull(r.downgradeReason)
        assertEquals(TransitionKind.SHARED_ANCHOR, r.transitionKind)
        assertEquals(DurationTier.EMPHASIZED, r.durationTier)
        assertEquals(Overshoot.CONTENT_ONLY, r.overshoot)
        assertTrue(r.interruptible)
        // baseMotion 复用旧 resolveMotion：SHARED_ANCHOR→SPRING surface→SOFT_SPRING
        assertEquals(LegacyResolvedMotion.SOFT_SPRING, r.baseMotion)
    }

    @Test
    fun `base motion maps fade surface to quick`() {
        val r = MotionPolicy.resolve(pageSpec(), MotionContext())
        assertEquals(LegacyResolvedMotion.QUICK, r.baseMotion)
    }

    // ── 优先级：多条件叠加时高优先级胜出 ──

    @Test
    fun `priority reduce motion beats all`() {
        val ctx = MotionContext(
            reduceMotion = true,
            perfTier = PerfTier.ESSENTIAL,
            denseList = true,
            capabilities = CapabilitySnapshot(
                transition = CapabilityResult.Unsupported("predictive-back-unsupported-below-api-29"),
            ),
            runtimeMaxTransitionKind = TransitionKind.FADE,
        )
        val r = MotionPolicy.resolve(sheetSpec(), ctx)
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.FAST, r.durationTier)
    }

    @Test
    fun `priority essential beats dense list and capability`() {
        val ctx = MotionContext(
            perfTier = PerfTier.ESSENTIAL,
            denseList = true,
            capabilities = CapabilitySnapshot(
                transition = CapabilityResult.Unsupported("predictive-back-unsupported-below-api-29"),
            ),
        )
        val r = MotionPolicy.resolve(sheetSpec(), ctx)
        assertEquals(MotionDowngradeReasons.PERF_TIER_ESSENTIAL, r.downgradeReason)
    }

    @Test
    fun `priority dense list beats capability`() {
        val ctx = MotionContext(
            denseList = true,
            capabilities = CapabilitySnapshot(
                transition = CapabilityResult.Unsupported("predictive-back-unsupported-below-api-29"),
            ),
        )
        val r = MotionPolicy.resolve(sheetSpec(), ctx)
        assertEquals(MotionDowngradeReasons.DENSE_LIST, r.downgradeReason)
    }

    @Test
    fun `frame rate reason only recorded when no higher priority reason`() {
        // dense-list 已命中时，帧率上限仍会压 kind（FADE），但原因保留更高优先级的 dense-list
        val ctx = MotionContext(
            denseList = true,
            runtimeMaxTransitionKind = TransitionKind.FADE,
        )
        val r = MotionPolicy.resolve(sheetSpec(), ctx)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(MotionDowngradeReasons.DENSE_LIST, r.downgradeReason)
    }
}
