package com.xiaozhanggui.app.ui.poc.glass

import com.xiaozhanggui.app.ui.motion.CapabilityResult
import com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons
import com.xiaozhanggui.app.ui.motion.PerfTier
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-2 降级触发条件序列测试（v1.2.7 审计建议 PoC-2 #1）。
 *
 * 背景：`GlassResolveTest` 已逐条覆盖单个降级条件（Reduce Motion /
 * perf-tier / 能力探测 / 帧率），但缺"条件连续变化时档位按具名策略
 * 逐步下调、且当前档位可查询"的序列证据。本测试用有状态的
 * [GlassTierResolver] 模拟"低性能→省电→Reduce Motion"的连续变化，
 * 断言每一步的档位、具名原因，以及降级事件日志的完整序列。
 *
 * 纯 JVM 测试；只加测试，不改 PoC 实现。
 */
class GlassTierSequenceTest {

    private fun full() = PerfTier.FULL
    private fun ok() = CapabilityResult.Ok

    @Test
    fun `tier steps down through named reasons as conditions worsen`() {
        var now = 1000L
        val seen = mutableListOf<GlassDowngradeEvent>()
        val resolver = GlassTierResolver(clockMs = { now }, onDowngrade = { seen.add(it) })

        // 基线：T1 请求，全能力 → 不降级，当前档位可查询为 T1
        var r = resolver.resolve(
            requested = GlassTier.T1_FIDELITY,
            reduceMotion = false,
            perfTier = full(),
            capability = ok(),
            frameRateDowngraded = false,
        )
        assertEquals(GlassTier.T1_FIDELITY, r.tier)
        assertNull(r.downgradeReason)
        assertTrue(seen.isEmpty())

        // 省电/低性能（PerfTier.REDUCED 抽象）→ 退一档到 T2，具名 perf-tier-reduced
        now = 2000L
        r = resolver.resolve(
            requested = GlassTier.T1_FIDELITY,
            reduceMotion = false,
            perfTier = PerfTier.REDUCED,
            capability = ok(),
            frameRateDowngraded = false,
        )
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertEquals(GlassDowngradeReasons.PERF_TIER_REDUCED, r.downgradeReason)

        // 再叠加 Reduce Motion → 直接 T3，具名 reduce-motion（优先级最高）
        now = 3000L
        r = resolver.resolve(
            requested = GlassTier.T1_FIDELITY,
            reduceMotion = true,
            perfTier = PerfTier.REDUCED,
            capability = ok(),
            frameRateDowngraded = false,
        )
        assertEquals(GlassTier.T3_ESSENTIAL, r.tier)
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, r.downgradeReason)

        // 降级事件日志：只记档位变化，序列完整可查（当前档位可查询）
        assertEquals(2, seen.size)
        assertEquals(GlassTier.T1_FIDELITY, seen[0].from)
        assertEquals(GlassTier.T2_BALANCED, seen[0].to)
        assertEquals(GlassDowngradeReasons.PERF_TIER_REDUCED, seen[0].reason)
        assertEquals(2000L, seen[0].atMs)
        assertEquals(GlassTier.T2_BALANCED, seen[1].from)
        assertEquals(GlassTier.T3_ESSENTIAL, seen[1].to)
        assertEquals(MotionDowngradeReasons.REDUCE_MOTION, seen[1].reason)
        assertEquals(3000L, seen[1].atMs)
    }

    @Test
    fun `resolver is stateless per call - each resolve evaluates current conditions`() {
        val resolver = GlassTierResolver()
        // 恶劣条件 → T3（具名 perf-tier-essential）
        val bad = resolver.resolve(
            reduceMotion = false,
            perfTier = PerfTier.ESSENTIAL,
            capability = ok(),
            frameRateDowngraded = false,
        )
        assertEquals(GlassTier.T3_ESSENTIAL, bad.tier)
        assertEquals(MotionDowngradeReasons.PERF_TIER_ESSENTIAL, bad.downgradeReason)
        // 条件恢复 → 回到 T1（纯函数每次独立求值；运行时的"只降不升"
        // 由 FrameRateMonitor 的档位上限保证，不在本函数）
        val recovered = resolver.resolve(
            reduceMotion = false,
            perfTier = full(),
            capability = ok(),
            frameRateDowngraded = false,
        )
        assertEquals(GlassTier.T1_FIDELITY, recovered.tier)
        assertNull(recovered.downgradeReason)
    }

    @Test
    fun `frame rate downgrade is idempotent - repeated calls stay at t2 with one event`() {
        // resolveGlassTier 是纯函数：每次从 requested 重新求值，无跨调用记忆。
        // 持续低帧率下重复调用应幂等地停在 T2，且只记第一次档位变化。
        var now = 1000L
        val seen = mutableListOf<GlassDowngradeEvent>()
        val resolver = GlassTierResolver(clockMs = { now }, onDowngrade = { seen.add(it) })

        resolver.resolve(
            reduceMotion = false, perfTier = full(), capability = ok(),
            frameRateDowngraded = false,
        )
        // 持续低帧率：T1 → T2
        now = 2000L
        var r = resolver.resolve(
            reduceMotion = false, perfTier = full(), capability = ok(),
            frameRateDowngraded = true,
        )
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, r.downgradeReason)
        // 再调一次：仍是 T2（不累积到 T3），不记重复事件
        now = 3000L
        r = resolver.resolve(
            reduceMotion = false, perfTier = full(), capability = ok(),
            frameRateDowngraded = true,
        )
        assertEquals(GlassTier.T2_BALANCED, r.tier)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, r.downgradeReason)

        assertEquals(1, seen.size)
        assertEquals(GlassTier.T1_FIDELITY, seen[0].from)
        assertEquals(GlassTier.T2_BALANCED, seen[0].to)
        assertEquals(MotionDowngradeReasons.FRAME_RATE, seen[0].reason)
    }
}
