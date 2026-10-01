package com.xiaozhanggui.app.ui.screens.performance

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.SouthWest
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.ExpenseRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.domain.PerformanceStats2
import com.xiaozhanggui.app.ui.components.BubbleTone
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.components.Sparkline
import com.xiaozhanggui.app.ui.components.V32IconBubble
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.v32PressFeedback
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * 经营数据 ViewModel。对应 iOS `PerformanceView` 的 `@Query` 数据源：
 * performanceRepository.observeAll + expenseRepository.observeAll。
 */
class PerformanceViewModel(
    private val performanceRepository: PerformanceRepository,
    private val expenseRepository: ExpenseRepository
) : ViewModel() {
    val performances: StateFlow<List<PerformanceEntity>> =
        performanceRepository.observeAll()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    val expenses: StateFlow<List<ExpenseEntity>> =
        expenseRepository.observeAll()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    suspend fun deletePerformance(p: PerformanceEntity) = performanceRepository.delete(p)
    suspend fun deleteExpense(e: ExpenseEntity) = expenseRepository.delete(e)
}

internal fun performanceViewModelFactory(): ViewModelProvider.Factory =
    object : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            PerformanceViewModel(
                XzgGraph.performanceRepository,
                XzgGraph.expenseRepository
            ) as T
    }

/**
 * 交易流水行（收入/支出合并，携带原实体以支持编辑/删除）。
 * 对应 iOS `MoneyRecord`（含 performance/expense 引用）。
 */
data class PerformanceRowItem(
    val id: String,
    val title: String,
    /** 收入为正、支出为负 */
    val amount: Double,
    val date: Long,
    val source: String,
    val isIncome: Boolean,
    val performance: PerformanceEntity?,
    val expense: ExpenseEntity?
)

private fun toRowItem(p: PerformanceEntity): PerformanceRowItem = PerformanceRowItem(
    id = "p-${p.id}",
    title = DisplayLogic.performanceTitle(p),
    amount = p.amount,
    date = p.date,
    source = DisplayLogic.recordSourceLabel(p),
    isIncome = true,
    performance = p,
    expense = null
)

internal fun toExpenseRowItem(e: ExpenseEntity): PerformanceRowItem = PerformanceRowItem(
    id = "e-${e.id}",
    title = DisplayLogic.expenseTitle(e),
    amount = -e.amount,
    date = e.date,
    source = expenseSourceLabel(e),
    isIncome = false,
    performance = null,
    expense = e
)

/**
 * 支出来源标签。对应 iOS `RecordSourceLabel.display(expense:)`：
 * category 非 banned（"" / 其他 / other / 收入 / 营业额 / 支出）→ category；
 * 否则 note 为"手动"/"门店"/"美团" → note；其余 → "手动"。
 */
internal fun expenseSourceLabel(e: ExpenseEntity): String {
    val banned = setOf("", "其他", "收入", "营业额", "支出")
    val category = e.category.trim()
    if (category !in banned && !category.equals("other", ignoreCase = true)) return category
    val note = e.note.trim()
    if (note == "手动" || note == "门店" || note == "美团") return note
    return "手动"
}

private fun startOfYear(nowMillis: Long): Long {
    val zone = ZoneId.systemDefault()
    return ZonedDateTime.ofInstant(Instant.ofEpochMilli(nowMillis), zone)
        .toLocalDate().withDayOfYear(1).atStartOfDay(zone).toInstant().toEpochMilli()
}

