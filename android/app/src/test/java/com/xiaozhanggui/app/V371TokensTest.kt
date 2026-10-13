package com.xiaozhanggui.app

import androidx.compose.ui.graphics.Color
import com.xiaozhanggui.app.ui.theme.MotionSurface
import com.xiaozhanggui.app.ui.theme.ResolvedMotion
import com.xiaozhanggui.app.ui.theme.v371.V371Colors
import com.xiaozhanggui.app.ui.theme.v371.V371Motion
import com.xiaozhanggui.app.ui.theme.v371.V371Radius
import com.xiaozhanggui.app.ui.theme.v371.V371Space
import com.xiaozhanggui.app.ui.theme.v371.V371Type
import com.xiaozhanggui.app.ui.theme.v371.v371DarkColors
import com.xiaozhanggui.app.ui.theme.v371.v371LightColors
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * V371 设计 token 回归测试（对应 iOS `V371DesignSystem.swift`）：
 * S0–S1 面色、状态色、字阶、间距、圆角、动效 token。
 */
class V371TokensTest {

    private val light = v371LightColors()
    private val dark = v371DarkColors()

    @Test
    fun `S0 canvas matches spec`() {
        assertEquals(Color(0xFFF4F4F7), light.canvas)
        assertEquals(Color(0xFF08080B), dark.canvas)
    }

    @Test
    fun `S1 group surfaces match spec`() {
        assertEquals(Color(0xFFFFFFFF), light.group)
        assertEquals(Color(0xFF1B1B20), dark.group)
        assertEquals(Color(0xFFF1F1F3), light.groupSecondary)
        assertEquals(Color(0xFF27272E), dark.groupSecondary)
    }

    @Test
    fun `S2 hero gradient blue only for weather sheet`() {
        assertEquals(Color(0xFF4A9CFF), light.heroTop)
        assertEquals(Color(0xFF2B6EF2), light.heroBottom)
        assertEquals(Color(0xFF2E61E0), dark.heroTop)
        assertEquals(Color(0xFF1C47B8), dark.heroBottom)
    }

    @Test
    fun `status colors match spec`() {
        assertEquals(Color(0xFF2E75F5), light.blue)
        assertEquals(Color(0xFF21A359), light.green)
        assertEquals(Color(0xFFE8910D), light.orange)
        assertEquals(Color(0xFFE6474D), light.red)
        assertEquals(Color(0xFFC99900), light.yellow)
        // Dark 提亮
        assertEquals(Color(0xFF5C9EFF), dark.blue)
        assertEquals(Color(0xFF4DC77A), dark.green)
        assertEquals(Color(0xFFFFA84D), dark.orange)
        assertEquals(Color(0xFFFF6B6B), dark.red)
        assertEquals(Color(0xFFFFCC59), dark.yellow)
    }

    @Test
    fun `tinted uses 13 percent alpha`() {
        val tinted: Color = light.tinted(light.blue)
        assertEquals(0.13f, tinted.alpha, 0.001f)
        assertEquals(light.blue.red, tinted.red, 0.001f)
        assertEquals(light.blue.green, tinted.green, 0.001f)
        assertEquals(light.blue.blue, tinted.blue, 0.001f)
    }

    @Test
    fun `V371Colors is a pure data palette`() {
        // 值语义：同参数构造相等
        assertEquals(v371LightColors(), light)
        assertEquals(v371DarkColors(), dark)
    }

    @Test
    fun `typography sizes match spec`() {
        assertEquals(44, V371Type.heroNumber.fontSize.value.toInt())
        assertEquals(15, V371Type.heroTitle.fontSize.value.toInt())
        assertEquals(17, V371Type.sectionTitle.fontSize.value.toInt())
        assertEquals(16, V371Type.rowTitle.fontSize.value.toInt())
        assertEquals(13, V371Type.rowSubtitle.fontSize.value.toInt())
        assertEquals(13, V371Type.time.fontSize.value.toInt())
        assertEquals(12, V371Type.badge.fontSize.value.toInt())
        assertEquals(12, V371Type.quickAction.fontSize.value.toInt())
    }

    @Test
    fun `spacing and radius match spec`() {
        assertEquals(16, V371Space.page.value.toInt())
        assertEquals(20, V371Space.section.value.toInt())
        assertEquals(12, V371Space.rowGap.value.toInt())
        assertEquals(14, V371Space.rowPadding.value.toInt())
        assertEquals(12, V371Radius.control.value.toInt())
        assertEquals(20, V371Radius.tile.value.toInt())
        assertEquals(24, V371Radius.group.value.toInt())
        assertEquals(28, V371Radius.hero.value.toInt())
    }

    @Test
    fun `motion tokens match iOS V371 Motion`() {
        assertEquals(100, V371Motion.INSTANT_MS)
        assertEquals(180, V371Motion.FAST_MS)
        assertEquals(280, V371Motion.STANDARD_MS)
        assertEquals(420, V371Motion.EMPHASIZED_MS)
        assertEquals(0.97f, V371Motion.PRESS_SCALE, 0.0001f)
    }

    @Test
    fun `motion resolve delegates to V32 resolve`() {
        // 对应 iOS V371.Motion.resolve → V32Motion.resolve
        assertEquals(ResolvedMotion.QUICK, V371Motion.resolve(MotionSurface.FADE, false))
        assertEquals(ResolvedMotion.SOFT_SPRING, V371Motion.resolve(MotionSurface.SPRING, false))
        assertEquals(ResolvedMotion.STANDARD, V371Motion.resolve(MotionSurface.NUMERIC, false))
        assertEquals(ResolvedMotion.QUICK, V371Motion.resolve(MotionSurface.FADE, true))
        assertEquals(ResolvedMotion.QUICK, V371Motion.resolve(MotionSurface.SPRING, true))
        assertEquals(ResolvedMotion.NONE, V371Motion.resolve(MotionSurface.NUMERIC, true))
    }
}
