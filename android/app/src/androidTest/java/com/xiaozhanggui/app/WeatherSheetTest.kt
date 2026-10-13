package com.xiaozhanggui.app

import androidx.compose.ui.test.assertExists
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.screens.home.WeatherSheet
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 天气 Sheet 占位实现测试（R10）。
 *
 * Phase 5 接入真实天气数据前：温度显示 "--°" 占位，并明确说明
 * 「天气服务将于 Phase 5 接入 WeatherAPI」，不留空 Sheet。
 */
@RunWith(AndroidJUnit4::class)
class WeatherSheetTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun weatherSheet_renders_placeholder() {
        rule.setContent {
            XzgTheme {
                WeatherSheet(onDismiss = {})
            }
        }
        rule.waitForIdle()
        rule.onNodeWithText("当前天气").assertExists()
        rule.onNodeWithText("--°").assertExists()
        rule.onNodeWithText("天气服务将于 Phase 5 接入 WeatherAPI，当前温度为占位展示。").assertExists()
    }
}
