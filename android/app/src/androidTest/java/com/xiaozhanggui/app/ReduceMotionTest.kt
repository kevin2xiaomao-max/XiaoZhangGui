package com.xiaozhanggui.app

import android.content.Context
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Text
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.ui.theme.XzgTheme
import com.xiaozhanggui.app.ui.theme.isReduceMotionEnabled
import com.xiaozhanggui.app.ui.theme.rememberReduceMotion
import com.xiaozhanggui.app.ui.theme.rememberXzgModalBottomSheetState
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Reduce Motion 接线测试（Phase 3 Worker C）。
 *
 * 验证链路：系统设置（Settings.Global.ANIMATOR_DURATION_SCALE）
 * → [rememberReduceMotion] → [rememberXzgModalBottomSheetState]。
 */
@OptIn(ExperimentalMaterial3Api::class)
@RunWith(AndroidJUnit4::class)
class ReduceMotionTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun systemSetting_isWiredToComposable() {
        // 系统设置的真实值（模拟器默认 1f → false；用户开启「移除动画」后为 0f → true）
        val context = ApplicationProvider.getApplicationContext<Context>()
        val expected = isReduceMotionEnabled(context)

        rule.setContent {
            XzgTheme {
                val reduceMotion = rememberReduceMotion()
                Text(if (reduceMotion) "RM-ON" else "RM-OFF")
            }
        }

        // composable 读到的值必须与直接读系统设置一致：接线不断
        rule.onNodeWithText(if (expected) "RM-ON" else "RM-OFF").assertIsDisplayed()
    }

    @Test
    fun sheetState_initialValue_respectsReduceMotion() {
        var onValue: SheetValue? = null
        var offValue: SheetValue? = null
        rule.setContent {
            XzgTheme {
                // reduceMotionOverride 为测试钩子：验证「开关 → Sheet 初始态」的分支逻辑
                onValue = rememberXzgModalBottomSheetState(reduceMotionOverride = true).currentValue
                offValue = rememberXzgModalBottomSheetState(reduceMotionOverride = false).currentValue
            }
        }
        rule.waitForIdle()

        // 开启 → 直接 Expanded（跳过滑入动画）；关闭 → Hidden（走框架默认滑入）
        assertEquals(SheetValue.Expanded, onValue)
        assertEquals(SheetValue.Hidden, offValue)
    }
}
