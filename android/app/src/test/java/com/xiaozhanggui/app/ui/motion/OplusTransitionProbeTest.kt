package com.xiaozhanggui.app.ui.motion

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-4 转场能力探测测试（Design System §1.5 / §5.2 具名失败思想）。
 *
 * - 每个探测分支断言具名原因（`CapabilityResult.Unsupported.reason`），禁止裸 boolean；
 * - 探测项 id 稳定（进探测报告）；
 * - 每个探测项的降级链声明恒为 `"FADE"`（公开 API 等效路径）。
 */
class OplusTransitionProbeTest {

    private fun baseEnv() = OplusProbeEnv(
        apiLevel = 35,
        manufacturer = "OPPO",
        buildDisplay = "PKJ110_ColorOS V17.0",
        classPresent = OPLUS_CLASS_CANDIDATES_UNVERIFIED.associateWith { true },
        predictiveBackSystemEnabled = true,
        windowMode = OplusWindowMode.NORMAL,
        hardwareAccelerated = true,
    )

    private fun itemById(items: List<OplusProbeItem>, id: String): OplusProbeItem =
        items.first { it.id == id }

    private fun reasonOf(items: List<OplusProbeItem>, id: String): String? =
        (itemById(items, id).result as? CapabilityResult.Unsupported)?.reason

    // ── parseColorOsMajorVersion ──

    @Test
    fun `parse coloros major from display with ColorOS marker`() {
        assertEquals(17, parseColorOsMajorVersion("PKJ110_ColorOS V17.0"))
    }

    @Test
    fun `parse coloros major from display with bare V marker`() {
        assertEquals(15, parseColorOsMajorVersion("CPH2581_V15.0.0"))
    }

    @Test
    fun `parse coloros major returns null when unreadable`() {
        assertNull(parseColorOsMajorVersion(null))
        assertNull(parseColorOsMajorVersion(""))
        assertNull(parseColorOsMajorVersion("random-build-string"))
    }

    // ── 全 Ok 基线 ──

    @Test
    fun `all-ok baseline on oplus coloros17 device`() {
        val items = probeOplusTransitions(baseEnv())
        val failed = items.filter { it.result is CapabilityResult.Unsupported }
        assertTrue("expected all Ok, failed=${failed.map { it.id }}", failed.isEmpty())
    }

    @Test
    fun `every item declares FADE fallback`() {
        for (item in probeOplusTransitions(baseEnv())) {
            assertEquals("item ${item.id}", "FADE", item.fallback)
        }
    }

    @Test
    fun `probe item ids are stable and cover all seven groups`() {
        val ids = probeOplusTransitions(baseEnv()).map { it.id }
        assertTrue(ids.contains("hardware-acceleration"))
        assertTrue(ids.contains("api-level"))
        assertTrue(ids.contains("device-family"))
        assertTrue(ids.contains("coloros-version"))
        assertTrue(ids.any { it.startsWith("oplus-class:") })
        assertTrue(ids.contains("predictive-back"))
        assertTrue(ids.contains("window-mode"))
    }

    // ── hardware-acceleration ──

    @Test
    fun `no hardware acceleration yields named unsupported`() {
        val items = probeOplusTransitions(baseEnv().copy(hardwareAccelerated = false))
        assertEquals(
            "transition-requires-hardware-acceleration",
            reasonOf(items, "hardware-acceleration"),
        )
    }

    // ── api-level ──

    @Test
    fun `api 29 yields oplus-api-level-below-33`() {
        val items = probeOplusTransitions(baseEnv().copy(apiLevel = 29))
        assertEquals("oplus-api-level-below-33", reasonOf(items, "api-level"))
    }

    @Test
    fun `api 33 yields ok`() {
        val items = probeOplusTransitions(baseEnv().copy(apiLevel = 33))
        assertEquals(CapabilityResult.Ok, itemById(items, "api-level").result)
    }

    // ── device-family ──

    @Test
    fun `oneplus and realme are oplus family`() {
        for (maker in listOf("OnePlus", "REALME", "oppo")) {
            val items = probeOplusTransitions(baseEnv().copy(manufacturer = maker))
            assertEquals(
                "maker=$maker",
                CapabilityResult.Ok,
                itemById(items, "device-family").result,
            )
        }
    }

    @Test
    fun `non-oplus manufacturer yields not-oplus-family-device`() {
        val items = probeOplusTransitions(baseEnv().copy(manufacturer = "Google"))
        assertEquals("not-oplus-family-device", reasonOf(items, "device-family"))
    }

    // ── coloros-version ──

