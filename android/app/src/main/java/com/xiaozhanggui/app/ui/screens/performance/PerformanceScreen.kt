package com.xiaozhanggui.app.ui.screens.performance

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material.icons.filled.SouthWest
import androidx.compose.material.icons.filled.Store
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
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
import com.xiaozhanggui.app.domain.TransactionSearchable
import com.xiaozhanggui.app.domain.PerformanceStats2
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.components.EmptyState
import com.xiaozhanggui.app.ui.components.GroupSurface
import com.xiaozhanggui.app.ui.components.SectionHeader
import com.xiaozhanggui.app.ui.components.Sparkline
import com.xiaozhanggui.app.ui.components.V371Chevron
import com.xiaozhanggui.app.ui.components.V371Divider
import com.xiaozhanggui.app.ui.components.WorkRow
import com.xiaozhanggui.app.ui.theme.v371.LocalV371Colors
import com.xiaozhanggui.app.ui.theme.v371.V371Space
import com.xiaozhanggui.app.ui.theme.v371.V371Theme
import com.xiaozhanggui.app.ui.theme.v371.V371Type
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
    override val title: String,
    /** 收入为正、支出为负 */
    val amount: Double,
    val date: Long,
    override val source: String,
    val isIncome: Boolean,
    val performance: PerformanceEntity?,
    val expense: ExpenseEntity?
) : TransactionSearchable

