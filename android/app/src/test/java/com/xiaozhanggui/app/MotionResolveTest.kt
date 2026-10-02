package com.xiaozhanggui.app

import com.xiaozhanggui.app.ui.theme.MotionSurface
import com.xiaozhanggui.app.ui.theme.ResolvedMotion
import com.xiaozhanggui.app.ui.theme.XzgMotion
import com.xiaozhanggui.app.ui.theme.resolveMotion
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 动效 token 回归测试。对应 iOS `V32Motion`：
 * 时长/弹簧参数 1:1，Reduce Motion 降级走 [resolveMotion] 纯函数。
 */
class MotionResolveTest {

    @Test
    fun `duration tokens match iOS V32Motion`() {
        assertEquals(180, XzgMotion.QUICK_MS)
        assertEquals(280, XzgMotion.STANDARD_MS)
        assertEquals(420, XzgMotion.SLOW_MS)
        assertEquals(120, XzgMotion.REDUCED_FADE_MS)
    }

    @Test
    fun `resolve without reduce motion`() {
        // 对应 iOS resolve(_:reduceMotion:false)：fade→quick / spring→softSpring / numeric→standard
        assertEquals(ResolvedMotion.QUICK, resolveMotion(MotionSurface.FADE, false))
        assertEquals(ResolvedMotion.SOFT_SPRING, resolveMotion(MotionSurface.SPRING, false))
        assertEquals(ResolvedMotion.STANDARD, resolveMotion(MotionSurface.NUMERIC, false))
    }

    @Test
    fun `resolve with reduce motion degrades to short fade`() {
        // 对应 iOS resolve(_:reduceMotion:true)：无位移/无弹簧；fade/spring→quick 短淡入；numeric→none（直接终值）
        assertEquals(ResolvedMotion.QUICK, resolveMotion(MotionSurface.FADE, true))
        assertEquals(ResolvedMotion.QUICK, resolveMotion(MotionSurface.SPRING, true))
        assertEquals(ResolvedMotion.NONE, resolveMotion(MotionSurface.NUMERIC, true))
    }
}
