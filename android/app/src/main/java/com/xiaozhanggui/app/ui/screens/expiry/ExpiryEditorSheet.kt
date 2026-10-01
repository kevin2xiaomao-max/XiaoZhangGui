package com.xiaozhanggui.app.ui.screens.expiry

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.PhotoPickerField
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.components.V32SegmentedPicker
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.launch

/**
 * 临期商品新增/编辑 Sheet。对应 iOS Expiry/ExpiryEditorSheet.swift。
 *
 * - 商品名称（必填，保存时静默截断 ≤100）
 * - 数量：Stepper +/-（1..9999）+ 数字输入框
 * - 到期日期：DatePickerDialog，不可选过去日期
 * - 提前提醒：三段 3天 / 7天 / 15天，默认 7（仅用于通知调度，不参与分组）
 * - 备注（保存时截断 ≤200）+ PhotoPickerField
 * - 名称非空且数量 > 0 可保存；保存失败弹 alert
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExpiryEditorSheet(
    item: ExpiryItemEntity?,
    onDismiss: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val repo = XzgGraph.expiryRepository
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palettes.background.pageBG
    ) {
        ExpiryEditorContent(
            item = item,
            onDismiss = onDismiss,
            onSave = { existing, name, quantity, expiryDate, remindDays, note, imagePath ->
                if (existing != null) {
                    repo.update(
                        existing.copy(
                            name = name,
                            quantity = quantity,
                            expiryDate = expiryDate,
                            remindDaysBefore = remindDays,
                            note = note,
                            imagePath = imagePath
                        )
                    )
                } else {
                    repo.add(
                        name = name,
                        quantity = quantity,
                        expiryDate = expiryDate,
                        remindDaysBefore = remindDays,
                        note = note,
                        imagePath = imagePath
                    )
                }
            }
        )
    }
}

/**
 * 临期商品编辑 Sheet 纯渲染内容（不含 ModalBottomSheet 包裹，供 Paparazzi 截图用）。
 * 状态逻辑与 ExpiryEditorSheet 完全一致，仅剥离手势容器与 Repository 写入
 * （写入经 [onSave] 回调交由外层执行；名称 ≤100、备注 ≤200 的静默截断保留在内容侧）。
 */
