package com.xiaozhanggui.app.ui.screens.home

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Notes
import androidx.compose.material.icons.filled.Photo
import androidx.compose.material.icons.filled.WbCloudy
import androidx.compose.material3.AlertDialog
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
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
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.Sparkline
import com.xiaozhanggui.app.ui.components.V32Checkbox
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.theme.FixedSemanticColors
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.delay
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
 * 首页。对应 iOS `Features/Home/HomeView.swift`（V3.6 Home 1.4 Compact）。
 *
 * 结构（A_shell_home.md §2.2 逐字实现）：
 * ① header（问候/店主名/日期/天气按钮）→ ② RevenueHero（整卡可点→经营页）
 * → ③ weekRail（周一开头 7 天）→ ④ 今日事项（HomeInbox，limit=3）
 * → ⑤ 最近备忘（前 2）→ ⑥ 概览三格（待办/配送/临期）。
 * Toolbar：左抽屉按钮 / 右 mic 快速记录。
 *
 * 导航由 shell 层通过回调接线；抽屉本体见 [HomeDrawer]。
 */
private const val DAY_MILLIS = 24 * 3600 * 1000L

/** 今日事项行路由（对应 iOS HomeInboxItem.Route） */
enum class InboxRoute { TODO, CUSTOMER, EXPIRY }

data class HomeInboxUiItem(
    val id: String,
    val title: String,
    val subtitle: String,
    val time: String,
    val route: InboxRoute
)

data class HomeUiState(
    val greeting: String = "",
    val ownerName: String = "老板",
    val dateLabel: String = "",
    val todayRevenue: Double = 0.0,
    val changePercent: Double? = null,
    val trend: List<Double> = emptyList(),
    val monthRevenue: Double = 0.0,
    val monthGoal: Double = 0.0,
    val todoCount: Int = 0,
    val customerCount: Int = 0,
    val expiryCount: Int = 0,
    val todoInsight: String? = null,
    val customerInsight: String? = null,
    val expiryInsight: String? = null,
    val inboxItems: List<HomeInboxUiItem> = emptyList(),
    val recentMemos: List<MemoEntity> = emptyList(),
    val actionError: String? = null
)

