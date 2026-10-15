package com.xiaozhanggui.app.ui.motion

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 能力探测测试（Design System §2.3 / §5.1 具名失败思想）。
 *
 * - 低 API 返回 `Unsupported("<具名词>")`；高 API 返回 `Ok`
 * - **禁止裸 Boolean**：在 API 签名层面用反射断言返回类型是 [CapabilityResult]
 *   而非 boolean/Boolean；[CapabilityResult] 为 sealed，只有 Ok/Unsupported 两个子类型
 */
class CapabilityProbeTest {

    // ── probeGlassCapability ──

    @Test
    fun `glass probe on api 29 returns named unsupported`() {
        val result = probeGlassCapability(apiLevel = 29)
        assertTrue(result is CapabilityResult.Unsupported)
        assertEquals("no-backdrop-blur-on-api-29", (result as CapabilityResult.Unsupported).reason)
    }

    @Test
    fun `glass probe on api 30 returns named unsupported`() {
        val result = probeGlassCapability(apiLevel = 30) as CapabilityResult.Unsupported
        assertEquals("no-backdrop-blur-on-api-30", result.reason)
    }

    @Test
    fun `glass probe on api 31 returns ok`() {
        // RenderEffect（API 31+）可用 → T1 实时模糊能力成立
        assertEquals(CapabilityResult.Ok, probeGlassCapability(apiLevel = 31))
    }

    @Test
    fun `glass probe on api 35 returns ok`() {
        assertEquals(CapabilityResult.Ok, probeGlassCapability(apiLevel = 35))
    }

    @Test
    fun `glass probe without hardware acceleration returns named unsupported`() {
        val result = probeGlassCapability(apiLevel = 35, hardwareAccelerated = false)
        assertTrue(result is CapabilityResult.Unsupported)
        assertEquals(
            "glass-requires-hardware-acceleration",
            (result as CapabilityResult.Unsupported).reason,
        )
    }

    // ── probeTransitionCapability ──

    @Test
    fun `transition probe on api 29 without predictive back returns ok`() {
        // FADE / SHARED_ANCHOR 是 App 侧独立实现，始终可用
        assertEquals(CapabilityResult.Ok, probeTransitionCapability(apiLevel = 29))
    }

    @Test
    fun `transition probe predictive back on api 29 returns named unsupported`() {
        val result = probeTransitionCapability(apiLevel = 29, predictiveBackRequested = true)
        assertTrue(result is CapabilityResult.Unsupported)
        assertEquals(
            "predictive-back-unsupported-below-api-29",
            (result as CapabilityResult.Unsupported).reason,
        )
    }

    @Test
    fun `transition probe predictive back on api 33 returns ok`() {
        assertEquals(
            CapabilityResult.Ok,
            probeTransitionCapability(apiLevel = 33, predictiveBackRequested = true),
        )
    }

    @Test
    fun `transition probe without hardware acceleration returns named unsupported`() {
        val result = probeTransitionCapability(apiLevel = 35, hardwareAccelerated = false)
        assertTrue(result is CapabilityResult.Unsupported)
        assertEquals(
            "transition-requires-hardware-acceleration",
            (result as CapabilityResult.Unsupported).reason,
        )
    }

    // ── 禁止裸 Boolean：API 签名层面保证 ──

    @Test
    fun `probe functions do not return bare boolean`() {
        val facade = Class.forName("com.xiaozhanggui.app.ui.motion.CapabilityKt")
        val probes = facade.declaredMethods.filter {
            (it.name == "probeGlassCapability" || it.name == "probeTransitionCapability") &&
                !it.isSynthetic
        }
        assertTrue("应找到探测函数", probes.isNotEmpty())
        probes.forEach { method ->
            assertEquals(
                "探测函数 ${method.name} 必须返回 CapabilityResult，禁止裸 Boolean",
                CapabilityResult::class.java,
                method.returnType,
            )
            assertNotEquals(java.lang.Boolean.TYPE, method.returnType)
            assertNotEquals(java.lang.Boolean::class.java, method.returnType)
        }
    }

    @Test
    fun `capability result is sealed with exactly ok and unsupported`() {
        val nested = CapabilityResult::class.java.declaredClasses
            .map { it.simpleName }.toSet()
        assertEquals(setOf("Ok", "Unsupported"), nested)
    }

    @Test
    fun `unsupported carries a loggable named reason`() {
        val reason = "no-backdrop-blur-on-api-29"
        val unsupported = CapabilityResult.Unsupported(reason)
        assertEquals(reason, unsupported.reason)
        assertTrue(unsupported.reason.isNotBlank())
        // data class：同值相等，可直接写日志断言
        assertEquals(unsupported, CapabilityResult.Unsupported(reason))
    }
}
