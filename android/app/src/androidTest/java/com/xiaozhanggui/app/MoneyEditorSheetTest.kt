package com.xiaozhanggui.app

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.ui.screens.performance.MoneyEditorMode
import com.xiaozhanggui.app.ui.screens.performance.MoneyEditorSheet
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 记账编辑器 4 模式渲染测试（Phase 6 Worker A）。
 *
 * 只验证各模式正常渲染不崩溃（不点保存 → 不触及 XzgGraph）：
 * NEW_INCOME / NEW_EXPENSE / EDIT_PERFORMANCE / EDIT_EXPENSE。
 */
@RunWith(AndroidJUnit4::class)
class MoneyEditorSheetTest {

    @get:Rule
    val rule = createComposeRule()

    private fun launchMode(
        mode: MoneyEditorMode,
        performance: PerformanceEntity? = null,
        expense: ExpenseEntity? = null
    ) {
        rule.setContent {
            XzgTheme {
                MoneyEditorSheet(
                    mode = mode,
                    performance = performance,
                    expense = expense,
                    onDismiss = {}
                )
            }
        }
        rule.waitForIdle()
    }

    @Test
    fun moneyEditor_newIncome_renders() {
        launchMode(MoneyEditorMode.NEW_INCOME)
        rule.onNodeWithText("记一笔收入").assertExists()
        rule.onNodeWithText("收入金额").assertExists()
        rule.onNodeWithText("收入来源").assertExists()
    }

    @Test
    fun moneyEditor_newExpense_renders() {
        launchMode(MoneyEditorMode.NEW_EXPENSE)
        rule.onNodeWithText("记一笔支出").assertExists()
        rule.onNodeWithText("支出金额").assertExists()
        rule.onNodeWithText("分类").assertExists()
    }

    @Test
    fun moneyEditor_editPerformance_rendersWithPrefill() {
        launchMode(
            MoneyEditorMode.EDIT_PERFORMANCE,
            performance = PerformanceEntity(amount = 100.0, note = "午市")
        )
        rule.onNodeWithText("编辑收入").assertExists()
        // 编辑回填：金额整数显示整数形式
        rule.onNodeWithText("100").assertExists()
        rule.onNodeWithText("午市").assertExists()
    }

    @Test
    fun moneyEditor_editExpense_rendersWithPrefill() {
        launchMode(
            MoneyEditorMode.EDIT_EXPENSE,
            expense = ExpenseEntity(amount = 50.5, note = "进货")
        )
        rule.onNodeWithText("编辑支出").assertExists()
        rule.onNodeWithText("50.5").assertExists()
        // 备注输入框用 testTag 精确定位："进货"同时出现在输入框文本与分类 chip，
        // onNodeWithText 会命中 2 个节点
        rule.onNodeWithTag("money.noteInput").assertTextContains("进货")
    }
}
