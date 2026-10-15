package com.xiaozhanggui.app

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNode
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.db.ExpenseCategory
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.ui.screens.performance.TransactionHistoryContent
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 全部交易页 UI 测试（R18）。
 *
 * 测与 VM 解耦后的 [TransactionHistoryContent]：
 * - 标题 / 搜索框 / 收入支出行（标题 + 金额符号）渲染
 * - 搜索过滤（标题/来源大小写不敏感）
 * - 空态「暂无交易」
 * - 返回按钮回调
 */
@RunWith(AndroidJUnit4::class)
class TransactionHistoryTest {

    @get:Rule
    val rule = createComposeRule()

    private val t0 = 1_760_000_000_000L // 固定锚点（渲染断言不依赖真实时间）

    private fun performances() = listOf(
        PerformanceEntity(
            id = "p-1",
            amount = 680.0,
            note = "美团外卖到账",
            date = t0,
            incomeSource = "美团"
        )
    )

    private fun expenses() = listOf(
        ExpenseEntity(
            id = "e-1",
            amount = 120.0,
            category = ExpenseCategory.STOCK,
            note = "进货",
            date = t0 - 3600 * 1000L
        )
    )

    private fun launch(
        performances: List<PerformanceEntity> = performances(),
        expenses: List<ExpenseEntity> = expenses(),
        onBack: () -> Unit = {}
    ) {
        rule.setContent {
            XzgTheme {
                TransactionHistoryContent(
                    performances = performances,
                    expenses = expenses,
                    onBack = onBack
                )
            }
        }
        rule.waitForIdle()
    }

    @Test
    fun transactionHistory_rendersTitleAndRows() {
        launch()
        rule.onNodeWithText("交易记录").assertExists()
        rule.onNodeWithText("搜索交易或来源").assertExists()
        // 收入行：标题 + +¥ 金额
        rule.onNodeWithText("美团外卖到账").assertExists()
        rule.onNodeWithText("+¥680.00").assertExists()
        // 支出行：标题 + -¥ 金额
        rule.onAllNodesWithText("进货")[0].assertExists()
        rule.onNodeWithText("-¥120.00").assertExists()
    }

    @Test
    fun transactionHistory_searchFiltersRows() {
        launch()
        rule.onNode(hasSetTextAction()).performTextInput("美团")
        rule.waitForIdle()
        rule.onNodeWithText("美团外卖到账").assertExists()
        rule.onNodeWithText("进货").assertDoesNotExist()
    }

    @Test
    fun transactionHistory_emptyShowsPlaceholder() {
        launch(performances = emptyList(), expenses = emptyList())
        rule.onNodeWithText("暂无交易").assertExists()
        rule.onNodeWithText("美团外卖到账").assertDoesNotExist()
    }

    @Test
    fun transactionHistory_backButtonCallsOnBack() {
        var backed = false
        launch(onBack = { backed = true })
        rule.onNodeWithContentDescription("返回").assertIsEnabled()
        rule.onNodeWithContentDescription("返回").performClick()
        rule.waitForIdle()
        assertTrue("点击返回应触发 onBack", backed)
    }
}
