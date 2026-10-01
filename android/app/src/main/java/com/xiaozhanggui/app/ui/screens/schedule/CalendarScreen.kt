package com.xiaozhanggui.app.ui.screens.schedule

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.CalendarDayData
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.domain.EventFlag
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** 日历星期头：周日首列，对应 iOS CalendarView firstWeekday=1（与日程的周一开头区分）。 */
private val WEEK_SYMBOLS_SUN = listOf("日", "一", "二", "三", "四", "五", "六")

/** 状态点颜色，对应 iOS CalendarView.swift:290-300。 */
private val FLAG_ORDER = listOf(EventFlag.MONEY, EventFlag.TODO, EventFlag.EXPIRY, EventFlag.CUSTOMER)

/**
 * 日历页（日程的二级入口「完整月历」）。对应 iOS `Calendar/CalendarView.swift`：
 * - 月视图：周日开头，可切换月份；每天格子显示当日事项状态点
 * - 选中日期的日程详情（复用 [CalendarAgenda] 聚合；客户配送按解码 deliveryTime 聚合，
 *   编码串用 [DisplayLogic.visible] 隐藏）
 *
 * 详情行为纯展示（无导航回调）；返回走系统返回键。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(modifier: Modifier = Modifier) {
    val vm: ScheduleViewModel = viewModel(
        factory = XzgGraph.vmFactory {
            ScheduleViewModel(
                XzgGraph.todoRepository,
                XzgGraph.performanceRepository,
                XzgGraph.expenseRepository,
                XzgGraph.expiryRepository,
                XzgGraph.customerRepository,
                XzgGraph.memoRepository
            )
        }
    )

    val monthMillis by vm.monthMillis.collectAsStateWithLifecycle()
    val selectedDay by vm.selectedDayMillis.collectAsStateWithLifecycle()
    val flags by vm.monthFlags.collectAsStateWithLifecycle()
    val data by vm.dayData.collectAsStateWithLifecycle()

    CalendarContent(
        monthMillis = monthMillis,
        selectedDayMillis = selectedDay,
        flags = flags,
        data = data,
        onShiftMonth = { vm.shiftMonth(it) },
        onSelectDay = { vm.selectDay(it) },
        modifier = modifier
    )
}

/**
 * 日历页纯渲染内容（Paparazzi 截图入口）。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarContent(
    monthMillis: Long,
    selectedDayMillis: Long,
    flags: Map<Long, Set<EventFlag>>,
    data: CalendarDayData,
    onShiftMonth: (Int) -> Unit = {},
    onSelectDay: (Long) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current

    Scaffold(
        modifier = modifier,
        containerColor = palettes.background.pageBG,
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = "日历",
                        style = XzgType.headline,
                        color = palettes.background.textPrimary
                    )
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = palettes.background.pageBG
                )
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(
                start = XzgDimens.pageMargin,
                end = XzgDimens.pageMargin,
                top = 8.dp,
                bottom = 32.dp
            ),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item(key = "navigator") {
                CalendarMonthNavigator(
                    monthMillis = monthMillis,
                    onShiftMonth = onShiftMonth
                )
            }
            item(key = "grid") {
                V32Card {
                    CalendarWeekdayHeader()
                    Spacer(Modifier.height(8.dp))
                    CalendarMonthGrid(
                        monthMillis = monthMillis,
                        selectedDay = selectedDayMillis,
                        flags = flags,
                        onSelectDay = onSelectDay
                    )
                }
            }
            item(key = "detailHeader") {
                Text(
                    text = "${Format.monthDay(selectedDayMillis)} · 星期${weekdaySymbol(selectedDayMillis)}",
                    style = XzgType.headline,
                    color = palettes.background.textPrimary
                )
            }
            item(key = "detail") {
                CalendarDayDetail(data = data)
            }
        }
    }
}
}

/** 月份导航：chevron.left /「2026年10月」/ chevron.right。对应 iOS monthNavigator。 */
@Composable
private fun CalendarMonthNavigator(monthMillis: Long, onShiftMonth: (Int) -> Unit) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = { onShiftMonth(-1) }) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                contentDescription = "上个月",
                tint = palettes.background.textSecondary
            )
        }
        Text(
            text = DateTimeFormatter.ofPattern("yyyy年M月", Locale.CHINA)
                .format(localDateOf(monthMillis)),
            style = XzgType.headline,
            color = palettes.background.textPrimary,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.Center
        )
        IconButton(onClick = { onShiftMonth(1) }) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = "下个月",
                tint = palettes.background.textSecondary
            )
        }
    }
}

