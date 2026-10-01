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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.BubbleTone
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32Checkbox
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32IconBubble
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import java.time.DayOfWeek

/** 周条星期符号：周一起始，对应 iOS ScheduleView.firstWeekday=2。 */
private val WEEK_SYMBOLS_MON = listOf("一", "二", "三", "四", "五", "六", "日")

/**
 * 日程页。对应 iOS `Schedule/ScheduleView.swift`：
 * - 周条（周一起始）+ 当日时间轴（「时间」）+ 全天事项 + 当日经营摘要
 * - 工具栏：标题「日程」+「今天」+ 日历图标（二级入口「完整月历」）
 *
 * 行点击通过回调交由 coordinator 接线到对应业务页：
 * @param onOpenCalendar 打开日历二级入口
 * @param onTodoClick 待办行点击（待办 id）
 * @param onExpiryClick 临期行点击（临期 id）
 * @param onCustomerClick 配送行点击（客户需求 id）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleScreen(
    onOpenCalendar: () -> Unit,
    onTodoClick: (String) -> Unit,
    onExpiryClick: (String) -> Unit,
    onCustomerClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    val haptic = LocalHapticFeedback.current
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

    val selectedDay by vm.selectedDayMillis.collectAsStateWithLifecycle()
    val day by vm.scheduleDay.collectAsStateWithLifecycle()
    val togglingIds by vm.togglingIds.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()

    ScheduleContent(
        selectedDayMillis = selectedDay,
        day = day,
        togglingIds = togglingIds,
        onSelectDay = {
            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            vm.selectDay(it)
        },
        onShiftWeek = { vm.shiftWeek(it) },
        onSelectToday = { vm.selectToday() },
        onOpenCalendar = onOpenCalendar,
        onToggleTodo = {
            val completing = !it.isCompleted
            haptic.performHapticFeedback(
                if (completing) HapticFeedbackType.LongPress
                else HapticFeedbackType.TextHandleMove
            )
            vm.toggleTodo(it)
        },
        onTodoClick = onTodoClick,
        onCustomerClick = onCustomerClick,
        onExpiryClick = onExpiryClick,
        modifier = modifier
    )

    error?.let {
        AlertDialog(
            onDismissRequest = vm::clearError,
            title = {
                Text(
                    text = it.title,
                    style = XzgType.headline,
                    color = palettes.background.textPrimary
                )
            },
            text = {
                Text(
                    text = it.message,
                    style = XzgType.body,
                    color = palettes.background.textSecondary
                )
            },
            confirmButton = {
                TextButton(onClick = vm::clearError) { Text("知道了") }
            },
            containerColor = palettes.background.card
        )
    }
}

/**
 * 日程页纯渲染内容（Paparazzi 截图入口）。
 * 错误弹窗保留在 [ScheduleScreen]。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduleContent(
    selectedDayMillis: Long,
    day: ScheduleDay,
    onSelectDay: (Long) -> Unit = {},
    onShiftWeek: (Int) -> Unit = {},
    onSelectToday: () -> Unit = {},
    onOpenCalendar: () -> Unit = {},
    togglingIds: Set<String> = emptySet(),
    onToggleTodo: (TodoEntity) -> Unit = {},
    onTodoClick: (String) -> Unit = {},
    onCustomerClick: (String) -> Unit = {},
    onExpiryClick: (String) -> Unit = {},
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
                        text = "日程",
                        style = XzgType.headline,
                        color = palettes.background.textPrimary
                    )
                },
                actions = {
                    TextButton(onClick = onSelectToday) {
                        Text(
                            text = "今天",
                            style = XzgType.subhead,
                            color = palettes.background.textSecondary
                        )
                    }
                    IconButton(onClick = onOpenCalendar) {
                        Icon(
                            imageVector = Icons.Filled.CalendarMonth,
                            contentDescription = "完整月历",
                            tint = palettes.background.textSecondary
                        )
                    }
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
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            item(key = "weekStrip") {
                ScheduleWeekStrip(
                    selectedDay = selectedDayMillis,
                    onSelectDay = onSelectDay,
                    onShiftWeek = onShiftWeek
                )
            }
            if (day.timedEvents.isNotEmpty()) {
                item(key = "timeline") {
                    ScheduleTimelineSection(
                        events = day.timedEvents,
                        onTodoClick = onTodoClick,
                        onCustomerClick = onCustomerClick
                    )
                }
            }
            item(key = "allDay") {
                ScheduleAllDaySection(
                    day = day,
                    togglingIds = togglingIds,
                    onToggleTodo = onToggleTodo,
                    onTodoClick = onTodoClick,
                    onCustomerClick = onCustomerClick,
                    onExpiryClick = onExpiryClick
                )
            }
            item(key = "summary") {
                ScheduleSummarySection(day = day)
            }
        }
    }
}

/** 周条：月份标题 + 左右切周 + 本周 7 天（周一起始）。对应 iOS weekStrip。 */
@Composable
private fun ScheduleWeekStrip(
    selectedDay: Long,
    onSelectDay: (Long) -> Unit,
    onShiftWeek: (Int) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val selectedDate = localDateOf(selectedDay)
    val weekStart = selectedDate.with(DayOfWeek.MONDAY)
    val days = (0..6).map { weekStart.plusDays(it.toLong()) }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = java.time.format.DateTimeFormatter
                    .ofPattern("yyyy年M月", java.util.Locale.CHINA)
                    .format(selectedDate),
                style = XzgType.headline,
                color = palettes.background.textPrimary
            )
            Spacer(Modifier.weight(1f))
            WeekArrowButton(
                icon = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                description = "上一周",
                onClick = { onShiftWeek(-1) }
            )
            Spacer(Modifier.width(8.dp))
            WeekArrowButton(
                icon = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                description = "下一周",
                onClick = { onShiftWeek(1) }
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            days.forEachIndexed { index, date ->
                val dayMillis = date.atStartOfDay(java.time.ZoneId.systemDefault())
                    .toInstant().toEpochMilli()
                ScheduleWeekDayCell(
                    symbol = WEEK_SYMBOLS_MON[index],
                    dayOfMonth = date.dayOfMonth,
                    isSelected = DateExt.isSameDay(dayMillis, selectedDay),
                    isToday = DateExt.isToday(dayMillis),
                    onClick = { onSelectDay(dayMillis) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun WeekArrowButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    description: String,
    onClick: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(30.dp)
            .clip(CircleShape)
            .background(palettes.background.card)
            .border(1.dp, palettes.background.cardOutline, CircleShape)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = description,
            tint = palettes.background.textSecondary,
            modifier = Modifier.size(16.dp)
        )
    }
}

/** 周条单格：星期符号 + 日期数字；选中=品牌浅底圆角块，今日未选中时下方小圆点。 */
@Composable
private fun ScheduleWeekDayCell(
    symbol: String,
    dayOfMonth: Int,
    isSelected: Boolean,
    isToday: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(13.dp))
            .background(
                if (isSelected) palettes.accent.selectedTint
                else palettes.background.pageBG
            )
            .clickable(onClick = onClick)
            .padding(vertical = 9.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = symbol,
            style = XzgType.caption,
            color = when {
                isSelected -> palettes.background.textPrimary
                isToday -> palettes.accent.accent
                else -> palettes.background.textSecondary
            }
        )
        Text(
            text = dayOfMonth.toString(),
            style = XzgType.headline,
            color = when {
                isSelected -> palettes.background.textPrimary
                isToday -> palettes.accent.accent
                else -> palettes.background.textSecondary
            }
        )
        // 预留 4dp 高度：今日小圆点显隐不引起格子高度抖动
        Box(
            modifier = Modifier.height(4.dp),
            contentAlignment = Alignment.Center
        ) {
            if (isToday && !isSelected) {
                Box(
                    modifier = Modifier
                        .size(4.dp)
                        .clip(CircleShape)
                        .background(palettes.accent.accent)
                )
            }
        }
    }
}

