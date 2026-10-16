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
    fun `parse coloros major from display with oppo build-id form`() {
        // 真机形态：OPPO 官方构建串为"型号_版本(地区)"，无 ColorOS/V 标记
        //（P0 真机修复：PKJ110 / ColorOS 17 的 Build.DISPLAY 即此形态）。
        assertEquals(17, parseColorOsMajorVersion("PKJ110_17.0.0.201(CN01)"))
        assertEquals(15, parseColorOsMajorVersion("CPH2581_15.0.0.601(EX01)"))
    }

    @Test
    fun `parse returns null for aosp-style build id with long components`() {
        // AOSP 形态长分量（240905/015）不是 ColorOS 版本，必须诚实返回 null。
        assertNull(parseColorOsMajorVersion("AP3A.240905.015.A1"))
    }

    @Test
    fun `parse falls back to versionIncremental when display has no version marker`() {
        assertEquals(
            17,
            parseColorOsMajorVersion("AP3A.240905.015.A1", "V17.0.1"),
        )
        assertEquals(
            17,
            parseColorOsMajorVersion(null, "PKJ110_17.0.0.201(CN01)"),
        )
    }

    @Test
    fun `display takes precedence over versionIncremental`() {
        // DISPLAY 是设置"版本号"显示的构建号，冲突时以它为准。
        assertEquals(
            15,
            parseColorOsMajorVersion("CPH2581_15.0.0.601(EX01)", "V17.0.1"),
        )
    }

    @Test
    fun `hash-like versionIncremental is ignored`() {
        // 部分机型 INCREMENTAL 放构建哈希而非版本串：非版本形态不得误解析。
        assertNull(parseColorOsMajorVersion("AP3A.240905.015.A1", "1474513791"))
        assertNull(parseColorOsMajorVersion("AP3A.240905.015.A1", "eng.root.20161222.224308"))
    }

    @Test
    fun `explicit marker wins over build-id form within the same source`() {
        // 同一来源内：显式标记（V15）优先于构建号形态（_17.0.0），返回 15 而非 17。
        assertEquals(15, parseColorOsMajorVersion("V15 CPH2581_17.0.0.601(EX01)"))
    }

    @Test
    fun `parse returns null for implausible multi-digit major`() {
        // V177 不是真实 ColorOS 版本：不截断猜测，诚实返回 null。
        assertNull(parseColorOsMajorVersion("V177.0"))
    }

    @Test
    fun `parse coloros major returns null when unreadable`() {
        assertNull(parseColorOsMajorVersion(null))
        assertNull(parseColorOsMajorVersion(""))
        assertNull(parseColorOsMajorVersion("random-build-string"))
        assertNull(parseColorOsMajorVersion(null, null))
        assertNull(parseColorOsMajorVersion("", "   "))
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
    fun `coloros 17 yields ok for oppo build-id display without marker`() {
        // 真机形态：PKJ110 / ColorOS 17 的 Build.DISPLAY 无 ColorOS/V 标记
        //（P0 修复前此处为 UNAVAILABLE · coloros-version-unparseable）。
        val items = probeOplusTransitions(baseEnv().copy(buildDisplay = "PKJ110_17.0.0.201(CN01)"))
        assertEquals(CapabilityResult.Ok, itemById(items, "coloros-version").result)
    }

    @Test
    fun `coloros 17 yields ok via versionIncremental fallback`() {
        val items = probeOplusTransitions(
            baseEnv().copy(buildDisplay = "AP3A.240905.015.A1", versionIncremental = "V17.0.1"),
        )
        assertEquals(CapabilityResult.Ok, itemById(items, "coloros-version").result)
    }

    @Test
    fun `unreadable requires both display and incremental blank`() {
        val items = probeOplusTransitions(
            baseEnv().copy(buildDisplay = null, versionIncremental = null),
        )
        assertEquals("coloros-version-unreadable", reasonOf(items, "coloros-version"))
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
