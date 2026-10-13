package com.xiaozhanggui.app.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.WbCloudy
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.datastore.XzgSettings
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.AICommandEntry
import com.xiaozhanggui.app.ui.components.EmptyState
import com.xiaozhanggui.app.ui.components.GroupSurface
import com.xiaozhanggui.app.ui.components.SectionHeader
import com.xiaozhanggui.app.ui.components.StatusBadge
import com.xiaozhanggui.app.ui.components.TimedRow
import com.xiaozhanggui.app.ui.components.V371Chevron
import com.xiaozhanggui.app.ui.components.V371Divider
import com.xiaozhanggui.app.ui.components.WorkRow
import com.xiaozhanggui.app.ui.theme.v371.LocalV371Colors
import com.xiaozhanggui.app.ui.theme.v371.V371Space
import com.xiaozhanggui.app.ui.theme.v371.V371TestTags
import com.xiaozhanggui.app.ui.theme.v371.V371Theme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneId

/**
 * 首页（V3.7.1 Editorial 平面结构，对应 iOS `Features/Home/HomeView.swift`）。
 *
 * 结构：Header（日期 + 天气按钮 / 记一笔胶囊 + 头像；第二行大问候）
 * → heroFlat（「今日营业额」+ ¥ 大数字 +「较昨日 ±x.x% · 月目标 xx%」，可点击进经营）
 * → AICommandEntry →「今日重点」（GroupSurface 三 WorkRow：客户配送 / 今日待办 / 临期退货，
 * 行间 hairline）→「接下来」（TimedRow 最多 3 项，彩色 accent 条；空则 EmptyState）。
 *
 * V3.6 结构已移除：大蓝渐变 Hero / 周条 / 最近备忘 / 概览三格 / 抽屉入口。
 * 头像按钮与 AICommandEntry 的点击行为由导航 worker 接线（[onOpenProfile] / [onOpenAI]）。
 */
private const val DAY_MILLIS = 24 * 3600 * 1000L

/** 今日事项行路由（对应 iOS HomeInboxItem.Route） */
enum class InboxRoute { TODO, CUSTOMER, EXPIRY }

/** 「接下来」行色调（对应 iOS HomeInboxItem.Tone） */
enum class InboxTone { NORMAL, ACCENT, WARNING, URGENT }

data class HomeInboxUiItem(
    val id: String,
    val title: String,
    val subtitle: String,
    val time: String,
    val route: InboxRoute,
    val tone: InboxTone = InboxTone.NORMAL
)

data class HomeUiState(
    val greeting: String = "",
    val dateLabel: String = "",
    val todayRevenue: Double = 0.0,
    val changePercent: Double? = null,
    val monthRevenue: Double = 0.0,
    val monthGoal: Double = 0.0,
    val todoCount: Int = 0,
    val customerCount: Int = 0,
    val expiryCount: Int = 0,
    val todoSubtitle: String = "",
    val deliverySubtitle: String = "",
    val expirySubtitle: String = "",
    val inboxItems: List<HomeInboxUiItem> = emptyList(),
    val actionError: String? = null
)

