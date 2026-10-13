package com.xiaozhanggui.app.e2e

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.filters.LargeTest
import androidx.test.platform.app.InstrumentationRegistry
import com.xiaozhanggui.app.MainActivity
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test

/**
 * 旅程 4：深链接 `xzg://ai` → AI Sheet（V3.7.1 Phase 2 导航 worker 重写；
 * AI 不再是 Tab）。
 *
 * 链路：冷启动 VIEW intent → MainActivity.onCreate(intent) →
 * XzgDeepLink（OpenAISheet）→ XzgNavGraph(planColdStart：首页 Tab + AI Sheet 标记）→
 * LaunchedEffect（setGraph 后）打开 AI Sheet（内容为 AIChatView 对应的 AIChatScreen）。
 *
 * `xzg://ai?mode=voice` → 同链路 + AI Sheet 内同步拉起短语音面板；
 * CI 模拟器（API 30 无 GMS）上 ASR 不可用，按 OPPO 专项红线降级为文字输入、
 * 不拉起面板，此处仅断言 AI Sheet 打开（面板拉起需真机/GMS 验证）。
 *
 * 实现方式与 manifest 配对检查见 [DeepLinkTodoJourneyTest]（同源修复史）。
 */
@LargeTest
class DeepLinkAiJourneyTest {

    @get:Rule
    val composeTestRule = createEmptyComposeRule()

    private var scenario: ActivityScenario<MainActivity>? = null

    companion object {
        @JvmStatic
        @BeforeClass
        fun setupClass() {
            E2EBase.disableAnimations()
        }
    }

    private fun launchWithDeepLink(uri: String) {
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse(uri),
            ApplicationProvider.getApplicationContext(),
            MainActivity::class.java
        )
        scenario = ActivityScenario.launch(intent)
    }

    @After
    fun closeScenario() {
        // 手动关闭；若模拟器上关不掉也不让 teardown 掩盖测试本体结果
        try {
            scenario?.close()
        } catch (e: Exception) {
            // ignore: CI 模拟器上 ActivityScenario.close() 偶发超时
        } finally {
            scenario = null
        }
    }

    @Test
    fun deepLinkAi_opensAISheet() {
        launchWithDeepLink("xzg://ai")
        assertDeepLinkResolves("xzg://ai")
        // AI Sheet 打开：sheet 容器 tag + AI 对话输入栏（AIChatScreen 内容装入 Sheet）
        composeTestRule.waitUntil(10_000) {
            composeTestRule.onAllNodesWithTag("ai.sheet")
                .fetchSemanticsNodes().isNotEmpty()
        }
        composeTestRule.onNodeWithTag("ai.sheet").assertIsDisplayed()
        composeTestRule.waitUntil(10_000) {
            composeTestRule.onAllNodesWithTag("ai.input")
                .fetchSemanticsNodes().isNotEmpty()
        }
        composeTestRule.onNodeWithTag("ai.input").assertIsDisplayed()
    }

    @Test
    fun deepLinkAiVoice_opensAISheet() {
        launchWithDeepLink("xzg://ai?mode=voice")
        assertDeepLinkResolves("xzg://ai?mode=voice")
        // AI Sheet 打开（无 GMS 模拟器上短语音面板按红线降级不拉起；真机/GMS 再验面板）
        composeTestRule.waitUntil(10_000) {
            composeTestRule.onAllNodesWithTag("ai.sheet")
                .fetchSemanticsNodes().isNotEmpty()
        }
        composeTestRule.onNodeWithTag("ai.sheet").assertIsDisplayed()
        composeTestRule.onNodeWithTag("ai.input").assertIsDisplayed()
    }

    /**
     * 隐式 intent 必须能解析到 MainActivity（manifest intent-filter 配对检查）。
     */
    private fun assertDeepLinkResolves(uri: String) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val pm = context.packageManager
        val implicit = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
        val resolved = pm.resolveActivity(implicit, 0)
        assertNotNull("隐式深链接 $uri 未解析到任何 Activity，请检查 Manifest intent-filter", resolved)
        assertEquals(
            "深链接 $uri 解析到了错误的组件",
            MainActivity::class.java.name,
            resolved!!.activityInfo.name
        )
    }
}
