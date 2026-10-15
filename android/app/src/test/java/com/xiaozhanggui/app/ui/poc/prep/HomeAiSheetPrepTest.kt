package com.xiaozhanggui.app.ui.poc.prep

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.FrameRateMonitor
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.PerfTier
import com.xiaozhanggui.app.ui.motion.TransitionKind
import com.xiaozhanggui.app.ui.poc.droplet.AnchorRect
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页 AI Sheet 液滴展开的 Spec 草案测试（Phase 3 接入准备；JVM）。
 *
 * 覆盖：Spec 声明字段、Phase A 锚点确认（no-anchor 具名降级）、
 * 五级降级分支、相位边界与顺序（同起/不抢跑）、过冲边界。
 * 真机录屏逐帧验证 NOT RUN（见 `docs/ANDROID_V38_PHASE3_PREP.md`）。
 */
class HomeAiSheetPrepTest {

    private val anchor = AnchorRect(0f, 0f, 100f, 48f, 12f)

    @After
    fun restoreMasterSwitch() {
        MotionPolicy.masterEnabled = true
    }

    // ── Spec 声明字段 ──

    @Test
    fun `spec declares shared-anchor with standard tier and explicit fade fallback`() {
        val s = HomeAiSheetPrep.EXPAND
        assertEquals("v38.prep.home.ai-sheet-expand", s.id)
        assertEquals(TransitionKind.SHARED_ANCHOR, s.transitionKind)
        assertEquals(DurationTier.STANDARD, s.durationTier)
        assertEquals(280, s.durationTier.ms)
        assertEquals(Overshoot.CONTENT_ONLY, s.overshoot)
        assertEquals(TransitionKind.FADE, s.fallbackKind)
        assertTrue(s.interruptible)
        assertTrue(s.enabled)
    }

    @Test
    fun `glass material declares backdrop domain role and fallback chain`() {
        val g = HomeAiSheetPrep.AI_SHEET_GLASS
        assertEquals(PrepGlassMaterial.Tier.T1_FIDELITY, g.tier)
        assertEquals("home-feed", g.backdropDomain)
        assertEquals("floating-sheet", g.role)
        assertEquals("T2 -> T3", g.fallbackChain)
    }

    // ── Phase A 锚点确认：no-anchor 具名降级 ──