@Composable
private fun CalendarWeekdayHeader() {
    val palettes = LocalXzgPalettes.current
    Row(modifier = Modifier.fillMaxWidth()) {
        WEEK_SYMBOLS_SUN.forEach { symbol ->
            Text(
                text = symbol,
                style = XzgType.caption,
                color = palettes.background.textTertiary,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

/**
 * 月网格：7 列，首尾补空位（总格数=7 倍数）。周日首列。
 * 对应 iOS CalendarView monthGrid（LazyVGrid 7 列 + nil 补位）。
 */
@Composable
private fun CalendarMonthGrid(
    monthMillis: Long,
    selectedDay: Long,
    flags: Map<Long, Set<EventFlag>>,
    onSelectDay: (Long) -> Unit
) {
    val monthDate = localDateOf(monthMillis)
    val leadingBlanks = monthDate.withDayOfMonth(1).dayOfWeek.value % 7 // 周日=0
    val daysInMonth = monthDate.lengthOfMonth()
    val cells: List<Int?> = List(leadingBlanks) { null } + (1..daysInMonth).toList()
    val rows = cells.chunked(7)

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        rows.forEach { row ->
            Row(modifier = Modifier.fillMaxWidth()) {
                row.forEach { dayOfMonth ->
                    if (dayOfMonth == null) {
                        Spacer(Modifier.weight(1f))
                    } else {
                        val dayStart = monthDate.withDayOfMonth(dayOfMonth)
                            .atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                        CalendarDayCell(
                            dayOfMonth = dayOfMonth,
                            isToday = DateExt.isToday(dayStart),
                            isSelected = DateExt.isSameDay(dayStart, selectedDay),
                            dayFlags = flags[dayStart] ?: emptySet(),
                            onClick = { onSelectDay(dayStart) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                // 补齐末行空格（chunked 末行可能不足 7 格）
                repeat(7 - row.size) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

/**
 * 日期格：今日=品牌色实心圆白字；选中=卡片色圆+描边；状态点最多 4 点。
 * 对应 iOS CalendarDayCell。
 */
@Composable
private fun CalendarDayCell(
    dayOfMonth: Int,
    isToday: Boolean,
    isSelected: Boolean,
    dayFlags: Set<EventFlag>,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = modifier
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(
                    when {
                        isToday -> palettes.accent.accent
                        isSelected -> palettes.background.cardElevated
                        else -> Color.Transparent
                    }
                )
                .then(
                    if (isSelected && !isToday) {
                        Modifier.border(1.dp, palettes.background.cardOutline, CircleShape)
                    } else {
                        Modifier
                    }
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = dayOfMonth.toString(),
                style = XzgType.subhead,
                color = when {
                    isToday -> palettes.accent.onAccent
                    else -> palettes.background.textPrimary
                },
                textAlign = TextAlign.Center
            )
        }
        Spacer(Modifier.height(3.dp))
        Row(
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            modifier = Modifier.height(5.dp)
        ) {
            FLAG_ORDER.forEach { flag ->
                if (dayFlags.contains(flag)) {
                    Box(
                        modifier = Modifier
                            .size(4.dp)
                            .clip(CircleShape)
                            .background(flagColor(flag))
                    )
                }
            }
        }
    }
}

@Composable
private fun flagColor(flag: EventFlag): Color {
    val palettes = LocalXzgPalettes.current
    return when (flag) {
        EventFlag.MONEY -> palettes.accent.accent
        EventFlag.TODO -> palettes.fixed.info
        EventFlag.EXPIRY -> palettes.fixed.amber
        EventFlag.CUSTOMER -> palettes.background.neutral
    }
}

private fun weekdaySymbol(millis: Long): String =
    WEEK_SYMBOLS_SUN[localDateOf(millis).dayOfWeek.value % 7]

/**
 * 选中日期详情：营业额/收支 / 待办事项 / 记录 / 临期提醒 / 客户需求。
 * 对应 iOS CalendarView.swift:199-246 的详情行。
 */
@Composable
private fun CalendarDayDetail(data: CalendarDayData) {
    val palettes = LocalXzgPalettes.current
    val hasMoney = data.performances.isNotEmpty() || data.expenses.isNotEmpty()
    val hasAny = hasMoney || data.todos.isNotEmpty() || data.memos.isNotEmpty() ||
        data.expiryItems.isNotEmpty() || data.customers.isNotEmpty()

    if (!hasAny) {
        Text(
            text = "当天暂无经营记录",
            style = XzgType.subhead,
            color = palettes.background.textTertiary,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 24.dp)
        )
        return
    }

    V32Card {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (hasMoney) {
                val revenue = data.performances.sumOf { it.amount }
                CalendarDetailCategory(
                    dotColor = palettes.accent.accent,
                    label = "营业额/收支",
                    lines = listOf(
                        "收入 ${data.performances.size} 笔 · 支出 ${data.expenses.size} 笔"
                    ),
                    trailing = "¥${Format.groupedAmount(revenue)}"
                )
            }
            if (data.todos.isNotEmpty()) {
                CalendarDetailCategory(
                    dotColor = palettes.fixed.info,
                    label = "待办事项",
                    lines = data.todos.take(2).map { todo ->
                        val timePart = todo.dueDate?.let {
                            if (DateExt.hasClock(it)) Format.time(it) else "全天"
                        } ?: "全天"
                        "$timePart ${DisplayLogic.visible(todo.title, "待办事项")}"
                    }
                )
            }
            if (data.memos.isNotEmpty()) {
                CalendarDetailCategory(
                    dotColor = palettes.background.neutral,
                    label = "记录",
                    lines = data.memos.take(2).map {
                        DisplayLogic.visible(it.title, "备忘")
                    }
                )
            }
            if (data.expiryItems.isNotEmpty()) {
                CalendarDetailCategory(
                    dotColor = palettes.fixed.amber,
                    label = "临期提醒",
                    lines = data.expiryItems.take(2).map {
                        "${DisplayLogic.visible(it.name, "临期商品")} × ${it.quantity}"
                    }
                )
            }
            if (data.customers.isNotEmpty()) {
                CalendarDetailCategory(
                    dotColor = palettes.background.neutral,
                    label = "客户需求",
                    lines = data.customers.take(2).map { customerDeliveryLine(it) }
                )
            }
        }
    }
}

/** 详情分类行：圆点 + 标签 + 副标题行 + 右侧金额。对应 iOS CalendarDetailRow。 */
@Composable
private fun CalendarDetailCategory(
    dotColor: Color,
    label: String,
    lines: List<String>,
    trailing: String? = null
) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(dotColor)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = label,
                style = XzgType.subhead,
                color = palettes.background.textSecondary
            )
            if (trailing != null) {
                Spacer(Modifier.weight(1f))
                Text(
                    text = trailing,
                    style = XzgType.headline,
                    color = palettes.background.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        lines.forEach { line ->
            Text(
                text = line,
                style = XzgType.subhead,
                color = palettes.background.textTertiary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(start = 16.dp)
            )
        }
    }
}