@Composable
internal fun ExpiryEditorContent(
    item: ExpiryItemEntity?,
    onDismiss: () -> Unit,
    onSave: suspend (
        item: ExpiryItemEntity?,
        name: String,
        quantity: Int,
        expiryDate: Long,
        remindDays: Int,
        note: String,
        imagePath: String?
    ) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()

    var name by remember { mutableStateOf("") }
    var quantityText by remember { mutableStateOf("1") }
    var expiryDate by remember { mutableLongStateOf(DateExt.startOfDay(System.currentTimeMillis())) }
    var remindDays by remember { mutableStateOf(7) }
    var note by remember { mutableStateOf("") }
    var imagePath by remember { mutableStateOf<String?>(null) }
    var initialized by remember { mutableStateOf(false) }
    var saveError by remember { mutableStateOf<String?>(null) }
    var showDatePicker by remember { mutableStateOf(false) }

    if (!initialized) {
        initialized = true
        item?.let {
            name = it.name
            quantityText = maxOf(it.quantity, 1).toString()
            expiryDate = it.expiryDate
            remindDays = it.remindDaysBefore
            note = it.note
            imagePath = it.imagePath
        }
    }

    val quantity = quantityText.filter { it.isDigit() }.toIntOrNull() ?: 0
    val canSave = name.isNotBlank() && quantity > 0
    val remindOptions = listOf(3, 7, 15)

    fun save() {
        scope.launch {
            runCatching {
                onSave(
                    item,
                    name.trim().take(100),
                    quantity.coerceIn(1, 9999),
                    expiryDate,
                    remindDays,
                    note.trim().take(200),
                    imagePath
                )
            }.onSuccess {
                onDismiss()
            }.onFailure {
                saveError = "临期记录未保存，请重试。"
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = XzgDimens.pageMargin)
    ) {
        // 标题栏
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "取消",
                style = XzgType.body,
                color = palettes.background.textTertiary,
                modifier = Modifier.clickable(onClick = onDismiss)
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = if (item == null) "新增临期商品" else "编辑临期商品",
                style = XzgType.headline,
                color = palettes.background.textPrimary
            )
            Spacer(modifier = Modifier.weight(1f))
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 商品名称
        V32SectionHeader(title = "商品名称")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            SheetTextField(
                value = name,
                onValueChange = { name = it },
                placeholder = "例如：牛奶 250ml",
                modifier = Modifier.fillMaxWidth()
            )
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 数量
        V32SectionHeader(title = "数量")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                IconButton(
                    onClick = {
                        quantityText = (quantity - 1).coerceIn(1, 9999).toString()
                    }
                ) {
                    Icon(
                        imageVector = Icons.Filled.Remove,
                        contentDescription = "减少",
                        tint = palettes.accent.accent
                    )
                }
                TextField(
                    value = quantityText,
                    onValueChange = { v ->
                        val digits = v.filter { it.isDigit() }.take(4)
                        quantityText = digits
                    },
                    modifier = Modifier.width(96.dp),
                    textStyle = XzgType.headline.copy(
                        color = palettes.background.textPrimary,
                        textAlign = TextAlign.Center
                    ),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        disabledContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        cursorColor = palettes.accent.accent
                    )
                )
                IconButton(
                    onClick = {
                        quantityText = (quantity + 1).coerceIn(1, 9999).toString()
                    }
                ) {
                    Icon(
                        imageVector = Icons.Filled.Add,
                        contentDescription = "增加",
                        tint = palettes.accent.accent
                    )
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 到期日期
        V32SectionHeader(title = "到期日期")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { showDatePicker = true }
                    .padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "到期",
                    style = XzgType.title,
                    color = palettes.background.textPrimary
                )
                Text(
                    text = Format.formatDate(expiryDate),
                    style = XzgType.body,
                    color = palettes.background.textSecondary
                )
            }
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 提前提醒
        V32SectionHeader(title = "提前提醒")
        Spacer(modifier = Modifier.height(10.dp))
        V32SegmentedPicker(
            options = remindOptions.map { "$it 天" },
            selectedIndex = remindOptions.indexOf(remindDays).coerceAtLeast(0),
            onSelect = { remindDays = remindOptions[it] },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(16.dp))

        // 备注
        V32SectionHeader(title = "备注")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            SheetTextField(
                value = note,
                onValueChange = { note = it },
                placeholder = "供应商、批次等",
                modifier = Modifier.fillMaxWidth()
            )
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 图片
        V32SectionHeader(title = "图片")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            PhotoPickerField(
                imagePath = imagePath,
                onPick = { imagePath = it },
                modifier = Modifier.fillMaxWidth()
            )
        }
        Spacer(modifier = Modifier.height(20.dp))

        V32PrimaryButton(
            text = "保存",
            onClick = ::save,
            enabled = canSave,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(XzgDimens.bottomPad))
    }

    if (showDatePicker) {
        val todayStart = DateExt.startOfDay(System.currentTimeMillis())
        val dateState = rememberDatePickerState(
            initialSelectedDateMillis = expiryDate,
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                    utcTimeMillis >= todayStart
            }
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    dateState.selectedDateMillis?.let { expiryDate = it }
                    showDatePicker = false
                }) { Text(text = "确定") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text(text = "取消") }
            }
        ) {
            DatePicker(state = dateState)
        }
    }

    if (saveError != null) {
        AlertDialog(
            onDismissRequest = { saveError = null },
            title = { Text(text = "保存失败", style = XzgType.headline) },
            text = { Text(text = saveError ?: "请稍后重试", style = XzgType.body) },
            confirmButton = {
                TextButton(onClick = { saveError = null; save() }) { Text(text = "重试") }
            },
            dismissButton = {
                TextButton(onClick = { saveError = null }) { Text(text = "取消") }
            }
        )
    }
}

/** Sheet 内无边框输入框（贴 V32FieldGroup 视觉） */
@Composable
private fun SheetTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier
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
        modifier = modifier,
        textStyle = XzgType.body.copy(color = palettes.background.textPrimary),
        singleLine = true,
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            disabledContainerColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            cursorColor = palettes.accent.accent
        )
    )
}
