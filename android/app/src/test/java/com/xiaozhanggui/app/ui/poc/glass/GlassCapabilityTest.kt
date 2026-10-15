package com.xiaozhanggui.app.ui.poc.glass

import com.xiaozhanggui.app.ui.motion.CapabilityResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-2：T1 档能力探测分支（具名失败原因断言）。
 *
 * 复用 Phase 1 `probeGlassCapability` 的 API/硬件加速判定（原因原样透传），
 * PoC-2 追加低内存分支。
 */
class GlassCapabilityTest {

    @Test
    fun `api 35 full capability is Ok`() {
        assertEquals(CapabilityResult.Ok, probeGlassTierCapability(apiLevel = 35))
    }

    @Test
    fun `api 31 boundary is Ok`() {
        assertEquals(CapabilityResult.Ok, probeGlassTierCapability(apiLevel = 31))
    }

    @Test
    fun `api 29 unsupported with named reason`() {
        val result = probeGlassTierCapability(apiLevel = 29)
        assertTrue(result is CapabilityResult.Unsupported)
        assertEquals(
            "no-backdrop-blur-on-api-29",
            (result as CapabilityResult.Unsupported).reason,
        )
    }

    @Test
    fun `low memory unsupported with named reason`() {
        val result = probeGlassTierCapability(apiLevel = 35, lowMemory = true)
        assertTrue(result is CapabilityResult.Unsupported)
        assertEquals(
            "glass-low-memory-device",
            (result as CapabilityResult.Unsupported).reason,
        )
    }

    @Test
    fun `no hardware acceleration unsupported with named reason`() {
        val result = probeGlassTierCapability(apiLevel = 35, hardwareAccelerated = false)
        assertTrue(result is CapabilityResult.Unsupported)
        assertEquals(
            "glass-requires-hardware-acceleration",
            (result as CapabilityResult.Unsupported).reason,
        )
    }
}
