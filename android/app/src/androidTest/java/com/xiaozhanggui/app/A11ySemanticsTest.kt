package com.xiaozhanggui.app

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasContentDescriptionExactly
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.navigation.XzgNavGraph
import com.xiaozhanggui.app.ui.navigation.XzgTab
import com.xiaozhanggui.app.ui.theme.XzgTheme
import com.xiaozhanggui.app.ui.theme.v371.V371TestTags
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 无障碍语义抽查（Phase 3 Worker C）：
 * 四 Tab / AI Sheet / 保存按钮的 TalkBack 可达性。
 *
 * 注意：`testTag(tab.tag)` 挂在 NavigationBarItem 外层 Box 上，
 * contentDescription 经合并语义落在内层可点击节点；断言 TalkBack 实际读到的
 * 值时按 contentDescription 查找合并树节点（这正是无障碍服务遍历的视角）。
 */
@RunWith(AndroidJUnit4::class)
class A11ySemanticsTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun fourTabs_haveContentDescription() {
        rule.setContent { XzgTheme { XzgNavGraph() } }
        rule.waitForIdle()

        // 四个 Tab 在合并语义树中各有且仅有一个 contentDescription 精确节点
        listOf("首页", "待办", "日历", "经营").forEach { label ->
            rule.onNode(hasContentDescriptionExactly(label)).assertIsDisplayed()
        }
        // Tab 本体仍可点（语义不断可达性）
        rule.onNodeWithTag(XzgTab.HOME.tag).assertIsDisplayed()
    }

    @Test
    fun aiSheet_inputHasAccessibleLabel() {
        rule.setContent { XzgTheme { XzgNavGraph() } }
        rule.waitForIdle()

        rule.onNodeWithTag(V371TestTags.HOME_AI).performClick()
        rule.waitForIdle()

        rule.onNodeWithTag("ai.sheet").assertIsDisplayed()
        rule.onNode(hasContentDescriptionExactly("问小掌柜，输入问题或记账"))
            .assertIsDisplayed()
    }

    @Test
    fun todoEditor_saveAndCancel_areExposedAndClickable() {
        rule.setContent { XzgTheme { XzgNavGraph() } }
        rule.waitForIdle()

        // 待办 Tab → 顶部栏「新增待办」
        rule.onNodeWithTag(XzgTab.TODO.tag).performClick()
        rule.waitForIdle()
        rule.onNode(hasContentDescriptionExactly("新增待办")).performClick()
        rule.waitForIdle()

        // 编辑器 Sheet 已打开（标题可达）
        rule.onNodeWithText("新增待办").assertIsDisplayed()

        // 保存按钮：文字即 TalkBack 标签；先滚动到可见再断言可点击。
        // 取消语义同样存在（保存/取消语义与 Reduce Motion 开关无关）。
        rule.onNodeWithText("保存").performScrollTo()
            .assertIsDisplayed().assertHasClickAction()
        rule.onNodeWithText("取消").assertIsDisplayed().assertHasClickAction()
    }
}
