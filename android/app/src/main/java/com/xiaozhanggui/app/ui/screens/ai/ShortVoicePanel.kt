package com.xiaozhanggui.app.ui.screens.ai

import android.provider.Settings
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.voice.ShortVoicePhase
import com.xiaozhanggui.app.domain.voice.QuickCaptureSemantic
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 小掌柜短语音面板（单事项）。对应 iOS `Features/Assistant/AI/UI/ShortVoicePanel.swift`。
 *
 * V371：底部 sheet 式 solid group 面（顶部圆角 24），轻量脉冲/状态 + 转写 + 操作按钮。
 * 状态机由 [com.xiaozhanggui.app.data.voice.ShortVoiceSession] 驱动：
 * 聆听 → final transcript → 与文字相同的 Agent 流程；失败保留原文，可一键填入输入框改写重发。
 *
 * 宿主约定（对应 iOS AIChatView.voiceOverlay）：调用方把本面板放在底部覆盖层中，
 * 背后加 0.28 黑色遮罩（点击遮罩 = onCancel），面板不忽略底部安全区。
 * ASR 不可用时上层直接降级为文字输入，不拉起本面板。
 *
 * @param phase [ShortVoicePhase]（idle/listening/finalizing/failed）
 * @param liveTranscript 实时转写文本
 * @param onStop 手动停止并识别
 * @param onCancel 取消语音（关闭面板）
 * @param onEditText 失败后「填入文字」：把保留原文交回输入框
 */
@Composable
fun ShortVoicePanel(
    phase: ShortVoicePhase,
    liveTranscript: String,
    onStop: () -> Unit,
    onCancel: () -> Unit,
    onEditText: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    val shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(palettes.background.card)
            .border(1.dp, palettes.background.divider, shape)
            .padding(horizontal = 16.dp)
            .padding(top = 22.dp, bottom = 26.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        when (phase) {
            is ShortVoicePhase.Failed ->
                ShortVoiceFailureContent(
                    message = phase.message,
                    liveTranscript = liveTranscript,
                    onEditText = onEditText,
                    onCancel = onCancel
                )
            else ->
                ShortVoiceListeningContent(
                    phase = phase,
                    liveTranscript = liveTranscript,
                    onStop = onStop,
                    onCancel = onCancel
                )
        }
    }
}

@Composable
private fun ShortVoiceListeningContent(
    phase: ShortVoicePhase,
    liveTranscript: String,
    onStop: () -> Unit,
    onCancel: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val context = LocalContext.current
    // Reduce Motion：系统动画缩放为 0（开发者选项/无障碍"移除动画"）时不做脉冲
    val reduceMotion = remember {
        runCatching {
            Settings.Global.getFloat(
                context.contentResolver,
                Settings.Global.TRANSITION_ANIMATION_SCALE,
                1f
            ) == 0f
        }.getOrDefault(false)
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(
            modifier = Modifier.height(92.dp),
            contentAlignment = Alignment.Center
        ) {
            if (reduceMotion) {
                Box(
                    modifier = Modifier
                        .size(84.dp)
                        .clip(CircleShape)
                        .background(palettes.accent.accentSoft),
                    contentAlignment = Alignment.Center
                ) {
                    PhaseIcon(phase = phase)
                }
            } else {
                val transition = rememberInfiniteTransition(label = "shortVoicePulse")
                val scale by transition.animateFloat(
                    initialValue = 0.94f,
                    targetValue = 1.12f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(durationMillis = 900, easing = FastOutSlowInEasing),
                        repeatMode = RepeatMode.Reverse
                    ),
                    label = "pulseScale"
                )
                val pulseAlpha by transition.animateFloat(
                    initialValue = 1f,
                    targetValue = 0.55f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(durationMillis = 900, easing = FastOutSlowInEasing),
                        repeatMode = RepeatMode.Reverse
                    ),
                    label = "pulseAlpha"
                )
                Box(
                    modifier = Modifier
                        .size(84.dp)
                        .scale(scale)
                        .alpha(pulseAlpha)
                        .clip(CircleShape)
                        .background(palettes.accent.accentSoft),
                    contentAlignment = Alignment.Center
                ) {
                    PhaseIcon(phase = phase)
                }
            }
        }

        val transcript = liveTranscript.trim()
        Text(
            text = transcript.ifEmpty { "正在听…说一件事，例如：今晚8点给302送两箱怡宝" },
            style = XzgType.body,
            color = if (transcript.isEmpty()) palettes.background.textTertiary
            else palettes.background.textPrimary,
            textAlign = TextAlign.Center,
            maxLines = 3,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp)
        )

        Text(
            text = if (phase == ShortVoicePhase.Finalizing) QuickCaptureSemantic.PROCESSING
            else "停顿后会自动识别，也可手动停止",
            style = XzgType.caption,
            color = palettes.background.textTertiary
        )

        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(CircleShape)
                    .background(palettes.background.cardInset)
                    .clickable(onClick = onCancel)
                    .semantics { contentDescription = "取消语音" },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = null,
                    tint = palettes.background.textSecondary,
                    modifier = Modifier.size(17.dp)
                )
            }
            val stopEnabled = phase != ShortVoicePhase.Finalizing
            Box(
                modifier = Modifier
                    .size(66.dp)
                    .clip(CircleShape)
                    .background(palettes.accent.accent)
                    .alpha(if (stopEnabled) 1f else 0.6f)
                    .clickable(enabled = stopEnabled, onClick = onStop)
                    .semantics { contentDescription = "停止并识别" },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Stop,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}

@Composable
private fun PhaseIcon(phase: ShortVoicePhase) {
    val palettes = LocalXzgPalettes.current
    Icon(
        imageVector = if (phase == ShortVoicePhase.Finalizing) Icons.Filled.AutoAwesome
        else Icons.Filled.Mic,
        contentDescription = null,
        tint = palettes.accent.accent,
        modifier = Modifier.size(30.dp)
    )
}

@Composable
private fun ShortVoiceFailureContent(
    message: String,
    liveTranscript: String,
    onEditText: () -> Unit,
    onCancel: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(CircleShape)
                .background(palettes.fixed.amberSoft),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Warning,
                contentDescription = null,
                tint = palettes.fixed.amber,
                modifier = Modifier.size(26.dp)
            )
        }
        Text(
            text = "${QuickCaptureSemantic.FAILED}：$message",
            style = XzgType.subhead,
            color = palettes.background.textSecondary,
            textAlign = TextAlign.Center
        )
        if (liveTranscript.isNotEmpty()) {
            Text(
                text = "已保留：$liveTranscript",
                style = XzgType.caption,
                color = palettes.background.textTertiary,
                maxLines = 2,
                textAlign = TextAlign.Center
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(CircleShape)
                    .background(palettes.accent.accentSoft)
                    .clickable(onClick = onEditText)
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Keyboard,
                    contentDescription = null,
                    tint = palettes.accent.accent,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = "填入文字",
                    style = XzgType.subhead.copy(fontWeight = FontWeight.SemiBold),
                    color = palettes.accent.accent
                )
            }
            Row(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(CircleShape)
                    .background(palettes.background.cardInset)
                    .clickable(onClick = onCancel)
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = null,
                    tint = palettes.background.textSecondary,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = "关闭",
                    style = XzgType.subhead.copy(fontWeight = FontWeight.SemiBold),
                    color = palettes.background.textSecondary
                )
            }
        }
    }
}
