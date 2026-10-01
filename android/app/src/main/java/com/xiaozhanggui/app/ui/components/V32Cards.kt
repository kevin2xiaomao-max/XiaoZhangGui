package com.xiaozhanggui.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * V32 普通卡片。对应 iOS `V32Card`：padding 16.dp（cardPad）、圆角 18、
 * card 底、cardOutline 1dp 描边，全宽左对齐。
 */
@Composable
fun V32Card(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val palettes = LocalXzgPalettes.current
    val shape = RoundedCornerShape(XzgDimens.card)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(palettes.background.card)
            .border(1.dp, palettes.background.cardOutline, shape)
            .padding(XzgDimens.cardPad),
        content = content
    )
}

/**
 * V32 区块标题。对应 iOS `V32SectionHeader`：section 字阶 + 主文本色，
 * 右侧可选 trailing 操作区。
 */
@Composable
fun V32SectionHeader(title: String, modifier: Modifier = Modifier, trailing: @Composable (() -> Unit)? = null) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = XzgType.section,
            color = palettes.background.textPrimary
        )
        Spacer(Modifier.width(8.dp))
        Spacer(Modifier.weight(1f))
        trailing?.invoke()
    }
}

/**
 * V32 空状态。对应 iOS `V32EmptyState`：中性图标泡 + headline 标题 +
 * subhead 说明；contract 新增的可选操作按钮（actionText + onAction 均非空时显示，
 * 品牌色文本按钮）。
 */
@Composable
fun V32EmptyState(icon: ImageVector, title: String, message: String? = null, actionText: String? = null, onAction: (() -> Unit)? = null) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = XzgDimens.pageMargin)
            .padding(vertical = 36.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        V32IconBubble(icon = icon, tone = BubbleTone.NEUTRAL, size = 56.dp)
        Text(
            text = title,
            style = XzgType.headline,
            color = palettes.background.textSecondary
        )
        if (message != null) {
            Text(
                text = message,
                style = XzgType.subhead,
                color = palettes.background.textTertiary,
                textAlign = TextAlign.Center
            )
        }
        if (actionText != null && onAction != null) {
            TextButton(onClick = onAction) {
                Text(
                    text = actionText,
                    style = XzgType.headline,
                    color = palettes.accent.accent
                )
            }
        }
    }
}

/**
 * V32 指标格。对应 iOS `V32MetricCell`：caption 标签（textTertiary）+
 * metric 数字（textPrimary，等宽数字由 XzgType.metric 自带 tnum）+
 * 可选 caption 说明（textTertiary）。
 */
@Composable
fun V32MetricCell(label: String, value: String, sub: String? = null, modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = XzgType.caption,
            color = palettes.background.textTertiary
        )
        Text(
            text = value,
            style = XzgType.metric,
            color = palettes.background.textPrimary,
            maxLines = 1
        )
        if (sub != null) {
            Text(
                text = sub,
                style = XzgType.caption,
                color = palettes.background.textTertiary,
                maxLines = 1
            )
        }
    }
}
