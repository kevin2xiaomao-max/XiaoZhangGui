package com.xiaozhanggui.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.screens.home.HomeContent
import com.xiaozhanggui.app.ui.screens.home.HomeInboxUiItem
import com.xiaozhanggui.app.ui.screens.home.HomeUiState
import com.xiaozhanggui.app.ui.screens.home.InboxRoute
import com.xiaozhanggui.app.ui.screens.home.InboxTone
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 首页内容测试（V3.7.1 Editorial 结构）。
 *
 * 直接测纯渲染 [HomeContent]（假 HomeUiState，不经过 XzgGraph / 数据库）：
 * Hero 今日营业额、「今日重点」三行、「接下来」。
 */
@RunWith(AndroidJUnit4::class)
class HomeContentTest {

    @get:Rule
    val rule = createComposeRule()

    private fun fakeState() = HomeUiState(
        greeting = "晚上好，王老板",
        dateLabel = "10月2日 星期五",
        todayRevenue = 1234.5,
        changePercent = 12.5,
        monthRevenue = 20000.0,
        monthGoal = 50000.0,
        todoCount = 3,
        customerCount = 2,
        expiryCount = 1,
        todoSubtitle = "1 项今天到期",
        deliverySubtitle = "有 1 单配送中",
        expirySubtitle = "1 件 3 天内临期",
        inboxItems = listOf(
            HomeInboxUiItem(
                id = "todo-1",
                title = "给张三送两箱可乐",
                subtitle = "客户配送",
                time = "今天 18:00",
                route = InboxRoute.CUSTOMER,
                tone = InboxTone.ACCENT
            )
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
                    onOpenProfile = {},
                    onOpenAI = {},
                    onOpenQuickRecord = {},
                    onWeatherClick = {}
                )
            }
        }
        rule.waitForIdle()
    }

    @Test
    fun home_hero_revenueSection_exists() {
        launchHome()
        // Hero 节点（testTag home.heroRevenue 为 V3.6 预埋，V3.7.1 保留兼容）
        rule.onNodeWithTag("home.heroRevenue").assertIsDisplayed()
        rule.onNodeWithText("今日营业额").assertExists()
        rule.onNodeWithText("较昨日 +12.5%").assertExists()
        rule.onNodeWithText("月目标 40%").assertExists()
    }

    @Test
    fun home_header_showsGreetingAndEntries() {
        launchHome()
        rule.onNodeWithText("晚上好，王老板").assertExists()
        rule.onNodeWithText("10月2日 星期五").assertExists()
        rule.onNodeWithText("记一笔").assertExists()
        rule.onNodeWithText("问小掌柜").assertExists()
        rule.onNodeWithTag("home.profile").assertExists()
        rule.onNodeWithTag("home.ai").assertExists()
    }

    @Test
    fun home_focusSection_hasThreeRows() {
        launchHome()
        rule.onNodeWithText("今日重点").assertExists()
        // 「客户配送」文案出现两处：「今日重点」行标题 + 「接下来」事项副标题
        //（onNodeWithText 为子串匹配，精确单节点断言会误报；此处按实际渲染断言 2 处）
        rule.onAllNodesWithText("客户配送").assertCountEquals(2)
        rule.onNodeWithText("今日待办").assertExists()
        rule.onNodeWithText("临期退货").assertExists()
        rule.onNodeWithText("有 1 单配送中").assertExists()
        rule.onNodeWithText("1 项今天到期").assertExists()
        rule.onNodeWithText("1 件 3 天内临期").assertExists()
        rule.onNodeWithText("2 单").assertExists()
        rule.onNodeWithText("3 项").assertExists()
        // 「1 件」为「1 件 3 天内临期」的子串：副标题 + 徽章各一处
        rule.onAllNodesWithText("1 件").assertCountEquals(2)
    }

    @Test
    fun home_nextSection_showsInboxItems() {
        launchHome()
        rule.onNodeWithText("接下来").assertExists()
        rule.onNodeWithText("给张三送两箱可乐").assertExists()
    }

    @Test
    fun home_emptyInbox_showsEmptyState() {
        launchHome(fakeState().copy(inboxItems = emptyList()))
        // 「接下来」无事项时显示 EmptyState，页面不崩溃
        rule.onNodeWithTag("home.heroRevenue").assertIsDisplayed()
        rule.onNodeWithText("今天暂无安排").assertExists()
        rule.onNodeWithText("待办、配送与临期事项会出现在这里").assertExists()
    }
}
