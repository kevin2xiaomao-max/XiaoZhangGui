package com.xiaozhanggui.app.ui.motion

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 能力探测：返回具名失败原因（非 Boolean），reason 可直接写日志。
 */
class CapabilityProbeTest {

    @Test
    fun `glass capability ok on api 31 plus`() {
        assertEquals(CapabilityResult.Ok, probeGlassCapability(apiLevel = 31))
        assertEquals(CapabilityResult.Ok, probeGlassCapability(apiLevel = 35))
    }

    @Test
    fun `glass capability names api level on old devices`() {
        val r = probeGlassCapability(apiLevel = 29)
        assertTrue(r is CapabilityResult.Unsupported)
        assertEquals("no-backdrop-blur-on-api-29", (r as CapabilityResult.Unsupported).reason)
    }

    @Test
    fun `glass capability names missing hardware acceleration`() {
        val r = probeGlassCapability(apiLevel = 35, hardwareAccelerated = false)
        assertEquals(
            "glass-requires-hardware-acceleration",
            (r as CapabilityResult.Unsupported).reason,
        )
    }

    @Test
    fun `transition capability ok for app-driven transitions`() {
        // FADE / SHARED_ANCHOR 是 App 侧独立实现，不依赖平台能力
        assertEquals(CapabilityResult.Ok, probeTransitionCapability(apiLevel = 29))
    }

    @Test
    fun `transition capability names missing predictive back`() {
        val r = probeTransitionCapability(
            apiLevel = 32,
            predictiveBackRequested = true,
        )
        assertEquals(
            "predictive-back-unsupported-below-api-32",
            (r as CapabilityResult.Unsupported).reason,
        )
        assertEquals(
            CapabilityResult.Ok,
            probeTransitionCapability(apiLevel = 33, predictiveBackRequested = true),
        )
    }

    @Test
    fun `transition capability names missing hardware acceleration`() {
        val r = probeTransitionCapability(apiLevel = 35, hardwareAccelerated = false)
        assertEquals(
            "transition-requires-hardware-acceleration",
            (r as CapabilityResult.Unsupported).reason,
        )
    }
}
