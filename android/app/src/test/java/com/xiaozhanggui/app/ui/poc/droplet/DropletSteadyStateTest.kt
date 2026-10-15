package com.xiaozhanggui.app.ui.poc.droplet

import com.xiaozhanggui.app.ui.theme.v371.V371Radius
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * PoC-1 稳定态几何一致性：展开结束（p=1）时面板几何 == 标准 token。
 *
 * 对应 Paparazzi `Poc_droplet_steady` 截图的代码级断言：
 * 截图看像素，这里断言数值——圆角插值 t=1 → 目标圆角精确等于
 * [V371Radius.group]，无中间态残留。
 */
class DropletSteadyStateTest {

    @Test
    fun `steady state corner radius equals group token exactly`() {
        val anchorR = 12f // px（V371Radius.control 换算，调用方传入）
        val targetToken = V371Radius.group.value // 24dp
        val t = DropletPhases.cornerT(1f)
        assertEquals(1f, t, 0f)
        val radiusPx = anchorR + (targetToken - anchorR) * t
        assertEquals(targetToken, radiusPx, 1e-6f)
    }

    @Test
    fun `steady state panel is at full target geometry`() {
        val p = 1f
        // 中心回到目标中心（moveProgress=1 → lerp 系数 1）
        assertEquals(1f, DropletPhases.moveProgress(p), 0f)
        // 尺寸回到目标尺寸
        assertEquals(1f, DropletPhases.heightFraction(p), 0f)
        assertEquals(1f, DropletPhases.widthFraction(p), 0f)
        // 无缩放残留、无透明度残留、无锥度残留
        assertEquals(1f, DropletPhases.anchorScale(p), 0f)
        assertEquals(1f, DropletPhases.panelOvershoot(p), 0f)
        assertEquals(1f, DropletPhases.contentAlpha(p), 0f)
        assertEquals(1f, DropletPhases.surfaceAlpha(p), 0f)
        assertEquals(0f, DropletPhases.leadingTaperT(p), 0f)
    }

    @Test
    fun `collapsed state is pure rest - no phantom geometry`() {
        val p = 0f
        assertEquals(1f, DropletPhases.anchorScale(p), 0f)
        assertEquals(0f, DropletPhases.cornerT(p), 0f)
        assertEquals(0f, DropletPhases.contentAlpha(p), 0f)
        assertEquals(0f, DropletPhases.surfaceAlpha(p), 0f)
        assertEquals(1f, DropletPhases.panelOvershoot(p), 0f)
        assertEquals(0f, DropletPhases.heightFraction(p), 0f)
        assertEquals(0f, DropletPhases.widthFraction(p), 0f)
    }
}
