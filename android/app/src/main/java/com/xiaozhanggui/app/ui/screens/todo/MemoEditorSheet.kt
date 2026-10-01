package com.xiaozhanggui.app.ui.screens.todo

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.ui.components.PhotoPickerField
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import kotlinx.coroutines.launch

/**
 * 备忘编辑 Sheet（新增/编辑共用，memo == null 为新增）。
 * 对应 iOS MemoEditorSheet：标题 + 内容（"记点什么…"，4 行）+ PhotoPickerField。
 * 保存条件：标题或内容任一非空；长度上限由 Repository 层静默截断
 * （标题 ≤100、内容 ≤2000）。保存失败弹窗「保存失败」。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoEditorSheet(
    memo: MemoEntity?,
    onDismiss: () -> Unit,
    onSave: suspend (title: String, content: String, imagePath: String?) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(XzgDimens.sheet),
        containerColor = palettes.background.pageBG
    ) {
        MemoEditorContent(
            memo = memo,
            onDismiss = onDismiss,
            onSave = onSave
        )
    }
}

/**
 * 备忘编辑 Sheet 纯渲染内容（不含 ModalBottomSheet 包裹，供 Paparazzi 截图用）。
 * 状态逻辑与 MemoEditorSheet 完全一致，仅剥离手势容器。
 */
@Composable
internal fun MemoEditorContent(
    memo: MemoEntity?,
    onDismiss: () -> Unit,
    onSave: suspend (title: String, content: String, imagePath: String?) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()

    var title by remember(memo) { mutableStateOf(memo?.title ?: "") }
    var content by remember(memo) { mutableStateOf(memo?.content ?: "") }
    var imagePath by remember(memo) { mutableStateOf(memo?.imagePath) }
    var saving by remember { mutableStateOf(false) }
    var showSaveError by remember { mutableStateOf(false) }

    val canSave = (title.trim().isNotEmpty() || content.trim().isNotEmpty()) && !saving

    fun doSave() {
        if (!canSave) return
        scope.launch {
            saving = true
            val ok = try {
                onSave(title.trim(), content.trim(), imagePath)
                true
            } catch (e: Exception) {
                false
            }
            saving = false
            if (ok) onDismiss() else showSaveError = true
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = XzgDimens.pageMargin)
            .padding(bottom = 24.dp)
    ) {
            SheetHeader(
                title = if (memo == null) "新增备忘" else "编辑备忘",
                onCancel = onDismiss,
                cancelColor = palettes.background.textTertiary
            )

            V32SectionHeader(title = "标题")
            Spacer(Modifier.height(8.dp))
            V32Card {
                XzgSheetTextField(
                    value = title,
                    onValueChange = { title = it },
                    placeholder = "记录标题",
                    singleLine = true
                )
            }

            Spacer(Modifier.height(12.dp))

            V32SectionHeader(title = "内容")
            Spacer(Modifier.height(8.dp))
            V32Card {
                XzgSheetTextField(
                    value = content,
                    onValueChange = { content = it },
                    placeholder = "记点什么…",
                    minLines = 4,
                    maxLines = 8
                )
            }

            Spacer(Modifier.height(12.dp))

            V32SectionHeader(title = "图片")
            Spacer(Modifier.height(8.dp))
            PhotoPickerField(
                imagePath = imagePath,
                onPick = { imagePath = it },
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(16.dp))

            V32PrimaryButton(
                text = "保存",
                onClick = { doSave() },
                modifier = Modifier.fillMaxWidth(),
                enabled = canSave
            )
    }

    if (showSaveError) {
        SaveFailedDialog(
            message = "备忘未保存，请重试。",
            onRetry = {
                showSaveError = false
                doSave()
            },
            onCancel = { showSaveError = false }
        )
    }
}
