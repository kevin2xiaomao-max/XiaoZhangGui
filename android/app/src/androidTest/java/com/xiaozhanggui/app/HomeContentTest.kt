package com.xiaozhanggui.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.ui.screens.home.HomeContent
import com.xiaozhanggui.app.ui.screens.home.HomeInboxUiItem
import com.xiaozhanggui.app.ui.screens.home.HomeUiState
import com.xiaozhanggui.app.ui.screens.home.InboxRoute
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 首页内容测试（Phase 6 Worker A）。
 *
 * 直接测纯渲染 [HomeContent]（假 HomeUiState，不经过 XzgGraph / 数据库）：
 * Hero 今日营业额、今日事项、备忘节点存在。
 */
@RunWith(AndroidJUnit4::class)
class HomeContentTest {

    @get:Rule
    val rule = createComposeRule()

    private fun fakeState() = HomeUiState(
        greeting = "晚上好",
        ownerName = "王老板",
        dateLabel = "10月2日 星期五",
        todayRevenue = 1234.5,
        monthRevenue = 20000.0,
        monthGoal = 50000.0,
        inboxItems = listOf(
            HomeInboxUiItem(
                id = "todo-1",
                title = "给张三送两箱可乐",
                subtitle = "客户配送",
                time = "今天 18:00",
                route = InboxRoute.CUSTOMER
            )
        ),
        recentMemos = listOf(
            MemoEntity(title = "记得进货", content = "可乐快没了")
        )
    )

    private fun launchHome(state: HomeUiState = fakeState()) {
        rule.setContent {
            XzgTheme {
                HomeContent(
                    state = state,
                    onOpenPerformance = {},
                    onOpenTodoTab = {},
                    onOpenCustomer = {},
                    onOpenExpiry = {},
                    onOpenMemo = {},
                    onOpenDrawer = {},
                    onOpenQuickRecord = {},
                    onToggleTodo = {},
                    onWeatherClick = {},
                    // 关掉入场动画：动画初态透明会导致 assertIsDisplayed 抖动
                    animateEntrance = false
                )
            }
        }
        rule.waitForIdle()
    }

    @Test
    fun home_hero_revenueSection_exists() {
        launchHome()
        // Hero 节点（testTag home.heroRevenue 为 Phase 3 预埋）
        rule.onNodeWithTag("home.heroRevenue").assertIsDisplayed()
        rule.onNodeWithText("今日营业额").assertExists()
    }

    @Test
    fun home_todaySection_exists() {
        launchHome()
        rule.onNodeWithTag("home.todaySection").assertExists()
        rule.onNodeWithText("今日事项").assertExists()
        rule.onNodeWithText("给张三送两箱可乐").assertExists()
    }

    @Test
    fun home_memoSection_exists() {
        launchHome()
        rule.onNodeWithTag("home.memoSection").assertExists()
        rule.onNodeWithText("最近备忘").assertExists()
        rule.onNodeWithText("记得进货").assertExists()
    }

    @Test
    fun home_emptyInbox_showsEmptyHint() {
        launchHome(fakeState().copy(inboxItems = emptyList(), recentMemos = emptyList()))
        // 无事项 / 无备忘时各区块仍渲染（空态文案），页面不崩溃
        rule.onNodeWithTag("home.heroRevenue").assertIsDisplayed()
        rule.onNodeWithText("今天暂无待处理事项").assertExists()
    }
}
