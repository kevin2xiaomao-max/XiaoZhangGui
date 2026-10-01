package com.xiaozhanggui.app.data.datastore

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.byteArrayPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * DataStore 设置层。对应 iOS UserDefaults（AppSettings + ThemeStore + DemoMode + 各散落键）。
 * Key 字符串与 iOS 完全一致（含版本号后缀），保证语义可对照。
 * B_data.md §7 全键表。
 */
private val Context.xzgDataStore: DataStore<Preferences> by preferencesDataStore(name = "xzg_settings")

/** 显示模式（对应 iOS theme_mode）：system / light / dark */
enum class ThemeMode(val raw: String) {
    SYSTEM("system"),
    LIGHT("light"),
    DARK("dark");

    companion object {
        fun from(raw: String): ThemeMode = values().find { it.raw == raw } ?: SYSTEM
    }
}

/** 6 套 Accent（对应 iOS AccentTheme） */
enum class AccentTheme(val raw: String) {
    EMERALD("emerald"),
    BLUE("blue"),
    PURPLE("purple"),
    CORAL("coral"),
    GRAPHITE("graphite"),
    ROSE("rose");

    companion object {
        fun from(raw: String): AccentTheme = values().find { it.raw == raw } ?: EMERALD
    }
}

/** 6 套 Background（对应 iOS BackgroundTheme） */
enum class BackgroundTheme(val raw: String) {
    WARM_CREAM("warmCream"),
    PURE_WHITE("pureWhite"),
    SAGE_GREEN("sageGreen"),
    HAZE_BLUE("hazeBlue"),
    NEUTRAL_GRAY("neutralGray"),
    SOFT_LILAC("softLilac");

    companion object {
        fun from(raw: String): BackgroundTheme = values().find { it.raw == raw } ?: WARM_CREAM
    }
}

class XzgSettings(private val context: Context) {

    private object Keys {
        // AppSettings（Utilities/AppSettings.swift）
        val SHOP_NAME = stringPreferencesKey("shop_name")
        val OWNER_NAME = stringPreferencesKey("owner_name")
        val MONTH_GOAL = doublePreferencesKey("month_goal")
        val THEME_MODE = stringPreferencesKey("theme_mode")
        val TODO_REMINDER = booleanPreferencesKey("todo_reminder")
        val EXPIRY_REMINDER = booleanPreferencesKey("expiry_reminder")
        val VOICE_LANGUAGE = stringPreferencesKey("voice_language")
        val AVATAR_EMOJI = stringPreferencesKey("avatar_emoji")
        val AVATAR_IMAGE_DATA = byteArrayPreferencesKey("avatar_image_data")
        // DemoMode（Demo/DemoMode.swift）；新安装默认关闭
        val DEMO_MODE_ENABLED = booleanPreferencesKey("xzg_demo_mode_enabled")
        // 收款码 metadata（PaymentCodeModel.swift）
        val PAYMENT_CODE_METADATA = stringPreferencesKey("xzg.paymentCodes.metadata.v1")
        // 数据库健康标记（Data/ModelContainer.swift）
        val DB_USED_LOCAL_FALLBACK = booleanPreferencesKey("xzg.db.usedLocalFallback.v1")
        val DB_SHARED_FAILURE = booleanPreferencesKey("xzg.db.sharedFailure.v1")
        val DB_PERSISTENT_FAILURE = booleanPreferencesKey("xzg.db.persistentFailure.v1")
        // ThemeStore（V32/Theme/ThemeStore.swift）
        val V32_ACCENT = stringPreferencesKey("v32.theme.accent")
        val V32_BACKGROUND = stringPreferencesKey("v32.theme.background")
        val V32_WALLPAPER = stringPreferencesKey("v32.theme.wallpaper")
        val V32_THEME_MIGRATED = booleanPreferencesKey("v32_theme_migrated")
    }

