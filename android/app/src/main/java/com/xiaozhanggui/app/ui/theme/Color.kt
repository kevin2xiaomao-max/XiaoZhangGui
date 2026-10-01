package com.xiaozhanggui.app.ui.theme

import androidx.compose.ui.graphics.Color
import com.xiaozhanggui.app.data.datastore.AccentTheme
import com.xiaozhanggui.app.data.datastore.BackgroundTheme

/**
 * V32 色板。对应 iOS `DesignSystem/V32/V32Color.swift` +
 * `V32/Theme/V32ThemePalette.swift`（b28 T23）。
 *
 * - BackgroundPalette：可主题化的背景层级 + 中性文本 + divider + neutral（6 套 × light/dark）
 * - AccentPalette：点缀 / 主按钮 / 选中 / 进度 / 图标泡（6 套 × light/dark）
 * - FixedSemanticColors：Hero / amber / danger / 配送状态色固定，不随 accent/background 变化
 * - 默认组合 warmCream + emerald 与 iOS b27 取值逐一对齐
 */

/** 取 light/dark 双值 */
private fun dyn(light: Long, dark: Long, isDark: Boolean): Color =
    Color(if (isDark) 0xFF000000L or dark else 0xFF000000L or light)

/** 取带透明度的 light/dark 双值 */
private fun dynA(
    light: Long,
    dark: Long,
    lightAlpha: Float,
    darkAlpha: Float,
    isDark: Boolean
): Color = dyn(light, dark, isDark).copy(alpha = if (isDark) darkAlpha else lightAlpha)

data class BackgroundPalette(
    val pageBG: Color,
    val pageBGSecondary: Color,
    val card: Color,
    val cardElevated: Color,
    val cardInset: Color,
    val cardOutline: Color,
    val divider: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val textQuaternary: Color,
    val neutral: Color,
    val neutralSoft: Color
)

data class AccentPalette(
    val accent: Color,
    val accentSoft: Color,
    val onAccent: Color,
    val secondaryAccent: Color,
    val heroStart: Color,
    val heroEnd: Color,
    val selectedTint: Color,
    val chartAccent: Color,
    val aiAccent: Color,
    val subtleTint: Color
)

/** 固定语义色：Hero / amber / danger / info，不随主题变化 */
data class FixedSemanticColors(
    val hero: Color,
    val heroGlow: Color,
    val brandOnHero: Color,
    val brandSoftOnHero: Color,
    val textOnHero: Color,
    val textOnHeroSecondary: Color,
    val dividerOnHero: Color,
    val amber: Color,
    val amberSoft: Color,
    val amberOnHero: Color,
    val danger: Color,
    val dangerSoft: Color,
    val info: Color,
    val infoSoft: Color
)

fun fixedSemanticColors(isDark: Boolean): FixedSemanticColors = FixedSemanticColors(
    hero = dyn(0x1F2B24, 0x1B2A22, isDark),
    heroGlow = dyn(0x2C3E33, 0x22352A, isDark),
    brandOnHero = dyn(0x4FBF86, 0x35D083, isDark),
    brandSoftOnHero = dyn(0x2A3D32, 0x153225, isDark),
    textOnHero = dyn(0xFFFFFF, 0xEDF3EE, isDark),
    textOnHeroSecondary = dynA(0xFFFFFF, 0xB5C2B8, 0.66f, 1f, isDark),
    dividerOnHero = dynA(0xFFFFFF, 0xFFFFFF, 0.14f, 0.14f, isDark),
    amber = dyn(0xC08A2E, 0xF2A93B, isDark),
    amberSoft = dyn(0xF7EDD9, 0x382C17, isDark),
    amberOnHero = dyn(0xF0B04C, 0xF2A93B, isDark),
    danger = dyn(0xC9483E, 0xFF6359, isDark),
    dangerSoft = dyn(0xF8E5E1, 0x3A201D, isDark),
    info = dyn(0x4A79A8, 0x6AA9E0, isDark),
    infoSoft = dyn(0xE6EEF6, 0x182A3A, isDark)
)