    @Test
    fun `null anchor downgrades to fade with named no-anchor reason`() {
        val r = HomeAiSheetPrep.resolveExpand(ctx = MotionContext(), anchor = null)
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.FAST, r.durationTier)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(HomeAiSheetPrep.DowngradeReasons.NO_ANCHOR, r.downgradeReason)
    }

    @Test
    fun `zero-size anchor downgrades to fade with named no-anchor reason`() {
        val empty = AnchorRect(10f, 10f, 10f, 10f, 0f)
        val r = HomeAiSheetPrep.resolveExpand(ctx = MotionContext(), anchor = empty)
        assertEquals(HomeAiSheetPrep.DowngradeReasons.NO_ANCHOR, r.downgradeReason)
        assertEquals(TransitionKind.FADE, r.transitionKind)
    }

    @Test
    fun `valid anchor with full ctx resolves without downgrade`() {
        val r = HomeAiSheetPrep.resolveExpand(ctx = MotionContext(), anchor = anchor)
        assertEquals(TransitionKind.SHARED_ANCHOR, r.transitionKind)
        assertEquals(null, r.downgradeReason)
    }

    // ── 五级降级分支 ──

    @Test
    fun `reduce motion degrades to fast fade`() {
        val r = HomeAiSheetPrep.resolveExpandReduceMotion(MotionContext())
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(DurationTier.FAST, r.durationTier)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)
    }

    @Test
    fun `perf tier essential degrades shared-anchor to fade`() {
        val r = HomeAiSheetPrep.resolveExpand(
            ctx = MotionContext(perfTier = PerfTier.ESSENTIAL),
            anchor = anchor,
        )
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(MotionDowngradeReasons.PERF_TIER_ESSENTIAL, r.downgradeReason)
    }

    @Test
    fun `dense list degrades content stagger to monotone`() {
        val r = HomeAiSheetPrep.resolveExpand(
            ctx = MotionContext(denseList = true),
            anchor = anchor,
        )
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(Overshoot.NONE, r.overshoot)
        assertEquals(MotionDowngradeReasons.DENSE_LIST, r.downgradeReason)
    }

    @Test
    fun `sustained low frame rate caps transition kind with named reason`() {
        val r = HomeAiSheetPrep.resolveExpand(
            ctx = MotionContext(runtimeMaxTransitionKind = TransitionKind.FADE),
            anchor = anchor,
        )
        assertEquals(TransitionKind.FADE, r.transitionKind)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, r.downgradeReason)
    }

    @Test
    fun `master disabled falls back to V371 instant behavior`() {
        MotionPolicy.masterEnabled = false
        val r = HomeAiSheetPrep.resolveExpand(ctx = MotionContext(), anchor = anchor)
        assertEquals(MotionDowngradeReasons.MOTION_DISABLED, r.downgradeReason)
        assertEquals(DurationTier.INSTANT, r.durationTier)
    }

    // ── 相位边界与顺序 ──

    @Test
    fun `anchor scale returns to exactly 1 at rest and steady state`() {
        assertEquals(1f, HomeAiSheetPrep.anchorScale(0f), 0f)
        assertEquals(1f, HomeAiSheetPrep.anchorScale(1f), 0f)
        assertTrue(HomeAiSheetPrep.anchorScale(0.125f) < 1f) // 收缩发生
    }

    @Test
    fun `move starts together with shrink no sequential start`() {
        // 反例「收缩播完才位移」⇔ p=0.125 时位移为 0；此处必须 >0
        assertTrue(HomeAiSheetPrep.moveProgress(0.125f) > 0f)
        assertEquals(0f, HomeAiSheetPrep.moveProgress(0f), 0f)
    }

    @Test
    fun `height leads width by quarter phase`() {
        // p=0.6 时纵向 ≥90% 先行，横向滞后
        assertTrue(HomeAiSheetPrep.heightFraction(0.6f) >= 0.9f)
        assertTrue(HomeAiSheetPrep.widthFraction(0.6f) < HomeAiSheetPrep.heightFraction(0.6f))
    }

    @Test
    fun `content does not appear before geometry quarter`() {
        assertEquals(0f, HomeAiSheetPrep.contentAlpha(0.25f), 0f)
        assertEquals(0f, HomeAiSheetPrep.contentAlpha(0f), 0f)
        assertEquals(1f, HomeAiSheetPrep.contentAlpha(1f), 0f)
    }

    @Test
    fun `overshoot peaks once and returns exactly to 1`() {
        val mid = HomeAiSheetPrep.panelOvershoot(0.925f)
        assertTrue(mid > 1f && mid <= 1.03f) // 单峰 2.5% < 3%
        assertEquals(1f, HomeAiSheetPrep.panelOvershoot(1f), 0f)
        assertEquals(1f, HomeAiSheetPrep.panelOvershoot(0f), 0f)
    }

    @Test
    fun `corner returns to token radius at steady state`() {
        assertEquals(1f, HomeAiSheetPrep.cornerT(1f), 0f)
        assertEquals(0f, HomeAiSheetPrep.cornerT(0f), 0f)
    }

    @Test
    fun `frame rate monitor wiring keeps shared-anchor at healthy fps`() {
        // JVM 假时钟仿真：60fps 健康时不触发降档（真机采样 NOT RUN）
        val now = longArrayOf(0L)
        val monitor = FrameRateMonitor(clockMs = { now[0] })
        repeat(120) { monitor.onFrame(); now[0] += 16 }
        val r = HomeAiSheetPrep.resolveExpand(
            ctx = MotionContext(runtimeMaxTransitionKind = monitor.currentMaxTransitionKind()),
            anchor = anchor,
        )
        assertEquals(TransitionKind.SHARED_ANCHOR, r.transitionKind)
    }
}