    val shopName: Flow<String> = context.xzgDataStore.data.map { it[Keys.SHOP_NAME] ?: "天福便利店" }
    val ownerName: Flow<String> = context.xzgDataStore.data.map { it[Keys.OWNER_NAME] ?: "掌柜" }
    val monthGoal: Flow<Double> = context.xzgDataStore.data.map { it[Keys.MONTH_GOAL] ?: 120000.0 }
    val themeMode: Flow<ThemeMode> =
        context.xzgDataStore.data.map { ThemeMode.from(it[Keys.THEME_MODE] ?: "system") }
    val todoReminderEnabled: Flow<Boolean> =
        context.xzgDataStore.data.map { it[Keys.TODO_REMINDER] ?: true }
    val expiryReminderEnabled: Flow<Boolean> =
        context.xzgDataStore.data.map { it[Keys.EXPIRY_REMINDER] ?: true }
    val voiceLanguage: Flow<String> =
        context.xzgDataStore.data.map { it[Keys.VOICE_LANGUAGE] ?: "普通话" }
    val avatarEmoji: Flow<String> =
        context.xzgDataStore.data.map { it[Keys.AVATAR_EMOJI] ?: "👨🏻‍💼" }
    val avatarImageData: Flow<ByteArray?> =
        context.xzgDataStore.data.map { it[Keys.AVATAR_IMAGE_DATA] }
    val demoModeEnabled: Flow<Boolean> =
        context.xzgDataStore.data.map { it[Keys.DEMO_MODE_ENABLED] ?: false }
    val paymentCodeMetadataJson: Flow<String> =
        context.xzgDataStore.data.map { it[Keys.PAYMENT_CODE_METADATA] ?: "" }
    val accentTheme: Flow<AccentTheme> =
        context.xzgDataStore.data.map { AccentTheme.from(it[Keys.V32_ACCENT] ?: "emerald") }
    val backgroundTheme: Flow<BackgroundTheme> =
        context.xzgDataStore.data.map { BackgroundTheme.from(it[Keys.V32_BACKGROUND] ?: "warmCream") }
    val wallpaperJson: Flow<String> =
        context.xzgDataStore.data.map { it[Keys.V32_WALLPAPER] ?: "" }
    val themeMigrated: Flow<Boolean> =
        context.xzgDataStore.data.map { it[Keys.V32_THEME_MIGRATED] ?: false }

    suspend fun setShopName(v: String) = edit { it[Keys.SHOP_NAME] = v }
    suspend fun setOwnerName(v: String) = edit { it[Keys.OWNER_NAME] = v }
    suspend fun setMonthGoal(v: Double) = edit { it[Keys.MONTH_GOAL] = v }
    suspend fun setThemeMode(v: ThemeMode) = edit { it[Keys.THEME_MODE] = v.raw }
    suspend fun setTodoReminderEnabled(v: Boolean) = edit { it[Keys.TODO_REMINDER] = v }
    suspend fun setExpiryReminderEnabled(v: Boolean) = edit { it[Keys.EXPIRY_REMINDER] = v }
    suspend fun setVoiceLanguage(v: String) = edit { it[Keys.VOICE_LANGUAGE] = v }
    suspend fun setAvatarEmoji(v: String) = edit { it[Keys.AVATAR_EMOJI] = v }
    suspend fun setAvatarImageData(v: ByteArray?) = edit {
        if (v == null) it.remove(Keys.AVATAR_IMAGE_DATA) else it[Keys.AVATAR_IMAGE_DATA] = v
    }
    suspend fun setDemoModeEnabled(v: Boolean) = edit { it[Keys.DEMO_MODE_ENABLED] = v }
    suspend fun setPaymentCodeMetadataJson(v: String) = edit { it[Keys.PAYMENT_CODE_METADATA] = v }
    suspend fun setDbUsedLocalFallback(v: Boolean) = edit { it[Keys.DB_USED_LOCAL_FALLBACK] = v }
    suspend fun setDbSharedFailure(v: Boolean) = edit { it[Keys.DB_SHARED_FAILURE] = v }
    suspend fun setDbPersistentFailure(v: Boolean) = edit { it[Keys.DB_PERSISTENT_FAILURE] = v }
    suspend fun setAccentTheme(v: AccentTheme) = edit { it[Keys.V32_ACCENT] = v.raw }
    suspend fun setBackgroundTheme(v: BackgroundTheme) = edit { it[Keys.V32_BACKGROUND] = v.raw }
    suspend fun setWallpaperJson(v: String) = edit { it[Keys.V32_WALLPAPER] = v }
    suspend fun setThemeMigrated(v: Boolean) = edit { it[Keys.V32_THEME_MIGRATED] = v }

    private suspend fun edit(block: (androidx.datastore.preferences.core.MutablePreferences) -> Unit) {
        context.xzgDataStore.edit(block)
    }
}
