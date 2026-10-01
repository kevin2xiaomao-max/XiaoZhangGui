package com.xiaozhanggui.app.ui.screens.ai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 小掌柜输入栏（文字 + 麦克风 + 发送）。对应 iOS `AI/UI/ChatInputBar.swift`。
 *
 * - onVoice：语音输入回调（语音面板由 Phase 4 语音 worker 实现，此处只暴露回调）；
 * - 发送按钮：有内容且非处理中才可点；
 * - testTag：ai.input / ai.send（与 iOS accessibilityIdentifier 对齐）。
 */
@Composable
fun ChatInputBar(
    text: String,
    onTextChange: (String) -> Unit,
    isProcessing: Boolean,
    voiceAvailable: Boolean,
    onSend: () -> Unit,
    onVoice: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    val canSend = text.isNotBlank() && !isProcessing

    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 语音按钮
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(CircleShape)
                .background(palettes.accent.accentSoft)
                .clickable(enabled = voiceAvailable) { onVoice() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Mic,
                contentDescription = "语音输入",
                tint = if (voiceAvailable) palettes.accent.accent
                else palettes.background.textTertiary,
                modifier = Modifier.size(20.dp)
            )
        }

        Spacer(modifier = Modifier.width(9.dp))

        // 输入框
        Box(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(20.dp))
                .background(palettes.background.card)
                .border(1.dp, palettes.background.cardOutline, RoundedCornerShape(20.dp))
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            if (text.isEmpty()) {
                Text(
                    text = "问小掌柜…（如：今天美团680）",
                    style = XzgType.body,
                    color = palettes.background.textTertiary
                )
            }
            BasicTextField(
                value = text,
                onValueChange = onTextChange,
                textStyle = XzgType.body.copy(color = palettes.background.textPrimary),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { if (canSend) onSend() }),
                modifier = Modifier.testTag("ai.input")
            )
        }

        Spacer(modifier = Modifier.width(9.dp))

        // 发送按钮
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(CircleShape)
                .testTag("ai.send")
                .background(
                    if (canSend) palettes.accent.accent
                    else palettes.background.textTertiary.copy(alpha = 0.35f)
                )
                .clickable(enabled = canSend) { onSend() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.ArrowUpward,
                contentDescription = "发送",
                tint = palettes.accent.onAccent,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}