/**
 * 经营数据页。对应 iOS `PerformanceView`（导航标题"经营数据"）。
 *
 * - Hero 卡：本月营业额（46sp 等宽大数字）+ 今日 + 较昨日 badge + 近 7 天 Sparkline
 * - 关键指标：昨日 / 本年
 * - 收入来源：本月按门店/美团/其他拆分
 * - 交易流水：近 30 天合并前 12 条，可编辑、可删除（确认框）
 *
 * @param onOpenTransactions "查看全部" → 交易记录页
 * @param onOpenSaobei 工具栏「扫呗导入」
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PerformanceScreen(
    onOpenTransactions: () -> Unit = {},
    onOpenSaobei: () -> Unit = {}
) {
    val vm: PerformanceViewModel = viewModel(factory = remember { performanceViewModelFactory() })
    val performances by vm.performances.collectAsStateWithLifecycle(initialValue = emptyList())
    val expenses by vm.expenses.collectAsStateWithLifecycle(initialValue = emptyList())
    val palettes = LocalXzgPalettes.current
    val scope = rememberCoroutineScope()

    var menuExpanded by remember { mutableStateOf(false) }
    var newMode by remember { mutableStateOf<MoneyEditorMode?>(null) }
    var editingPerformance by remember { mutableStateOf<PerformanceEntity?>(null) }
    var editingExpense by remember { mutableStateOf<ExpenseEntity?>(null) }
    var deletingItem by remember { mutableStateOf<PerformanceRowItem?>(null) }
    var deleteError by remember { mutableStateOf<String?>(null) }

    val now = System.currentTimeMillis()
    val todayStart = DateExt.startOfDay(now)
    val todayRevenue = performances.filter { DateExt.isToday(it.date) }.sumOf { it.amount }
    val yesterdayRevenue =
        performances.filter { DateExt.isSameDay(it.date, todayStart - 24 * 3600 * 1000L) }.sumOf { it.amount }
    val monthRevenue = performances
        .filter { it.date in DateExt.startOfMonth(now)..DateExt.endOfDay(now) }
        .sumOf { it.amount }
    val yearRevenue = performances
        .filter { it.date in startOfYear(now)..DateExt.endOfDay(now) }
        .sumOf { it.amount }
    // changePercent = (今-昨)/昨*100；昨日为 0 → null（显示"暂无昨日对比"）
    val changePercent: Double? =
        if (yesterdayRevenue > 0) (todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100 else null
    val trend = remember(performances, now) {
        PerformanceStats2.last7Days(performances, now).map { it.amount }
    }
    val records = remember(performances, expenses, now) {
        val start = todayStart - 30L * 24 * 3600 * 1000
        val end = DateExt.endOfDay(now)
        (performances.filter { it.date in start..end }.map(::toRowItem) +
                expenses.filter { it.date in start..end }.map(::toExpenseRowItem))
            .sortedByDescending { it.date }
            .take(12)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("经营数据", style = XzgType.headline, color = palettes.background.textPrimary) },
                actions = {
                    Box {
                        IconButton(onClick = { menuExpanded = true }) {
                            Icon(
                                imageVector = Icons.Filled.Add,
                                contentDescription = "经营数据操作",
                                tint = palettes.background.textPrimary
                            )
                        }
                        DropdownMenu(
                            expanded = menuExpanded,
                            onDismissRequest = { menuExpanded = false }
                        ) {
                            DropdownMenuItem(
                                text = { Text("记收入") },
                                onClick = { menuExpanded = false; newMode = MoneyEditorMode.NEW_INCOME }
                            )
                            DropdownMenuItem(
                                text = { Text("记支出") },
                                onClick = { menuExpanded = false; newMode = MoneyEditorMode.NEW_EXPENSE }
                            )
                            DropdownMenuItem(
                                text = { Text("扫呗导入") },
                                leadingIcon = {
                                    Icon(
                                        imageVector = Icons.Filled.Download,
                                        contentDescription = null
                                    )
                                },
                                onClick = { menuExpanded = false; onOpenSaobei() }
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = palettes.background.pageBG
                )
            )
        },
        containerColor = palettes.background.pageBG
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = XzgDimens.pageMargin)
                .padding(top = 16.dp, bottom = XzgDimens.bottomPad),
            verticalArrangement = Arrangement.spacedBy(30.dp)
        ) {
            HeroCard(
                monthRevenue = monthRevenue,
                todayRevenue = todayRevenue,
                changePercent = changePercent,
                trend = trend
            )
            KeyMetrics(yesterdayRevenue = yesterdayRevenue, yearRevenue = yearRevenue)
            IncomeSources(performances = performances, now = now)
            RecordsSection(
                records = records,
                onAddIncome = { newMode = MoneyEditorMode.NEW_INCOME },
                onEdit = { item ->
                    if (item.performance != null) editingPerformance = item.performance
                    else if (item.expense != null) editingExpense = item.expense
                },
                onDelete = { deletingItem = it },
                onOpenTransactions = onOpenTransactions
            )
        }
    }

    newMode?.let { mode ->
        MoneyEditorSheet(mode = mode, onDismiss = { newMode = null })
    }
    editingPerformance?.let { p ->
        MoneyEditorSheet(
            mode = MoneyEditorMode.EDIT_PERFORMANCE,
            performance = p,
            onDismiss = { editingPerformance = null }
        )
    }
    editingExpense?.let { e ->
        MoneyEditorSheet(
            mode = MoneyEditorMode.EDIT_EXPENSE,
            expense = e,
            onDismiss = { editingExpense = null }
        )
    }
    deletingItem?.let { item ->
        ConfirmDeleteDialog(
            title = "删除这条经营记录？",
            onConfirm = {
                deletingItem = null
                scope.launch {
                    try {
                        val p = item.performance
                        val e = item.expense
                        if (p != null) vm.deletePerformance(p)
                        else if (e != null) vm.deleteExpense(e)
                    } catch (_: Exception) {
                        deleteError = "经营记录未删除，请重试。"
                    }
                }
            },
            onDismiss = { deletingItem = null }
        )
    }
    deleteError?.let { message ->
        AlertDialog(
            onDismissRequest = { deleteError = null },
            title = { Text("删除失败", style = XzgType.headline) },
            text = { Text(message, style = XzgType.body) },
            confirmButton = {
                TextButton(onClick = { deleteError = null }) { Text("知道了") }
            }
        )
    }
}

@Composable
private fun HeroCard(
    monthRevenue: Double,
    todayRevenue: Double,
    changePercent: Double?,
    trend: List<Double>
) {
    val palettes = LocalXzgPalettes.current
    val fixed = palettes.fixed
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(palettes.accent.heroStart, palettes.accent.heroEnd),
                    start = Offset.Zero,
                    end = Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY)
                )
            )
            .padding(horizontal = 22.dp, vertical = 24.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = "本月营业额",
                    style = XzgType.body.copy(fontWeight = FontWeight.Medium),
                    color = fixed.textOnHeroSecondary
                )
                Spacer(Modifier.weight(1f))
                Text(
                    text = "经营数据",
                    style = XzgType.caption.copy(fontWeight = FontWeight.Medium),
                    color = fixed.textOnHeroSecondary
                )
            }
            Text(
                text = Format.money(monthRevenue),
                style = XzgType.heroMoney.copy(fontSize = 46.sp),
                color = fixed.textOnHero,
                maxLines = 1
            )
            Row(verticalAlignment = Alignment.Bottom) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "今日",
                        style = XzgType.caption,
                        color = fixed.textOnHeroSecondary
                    )
                    Text(
                        text = Format.money(todayRevenue),
                        style = XzgType.title.copy(fontFeatureSettings = "tnum"),
                        color = fixed.textOnHero
                    )
                }
                Spacer(Modifier.width(16.dp))
                ChangeBadge(changePercent = changePercent)
                Spacer(Modifier.weight(1f))
                if (trend.any { it > 0 }) {
                    Sparkline(
                        values = trend,
                        modifier = Modifier
                            .width(120.dp)
                            .height(52.dp),
                        color = fixed.brandOnHero
                    )
                }
            }
        }
    }
}

@Composable
private fun ChangeBadge(changePercent: Double?) {
    val fixed = LocalXzgPalettes.current.fixed
    if (changePercent == null) {
        Text(
            text = "暂无昨日对比",
            style = XzgType.pill,
            color = fixed.textOnHeroSecondary
        )
    } else {
        val up = changePercent >= 0
        val tint = if (up) fixed.brandOnHero else fixed.amberOnHero
        Row(
            modifier = Modifier
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.16f))
                .padding(horizontal = 9.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (up) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(10.dp)
            )
            Spacer(Modifier.width(4.dp))
            Text(
                text = String.format(Locale.CHINA, "%.1f%% 较昨日", abs(changePercent)),
                style = XzgType.pill,
                color = tint
            )
        }
    }
}

@Composable
private fun KeyMetrics(yesterdayRevenue: Double, yearRevenue: Double) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = "关键指标",
            style = XzgType.caption.copy(fontWeight = FontWeight.Medium),
            color = palettes.background.textTertiary
        )
        Column {
            HorizontalDivider(color = palettes.background.divider)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp)
            ) {
                MetricCell(
                    label = "昨日",
                    value = Format.money(yesterdayRevenue),
                    modifier = Modifier.weight(1f)
                )
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(36.dp)
                        .background(palettes.background.divider)
                        .align(Alignment.CenterVertically)
                )
                MetricCell(
                    label = "本年",
                    value = Format.money(yearRevenue),
                    modifier = Modifier.weight(1f)
                )
            }
            HorizontalDivider(color = palettes.background.divider)
        }
    }
}

@Composable
private fun MetricCell(label: String, value: String, modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = modifier.padding(start = 4.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = XzgType.caption,
            color = palettes.background.textTertiary
        )
        Text(
            text = value,
            style = XzgType.subhead.copy(
                fontWeight = FontWeight.SemiBold,
                fontFeatureSettings = "tnum"
            ),
            color = palettes.background.textSecondary
        )
    }
}

@Composable
private fun IncomeSources(performances: List<PerformanceEntity>, now: Long) {
    val palettes = LocalXzgPalettes.current
    val monthPerformances = remember(performances, now) {
        performances.filter { it.date in DateExt.startOfMonth(now)..DateExt.endOfDay(now) }
    }
    val summary = remember(monthPerformances) {
        PerformanceStats2.incomeSourceSummary(monthPerformances)
    }
    val items = remember(summary) {
        listOf("门店" to summary.store, "美团" to summary.meituan, "其他" to summary.other)
            .filter { it.second > 0 }
    }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = "收入来源",
            style = XzgType.caption.copy(fontWeight = FontWeight.Medium),
            color = palettes.background.textTertiary
        )
        Column {
            HorizontalDivider(color = palettes.background.divider)
            if (items.isEmpty()) {
                Text(
                    text = "本月暂无收入",
                    style = XzgType.subhead,
                    color = palettes.background.textTertiary,
                    modifier = Modifier.padding(vertical = 12.dp)
                )
            } else {
                items.forEachIndexed { index, (name, amount) ->
                    if (index > 0) {
                        HorizontalDivider(
                            color = palettes.background.divider,
                            modifier = Modifier.padding(start = 12.dp)
                        )
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 13.dp),
                        verticalAlignment = Alignment.Bottom
                    ) {
                        Text(
                            text = name,
                            style = XzgType.body.copy(fontWeight = FontWeight.Medium),
                            color = palettes.background.textPrimary
                        )
                        Spacer(Modifier.weight(1f))
                        Text(
                            text = Format.money(amount),
                            style = XzgType.subhead.copy(
                                fontWeight = FontWeight.SemiBold,
                                fontFeatureSettings = "tnum"
                            ),
                            color = palettes.accent.chartAccent
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = "${(summary.ratio(amount) * 100).roundToInt()}%",
                            style = XzgType.caption.copy(fontFeatureSettings = "tnum"),
                            color = palettes.background.textTertiary
                        )
                    }
                }
            }
            HorizontalDivider(color = palettes.background.divider)
        }
    }
}

@Composable
private fun RecordsSection(
    records: List<PerformanceRowItem>,
    onAddIncome: () -> Unit,
    onEdit: (PerformanceRowItem) -> Unit,
    onDelete: (PerformanceRowItem) -> Unit,
    onOpenTransactions: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = "交易流水",
            style = XzgType.caption.copy(fontWeight = FontWeight.Medium),
            color = palettes.background.textTertiary
        )
        if (records.isEmpty()) {
            Column(
                modifier = Modifier.padding(vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Filled.Inbox,
                        contentDescription = null,
                        tint = palettes.background.textTertiary,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = "暂无交易记录",
                        style = XzgType.body,
                        color = palettes.background.textTertiary
                    )
                }
                V32PrimaryButton(text = "记一笔", onClick = onAddIncome)
            }
        } else {
            Column {
                records.forEachIndexed { index, record ->
                    if (index > 0) {
                        HorizontalDivider(
                            color = palettes.background.divider,
                            modifier = Modifier.padding(start = 48.dp)
                        )
                    }
                    PerformanceRecordRow(
                        item = record,
                        onEdit = { onEdit(record) },
                        onDelete = { onDelete(record) }
                    )
                }
            }
            TextButton(
                onClick = onOpenTransactions,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.List,
                    contentDescription = null,
                    tint = palettes.accent.accent,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = "查看全部",
                    style = XzgType.subhead,
                    color = palettes.accent.accent
                )
            }
        }
    }
}

@Composable
private fun PerformanceRecordRow(
    item: PerformanceRowItem,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val (icon, tone) = when {
        item.source == "扫呗" -> Icons.Filled.QrCode to BubbleTone.NEUTRAL
        item.isIncome -> Icons.Filled.SouthWest to BubbleTone.BRAND
        else -> Icons.Filled.NorthEast to BubbleTone.DANGER
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp)
            .heightIn(min = 64.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        V32IconBubble(icon = icon, tone = tone, size = 34.dp)
        Spacer(Modifier.width(12.dp))
        Column(
            modifier = Modifier
                .weight(1f)
                .v32PressFeedback(onClick = onEdit),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(
                text = item.title,
                style = XzgType.title,
                color = palettes.background.textPrimary,
                maxLines = 1
            )
            Text(
                text = if (item.source.isEmpty()) Format.shortDateTime(item.date)
                else "${item.source} · ${Format.shortDateTime(item.date)}",
                style = XzgType.caption,
                color = palettes.background.textTertiary,
                maxLines = 1
            )
        }
        Text(
            text = (if (item.isIncome) "+" else "-") + Format.money(abs(item.amount)),
            style = XzgType.title.copy(fontFeatureSettings = "tnum"),
            color = if (item.isIncome) palettes.accent.accent else palettes.fixed.danger,
            maxLines = 1
        )
        Spacer(Modifier.width(8.dp))
        IconButton(
            onClick = onDelete,
            modifier = Modifier.size(30.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.Delete,
                contentDescription = "删除记录",
                tint = palettes.background.textQuaternary,
                modifier = Modifier.size(14.dp)
            )
        }
    }
}
