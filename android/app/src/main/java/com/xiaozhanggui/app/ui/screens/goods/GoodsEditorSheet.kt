package com.xiaozhanggui.app.ui.screens.goods

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.data.db.GoodsCategory
import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.domain.isGoodsNameValid
import com.xiaozhanggui.app.ui.components.PhotoPickerField
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.components.V32SegmentedPicker
import com.xiaozhanggui.app.ui.components.v32PressFeedback
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.launch

/** 商品编辑器模式：新增 / 编辑。对应 iOS GoodsEditorSheet(goods: Goods?)。 */
enum class GoodsEditorMode { NEW, EDIT }

/**
 * 商品编辑器。对应 iOS `GoodsEditorSheet`：
 * - 商品名称（必填，去首尾空格后非空才能保存）
 * - 分类 5 选 / 条码 / 库存 + 最低库存 / 进价 + 售价
 * - 生产日期（开关 + DatePickerDialog）/ 保质期（天）/ 到期日期（开关 + DatePickerDialog，不早于今天）
 * - 备注 / 商品图片（PhotoPickerField，存路径）
 * - 保存失败静默（与 iOS 一致）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoodsEditorSheet(
    mode: GoodsEditorMode,
    goods: GoodsEntity? = null,
    onDismiss: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palettes.background.pageBG
    ) {
        GoodsEditorContent(
        mode = mode,
        goods = goods,
        onDismiss = onDismiss,
        onSave = { entity ->
            if (mode == GoodsEditorMode.EDIT) {
                XzgGraph.goodsRepository.update(entity)
            } else {
                XzgGraph.goodsRepository.add(entity)
            }
        }
        )
    }
}

/**
 * 商品编辑器纯渲染内容（不含 ModalBottomSheet 包裹，供 Paparazzi 截图用）。
 * 状态逻辑与 GoodsEditorSheet 完全一致，仅剥离手势容器与 Repository 写入
 * （写入经 [onSave] 回调交由外层执行；保存失败静默行为不变）。
 */
