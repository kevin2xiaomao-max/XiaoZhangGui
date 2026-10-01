package com.xiaozhanggui.app.paparazzi

import androidx.compose.runtime.Composable
import app.cash.paparazzi.DeviceConfig
import app.cash.paparazzi.Paparazzi
import com.xiaozhanggui.app.data.datastore.ThemeMode
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Rule

/**
 * Paparazzi 截图基类（Phase 5 Visual Gate）。
 *
 * 约定（两个 worker 共用）：
 * - 测试类继承此类，按页面/组件写 @Test 方法
 * - 方法命名：`{screen}Light` / `{screen}Dark`（如 `homeLight`），生成文件
 *   `XxxScreenshotTest_homelight.png`；为满足 `{Screen}_light.png` 命名要求，
 *   请用 `snapshot(name = "Home_light")` / `snapshot(name = "Home_dark")` 显式命名
 * - 内容一律用 XzgTheme 包裹，light 用 ThemeMode.LIGHT，dark 用 ThemeMode.DARK
 * - 数据用手写假数据，不得依赖真数据库 / DataStore / 网络
 * - 设备：PIXEL_6 竖屏；Sheet 类用底部对齐渲染（调用 sheet() helper）
 */
abstract class XzgScreenshotTest {

    @get:Rule
    val paparazzi = Paparazzi(
        deviceConfig = DeviceConfig.PIXEL_6,
        // CI 与本地渲染一致性：关闭动画
        showSystemUi = false
    )

    /** 页面级截图：XzgTheme 包裹全屏内容 */
    protected fun page(name: String, dark: Boolean, content: @Composable () -> Unit) {
        paparazzi.snapshot(name = name) {
            XzgTheme(themeMode = if (dark) ThemeMode.DARK else ThemeMode.LIGHT) {
                content()
            }
        }
    }

    protected fun pageLight(name: String, content: @Composable () -> Unit) =
        page(name = "${name}_light", dark = false, content = content)

    protected fun pageDark(name: String, content: @Composable () -> Unit) =
        page(name = "${name}_dark", dark = true, content = content)
}
