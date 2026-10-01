package com.xiaozhanggui.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.xiaozhanggui.app.ui.navigation.XzgNavGraph
import com.xiaozhanggui.app.ui.theme.XzgTheme

/**
 * 主 Activity。对应 iOS `App/RootView.swift` + `XiaoZhangGuiApp.swift`。
 *
 * - edge-to-edge：对应 iOS 全面屏安全区；iOS 26 `.tabBarMinimizeBehavior` 的
 *   下滑隐藏行为在 Phase 5 用 nestedScroll 实现。
 * - 深链接 xzg://（ai/voice/quickrecord/quick）：Manifest 已注册 intent-filter；
 *   onNewIntent 分发在 Phase 4（语音/速记全局 Sheet）实现。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            XzgTheme {
                XzgNavGraph()
            }
        }
    }
}
