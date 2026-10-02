package com.xiaozhanggui.app.ui.theme

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.ui.unit.IntOffset

/**
 * V32 动效。对应 iOS `DesignSystem/V32/V32Motion.swift`。
 *
 * iOS 参数说明：
 * - quick 0.18 / standard 0.28 / slow 0.42（easeOut）
 * - softSpring(0.35, 0.86)：SwiftUI spring(response: 0.35, dampingFraction: 0.86)
 * - interactiveSpring(0.28, 0.82)：spring(response: 0.28, dampingFraction: 0.82)
 * - reducedFade 0.12
 *
 * Compose spring 用 dampingRatio + stiffness 描述；stiffness 由 response 近似：
 * stiffness ≈ (2π / response)² → 0.35s ≈ 322，0.28s ≈ 503。
 * Reduce Motion 时调用方应改用 [reducedFadeSpec]（淡入替代位移/弹簧），
 * 并检查系统无障碍设置（V32Motion.resolve 对应逻辑在 Phase 5 接入）。
 */
object XzgMotion {
    const val QUICK_MS = 180
    const val STANDARD_MS = 280
    const val SLOW_MS = 420
    const val REDUCED_FADE_MS = 120

    fun <T> quick() = tween<T>(QUICK_MS)
    fun <T> standard() = tween<T>(STANDARD_MS)
    fun <T> slow() = tween<T>(SLOW_MS)

    /** softSpring：dampingRatio 0.86，stiffness ≈ 320 */
    fun <T> softSpring() = spring<T>(
        dampingRatio = 0.86f,
        stiffness = 320f
    )

    /** interactiveSpring：dampingRatio 0.82，stiffness ≈ 500 */
    fun <T> interactiveSpring() = spring<T>(
        dampingRatio = 0.82f,
        stiffness = 500f
    )

    /** Reduce Motion 降级：直切淡入 */
    fun <T> reducedFade() = tween<T>(REDUCED_FADE_MS)

    /** 默认弹簧（未指定时用 softSpring） */
    fun <T> defaultSpring() = spring<T>(
        dampingRatio = Spring.DampingRatioNoBouncy,
        stiffness = Spring.StiffnessMediumLow
    )
}

/** 位移淡入组合（与 iOS V32PressButtonStyle 按压缩放 0.98 对应，Compose 侧用 scale 修饰符实现） */
const val PRESS_SCALE = 0.98f
const val PRESS_ALPHA = 0.82f

/** 动效表面分类，对应 iOS `V32Motion.Surface`：crossfade / 弹簧位移 / 数字滚动。 */
enum class MotionSurface {
    /** 短淡入 / crossfade（普通切换、状态淡入） */
    FADE,
    /** 弹簧 / 位移类（展开、卡片状态变化） */
    SPRING,
    /** 数字滚动类（numericText 金额、进度数值） */
    NUMERIC
}

/** 解析后的动效选择（值语义，可单测）。对应 iOS `V32Motion.Resolved`。 */
enum class ResolvedMotion {
    QUICK, STANDARD, SLOW, SOFT_SPRING, INTERACTIVE_SPRING, NONE
}

/**
 * 按系统「减弱动态效果」开关解析应使用的动效。对应 iOS `V32Motion.resolve`（纯函数，可单测）：
 * - reduceMotion 为 true：无位移、无弹簧、无明显 scale；fade/spring 统一退化为短淡入，
 *   numeric 直接替换终值（NONE → 调用方立即应用终值，不做动画）。
 * - reduceMotion 为 false：fade→quick，spring→softSpring，numeric→standard。
 *
 * 注意：调用方需自行读取系统无障碍设置（Settings.Global.ANIMATOR_DURATION_SCALE == 0
 * 或 AccessibilityManager.isReducedMotion 等）并传入；集中接线待后续 Phase。
 */
fun resolveMotion(surface: MotionSurface, reduceMotion: Boolean): ResolvedMotion {
    if (reduceMotion) {
        return if (surface == MotionSurface.NUMERIC) ResolvedMotion.NONE else ResolvedMotion.QUICK
    }
    return when (surface) {
        MotionSurface.FADE -> ResolvedMotion.QUICK
        MotionSurface.SPRING -> ResolvedMotion.SOFT_SPRING
        MotionSurface.NUMERIC -> ResolvedMotion.STANDARD
    }
}
