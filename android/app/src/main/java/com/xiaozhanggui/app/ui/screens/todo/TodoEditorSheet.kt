package com.xiaozhanggui.app.ui.screens.todo

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.PhotoPickerField
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SegmentedPicker
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlinx.coroutines.launch

/**
 * Sheet 头：左上"取消" + 居中标题。对应 iOS 各 EditorSheet 的导航栏样式。
 */
@Composable
internal fun SheetHeader(title: String, onCancel: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
    ) {
        TextButton(
            onClick = onCancel,
            modifier = Modifier.align(Alignment.CenterStart)
        ) {
            Text(
                text = "取消",
                style = XzgType.body,
                color = palettes.accent.accent
            )
        }
        Text(
            text = title,
            style = XzgType.headline,
            color = palettes.background.textPrimary,
            modifier = Modifier.align(Alignment.Center)
        )
    }
}

/** Sheet 内无边框输入框（透明底，放在 V32Card 内使用）。 */
@Composable
internal fun XzgSheetTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = false,
    minLines: Int = 1,
    maxLines: Int = Int.MAX_VALUE
) {
    val palettes = LocalXzgPalettes.current
    TextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = {
            Text(
                text = placeholder,
                style = XzgType.body,
                color = palettes.background.textQuaternary
            )
        },
        singleLine = singleLine,
        minLines = minLines,
        maxLines = maxLines,
        textStyle = XzgType.body.copy(color = palettes.background.textPrimary),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            disabledContainerColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            cursorColor = palettes.accent.accent,
            focusedTextColor = palettes.background.textPrimary,
            unfocusedTextColor = palettes.background.textPrimary
        ),
        modifier = modifier.fillMaxWidth()
    )
}

/** 保存失败弹窗：标题「保存失败」+ 重试/取消。对应 iOS 各 EditorSheet 的保存失败 alert。 */
@Composable
internal fun SaveFailedDialog(
    message: String,
    onRetry: () -> Unit,
    onCancel: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    AlertDialog(
        onDismissRequest = onCancel,
        title = {
            Text(
                text = "保存失败",
                style = XzgType.headline,
                color = palettes.background.textPrimary
            )
        },
        text = {
            Text(
                text = message,
                style = XzgType.body,
                color = palettes.background.textSecondary
            )
        },
        confirmButton = {
            TextButton(onClick = onRetry) { Text("重试") }
        },
        dismissButton = {
            TextButton(onClick = onCancel) { Text("取消") }
        },
        containerColor = palettes.background.card
    )
}

/**
 * 待办编辑 Sheet（新增/编辑共用，todo == null 为新增）。
 * 对应 iOS TodoEditorSheet：标题（必填）+ 补充说明 + 截止开关（默认今日 9:00）+
 * DatePicker（日期+时分）+ 优先级三段（默认低）+ PhotoPickerField。
 * 标题为空时保存按钮不可点；保存失败弹窗「保存失败」。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodoEditorSheet(
    todo: TodoEntity?,
    onDismiss: () -> Unit,
    onSave: suspend (title: String, detail: String, dueDate: Long?, priority: Int, imagePath: String?) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    var title by remember(todo) { mutableStateOf(todo?.title ?: "") }
    var detail by remember(todo) { mutableStateOf(todo?.detail ?: "") }
    // 新增时开关默认开、时间为今日 9:00；编辑时按已有 dueDate 回填
    var hasDueDate by remember(todo) { mutableStateOf(todo?.dueDate != null || todo == null) }
    var dueDate by remember(todo) {
        mutableStateOf(todo?.dueDate ?: DateExt.atTime(System.currentTimeMillis(), 9, 0))
    }
    var priority by remember(todo) { mutableStateOf(todo?.priority?.coerceIn(0, 2) ?: 0) }
    var imagePath by remember(todo) { mutableStateOf(todo?.imagePath) }
    var saving by remember { mutableStateOf(false) }
    var showSaveError by remember { mutableStateOf(false) }

    val canSave = title.trim().isNotEmpty() && !saving

    fun pickDateTime() {
        val zdt = ZonedDateTime.ofInstant(Instant.ofEpochMilli(dueDate), ZoneId.systemDefault())
        DatePickerDialog(
            context,
            { _, year, month, day ->
                TimePickerDialog(
                    context,
                    { _, hour, minute ->
                        dueDate = ZonedDateTime
                            .of(year, month + 1, day, hour, minute, 0, 0, ZoneId.systemDefault())
                            .toInstant()
                            .toEpochMilli()
                    },
                    zdt.hour,
                    zdt.minute,
                    true
                ).show()
            },
            zdt.year,
            zdt.monthValue - 1,
            zdt.dayOfMonth
        ).show()
    }

    fun doSave() {
        val t = title.trim()
        if (t.isEmpty() || saving) return
        scope.launch {
            saving = true
            val ok = try {
                onSave(t, detail.trim(), if (hasDueDate) dueDate else null, priority, imagePath)
                true
            } catch (e: Exception) {
                false
            }
            saving = false
            if (ok) onDismiss() else showSaveError = true
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(XzgDimens.sheet),
        containerColor = palettes.background.pageBG
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = XzgDimens.pageMargin)
                .padding(bottom = 24.dp)
        ) {
            SheetHeader(
                title = if (todo == null) "新增待办" else "编辑待办",
                onCancel = onDismiss
            )

            V32Card {
                Column {
                    XzgSheetTextField(
                        value = title,
                        onValueChange = { title = it },
                        placeholder = "要做什么？",
                        singleLine = true
                    )
                    HorizontalDivider(color = palettes.background.divider)
                    XzgSheetTextField(
                        value = detail,
                        onValueChange = { detail = it },
                        placeholder = "补充说明（可选）",
                        minLines = 3,
                        maxLines = 6
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            V32Card {
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "设置截止时间",
                            style = XzgType.body,
                            color = palettes.background.textPrimary,
                            modifier = Modifier.weight(1f)
                        )
                        Switch(
                            checked = hasDueDate,
                            onCheckedChange = { hasDueDate = it }
                        )
                    }
                    if (hasDueDate) {
                        Spacer(Modifier.height(4.dp))
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(onClick = { pickDateTime() })
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Schedule,
                                contentDescription = null,
                                tint = palettes.accent.accent,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = Format.dateTime(dueDate),
                                style = XzgType.body,
                                color = palettes.accent.accent,
                                modifier = Modifier.weight(1f)
                            )
                            Icon(
                                imageVector = Icons.Filled.ChevronRight,
                                contentDescription = "选择时间",
                                tint = palettes.background.textTertiary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            Text(
                text = "优先级",
                style = XzgType.subhead,
                color = palettes.background.textSecondary,
                modifier = Modifier.padding(start = 4.dp, bottom = 8.dp)
            )
            V32SegmentedPicker(
                options = listOf("低", "中", "高"),
                selectedIndex = priority,
                onSelect = { priority = it },
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(12.dp))

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
    }

    if (showSaveError) {
        SaveFailedDialog(
            message = "内容未保存，请重试。",
            onRetry = {
                showSaveError = false
                doSave()
            },
            onCancel = { showSaveError = false }
        )
    }
}
