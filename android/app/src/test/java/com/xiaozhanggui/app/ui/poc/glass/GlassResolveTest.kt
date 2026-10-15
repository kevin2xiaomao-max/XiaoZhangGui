package com.xiaozhanggui.app.ui.poc.glass

import com.xiaozhanggui.app.ui.motion.CapabilityResult
import com.xiaozhanggui.app.ui.motion.FrameRateMonitor
import com.xiaozhanggui.app.ui.motion.PerfTier
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-2：三档降级链具名原因断言 + 降级日志 + T1 帧率采样。
 *
 * 降级优先级（只降不升）：reduce-motion → perf-tier-essential →
 * perf-tier-reduced → capability-unsupported → frame-rate-below-55fps。
 * 原因字符串复用 Phase 1 `MotionDowngradeReasons`（不分叉）。
 */
class GlassResolveTest {

    private fun resolve(
        requested: GlassTier = GlassTier.T1_FIDELITY,
        reduceMotion: Boolean = false,
        perfTier: PerfTier = PerfTier.FULL,
        capability: CapabilityResult = CapabilityResult.Ok,
        frameRateDowngraded: Boolean = false,
    ): GlassResolution = resolveGlassTier(
        requested = requested,
        reduceMotion = reduceMotion,
        perfTier = perfTier,
        capability = capability,
        frameRateDowngraded = frameRateDowngraded,
    )

    // ── 降级链：具名原因 ──

    @Test
    fun `t1 with full capability is not downgraded`() {
        val r = resolve()
        assertEquals(GlassTier.T1_FIDELITY, r.tier)
        assertNull(r.downgradeReason)
    }

    @Test
    fun `api 29 downgrades t1 to t2 with named reason`() {
        val r = resolve(capability = probeGlassTierCapability(apiLevel = 29))
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertEquals("capability-unsupported:no-backdrop-blur-on-api-29", r.downgradeReason)
    }

    @Test
    fun `low memory downgrades t1 to t2 with named reason`() {
        val r = resolve(capability = probeGlassTierCapability(apiLevel = 35, lowMemory = true))
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertEquals("capability-unsupported:glass-low-memory-device", r.downgradeReason)
    }

    @Test
    fun `capability gate does not affect t2 or t3`() {
        val bad = probeGlassTierCapability(apiLevel = 29)
        val r2 = resolve(requested = GlassTier.T2_BALANCED, capability = bad)
        assertEquals(GlassTier.T2_BALANCED, r2.tier)
        assertNull(r2.downgradeReason)
        val r3 = resolve(requested = GlassTier.T3_ESSENTIAL, capability = bad)
        assertEquals(GlassTier.T3_ESSENTIAL, r3.tier)
        assertNull(r3.downgradeReason)
    }

    @Test
    fun `reduce motion forces t3 with named reason`() {
        val r = resolve(reduceMotion = true)
        assertEquals(GlassTier.T3_ESSENTIAL, r.tier)
        assertEquals("reduce-motion", r.downgradeReason)
    }

    @Test
    fun `reduce motion on t3 request keeps t3 with no reason`() {
        // 未发生档位下调 → 不算降级，reason 为 null（日志不记）
        val r = resolve(requested = GlassTier.T3_ESSENTIAL, reduceMotion = true)
        assertEquals(GlassTier.T3_ESSENTIAL, r.tier)
        assertNull(r.downgradeReason)
    }

    @Test
    fun `perf tier essential forces t3 with named reason`() {
        val r = resolve(perfTier = PerfTier.ESSENTIAL)
        assertEquals(GlassTier.T3_ESSENTIAL, r.tier)
        assertEquals("perf-tier-essential", r.downgradeReason)
    }

    @Test
    fun `perf tier reduced steps t1 down to t2`() {
        val r = resolve(perfTier = PerfTier.REDUCED)
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertEquals("perf-tier-reduced", r.downgradeReason)
    }

    @Test
    fun `perf tier reduced does not touch t2`() {
        val r = resolve(requested = GlassTier.T2_BALANCED, perfTier = PerfTier.REDUCED)
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertNull(r.downgradeReason)
    }

    @Test
    fun `frame rate downgrade moves t1 to t2 - device defaults to t2`() {
        // PoC-2 合入标准③：T1 在目标机型上 <55fps → 该机型默认 T2
        val r = resolve(frameRateDowngraded = true)
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertEquals("frame-rate-below-55fps", r.downgradeReason)
    }

    @Test
    fun `frame rate downgrade moves t2 to t3`() {
        val r = resolve(requested = GlassTier.T2_BALANCED, frameRateDowngraded = true)
        assertEquals(GlassTier.T3_ESSENTIAL, r.tier)
        assertEquals("frame-rate-below-55fps", r.downgradeReason)
    }

