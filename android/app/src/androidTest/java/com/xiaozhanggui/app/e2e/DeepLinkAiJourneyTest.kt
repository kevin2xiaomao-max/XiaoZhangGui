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
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test

/**
 * 旅程 4：深链接 `xzg://ai` → 小掌柜页（Phase 6 Worker B）。
 *
 * 链路：冷启动 VIEW intent → MainActivity.onCreate(intent) →
 * XzgDeepLink → XzgNavGraph(pendingDeepLink) → 切小掌柜 Tab。
 *
 * 实现方式与 manifest 配对检查见 [DeepLinkTodoJourneyTest]（同源修复史）。
 */
@LargeTest
class DeepLinkAiJourneyTest {

    @get:Rule
    val composeTestRule = createEmptyComposeRule()

    private lateinit var scenario: ActivityScenario<MainActivity>

    companion object {
        @JvmStatic
        @BeforeClass
        fun setupClass() {
            E2EBase.disableAnimations()
        }
    }

    @Before
    fun launchWithDeepLink() {
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("xzg://ai"),
            ApplicationProvider.getApplicationContext(),
            MainActivity::class.java
        )
        scenario = ActivityScenario.launch(intent)
    }

    @After
    fun closeScenario() {
        // 手动关闭；若模拟器上关不掉也不让 teardown 掩盖测试本体结果
        try {
            scenario.close()
        } catch (e: Exception) {
            // ignore: CI 模拟器上 ActivityScenario.close() 偶发超时
        }
    }

    @Test
    fun deepLinkAi_opensAssistantTab() {
        assertDeepLinkResolves("xzg://ai")
        composeTestRule.waitUntil(10_000) {
            composeTestRule.onAllNodesWithTag("ai.input")
                .fetchSemanticsNodes().isNotEmpty()
        }
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
