package com.xiaozhanggui.app.ui.screens.profile

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.delay

/**
 * 底部 Toast（自定义实现，非系统 Toast / Snackbar）。
 *
 * 对应 iOS ProfileView 的 toast：底部 overlay 胶囊卡片，2 秒自动消失。
 */
class ToastState internal constructor() {
    var message: String? by mutableStateOf(null)
        private set

    fun show(msg: String) {
        message = msg
    }

    internal fun clear() {
        message = null
    }
}

@Composable
fun rememberToastState(): ToastState = remember { ToastState() }

/**
 * Toast 宿主：放在页面最上层（Box 内最后绘制），消息 2 秒后自动消失。
 * 不拦截触摸事件。
 */
@Composable
fun XzgToastHost(
    state: ToastState,
    modifier: Modifier = Modifier,
) {
    val palettes = LocalXzgPalettes.current
    val message = state.message
    if (message != null) {
        LaunchedEffect(message) {
            delay(2000)
            state.clear()
        }
        Box(
            modifier = modifier.fillMaxSize(),
            contentAlignment = Alignment.BottomCenter
        ) {
            Surface(
                shape = CircleShape,
                color = palettes.background.textPrimary.copy(alpha = 0.92f),
                modifier = Modifier.padding(bottom = 96.dp)
            ) {
                Text(
                    text = message,
                    style = XzgType.subhead,
                    color = Color.White,
                    modifier = Modifier.padding(horizontal = 18.dp, vertical = 10.dp)
                )
            }
        }
    }
}