class HomeViewModel(
    private val todoRepository: TodoRepository = XzgGraph.todoRepository,
    private val performanceRepository: PerformanceRepository = XzgGraph.performanceRepository,
    private val expiryRepository: ExpiryRepository = XzgGraph.expiryRepository,
    private val customerRepository: CustomerRepository = XzgGraph.customerRepository,
    private val settings: XzgSettings = XzgGraph.settings
) : ViewModel() {

    private val _actionError = MutableStateFlow<String?>(null)

    val uiState: StateFlow<HomeUiState> = combine(
        todoRepository.observeAll(),
        performanceRepository.observeAll(),
        expiryRepository.observeAll(),
        customerRepository.observeAll(),
        settings.ownerName,
        settings.monthGoal,
        _actionError
    ) { args: Array<Any?> ->
        @Suppress("UNCHECKED_CAST")
        buildState(
            args[0] as List<TodoEntity>,
            args[1] as List<PerformanceEntity>,
            args[2] as List<ExpiryItemEntity>,
            args[3] as List<CustomerRequestEntity>,
            args[4] as String,
            args[5] as Double,
            args[6] as String?
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), HomeUiState())

    /** 待办状态切换（走 TodoRepository.toggleComplete；V3.7.1 首页无勾选 UI，保留供他处复用） */
    fun toggleTodo(itemId: String) {
        viewModelScope.launch {
            try {
                val todo = todoRepository.observeAll().first()
                    .firstOrNull { "todo-${it.notificationId}" == itemId }
                if (todo != null) {
                    todoRepository.toggleComplete(todo)
                } else {
                    _actionError.value = "待办状态未改变，请重试。"
                }
            } catch (e: Exception) {
                _actionError.value = "待办状态未改变，请重试。"
            }
        }
    }

    fun clearActionError() {
        _actionError.value = null
    }

    private fun buildState(
        todos: List<TodoEntity>,
        performances: List<PerformanceEntity>,
        expiryItems: List<ExpiryItemEntity>,
        customers: List<CustomerRequestEntity>,
        ownerNameRaw: String,
        monthGoal: Double,
        actionError: String?
    ): HomeUiState {
        val now = System.currentTimeMillis()
        val owner = ownerNameRaw.trim().ifEmpty { "老板" }
        val todayStart = DateExt.startOfDay(now)

        // 今日/昨日营业额（GATE C：按业务 date 落区间）
        val todayRevenue = performances
            .filter { it.date in todayStart until todayStart + DAY_MILLIS }
            .sumOf { it.amount }
        val yesterdayStart = todayStart - DAY_MILLIS
        val yesterdayRevenue = performances
            .filter { it.date in yesterdayStart until todayStart }
            .sumOf { it.amount }
        // 昨日为 0 → 不显示涨跌（对应 iOS changePercent == nil）
        val changePercent =
            if (yesterdayRevenue > 0) (todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100 else null

        // 本月累计
        val monthStart = DateExt.startOfMonth(now)
        val nextMonthStart = DateExt.startOfNextMonth(now)
        val monthRevenue = performances
            .filter { it.date in monthStart until nextMonthStart }
            .sumOf { it.amount }

        // 今日事项口径（对应 iOS TodaySummary）
        val todayTodos = todos
            .filter { !it.isCompleted && (it.dueDate == null || DateExt.isSameDay(it.dueDate, now)) }
            .sortedBy { it.dueDate ?: Long.MAX_VALUE }
        val deliveries = customers.filter { it.status != CustomerStatus.DONE }
        val pendingExpiry = expiryItems.filter { it.returnStatus == ReturnStatus.PENDING }

        // 「今日重点」副标题（对应 iOS HomeView 的 deliverySubtitle / todoSubtitle / expirySubtitle）
        val deliveringCount = deliveries.count { it.status == CustomerStatus.DELIVERING }
        val deliverySubtitle = when {
            deliveringCount > 0 -> "有 $deliveringCount 单配送中"
            deliveries.isEmpty() -> "暂无配送"
            else -> "待配送"
        }
        val dueTodayCount = todayTodos.count { it.dueDate != null && DateExt.isSameDay(it.dueDate, now) }
        val todoSubtitle = when {
            dueTodayCount > 0 -> "$dueTodayCount 项今天到期"
            todayTodos.isEmpty() -> "全部完成"
            else -> "灵活安排"
        }
        val urgentExpiryCount = pendingExpiry.count { daysLeft(it.expiryDate, now) <= 3 }
        val expirySubtitle = when {
            urgentExpiryCount > 0 -> "$urgentExpiryCount 件 3 天内临期"
            pendingExpiry.isEmpty() -> "暂无临期"
            else -> "待处理"
        }

        return HomeUiState(
            greeting = DisplayLogic.greetingPhrase(now, owner),
            dateLabel = "${Format.monthDay(now)} ${weekdayLabel(now)}",
            todayRevenue = todayRevenue,
            changePercent = changePercent,
            monthRevenue = monthRevenue,
            monthGoal = monthGoal,
            todoCount = todayTodos.size,
            customerCount = deliveries.size,
            expiryCount = pendingExpiry.size,
            todoSubtitle = todoSubtitle,
            deliverySubtitle = deliverySubtitle,
            expirySubtitle = expirySubtitle,
            inboxItems = buildInbox(todayTodos, deliveries, pendingExpiry, now),
            actionError = actionError
        )
    }

    /**
     * 今日事项收件箱（对应 iOS HomeInbox.items，limit=3）：
     * 未完成待办（无截止/截止今天）+ 未完成客户需求 + 待处理临期，
     * 按 rank 升序、同 rank 按日期升序，取前 3。
     * rank：临期今天/过期=0、高优待办=1、配送中=2、普通配送=3、普通待办=4、远期临期=5。
     * tone：高优待办/过期临期=urgent、配送中=accent、近临期=warning、其余=normal。
     */
    private fun buildInbox(
        todayTodos: List<TodoEntity>,
        deliveries: List<CustomerRequestEntity>,
        pendingExpiry: List<ExpiryItemEntity>,
        now: Long
    ): List<HomeInboxUiItem> {
        // Triple(item, rank, sortDate)
        val items = mutableListOf<Triple<HomeInboxUiItem, Int, Long>>()

        for (todo in todayTodos) {
            val high = todo.priority >= 2
            items += Triple(
                HomeInboxUiItem(
                    id = "todo-${todo.notificationId}",
                    title = DisplayLogic.visible(todo.title, "待办事项"),
                    subtitle = DisplayLogic.visible(todo.detail, priorityLabel(todo.priority)),
                    time = DisplayLogic.dayTimeLabel(todo.dueDate, "全天"),
                    route = InboxRoute.TODO,
                    tone = if (high) InboxTone.URGENT else InboxTone.NORMAL
                ),
                if (high) 1 else 4,
                todo.dueDate ?: todo.createdAt
            )
        }

        for (request in deliveries) {
            val delivering = request.status == CustomerStatus.DELIVERING
            val name = DisplayLogic.visible(
                CustomerDeliveryStorage.decode(request.customer).legacyCustomer, ""
            )
            val titleFallback = if (name.isEmpty()) "客户配送" else name
            items += Triple(
                HomeInboxUiItem(
                    id = "delivery-${request.notificationId}",
                    title = DisplayLogic.visible(request.content, titleFallback),
                    subtitle = listOf(name, request.roomOrAddress.trim())
                        .filter { it.isNotEmpty() }.joinToString(" · "),
                    time = if (delivering) "配送中" else "配送",
                    route = InboxRoute.CUSTOMER,
                    tone = if (delivering) InboxTone.ACCENT else InboxTone.NORMAL
                ),
                if (delivering) 2 else 3,
                request.updatedAt
            )
        }

        for (item in pendingExpiry) {
            val days = daysLeft(item.expiryDate, now)
            val rank = when {
                days <= 0 -> 0
                days <= 1 -> 2
                else -> 5
            }
            val tone = when {
                days <= 0 -> InboxTone.URGENT
                else -> InboxTone.WARNING
            }
            items += Triple(
                HomeInboxUiItem(
                    id = "expiry-${item.notificationId}",
                    title = "${DisplayLogic.visible(item.name, "临期商品")} × ${item.quantity}",
                    subtitle = when {
                        days < 0 -> "已临期"
                        days == 0L -> "今天临期"
                        else -> "即将临期"
                    },
                    time = if (days <= 0) "今天" else "${days}天",
                    route = InboxRoute.EXPIRY,
                    tone = tone
                ),
                rank,
                item.expiryDate
            )
        }

        return items
            .sortedWith(compareBy({ it.second }, { it.third }))
            .take(3)
            .map { it.first }
    }

    private fun daysLeft(expiryDate: Long, now: Long): Long =
        DateExt.daysBetween(DateExt.startOfDay(now), DateExt.startOfDay(expiryDate))

    private fun priorityLabel(priority: Int): String = when (priority) {
        2 -> "高优先级"
        1 -> "中优先级"
        else -> "低优先级"
    }

    private fun weekdayLabel(nowMillis: Long): String {
        val dow = Instant.ofEpochMilli(nowMillis).atZone(ZoneId.systemDefault()).dayOfWeek
        val symbol = when (dow) {
            DayOfWeek.MONDAY -> "一"
            DayOfWeek.TUESDAY -> "二"
            DayOfWeek.WEDNESDAY -> "三"
            DayOfWeek.THURSDAY -> "四"
            DayOfWeek.FRIDAY -> "五"
            DayOfWeek.SATURDAY -> "六"
            DayOfWeek.SUNDAY -> "日"
        }
        return "星期$symbol"
    }
}

@Composable
fun HomeScreen(
    onOpenPerformance: () -> Unit,
    onOpenTodoTab: () -> Unit,
    onOpenCustomer: () -> Unit,
    onOpenExpiry: () -> Unit,
    /** 头像 → 个人中心。V3.7.1 新增入口，由导航 worker 接线（默认空实现，保持 XzgNavGraph 可编译）。 */
    onOpenProfile: () -> Unit = {},
    /** AICommandEntry → AI Sheet（AI 不再是 Tab）。由导航 worker 接线（默认空实现，保持 XzgNavGraph 可编译）。 */
    onOpenAI: () -> Unit = {},
    onOpenQuickRecord: () -> Unit,
    onWeatherClick: () -> Unit,
    /**
     * V3.6 遗留参数：V3.7.1 首页已无备忘入口（备忘迁至经营 Tab）。
     * 导航 worker 重写 XzgNavGraph 时移除。
     */
    onOpenMemo: () -> Unit = {},
    /**
     * V3.6 遗留参数：V3.7.1 首页已无抽屉入口。
     * 导航 worker 重写 XzgNavGraph 时移除。
     */
    onOpenDrawer: () -> Unit = {},
    modifier: Modifier = Modifier,
    viewModel: HomeViewModel = viewModel(factory = XzgGraph.vmFactory { HomeViewModel() })
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showWeatherSheet by remember { mutableStateOf(false) }

    HomeContent(
        state = state,
        onOpenPerformance = onOpenPerformance,
        onOpenTodoTab = onOpenTodoTab,
        onOpenCustomer = onOpenCustomer,
        onOpenExpiry = onOpenExpiry,
        onOpenProfile = onOpenProfile,
        onOpenAI = onOpenAI,
        onOpenQuickRecord = onOpenQuickRecord,
        onWeatherClick = {
            showWeatherSheet = true
            onWeatherClick()
        },
        modifier = modifier
    )

    if (showWeatherSheet) {
        WeatherSheet(onDismiss = { showWeatherSheet = false })
    }

    state.actionError?.let { message ->
        AlertDialog(
            onDismissRequest = viewModel::clearActionError,
            confirmButton = {
                TextButton(onClick = viewModel::clearActionError) { Text("知道了") }
            },
            title = { Text("操作失败") },
            text = { Text(message) }
        )
    }
}

/**
 * 首页纯渲染内容（Paparazzi 截图入口）。
 *
 * V3.7.1 Editorial 结构：Header → heroFlat → AICommandEntry →「今日重点」→「接下来」。
 */
@Composable
fun HomeContent(
    state: HomeUiState,
    onOpenPerformance: () -> Unit,
    onOpenTodoTab: () -> Unit,
    onOpenCustomer: () -> Unit,
    onOpenExpiry: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenAI: () -> Unit,
    onOpenQuickRecord: () -> Unit,
    onWeatherClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    V371Theme {
        val colors = LocalV371Colors.current
        Column(
            modifier = modifier
                .fillMaxSize()
                .background(colors.canvas)
                .testTag(V371TestTags.SCREEN_HOME)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = V371Space.page)
                .padding(top = 10.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(V371Space.section)
        ) {
            HomeHeader(
                dateLabel = state.dateLabel,
                greeting = state.greeting,
                onWeatherClick = onWeatherClick,
                onOpenQuickRecord = onOpenQuickRecord,
                onOpenProfile = onOpenProfile
            )
            HeroFlat(state = state, onOpenPerformance = onOpenPerformance)
            AICommandEntry(onClick = onOpenAI)
            FocusSection(
                state = state,
                onOpenTodoTab = onOpenTodoTab,
                onOpenCustomer = onOpenCustomer,
                onOpenExpiry = onOpenExpiry
            )
            NextSection(
                items = state.inboxItems,
                onOpenRoute = { route ->
                    when (route) {
                        InboxRoute.TODO -> onOpenTodoTab()
                        InboxRoute.CUSTOMER -> onOpenCustomer()
                        InboxRoute.EXPIRY -> onOpenExpiry()
                    }
                }
            )
            // 滚动末端锚点（对应 iOS V371ScrollEndMarker；无额外留白）
            Spacer(modifier = Modifier.height(1.dp).testTag(V371TestTags.SCROLL_END_HOME))
            // 底部呼吸：V32 bottomPad(28) + 浮动 Dock 预留(72+12)；Dock 本体由导航 worker 接线
            Spacer(modifier = Modifier.height((28 + 72 + 12).dp))
        }
    }
}

/**
 * ① Header（对应 iOS HomeView.header）：
 * 第一行：日期 + 天气按钮 … 记一笔胶囊 + 头像；第二行：大问候。
 */
@Composable
private fun HomeHeader(
    dateLabel: String,
    greeting: String,
    onWeatherClick: () -> Unit,
    onOpenQuickRecord: () -> Unit,
    onOpenProfile: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                dateLabel,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = colors.textSecondary
            )
            // 天气按钮（温度占位：Phase 5 接入真实数据前显示 "--"）
            Row(
                modifier = Modifier
                    .heightIn(min = 44.dp)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        role = Role.Button,
                        onClick = onWeatherClick
                    )
                    .padding(horizontal = 2.dp)
                    .semantics { contentDescription = "天气" },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                Icon(
                    Icons.Filled.WbCloudy,
                    contentDescription = null,
                    tint = colors.textSecondary,
                    modifier = Modifier.size(15.dp)
                )
                Text(
                    "--",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.textSecondary
                )
            }
            Spacer(modifier = Modifier.weight(1f))
            // 记一笔胶囊
            Row(
                modifier = Modifier
                    .heightIn(min = 44.dp)
                    .clip(CircleShape)
                    .background(colors.frostedFill)
                    .border(0.5.dp, colors.frostedBorder, CircleShape)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        role = Role.Button,
                        onClick = onOpenQuickRecord
                    )
                    .testTag(V371TestTags.HOME_QUICK_RECORD)
                    .semantics { contentDescription = "记一笔，支持文字或语音快速记录" }
                    .padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    Icons.Filled.EditNote,
                    contentDescription = null,
                    tint = colors.textPrimary,
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    "记一笔",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.textPrimary
                )
            }
            // 头像 → 个人中心
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(colors.frostedFill)
                    .border(0.5.dp, colors.frostedBorder, CircleShape)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        role = Role.Button,
                        onClick = onOpenProfile
                    )
                    .testTag(V371TestTags.HOME_PROFILE)
                    .semantics { contentDescription = "个人中心" },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.Person,
                    contentDescription = null,
                    tint = colors.textPrimary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        Text(
            greeting,
            fontSize = 30.sp,
            fontWeight = FontWeight.Bold,
            color = colors.textPrimary,
            maxLines = 1
        )
    }
}

