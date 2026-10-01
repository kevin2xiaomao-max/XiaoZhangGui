package com.xiaozhanggui.app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha

/**
 * V32 按压反馈：对应 iOS `V32PressButtonStyle`（pressed → opacity 0.82）。
 *
 * 按压缩放效果按约定用简单的 clickable + alpha 代替，不引入复杂动画库。
 */
@Composable
fun Modifier.v32PressFeedback(enabled: Boolean = true, onClick: () -> Unit): Modifier {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    return this
        .alpha(if (pressed) 0.82f else 1f)
        .clickable(
            interactionSource = interactionSource,
            indication = null,
            enabled = enabled,
            onClick = onClick
        )
}
