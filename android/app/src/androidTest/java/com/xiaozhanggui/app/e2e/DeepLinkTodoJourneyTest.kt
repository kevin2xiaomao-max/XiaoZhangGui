package com.xiaozhanggui.app.e2e

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.filters.LargeTest
import androidx.test.platform.app.InstrumentationRegistry
import com.xiaozhanggui.app.MainActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test

/**
 * 旅程 3：深链接 `xzg://todo` → 待办页（Phase 6 Worker B）。
 *
 * 链路：冷启动 VIEW intent → MainActivity.onCreate(intent) →
 * XzgDeepLink → XzgNavGraph(pendingDeepLink) → 切待办 Tab。
 *
 * 投递方式说明（Phase 6 修复史）：
 * - 最初用 `am start`（UiDevice shell）投递隐式 intent：CI 模拟器（API 30）
 *   system 侧 INTENT_FAILED，从未投递到 App（aapt 验证 merged manifest
 *   intent-filter 正确，判为模拟器环境问题，非 App bug）。
 * - 改显式 Component + startActivity：task 切换把 Activity 晾在 PAUSED，
 *   teardown 失败。
 * - 改直接调 onNewIntent：测试本体通过，但 ActivityScenarioRule.after →
 *   close() 在 CI 模拟器上持续超时（Activity 卡在 RESUMED，走不到
 *   DESTROYED；runOnUiThread / 手动 finish 均无效）。
 * - 最终方案（本文件）：Activity **带着深链接冷启动**
 *  （`createAndroidComposeRule` 的 `activityIntentSupplier`），走
 *   onCreate 生产路径——这正是用户点链接时 App 未运行的真实场景，
 *   且完全避开 onNewIntent / scenario 交互触发的 teardown 死锁。
 *
 * manifest 配对检查：用 PackageManager.resolveActivity 断言隐式
 * `xzg://todo` 能解析到 MainActivity（intent-filter 配对）。
 */
@LargeTest
class DeepLinkTodoJourneyTest {

    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>(
        activityIntentSupplier = {
            Intent(Intent.ACTION_VIEW, Uri.parse("xzg://todo"))
        }
    )

    companion object {
        @JvmStatic
        @BeforeClass
        fun setupClass() {
            E2EBase.disableAnimations()
        }
    }

    @Test
    fun deepLinkTodo_opensTodoTab() {
        assertDeepLinkResolves("xzg://todo")
        rule.waitUntil(10_000) {
            rule.onAllNodesWithTag("todo.screen")
                .fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithTag("todo.screen").assertIsDisplayed()
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
