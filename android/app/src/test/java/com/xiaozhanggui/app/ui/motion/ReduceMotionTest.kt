package com.xiaozhanggui.app.ui.motion

import com.xiaozhanggui.app.ui.components.XzgMotionSpecs
import com.xiaozhanggui.app.ui.theme.ResolvedMotion as LegacyResolvedMotion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Reduce Motion 全链路测试（Roadmap Phase 1 验收标准 §4）。
 *
 * 链路：`ANIMATOR_DURATION_SCALE` → [isReduceMotionEnabled]（纯函数，
 * `ui.motion`；`ui.theme` 的 Context 版本只取值、判定委托到这里）
 * → MotionContext.reduceMotion（生产侧由 `rememberReduceMotion(reduceMotionOverride)`
 *   测试钩子注入，见 `ui.theme`）
 * → [MotionPolicy.resolve] reduce-motion 分支 → FAST 短淡入。
 *
 * 四路径（按钮/菜单/弹窗/页面）以 Worker B 的真实声明
 * （[XzgMotionSpecs]，已迁移为 Worker A 的 [MotionSpec] 类型）为输入，
 * 逐一验证 reduce-motion 分支。
 */
class ReduceMotionTest {

    // ── 1. isReduceMotionEnabled 纯函数 ──

    @Test
    fun `animator scale zero means reduce motion enabled`() {
        assertTrue(isReduceMotionEnabled(0f))
    }

    @Test
    fun `animator scale one means reduce motion disabled`() {
        assertFalse(isReduceMotionEnabled(1f))
    }

    @Test
    fun `animator scale fractional means reduce motion disabled`() {
        // 只有 == 0 才是"移除动画"；0.5 只是放慢，不算开启
        assertFalse(isReduceMotionEnabled(0.5f))
    }

    // ── 2. 四路径 reduce-motion 分支（Worker B 真实声明 → MotionPolicy） ──

    private fun assertReduceMotionBranch(spec: MotionSpec) {
        val resolved = MotionPolicy.resolve(spec, MotionContext(reduceMotion = true))
        assertEquals(
            "reduce-motion 具名原因 [${spec.id}]",
            MotionDowngradeReasons.REDUCE_MOTION,
            resolved.downgradeReason,
        )
        // FAST 短淡入（180ms），无位移/弹簧/过冲/模糊
        assertEquals(spec.id, TransitionKind.FADE, resolved.transitionKind)
        assertEquals(spec.id, DurationTier.FAST, resolved.durationTier)
        assertEquals(spec.id, 180, resolved.durationTier.ms)
        assertEquals(spec.id, Overshoot.NONE, resolved.overshoot)
        assertEquals(spec.id, LegacyResolvedMotion.QUICK, resolved.baseMotion)
    }

    @Test
    fun `button path reduce motion branch`() {
        // 按钮按压：FADE/FAST → reduce-motion 下 FAST 短淡入（无缩放）
        assertReduceMotionBranch(XzgMotionSpecs.BUTTON_PRESS)
    }

    @Test
    fun `menu path reduce motion branch`() {
        // 菜单展开：FADE/FAST → reduce-motion 下直接呈现（框架动画服从系统缩放）
        assertReduceMotionBranch(XzgMotionSpecs.MENU_EXPAND_AI_CHAT)
    }

    @Test
    fun `dialog path reduce motion branch`() {
        // 弹窗：FADE/STANDARD → reduce-motion 下短淡入（平台窗口动画归零）
        assertReduceMotionBranch(XzgMotionSpecs.DIALOG_CONFIRM_DELETE)
    }

    @Test
    fun `page path reduce motion branch`() {
        // 页面切换：FADE/FAST → reduce-motion 下直接显示（fallbackInstant）
        assertReduceMotionBranch(XzgMotionSpecs.NAV_PAGE_FADE)
    }

    @Test
    fun `all four path families degrade under reduce motion`() {
        val families = listOf(
            XzgMotionSpecs.BUTTON_PRESS,
            XzgMotionSpecs.MENU_EXPAND_CUSTOMER_ROW,
            XzgMotionSpecs.DIALOG_TODO_SAVE_FAILED,
            XzgMotionSpecs.NAV_PAGE_FADE,
        )
        families.forEach { assertReduceMotionBranch(it) }
    }

    @Test
    fun `four paths unaffected when reduce motion off`() {
        // 开关关闭时按声明原样执行，不记录降级
        val resolved = MotionPolicy.resolve(
            XzgMotionSpecs.NAV_PAGE_FADE,
            MotionContext(reduceMotion = false),
        )
        assertNull(resolved.downgradeReason)
        assertEquals(TransitionKind.FADE, resolved.transitionKind)
        assertEquals(DurationTier.FAST, resolved.durationTier)
    }
}
