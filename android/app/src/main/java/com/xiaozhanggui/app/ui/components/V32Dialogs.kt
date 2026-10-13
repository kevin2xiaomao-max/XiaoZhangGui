package com.xiaozhanggui.app.ui.components

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 删除确认对话框：标题 + 可选说明；确认按钮为 danger 色"删除"，
 * 取消按钮为次文本色"取消"。
 *
 * @param confirmTestTag 确认按钮 testTag（对应 iOS accessibilityIdentifier，如 "goods.delete.confirm"）
 * @param dismissTestTag 取消按钮 testTag（如 "goods.delete.cancel"）
 */
@Composable
fun ConfirmDeleteDialog(
    title: String,
    message: String? = null,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    confirmTestTag: String? = null,
    dismissTestTag: String? = null
) {
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
            TextButton(
                onClick = onConfirm,
                modifier = if (confirmTestTag != null) Modifier.testTag(confirmTestTag) else Modifier
            ) {
                Text(
                    text = "删除",
                    style = XzgType.headline,
                    color = palettes.fixed.danger
                )
            }
        },
        dismissButton = {
            TextButton(
                onClick = onDismiss,
                modifier = if (dismissTestTag != null) Modifier.testTag(dismissTestTag) else Modifier
            ) {
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
