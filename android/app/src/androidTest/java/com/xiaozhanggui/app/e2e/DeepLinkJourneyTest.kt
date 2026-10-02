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
 *  2. 用显式 Component 的 VIEW intent 经 rule 的前台 Activity 直接投递
 *     （不带 FLAG_ACTIVITY_NEW_TASK，绕过坏掉的 am 路径，且避免 task 切换
 *     把 Activity 晾在 PAUSED 致 teardown 失败），仍完整走
 *     MainActivity.onNewIntent → XzgDeepLink → XzgNavGraph 生产链路。
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

    // 注意：teardown 由 ActivityScenarioRule 自动处理（close → DESTROYED）。
    // fireDeepLink 已改为直接调 onNewIntent，无 task 切换，Activity 全程 RESUMED。

    /**
     * 投递深链接并校验 manifest 配对。
     *
     * MainActivity 为 singleTask：已在前台时走 onNewIntent（本测试的场景，
     * rule 已先启动 Activity）。
     *
     * 投递方式（Phase 6 第三轮修复）：显式 intent 经 rule 的 Activity（前台
     * Activity context）直接 startActivity，**不带 FLAG_ACTIVITY_NEW_TASK**。
     * 根因：之前经 Application context + NEW_TASK 投递，task 切换把 Activity
     * 晾在 PAUSED，测试本体断言虽通过，但 ActivityScenarioRule.after → close()
     * 走不到 DESTROYED，teardown 抛 AssertionError。从前台 Activity context
     * 向 singleTask 的自己投递 → 走 onNewIntent，无 task 切换，Activity 全程
     * RESUMED，rule 可正常关闭。不碰 MainActivity 的 launchMode。
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

        // 2. 直接调用 onNewIntent（绕过 ActivityManager 的 task 调度）：
        //    CI 模拟器上经 startActivity 投递（无论是否带 NEW_TASK）都会把
        //    Activity 晾在 PAUSED，致 ActivityScenarioRule.after → close() 失败。
        //    直接调 onNewIntent 仍完整走生产链路
        //    MainActivity.onNewIntent → XzgDeepLink → XzgNavGraph(pendingDeepLink)。
        //    用 rule.runOnUiThread 而非 scenario.onActivity：后者在 CI 模拟器上
        //    疑与 rule 的 teardown 产生死锁（Activity 卡在 RESUMED 关不掉）。
        val explicit = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
            setClassName(context, MainActivity::class.java.name)
        }
        rule.runOnUiThread {
            rule.activity.onNewIntent(explicit)
        }
    }
}
