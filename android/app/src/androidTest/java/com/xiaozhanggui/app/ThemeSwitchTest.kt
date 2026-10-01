package com.xiaozhanggui.app

import androidx.compose.ui.test.assertExists
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.datastore.ThemeMode
import com.xiaozhanggui.app.ui.screens.home.HomeContent
import com.xiaozhanggui.app.ui.screens.home.HomeUiState
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 主题切换渲染测试（Phase 6 Worker A）：
 * 同一份首页内容在 Light / Dark 下渲染均不崩溃。
 */
@RunWith(AndroidJUnit4::class)
class ThemeSwitchTest {

    @get:Rule
    val rule = createComposeRule()

    private fun launchHome(themeMode: ThemeMode) {
        rule.setContent {
            XzgTheme(themeMode = themeMode) {
                HomeContent(
                    state = HomeUiState(
                        greeting = "晚上好",
                        ownerName = "王老板",
                        dateLabel = "10月2日 星期五",
                        todayRevenue = 888.88
                    ),
                    onOpenPerformance = {},
                    onOpenTodoTab = {},
                    onOpenCustomer = {},
                    onOpenExpiry = {},
                    onOpenMemo = {},
                    onOpenDrawer = {},
                    onOpenQuickRecord = {},
                    onToggleTodo = {},
                    onWeatherClick = {},
                    animateEntrance = false
                )
            }
        }
        rule.waitForIdle()
    }

    @Test
    fun home_lightTheme_rendersWithoutCrash() {
        launchHome(ThemeMode.LIGHT)
        rule.onNodeWithTag("home.heroRevenue").assertIsDisplayed()
        rule.onNodeWithText("今日营业额").assertExists()
        rule.onNodeWithText("王老板").assertExists()
    }

    @Test
    fun home_darkTheme_rendersWithoutCrash() {
        launchHome(ThemeMode.DARK)
        rule.onNodeWithTag("home.heroRevenue").assertIsDisplayed()
        rule.onNodeWithText("今日营业额").assertExists()
        rule.onNodeWithText("王老板").assertExists()
    }
}
