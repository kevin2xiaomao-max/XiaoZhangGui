package com.xiaozhanggui.app.ui.poc.perf

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [PerfIntervalStats] 单元测试（V3.8 口径审计 · Worker B）。
 *
 * 纯 JVM：帧间隔差分、百分位、卡顿率、fps 换算、判定口径。
 */
class PerfIntervalStatsTest {

    /** 生成恒定间隔的 frameTimeNanos 序列：n 个点，间隔 intervalNs。 */
    private fun constantFrameTimes(n: Int, intervalNs: Long): List<Long> =
        List(n) { i -> i * intervalNs }

    // ── intervalsNs ──

    @Test
    fun `constant 16_6ms sequence yields constant intervals`() {
        val times = constantFrameTimes(61, 16_600_000L)
        val intervals = PerfIntervalStats.intervalsNs(times)
        assertEquals(60, intervals.size)
        assertTrue(intervals.all { it == 16_600_000L })
    }

    @Test
    fun `intervals filter out non-positive and over-1s gaps`() {
        // t: 0, 16.6ms, 16.6ms(重复→0), 10ms(倒退→负), 16.6ms+2s(>1s断档)
        val times = listOf(0L, 16_600_000L, 16_600_000L, 10_000_000L, 2_016_600_000L)
        val intervals = PerfIntervalStats.intervalsNs(times)
        assertEquals(listOf(16_600_000L), intervals)
    }

    @Test
    fun `empty and single-point sequences yield no intervals`() {
        assertTrue(PerfIntervalStats.intervalsNs(emptyList()).isEmpty())
        assertTrue(PerfIntervalStats.intervalsNs(listOf(123L)).isEmpty())
    }

    // ── percentileMs ──

    @Test
    fun `percentile on empty is NaN`() {
        assertTrue(PerfIntervalStats.percentileMs(emptyList(), 50.0).isNaN())
    }

    @Test
    fun `nearest-rank percentile over raw ns values`() {
        // 100 个 16.6ms + 5 个 33.3ms：p50→16.6，p95→16.6（rank=100），p100→33.3
        val intervals = List(100) { 16_600_000L } + List(5) { 33_300_000L }
        assertEquals(16.6, PerfIntervalStats.percentileMs(intervals, 50.0), 1e-9)
        assertEquals(16.6, PerfIntervalStats.percentileMs(intervals, 95.0), 1e-9)
        assertEquals(33.3, PerfIntervalStats.percentileMs(intervals, 100.0), 1e-9)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `percentile rejects out of range p`() {
        PerfIntervalStats.percentileMs(listOf(16_600_000L), 101.0)
    }

    // ── fpsFromMedianIntervalMs ──

    @Test
    fun `constant 16_6ms median converts to about 60fps`() {
        val intervals = PerfIntervalStats.intervalsNs(constantFrameTimes(61, 16_600_000L))
        val median = PerfIntervalStats.percentileMs(intervals, 50.0)
        val fps = PerfIntervalStats.fpsFromMedianIntervalMs(median)
        assertEquals(60.0, fps, 0.5) // 1000/16.6 ≈ 60.24
    }

    // ── jankCount ──

    @Test
    fun `injected janks are counted above 2x vsync`() {
        // vsync 16.67ms(60Hz) → 卡顿阈值 33.33ms；注入 3 个 50ms
        val intervals = List(97) { 16_600_000L } + List(3) { 50_000_000L }
        val jank = PerfIntervalStats.jankCount(intervals, vsyncExpectedMs = 1000.0 / 60.0)
        assertEquals(3L, jank)
        assertEquals(0.03, 3.0 / 100, 1e-9)
    }

    @Test
    fun `no jank when all intervals within 2x vsync`() {
        val intervals = List(100) { 16_600_000L }
        assertEquals(0L, PerfIntervalStats.jankCount(intervals, 1000.0 / 60.0))
    }

    // ── summarize 判定口径 ──

    @Test
    fun `constant 16_6ms passes 55fps on interval p95`() {
        val s = PerfIntervalStats.summarize(
            "droplet", "PoC-1 液滴菜单",
            constantFrameTimes(361, 16_600_000L), 6.0, 60.0,
        )
        assertEquals(PerfIntervalStats.Verdict.PASS, s.verdict)
        assertEquals(360, s.intervalCount)
        assertEquals(0.0, s.jankRate, 1e-9)
        assertEquals(60.0, s.fpsMedian, 0.5)
    }

    @Test
    fun `intervals with p95 above 18_18ms fail`() {
        // 90 个 16.6ms + 10 个 25ms：p95 rank=95 → 25ms > 18.18 → FAIL
        val intervals = List(90) { 16_600_000L } + List(10) { 25_000_000L }
        var t = 0L
        val times = intervals.map { dt -> t.also { t += dt } } + t
        val s = PerfIntervalStats.summarize("glass", "PoC-2 玻璃三档", times, 6.0, 60.0)
        assertEquals(PerfIntervalStats.Verdict.FAIL, s.verdict)
        // 25ms < 2×16.67ms=33.3ms，不算卡顿
        assertEquals(0L, s.jankCount)
    }

    @Test
    fun `empty sequence is NO_DATA`() {
        val s = PerfIntervalStats.summarize("morph", "PoC-3 连续形变", emptyList(), 6.0, 60.0)
        assertEquals(PerfIntervalStats.Verdict.NO_DATA, s.verdict)
        assertTrue(s.p50Ms.isNaN())
        assertTrue(s.p95Ms.isNaN())
        assertTrue(s.jankRate.isNaN())
        assertTrue(s.fpsMedian.isNaN())
        assertEquals(0, s.intervalCount)
    }

    @Test
    fun `single point is NO_DATA`() {
        val s = PerfIntervalStats.summarize("morph", "PoC-3 连续形变", listOf(999L), 6.0, 60.0)
        assertEquals(PerfIntervalStats.Verdict.NO_DATA, s.verdict)
        assertEquals(1, s.frameCount)
        assertEquals(0, s.intervalCount)
    }

    @Test
    fun `non-positive refresh rate falls back to 60Hz assumption`() {
        val s = PerfIntervalStats.summarize(
            "droplet", "PoC-1 液滴菜单",
            constantFrameTimes(61, 16_600_000L), 6.0, refreshRateHz = 0.0,
        )
        assertTrue(s.assumedRefreshRate)
        assertEquals(60.0, s.refreshRateHz, 1e-9)
        assertEquals(PerfIntervalStats.Verdict.PASS, s.verdict)
    }

    @Test
    fun `real refresh rate is kept and not marked assumed`() {
        val s = PerfIntervalStats.summarize(
            "droplet", "PoC-1 液滴菜单",
            constantFrameTimes(61, 8_300_000L), 6.0, refreshRateHz = 120.0,
        )
        assertTrue(!s.assumedRefreshRate)
        assertEquals(120.0, s.refreshRateHz, 1e-9)
        assertEquals(PerfIntervalStats.Verdict.PASS, s.verdict)
        assertEquals(120.0, s.fpsMedian, 1.0)
    }

    @Test
    fun `severe jank rate is computed against 2x vsync`() {
        // 60Hz 下注入 5 个 50ms（>33.33ms）→ 卡顿率 5%
        val intervals = List(95) { 16_600_000L } + List(5) { 50_000_000L }
        var t = 0L
        val times = intervals.map { dt -> t.also { t += dt } } + t
        val s = PerfIntervalStats.summarize("droplet", "PoC-1", times, 6.0, 60.0)
        assertEquals(5L, s.jankCount)
        assertEquals(0.05, s.jankRate, 1e-9)
    }
}
