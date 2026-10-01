package com.xiaozhanggui.app.ui.screens.performance

import androidx.compose.foundation.background
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.xiaozhanggui.app.data.db.ExpenseCategory
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.IncomeSource
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.domain.PerformanceStats2
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.components.V32SegmentedPicker
import com.xiaozhanggui.app.ui.components.v32PressFeedback
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.launch

/**
 * 记账编辑器模式。对应 iOS `MoneyEditorSheet.Mode`：
 * new(.income) / new(.expense) / editPerformance / editExpense。
 */
enum class MoneyEditorMode {
    NEW_INCOME,
    NEW_EXPENSE,
    EDIT_PERFORMANCE,
    EDIT_EXPENSE
}

private val EXPENSE_CATEGORIES = ExpenseCategory.ALL
private val INCOME_SOURCES = listOf(IncomeSource.STORE, IncomeSource.MEITUAN, IncomeSource.OTHER)

/**
 * 记收入 / 记支出编辑器。对应 iOS `MoneyEditorSheet`。
 *
 * - 金额大字（46sp）：逗号清洗后必须 > 0 才能保存
 * - 备注（选填）+ 日期（DatePickerDialog）
 * - 支出：分类 5 选（进货/房租/水电/人工/其他）；收入：来源 3 选（门店/美团/其他）
 * - 保存失败弹 alert「保存失败」
 *
 * @param mode 4 种模式
 * @param performance 编辑收入时传入
 * @param expense 编辑支出时传入
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoneyEditorSheet(
    mode: MoneyEditorMode,
    performance: PerformanceEntity? = null,
    expense: ExpenseEntity? = null,
    onDismiss: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val isIncome = mode == MoneyEditorMode.NEW_INCOME || mode == MoneyEditorMode.EDIT_PERFORMANCE

    var amountText by remember {
        mutableStateOf(
            when (mode) {
                MoneyEditorMode.EDIT_PERFORMANCE -> formatAmountInput(performance?.amount)
                MoneyEditorMode.EDIT_EXPENSE -> formatAmountInput(expense?.amount)
                else -> ""
            }
        )
    }
    var note by remember {
        mutableStateOf(
            when (mode) {
                MoneyEditorMode.EDIT_PERFORMANCE -> performance?.note ?: ""
                MoneyEditorMode.EDIT_EXPENSE -> expense?.note ?: ""
                else -> ""
            }
        )
    }
    var date by remember {
        mutableStateOf(
            when (mode) {
                MoneyEditorMode.EDIT_PERFORMANCE -> performance?.date ?: System.currentTimeMillis()
                MoneyEditorMode.EDIT_EXPENSE -> expense?.date ?: System.currentTimeMillis()
                else -> System.currentTimeMillis()
            }
        )
    }
    var category by remember {
        mutableStateOf(
            if (mode == MoneyEditorMode.EDIT_EXPENSE) expense?.category ?: ExpenseCategory.OTHER
            else ExpenseCategory.OTHER
        )
    }
    var incomeSource by remember {
        mutableStateOf(
            if (mode == MoneyEditorMode.EDIT_PERFORMANCE && performance != null)
                PerformanceStats2.resolveIncomeSource(performance)
            else IncomeSource.STORE
        )
    }
    var showDatePicker by remember { mutableStateOf(false) }
    var saveError by remember { mutableStateOf<String?>(null) }

    // 金额校验：去掉逗号后 Double 解析，必须 > 0（对应 iOS amount 计算属性）
    val amount: Double? = remember(amountText) {
        amountText.replace(",", "").trim().toDoubleOrNull()?.takeIf { it > 0 }
    }

    val title = when (mode) {
        MoneyEditorMode.NEW_INCOME -> "记一笔收入"
        MoneyEditorMode.NEW_EXPENSE -> "记一笔支出"
        MoneyEditorMode.EDIT_PERFORMANCE -> "编辑收入"
        MoneyEditorMode.EDIT_EXPENSE -> "编辑支出"
    }

    fun save() {
        val value = amount ?: return
        scope.launch {
            try {
                when (mode) {
                    MoneyEditorMode.NEW_INCOME ->
                        XzgGraph.performanceRepository.add(value, note.trim(), date, incomeSource)
                    MoneyEditorMode.NEW_EXPENSE ->
                        XzgGraph.expenseRepository.add(value, category, note.trim(), date)
                    MoneyEditorMode.EDIT_PERFORMANCE -> {
                        val p = performance ?: return@launch
                        XzgGraph.performanceRepository.update(
                            p.copy(
                                amount = value,
                                note = note.trim(),
                                date = date,
                                incomeSource = incomeSource
                            )
                        )
                    }
                    MoneyEditorMode.EDIT_EXPENSE -> {
                        val e = expense ?: return@launch
                        XzgGraph.expenseRepository.update(
                            e.copy(
                                amount = value,
                                note = note.trim(),
                                category = category,
                                date = date
                            )
                        )
                    }
                }
                onDismiss()
            } catch (_: Exception) {
                saveError = "经营记录未保存，请重试。"
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palettes.background.pageBG
    ) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = XzgDimens.pageMargin)
                .padding(top = 14.dp, bottom = XzgDimens.bottomPad),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            // 头部：左上"取消" + 居中标题
            Box(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = title,
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

            // 金额卡
            Column(
                modifier = Modifier.padding(top = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    text = if (isIncome) "收入金额" else "支出金额",
                    style = XzgType.caption,
                    color = palettes.background.textSecondary
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = "¥",
                        style = XzgType.title.copy(
                            fontSize = 26.sp,
                            fontWeight = FontWeight.SemiBold
                        ),
                        color = palettes.background.textSecondary
                    )
                    Spacer(Modifier.width(8.dp))
                    BasicTextField(
                        value = amountText,
                        onValueChange = { amountText = it },
                        textStyle = XzgType.heroMoney.copy(
                            fontSize = 46.sp,
                            color = palettes.background.textPrimary
                        ),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                        decorationBox = { innerTextField ->
                            Box {
                                if (amountText.isEmpty()) {
                                    Text(
                                        text = "0.00",
                                        style = XzgType.heroMoney.copy(
                                            fontSize = 46.sp,
                                            color = palettes.background.textQuaternary
                                        )
                                    )
                                }
                                innerTextField()
                            }
                        }
                    )
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(2.dp)
                        .background(palettes.accent.accent.copy(alpha = 0.45f))
                )
            }

            // 明细卡：备注 + 日期
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                V32SectionHeader("明细")
                BasicTextField(
                    value = note,
                    onValueChange = { note = it },
                    textStyle = XzgType.body.copy(color = palettes.background.textPrimary),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    decorationBox = { innerTextField ->
                        Box {
                            if (note.isEmpty()) {
                                Text(
                                    text = if (isIncome) "备注（选填）" else "备注（选填，如：进了两箱可乐）",
                                    style = XzgType.body,
                                    color = palettes.background.textQuaternary
                                )
                            }
                            innerTextField()
                        }
                    }
                )
                HorizontalDivider(color = palettes.background.divider)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .v32PressFeedback(onClick = { showDatePicker = true })
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "日期",
                        style = XzgType.title,
                        color = palettes.background.textPrimary
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = Format.formatDate(date),
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

            // 分类（仅支出）/ 收入来源（仅收入）
            if (isIncome) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    V32SectionHeader("收入来源")
                    V32SegmentedPicker(
                        options = INCOME_SOURCES,
                        selectedIndex = INCOME_SOURCES.indexOf(incomeSource).takeIf { it >= 0 } ?: 0,
                        onSelect = { incomeSource = INCOME_SOURCES[it] }
                    )
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    V32SectionHeader("分类")
                    V32SegmentedPicker(
                        options = EXPENSE_CATEGORIES,
                        selectedIndex = EXPENSE_CATEGORIES.indexOf(category).takeIf { it >= 0 }
                            ?: (EXPENSE_CATEGORIES.size - 1),
                        onSelect = { category = EXPENSE_CATEGORIES[it] }
                    )
                }
            }

            V32PrimaryButton(
                text = "保存",
                onClick = ::save,
                enabled = amount != null
            )
        }
    }

    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = date)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { date = it }
                        showDatePicker = false
                    }
                ) { Text("确定") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("取消") }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    saveError?.let { message ->
        AlertDialog(
            onDismissRequest = { saveError = null },
            title = { Text("保存失败", style = XzgType.headline) },
            text = { Text(message, style = XzgType.body) },
            confirmButton = {
                TextButton(
                    onClick = {
                        saveError = null
                        save()
                    }
                ) { Text("重试") }
            },
            dismissButton = {
                TextButton(onClick = { saveError = null }) { Text("取消") }
            }
        )
    }
}

/** 编辑回填：整数显示整数形式（对应 iOS loadEditing）。 */
private fun formatAmountInput(amount: Double?): String {
    if (amount == null) return ""
    return if (amount % 1 == 0.0) amount.toLong().toString() else amount.toString()
}