    @Test
    fun `frame rate downgrade never moves t3`() {
        val r = resolve(requested = GlassTier.T3_ESSENTIAL, frameRateDowngraded = true)
        assertEquals(GlassTier.T3_ESSENTIAL, r.tier)
        assertNull(r.downgradeReason)
    }

    @Test
    fun `higher priority reason wins - reduce motion over capability`() {
        val r = resolve(
            reduceMotion = true,
            capability = probeGlassTierCapability(apiLevel = 29),
        )
        assertEquals(GlassTier.T3_ESSENTIAL, r.tier)
        assertEquals("reduce-motion", r.downgradeReason)
    }

    // ── 降级日志：只记档位变化 ──

    @Test
    fun `resolver logs only tier changes with named reasons`() {
        var now = 1000L
        val seen = mutableListOf<GlassDowngradeEvent>()
        val resolver = GlassTierResolver(clockMs = { now }, onDowngrade = { seen.add(it) })
        val defaults = { r: GlassTierResolver -> r.resolve(
            reduceMotion = false,
            perfTier = PerfTier.FULL,
            capability = CapabilityResult.Ok,
            frameRateDowngraded = false,
        ) }

        // 首次解析建立基线，不记事件
        defaults(resolver)
        assertTrue(seen.isEmpty())
        // 档位不变，不记
        defaults(resolver)
        assertTrue(seen.isEmpty())

        // 低内存：T1 → T2，记一条（具名原因 + 时间戳，不含业务正文）
        now = 2000L
        resolver.resolve(
            reduceMotion = false,
            perfTier = PerfTier.FULL,
            capability = probeGlassTierCapability(apiLevel = 35, lowMemory = true),
            frameRateDowngraded = false,
        )
        assertEquals(1, seen.size)
        val event = seen.single()
        assertEquals(GlassTier.T1_FIDELITY, event.from)
        assertEquals(GlassTier.T2_BALANCED, event.to)
        assertEquals("capability-unsupported:glass-low-memory-device", event.reason)
        assertEquals(2000L, event.atMs)
    }

    @Test
    fun `resolver downgradeEvents returns a snapshot copy`() {
        val resolver = GlassTierResolver()
        resolver.resolve(
            reduceMotion = false,
            perfTier = PerfTier.FULL,
            capability = CapabilityResult.Ok,
            frameRateDowngraded = false,
        )
        resolver.resolve(
            reduceMotion = true,
            perfTier = PerfTier.FULL,
            capability = CapabilityResult.Ok,
            frameRateDowngraded = false,
        )
        val events = resolver.downgradeEvents()
        assertEquals(1, events.size)
        assertEquals(GlassTier.T1_FIDELITY, events[0].from)
        assertEquals(GlassTier.T3_ESSENTIAL, events[0].to)
        assertEquals("reduce-motion", events[0].reason)
    }

    // ── T1 帧率采样 ──

    @Test
    fun `frame sampler records t1 samples and downgrades on sustained low fps`() {
        var now = 0L
        val monitorEvents = mutableListOf<FrameRateMonitor.DowngradeEvent>()
        val sampler = GlassFrameSampler(
            clockMs = { now },
            onMonitorDowngrade = { monitorEvents.add(it) },
        )
        // 50fps 持续 2.5s（125 帧）：超过"持续 1s < 55fps"判定窗口
        repeat(125) {
            now += 20
            sampler.onFrame()
        }
        assertTrue(sampler.isDowngraded)
        assertEquals(125, sampler.sampledFrames().size)
        assertEquals(1, monitorEvents.size)
        assertEquals("frame-rate-below-55fps", monitorEvents.single().reason)

        // 采样器状态可被降级链消费：T1 → T2（该机型默认 T2）
        val r = resolve(frameRateDowngraded = sampler.isDowngraded)
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertEquals("frame-rate-below-55fps", r.downgradeReason)
    }

    @Test
    fun `frame sampler does not downgrade on healthy fps`() {
        var now = 0L
        val sampler = GlassFrameSampler(clockMs = { now })
        // 60fps 持续 2.5s：不触发
        repeat(150) {
            now += 16
            sampler.onFrame()
        }
        assertTrue(!sampler.isDowngraded)
        assertEquals(150, sampler.sampledFrames().size)
    }

    @Test
    fun `frame sampler reset restores tier ceiling`() {
        var now = 0L
        val sampler = GlassFrameSampler(clockMs = { now })
        repeat(125) {
            now += 20
            sampler.onFrame()
        }
        assertTrue(sampler.isDowngraded)
        sampler.reset()
        assertTrue(!sampler.isDowngraded)
        assertTrue(sampler.sampledFrames().isEmpty())
    }
}
