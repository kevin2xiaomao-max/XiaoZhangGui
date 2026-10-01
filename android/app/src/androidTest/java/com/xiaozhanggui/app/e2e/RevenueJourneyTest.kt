package com.xiaozhanggui.app.e2e

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.espresso.Espresso
import androidx.test.filters.LargeTest
import com.xiaozhanggui.app.MainActivity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.Format
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test

/**
 * 旅程 1：记录一笔营业额（Phase 6 Worker B）。
 *
 * 首页 → 点击 RevenueHero → 经营数据页 → 右上菜单「记收入」→
 * MoneyEditorSheet 填金额/备注 → 保存 → 返回首页 →
 * Hero「今日营业额」数值更新（期望值 = 记录前今日总额 + 本次金额）。
 *
 * 数据隔离：金额用整数 500.0（浮点加法精确，与求和顺序无关），
 * 备注带唯一 marker，旅程结束经 Repository 删除写入的数据（try/finally）。
 */
@LargeTest
class RevenueJourneyTest {

    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    companion object {
        @JvmStatic
        @BeforeClass
        fun setupClass() {
            E2EBase.disableAnimations()
        }
    }

    @Test
    fun recordRevenue_updatesHomeHeroTodayRevenue() {
        val perfRepo = XzgGraph.performanceRepository
        val marker = "E2E-${System.currentTimeMillis()}"
        val amount = 500.0
        val before = runBlocking { perfRepo.observeAll().first() }
            .filter { DateExt.isToday(it.date) }
            .sumOf { it.amount }

        try {
            // 首页 Hero → 经营页
            rule.onNodeWithTag("home.heroRevenue").assertIsDisplayed()
            rule.onNodeWithTag("home.heroRevenue").performClick()

            // 经营页右上菜单 → 记收入
            rule.waitUntil(10_000) {
                rule.onAllNodesWithContentDescription("经营数据操作")
                    .fetchSemanticsNodes().isNotEmpty()
            }
            rule.onNodeWithContentDescription("经营数据操作").performClick()
            rule.onNodeWithText("记收入").performClick()

            // 记一笔收入 Sheet：金额 + 备注 → 保存
            rule.waitUntil(10_000) {
                rule.onAllNodesWithTag("money.amountInput")
                    .fetchSemanticsNodes().isNotEmpty()
            }
            rule.onNodeWithTag("money.amountInput").performTextInput("500")
            rule.onNodeWithTag("money.noteInput").performTextInput(marker)
            rule.onNodeWithTag("money.saveButton").performClick()

            // Sheet 关闭
            rule.waitUntil(10_000) {
                rule.onAllNodesWithTag("money.amountInput")
                    .fetchSemanticsNodes().isEmpty()
            }

            // 返回首页，Hero 今日营业额更新（精确匹配：避免与经营页 "¥500.00" 的子串混淆）
            Espresso.pressBack()
            val expected = "¥" + Format.groupedAmount(before + amount)
            rule.waitUntil(15_000) {
                rule.onAllNodesWithText(expected)
                    .fetchSemanticsNodes().isNotEmpty()
            }
            rule.onNodeWithText(expected).assertIsDisplayed()
        } finally {
            // 清理：删除本旅程写入的经营记录
            runBlocking {
                val created = perfRepo.observeAll().first()
                    .firstOrNull { it.note == marker }
                if (created != null) perfRepo.delete(created)
            }
        }
    }
}
