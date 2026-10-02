package com.xiaozhanggui.app

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.espresso.Espresso
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.navigation.XzgNavGraph
import com.xiaozhanggui.app.ui.navigation.XzgTab
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 导航冒烟测试（Phase 6 Worker A）。
 *
 * - 用真实 [XzgNavGraph]（XzgGraph 在测试进程内已由 XzgApplication.onCreate 初始化，
 *   各屏读空数据库，不依赖假数据）；
 * - 只断言"可点 + 到达目标屏不崩溃"，不做深层业务断言。
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
    fun fiveTabs_switchWithoutCrash() {
        launchGraph()

        // 首页（默认 Tab）：抽屉菜单钮存在
        rule.onNodeWithContentDescription("打开经营快捷中心").assertExists()

        // 日程：底部栏 label + 屏内标题各一处
        rule.onNodeWithContentDescription(XzgTab.SCHEDULE.label).performClick()
        rule.onAllNodesWithText("日程").assertCountEquals(2)

        // 小掌柜：对话页顶栏标题
        rule.onNodeWithContentDescription(XzgTab.ASSISTANT.label).performClick()
        rule.onNodeWithText("说句话，帮你记账、派单、备忘").assertExists()

        // 待办：TodoContent 纯渲染根节点 tag（屏内"待办"文案有多处，用 tag 精确定位）
        rule.onNodeWithContentDescription(XzgTab.TODO.label).performClick()
        rule.onNodeWithTag("todo.screen").assertExists()

        // 我的：底部栏 label + 屏内标题各一处
        rule.onNodeWithContentDescription(XzgTab.PROFILE.label).performClick()
        rule.onAllNodesWithText("我的").assertCountEquals(2)

        // 回到首页
        rule.onNodeWithContentDescription(XzgTab.HOME.label).performClick()
        rule.onNodeWithContentDescription("打开经营快捷中心").assertExists()
    }

    @Test
    fun drawer_pushDestinations_navigateWithoutCrash() {
        launchGraph()

        // 交易记录：抽屉行 + 二级页标题各一处
        openDrawerAndClick("交易记录")
        rule.onAllNodesWithText("交易记录").assertCountEquals(2)
        pressBack()

        // 客户需求
        openDrawerAndClick("客户需求")
        rule.onNodeWithText("客户配送").assertExists()
        pressBack()

        // 临期退货
        openDrawerAndClick("临期退货")
        rule.onNodeWithText("临期提醒").assertExists()
        pressBack()

        // 商品：抽屉行 + 二级页标题各一处
        openDrawerAndClick("商品")
        rule.onAllNodesWithText("商品").assertCountEquals(2)
        pressBack()

        // 备忘（MemoScreen 标题为"记录"）
        openDrawerAndClick("备忘")
        rule.onNodeWithText("记录").assertExists()
        pressBack()

        // 回到首页确认抽屉仍可开
        rule.onNodeWithContentDescription("打开经营快捷中心").assertIsDisplayed()
    }

    @Test
    fun drawer_sheetDestinations_openWithoutCrash() {
        launchGraph()

        // 今日经营报告
        openDrawerAndClick("今日经营报告")
        rule.onNodeWithText("今日经营日报").assertExists()
        pressBack()

        // 快速记一笔
        openDrawerAndClick("快速记一笔")
        rule.onNodeWithText("快速记录").assertExists()
        pressBack()

        // 扫呗导入：抽屉行 + Sheet 标题各一处
        openDrawerAndClick("扫呗导入")
        rule.onAllNodesWithText("扫呗导入").assertCountEquals(2)
        pressBack()

        rule.onNodeWithContentDescription("打开经营快捷中心").assertIsDisplayed()
    }

    /** 打开抽屉 → 等行可见（防抽屉关闭态误点）→ 点击。 */
    private fun openDrawerAndClick(rowText: String) {
        rule.onNodeWithContentDescription("打开经营快捷中心").performClick()
        rule.waitUntil(timeoutMillis = 5_000) {
            runCatching { rule.onNodeWithText(rowText).assertIsDisplayed() }.isSuccess
        }
        rule.onNodeWithText(rowText).performClick()
        rule.waitForIdle()
    }

    private fun pressBack() {
        Espresso.pressBack()
        rule.waitForIdle()
    }
}
