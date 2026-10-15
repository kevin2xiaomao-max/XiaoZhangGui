package com.xiaozhanggui.app

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.ui.screens.profile.GoalEditSheet
import com.xiaozhanggui.app.ui.screens.profile.ShopEditSheet
import com.xiaozhanggui.app.ui.theme.XzgTheme
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 店铺 / 月营业目标设置 Sheet 测试（R23）。
 *
 * 渲染 + 校验规则（空值禁用保存）+ 保存真实落库 DataStore
 * （跑在测试应用进程内；用例结束恢复原始设置，避免污染其他测试）。
 */
@RunWith(AndroidJUnit4::class)
class ProfileSettingsTest {

    @get:Rule
    val rule = createComposeRule()

    private val settings get() = XzgGraph.settings

    /** 轮询等待设置落库（测试线程执行，Main 保持空闲让保存协程跑完）。 */
    private fun awaitSettingEquals(timeoutMs: Long, expected: Any, read: suspend () -> Any) {
        val deadline = System.currentTimeMillis() + timeoutMs
        var last: Any = "<unset>"
        while (System.currentTimeMillis() < deadline) {
            last = runBlocking { read() }
            if (last == expected) return
            Thread.sleep(200)
        }
        Assert.fail("设置未在 ${timeoutMs}ms 内落库：期望=$expected 实际=$last")
    }

    // ---------- 店铺信息 ----------

    @Test
    fun shopEditSheet_rendersAndSaves() {
        val origShop = runBlocking { settings.shopName.first() }
        val origOwner = runBlocking { settings.ownerName.first() }
        try {
            var dismissed = false
            rule.setContent {
                XzgTheme {
                    ShopEditSheet(
                        initialShop = "测试店",
                        initialOwner = "测试掌柜",
                        onDismiss = { dismissed = true }
                    )
                }
            }
            rule.waitForIdle()
            rule.onNodeWithText("店铺信息").assertExists()
            rule.onNodeWithText("店铺名称").assertExists()
            rule.onNodeWithText("店主称呼").assertExists()
            // 两字段非空 → 保存可用
            rule.onNodeWithText("保存").assertIsEnabled()

            val fields = rule.onAllNodes(hasSetTextAction())
            fields[0].performTextClearance()
            fields[0].performTextInput("新店名")
            fields[1].performTextClearance()
            fields[1].performTextInput("新掌柜")
            rule.onNodeWithText("保存").performClick()

            awaitSettingEquals(8000, "新店名") { settings.shopName.first() }
            awaitSettingEquals(8000, "新掌柜") { settings.ownerName.first() }
            rule.waitUntil(5000) { dismissed }
        } finally {
            runBlocking {
                settings.setShopName(origShop)
                settings.setOwnerName(origOwner)
            }
        }
    }

    @Test
    fun shopEditSheet_saveDisabledWhenEmpty() {
        rule.setContent {
            XzgTheme {
                ShopEditSheet(initialShop = "", initialOwner = "", onDismiss = {})
            }
        }
        rule.waitForIdle()
        rule.onNodeWithText("保存").assertIsNotEnabled()
        // 填入两字段后恢复可用
        val fields = rule.onAllNodes(hasSetTextAction())
        fields[0].performTextInput("有店名")
        fields[1].performTextInput("有掌柜")
        rule.waitForIdle()
        rule.onNodeWithText("保存").assertIsEnabled()
    }

    // ---------- 月营业目标 ----------

    @Test
    fun goalEditSheet_rendersAndSaves() {
        val origGoal = runBlocking { settings.monthGoal.first() }
        try {
            rule.setContent {
                XzgTheme {
                    GoalEditSheet(initialGoal = 50000.0, onDismiss = {})
                }
            }
            rule.waitForIdle()
            rule.onNodeWithText("月营业目标").assertExists()
            rule.onNodeWithText("目标金额").assertExists()
            val field = rule.onAllNodes(hasSetTextAction())[0]
            field.assertTextContains("50000")
            rule.onNodeWithText("保存").assertIsEnabled()

            field.performTextClearance()
            field.performTextInput("80000")
            rule.onNodeWithText("保存").performClick()

            awaitSettingEquals(8000, 80000.0) { settings.monthGoal.first() }
        } finally {
            runBlocking { settings.setMonthGoal(origGoal) }
        }
    }

    @Test
    fun goalEditSheet_saveDisabledWhenInvalid() {
        rule.setContent {
            XzgTheme {
                GoalEditSheet(initialGoal = 0.0, onDismiss = {})
            }
        }
        rule.waitForIdle()
        // 初始空 → 保存禁用
        rule.onNodeWithText("保存").assertIsNotEnabled()
        // 非法输入仍禁用
        val field = rule.onAllNodes(hasSetTextAction())[0]
        field.performTextInput("abc")
        rule.waitForIdle()
        rule.onNodeWithText("保存").assertIsNotEnabled()
        // 合法金额 → 可用
        field.performTextClearance()
        field.performTextInput("120000")
        rule.waitForIdle()
        rule.onNodeWithText("保存").assertIsEnabled()
    }
}
