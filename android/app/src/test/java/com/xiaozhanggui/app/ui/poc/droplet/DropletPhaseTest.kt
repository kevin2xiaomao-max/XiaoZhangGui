package com.xiaozhanggui.app.ui.poc.droplet

import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.ANCHOR_MIN_SCALE
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.CONTENT_END
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.CONTENT_START
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.CORNER_END
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.CORNER_START
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.HEIGHT_END
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.HEIGHT_START
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.OVERSHOOT_AMPLITUDE
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.OVERSHOOT_END
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.OVERSHOOT_START
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.SHRINK_END
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases.WIDTH_START
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-1 六层相位顺序测试（Design System §2.2 + 反例清单）。
 *
 * 全部纯函数断言：相位边界精确（`phaseProgress` 窗口外钳制 0/1），
 * 慢放逐帧核验的顺序关系在此先行锁定。
 */
class DropletPhaseTest {

    // ── Phase B：收缩 ⊗ 位移同起 ──

    @Test
    fun `shrink and move start together`() {
        // t=0 之后极小进度：收缩已开始（scale<1）且位移已开始（move>0）
        assertTrue(DropletPhases.anchorScale(0.05f) < 1f)
        assertTrue(DropletPhases.moveProgress(0.05f) > 0f)
    }

    @Test
    fun `anti-pattern - move does not wait for shrink to finish`() {
        // 反例"收缩播完才开始位移" ⇔ moveProgress 在收缩窗口内恒为 0
        assertTrue(DropletPhases.moveProgress(SHRINK_END / 2f) > 0f)
        assertEquals(1f, DropletPhases.anchorScale(0f), 0f)
        assertEquals(0f, DropletPhases.moveProgress(0f), 0f)
    }

    @Test
    fun `anchor shrinks to 0_96 then holds`() {
        assertEquals(ANCHOR_MIN_SCALE, DropletPhases.anchorScale(SHRINK_END), 1e-6f)
        assertEquals(ANCHOR_MIN_SCALE, DropletPhases.anchorScale(0.5f), 1e-6f)
    }

    // ── Phase C：高度先行 ──

    @Test
    fun `width lags height by quarter phase`() {
        assertEquals(0.25f, WIDTH_START - HEIGHT_START, 0.01f)
    }

    @Test
    fun `height reaches 90 percent while width still lags`() {
        // p=0.6：纵向 ≥90%，横向明显滞后（高度先行可观测）
        assertTrue(DropletPhases.heightFraction(0.6f) >= 0.9f)
        assertTrue(DropletPhases.widthFraction(0.6f) < 0.5f)
    }

    @Test
    fun `longitudinal expansion uses STANDARD tier`() {
        // 纵向展开总时长 = STANDARD 280ms（V371 时长档，不分叉）
        assertEquals(
            com.xiaozhanggui.app.ui.motion.DurationTier.STANDARD,
            DropletSpecs.MENU_EXPAND.durationTier,
        )
        assertEquals(280, DropletSpecs.MENU_EXPAND.durationTier.ms)
    }

    // ── Phase D：圆角延迟插值 ──

    @Test
    fun `corner interpolation delayed by one third of height phase`() {
        val delay = (CORNER_START - HEIGHT_START) / (HEIGHT_END - HEIGHT_START)
        assertEquals(1f / 3f, delay, 0.05f)
    }

    @Test
    fun `cornerT is zero before its window and one at the end`() {
        assertEquals(0f, DropletPhases.cornerT(0.2f), 0f)
        assertEquals(1f, DropletPhases.cornerT(1f), 0f)
        assertEquals(1f, DropletPhases.cornerT(CORNER_END), 0f)
    }

    // ── Phase E：内容 1/4–3/4 淡入 ──

    @Test
    fun `anti-pattern - content never appears before geometry expands`() {
        assertEquals(0f, DropletPhases.contentAlpha(0f), 0f)
        assertEquals(0f, DropletPhases.contentAlpha(CONTENT_START - 0.01f), 0f)
    }

    @Test
    fun `content fades in across the 1-4 to 3-4 window`() {
        assertEquals(0f, DropletPhases.contentAlpha(CONTENT_START), 0f)
        val mid = DropletPhases.contentAlpha(0.5f)
        assertTrue(mid > 0f && mid < 1f)
        assertEquals(1f, DropletPhases.contentAlpha(CONTENT_END), 0f)
        assertEquals(1f, DropletPhases.contentAlpha(0.9f), 0f)
    }

    // ── Phase F：末段一次过冲 + 锚点回归 + 释放 ──

    @Test
    fun `overshoot happens exactly once and stays below 3 percent`() {
        // 200 采样点找局部极大值：必须恰好 1 个
        val n = 200
        val values = FloatArray(n + 1) { i ->
            DropletPhases.panelOvershoot(
                OVERSHOOT_START + (OVERSHOOT_END - OVERSHOOT_START) * i / n,
            )
        }
        var peaks = 0
        var max = 1f
        for (i in 1 until n) {
            if (values[i] > values[i - 1] && values[i] > values[i + 1]) peaks++
            if (values[i] > max) max = values[i]
        }
        assertEquals(1, peaks)
        assertTrue(max <= 1.03f)
        assertEquals(1f + OVERSHOOT_AMPLITUDE, max, 1e-4f)
    }

    @Test
    fun `overshoot is exactly one at both ends of its window`() {
        assertEquals(1f, DropletPhases.panelOvershoot(OVERSHOOT_START), 0f)
        assertEquals(1f, DropletPhases.panelOvershoot(1f), 0f)
    }

    @Test
    fun `anchor returns to exactly 1 at the end`() {
        assertEquals(1f, DropletPhases.anchorScale(1f), 0f)
    }

    // ── 稳定态：释放临时形变 ──

    @Test
    fun `steady state releases all temporary morphs`() {
        val p = 1f
        assertEquals(1f, DropletPhases.anchorScale(p), 0f)
        assertEquals(1f, DropletPhases.cornerT(p), 0f)
        assertEquals(1f, DropletPhases.contentAlpha(p), 0f)
        assertEquals(1f, DropletPhases.surfaceAlpha(p), 0f)
        assertEquals(1f, DropletPhases.panelOvershoot(p), 0f)
        assertEquals(1f, DropletPhases.heightFraction(p), 0f)
        assertEquals(1f, DropletPhases.widthFraction(p), 0f)
        assertEquals(1f, DropletPhases.moveProgress(p), 0f)
        assertEquals(0f, DropletPhases.leadingTaperT(p), 0f)
    }

    @Test
    fun `leading taper is zero at rest and peaks mid-motion`() {
        assertEquals(0f, DropletPhases.leadingTaperT(0f), 0f)
        assertEquals(0f, DropletPhases.leadingTaperT(1f), 0f)
        assertTrue(DropletPhases.leadingTaperT(0.45f) > 0f)
    }
}
