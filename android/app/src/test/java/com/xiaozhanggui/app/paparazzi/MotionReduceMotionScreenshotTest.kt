package com.xiaozhanggui.app.paparazzi

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.components.XzgMotionSpecs
import com.xiaozhanggui.app.ui.components.xzgPressFeedback
import org.junit.Test

/**
 * 四路径接线 `reduceMotionOverride` 测试钩子的 Paparazzi 覆盖。
 *
 * 按钮路径（[xzgPressFeedback]）是四路径中唯一在 JVM 可渲染且含真实分支逻辑
 * （`motionOn = spec.enabled && enabled && !reduceMotion`）的接线；
 * 菜单/弹窗路径的进出动画由框架/平台窗口动画驱动、服从系统 ANIMATOR_DURATION_SCALE，
 * 其 JVM 侧覆盖见 `ui.motion.ReduceMotionTest`（声明 → MotionPolicy 分支）。
 *
 * 本测试渲染 reduceMotionOverride=true/false 两条分支（未按压稳态）：
 * 钩子路径真实执行、无崩溃；动效是运行时行为，静态截图两分支一致即符合预期。
 */
class MotionReduceMotionScreenshotTest : XzgScreenshotTest() {

    @Composable
    private fun PressDemo(reduceMotionOverride: Boolean?) {
        Column(modifier = Modifier.padding(24.dp)) {
            Button(
                onClick = {},
                modifier = Modifier.xzgPressFeedback(
                    spec = XzgMotionSpecs.BUTTON_PRESS,
                    reduceMotionOverride = reduceMotionOverride,
                    onClick = {},
                ),
            ) {
                Text("小掌柜")
            }
        }
    }

    @Test
    fun pressFeedback_reduceMotionOn_light() {
        pageLight("Motion_press_reduce_on") {
            PressDemo(reduceMotionOverride = true)
        }
    }

    @Test
    fun pressFeedback_reduceMotionOff_light() {
        pageLight("Motion_press_reduce_off") {
            PressDemo(reduceMotionOverride = false)
        }
    }

    @Test
    fun pressFeedback_reduceMotionOn_dark() {
        pageDark("Motion_press_reduce_on") {
            PressDemo(reduceMotionOverride = true)
        }
    }
}
