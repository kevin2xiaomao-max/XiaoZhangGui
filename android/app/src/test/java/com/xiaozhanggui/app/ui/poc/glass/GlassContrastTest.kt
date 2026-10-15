package com.xiaozhanggui.app.ui.poc.glass

import androidx.compose.ui.graphics.Color
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-2：对比度守恒（Design System §2.1）。
 *
 * - 三档底色不透明度严格单调递增（T1 < T2 < T3）；
 * - 同一文字在三档下的对比度落在同一区间
 *   （极差 ≤ 1.5 且每档 ≥ 4.5，WARM_CREAM 实际色板）；
 * - WCAG 公式回归（黑/白 = 21）。
 */
class GlassContrastTest {

    @Test
    fun `overlay alpha is strictly increasing t1 to t3`() {
        val t1 = GlassContrast.overlayAlpha.getValue(GlassTier.T1_FIDELITY)
        val t2 = GlassContrast.overlayAlpha.getValue(GlassTier.T2_BALANCED)
        val t3 = GlassContrast.overlayAlpha.getValue(GlassTier.T3_ESSENTIAL)
        assertTrue("T1($t1) < T2($t2)", t1 < t2)
        assertTrue("T2($t2) < T3($t3)", t2 < t3)
    }

    @Test
    fun `wcag black on white is 21`() {
        assertEquals(21.0, GlassContrast.contrastRatio(Color.Black, Color.White), 0.01)
    }

    @Test
    fun `effective background at alpha 1 is overlay and at 0 is backdrop`() {
        val backdrop = Color(0xFFF4F1E8)
        val overlay = Color.White
        val full = GlassContrast.effectiveBackground(backdrop, overlay, 1f)
        assertEquals(255, (full.red * 255).roundToInt())
        assertEquals(255, (full.green * 255).roundToInt())
        assertEquals(255, (full.blue * 255).roundToInt())
        val none = GlassContrast.effectiveBackground(backdrop, overlay, 0f)
        assertEquals(0xF4, (none.red * 255).roundToInt())
        assertEquals(0xF1, (none.green * 255).roundToInt())
        assertEquals(0xE8, (none.blue * 255).roundToInt())
    }

    @Test
    fun `same text three tiers stay in same band on light`() {
        // WARM_CREAM Light 实际色板：pageBG / overlay 白 / textPrimary
        val contrasts = GlassTier.values().map { tier ->
            GlassContrast.tierContrast(
                tier = tier,
                text = Color(0xFF232623),
                backdrop = Color(0xFFF4F1E8),
                overlay = Color.White,
            )
        }
        contrasts.forEach { assertTrue("contrast $it < 4.5", it >= GlassContrast.MIN_CONTRAST) }
        assertTrue(
            "spread ${contrasts.max() - contrasts.min()} > 1.5: $contrasts",
            GlassContrast.isSameBand(contrasts),
        )
    }

    @Test
    fun `same text three tiers stay in same band on dark`() {
        // WARM_CREAM Dark 实际色板：pageBG / overlay 深 surface / textPrimary
        val contrasts = GlassTier.values().map { tier ->
            GlassContrast.tierContrast(
                tier = tier,
                text = Color(0xFFF2F0E9),
                backdrop = Color(0xFF16181A),
                overlay = Color(0xFF232A26),
            )
        }
        contrasts.forEach { assertTrue("contrast $it < 4.5", it >= GlassContrast.MIN_CONTRAST) }
        assertTrue(
            "spread ${contrasts.max() - contrasts.min()} > 1.5: $contrasts",
            GlassContrast.isSameBand(contrasts),
        )
    }

    @Test
    fun `isSameBand rejects wide spread`() {
        assertFalse(GlassContrast.isSameBand(listOf(4.5, 7.0)))
    }

    @Test
    fun `isSameBand rejects below minimum contrast`() {
        assertFalse(GlassContrast.isSameBand(listOf(3.0, 3.2, 3.1)))
    }

    @Test
    fun `isSameBand rejects empty`() {
        assertFalse(GlassContrast.isSameBand(emptyList()))
    }
}