class HomeViewModel(
    private val todoRepository: TodoRepository = XzgGraph.todoRepository,
    private val performanceRepository: PerformanceRepository = XzgGraph.performanceRepository,
    private val expiryRepository: ExpiryRepository = XzgGraph.expiryRepository,
    private val customerRepository: CustomerRepository = XzgGraph.customerRepository,
    private val memoRepository: MemoRepository = XzgGraph.memoRepository,
    private val settings: XzgSettings = XzgGraph.settings
) : ViewModel() {

    private val _actionError = MutableStateFlow<String?>(null)

    val uiState: StateFlow<HomeUiState> = combine(
        todoRepository.observeAll(),
        performanceRepository.observeAll(),
        expiryRepository.observeAll(),
        customerRepository.observeAll(),
        memoRepository.observeAll(),
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
            args[4] as List<MemoEntity>,
            args[5] as String,
            args[6] as Double,
            args[7] as String?
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), HomeUiState())

    /** 今日事项行勾选待办（对应 iOS toggleTodo，走 TodoRepository.toggleComplete） */
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
        memos: List<MemoEntity>,
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

        // 7 日趋势（今天往前 6 天）
        val trend = (6 downTo 0).map { back ->
            val d = todayStart - back * DAY_MILLIS
            performances.filter { it.date in d until d + DAY_MILLIS }.sumOf { it.amount }
        }

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

        return HomeUiState(
            greeting = DisplayLogic.greetingPhrase(now, owner),
            ownerName = owner,
            dateLabel = "${Format.monthDay(now)} ${weekdayLabel(now)}",
            todayRevenue = todayRevenue,
            changePercent = changePercent,
            trend = trend,
            monthRevenue = monthRevenue,
            monthGoal = monthGoal,
            todoCount = todayTodos.size,
            customerCount = deliveries.size,
            expiryCount = pendingExpiry.size,
            todoInsight = if (todayTodos.any { it.dueDate != null && DateExt.isSameDay(it.dueDate, now) }) "今天到期" else null,
            customerInsight = if (deliveries.isNotEmpty()) "待配送" else null,
            expiryInsight = if (pendingExpiry.any { daysLeft(it.expiryDate, now) <= 3 }) "≤3天" else null,
            inboxItems = buildInbox(todayTodos, deliveries, pendingExpiry, now),
            // MemoDao 已按 updatedAt 倒序
            recentMemos = memos.take(2),
            actionError = actionError
        )
    }

    /**
     * 今日事项收件箱（对应 iOS HomeInbox.items）：
     * 未完成待办（无截止/截止今天）+ 未完成客户需求 + 待处理临期，
     * 按 rank 升序、同 rank 按日期升序，取前 3。
     * rank：临期今天/过期=0、高优待办=1、配送中=2、普通配送=3、普通待办=4、远期临期=5。
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
                    route = InboxRoute.TODO
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
                    route = InboxRoute.CUSTOMER
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
                    route = InboxRoute.EXPIRY
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onOpenPerformance: () -> Unit,
    onOpenTodoTab: () -> Unit,
    onOpenCustomer: () -> Unit,
    onOpenExpiry: () -> Unit,
    onOpenMemo: () -> Unit,
    onOpenDrawer: () -> Unit,
    onOpenQuickRecord: () -> Unit,
    onOpenWeather: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HomeViewModel = viewModel(factory = XzgGraph.vmFactory { HomeViewModel() })
) {
    val palettes = LocalXzgPalettes.current
    val bg = palettes.background
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showWeatherSheet by remember { mutableStateOf(false) }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = {
                    IconButton(onClick = onOpenDrawer) {
                        Icon(
                            Icons.Filled.Menu,
                            contentDescription = "打开经营快捷中心",
                            tint = bg.textSecondary
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onOpenQuickRecord) {
                        Icon(
                            Icons.Filled.Mic,
                            contentDescription = "一句话快速记录",
                            tint = bg.textSecondary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
        },
        containerColor = bg.pageBG
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 6.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            HomeHeader(
                greeting = state.greeting,
                ownerName = state.ownerName,
                dateLabel = state.dateLabel,
                onWeatherClick = {
                    showWeatherSheet = true
                    onOpenWeather()
                }
            )
            RevenueHero(
                state = state,
                onOpenPerformance = onOpenPerformance,
                modifier = Modifier.homeEntrance(0)
            )
            WeekRail()
            FocusSection(
                items = state.inboxItems,
                onToggleTodo = viewModel::toggleTodo,
                onOpenRoute = { route ->
                    when (route) {
                        InboxRoute.TODO -> onOpenTodoTab()
                        InboxRoute.CUSTOMER -> onOpenCustomer()
                        InboxRoute.EXPIRY -> onOpenExpiry()
                    }
                },
                modifier = Modifier.homeEntrance(40)
            )
            if (state.recentMemos.isNotEmpty()) {
                RecentMemo(
                    memos = state.recentMemos,
                    onOpenMemo = onOpenMemo,
                    modifier = Modifier.homeEntrance(60)
                )
            }
            OverviewGrid(
                todoCount = state.todoCount,
                customerCount = state.customerCount,
                expiryCount = state.expiryCount,
                todoInsight = state.todoInsight,
                customerInsight = state.customerInsight,
                expiryInsight = state.expiryInsight,
                onTodo = onOpenTodoTab,
                onCustomer = onOpenCustomer,
                onExpiry = onOpenExpiry,
                modifier = Modifier.homeEntrance(80)
            )
            // 底部呼吸：V32 bottomPad(28) + 浮动 TabBar 预留(72+12)
            Spacer(modifier = Modifier.height((28 + 72 + 12).dp))
        }
    }

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

/** 首页入场：opacity 0→1 + 上浮 8dp（对应 iOS V32HomeEntrance；Reduce Motion 降级 Phase 5 接入） */
private fun Modifier.homeEntrance(delayMs: Int): Modifier = composed {
    val density = LocalDensity.current
    val alphaAnim = remember { Animatable(0f) }
    val riseAnim = remember { Animatable(with(density) { 8.dp.toPx() }) }
    LaunchedEffect(Unit) {
        delay(delayMs.toLong())
        launch { alphaAnim.animateTo(1f, animationSpec = tween(280)) }
        launch { riseAnim.animateTo(0f, animationSpec = tween(280)) }
    }
    graphicsLayer {
        alpha = alphaAnim.value
        translationY = riseAnim.value
    }
}

