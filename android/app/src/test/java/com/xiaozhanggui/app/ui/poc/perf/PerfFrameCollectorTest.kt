package com.xiaozhanggui.app.ui.poc.perf

import android.app.Activity
import android.util.SparseIntArray
import androidx.core.app.FrameMetricsAggregator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * [PerfFrameCollector] 回归测试（V3.8 P0 真机根因：下标误用）。
 *
 * Robolectric（真实 `android.util.SparseIntArray`，零反射）：
 * - `extractTotalBuckets`：`getMetrics()` 形态数组（index0 = TOTAL_INDEX，
 *   其余下标 null/其它指标）→ 只读下标 0 的分桶；
 * - 生命周期：[CollectOutcome]/[CollectReason] 五种失败原因全覆盖
 *   （伪造 [PerfFrameCollector.CollectorBackend]，不碰真机窗口）。
 *
 * 根因背景（AOSP）：`FrameMetricsAggregator(TOTAL_DURATION)` 的构造器参数
 * 是 bit flag（TOTAL_DURATION = 1）；`getMetrics()` 数组按 `*_INDEX` 下标
 * 寻址（TOTAL_INDEX = 0）。旧代码 `getOrNull(TOTAL_DURATION)` 读下标 1 →
 * 恒 null → 真机 0 帧。本测试在旧下标下为红，修下标后为绿。
 */
@RunWith(RobolectricTestRunner::class)
// 锁定 API 35（与 app targetSdk 一致）：
// 无 @Config 时 DefaultSdkPicker 会回退到 API 21，导致 android-all 解析漂移。
@Config(sdk = [35])
class PerfFrameCollectorTest {

    // ── extractTotalBuckets：TOTAL_INDEX 下标 ──

    @Test
    fun `TOTAL_INDEX constant is zero`() {
        // 构造器 bit flag TOTAL_DURATION = 1 不可作下标——锁死该认知。
        assertEquals(0, FrameMetricsAggregator.TOTAL_INDEX)
        assertEquals(1, FrameMetricsAggregator.TOTAL_DURATION)
    }

    @Test
    fun `extract reads TOTAL bucket at index 0`() {
        val totals = SparseIntArray().apply {
            put(16, 90)
            put(33, 10)
        }
        // 只启用 TOTAL_DURATION 的形态：index0 有数据，其余下标 null。
        val metrics = arrayOf<SparseIntArray?>(
            totals, null, null, null, null, null, null, null, null,
        )
        assertEquals(
            mapOf(16 to 90L, 33 to 10L),
            PerfFrameCollector.extractTotalBuckets(metrics),
        )
    }

    @Test
    fun `extract ignores buckets at other indexes`() {
        val totals = SparseIntArray().apply { put(16, 5) }
        val other = SparseIntArray().apply { put(16, 999) }
        val metrics = arrayOf<SparseIntArray?>(totals, other)
        assertEquals(mapOf(16 to 5L), PerfFrameCollector.extractTotalBuckets(metrics))
    }

    @Test
    fun `extract with null metrics returns empty`() {
        assertTrue(PerfFrameCollector.extractTotalBuckets(null).isEmpty())
    }

    @Test
    fun `extract with missing total index returns empty`() {
        // 下标 0 无数据（数组过短 / 该位 null）→ 空 map，stop() 据此判 INDEX_MISSING。
        assertTrue(PerfFrameCollector.extractTotalBuckets(emptyArray()).isEmpty())
        assertTrue(
            PerfFrameCollector.extractTotalBuckets(arrayOfNulls<SparseIntArray?>(4)).isEmpty(),
        )
    }

    // ── 生命周期：CollectOutcome ──

    private fun activity(): Activity =
        Robolectric.buildActivity(Activity::class.java).setup().get()

    private class FakeSource(
        private val metrics: Array<SparseIntArray?>?,
        private val snapshotThrows: Boolean = false,
    ) : PerfFrameCollector.MetricsSource {
        var released = false
            private set

        override fun snapshot(): Array<SparseIntArray?>? {
            if (snapshotThrows) throw RuntimeException("fake snapshot failure")
            return metrics
        }

        override fun release() {
            released = true
        }
    }

    private class FakeBackend(
        private val source: FakeSource?,
        private val attachThrows: Boolean = false,
    ) : PerfFrameCollector.CollectorBackend {
        override fun attach(activity: Activity): PerfFrameCollector.MetricsSource {
            if (attachThrows) throw RuntimeException("fake attach failure")
            return source ?: throw AssertionError("no fake source configured")
        }
    }

    @Test
    fun `ok path returns buckets`() {
        val source = FakeSource(arrayOf(SparseIntArray().apply { put(16, 42) }))
        val collector = PerfFrameCollector(FakeBackend(source))
        assertTrue(collector.start(activity()))
        assertEquals(
            CollectOutcome.Ok(mapOf(16 to 42L)),
            collector.stop(),
        )
        assertTrue(source.released)
    }

    @Test
    fun `start exception then stop yields START_EXCEPTION`() {
        val collector = PerfFrameCollector(FakeBackend(source = null, attachThrows = true))
        assertFalse(collector.start(activity()))
        assertEquals(
            CollectOutcome.Failed(CollectReason.START_EXCEPTION),
            collector.stop(),
        )
    }

    @Test
    fun `null metrics yields METRICS_NULL`() {
        val collector = PerfFrameCollector(FakeBackend(FakeSource(metrics = null)))
        assertTrue(collector.start(activity()))
        assertEquals(
            CollectOutcome.Failed(CollectReason.METRICS_NULL),
            collector.stop(),
        )
    }

    @Test
    fun `missing total index yields INDEX_MISSING`() {
        val collector = PerfFrameCollector(
            FakeBackend(FakeSource(arrayOfNulls<SparseIntArray?>(4))),
        )
        assertTrue(collector.start(activity()))
        assertEquals(
            CollectOutcome.Failed(CollectReason.INDEX_MISSING),
            collector.stop(),
        )
    }

    @Test
    fun `empty total bucket yields ZERO_FRAMES`() {
        val collector = PerfFrameCollector(
            FakeBackend(FakeSource(arrayOf(SparseIntArray()))),
        )
        assertTrue(collector.start(activity()))
        assertEquals(
            CollectOutcome.Failed(CollectReason.ZERO_FRAMES),
            collector.stop(),
        )
    }

    @Test
    fun `snapshot exception yields STOP_EXCEPTION`() {
        val collector = PerfFrameCollector(
            FakeBackend(FakeSource(metrics = null, snapshotThrows = true)),
        )
        assertTrue(collector.start(activity()))
        assertEquals(
            CollectOutcome.Failed(CollectReason.STOP_EXCEPTION),
            collector.stop(),
        )
    }

    @Test
    fun `stop without start yields METRICS_NULL`() {
        // 从未 start：无采集源、亦无 start 失败粘滞 → METRICS_NULL。
        val collector = PerfFrameCollector()
        assertEquals(
            CollectOutcome.Failed(CollectReason.METRICS_NULL),
            collector.stop(),
        )
    }
}
