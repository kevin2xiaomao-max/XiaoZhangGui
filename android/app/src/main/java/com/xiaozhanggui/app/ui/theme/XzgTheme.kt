package com.xiaozhanggui.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import com.xiaozhanggui.app.data.datastore.AccentTheme
import com.xiaozhanggui.app.data.datastore.BackgroundTheme
import com.xiaozhanggui.app.data.datastore.ThemeMode

/**
 * XzgTheme：V32 主题桥接。
 *
 * 对应 iOS `V32/Theme/`（ThemeStore + v32ThemeStore EnvironmentKey）。
 * 三正交维度：显示模式（跟随系统/浅色/深色）× Accent 6 套 × Background 6 套。
 * Material3 colorScheme 仅作实现工具，视觉以 V32 色板为准；
 * 页面应优先使用 [LocalXzgPalettes] 的 V32 语义色，而非 Material 默认色。
 *
 * Phase 5 接入：DataStore 订阅（themeMode/accent/background）、壁纸背景层、
 * Reduce Motion 检查。
 */
data class XzgPalettes(
    val background: BackgroundPalette,
    val accent: AccentPalette,
    val fixed: FixedSemanticColors,
    val isDark: Boolean
)

val LocalXzgPalettes = staticCompositionLocalOf<XzgPalettes> {
    error("LocalXzgPalettes 未提供：请在 XzgTheme 内使用")
}

@Composable
fun XzgTheme(
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    accentTheme: AccentTheme = AccentTheme.EMERALD,
    backgroundTheme: BackgroundTheme = BackgroundTheme.WARM_CREAM,
    content: @Composable () -> Unit
) {
    val isDark = when (themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
    }
    val bg = backgroundPalette(backgroundTheme, isDark)
    val ac = accentPalette(accentTheme, isDark)
    val fixed = fixedSemanticColors(isDark)

    val colorScheme = if (isDark) {
        darkColorScheme(
            primary = ac.accent,
            onPrimary = ac.onAccent,
            primaryContainer = ac.accentSoft,
            onPrimaryContainer = ac.accent,
            secondary = ac.secondaryAccent,
            background = bg.pageBG,
            onBackground = bg.textPrimary,
            surface = bg.card,
            onSurface = bg.textPrimary,
            surfaceVariant = bg.pageBGSecondary,
            onSurfaceVariant = bg.textSecondary,
            outline = bg.cardOutline,
            outlineVariant = bg.divider,
            error = fixed.danger,
            onError = Color.White
        )
    } else {
        lightColorScheme(
            primary = ac.accent,
            onPrimary = ac.onAccent,
            primaryContainer = ac.accentSoft,
            onPrimaryContainer = ac.accent,
            secondary = ac.secondaryAccent,
            background = bg.pageBG,
            onBackground = bg.textPrimary,
            surface = bg.card,
            onSurface = bg.textPrimary,
            surfaceVariant = bg.pageBGSecondary,
            onSurfaceVariant = bg.textSecondary,
            outline = bg.cardOutline,
            outlineVariant = bg.divider,
            error = fixed.danger,
            onError = Color.White
        )
    }

    CompositionLocalProvider(LocalXzgPalettes provides XzgPalettes(bg, ac, fixed, isDark)) {
        MaterialTheme(
            colorScheme = colorScheme,
            content = content
        )
    }
}
