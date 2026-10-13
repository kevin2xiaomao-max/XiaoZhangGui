package com.xiaozhanggui.app

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.espresso.Espresso
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.navigation.XzgNavGraph
import com.xiaozhanggui.app.ui.navigation.XzgTab
import com.xiaozhanggui.app.ui.theme.XzgTheme
import com.xiaozhanggui.app.ui.theme.v371.V371TestTags
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 导航冒烟测试（V3.7.1 Phase 2 导航 worker 重写）。
 *
 * - 用真实 [XzgNavGraph]（XzgGraph 在测试进程内已由 XzgApplication.onCreate 初始化，
 *   各屏读空数据库，不依赖假数据）；
 * - 只断言"可点 + 到达目标屏不崩溃"，不做深层业务断言；
 * - V3.7.1：4 Tab（首页/待办/日历/经营）；AI 不再是 Tab（首页 AICommandEntry → AI Sheet）；
 *   「我的」不再是 Tab（首页头像 → navigationDestination）；经营快捷抽屉已退役，
 *   原抽屉目的地全部迁至新入口（经营 menu / 首页「今日重点」行）。
 */
@RunWith(AndroidJUnit4::class)
class NavSmokeTest {

    @get:Rule
    val rule = createComposeRule()

    private fun launchGraph() {
        rule.setContent {
            XzgTheme {
                XzgNavGraph()
            }
        }
        rule.waitForIdle()
    }

    @Test
    fun fourTabs_switchWithoutCrash() {
        launchGraph()

        // 首页（默认 Tab）
        rule.onNodeWithTag(V371TestTags.SCREEN_HOME).assertExists()

        // 四 Tab tag 与 iOS V371AccessibilityID.tab* 对齐
        rule.onNodeWithTag(XzgTab.HOME.tag).assertExists()
        rule.onNodeWithTag(XzgTab.TODO.tag).assertExists()
        rule.onNodeWithTag(XzgTab.CALENDAR.tag).assertExists()
        rule.onNodeWithTag(XzgTab.BUSINESS.tag).assertExists()

        // 底部栏图标 contentDescription 在未合并树中（NavigationBarItem 合并语义），需 useUnmergedTree
        // 日历：Tab 内容为 ScheduleScreen（即 iOS 日历 Tab 下的 ScheduleView 对应屏）
        rule.onNodeWithContentDescription(XzgTab.CALENDAR.label, useUnmergedTree = true).performClick()
        rule.onNodeWithText("日程").assertExists()

        // 待办：TodoContent 纯渲染根节点 tag（屏内"待办"文案有多处，用 tag 精确定位）
        rule.onNodeWithContentDescription(XzgTab.TODO.label, useUnmergedTree = true).performClick()
        rule.onNodeWithTag("todo.screen").assertExists()

        // 经营
        rule.onNodeWithContentDescription(XzgTab.BUSINESS.label, useUnmergedTree = true).performClick()
        rule.onNodeWithText("经营数据").assertExists()

        // AI 不再是 Tab：底部栏无「小掌柜」Tab（首页 AICommandEntry 的 contentDescription 为"问小掌柜，AI 助手"，
        // 此处精确匹配 Tab label「小掌柜」）
        rule.onAllNodesWithContentDescription("小掌柜", useUnmergedTree = true).assertCountEquals(0)
        // 「我的」不再是 Tab
        rule.onAllNodesWithContentDescription("我的", useUnmergedTree = true).assertCountEquals(0)

        // 回到首页
        rule.onNodeWithContentDescription(XzgTab.HOME.label, useUnmergedTree = true).performClick()
        rule.onNodeWithTag(V371TestTags.SCREEN_HOME).assertExists()
    }

    @Test
    fun homeEntries_aiProfileFocusRows_navigateWithoutCrash() {
        launchGraph()

        // 首页「今日重点」客户配送行 → 客户页
        rule.onNodeWithTag(V371TestTags.HOME_CUSTOMER).performClick()
        rule.onNodeWithText("客户配送").assertExists()
        pressBack()

        // 首页「今日重点」临期退货行 → 临期页
        rule.onNodeWithTag(V371TestTags.HOME_EXPIRY).performClick()
        rule.onNodeWithText("临期提醒").assertExists()
        pressBack()

        // 首页 AICommandEntry → AI Sheet（AI 不再是 Tab）
        rule.onNodeWithTag(V371TestTags.HOME_AI).performClick()
        rule.onNodeWithTag("ai.sheet").assertIsDisplayed()
        pressBack()

        // 首页 header 头像 → Profile（导航目的地，非 Tab）
        rule.onNodeWithTag(V371TestTags.HOME_PROFILE).performClick()
        rule.onNodeWithText("我的").assertExists()
        pressBack()

        // 回到首页
        rule.onNodeWithTag(V371TestTags.SCREEN_HOME).assertExists()
    }

    @Test
    fun businessTab_menuDestinations_navigateWithoutCrash() {
        launchGraph()
        rule.onNodeWithContentDescription(XzgTab.BUSINESS.label, useUnmergedTree = true).performClick()
        rule.onNodeWithText("经营数据").assertExists()

        // 扫呗导入（经营 menu → sheet）
        openBusinessMenuAndClick("扫呗导入")
        rule.onNodeWithText("扫呗导入").assertExists()
        pressBack()

        // 记录（经营 menu → 备忘页，R13：备忘入口迁至经营 Tab）
        openBusinessMenuAndClick("记录")
        rule.onNodeWithText("记录").assertExists()
        pressBack()

        // 今日经营日报（经营 menu → sheet）
        openBusinessMenuAndClick("今日经营日报")
        rule.onNodeWithText("今日经营日报").assertExists()
        pressBack()

        // 商品（经营 toolbar「商品管理」→ 商品页，R11）
        rule.onNodeWithContentDescription("商品管理").performClick()
        rule.onAllNodesWithText("商品").assertCountEquals(1)
        pressBack()

        // 交易记录（经营页「查看全部交易」）
        rule.onNodeWithContentDescription("查看全部交易").performClick()
        rule.onAllNodesWithText("交易记录").assertCountEquals(1)
        pressBack()

        // 回到经营 Tab 确认底部栏仍可点
        rule.onNodeWithText("经营数据").assertExists()
    }

    /** 经营页右上角 menu（contentDescription "记一笔"）→ 等菜单项可见 → 点击。 */
    private fun openBusinessMenuAndClick(itemText: String) {
        rule.onNodeWithContentDescription("记一笔").performClick()
        rule.waitUntil(timeoutMillis = 5_000) {
            runCatching { rule.onNodeWithText(itemText).assertIsDisplayed() }.isSuccess
        }
        rule.onNodeWithText(itemText).performClick()
        rule.waitForIdle()
    }

    private fun pressBack() {
        Espresso.pressBack()
        rule.waitForIdle()
    }
}