fun backgroundPalette(theme: BackgroundTheme, isDark: Boolean): BackgroundPalette =
    when (theme) {
        BackgroundTheme.WARM_CREAM -> BackgroundPalette(
            pageBG = dyn(0xF4F1E8, 0x16181A, isDark),
            pageBGSecondary = dyn(0xECE8DB, 0x1D201E, isDark),
            card = dyn(0xFFFFFF, 0x1F2220, isDark),
            cardElevated = dyn(0xFFFFFF, 0x262A27, isDark),
            cardInset = dyn(0xF4F1E8, 0x2A2E2B, isDark),
            cardOutline = dynA(0x232623, 0xFFFFFF, 0.07f, 0.08f, isDark),
            divider = dynA(0x232623, 0xFFFFFF, 0.08f, 0.08f, isDark),
            textPrimary = dyn(0x232623, 0xF2F0E9, isDark),
            textSecondary = dyn(0x60655E, 0xB8BDB4, isDark),
            textTertiary = dyn(0x94988F, 0x898F87, isDark),
            textQuaternary = dyn(0xAFB3AA, 0x6B7169, isDark),
            neutral = dyn(0x8B9088, 0x9AA098, isDark),
            neutralSoft = dyn(0xEEF0EA, 0x2C302D, isDark)
        )
        BackgroundTheme.PURE_WHITE -> BackgroundPalette(
            pageBG = dyn(0xFCFCFD, 0x131516, isDark),
            pageBGSecondary = dyn(0xF2F2F5, 0x1A1C1E, isDark),
            card = dyn(0xFFFFFF, 0x1C1E20, isDark),
            cardElevated = dyn(0xFFFFFF, 0x232628, isDark),
            cardInset = dyn(0xF7F7F9, 0x272A2C, isDark),
            cardOutline = dynA(0x1D1D1F, 0xFFFFFF, 0.08f, 0.10f, isDark),
            divider = dynA(0x1D1D1F, 0xFFFFFF, 0.10f, 0.10f, isDark),
            textPrimary = dyn(0x1D1D1F, 0xF5F5F7, isDark),
            textSecondary = dyn(0x5A5A60, 0xC0C0C6, isDark),
            textTertiary = dyn(0x8A8A90, 0x8A8A90, isDark),
            textQuaternary = dyn(0xAEAEB4, 0x68686E, isDark),
            neutral = dyn(0x8E8E93, 0x9A9AA0, isDark),
            neutralSoft = dyn(0xF0F0F2, 0x2A2A2D, isDark)
        )
        BackgroundTheme.SAGE_GREEN -> BackgroundPalette(
            pageBG = dyn(0xEDEFE7, 0x14181A, isDark),
            pageBGSecondary = dyn(0xE3E6DA, 0x1B201D, isDark),
            card = dyn(0xF7F8F2, 0x1E2320, isDark),
            cardElevated = dyn(0xFBFCF6, 0x252B27, isDark),
            cardInset = dyn(0xECEEE3, 0x293025, isDark),
            cardOutline = dynA(0x2A3328, 0xFFFFFF, 0.08f, 0.08f, isDark),
            divider = dynA(0x2A3328, 0xFFFFFF, 0.08f, 0.08f, isDark),
            textPrimary = dyn(0x232825, 0xECF1EA, isDark),
            textSecondary = dyn(0x5A6359, 0xB5C0B6, isDark),
            textTertiary = dyn(0x8B948A, 0x888F87, isDark),
            textQuaternary = dyn(0xA8B0A6, 0x6A726A, isDark),
            neutral = dyn(0x8A9388, 0x9AA298, isDark),
            neutralSoft = dyn(0xE6E9DC, 0x2A3025, isDark)
        )
        BackgroundTheme.HAZE_BLUE -> BackgroundPalette(
            pageBG = dyn(0xECF0F3, 0x141719, isDark),
            pageBGSecondary = dyn(0xE0E6EA, 0x1A1E22, isDark),
            card = dyn(0xF8FBFC, 0x1D2226, isDark),
            cardElevated = dyn(0xFBFEFE, 0x242A2F, isDark),
            cardInset = dyn(0xEDF1F4, 0x282F34, isDark),
            cardOutline = dynA(0x1A2A35, 0xFFFFFF, 0.08f, 0.08f, isDark),
            divider = dynA(0x1A2A35, 0xFFFFFF, 0.08f, 0.08f, isDark),
            textPrimary = dyn(0x1F2830, 0xEAF0F4, isDark),
            textSecondary = dyn(0x566270, 0xB0BCC6, isDark),
            textTertiary = dyn(0x83909A, 0x808E98, isDark),
            textQuaternary = dyn(0xA2AFB8, 0x62707A, isDark),
            neutral = dyn(0x88969F, 0x96A4AD, isDark),
            neutralSoft = dyn(0xE2E7EC, 0x262D32, isDark)
        )
        BackgroundTheme.NEUTRAL_GRAY -> BackgroundPalette(
            pageBG = dyn(0xF1F1F2, 0x151617, isDark),
            pageBGSecondary = dyn(0xE7E7E9, 0x1B1C1E, isDark),
            card = dyn(0xFBFBFC, 0x1E1F21, isDark),
            cardElevated = dyn(0xFFFFFF, 0x252628, isDark),
            cardInset = dyn(0xF2F2F3, 0x292A2C, isDark),
            cardOutline = dynA(0x232325, 0xFFFFFF, 0.08f, 0.08f, isDark),
            divider = dynA(0x232325, 0xFFFFFF, 0.08f, 0.08f, isDark),
            textPrimary = dyn(0x1F2022, 0xF1F1F3, isDark),
            textSecondary = dyn(0x5A5B5E, 0xB8B9BE, isDark),
            textTertiary = dyn(0x8A8B8F, 0x898A8E, isDark),
            textQuaternary = dyn(0xA8A9AD, 0x6A6B6F, isDark),
            neutral = dyn(0x8E8F93, 0x9AA0A4, isDark),
            neutralSoft = dyn(0xECEEED, 0x2A2B2D, isDark)
        )
        BackgroundTheme.SOFT_LILAC -> BackgroundPalette(
            pageBG = dyn(0xF1ECF3, 0x161418, isDark),
            pageBGSecondary = dyn(0xE7E0EC, 0x1C1A20, isDark),
            card = dyn(0xFBF8FC, 0x201D24, isDark),
            cardElevated = dyn(0xFEFBFF, 0x272329, isDark),
            cardInset = dyn(0xF3EEF4, 0x2B2630, isDark),
            cardOutline = dynA(0x2E2535, 0xFFFFFF, 0.08f, 0.08f, isDark),
            divider = dynA(0x2E2535, 0xFFFFFF, 0.08f, 0.08f, isDark),
            textPrimary = dyn(0x251F2C, 0xF1ECF4, isDark),
            textSecondary = dyn(0x5F5570, 0xBAB0C6, isDark),
            textTertiary = dyn(0x8E849A, 0x8A8096, isDark),
            textQuaternary = dyn(0xAB9FB6, 0x6A5F76, isDark),
            neutral = dyn(0x9088A0, 0x9C92AC, isDark),
            neutralSoft = dyn(0xE5DEEC, 0x2A2532, isDark)
        )
    }

