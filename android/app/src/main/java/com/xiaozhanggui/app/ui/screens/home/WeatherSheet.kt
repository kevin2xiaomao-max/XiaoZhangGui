package com.xiaozhanggui.app.ui.screens.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.WbCloudy
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.xiaozhanggui.app.ui.components.V32SecondaryButton
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 天气详情 Sheet（对应 iOS `WeatherDetailSheet`，.medium 高度）。
 *
 * Phase 5 接入真实天气数据前：温度显示 "--°" 占位，
 * 并明确说明「天气服务将于 Phase 5 接入 WeatherAPI」。不留空 Sheet。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WeatherSheet(onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    val bg = palettes.background

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = bg.pageBG,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 标题栏：「当前天气」居中 + 右上关闭
            Box(modifier = Modifier.fillMaxWidth()) {
                Text(
                    "当前天气",
                    style = XzgType.headline,
                    color = bg.textPrimary,
                    modifier = Modifier.align(Alignment.Center)
                )
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier.align(Alignment.CenterEnd)
                ) {
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = "关闭",
                        tint = bg.textTertiary
                    )
                }
            }

            // 温度占位
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    Icons.Filled.WbCloudy,
                    contentDescription = null,
                    tint = bg.textSecondary,
                    modifier = Modifier.size(40.dp)
                )
                Text(
                    "--°",
                    style = TextStyle(
                        fontSize = 48.sp,
                        fontWeight = FontWeight.Bold,
                        fontFeatureSettings = "tnum"
                    ),
                    color = bg.textPrimary
                )
            }

            // Phase 5 接入说明（Sheet 不留空）
            Text(
                "天气服务将于 Phase 5 接入 WeatherAPI，当前温度为占位展示。",
                style = XzgType.body,
                color = bg.textSecondary
            )

            V32SecondaryButton(
                text = "关闭",
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