@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun GoodsEditorContent(
    mode: GoodsEditorMode,
    goods: GoodsEntity? = null,
    onDismiss: () -> Unit,
    onSave: suspend (entity: GoodsEntity) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()

    var name by remember { mutableStateOf(goods?.name ?: "") }
    var category by remember {
        mutableStateOf(
        if (goods != null && GoodsCategory.ALL.contains(goods.category)) goods.category
        else GoodsCategory.OTHER
        )
    }
    var barcode by remember { mutableStateOf(goods?.barcode ?: "") }
    var stockText by remember { mutableStateOf(goods?.let { it.stock.toString() } ?: "0") }
    var minStockText by remember { mutableStateOf(goods?.let { it.minStock.toString() } ?: "0") }
    var purchaseText by remember {
        mutableStateOf(if (goods != null && goods.purchasePrice != 0.0) trimAmount(goods.purchasePrice) else "")
    }
    var saleText by remember {
        mutableStateOf(if (goods != null && goods.salePrice != 0.0) trimAmount(goods.salePrice) else "")
    }
    var hasProductionDate by remember { mutableStateOf(goods?.productionDate != null) }
    var productionDate by remember { mutableStateOf(goods?.productionDate ?: System.currentTimeMillis()) }
    var shelfLifeText by remember {
        mutableStateOf(if (goods != null && goods.shelfLifeDays != 0) goods.shelfLifeDays.toString() else "")
    }
    var hasExpiryDate by remember { mutableStateOf(goods?.expiryDate != null) }
    var expiryDate by remember { mutableStateOf(goods?.expiryDate ?: System.currentTimeMillis()) }
    var note by remember { mutableStateOf(goods?.note ?: "") }
    var imagePath by remember { mutableStateOf(goods?.imagePath) }

    var showProductionPicker by remember { mutableStateOf(false) }
    var showExpiryPicker by remember { mutableStateOf(false) }
    var saveError by remember { mutableStateOf<String?>(null) }

    val canSave = isGoodsNameValid(name)

    fun save() {
        if (!canSave) return
        val trimmedName = name.trim()
        val entity = GoodsEntity(
        id = goods?.id ?: java.util.UUID.randomUUID().toString(),
        name = trimmedName,
        category = category,
        barcode = barcode.trim(),
        stock = stockText.filter { it.isDigit() }.toIntOrNull() ?: 0,
        minStock = minStockText.filter { it.isDigit() }.toIntOrNull() ?: 0,
        purchasePrice = purchaseText.toDoubleOrNull() ?: 0.0,
        salePrice = saleText.toDoubleOrNull() ?: 0.0,
        productionDate = if (hasProductionDate) productionDate else null,
        shelfLifeDays = shelfLifeText.filter { it.isDigit() }.toIntOrNull() ?: 0,
        expiryDate = if (hasExpiryDate) expiryDate else null,
        note = note.trim(),
        imagePath = imagePath,
        createdAt = goods?.createdAt ?: System.currentTimeMillis(),
        updatedAt = System.currentTimeMillis()
        )
        scope.launch {
        try {
            onSave(entity)
            onDismiss()
        } catch (_: Exception) {
            // 与 iOS 一致：保存失败静默（仅记录状态以便排查，不打断用户）
            saveError = "商品未保存，请重试。"
        }
        }
    }

    Column(
        modifier = Modifier
        .verticalScroll(rememberScrollState())
        .padding(horizontal = XzgDimens.pageMargin)
        .padding(top = 14.dp, bottom = XzgDimens.bottomPad),
        verticalArrangement = Arrangement.spacedBy(18.dp)
    ) {
        // 头部
        Box(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = if (mode == GoodsEditorMode.NEW) "新增商品" else "编辑商品",
                style = XzgType.headline,
                color = palettes.background.textPrimary,
                modifier = Modifier.align(Alignment.Center)
            )
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.align(Alignment.CenterStart)
            ) {
                Text(
                    text = "取消",
                    style = XzgType.body,
                    color = palettes.background.textTertiary
                )
            }
        }

        // 商品名称
        FieldSection("商品名称") {
            EditorTextField(
                value = name,
                onValueChange = { name = it },
                placeholder = "如：可口可乐 330ml"
            )
        }

        // 分类
        FieldSection("分类") {
            V32SegmentedPicker(
                options = GoodsCategory.ALL,
                selectedIndex = GoodsCategory.ALL.indexOf(category).takeIf { it >= 0 }
                    ?: (GoodsCategory.ALL.size - 1),
                onSelect = { category = GoodsCategory.ALL[it] }
            )
        }

        // 条码
        FieldSection("条码") {
            EditorTextField(
                value = barcode,
                onValueChange = { barcode = it },
                placeholder = "选填，扫码枪可直接录入",
                keyboardType = KeyboardType.Number
            )
        }

        // 库存
        FieldSection("库存") {
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                NumberField(
                    label = "当前库存",
                    value = stockText,
                    onValueChange = { if (it.all { c -> c.isDigit() }) stockText = it },
                    modifier = Modifier.weight(1f)
                )
                NumberField(
                    label = "最低库存",
                    value = minStockText,
                    onValueChange = { if (it.all { c -> c.isDigit() }) minStockText = it },
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // 价格
        FieldSection("价格") {
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                NumberField(
                    label = "进价",
                    value = purchaseText,
                    onValueChange = { if (it.matches(DECIMAL_RE)) purchaseText = it },
                    decimal = true,
                    modifier = Modifier.weight(1f)
                )
                NumberField(
                    label = "售价",
                    value = saleText,
                    onValueChange = { if (it.matches(DECIMAL_RE)) saleText = it },
                    decimal = true,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // 生产日期
        FieldSection("生产日期") {
            ToggleRow(
                title = "设置生产日期",
                checked = hasProductionDate,
                onCheckedChange = { hasProductionDate = it }
            )
            if (hasProductionDate) {
                DateRow(
                    dateText = Format.formatDate(productionDate),
                    onClick = { showProductionPicker = true }
                )
            }
        }

        // 保质期
        FieldSection("保质期") {
            NumberField(
                label = "保质期（天）",
                value = shelfLifeText,
                onValueChange = { if (it.all { c -> c.isDigit() }) shelfLifeText = it },
                modifier = Modifier.fillMaxWidth()
            )
        }

        // 到期日期
        FieldSection("到期日期") {
            ToggleRow(
                title = "设置到期日期",
                checked = hasExpiryDate,
                onCheckedChange = { hasExpiryDate = it }
            )
            if (hasExpiryDate) {
                DateRow(
                    dateText = Format.formatDate(expiryDate),
                    onClick = { showExpiryPicker = true }
                )
            }
        }

        // 备注
        FieldSection("备注") {
            EditorTextField(
                value = note,
                onValueChange = { note = it },
                placeholder = "选填"
            )
        }

        // 商品图片
        FieldSection("商品图片") {
            PhotoPickerField(
                imagePath = imagePath,
                onPick = { imagePath = it },
                modifier = Modifier.fillMaxWidth()
            )
        }

        V32PrimaryButton(
            text = "保存",
            onClick = ::save,
            enabled = canSave
        )
    }

    if (showProductionPicker) {
        val state = rememberDatePickerState(initialSelectedDateMillis = productionDate)
        DatePickerDialog(
            onDismissRequest = { showProductionPicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        state.selectedDateMillis?.let { productionDate = it }
                        showProductionPicker = false
                    }
                ) { Text("确定") }
            },
            dismissButton = {
                TextButton(onClick = { showProductionPicker = false }) { Text("取消") }
            }
        ) {
            DatePicker(state = state)
        }
    }

    if (showExpiryPicker) {
        val todayStart = DateExt.startOfDay(System.currentTimeMillis())
        val state = rememberDatePickerState(
            initialSelectedDateMillis = expiryDate,
            selectableDates = object : SelectableDates {
                // 对应 iOS DatePicker(in: Date()...)：到期日不早于今天
                override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                    utcTimeMillis >= todayStart
            }
        )
        DatePickerDialog(
            onDismissRequest = { showExpiryPicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        state.selectedDateMillis?.let { expiryDate = it }
                        showExpiryPicker = false
                    }
                ) { Text("确定") }
            },
            dismissButton = {
                TextButton(onClick = { showExpiryPicker = false }) { Text("取消") }
            }
        ) {
            DatePicker(state = state)
        }
    }

    saveError?.let { message ->
        AlertDialog(
            onDismissRequest = { saveError = null },
            title = { Text("保存失败", style = XzgType.headline) },
            text = { Text(message, style = XzgType.body) },
            confirmButton = {
                TextButton(onClick = { saveError = null }) { Text("知道了") }
            }
        )
    }
}