/**
 * ② heroFlat（对应 iOS HomeView.heroFlat）：平面 Editorial 排版，无大蓝渐变。
 * 「今日营业额」+ ¥ 大数字 +「较昨日 ±x.x% · 月目标 xx%」，整块可点进经营。
 */
@Composable
private fun HeroFlat(
    state: HomeUiState,
    onOpenPerformance: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    val interactionSource = remember { MutableInteractionSource() }
    val infoParts = buildList {
        state.changePercent?.let { change ->
            val sign = if (change >= 0) "+" else ""
            add("较昨日 $sign${"%.1f".format(change)}%")
        }
        if (state.monthGoal > 0) {
            add("月目标 ${"%.0f".format(state.monthRevenue / state.monthGoal * 100)}%")
        }
    }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
                onClick = onOpenPerformance
            )
            .testTag(V371TestTags.HERO_REVENUE)
            .semantics {
                contentDescription =
                    "今日营业额 ¥${Format.groupedAmount(state.todayRevenue)}，查看经营详情"
            }
            .padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            "今日营业额",
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = colors.textSecondary
        )
        Text(
            "¥" + Format.groupedAmount(state.todayRevenue),
            fontSize = 54.sp,
            fontWeight = FontWeight.SemiBold,
            color = colors.textPrimary,
            maxLines = 1,
            letterSpacing = (-1.5).sp
        )
        if (infoParts.isNotEmpty()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                infoParts.forEachIndexed { index, part ->
                    if (index > 0) {
                        Box(
                            modifier = Modifier
                                .size(3.dp)
                                .clip(CircleShape)
                                .background(colors.textTertiary)
                        )
                    }
                    Text(
                        part,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.textSecondary
                    )
                }
            }
        }
    }
}