/** ① header：问候语 / 店主名(30sp bold，空→"老板") / 日期 / 右侧天气按钮 */
@Composable
private fun HomeHeader(
    greeting: String,
    ownerName: String,
    dateLabel: String,
    onWeatherClick: () -> Unit
) {
    val bg = LocalXzgPalettes.current.background
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Bottom
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                greeting,
                style = XzgType.body.copy(fontWeight = FontWeight.Medium),
                color = bg.textSecondary
            )
            Text(
                ownerName,
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
                color = bg.textPrimary,
                maxLines = 1
            )
            Text(
                dateLabel,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = bg.textTertiary,
                modifier = Modifier.padding(top = 1.dp)
            )
        }
        TextButton(
            onClick = onWeatherClick,
            modifier = Modifier.heightIn(min = 44.dp),
            contentPadding = PaddingValues(horizontal = 2.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                Icon(
                    Icons.Filled.WbCloudy,
                    contentDescription = null,
                    tint = bg.textSecondary,
                    modifier = Modifier.size(16.dp)
                )
                // 温度占位：Phase 5 接入真实数据前显示 "--"
                Text(
                    "--",
                    style = XzgType.body.copy(
                        fontWeight = FontWeight.SemiBold,
                        fontFeatureSettings = "tnum"
                    ),
                    color = bg.textSecondary
                )
            }
        }
    }
}

/** ② RevenueHero（对应 iOS V35HomeRevenueHero）：整卡可点→经营页 */
@Composable
private fun RevenueHero(
    state: HomeUiState,
    onOpenPerformance: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    val accent = palettes.accent
    val fixed = palettes.fixed
    val progress = if (state.monthGoal > 0) {
        (state.monthRevenue / state.monthGoal).toFloat().coerceIn(0f, 1f)
    } else 0f
    val completedPercent = (progress * 100).toInt()

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(accent.heroStart, accent.heroEnd),
                    start = androidx.compose.ui.geometry.Offset(0f, 0f),
                    end = androidx.compose.ui.geometry.Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY)
                )
            )
            .clickable(onClick = onOpenPerformance, role = Role.Button)
            .semantics {
                contentDescription = "今日营业额 ${Format.money(state.todayRevenue)}，点击查看经营数据"
            }
            .padding(horizontal = 22.dp, vertical = 15.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.Top) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        "今日营业额",
                        style = XzgType.body.copy(fontWeight = FontWeight.Medium),
                        color = fixed.textOnHeroSecondary
                    )
                    Text(
                        "¥" + Format.groupedAmount(state.todayRevenue),
                        style = TextStyle(
                            fontSize = 48.sp,
                            fontWeight = FontWeight.Bold,
                            fontFeatureSettings = "tnum"
                        ),
                        color = fixed.textOnHero,
                        maxLines = 1
                    )
                    // 昨日为 0 → 不显示涨跌
                    state.changePercent?.let { change ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                if (change >= 0) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward,
                                contentDescription = null,
                                tint = fixed.brandOnHero,
                                modifier = Modifier.size(12.dp)
                            )
                            Text(
                                "${"%+.1f".format(change)}% 较昨日",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = fixed.brandOnHero
                            )
                        }
                    }
                }
                if (state.trend.any { it > 0 }) {
                    Sparkline(
                        values = state.trend,
                        color = accent.chartAccent,
                        modifier = Modifier
                            .size(width = 92.dp, height = 26.dp)
                            .padding(top = 10.dp)
                    )
                }
            }
            HorizontalDivider(
                color = fixed.dividerOnHero.copy(alpha = 0.7f),
                thickness = 1.dp
            )
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                HeroMetric("本月", Format.money(state.monthRevenue), fixed)
                HeroMetric("目标", Format.money(state.monthGoal), fixed)
                HeroMetric("完成", "$completedPercent%", fixed)
            }
            // 3dp 进度条：底 textOnHero 0.16，填充 secondaryAccent
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .clip(CircleShape)
                    .background(fixed.textOnHero.copy(alpha = 0.16f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progress)
                        .fillMaxHeight()
                        .clip(CircleShape)
                        .background(accent.secondaryAccent)
                )
            }
        }
    }
}

