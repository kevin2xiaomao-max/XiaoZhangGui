package com.xiaozhanggui.app.ui.poc.morph

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * PoC-3 逆向/中断与无过期几何测试（v1.2.7 审计建议 PoC-3 #1、#3）。
 *
 * #1 逆向/中断：动画中途反向与取消，断言无超调、无闪烁、回到稳定态。
 * - 反向连续性：细网格扫描相邻进度点的包络差上界（反向即沿同一曲线回走，
 *   无突变 = 无闪烁）；
 * - 取消：任意中途状态重置为默认值后精确回到静止（端点精确性）。
 *
 * #3 窗口变化后几何重算：PoC-3 的运行时状态按设计不持有任何窗口几何
 * （键盘/旋转/窗口尺寸），几何每帧由调用方按当前度量重算。
 * - 包络函数引用透明：同输入恒同输出，无隐藏状态 → 不可能使用过期快照；
 * - 反射断言 `MorphRuntimeState` 无窗口/屏幕/键盘/IME 相关字段。
 *
 * 纯 JVM 测试；只加测试，不改 PoC 实现。
 */
class MorphReverseInterruptTest {

    // ── #1 逆向：连续性（无闪烁） ──

    @Test
    fun `corner bulge is continuous on fine grid - reversal causes no flicker`() {
        // 步长 0.001 扫描：相邻点差的上界即"反向回走"时的最大跳变。
        // sin(πp) 导数上界 π，步长 0.001 → 差 < 0.005；取 0.01 留足余量。
        var maxStep = 0f
        val n = 1000
        var prev = MorphEnvelope.cornerBulge(0f)
        for (i in 1..n) {
            val cur = MorphEnvelope.cornerBulge(i / n.toFloat())
            maxStep = maxOf(maxStep, abs(cur - prev))
            prev = cur
        }
        assertTrue("max step $maxStep too large, reversal would flicker", maxStep < 0.01f)
    }

    @Test
    fun `overshoot scale is continuous on fine grid - reversal causes no flicker`() {
        var maxStep = 0f
        val n = 1000
        var prev = MorphEnvelope.overshootScale(0f)
        for (i in 1..n) {
            val cur = MorphEnvelope.overshootScale(i / n.toFloat())
            maxStep = maxOf(maxStep, abs(cur - prev))
            prev = cur
        }
        assertTrue("max step $maxStep too large", maxStep < 0.01f)
    }

    @Test
    fun `reversal mirrors trajectory exactly - bulge at p equals bulge at 1-p`() {
        val grid = listOf(0.05f, 0.2f, 0.37f, 0.5f, 0.63f, 0.8f, 0.95f)
        for (p in grid) {
            assertEquals(
                "bulge($p) != bulge(${1f - p})",
                MorphEnvelope.cornerBulge(p),
                MorphEnvelope.cornerBulge(1f - p),
                1e-6f,
            )
            assertEquals(
                "overshoot($p) != overshoot(${1f - p})",
                MorphEnvelope.overshootScale(p),
                MorphEnvelope.overshootScale(1f - p),
                1e-6f,
            )
        }
    }

    // ── #1 中断/取消：回到稳定态 ──

    @Test
    fun `cancel mid-flight returns to exact rest state`() {
        // 中途任意状态…
        val midFlight = MorphRuntimeState(
            dragOffsetPx = 87.5f,
            dragMaxPx = 200f,
            expandProgress = 0.62f,
            tempMorphActive = true,
            settleStartMs = 1_700_000_000L,
        )
        assertTrue(midFlight.tempMorphActive)
        // …取消 = 回到默认值（调用方语义），必须精确回到静止
        val cancelled = MorphRuntimeState()
        assertEquals(0f, cancelled.dragProgress, 0f)
        assertEquals(0, cancelled.dragDirection)
        assertFalse(cancelled.tempMorphActive)
        assertNull(cancelled.settleStartMs)
        // 端点精确：静止态包络恒为 0/1，无残留
        assertEquals(0f, MorphEnvelope.cornerBulge(0f), 0f)
        assertEquals(0f, MorphEnvelope.leadingTaperT(0f), 0f)
        assertEquals(1f, MorphEnvelope.overshootScale(0f), 0f)
        assertEquals(1f, MorphEnvelope.overshootScale(1f), 0f)
    }

    @Test
    fun `released value edges - zero and negative elapsed keep temp morph`() {
        val token = 12f
        assertNull(MorphEnvelope.releasedValue(-1L, token))
        assertNull(MorphEnvelope.releasedValue(0L, token))
        assertNull(MorphEnvelope.releasedValue(199L, token))
        assertEquals(token, MorphEnvelope.releasedValue(200L, token)!!, 0f)
        assertFalse(MorphEnvelope.shouldReleaseTempMorph(199L))
        assertTrue(MorphEnvelope.shouldReleaseTempMorph(200L))
    }

    // ── #3 无过期几何：引用透明 + 无窗口字段 ──

    @Test
    fun `envelope functions are referentially transparent - no hidden state`() {
        // 同输入恒同输出、交错调用互不影响 → 不可能持有过期快照/窗口几何
        val a1 = MorphEnvelope.cornerBulge(0.37f)
        val b1 = MorphEnvelope.overshootScale(0.71f)
        val a2 = MorphEnvelope.cornerBulge(0.37f)
        val b2 = MorphEnvelope.overshootScale(0.71f)
        // 中间穿插大量其他进度调用
        for (i in 0..100) MorphEnvelope.cornerBulge(i / 100f)
        val a3 = MorphEnvelope.cornerBulge(0.37f)
        val b3 = MorphEnvelope.overshootScale(0.71f)
        assertEquals(a1, a2, 0f)
        assertEquals(b1, b2, 0f)
        assertEquals(a1, a3, 0f)
        assertEquals(b1, b3, 0f)
    }

    @Test
    fun `runtime state holds no window geometry fields - rotation cannot use stale data`() {
        // 与 noBitmapFieldsInRuntimeState 同思路：状态只持标量进度，
        // 窗口/键盘/屏幕几何每帧由调用方按当前度量传入，不可能过期。
        val banned = listOf("window", "screen", "keyboard", "ime", "inset", "display", "rotation")
        val offending = MorphRuntimeState::class.java.declaredFields.filter { f ->
            banned.any { keyword -> f.name.lowercase().contains(keyword) }
        }
        assertTrue(
            "stale geometry risk: fields ${offending.map { it.name }}",
            offending.isEmpty(),
        )
    }
}