    @Test
    fun `unreadable build display yields coloros-version-unreadable`() {
        val items = probeOplusTransitions(baseEnv().copy(buildDisplay = null))
        assertEquals("coloros-version-unreadable", reasonOf(items, "coloros-version"))
    }

    @Test
    fun `unparseable build display yields coloros-version-unparseable`() {
        val items = probeOplusTransitions(baseEnv().copy(buildDisplay = "some-oem-build"))
        assertEquals("coloros-version-unparseable", reasonOf(items, "coloros-version"))
    }

    @Test
    fun `coloros 15 yields coloros-below-17`() {
        val items = probeOplusTransitions(baseEnv().copy(buildDisplay = "CPH2581_ColorOS V15.0"))
        assertEquals("coloros-below-17", reasonOf(items, "coloros-version"))
    }

    @Test
    fun `coloros 17 yields ok`() {
        val items = probeOplusTransitions(baseEnv().copy(buildDisplay = "PKJ110_ColorOS V17.0.1"))
        assertEquals(CapabilityResult.Ok, itemById(items, "coloros-version").result)
    }

    // ── oplus-class ──

    @Test
    fun `missing candidate class yields oplus-class-missing with simple name`() {
        val items = probeOplusTransitions(baseEnv().copy(classPresent = emptyMap()))
        for (candidate in OPLUS_CLASS_CANDIDATES_UNVERIFIED) {
            val simple = candidate.substringAfterLast('.')
            assertEquals(
                "oplus-class-missing:$simple",
                reasonOf(items, "oplus-class:$simple"),
            )
        }
    }

    @Test
    fun `present candidate class yields ok`() {
        val items = probeOplusTransitions(baseEnv())
        for (candidate in OPLUS_CLASS_CANDIDATES_UNVERIFIED) {
            val simple = candidate.substringAfterLast('.')
            assertEquals(
                CapabilityResult.Ok,
                itemById(items, "oplus-class:$simple").result,
            )
        }
    }

    // ── predictive-back ──

    @Test
    fun `predictive back below api 33 yields named unsupported`() {
        val items = probeOplusTransitions(baseEnv().copy(apiLevel = 32))
        assertEquals(
            "predictive-back-unsupported-below-api-33",
            reasonOf(items, "predictive-back"),
        )
    }

    @Test
    fun `predictive back disabled by system yields named unsupported`() {
        val items = probeOplusTransitions(
            baseEnv().copy(apiLevel = 35, predictiveBackSystemEnabled = false),
        )
        assertEquals("predictive-back-disabled-by-system", reasonOf(items, "predictive-back"))
    }

    @Test
    fun `predictive back unknown system state yields named unsupported not guessed ok`() {
        // 无公开 API 可读系统开关时必须诚实标 unknown，禁止猜测为可用。
        val items = probeOplusTransitions(
            baseEnv().copy(apiLevel = 35, predictiveBackSystemEnabled = null),
        )
        val result = itemById(items, "predictive-back").result
        assertTrue(result is CapabilityResult.Unsupported)
        assertEquals(
            "predictive-back-system-state-unknown",
            (result as CapabilityResult.Unsupported).reason,
        )
    }

    @Test
    fun `predictive back enabled yields ok`() {
        val items = probeOplusTransitions(
            baseEnv().copy(apiLevel = 35, predictiveBackSystemEnabled = true),
        )
        assertEquals(CapabilityResult.Ok, itemById(items, "predictive-back").result)
    }

    // ── window-mode ──

    @Test
    fun `freeform window yields named unsupported`() {
        val items = probeOplusTransitions(baseEnv().copy(windowMode = OplusWindowMode.FREEFORM))
        assertEquals(
            "window-mode-freeform-no-gesture-transition",
            reasonOf(items, "window-mode"),
        )
    }

    @Test
    fun `pip window yields named unsupported`() {
        val items = probeOplusTransitions(baseEnv().copy(windowMode = OplusWindowMode.PIP))
        assertEquals(
            "window-mode-pip-no-gesture-transition",
            reasonOf(items, "window-mode"),
        )
    }

    @Test
    fun `normal window yields ok`() {
        val items = probeOplusTransitions(baseEnv().copy(windowMode = OplusWindowMode.NORMAL))
        assertEquals(CapabilityResult.Ok, itemById(items, "window-mode").result)
    }

    // ── 结构：禁止裸 boolean ──

    @Test
    fun `probe results are CapabilityResult not boolean`() {
        for (item in probeOplusTransitions(baseEnv())) {
            assertTrue(
                "item ${item.id} must be CapabilityResult",
                item.result is CapabilityResult,
            )
            assertNotNull(item.id)
        }
    }
}