@Composable
private fun HeroMetric(title: String, value: String, fixed: FixedSemanticColors) {
    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Text(title, fontSize = 12.sp, color = fixed.textOnHeroSecondary)
        Text(
            value,
            style = XzgType.metricSmall.copy(fontFeatureSettings = "tnum"),
            color = fixed.textOnHero
        )
    }
}

/** ③ weekRail：本周 7 天（周一开头）；今天 accent 底白字圆角 14 */
@Composable
private fun WeekRail(modifier: Modifier = Modifier) {
    val palettes = LocalXzgPalettes.current
    val bg = palettes.background
    val today = LocalDate.now()
    val monday = today.with(DayOfWeek.MONDAY)
    val symbols = listOf("一", "二", "三", "四", "五", "六", "日")

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        (0..6).forEach { index ->
            val date = monday.plusDays(index.toLong())
            val isToday = date == today
            Column(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 48.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (isToday) palettes.accent.accent else Color.Transparent)
                    .padding(vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterVertically)
            ) {
                Text(
                    symbols[index],
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (isToday) palettes.accent.onAccent else bg.textSecondary
                )
                Text(
                    "${date.dayOfMonth}",
                    style = XzgType.body.copy(
                        fontWeight = FontWeight.SemiBold,
                        fontFeatureSettings = "tnum"
                    ),
                    color = if (isToday) palettes.accent.onAccent else bg.textSecondary
                )
            }
        }
    }
}

