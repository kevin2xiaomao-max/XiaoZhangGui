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
 * 旅程 3：深链接 `xzg://todo` → 待办页（Phase 6 Worker B）。
 *
 * 链路：冷启动 VIEW intent → MainActivity.onCreate(intent) →
 * XzgDeepLink → XzgNavGraph(pendingDeepLink) → 切待办 Tab。
 *
 * 实现方式（Phase 6 修复史）：
 * - `createAndroidComposeRule` 在本工程 Compose 版本无 Intent 重载，
 *   且经 `scenario.onActivity { onNewIntent }` 投递后
 *   `ActivityScenarioRule.after → close()` 在 CI 模拟器上持续超时
 *   （Activity 卡在 RESUMED，走不到 DESTROYED）。
 * - 改用 `createEmptyComposeRule()` + 手动 `ActivityScenario.launch(intent)`：
 *   Activity 带着深链接冷启动（用户点链接时 App 未运行的真实场景），
 *   teardown 完全由测试自己控制，不依赖 rule 的自动 close。
 *
 * manifest 配对检查：用 PackageManager.resolveActivity 断言隐式
 * `xzg://todo` 能解析到 MainActivity（intent-filter 配对）。
 */
@LargeTest
class DeepLinkTodoJourneyTest {

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
            Uri.parse("xzg://todo"),
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
    fun deepLinkTodo_opensTodoTab() {
        assertDeepLinkResolves("xzg://todo")
        composeTestRule.waitUntil(10_000) {
            composeTestRule.onAllNodesWithTag("todo.screen")
                .fetchSemanticsNodes().isNotEmpty()
        }
        composeTestRule.onNodeWithTag("todo.screen").assertIsDisplayed()
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