/** ③「今日重点」（对应 iOS HomeView.focusSection） */
@Composable
private fun FocusSection(
    state: HomeUiState,
    onOpenTodoTab: () -> Unit,
    onOpenCustomer: () -> Unit,
    onOpenExpiry: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        SectionHeader("今日重点")
        GroupSurface {
            WorkRow(
                icon = Icons.Filled.LocalShipping,
                iconColor = colors.blue,
                title = "客户配送",
                subtitle = state.deliverySubtitle,
                onClick = onOpenCustomer,
                testTag = V371TestTags.HOME_CUSTOMER
            ) {
                StatusBadge("${state.customerCount} 单", color = colors.blue)
                V371Chevron()
            }
            V371Divider()
            WorkRow(
                icon = Icons.Filled.Checklist,
                iconColor = colors.green,
                title = "今日待办",
                subtitle = state.todoSubtitle,
                onClick = onOpenTodoTab
            ) {
                StatusBadge("${state.todoCount} 项", color = colors.green)
                V371Chevron()
            }
            V371Divider()
            WorkRow(
                icon = Icons.Filled.HourglassEmpty,
                iconColor = colors.orange,
                title = "临期退货",
                subtitle = state.expirySubtitle,
                onClick = onOpenExpiry,
                testTag = V371TestTags.HOME_EXPIRY
            ) {
                StatusBadge("${state.expiryCount} 件", color = colors.orange)
                V371Chevron()
            }
        }
    }
}

/** ④「接下来」（对应 iOS HomeView.nextSection）：TimedRow 最多 3 项，空则 EmptyState */
@Composable
private fun NextSection(
    items: List<HomeInboxUiItem>,
    onOpenRoute: (InboxRoute) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        SectionHeader("接下来")
        GroupSurface {
            if (items.isEmpty()) {
                EmptyState(
                    icon = Icons.Filled.WbSunny,
                    title = "今天暂无安排",
                    message = "待办、配送与临期事项会出现在这里"
                )
            } else {
                items.forEachIndexed { index, item ->
                    if (index > 0) {
                        V371Divider(leading = 30.dp)
                    }
                    TimedRow(
                        time = item.time,
                        title = item.title,
                        subtitle = item.subtitle.ifEmpty { null },
                        accent = when (item.tone) {
                            InboxTone.URGENT -> colors.red
                            InboxTone.WARNING -> colors.orange
                            InboxTone.ACCENT -> colors.blue
                            InboxTone.NORMAL -> colors.gray
                        },
                        onClick = { onOpenRoute(item.route) }
                    )
                }
            }
        }
    }
}
