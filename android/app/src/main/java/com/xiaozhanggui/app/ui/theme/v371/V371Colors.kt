package com.xiaozhanggui.app.ui.theme.v371

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes

/**
 * V371 色板（对应 iOS `DesignSystem/V371/V371DesignSystem.swift` 的 `V371.Colors`）。
 *
 * Surface 分级（只允许 S0–S3）：
 * - S0 Canvas：页面底色（Light #F4F4F7 / Dark #08080B）
 * - S1 Group：分组面（Light #FFFFFF / Dark #1B1B20，圆角 24 solid，禁用 material）
 * - S1 GroupSecondary：嵌套小块
 * - S2 Hero 蓝渐变（#4A9CFF→#2B6EF2，**仅天气详情 sheet 用**，首页/日历禁用）
 * - S3 Floating：Dock / AI command 允许半透明（Android 无 backdrop blur，用半透明 + hairline 近似）
 *
 * 文本色为固定 Light/Dark 值（不随 V32 背景主题变化），与 iOS 系统语义色对齐；
 * iOS 的 textTertiary 仍保持次级层级（不用 tertiaryLabel，避免 Dark 对比度过低）。
 */
data class V371Colors(
    /** S0 页面底 */
    val canvas: Color,
    /** S1 分组面 */
    val group: Color,
    /** S1 嵌套小块 */
    val groupSecondary: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val divider: Color,
    /** 状态色：蓝（Dark 提亮） */
    val blue: Color,
    /** 状态色：绿（Dark 提亮） */
    val green: Color,
    /** 状态色：橙（Dark 提亮） */
    val orange: Color,
    /** 状态色：红（Dark 提亮） */
    val red: Color,
    /** 状态色：黄（Dark 提亮） */
    val yellow: Color,
    val gray: Color,
    /** S2 Hero 渐变顶（仅天气详情 sheet） */
    val heroTop: Color,
    /** S2 Hero 渐变底（仅天气详情 sheet） */
    val heroBottom: Color,
    /** S3 / 头部控件填充：ultraThinMaterial 的 Android 近似（半透明 + hairline 边框） */
    val frostedFill: Color,
    val frostedBorder: Color
) {
    /** 行内图标底（对应 iOS `V371.Colors.tinted`：13% 透明度） */
    fun tinted(color: Color): Color = color.copy(alpha = 0.13f)
}

fun v371LightColors(): V371Colors = V371Colors(
    canvas = Color(0xFFF4F4F7),
    group = Color(0xFFFFFFFF),
    groupSecondary = Color(0xFFF1F1F3),
    textPrimary = Color(0xFF000000),
    textSecondary = Color(0xFF000000).copy(alpha = 0.6f),
    textTertiary = Color(0xFF000000).copy(alpha = 0.6f),
    divider = Color(0xFF000000).copy(alpha = 0.12f),
    blue = Color(0xFF2E75F5),
    green = Color(0xFF21A359),
    orange = Color(0xFFE8910D),
    red = Color(0xFFE6474D),
    yellow = Color(0xFFC99900),
    gray = Color(0xFF8E8E93),
    heroTop = Color(0xFF4A9CFF),
    heroBottom = Color(0xFF2B6EF2),
    frostedFill = Color(0xB8FFFFFF),
    frostedBorder = Color(0xFF000000).copy(alpha = 0.10f)
)

fun v371DarkColors(): V371Colors = V371Colors(
    canvas = Color(0xFF08080B),
    group = Color(0xFF1B1B20),
    groupSecondary = Color(0xFF27272E),
    textPrimary = Color(0xFFFFFFFF),
    textSecondary = Color(0xFFFFFFFF).copy(alpha = 0.6f),
    textTertiary = Color(0xFFFFFFFF).copy(alpha = 0.6f),
    divider = Color(0xFFFFFFFF).copy(alpha = 0.2f),
    blue = Color(0xFF5C9EFF),
    green = Color(0xFF4DC77A),
    orange = Color(0xFFFFA84D),
    red = Color(0xFFFF6B6B),
    yellow = Color(0xFFFFCC59),
    gray = Color(0xFF8E8E93),
    heroTop = Color(0xFF2E61E0),
    heroBottom = Color(0xFF1C47B8),
    frostedFill = Color(0x33FFFFFF),
    frostedBorder = Color(0xFFFFFFFF).copy(alpha = 0.14f)
)

val LocalV371Colors = staticCompositionLocalOf { v371LightColors() }

/**
 * V371 主题包装：按当前 Light/Dark 提供 [LocalV371Colors]。
 *
 * Light/Dark 跟随 [LocalXzgPalettes] 的 isDark（XzgTheme 的三档主题模式），
 * 保证 Paparazzi 强制 LIGHT/DARK 截图正确。
 * 必须在 XzgTheme 内使用（否则沿用 LocalXzgPalettes 的 fail-fast 报错）。
 */
@Composable
fun V371Theme(dark: Boolean? = null, content: @Composable () -> Unit) {
    val isDark = dark ?: LocalXzgPalettes.current.isDark
    CompositionLocalProvider(
        LocalV371Colors provides if (isDark) v371DarkColors() else v371LightColors()
    ) {
        content()
    }
}
