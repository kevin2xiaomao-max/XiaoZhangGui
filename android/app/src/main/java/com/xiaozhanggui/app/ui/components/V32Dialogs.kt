package com.xiaozhanggui.app.ui.components

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 删除确认对话框：标题 + 可选说明；确认按钮为 danger 色"删除"，
 * 取消按钮为次文本色"取消"。
 */
@Composable
fun ConfirmDeleteDialog(title: String, message: String? = null, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = title,
                style = XzgType.headline,
                color = palettes.background.textPrimary
            )
        },
        text = message?.let { msg ->
            {
                Text(
                    text = msg,
                    style = XzgType.body,
                    color = palettes.background.textSecondary
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(
                    text = "删除",
                    style = XzgType.headline,
                    color = palettes.fixed.danger
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(
                    text = "取消",
                    style = XzgType.headline,
                    color = palettes.background.textSecondary
                )
            }
        },
        containerColor = palettes.background.card,
        shape = RoundedCornerShape(XzgDimens.card)
    )
}