internal fun toRowItem(p: PerformanceEntity): PerformanceRowItem = PerformanceRowItem(
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
 * @param onOpenGoods 工具栏「商品」按钮 → 商品管理页（R11）
 * @param onOpenMemo 经营 menu →「记录」→ 备忘页 navigationDestination（R13）
 * @param onOpenDailyReport 经营 menu →「今日经营日报」→ 日报 sheet（R15）
 */

/**
 * 经营数据页。对应 iOS `PerformanceView`（导航标题"经营数据"）。
 *
 * V371 视觉（Editorial 平面结构）：
 * - editorialHero：平面「本月营业额」+ ¥ 大数字 + 今日/较昨日/趋势（无蓝色大卡片；
 *   S2 蓝渐变仅天气详情 sheet 用，经营页禁用）
 * - 月目标：GroupSurface + 进度条 + 本年累计
 * - 收入来源：SectionHeader + GroupSurface + WorkRow
 * - 交易流水：SectionHeader + GroupSurface + 行 +「查看全部」行链
 *
 * @param onOpenTransactions "查看全部" → 交易记录页
 * @param onOpenSaobei 工具栏「扫呗导入」
 * @param onOpenGoods 工具栏「商品」按钮 → 商品管理页（R11）
 * @param onOpenMemo 经营 menu →「记录」→ 备忘页 navigationDestination（R13）
 * @param onOpenDailyReport 经营 menu →「今日经营日报」→ 日报 sheet（R15）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PerformanceScreen(
    onOpenTransactions: () -> Unit = {},
    onOpenSaobei: () -> Unit = {},
    onOpenGoods: () -> Unit = {},
    onOpenMemo: () -> Unit = {},
    onOpenDailyReport: () -> Unit = {}
) {
    val vm: PerformanceViewModel = viewModel(factory = remember { performanceViewModelFactory() })
    val performances by vm.performances.collectAsStateWithLifecycle(initialValue = emptyList())
    val expenses by vm.expenses.collectAsStateWithLifecycle(initialValue = emptyList())
    val monthGoal by XzgGraph.settings.monthGoal.collectAsStateWithLifecycle(initialValue = 0.0)
    val scope = rememberCoroutineScope()

    var newMode by remember { mutableStateOf<MoneyEditorMode?>(null) }
    var editingPerformance by remember { mutableStateOf<PerformanceEntity?>(null) }
    var editingExpense by remember { mutableStateOf<ExpenseEntity?>(null) }
    var deletingItem by remember { mutableStateOf<PerformanceRowItem?>(null) }
    var deleteError by remember { mutableStateOf<String?>(null) }

    V371Theme {
        val colors = LocalV371Colors.current

        PerformanceContent(
            performances = performances,
            expenses = expenses,
            monthGoal = monthGoal,
            onOpenTransactions = onOpenTransactions,
            onOpenSaobei = onOpenSaobei,
            onOpenGoods = onOpenGoods,
            onOpenMemo = onOpenMemo,
            onOpenDailyReport = onOpenDailyReport,
            onAddIncome = { newMode = MoneyEditorMode.NEW_INCOME },
            onAddExpense = { newMode = MoneyEditorMode.NEW_EXPENSE },
            onEdit = { item ->
                if (item.performance != null) editingPerformance = item.performance
                else if (item.expense != null) editingExpense = item.expense
            },
            onDelete = { deletingItem = it }
        )

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
                title = { Text("删除失败", style = V371Type.sectionTitle, color = colors.textPrimary) },
                text = { Text(message, style = V371Type.rowTitle, color = colors.textSecondary) },
                confirmButton = {
                    TextButton(onClick = { deleteError = null }) { Text("知道了", color = colors.blue) }
                },
                containerColor = colors.group
            )
        }
    }
}

/**
 * 经营数据页纯渲染内容（Paparazzi 截图入口）。
 * 统计派生保留在此；记账 Sheet / 删除确认保留在 [PerformanceScreen]。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PerformanceContent(
    performances: List<PerformanceEntity>,
    expenses: List<ExpenseEntity>,
    monthGoal: Double = 0.0,
    onOpenTransactions: () -> Unit = {},
    onOpenSaobei: () -> Unit = {},
    onOpenGoods: () -> Unit = {},
    onOpenMemo: () -> Unit = {},
    onOpenDailyReport: () -> Unit = {},
    onAddIncome: () -> Unit = {},
    onAddExpense: () -> Unit = {},
    onEdit: (PerformanceRowItem) -> Unit = {},
    onDelete: (PerformanceRowItem) -> Unit = {}
) {
    V371Theme {
        val colors = LocalV371Colors.current
        var menuExpanded by remember { mutableStateOf(false) }

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
        val goalProgress: Double =
            if (monthGoal > 0) (monthRevenue / monthGoal).coerceIn(0.0, 1.0) else 0.0
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
            // E2E 依赖 "performance.screen"（NavSmokeTest），保持不动
            modifier = Modifier.testTag("performance.screen"),
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            "经营数据",
                            style = V371Type.sectionTitle,
                            color = colors.textPrimary
                        )
                    },
                    actions = {
                        IconButton(onClick = onOpenGoods) {
                            Icon(
                                imageVector = Icons.Filled.Inventory,
                                contentDescription = "商品管理",
                                tint = colors.textPrimary
                            )
                        }
                        Box {
                            IconButton(onClick = { menuExpanded = true }) {
                                Icon(
                                    imageVector = Icons.Filled.Add,
                                    contentDescription = "记一笔",
                                    tint = colors.textPrimary
                                )
                            }
                            DropdownMenu(
                                expanded = menuExpanded,
                                onDismissRequest = { menuExpanded = false }
                            ) {
                                DropdownMenuItem(
                                    text = { Text("记收入") },
                                    onClick = { menuExpanded = false; onAddIncome() }
                                )
                                DropdownMenuItem(
                                    text = { Text("记支出") },
                                    onClick = { menuExpanded = false; onAddExpense() }
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
                                HorizontalDivider()
                                DropdownMenuItem(
                                    text = { Text("记录") },
                                    leadingIcon = {
                                        Icon(
                                            imageVector = Icons.Filled.EditNote,
                                            contentDescription = null
                                        )
                                    },
                                    onClick = { menuExpanded = false; onOpenMemo() }
                                )
                                DropdownMenuItem(
                                    text = { Text("今日经营日报") },
                                    leadingIcon = {
                                        Icon(
                                            imageVector = Icons.Filled.Description,
                                            contentDescription = null
                                        )
                                    },
                                    onClick = { menuExpanded = false; onOpenDailyReport() }
                                )
                            }
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = colors.canvas
                    )
                )
            },
            containerColor = colors.canvas
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = V371Space.page)
                    .padding(top = V371Space.page, bottom = V371Space.section),
                verticalArrangement = Arrangement.spacedBy(V371Space.section)
            ) {
                EditorialHero(
                    monthRevenue = monthRevenue,
                    todayRevenue = todayRevenue,
                    changePercent = changePercent,
                    trend = trend
                )
                GoalSection(
                    monthRevenue = monthRevenue,
                    monthGoal = monthGoal,
                    goalProgress = goalProgress,
                    yearRevenue = yearRevenue
                )
                IncomeSources(performances = performances, now = now)
                RecordsSection(
                    records = records,
                    onAddIncome = onAddIncome,
                    onEdit = onEdit,
                    onDelete = onDelete,
                    onOpenTransactions = onOpenTransactions
                )
            }
        }
    }
}

/**
 * 平面 Editorial Hero（对应 iOS `PerformanceView.editorialHero`）：
 * 「本月营业额」+ 大数字 + 今日/较昨日/趋势行。无蓝色大卡片。
 */
@Composable
private fun EditorialHero(
    monthRevenue: Double,
    todayRevenue: Double,
    changePercent: Double?,
    trend: List<Double>
) {
    val colors = LocalV371Colors.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
            .semantics {
                contentDescription = buildString {
                    append("本月营业额 ${Format.money(monthRevenue)}")
                    append("，今日 ${Format.money(todayRevenue)}")
                    if (changePercent != null) {
                        val direction = if (changePercent >= 0) "上涨" else "下降"
                        append("，较昨日$direction ${"%.1f".format(abs(changePercent))}%")
                    }
                }
            },
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            "本月营业额",
            style = V371Type.heroTitle,
            color = colors.textSecondary
        )
        Text(
            Format.money(monthRevenue),
            style = V371Type.heroNumber,
            color = colors.textPrimary,
            maxLines = 1
        )
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    "今日",
                    style = V371Type.rowSubtitle,
                    color = colors.textTertiary
                )
                Text(
                    Format.money(todayRevenue),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFeatureSettings = "tnum",
                    color = colors.textPrimary,
                    maxLines = 1
                )
                ChangeBadge(changePercent = changePercent)
            }
            if (trend.any { it > 0 }) {
                Sparkline(
                    values = trend,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(36.dp),
                    color = colors.blue
                )
            }
        }
    }
}

