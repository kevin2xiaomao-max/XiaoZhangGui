package com.xiaozhanggui.app.ui.poc.perf

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [PerfStats] 单元测试（V3.8 真机验收补强 · Worker 3）。
 *
 * 纯 JVM：百分位数学、掉帧率、判定口径。
 */
class PerfStatsTest {

    // ── percentileMs ──

    @Test
    fun `empty buckets percentile is NaN`() {
        assertTrue(PerfStats.percentileMs(emptyMap(), 50.0).isNaN())
    }

    @Test
    fun `single bucket returns its key`() {
        assertEquals(16.0, PerfStats.percentileMs(mapOf(16 to 100L), 50.0), 0.0)
        assertEquals(16.0, PerfStats.percentileMs(mapOf(16 to 100L), 95.0), 0.0)
        assertEquals(16.0, PerfStats.percentileMs(mapOf(16 to 100L), 100.0), 0.0)
    }

    @Test
    fun `nearest-rank percentile picks first bucket reaching rank`() {
        // N=100：p50 rank=50 → 桶16（累计90≥50）；p95 rank=95 → 桶17（累计100≥95）
        val buckets = mapOf(16 to 90L, 17 to 10L)
        assertEquals(16.0, PerfStats.percentileMs(buckets, 50.0), 0.0)
        assertEquals(17.0, PerfStats.percentileMs(buckets, 95.0), 0.0)
    }

    @Test
    fun `percentile is order independent of map iteration`() {
        val a = mapOf(20 to 5L, 16 to 90L, 17 to 5L)
        val b = mapOf(16 to 90L, 17 to 5L, 20 to 5L)
        assertEquals(
            PerfStats.percentileMs(a, 95.0),
            PerfStats.percentileMs(b, 95.0),
            0.0,
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `percentile rejects out of range p`() {
        PerfStats.percentileMs(mapOf(16 to 1L), 101.0)
    }

    // ── droppedCount ──

    @Test
    fun `dropped frames are those above 18_18ms`() {
        // 18ms 桶不计掉帧（≤18.18），19ms 桶计入
        val buckets = mapOf(16 to 80L, 18 to 10L, 19 to 7L, 33 to 3L)
        assertEquals(10L, PerfStats.droppedCount(buckets))
    }

    @Test
    fun `empty buckets drop zero`() {
        assertEquals(0L, PerfStats.droppedCount(emptyMap()))
    }

    // ── summarize / verdict ──

    @Test
    fun `empty buckets summarize to NO_DATA`() {
        val s = PerfStats.summarize("droplet", "PoC-1", emptyMap(), 6.0)
        assertEquals(PerfStats.Verdict.NO_DATA, s.verdict)
        assertEquals(0L, s.frameCount)
        assertTrue(s.p50Ms.isNaN())
        assertTrue(s.p95Ms.isNaN())
        assertEquals("droplet", s.stageId)
        assertEquals(6.0, s.durationSec, 0.0)
    }

    @Test
    fun `p95 within budget verdicts PASS`() {
        // 95% 帧 ≤18ms → p95=18 ≤ 18.18 → PASS；掉帧率 5%
        val buckets = mapOf(16 to 90L, 18 to 5L, 25 to 5L)
        val s = PerfStats.summarize("glass", "PoC-2", buckets, 6.0)
        assertEquals(100L, s.frameCount)
        assertEquals(16.0, s.p50Ms, 0.0)
        assertEquals(18.0, s.p95Ms, 0.0)
        assertEquals(5L, s.droppedFrames)
        assertEquals(0.05, s.dropRate, 1e-9)
        assertEquals(PerfStats.Verdict.PASS, s.verdict)
    }

    @Test
    fun `p95 above budget verdicts FAIL`() {
        // p95 rank=95 落在 25ms 桶 → FAIL
        val buckets = mapOf(16 to 80L, 17 to 10L, 25 to 10L)
        val s = PerfStats.summarize("morph", "PoC-3", buckets, 6.0)
        assertEquals(25.0, s.p95Ms, 0.0)
        assertEquals(PerfStats.Verdict.FAIL, s.verdict)
        assertEquals(0.10, s.dropRate, 1e-9)
    }

    @Test
    fun `frame budget constant is 1000 over 55`() {
        assertEquals(1000.0 / 55.0, PerfStats.FRAME_BUDGET_55FPS_MS, 1e-12)
        assertTrue(PerfStats.FRAME_BUDGET_55FPS_MS > 18.18)
        assertTrue(PerfStats.FRAME_BUDGET_55FPS_MS < 18.19)
    }
}
