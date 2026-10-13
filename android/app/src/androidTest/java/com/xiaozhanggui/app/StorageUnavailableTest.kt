package com.xiaozhanggui.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.screens.StorageUnavailableScreen
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * R29 存储不可用 fail-closed 触发路径测试（Phase 3 Worker C）。
 *
 * 触发链：MainActivity.onCreate 读取 `XzgGraph.storageError != null`
 * → 呈现 [StorageUnavailableScreen]（不伪装成正常 App）→ 重试回调
 * → `XzgGraph.recheckStorage()` 成功后回到正常导航。
 * 本文件覆盖 UI 侧：错误呈现 + 重试回调可达；XzgGraph 探针逻辑由单测覆盖。
 */
@RunWith(AndroidJUnit4::class)
class StorageUnavailableTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun showsTitle_errorMessage_andRetry() {
        var retried = false
        rule.setContent {
            XzgTheme {
                StorageUnavailableScreen(
                    error = RuntimeException("磁盘已满"),
                    onRetry = { retried = true }
                )
            }
        }

        // fail-closed：明确告知不可用，不渲染正常 App 内容
        rule.onNodeWithText("数据存储暂不可用").assertIsDisplayed()
        // 探针异常信息透出（localizedMessage），便于诊断
        rule.onNodeWithText("磁盘已满").assertIsDisplayed()
        // 重试按钮可达、可点击
        rule.onNodeWithText("重试").assertIsDisplayed().assert(hasClickAction())

        rule.onNodeWithText("重试").performClick()
        rule.waitForIdle()
        assertTrue("重试回调必须被调用（接回 XzgGraph.recheckStorage）", retried)
    }

    @Test
    fun nullError_showsGenericHint() {
        rule.setContent {
            XzgTheme {
                StorageUnavailableScreen(error = null, onRetry = {})
            }
        }

        rule.onNodeWithText("数据存储暂不可用").assertIsDisplayed()
        rule.onNodeWithText("请重新启动应用").assertIsDisplayed()
        rule.onNodeWithText("重试").assertIsDisplayed()
    }
}