/** 较昨日涨跌 badge（对应 iOS `PerformanceView.changeBadge`）。 */
@Composable
private fun ChangeBadge(changePercent: Double?) {
    val colors = LocalV371Colors.current
    if (changePercent == null) {
        Text(
            text = "暂无昨日对比",
            style = V371Type.badge,
            color = colors.textTertiary
        )
    } else {
        val up = changePercent >= 0
        val tint = if (up) colors.green else colors.red
        Row(
            modifier = Modifier
                .clip(CircleShape)
                .background(colors.tinted(tint))
                .padding(horizontal = 9.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(
                imageVector = if (up) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(10.dp)
            )
            Text(
                text = "${"%.1f".format(abs(changePercent))}% 较昨日",
                style = V371Type.badge,
                color = tint
            )
        }
    }
}

/**
 * 月目标（对应 iOS `PerformanceView.goalSection`）：
 * SectionHeader + GroupSurface（本月/目标/进度条 + hairline + 本年累计）。
 */
@Composable
private fun GoalSection(
    monthRevenue: Double,
    monthGoal: Double,
    goalProgress: Double,
    yearRevenue: Double
) {
    val colors = LocalV371Colors.current
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionHeader("月目标")
        GroupSurface {
            Column(
                modifier = Modifier.padding(V371Space.rowPadding),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        Format.money(monthRevenue),
                        style = V371Type.rowTitle.copy(fontFeatureSettings = "tnum"),
                        color = colors.textPrimary
                    )
                    if (monthGoal > 0) {
                        Text(
                            "/ 目标 ${Format.money(monthGoal)}",
                            style = V371Type.rowSubtitle,
                            color = colors.textTertiary
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    if (monthGoal > 0) {
                        Text(
                            "${(goalProgress * 100).roundToInt()}%",
                            style = V371Type.badge.copy(fontFeatureSettings = "tnum"),
                            color = colors.blue
                        )
                    }
                }
                if (monthGoal > 0) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp)
                            .clip(CircleShape)
                            .background(colors.groupSecondary)
                            .semantics {
                                contentDescription = "月目标完成 ${(goalProgress * 100).roundToInt()}%"
                            }
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(goalProgress.toFloat())
                                .height(6.dp)
                                .clip(CircleShape)
                                .background(colors.blue)
                        )
                    }
                }
                V371Divider(leading = 0.dp)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "本年累计",
                        style = V371Type.rowSubtitle,
                        color = colors.textTertiary
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        Format.money(yearRevenue),
                        style = V371Type.rowTitle.copy(fontFeatureSettings = "tnum"),
                        color = colors.textPrimary
                    )
                }
            }
        }
    }
}

/**
 * 收入来源（对应 iOS `PerformanceView.sourcesSection`）：
 * SectionHeader + GroupSurface + WorkRow（门店=蓝/美团=橙/其他=灰）。
 */
