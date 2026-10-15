package com.xiaozhanggui.app.ui.poc.glass

import androidx.compose.ui.graphics.Color
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * 对比度守恒（Design System §2.1 对比度守恒规则，独立标定）。
 *
 * 规则：T1→T2→T3 降级时，底色不透明度**单调递增**，保证同一文字在三档下的
 * 对比度落在同一区间。数值由本机脚本按 WARM_CREAM 色板独立推导，
 * 未引用任何外部实现的数值：
 *
 * - T1 = 0.42，T2 = 0.62，T3 = 0.82（严格单调递增）
 * - Light（底 #F4F1E8 /  overlay 白 / 文字 #232623）：三档对比度 [14.29, 14.93]，极差 0.64
 * - Dark（底 #16181A / overlay #232A26 / 文字 #F2F0E9）：三档对比度 [13.34, 14.47]，极差 1.13
 *
 * 验收口径（[isSameBand]）：同一文字三档对比度极差 ≤ [MAX_BAND_SPREAD]
 * 且每档 ≥ [MIN_CONTRAST]（WCAG AA 大字文本线）。
 *
 * 全部纯函数，JVM 可单测。
 */
object GlassContrast {

    /** 三档底色不透明度：T1 < T2 < T3（严格单调递增，守恒规则的字面要求） */
    val overlayAlpha: Map<GlassTier, Float> = mapOf(
        GlassTier.T1_FIDELITY to 0.42f,
        GlassTier.T2_BALANCED to 0.62f,
        GlassTier.T3_ESSENTIAL to 0.82f,
    )

    /** 同一区间判定的最大允许极差 */
    const val MAX_BAND_SPREAD = 1.5

    /** 单档最低对比度（WCAG AA，大字文本） */
    const val MIN_CONTRAST = 4.5

    /** sRGB 通道 → 线性光（WCAG 2.x 相对亮度定义） */
    private fun linearize(channel: Int): Double {
        val c = channel / 255.0
        return if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    /** WCAG 相对亮度（0..1） */
    fun relativeLuminance(color: Color): Double {
        val r = linearize((color.red * 255).roundToInt().coerceIn(0, 255))
        val g = linearize((color.green * 255).roundToInt().coerceIn(0, 255))
        val b = linearize((color.blue * 255).roundToInt().coerceIn(0, 255))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /** WCAG 对比度（1..21） */
    fun contrastRatio(foreground: Color, background: Color): Double {
        val l1 = relativeLuminance(foreground)
        val l2 = relativeLuminance(background)
        return (maxOf(l1, l2) + 0.05) / (minOf(l1, l2) + 0.05)
    }

    /**
     * Alpha 混合后的有效背景色。
     *
     * @param backdrop 背景域代表色（PoC 里为具名背景域的平均色）
     * @param overlay 玻璃底色（Light=白 / Dark=深 surface）
     * @param alpha 底色不透明度（[overlayAlpha]）
     */
    fun effectiveBackground(backdrop: Color, overlay: Color, alpha: Float): Color {
        require(alpha in 0f..1f) { "alpha 必须在 [0,1]：$alpha" }
        val a = alpha.toDouble()
        fun mix(b: Float, o: Float): Float = (b * (1 - a) + o * a).toFloat()
        return Color(
            red = mix(backdrop.red, overlay.red),
            green = mix(backdrop.green, overlay.green),
            blue = mix(backdrop.blue, overlay.blue),
            alpha = 1f,
        )
    }

    /**
     * 某档位下文字的实际对比度 = 文字 vs（背景域代表色 ⊕ 档位底色）。
     */
    fun tierContrast(
        tier: GlassTier,
        text: Color,
        backdrop: Color,
        overlay: Color,
    ): Double {
        val alpha = overlayAlpha.getValue(tier)
        return contrastRatio(text, effectiveBackground(backdrop, overlay, alpha))
    }

    /** 三档对比度是否落在同一区间（极差 ≤ 上限且每档 ≥ 最低线） */
    fun isSameBand(contrasts: List<Double>): Boolean {
        if (contrasts.isEmpty()) return false
        if (contrasts.any { it < MIN_CONTRAST }) return false
        return contrasts.max() - contrasts.min() <= MAX_BAND_SPREAD
    }
}
