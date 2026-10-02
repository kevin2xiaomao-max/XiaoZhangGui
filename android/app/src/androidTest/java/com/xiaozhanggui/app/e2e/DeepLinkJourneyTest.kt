package com.xiaozhanggui.app.e2e

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.lifecycle.Lifecycle
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
 * 旅程 3 / 4：深链接（Phase 6 Worker B）。
 *
 * 链路：投递 VIEW intent → MainActivity.onNewIntent → XzgDeepLink →
 * XzgNavGraph(pendingDeepLink) → 切 Tab。
 *
 * - 旅程 3：`xzg://todo` → 待办页可见（断言 todo.screen 节点）。
 *   注意 `todo` host 为本任务新增的 Android 侧扩展（iOS AppDeepLink 无此 host，
 *   见 XzgDeepLink KDoc）。
 * - 旅程 4：`xzg://ai` → 小掌柜页可见（断言 ai.input 节点）。
 *
 * 投递方式说明（Phase 6 修复）：最初用 `am start -a VIEW -d "xzg://…"`
 * （UiDevice shell）投递，但 CI 模拟器（API 30）上该隐式 intent 从未被解析投递——
 * logcat 实证：ActivityTaskManager 收到 START 后同一毫秒直接 INTENT_FAILED，
 * 无任何 Activity 启动、MainActivity.onNewIntent 从未被调用。
 * 而 APK 的 merged manifest 经 aapt 验证确含正确的 intent-filter
 * （VIEW + DEFAULT + BROWSABLE，scheme=xzg，host=ai/voice/quickrecord/quick/todo），
 * 且按 AOSP IntentFilter 源码规则该 intent 应当匹配，故判定为 CI 模拟器
 * system 侧隐式解析的环境问题，非 App bug（XzgDeepLink 解析另有单元测试覆盖）。
 * 因此本测试改为：
 *  1. 用 PackageManager.resolveActivity 断言隐式 intent 能解析到 MainActivity
 *    （即"intent-filter 配对"检查）；
 *  2. 用显式 Component 的 VIEW intent 经 targetContext 投递（绕过坏掉的 am 路径），
 *     仍完整走 MainActivity.onNewIntent → XzgDeepLink → XzgNavGraph 生产链路。
 */
@LargeTest
class DeepLinkJourneyTest {

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
    fun deepLinkTodo_opensTodoTab() {
        fireDeepLink("xzg://todo")
        rule.waitUntil(10_000) {
            rule.onAllNodesWithTag("todo.screen")
                .fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithTag("todo.screen").assertIsDisplayed()
    }

    @Test
    fun deepLinkAi_opensAssistantTab() {
        fireDeepLink("xzg://ai")
        rule.waitUntil(10_000) {
            rule.onAllNodesWithTag("ai.input")
                .fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithTag("ai.input").assertIsDisplayed()
    }

    /**
     * teardown 前把 Activity 带回前台。
     *
     * 根因：[fireDeepLink] 经 Application context + FLAG_ACTIVITY_NEW_TASK 向
     * singleTask 的 MainActivity 投递显式 intent；task 切换可能把 Activity 留在
     * PAUSED（测试本体断言已通过），而 ActivityScenarioRule.after → close()
     * 要求从前台状态走到 DESTROYED，卡在 PAUSED 会超时抛 AssertionError。
     * JUnit 中 @After 在 Rule.after 之前执行，故在此先 moveToState(RESUMED)，
     * 再让 rule 正常关闭。不碰 MainActivity 的 launchMode。
     */
    @After
    fun bringActivityToForeground() {
        try {
            rule.activityRule.scenario.moveToState(Lifecycle.State.RESUMED)
        } catch (e: Exception) {
            // Activity 已销毁或测试中途失败时忽略，避免 teardown 二次抛错掩盖原始失败
        }
    }

    /**
     * 投递深链接并校验 manifest 配对。
     *
     * MainActivity 为 singleTask：已在前台时走 onNewIntent（本测试的场景，
     * rule 已先启动 Activity）。
     */
    private fun fireDeepLink(uri: String) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val pm = context.packageManager

        // 1. 隐式 intent 必须能解析到 MainActivity（manifest intent-filter 配对检查）
        val implicit = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
        val resolved = pm.resolveActivity(implicit, 0)
        assertNotNull("隐式深链接 $uri 未解析到任何 Activity，请检查 Manifest intent-filter", resolved)
        assertEquals(
            "深链接 $uri 解析到了错误的组件",
            MainActivity::class.java.name,
            resolved!!.activityInfo.name
        )

        // 2. 显式投递（绕过 CI 模拟器上 am 隐式投递失败的环境问题）
        val explicit = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
            setClassName(context, MainActivity::class.java.name)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(explicit)
    }
}
