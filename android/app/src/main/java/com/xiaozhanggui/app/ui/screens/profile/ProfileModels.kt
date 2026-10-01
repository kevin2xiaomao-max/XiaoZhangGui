package com.xiaozhanggui.app.ui.screens.profile

import com.xiaozhanggui.app.data.datastore.AccentTheme
import com.xiaozhanggui.app.data.datastore.BackgroundTheme
import com.xiaozhanggui.app.data.datastore.ThemeMode
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** 显示模式中文名（对应 iOS AppSettings.themeModeLabel）。 */
fun ThemeMode.displayName(): String = when (this) {
    ThemeMode.SYSTEM -> "跟随系统"
    ThemeMode.LIGHT -> "浅色"
    ThemeMode.DARK -> "深色"
}

/** Accent 中文名（对应 iOS AccentTheme.displayName）。 */
fun AccentTheme.displayName(): String = when (this) {
    AccentTheme.EMERALD -> "墨绿"
    AccentTheme.BLUE -> "霁蓝"
    AccentTheme.PURPLE -> "紫罗兰"
    AccentTheme.CORAL -> "珊瑚"
    AccentTheme.GRAPHITE -> "石墨"
    AccentTheme.ROSE -> "玫瑰"
}

/** 背景风格中文名（对应 iOS BackgroundTheme.displayName）。 */
fun BackgroundTheme.displayName(): String = when (this) {
    BackgroundTheme.WARM_CREAM -> "暖米"
    BackgroundTheme.PURE_WHITE -> "纯净白"
    BackgroundTheme.SAGE_GREEN -> "鼠尾草"
    BackgroundTheme.HAZE_BLUE -> "雾霾蓝"
    BackgroundTheme.NEUTRAL_GRAY -> "中性灰"
    BackgroundTheme.SOFT_LILAC -> "柔紫"
}

/** 壁纸效果档（对应 iOS WallpaperEffect；简化版：只存选择，不做真实图片处理）。 */
enum class WallpaperEffect(val raw: String, val label: String) {
    ORIGINAL("original", "原图"),
    SOFT("soft", "柔和"),
    BLURRED("blurred", "模糊");

    companion object {
        fun from(raw: String): WallpaperEffect =
            values().find { it.raw == raw } ?: SOFT
    }
}

/** 壁纸遮罩强度（对应 iOS WallpaperMaskStrength；简化版：只存选择）。 */
enum class WallpaperMask(val raw: String, val label: String) {
    LIGHT("light", "轻"),
    MEDIUM("medium", "中"),
    STRONG("strong", "强");

    companion object {
        fun from(raw: String): WallpaperMask =
            values().find { it.raw == raw } ?: MEDIUM
    }
}

/**
 * 壁纸配置（简化版，对应 iOS WallpaperConfig）。
 * 以 JSON 存于 XzgSettings.wallpaperJson（key `v32.theme.wallpaper`）。
 */
@Serializable
data class WallpaperConfig(
    val isEnabled: Boolean = false,
    val fileName: String? = null,
    val effect: String = WallpaperEffect.SOFT.raw,
    val mask: String = WallpaperMask.MEDIUM.raw,
) {
    companion object {
        val disabled = WallpaperConfig()
        private val json = Json { ignoreUnknownKeys = true }

        /** 损坏的配置返回 disabled，不崩。 */
        fun decode(raw: String): WallpaperConfig =
            try {
                if (raw.isBlank()) disabled
                else json.decodeFromString(serializer(), raw)
            } catch (_: Exception) {
                disabled
            }
    }

    fun encode(): String = json.encodeToString(serializer(), this)

    fun effectLabel(): String = WallpaperEffect.from(effect).label
    fun maskLabel(): String = WallpaperMask.from(mask).label
}
