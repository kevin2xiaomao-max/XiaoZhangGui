package com.xiaozhanggui.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * R29 存储不可用态。对应 iOS `XiaoZhangGuiApp` 的 container 初始化失败分支
 *（`ContentUnavailableView("数据存储暂不可用", …)`）：
 * 数据库初始化失败时自动呈现此错误态，不伪装成正常 App（fail-closed）。
 *
 * @param error 探针捕获的异常（展示 localizedMessage；为空则显示通用提示）
 * @param onRetry 重试：重新执行存储探针，成功则回到正常页面
 */
@Composable
fun StorageUnavailableScreen(
    error: Throwable?,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    Scaffold(
        modifier = modifier,
        containerColor = palettes.background.pageBG
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Storage,
                contentDescription = null,
                tint = palettes.background.textTertiary,
                modifier = Modifier.size(56.dp)
            )
            Spacer(Modifier.height(16.dp))
            Text(
                text = "数据存储暂不可用",
                style = XzgType.section,
                color = palettes.background.textPrimary,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = error?.localizedMessage?.takeIf { it.isNotBlank() }
                    ?: "请重新启动应用",
                style = XzgType.body,
                color = palettes.background.textSecondary,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(24.dp))
            V32PrimaryButton(
                text = "重试",
                onClick = onRetry
            )
        }
    }
}