@Composable
private fun IncomeSources(performances: List<PerformanceEntity>, now: Long) {
    val colors = LocalV371Colors.current
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
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionHeader("收入来源")
        GroupSurface {
            if (items.isEmpty()) {
                Text(
                    text = "本月暂无收入",
                    style = V371Type.rowSubtitle,
                    color = colors.textTertiary,
                    modifier = Modifier.padding(
                        horizontal = V371Space.rowPadding,
                        vertical = 14.dp
                    )
                )
            } else {
                items.forEachIndexed { index, (name, amount) ->
                    if (index > 0) {
                        V371Divider()
                    }
                    val (icon, iconColor) = when (name) {
                        "门店" -> Icons.Filled.Store to colors.blue
                        "美团" -> Icons.Filled.ShoppingBag to colors.orange
                        else -> Icons.Filled.MoreHoriz to colors.gray
                    }
                    WorkRow(
                        icon = icon,
                        iconColor = iconColor,
                        title = name,
                        subtitle = "占 ${(summary.ratio(amount) * 100).roundToInt()}%"
                    ) {
                        Text(
                            Format.money(amount),
                            style = V371Type.rowTitle.copy(fontFeatureSettings = "tnum"),
                            color = colors.textPrimary,
                            maxLines = 1
                        )
                    }
                }
            }
        }
    }
}

/**
 * 交易流水（对应 iOS `PerformanceView.recordsSection`）：
 * SectionHeader + GroupSurface（行 + hairline +「查看全部」行链）。
 */
@Composable
private fun RecordsSection(
    records: List<PerformanceRowItem>,
    onAddIncome: () -> Unit,
    onEdit: (PerformanceRowItem) -> Unit,
    onDelete: (PerformanceRowItem) -> Unit,
    onOpenTransactions: () -> Unit
) {
    val colors = LocalV371Colors.current
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionHeader("交易流水")
        GroupSurface {
            if (records.isEmpty()) {
                Column(
                    modifier = Modifier.padding(V371Space.rowPadding),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    EmptyState(
                        icon = Icons.Filled.QrCode,
                        title = "暂无交易记录",
                        message = "记录第一笔交易开始统计"
                    )
                    Box(
                        modifier = Modifier.fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "记一笔",
                            style = V371Type.rowTitle,
                            color = Color.White,
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(colors.blue)
                                .clickable(
                                    role = Role.Button,
                                    onClick = onAddIncome
                                )
                                .padding(horizontal = 20.dp, vertical = 12.dp)
                        )
                    }
                }
            } else {
                records.forEachIndexed { index, record ->
                    if (index > 0) {
                        V371Divider()
                    }
                    PerformanceRecordRow(
                        item = record,
                        onEdit = { onEdit(record) },
                        onDelete = { onDelete(record) }
                    )
                }
                V371Divider(leading = 0.dp)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(
                            role = Role.Button,
                            onClick = onOpenTransactions
                        )
                        .padding(
                            horizontal = V371Space.rowPadding,
                            vertical = 12.dp
                        )
                        .heightIn(min = 28.dp)
                        .semantics { contentDescription = "查看全部交易" },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "查看全部",
                        style = V371Type.rowTitle,
                        color = colors.blue
                    )
                    Spacer(Modifier.weight(1f))
                    V371Chevron()
                }
            }
        }
    }
}

/**
 * 交易行（对应 iOS `PerformanceRecordRow`）：
 * 36dp 图标圆 + 标题/副标题 + 金额（收入蓝 / 支出红）+ 删除。
 */
@Composable
private fun PerformanceRecordRow(
    item: PerformanceRowItem,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    val colors = LocalV371Colors.current
    val (icon, iconColor) = when {
        item.source == "扫呗" -> Icons.Filled.QrCode to colors.gray
        item.isIncome -> Icons.Filled.SouthWest to colors.blue
        else -> Icons.Filled.NorthEast to colors.red
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = V371Space.rowPadding, vertical = 10.dp)
            .heightIn(min = 44.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(colors.tinted(iconColor)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = iconColor,
                modifier = Modifier.size(16.dp)
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(
            modifier = Modifier
                .weight(1f)
                .clickable(onClick = onEdit),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(
                text = item.title,
                style = V371Type.rowTitle,
                color = colors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = if (item.source.isEmpty()) Format.shortDateTime(item.date)
                else "${item.source} · ${Format.shortDateTime(item.date)}",
                style = V371Type.rowSubtitle,
                color = colors.textTertiary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Text(
            text = (if (item.isIncome) "+" else "-") + Format.money(abs(item.amount)),
            style = V371Type.rowTitle.copy(fontFeatureSettings = "tnum"),
            color = if (item.isIncome) colors.blue else colors.red,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Spacer(Modifier.width(8.dp))
        IconButton(
            onClick = onDelete,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.Delete,
                contentDescription = "删除记录",
                tint = colors.textTertiary,
                modifier = Modifier.size(14.dp)
            )
        }
    }
}
