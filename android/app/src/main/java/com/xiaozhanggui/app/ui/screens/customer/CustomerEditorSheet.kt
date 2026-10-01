package com.xiaozhanggui.app.ui.screens.customer

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
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
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.CustomerDeliveryInfo
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.PhotoPickerField
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

/**
 * 配送需求新增/编辑 Sheet。对应 iOS Customer/CustomerEditorSheet.swift。
 *
 * - 购买内容（必填）+ 配送地址（必填）+ 联系电话（选填）
 * - 配送时间开关（默认开）：DatePickerDialog 选日期 → TimePicker 选时间
 * - 备注 + PhotoPickerField
 * - 保存：customer 字段存 `xzg-delivery-v1:` 编码串
 *   （deliveryTime/note/legacyCustomer=地址）；编辑时 decode 回填
 * - 内容与地址双必填，否则保存按钮 disabled；保存失败弹 alert
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerEditorSheet(
    request: CustomerRequestEntity?,
    onDismiss: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val repo = XzgGraph.customerRepository
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palettes.background.pageBG
    ) {
        CustomerEditorContent(
            request = request,
            onDismiss = onDismiss,
            onSave = { req, content, address, phone, deliveryTime, note, imagePath ->
                val encoded = CustomerDeliveryStorage.encode(
                    CustomerDeliveryInfo(
                        deliveryTime = deliveryTime,
                        note = note.trim(),
                        legacyCustomer = address.trim()
                    )
                )
                if (req != null) {
                    repo.update(
                        req.copy(
                            customer = encoded,
                            roomOrAddress = address.trim(),
                            phone = phone.trim(),
                            content = content.trim(),
                            imagePath = imagePath
                        )
                    )
                } else {
                    repo.add(
                        customer = encoded,
                        roomOrAddress = address.trim(),
                        phone = phone.trim(),
                        content = content.trim(),
                        imagePath = imagePath
                    )
                }
            }
        )
    }
}

/**
 * 配送需求编辑 Sheet 纯渲染内容（不含 ModalBottomSheet 包裹，供 Paparazzi 截图用）。
 * 状态逻辑与 CustomerEditorSheet 完全一致，仅剥离手势容器与 Repository 写入
 * （写入经 [onSave] 回调交由外层执行）。
 */
@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun CustomerEditorContent(
    request: CustomerRequestEntity?,
    onDismiss: () -> Unit,
    onSave: suspend (
        request: CustomerRequestEntity?,
        content: String,
        address: String,
        phone: String,
        deliveryTime: Long?,
        note: String,
        imagePath: String?
    ) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()

    var content by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var hasDeliveryTime by remember { mutableStateOf(true) }
    var deliveryTime by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var note by remember { mutableStateOf("") }
    var imagePath by remember { mutableStateOf<String?>(null) }
    var initialized by remember { mutableStateOf(false) }
    var saveError by remember { mutableStateOf<String?>(null) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }

    if (!initialized) {
        initialized = true
        request?.let {
            address = it.roomOrAddress
            phone = it.phone
            content = it.content
            val info = CustomerDeliveryStorage.decode(it.customer)
            if (info.deliveryTime != null) {
                hasDeliveryTime = true
                deliveryTime = info.deliveryTime
            } else {
                hasDeliveryTime = false
            }
            note = info.note
            imagePath = it.imagePath
        }
    }

    val canSave = content.isNotBlank() && address.isNotBlank()

    fun save() {
        scope.launch {
            runCatching {
                onSave(
                    request,
                    content.trim(),
                    address.trim(),
                    phone.trim(),
                    if (hasDeliveryTime) deliveryTime else null,
                    note.trim(),
                    imagePath
                )
            }.onSuccess {
                onDismiss()
            }.onFailure {
                saveError = "配送需求未保存，请重试。"
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
                text = if (request == null) "新增配送需求" else "编辑配送需求",
                style = XzgType.headline,
                color = palettes.background.textPrimary
            )
            Spacer(modifier = Modifier.weight(1f))
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 购买内容
        V32SectionHeader(title = "购买内容")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            SheetTextField(
                value = content,
                onValueChange = { content = it },
                placeholder = "例：矿泉水2箱、啤酒10瓶、纸巾2包",
                minLines = 3,
                modifier = Modifier.fillMaxWidth()
            )
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 地址与联系
        V32SectionHeader(title = "地址与联系")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.fillMaxWidth()) {
                SheetTextField(
                    value = address,
                    onValueChange = { address = it },
                    placeholder = "配送地址 / 别墅地址，例：清泉八街24号",
                    modifier = Modifier.fillMaxWidth()
                )
                SheetTextField(
                    value = phone,
                    onValueChange = { phone = it },
                    placeholder = "联系电话（选填）",
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 配送时间
        V32SectionHeader(title = "配送时间")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "设置配送时间",
                        style = XzgType.title,
                        color = palettes.background.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    Switch(
                        checked = hasDeliveryTime,
                        onCheckedChange = { hasDeliveryTime = it },
                        colors = SwitchDefaults.colors(
                            checkedTrackColor = palettes.accent.accent
                        )
                    )
                }
                if (hasDeliveryTime) {
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { showDatePicker = true }
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "送达时间",
                            style = XzgType.title,
                            color = palettes.background.textPrimary
                        )
                        Text(
                            text = Format.monthDayTime(deliveryTime),
                            style = XzgType.body,
                            color = palettes.background.textSecondary
                        )
                    }
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))

        // 备注
        V32SectionHeader(title = "备注")
        Spacer(modifier = Modifier.height(10.dp))
        V32Card(modifier = Modifier.fillMaxWidth()) {
            SheetTextField(
                value = note,
                onValueChange = { note = it },
                placeholder = "例：到了打电话 / 放门口 / 晚上8点送",
                minLines = 2,
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
        val dateState = rememberDatePickerState(
            initialSelectedDateMillis = DateExt.startOfDay(deliveryTime)
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    val picked = dateState.selectedDateMillis
                    if (picked != null) {
                        // 先保留原时间，日期替换为所选日期
                        val zdt = java.time.ZonedDateTime.ofInstant(
                            Instant.ofEpochMilli(deliveryTime), ZoneId.systemDefault()
                        )
                        deliveryTime = DateExt.atTime(picked, zdt.hour, zdt.minute)
                    }
                    showDatePicker = false
                    showTimePicker = true
                }) { Text(text = "确定") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text(text = "取消") }
            }
        ) {
            DatePicker(state = dateState)
        }
    }

    if (showTimePicker) {
        val zdt = java.time.ZonedDateTime.ofInstant(
            Instant.ofEpochMilli(deliveryTime), ZoneId.systemDefault()
        )
        val timeState = rememberTimePickerState(
            initialHour = zdt.hour,
            initialMinute = zdt.minute,
            is24Hour = true
        )
        AlertDialog(
            onDismissRequest = { showTimePicker = false },
            text = {
                TimePicker(state = timeState)
            },
            confirmButton = {
                TextButton(onClick = {
                    deliveryTime = DateExt.atTime(
                        DateExt.startOfDay(deliveryTime),
                        timeState.hour,
                        timeState.minute
                    )
                    showTimePicker = false
                }) { Text(text = "确定") }
            },
            dismissButton = {
                TextButton(onClick = { showTimePicker = false }) { Text(text = "取消") }
            }
        )
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
    modifier: Modifier = Modifier,
    minLines: Int = 1,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default
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
        singleLine = minLines <= 1,
        minLines = minLines,
        keyboardOptions = keyboardOptions,
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
