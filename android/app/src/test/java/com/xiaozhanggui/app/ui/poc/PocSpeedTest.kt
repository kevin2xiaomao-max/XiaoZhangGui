package com.xiaozhanggui.app.ui.poc

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * PoC 全局速度控制器测试（V3.8 PoC 测试菜单增强）。
 *
 * [PocSpeed] 为进程级单例：每个用例结束强制复位 NORMAL，避免用例间
 * 顺序依赖。
 */
class PocSpeedTest {

    @After
    fun resetSpeed() {
        PocSpeed.mode = PocSpeedMode.NORMAL
    }

    @Test
    fun `normal mode scale is identity`() {
        PocSpeed.mode = PocSpeedMode.NORMAL
        assertEquals(280, PocSpeed.scale(280))
        assertEquals(100, PocSpeed.scale(100))
        assertEquals(420, PocSpeed.scale(420))
    }

    @Test
    fun `slow mode scales duration by four`() {
        PocSpeed.mode = PocSpeedMode.SLOW
        // 280ms（Phase C 纵向档）→ 1120ms；与各屏既有慢放口径一致
        assertEquals(1120, PocSpeed.scale(280))
        assertEquals(400, PocSpeed.scale(100))
        assertEquals(1680, PocSpeed.scale(420))
        assertEquals(880, PocSpeed.scale(220))
    }

    @Test
    fun `scale boundary non-positive durations return as-is`() {
        PocSpeed.mode = PocSpeedMode.SLOW
        // 零/非法时长不放大：避免把"无动画"变成动画
        assertEquals(0, PocSpeed.scale(0))
        assertEquals(-5, PocSpeed.scale(-5))
        PocSpeed.mode = PocSpeedMode.NORMAL
        assertEquals(0, PocSpeed.scale(0))
    }

    @Test
    fun `scale is consistent across mode switches`() {
        assertEquals(280, PocSpeed.scale(280))
        PocSpeed.mode = PocSpeedMode.SLOW
        assertEquals(1120, PocSpeed.scale(280))
        PocSpeed.mode = PocSpeedMode.NORMAL
        assertEquals(280, PocSpeed.scale(280))
    }

    @Test
    fun `modeForQuery maps slow and normal`() {
        assertEquals(PocSpeedMode.SLOW, PocSpeed.modeForQuery("slow"))
        assertEquals(PocSpeedMode.NORMAL, PocSpeed.modeForQuery("normal"))
    }

    @Test
    fun `modeForQuery returns null for missing or illegal values`() {
        // 缺省/非法 → null（导航层保持当前档，不重置）
        assertNull(PocSpeed.modeForQuery(null))
        assertNull(PocSpeed.modeForQuery(""))
        assertNull(PocSpeed.modeForQuery("fast"))
        // 大小写敏感：锁定行为（与 ai mode=voice 口径一致）
        assertNull(PocSpeed.modeForQuery("SLOW"))
    }

    @Test
    fun `slow factor constant is four`() {
        assertEquals(4, PocSpeed.SLOW_FACTOR)
        assertEquals(4, PocSpeedMode.SLOW.factor)
        assertEquals(1, PocSpeedMode.NORMAL.factor)
    }
}
