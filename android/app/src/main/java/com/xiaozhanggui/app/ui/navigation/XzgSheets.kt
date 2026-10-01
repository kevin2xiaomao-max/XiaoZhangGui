package com.xiaozhanggui.app.ui.navigation

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.components.V32SecondaryButton
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * Phase 3 桩 Sheet：快速记一笔 / 语音记一笔。
 *
 * 对应 iOS RootView 级全局 Sheet（QuickRecordSheet / VoiceView，圆角 28，
 * detents 260/340）。Phase 4 实现真正的打开逻辑与表单，当前仅为占位。
 */

@Composable
private fun PhaseStubSheetContent(text: String, onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(top = 12.dp, bottom = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = text,
            style = XzgType.headline,
            color = palettes.background.textSecondary
        )
        Spacer(modifier = Modifier.height(20.dp))
        V32SecondaryButton(
            text = "关闭",
            onClick = onDismiss,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

/** 快速记一笔桩 Sheet（Phase 4 实现）。 */
@Composable
fun QuickRecordStubSheet(onDismiss: () -> Unit) {
    PhaseStubSheetContent(text = "快速记一笔 Phase 4 实现", onDismiss = onDismiss)
}

/** 语音记一笔桩 Sheet（Phase 4 实现）。 */
@Composable
fun VoiceStubSheet(onDismiss: () -> Unit) {
    PhaseStubSheetContent(text = "语音记一笔 Phase 4 实现", onDismiss = onDismiss)
}
