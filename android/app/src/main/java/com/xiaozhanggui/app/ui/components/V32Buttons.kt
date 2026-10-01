package com.xiaozhanggui.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * V32 主按钮。对应 iOS `V32PrimaryButton`：全宽胶囊、品牌色底、白色 headline 文案、
 * 纵向 padding 14。禁用态为中性底 + 三级文本（iOS 侧无显式禁用样式，此为合理补齐）。
 */
@Composable
fun V32PrimaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    val palettes = LocalXzgPalettes.current
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(if (enabled) palettes.accent.accent else palettes.background.neutralSoft)
            .v32PressFeedback(enabled = enabled, onClick = onClick)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            style = XzgType.headline,
            color = if (enabled) palettes.accent.onAccent else palettes.background.textTertiary
        )
    }
}

/**
 * V32 次按钮。对应 iOS `V32SecondaryButton`：全宽胶囊、卡片底 + 1dp cardOutline 描边、
 * 主文本色。
 */
@Composable
fun V32SecondaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    val palettes = LocalXzgPalettes.current
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(if (enabled) palettes.background.card else palettes.background.neutralSoft)
            .border(1.dp, palettes.background.cardOutline, CircleShape)
            .v32PressFeedback(enabled = enabled, onClick = onClick)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            style = XzgType.headline,
            color = if (enabled) palettes.background.textPrimary else palettes.background.textTertiary
        )
    }
}

/**
 * V32 圆形勾选。对应 iOS `V32Checkbox`：26dp 圆形；选中为品牌色实心 + 白色对勾，
 * 未选中为透明底 + 1.6dp 三级文本描边（0.55 透明度）。
 */
@Composable
fun V32Checkbox(checked: Boolean, onCheckedChange: () -> Unit, modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    Box(
        modifier = modifier
            .size(XzgDimens.checkbox)
            .clip(CircleShape)
            .background(if (checked) palettes.accent.accent else Color.Transparent)
            .then(
                if (checked) Modifier
                else Modifier.border(
                    1.6.dp,
                    palettes.background.textTertiary.copy(alpha = 0.55f),
                    CircleShape
                )
            )
            .v32PressFeedback(onClick = onCheckedChange),
        contentAlignment = Alignment.Center
    ) {
        if (checked) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(13.dp)
            )
        }
    }
}
