package com.xiaozhanggui.app

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.espresso.Espresso
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.navigation.XzgNavGraph
import com.xiaozhanggui.app.ui.navigation.XzgTab
import com.xiaozhanggui.app.ui.theme.XzgTheme
import com.xiaozhanggui.app.ui.theme.v371.V371TestTags
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 四 Tab 导航契约测试（V3.7.1 Phase 2 测试 worker）。
 *
 * 补 [NavSmokeTest] 未覆盖的验收点：
 * - Tab 数量恒为 4（枚举级断言；旧「小掌柜」「我的」Tab 已从 [XzgTab] 删除）；
 * - AI Sheet 关闭 → 回到首页且状态不丢（Matrix R09：「关闭 Sheet 回到当前页」）。
 *
 * 写法沿用 NavSmokeTest 的既定模式：真实 [XzgNavGraph]
 *（XzgApplication 在测试进程内已初始化，空数据库，不依赖假数据）。
 */
@RunWith(AndroidJUnit4::class)
class FourTabNavContractTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun tabContract_isExactlyFour_noLegacyTabs() {
        assertEquals("Tab 数量必须为 4（首页/待办/日历/经营）", 4, XzgTab.values().size)
        assertEquals(
            listOf("首页", "待办", "日历", "经营"),
            XzgTab.values().map { it.label }
        )
        // 旧 Tab 路由不得残留
        val routes = XzgTab.values().map { it.route }
        assertEquals(listOf("home", "todo", "calendar", "business"), routes)
    }

    @Test
    fun aiSheet_close_returnsHomeWithStateKept() {
        rule.setContent {
            XzgTheme {
                XzgNavGraph()
            }
        }
        rule.waitForIdle()

        // 首页状态指纹：hero 营业额 + AICommandEntry
        rule.onNodeWithTag(V371TestTags.HERO_REVENUE).assertIsDisplayed()
        rule.onNodeWithTag(V371TestTags.HOME_AI).assertIsDisplayed()

        // 首页 AICommandEntry → AI Sheet 打开
        rule.onNodeWithTag(V371TestTags.HOME_AI).performClick()
        rule.waitForIdle()
        rule.onNodeWithTag("ai.sheet").assertIsDisplayed()
        rule.onNodeWithTag("ai.input").assertIsDisplayed()

        // 关闭 Sheet（返回键）→ 回到当前页
        Espresso.pressBack()
        rule.waitForIdle()

        // Sheet 消失；首页仍在，状态不丢
        rule.onAllNodesWithTag("ai.sheet").assertCountEquals(0)
        rule.onNodeWithTag(V371TestTags.SCREEN_HOME).assertIsDisplayed()
        rule.onNodeWithTag(V371TestTags.HERO_REVENUE).assertIsDisplayed()
        rule.onNodeWithTag(V371TestTags.HOME_AI).assertIsDisplayed()
    }
}
