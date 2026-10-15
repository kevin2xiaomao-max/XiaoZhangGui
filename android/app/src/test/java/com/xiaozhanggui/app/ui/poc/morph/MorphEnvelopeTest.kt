package com.xiaozhanggui.app.ui.poc.morph

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-3 连续形变包络测试（Roadmap §3 PoC-3 合入标准）。
 *
 * - 过冲仅一次、幅度 <3%；
 * - 动画结束 200ms 后圆角/裁切回到 token 标准值；
 * - 无快照残留（反射断言 [MorphRuntimeState] 无 Bitmap 字段）。
 */
class MorphEnvelopeTest {

    // ── 圆角包络 ──

    @Test
    fun `corner bulge is zero at rest and peaks mid-motion`() {
        assertEquals(0f, MorphEnvelope.cornerBulge(0f), 0f)
        assertEquals(0f, MorphEnvelope.cornerBulge(1f), 0f)
        assertEquals(1f, MorphEnvelope.cornerBulge(0.5f), 1e-6f)
        val mid = MorphEnvelope.cornerBulge(0.25f)
        assertTrue(mid > 0f && mid < 1f)
    }

    @Test
    fun `corner bulge is symmetric and monotonic on each half`() {
        assertEquals(
            MorphEnvelope.cornerBulge(0.3f),
            MorphEnvelope.cornerBulge(0.7f),
            1e-6f,
        )
        assertTrue(MorphEnvelope.cornerBulge(0.4f) > MorphEnvelope.cornerBulge(0.2f))
    }

    // ── 前缘锥度 ──

    @Test
    fun `leading taper is zero at rest and positive mid-motion`() {
        assertEquals(0f, MorphEnvelope.leadingTaperT(0f), 0f)
        assertEquals(0f, MorphEnvelope.leadingTaperT(1f), 0f)
        assertTrue(MorphEnvelope.leadingTaperT(0.5f) > 0f)
    }

    // ── 末段一次过冲（<3%）──

    @Test
    fun `overshoot happens exactly once and stays below 3 percent`() {
        val n = 200
        val values = FloatArray(n + 1) { i -> MorphEnvelope.overshootScale(i / n.toFloat()) }
        var peaks = 0
        var max = 1f
        for (i in 1 until n) {
            if (values[i] > values[i - 1] && values[i] > values[i + 1]) peaks++
            if (values[i] > max) max = values[i]
        }
        assertEquals(1, peaks)
        assertTrue(max <= 1.03f)
        assertEquals(1.025f, max, 1e-4f)
    }

    @Test
    fun `overshoot is exactly one at both ends`() {
        assertEquals(1f, MorphEnvelope.overshootScale(0f), 0f)
        assertEquals(1f, MorphEnvelope.overshootScale(1f), 0f)
    }

    // ── 稳定态 200ms 后回到 token ──

    @Test
    fun `temp morph is released exactly 200ms after animation ends`() {
        val token = 24f // V371Radius.group 换算（px），调用方传入
        assertFalse(MorphEnvelope.shouldReleaseTempMorph(0L))
        assertFalse(MorphEnvelope.shouldReleaseTempMorph(199L))
        assertTrue(MorphEnvelope.shouldReleaseTempMorph(200L))
        assertTrue(MorphEnvelope.shouldReleaseTempMorph(10_000L))
    }

    @Test
    fun `released value returns token exactly after 200ms, null before`() {
        val token = 24f
        assertNull(MorphEnvelope.releasedValue(0L, token))
        assertNull(MorphEnvelope.releasedValue(199L, token))
        assertEquals(token, MorphEnvelope.releasedValue(200L, token)!!, 0f)
        assertEquals(token, MorphEnvelope.releasedValue(5_000L, token)!!, 0f)
    }

    // ── 无快照残留 ──

    @Test
    fun `runtime state holds no bitmap or snapshot fields`() {
        val bitmapFields = MorphRuntimeState::class.java.declaredFields
            .filter { it.type.simpleName.contains("Bitmap", ignoreCase = true) }
            .map { it.name }
        assertTrue(
            "MorphRuntimeState must not hold snapshots/bitmaps, found: $bitmapFields",
            bitmapFields.isEmpty(),
        )
    }

    // ── 运行时状态辅助 ──

    @Test
    fun `drag progress is normalized and clamped`() {
        val s = MorphRuntimeState(dragOffsetPx = 80f, dragMaxPx = 160f)
        assertEquals(0.5f, s.dragProgress, 1e-6f)
        val over = MorphRuntimeState(dragOffsetPx = 500f, dragMaxPx = 160f)
        assertEquals(1f, over.dragProgress, 0f)
    }

    @Test
    fun `drag direction indicates the leading edge`() {
        assertEquals(1, MorphRuntimeState(dragOffsetPx = 10f).dragDirection)
        assertEquals(-1, MorphRuntimeState(dragOffsetPx = -10f).dragDirection)
        assertEquals(0, MorphRuntimeState(dragOffsetPx = 0f).dragDirection)
    }
}
