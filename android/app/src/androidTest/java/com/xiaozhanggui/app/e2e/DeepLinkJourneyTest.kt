package com.xiaozhanggui.app.e2e

import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.filters.LargeTest
import com.xiaozhanggui.app.MainActivity
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test

/**
 * 旅程 3 / 4：深链接（Phase 6 Worker B）。
 *
 * 用 `am start -a android.intent.action.VIEW -d "xzg://..."`（与任务要求的
 * adb 命令等价，UiDevice.executeShellCommand 以 shell 身份执行）调起，
 * 走 MainActivity.onNewIntent → XzgDeepLink → XzgNavGraph 完整链路。
 *
 * - 旅程 3：`xzg://todo` → 待办页可见（断言 todo.screen 节点）。
 *   注意 `todo` host 为本任务新增的 Android 侧扩展（iOS AppDeepLink 无此 host，
 *   见 XzgDeepLink KDoc）。
 * - 旅程 4：`xzg://ai` → 小掌柜页可见（断言 ai.input 节点）。
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
        E2EBase.device().executeShellCommand(
            "am start -a android.intent.action.VIEW -d \"xzg://todo\""
        )
        rule.waitUntil(10_000) {
            rule.onAllNodesWithTag("todo.screen")
                .fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithTag("todo.screen").assertIsDisplayed()
    }

    @Test
    fun deepLinkAi_opensAssistantTab() {
        E2EBase.device().executeShellCommand(
            "am start -a android.intent.action.VIEW -d \"xzg://ai\""
        )
        rule.waitUntil(10_000) {
            rule.onAllNodesWithTag("ai.input")
                .fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithTag("ai.input").assertIsDisplayed()
    }
}
