package com.xiaozhanggui.app

import com.xiaozhanggui.app.ui.theme.MotionSurface
import com.xiaozhanggui.app.ui.theme.ResolvedMotion
import com.xiaozhanggui.app.ui.theme.XzgMotion
import com.xiaozhanggui.app.ui.theme.resolveMotion
import com.xiaozhanggui.app.ui.theme.v371.V371Motion
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

    @Test
    fun `V371Motion resolve mirrors resolveMotion without reduce motion`() {
        // Phase 3：V371Motion.resolve(..., reduceMotion=false) 必须与底层一致
        assertEquals(ResolvedMotion.QUICK, V371Motion.resolve(MotionSurface.FADE, false))
        assertEquals(ResolvedMotion.SOFT_SPRING, V371Motion.resolve(MotionSurface.SPRING, false))
        assertEquals(ResolvedMotion.STANDARD, V371Motion.resolve(MotionSurface.NUMERIC, false))
    }

    @Test
    fun `V371Motion resolve mirrors resolveMotion with reduce motion`() {
        // Phase 3：V371Motion.resolve(..., reduceMotion=true) 退化分支
        assertEquals(ResolvedMotion.QUICK, V371Motion.resolve(MotionSurface.FADE, true))
        assertEquals(ResolvedMotion.QUICK, V371Motion.resolve(MotionSurface.SPRING, true))
        assertEquals(ResolvedMotion.NONE, V371Motion.resolve(MotionSurface.NUMERIC, true))
    }
}