/** ④ 今日事项（对应 iOS V35HomeFocusSection + HomeActionRow） */
@Composable
private fun FocusSection(
    items: List<HomeInboxUiItem>,
    onToggleTodo: (String) -> Unit,
    onOpenRoute: (InboxRoute) -> Unit,
    modifier: Modifier = Modifier
) {
    val bg = LocalXzgPalettes.current.background
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        V32SectionHeader("今日事项")
        if (items.isEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    Icons.Filled.Check,
                    contentDescription = null,
                    tint = bg.textTertiary,
                    modifier = Modifier.size(16.dp)
                )
                Text("今天暂无待处理事项", style = XzgType.body, color = bg.textTertiary)
            }
        } else {
            Column {
                items.forEachIndexed { index, item ->
                    HomeActionRow(
                        item = item,
                        onToggle = { onToggleTodo(item.id) },
                        onClick = { onOpenRoute(item.route) }
                    )
                    if (index == 0 && items.size > 1) {
                        HorizontalDivider(
                            color = bg.divider,
                            modifier = Modifier.padding(start = 48.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeActionRow(
    item: HomeInboxUiItem,
    onToggle: () -> Unit,
    onClick: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val bg = palettes.background
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clickable(onClick = onClick, role = Role.Button)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        when (item.route) {
            // 待办：V32Checkbox 可直接勾选（toggleComplete）
            InboxRoute.TODO -> V32Checkbox(checked = false, onCheckedChange = onToggle)
            InboxRoute.CUSTOMER -> Icon(
                Icons.Filled.LocalShipping,
                contentDescription = null,
                tint = palettes.accent.accent,
                modifier = Modifier.size(28.dp)
            )
            InboxRoute.EXPIRY -> Icon(
                Icons.Filled.HourglassEmpty,
                contentDescription = null,
                tint = palettes.fixed.amber,
                modifier = Modifier.size(28.dp)
            )
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(item.title, style = XzgType.title, color = bg.textPrimary, maxLines = 2)
            if (item.subtitle.isNotEmpty()) {
                Text(item.subtitle, style = XzgType.caption, color = bg.textTertiary, maxLines = 1)
            }
        }
        Text(item.time, style = XzgType.caption, color = bg.textTertiary, maxLines = 1)
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = bg.textQuaternary,
            modifier = Modifier.size(11.dp)
        )
    }
}

/** ⑤ 最近备忘（对应 iOS V35HomeRecentMemo）：前 2 条，整块可点→备忘页 */
@Composable
private fun RecentMemo(
    memos: List<MemoEntity>,
    onOpenMemo: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    val bg = palettes.background
    Column(
        modifier = modifier.padding(top = 4.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        V32SectionHeader("最近备忘")
        Column(
            modifier = Modifier
                .clickable(onClick = onOpenMemo, role = Role.Button)
                .semantics { contentDescription = "最近备忘，打开备忘" }
        ) {
            memos.forEachIndexed { index, memo ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 44.dp)
                        .padding(vertical = 11.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        if (memo.imagePath == null) Icons.Filled.Notes else Icons.Filled.Photo,
                        contentDescription = null,
                        tint = palettes.fixed.info,
                        modifier = Modifier
                            .size(18.dp)
                            .padding(top = 2.dp)
                    )
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        val titleText = when {
                            memo.title.isNotBlank() -> memo.title
                            memo.content.isNotBlank() -> memo.content
                            else -> "无标题"
                        }
                        Text(
                            titleText,
                            style = XzgType.body.copy(fontWeight = FontWeight.SemiBold),
                            color = bg.textPrimary,
                            maxLines = 1
                        )
                        if (memo.title.isNotBlank() && memo.content.isNotBlank()) {
                            Text(
                                memo.content,
                                style = XzgType.caption,
                                color = bg.textTertiary,
                                maxLines = 1
                            )
                        }
                    }
                    Text(
                        Format.memoTime(memo.updatedAt),
                        fontSize = 11.sp,
                        color = bg.textQuaternary,
                        maxLines = 1
                    )
                }
                if (index < memos.size - 1) {
                    HorizontalDivider(
                        color = bg.divider,
                        modifier = Modifier.padding(start = 28.dp)
                    )
                }
            }
        }
    }
}

/** ⑥ 概览三格（对应 iOS V35HomeOverviewGrid）：待办 / 配送 / 临期 */
@Composable
private fun OverviewGrid(
    todoCount: Int,
    customerCount: Int,
    expiryCount: Int,
    todoInsight: String?,
    customerInsight: String?,
    expiryInsight: String?,
    onTodo: () -> Unit,
    onCustomer: () -> Unit,
    onExpiry: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    val bg = palettes.background
    Column(modifier = modifier) {
        HorizontalDivider(color = bg.divider.copy(alpha = 0.6f))
        Row(modifier = Modifier.padding(vertical = 12.dp)) {
            OverviewCell(
                title = "待办",
                count = todoCount,
                insight = todoInsight,
                icon = Icons.Filled.CheckCircle,
                iconTint = palettes.accent.accent,
                onClick = onTodo,
                modifier = Modifier.weight(1f)
            )
            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(24.dp)
                    .background(bg.divider.copy(alpha = 0.7f))
                    .align(Alignment.CenterVertically)
            )
            OverviewCell(
                title = "配送",
                count = customerCount,
                insight = customerInsight,
                icon = Icons.Filled.LocalShipping,
                iconTint = palettes.fixed.info,
                onClick = onCustomer,
                modifier = Modifier.weight(1f)
            )
            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(24.dp)
                    .background(bg.divider.copy(alpha = 0.7f))
                    .align(Alignment.CenterVertically)
            )
            OverviewCell(
                title = "临期",
                count = expiryCount,
                insight = expiryInsight,
                icon = Icons.Filled.AccessTime,
                iconTint = palettes.fixed.amber,
                onClick = onExpiry,
                modifier = Modifier.weight(1f)
            )
        }
        HorizontalDivider(color = bg.divider.copy(alpha = 0.6f))
    }
}

@Composable
private fun OverviewCell(
    title: String,
    count: Int,
    insight: String?,
    icon: ImageVector,
    iconTint: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val bg = LocalXzgPalettes.current.background
    Box(
        modifier = modifier
            .heightIn(min = 44.dp)
            .clickable(onClick = onClick, role = Role.Button)
            .semantics { contentDescription = "今天$title$count 项，打开$title" },
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(16.dp))
            Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Text(title, fontSize = 11.sp, color = bg.textTertiary)
                Text(
                    "$count",
                    style = XzgType.body.copy(
                        fontWeight = FontWeight.SemiBold,
                        fontFeatureSettings = "tnum"
                    ),
                    color = bg.textSecondary
                )
                insight?.let { Text(it, fontSize = 11.sp, color = bg.textTertiary) }
            }
        }
    }
}
