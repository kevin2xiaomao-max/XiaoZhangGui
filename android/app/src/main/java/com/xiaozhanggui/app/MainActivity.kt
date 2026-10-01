package com.xiaozhanggui.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.xiaozhanggui.app.ui.navigation.DeepLinkAction
import com.xiaozhanggui.app.ui.navigation.XzgDeepLink
import com.xiaozhanggui.app.ui.navigation.XzgNavGraph
import com.xiaozhanggui.app.ui.theme.XzgTheme

/**
 * 主 Activity。对应 iOS `App/RootView.swift` + `XiaoZhangGuiApp.swift`。
 *
 * - edge-to-edge：对应 iOS 全面屏安全区；iOS 26 `.tabBarMinimizeBehavior` 的
 *   下滑隐藏行为在 Phase 5 用 nestedScroll 实现。
 * - 深链接 xzg://（ai/voice/quickrecord/quick）：Manifest 已注册 intent-filter；
 *   onCreate(intent) 与 onNewIntent 解析 `intent.data`，经 [XzgDeepLink.handle]
 *   得到 [DeepLinkAction] 后暂存为 [pendingDeepLink] 传给 [XzgNavGraph]，
 *   NavGraph 消费后经 onDeepLink 回调通知此处清空（launchMode=singleTask，
 *   后台调起走 onNewIntent）。
 */
class MainActivity : ComponentActivity() {

    private var pendingDeepLink by mutableStateOf<DeepLinkAction?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        pendingDeepLink = intent?.data?.let { XzgDeepLink.handle(it) }
            ?.takeIf { it != DeepLinkAction.Ignore }
        setContent {
            XzgTheme {
                XzgNavGraph(
                    deepLinkAction = pendingDeepLink,
                    onDeepLink = { pendingDeepLink = null }
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.let { XzgDeepLink.handle(it) }
            ?.takeIf { it != DeepLinkAction.Ignore }
            ?.let { pendingDeepLink = it }
    }
}
