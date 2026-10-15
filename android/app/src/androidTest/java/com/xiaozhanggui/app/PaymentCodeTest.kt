package com.xiaozhanggui.app

import android.content.Context
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodes
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.screens.paymentcode.PaymentCodeKind
import com.xiaozhanggui.app.ui.screens.paymentcode.PaymentCodeScreen
import com.xiaozhanggui.app.ui.screens.paymentcode.PaymentCodeStore
import com.xiaozhanggui.app.ui.theme.XzgTheme
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 收款码三件套 UI 测试（R19 列表 / R20 编辑器 / R21 全屏）。
 *
 * 走真实 [PaymentCodeScreen] + 真实 [PaymentCodeStore]（DataStore + filesDir，
 * 跑在测试应用进程内）；图片用占位字节（解码失败 → 占位 UI，可确定性断言）。
 * 每个用例前后清理 store，保证用例独立。
 */
@RunWith(AndroidJUnit4::class)
class PaymentCodeTest {

    @get:Rule
    val rule = createComposeRule()

    private val context: Context
        get() = ApplicationProvider.getApplicationContext()

    @Before
    fun clearBefore() = runBlocking { clearStore() }

    @After
    fun clearAfter() = runBlocking { clearStore() }

    private suspend fun clearStore() {
        val ctx = context
        PaymentCodeStore.codesFlow().first().forEach { PaymentCodeStore.delete(ctx, it.id) }
    }

    private fun seed(vararg codes: Pair<String, PaymentCodeKind>) = runBlocking {
        codes.forEach { (name, kind) ->
            PaymentCodeStore.add(context, name, kind, "fake-image-bytes".toByteArray())
        }
    }

    private fun launch() {
        rule.setContent {
            XzgTheme {
                PaymentCodeScreen(onBack = {})
            }
        }
        rule.waitForIdle()
    }

    // ---------- R19：列表渲染 ----------

    @Test
    fun paymentCodeList_rendersSeededCodes() {
        seed("微信收款码" to PaymentCodeKind.WECHAT, "支付宝收款码" to PaymentCodeKind.ALIPAY)
        launch()
        rule.waitUntil(5000) {
            rule.onAllNodesWithText("微信收款码").fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithText("微信收款码").assertExists()
        rule.onNodeWithText("支付宝收款码").assertExists()
        rule.onNodeWithText("微信").assertExists()
        rule.onNodeWithText("支付宝").assertExists()
        rule.onNodeWithText("还没有收款码").assertDoesNotExist()
        // 隐私脚注常驻
        rule.onNodeWithText("图片仅保存在本设备，不会上传服务器或发送给任何服务").assertExists()
    }

    @Test
    fun paymentCodeList_emptyState() {
        launch()
        rule.waitUntil(5000) {
            rule.onAllNodesWithText("还没有收款码").fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithText("还没有收款码").assertExists()
        rule.onNodeWithText("添加微信或支付宝收款码，结账时快速出示").assertExists()
        rule.onNodeWithText("添加收款码").assertExists()
    }

    // ---------- R20：编辑器打开 / 保存 ----------

    @Test
    fun paymentCodeEditor_addMode_opensFromList() {
        seed("微信收款码" to PaymentCodeKind.WECHAT)
        launch()
        rule.waitUntil(5000) {
            rule.onAllNodesWithText("微信收款码").fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithText("添加收款码").performClick()
        rule.waitForIdle()
        // 编辑器 Sheet 内容：类型三选 + 名称输入 + 未选图占位 + 保存
        rule.onNodeWithText("类型").assertExists()
        rule.onNodeWithText("名称").assertExists()
        rule.onNodeWithText("未选择图片").assertExists()
        rule.onNodeWithText("保存").assertExists()
    }

    @Test
    fun paymentCodeEditor_rename_savesToStore() {
        seed("旧名字" to PaymentCodeKind.WECHAT)
        launch()
        rule.waitUntil(5000) {
            rule.onAllNodesWithText("旧名字").fetchSemanticsNodes().isNotEmpty()
        }
        // 行右上「更多操作」→ 重命名
        rule.onNodeWithContentDescription("更多操作").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("重命名").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("编辑收款码").assertExists()

        // 改名并保存（编辑模式无需选图即可保存）
        val nameFields = rule.onAllNodes(hasSetTextAction())
        nameFields[0].performTextClearance()
        nameFields[0].performTextInput("新名字")
        rule.onNodeWithText("保存").performClick()

        // 列表行文本更新为「新名字」（编辑器关闭 + store 落库 + flow 回放）
        rule.waitUntil(8000) {
            rule.onAllNodesWithText("新名字").fetchSemanticsNodes().isNotEmpty()
        }
        val stored = runBlocking {
            PaymentCodeStore.codesFlow().first().map { it.name }
        }
        assertTrue("store 应落库新名字，实际=$stored", stored.contains("新名字"))
    }

    // ---------- R21：全屏展示 ----------

    @Test
    fun paymentCodeFullScreen_opensFromRow() {
        seed("码A" to PaymentCodeKind.WECHAT, "码B" to PaymentCodeKind.ALIPAY)
        launch()
        rule.waitUntil(5000) {
            rule.onAllNodesWithText("码A").fetchSemanticsNodes().isNotEmpty()
        }
        // 点击行 → 全屏 Dialog
        rule.onNodeWithText("码A").performClick()
        rule.waitUntil(5000) {
            rule.onAllNodesWithText("微信 · 1/2").fetchSemanticsNodes().isNotEmpty()
        }
        // 底部「类型 · n/N」页码指示 + 图片占位（占位字节解码失败）
        rule.onNodeWithText("微信 · 1/2").assertExists()
        rule.onNodeWithText("图片不可用").assertExists()
        // 关闭回收款码页
        rule.onNodeWithContentDescription("关闭").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("微信 · 1/2").assertDoesNotExist()
    }
}