/** 时间轴「时间」section：左侧 HH:mm + 卡片。对应 iOS timelineSection。 */
@Composable
private fun ScheduleTimelineSection(
    events: List<ScheduleEvent>,
    onTodoClick: (String) -> Unit,
    onCustomerClick: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        V32SectionHeader(title = "时间")
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            events.forEach { event ->
                ScheduleTimelineRow(
                    event = event,
                    onTodoClick = onTodoClick,
                    onCustomerClick = onCustomerClick
                )
            }
        }
    }
}

@Composable
private fun ScheduleTimelineRow(
    event: ScheduleEvent,
    onTodoClick: (String) -> Unit,
    onCustomerClick: (String) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val done = when (event) {
        is ScheduleEvent.Todo -> event.todo.isCompleted
        is ScheduleEvent.Delivery -> event.request.status == CustomerStatus.DONE
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = Format.time(event.date),
            style = XzgType.subhead,
            color = palettes.background.textTertiary,
            modifier = Modifier.width(48.dp)
        )
        val (icon, tone, title, subtitle) = when (event) {
            is ScheduleEvent.Todo -> Quad(
                Icons.Filled.CheckCircle, BubbleTone.BRAND,
                DisplayLogic.visible(event.todo.title, "待办事项"),
                DisplayLogic.visible(
                    event.todo.detail,
                    listOf("低优先级", "中优先级", "高优先级")[event.todo.priority.coerceIn(0, 2)]
                )
            )
            is ScheduleEvent.Delivery -> Quad(
                if (done) Icons.Filled.CheckCircle else Icons.Filled.LocalShipping,
                if (done) BubbleTone.NEUTRAL else BubbleTone.BRAND,
                customerDisplayName(event.request),
                customerSubtitle(event.request)
            )
        }
        Row(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(12.dp))
                .clickable(
                    onClick = {
                        when (event) {
                            is ScheduleEvent.Todo -> onTodoClick(event.todo.id)
                            is ScheduleEvent.Delivery -> onCustomerClick(event.request.id)
                        }
                    }
                )
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            V32IconBubble(icon = icon, tone = tone, size = 38.dp)
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = XzgType.title,
                    color = if (done) palettes.background.textTertiary
                    else palettes.background.textPrimary,
                    textDecoration = if (done) TextDecoration.LineThrough else null,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                if (subtitle.isNotEmpty()) {
                    Spacer(Modifier.height(3.dp))
                    Text(
                        text = subtitle,
                        style = XzgType.caption,
                        color = palettes.background.textTertiary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            if (event is ScheduleEvent.Delivery) {
                Icon(
                    imageVector = Icons.Filled.ChevronRight,
                    contentDescription = null,
                    tint = palettes.background.textQuaternary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

private data class Quad<A, B, C, D>(val a: A, val b: B, val c: C, val d: D)

/** 「全天事项」section：全天 todos（可直接勾选）/ 配送 / 临期（可展开）/ 备忘。 */
@Composable
private fun ScheduleAllDaySection(
    day: ScheduleDay,
    togglingIds: Set<String>,
    onToggleTodo: (TodoEntity) -> Unit,
    onTodoClick: (String) -> Unit,
    onCustomerClick: (String) -> Unit,
    onExpiryClick: (String) -> Unit
) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        V32SectionHeader(title = "全天事项") {
            if (!day.allDay.isEmpty) {
                Text(
                    text = "${day.allDay.count} 项",
                    style = XzgType.subhead,
                    color = palettes.background.textTertiary
                )
            }
        }
        if (day.isEmpty) {
            V32Card {
                V32EmptyState(
                    icon = Icons.Filled.WbSunny,
                    title = "该日期暂无事项",
                    message = "这一天还没有安排"
                )
            }
        } else if (!day.allDay.isEmpty) {
            val rows = mutableListOf<@Composable () -> Unit>()
            day.allDay.todos.forEach { todo ->
                rows += {
                    ScheduleAllDayTodoRow(
                        todo = todo,
                        toggleEnabled = !togglingIds.contains(todo.id),
                        onToggle = { onToggleTodo(todo) },
                        onClick = { onTodoClick(todo.id) }
                    )
                }
            }
            day.allDay.deliveries.forEach { request ->
                rows += { ScheduleDeliveryRow(request = request, onClick = { onCustomerClick(request.id) }) }
            }
            day.allDay.expiry.forEach { item ->
                rows += {
                    ScheduleExpiryRow(
                        item = item,
                        dayMillis = day.dateMillis,
                        onClick = { onExpiryClick(item.id) }
                    )
                }
            }
            day.allDay.memos.forEach { memo ->
                rows += { ScheduleMemoRow(memo = memo) }
            }
            // 全天行需要顶边对齐（V32Card 自带内边距会错位），此处按 V32Card 视觉自建无内边距卡片
            val cardShape = RoundedCornerShape(XzgDimens.card)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(cardShape)
                    .background(palettes.background.card)
                    .border(1.dp, palettes.background.cardOutline, cardShape)
            ) {
                rows.forEachIndexed { index, row ->
                    row()
                    if (index < rows.lastIndex) {
                        AllDayDivider()
                    }
                }
            }
        }
    }
}

@Composable
private fun AllDayDivider() {
    HorizontalDivider(
        color = LocalXzgPalettes.current.background.divider,
        modifier = Modifier.padding(start = 58.dp)
    )
}

/** 全天待办行：V32Checkbox 直接切换完成；整行点击进待办。对应 iOS allDayTodoRow。 */
@Composable
private fun ScheduleAllDayTodoRow(
    todo: TodoEntity,
    toggleEnabled: Boolean,
    onToggle: () -> Unit,
    onClick: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp)
            .height(54.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        V32Checkbox(
            checked = todo.isCompleted,
            // V32Checkbox 无 enabled 参数：300ms 防抖窗口内的点击在回调里直接忽略
            onCheckedChange = { if (toggleEnabled) onToggle() }
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp)
                .clickable(onClick = onClick)
        ) {
            Text(
                text = DisplayLogic.visible(todo.title, "待办事项"),
                style = XzgType.title,
                color = if (todo.isCompleted) palettes.background.textTertiary
                else palettes.background.textPrimary,
                textDecoration = if (todo.isCompleted) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            if (todo.priority == 2 && !todo.isCompleted) {
                Text(
                    text = "高优先级",
                    style = XzgType.caption,
                    color = palettes.fixed.amber
                )
            }
        }
    }
}

/** 全天配送行：点击进客户配送。 */
@Composable
private fun ScheduleDeliveryRow(
    request: CustomerRequestEntity,
    onClick: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val done = request.status == CustomerStatus.DONE
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp)
            .height(54.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        V32IconBubble(
            icon = if (done) Icons.Filled.CheckCircle else Icons.Filled.LocalShipping,
            tone = if (done) BubbleTone.NEUTRAL else BubbleTone.BRAND,
            size = 34.dp
        )
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = customerDisplayName(request),
                style = XzgType.title,
                color = if (done) palettes.background.textTertiary
                else palettes.background.textPrimary,
                textDecoration = if (done) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            val subtitle = customerSubtitle(request)
            if (subtitle.isNotEmpty()) {
                Spacer(Modifier.height(3.dp))
                Text(
                    text = subtitle,
                    style = XzgType.caption,
                    color = palettes.background.textTertiary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        Icon(
            imageVector = Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = palettes.background.textQuaternary,
            modifier = Modifier.size(16.dp)
        )
    }
}

/**
 * 全天临期行：点击进临期页；右端 chevron 按钮展开/折叠备注。
 * 对应 iOS expiryRow（默认折叠，点击展开备注）。
 */
@Composable
private fun ScheduleExpiryRow(
    item: ExpiryItemEntity,
    dayMillis: Long,
    onClick: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    var expanded by remember(item.id) { mutableStateOf(false) }
    val days = DateExt.daysBetween(
        DateExt.startOfDay(dayMillis),
        DateExt.startOfDay(item.expiryDate)
    )
    val hint = when {
        days < 0 -> "已临期 ${-days} 天"
        days == 0L -> "今天临期"
        else -> "$days 天后到期"
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp)
                .height(54.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            V32IconBubble(
                icon = Icons.Filled.HourglassEmpty,
                tone = BubbleTone.AMBER,
                size = 34.dp
            )
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${DisplayLogic.visible(item.name, "临期商品")} × ${item.quantity}",
                    style = XzgType.title,
                    color = palettes.background.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = hint,
                    style = XzgType.caption,
                    color = palettes.fixed.amber
                )
            }
            IconButton(
                onClick = { expanded = !expanded },
                modifier = Modifier.size(36.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.ChevronRight,
                    contentDescription = if (expanded) "收起备注" else "展开备注",
                    tint = palettes.background.textQuaternary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        if (expanded && item.note.trim().isNotEmpty()) {
            Text(
                text = DisplayLogic.visible(item.note, "退货备注"),
                style = XzgType.subhead,
                color = palettes.background.textSecondary,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 12.dp, end = 12.dp, bottom = 12.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(palettes.background.cardInset)
                    .padding(12.dp)
            )
        }
    }
}

/** 全天备忘行：展示用（备忘编辑入口在待办页备忘 tab）。 */
@Composable
private fun ScheduleMemoRow(memo: MemoEntity) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        V32IconBubble(
            icon = Icons.Filled.Description,
            tone = BubbleTone.NEUTRAL,
            size = 34.dp
        )
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = DisplayLogic.visible(memo.title, "备忘"),
                style = XzgType.title,
                color = palettes.background.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (memo.content.trim().isNotEmpty()) {
                Spacer(Modifier.height(3.dp))
                Text(
                    text = memo.content.trim(),
                    style = XzgType.caption,
                    color = palettes.background.textTertiary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/** 「当日经营」摘要：收入/支出/净额三格（流水只聚合，不逐笔列）。对应 iOS summarySection。 */
@Composable
private fun ScheduleSummarySection(day: ScheduleDay) {
    val palettes = LocalXzgPalettes.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        V32SectionHeader(title = "当日经营")
        V32Card {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                ScheduleMetricCell(
                    label = "当日收入",
                    value = "¥${Format.groupedAmount(day.revenue)}",
                    modifier = Modifier.weight(1f)
                )
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(34.dp)
                        .background(palettes.background.divider)
                )
                ScheduleMetricCell(
                    label = "当日支出",
                    value = "¥${Format.groupedAmount(day.expense)}",
                    modifier = Modifier.weight(1f)
                )
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(34.dp)
                        .background(palettes.background.divider)
                )
                ScheduleMetricCell(
                    label = "净额",
                    value = "¥${Format.groupedAmount(day.net)}",
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun ScheduleMetricCell(label: String, value: String, modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = XzgType.caption,
            color = palettes.background.textTertiary
        )
        Text(
            text = value,
            style = XzgType.headline.copy(fontWeight = FontWeight.SemiBold),
            color = palettes.background.textPrimary,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}