private val DECIMAL_RE = Regex("^\\d*\\.?\\d*$")

/** 编辑回填：整数显示整数形式。 */
private fun trimAmount(amount: Double): String =
    if (amount % 1 == 0.0) amount.toLong().toString() else amount.toString()

@Composable
private fun FieldSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        V32SectionHeader(title)
        content()
    }
}

@Composable
private fun EditorTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Text
) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = XzgType.body.copy(color = palettes.background.textPrimary),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            decorationBox = { innerTextField ->
                Box {
                    if (value.isEmpty()) {
                        Text(
                            text = placeholder,
                            style = XzgType.body,
                            color = palettes.background.textQuaternary
                        )
                    }
                    innerTextField()
                }
            }
        )
        HorizontalDivider(color = palettes.background.divider)
    }
}

@Composable
private fun NumberField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    decimal: Boolean = false
) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = XzgType.caption,
            color = palettes.background.textTertiary
        )
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = XzgType.headline.copy(color = palettes.background.textPrimary),
            keyboardOptions = KeyboardOptions(
                keyboardType = if (decimal) KeyboardType.Decimal else KeyboardType.Number
            ),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            decorationBox = { innerTextField ->
                Box {
                    if (value.isEmpty()) {
                        Text(
                            text = if (decimal) "0.00" else "0",
                            style = XzgType.headline,
                            color = palettes.background.textQuaternary
                        )
                    }
                    innerTextField()
                }
            }
        )
    }
}

@Composable
private fun ToggleRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = XzgType.title,
            color = palettes.background.textPrimary
        )
        Spacer(Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedTrackColor = palettes.accent.accent,
                checkedThumbColor = palettes.accent.onAccent
            )
        )
    }
}

@Composable
private fun DateRow(dateText: String, onClick: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .v32PressFeedback(onClick = onClick)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = dateText,
            style = XzgType.body,
            color = palettes.background.textSecondary
        )
        Spacer(Modifier.width(8.dp))
        Icon(
            imageVector = Icons.Filled.CalendarToday,
            contentDescription = null,
            tint = palettes.background.textTertiary,
            modifier = Modifier.size(16.dp)
        )
    }
}
