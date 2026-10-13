package com.xiaozhanggui.app

import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasContentDescriptionExactly
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
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
 */
@RunWith(AndroidJUnit4::class)
class A11ySemanticsTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun fourTabs_haveContentDescription() {
        rule.setContent { XzgTheme { XzgNavGraph() } }
        rule.waitForIdle()

        mapOf(
            XzgTab.HOME to "首页",
            XzgTab.TODO to "待办",
            XzgTab.CALENDAR to "日历",
            XzgTab.BUSINESS to "经营",
        ).forEach { (tab, label) ->
            rule.onNodeWithTag(tab.tag).assert(hasContentDescriptionExactly(label))
        }
    }

    @Test
    fun aiSheet_inputHasAccessibleLabel() {
        rule.setContent { XzgTheme { XzgNavGraph() } }
        rule.waitForIdle()

        rule.onNodeWithTag(V371TestTags.HOME_AI).performClick()
        rule.waitForIdle()

        rule.onNodeWithTag("ai.sheet").assertIsDisplayed()
        rule.onNodeWithTag("ai.input")
            .assert(hasContentDescriptionExactly("问小掌柜，输入问题或记账"))
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

        // 保存按钮：文字即 TalkBack 标签，可点击；取消语义同样存在
        //（保存/取消语义与 Reduce Motion 开关无关）
        rule.onNodeWithText("保存").assertIsDisplayed().assert(hasClickAction())
        rule.onNodeWithText("取消").assertIsDisplayed().assert(hasClickAction())
    }
}
