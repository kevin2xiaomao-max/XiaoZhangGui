package com.xiaozhanggui.app

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import com.xiaozhanggui.app.data.datastore.AccentTheme
import com.xiaozhanggui.app.data.datastore.BackgroundTheme
import com.xiaozhanggui.app.data.datastore.ThemeMode
import com.xiaozhanggui.app.data.datastore.XzgSettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * 主题偏好 DataStore 回归测试（Phase 6 Worker C）。
 *
 * 用 PreferenceDataStoreFactory 在 JVM 上构造**真实** DataStore（文件后端），
 * 覆盖主题三件套（theme_mode / v32.theme.accent / v32.theme.background）的读写
 * round-trip、默认值、非法值回退。XzgSettings 为此注入 DataStore 构造器
 * （生产仍走 Context 构造器，行为不变）。
 */
class ThemeSettingsTest {

    private lateinit var scope: CoroutineScope
    private lateinit var dir: File
    private lateinit var dataStore: DataStore<Preferences>
    private lateinit var settings: XzgSettings

    @Before
    fun setUp() {
        dir = Files.createTempDirectory("xzg-theme-test").toFile()
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        dataStore = PreferenceDataStoreFactory.create(
            scope = scope,
            produceFile = { File(dir, "settings.preferences_pb") }
        )
        settings = XzgSettings(dataStore)
    }

    @After
    fun tearDown() {
        scope.cancel()
        dir.deleteRecursively()
    }

    @Test
    fun `theme mode roundtrip`() = runTest {
        settings.setThemeMode(ThemeMode.DARK)
        assertEquals(ThemeMode.DARK, settings.themeMode.first())
        settings.setThemeMode(ThemeMode.LIGHT)
        assertEquals(ThemeMode.LIGHT, settings.themeMode.first())
        settings.setThemeMode(ThemeMode.SYSTEM)
        assertEquals(ThemeMode.SYSTEM, settings.themeMode.first())
    }

    @Test
    fun `theme mode defaults to system`() = runTest {
        assertEquals(ThemeMode.SYSTEM, settings.themeMode.first())
    }

    @Test
    fun `unknown theme raw values fall back to defaults`() {
        assertEquals(ThemeMode.SYSTEM, ThemeMode.from("neon"))
        assertEquals(ThemeMode.SYSTEM, ThemeMode.from(""))
        assertEquals(AccentTheme.EMERALD, AccentTheme.from("neon"))
        assertEquals(BackgroundTheme.WARM_CREAM, BackgroundTheme.from("neon"))
    }

    @Test
    fun `accent theme roundtrip and default`() = runTest {
        assertEquals(AccentTheme.EMERALD, settings.accentTheme.first())
        for (accent in AccentTheme.values()) {
            settings.setAccentTheme(accent)
            assertEquals(accent, settings.accentTheme.first())
        }
    }

    @Test
    fun `background theme roundtrip and default`() = runTest {
        assertEquals(BackgroundTheme.WARM_CREAM, settings.backgroundTheme.first())
        for (bg in BackgroundTheme.values()) {
            settings.setBackgroundTheme(bg)
            assertEquals(bg, settings.backgroundTheme.first())
        }
    }

    @Test
    fun `wallpaper json roundtrip`() = runTest {
        assertEquals("", settings.wallpaperJson.first())
        val payload = """{"id":"w1","opacity":0.8}"""
        settings.setWallpaperJson(payload)
        assertEquals(payload, settings.wallpaperJson.first())
    }

    @Test
    fun `theme migrated flag roundtrip`() = runTest {
        assertEquals(false, settings.themeMigrated.first())
        settings.setThemeMigrated(true)
        assertEquals(true, settings.themeMigrated.first())
    }

    @Test
    fun `theme keys use ios-compatible raw strings`() {
        assertEquals("system", ThemeMode.SYSTEM.raw)
        assertEquals("light", ThemeMode.LIGHT.raw)
        assertEquals("dark", ThemeMode.DARK.raw)
        assertEquals("emerald", AccentTheme.EMERALD.raw)
        assertEquals("warmCream", BackgroundTheme.WARM_CREAM.raw)
    }
}