fun accentPalette(theme: AccentTheme, isDark: Boolean): AccentPalette =
    when (theme) {
        AccentTheme.EMERALD -> AccentPalette(
            accent = dyn(0x2F6B4F, 0x35D083, isDark),
            accentSoft = dyn(0xE2EFE7, 0x153225, isDark),
            onAccent = dyn(0xFFFFFF, 0x0F1F18, isDark),
            secondaryAccent = dyn(0x6C927C, 0x7FE0A8, isDark),
            heroStart = dyn(0x234D3A, 0x173A2B, isDark),
            heroEnd = dyn(0x4C8767, 0x246B49, isDark),
            selectedTint = dyn(0xDCEDE3, 0x193B2A, isDark),
            chartAccent = dyn(0x2F8A5C, 0x63D895, isDark),
            aiAccent = dyn(0x327E5A, 0x75DFA3, isDark),
            subtleTint = dyn(0xEDF5F0, 0x17251D, isDark)
        )
        AccentTheme.BLUE -> AccentPalette(
            accent = dyn(0x3A6FB8, 0x6CA6F0, isDark),
            accentSoft = dyn(0xE2EBF6, 0x152638, isDark),
            onAccent = dyn(0xFFFFFF, 0x0A1A2E, isDark),
            secondaryAccent = dyn(0x6689B2, 0x92BDF5, isDark),
            heroStart = dyn(0x344F70, 0x1D2E43, isDark),
            heroEnd = dyn(0x5A82AC, 0x345B84, isDark),
            selectedTint = dyn(0xDCE8F4, 0x1B314A, isDark),
            chartAccent = dyn(0x477FBF, 0x83B7F2, isDark),
            aiAccent = dyn(0x3A78BE, 0x8BB9F1, isDark),
            subtleTint = dyn(0xEDF3F9, 0x182431, isDark)
        )
        AccentTheme.PURPLE -> AccentPalette(
            accent = dyn(0x7C5BC9, 0xB08CE0, isDark),
            accentSoft = dyn(0xECDEF6, 0x251938, isDark),
            onAccent = dyn(0xFFFFFF, 0x1A0E2A, isDark),
            secondaryAccent = dyn(0x9A82C9, 0xC5A9EB, isDark),
            heroStart = dyn(0x554078, 0x30234A, isDark),
            heroEnd = dyn(0x8B6AC1, 0x634C91, isDark),
            selectedTint = dyn(0xEAE1F5, 0x332647, isDark),
            chartAccent = dyn(0x866BD0, 0xC09BEF, isDark),
            aiAccent = dyn(0x795BC5, 0xC4A4EF, isDark),
            subtleTint = dyn(0xF3EFF9, 0x211A2C, isDark)
        )
        AccentTheme.CORAL -> AccentPalette(
            accent = dyn(0xE0654A, 0xFF8466, isDark),
            accentSoft = dyn(0xFBE4DC, 0x381F18, isDark),
            onAccent = dyn(0xFFFFFF, 0x2A0E06, isDark),
            secondaryAccent = dyn(0xC77D63, 0xFFA98D, isDark),
            heroStart = dyn(0x8A4633, 0x4C271F, isDark),
            heroEnd = dyn(0xC06A4B, 0x8B4937, isDark),
            selectedTint = dyn(0xF7E5DE, 0x42231C, isDark),
            chartAccent = dyn(0xD86D4E, 0xFF9A79, isDark),
            aiAccent = dyn(0xCF6549, 0xFFAA8D, isDark),
            subtleTint = dyn(0xFBF1ED, 0x2B1B17, isDark)
        )
        AccentTheme.GRAPHITE -> AccentPalette(
            accent = dyn(0x3A3F45, 0xC4C9CF, isDark),
            accentSoft = dyn(0xE3E5E8, 0x25282C, isDark),
            onAccent = dyn(0xFFFFFF, 0x101316, isDark),
            secondaryAccent = dyn(0x727982, 0xE0E3E8, isDark),
            heroStart = dyn(0x292E34, 0x22262A, isDark),
            heroEnd = dyn(0x555D66, 0x444B53, isDark),
            selectedTint = dyn(0xE6E8EA, 0x2E3338, isDark),
            chartAccent = dyn(0x56616C, 0xD1D7DD, isDark),
            aiAccent = dyn(0x4A525B, 0xD7DCE2, isDark),
            subtleTint = dyn(0xF0F1F2, 0x1D2023, isDark)
        )
        AccentTheme.ROSE -> AccentPalette(
            accent = dyn(0xB05270, 0xE39AAF, isDark),
            accentSoft = dyn(0xF6E3EA, 0x38212B, isDark),
            onAccent = dyn(0xFFFFFF, 0x2B121C, isDark),
            secondaryAccent = dyn(0xB8758C, 0xEDB6C7, isDark),
            heroStart = dyn(0x743A51, 0x462635, isDark),
            heroEnd = dyn(0xB86682, 0x744257, isDark),
            selectedTint = dyn(0xF2DEE6, 0x412531, isDark),
            chartAccent = dyn(0xB95B79, 0xE9A0B8, isDark),
            aiAccent = dyn(0xA94D6C, 0xE5A0B6, isDark),
            subtleTint = dyn(0xFAF0F4, 0x291B22, isDark)
        )
    }
