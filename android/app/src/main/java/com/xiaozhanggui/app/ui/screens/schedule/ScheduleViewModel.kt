package com.xiaozhanggui.app.ui.screens.schedule

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpenseRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.CalendarAgenda
import com.xiaozhanggui.app.domain.CalendarDayData
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.EventFlag
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * 日程/日历页共用的 ViewModel。对应 iOS ScheduleView/CalendarView 的 @Query 全量 6 表
 * + @State（selectedDate / month）：
 * - 6 张表的全量 Flow（Todo/Performance/Expense/Expiry/Customer/Memo）
 * - selectedDayMillis：选中日期（当天 0 点 millis）
 * - monthMillis：日历月视图当前月份（当月 1 日 0 点 millis）
 * - dayData：选中日期的 [CalendarDayData] 聚合（纯内存，复用 [CalendarAgenda]）
 * - scheduleDay：选中日期的日程派生（时间轴/全天/经营摘要，见 [deriveScheduleDay]）
 * - monthFlags：当前月份每天的事件旗标（日历月视图状态点用）
 */
class ScheduleViewModel(
    private val todoRepo: TodoRepository,
    performanceRepo: PerformanceRepository,
    expenseRepo: ExpenseRepository,
    expiryRepo: ExpiryRepository,
    customerRepo: CustomerRepository,
    memoRepo: MemoRepository
) : ViewModel() {

    private val _selectedDayMillis = MutableStateFlow(DateExt.startOfDay(System.currentTimeMillis()))
    val selectedDayMillis: StateFlow<Long> = _selectedDayMillis.asStateFlow()

    private val _monthMillis = MutableStateFlow(DateExt.startOfMonth(System.currentTimeMillis()))
    val monthMillis: StateFlow<Long> = _monthMillis.asStateFlow()

    private val todos: StateFlow<List<TodoEntity>> = todoRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    private val performances: StateFlow<List<PerformanceEntity>> = performanceRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    private val expenses: StateFlow<List<ExpenseEntity>> = expenseRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    private val expiryItems: StateFlow<List<ExpiryItemEntity>> = expiryRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    private val customers: StateFlow<List<CustomerRequestEntity>> = customerRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    private val memos: StateFlow<List<MemoEntity>> = memoRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    /** 6 表全量快照（避免 7 路 combine 的类型体操）。 */
    private data class ScheduleTables(
        val todos: List<TodoEntity>,
        val performances: List<PerformanceEntity>,
        val expenses: List<ExpenseEntity>,
        val expiryItems: List<ExpiryItemEntity>,
        val customers: List<CustomerRequestEntity>,
        val memos: List<MemoEntity>
    )

    private val tables: StateFlow<ScheduleTables> = combine(
        todos, performances, expenses, expiryItems, customers, memos
    ) { ts, ps, es, xs, cs, ms ->
        ScheduleTables(ts, ps, es, xs, cs, ms)
    }.stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5000),
        ScheduleTables(emptyList(), emptyList(), emptyList(), emptyList(), emptyList(), emptyList())
    )

    val dayData: StateFlow<CalendarDayData> = combine(tables, _selectedDayMillis) { t, day ->
        CalendarAgenda.dayData(
            dayMillis = day,
            todos = t.todos,
            performances = t.performances,
            expenses = t.expenses,
            expiryItems = t.expiryItems,
            customers = t.customers,
            memos = t.memos
        )
    }.stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5000),
        CalendarDayData(emptyList(), emptyList(), emptyList(), emptyList(), emptyList(), emptyList())
    )

    val scheduleDay: StateFlow<ScheduleDay> = combine(
        dayData, todos, _selectedDayMillis
    ) { data, ts, day -> deriveScheduleDay(data, ts, day) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), ScheduleDay(0L))

    /**
     * 当前月份每天的事件旗标（key = 当天 0 点 millis）。
     * 对应 iOS CalendarView 的 CalendarDayCell 状态点。
     */
    val monthFlags: StateFlow<Map<Long, Set<EventFlag>>> = combine(tables, _monthMillis) { t, month ->
        val monthDate = Instant.ofEpochMilli(month).atZone(ZoneId.systemDefault()).toLocalDate()
        val daysInMonth = monthDate.lengthOfMonth()
        buildMap {
            for (day in 1..daysInMonth) {
                val dayStart = monthDate.withDayOfMonth(day)
                    .atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                put(
                    dayStart,
                    CalendarAgenda.dayData(
                        dayMillis = dayStart,
                        todos = t.todos,
                        performances = t.performances,
                        expenses = t.expenses,
                        expiryItems = t.expiryItems,
                        customers = t.customers,
                        memos = t.memos
                    ).eventFlags
                )
            }
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyMap())

    /** 正在切换完成态的待办 id：300ms 内忽略重复点击，对应 iOS togglingIDs。 */
    private val _togglingIds = MutableStateFlow<Set<String>>(emptySet())
    val togglingIds: StateFlow<Set<String>> = _togglingIds.asStateFlow()

    private val _error = MutableStateFlow<ScheduleError?>(null)
    val error: StateFlow<ScheduleError?> = _error.asStateFlow()

    fun clearError() {
        _error.value = null
    }

    /** 选中日期（归一化到当天 0 点）。 */
    fun selectDay(millis: Long) {
        _selectedDayMillis.value = DateExt.startOfDay(millis)
    }

    /** 回到今天。对应 iOS ScheduleView 工具栏「今天」按钮。 */
    fun selectToday() {
        selectDay(System.currentTimeMillis())
    }

    /** 周条左右切换周（±7 天）。对应 Schedule 周视图。 */
    fun shiftWeek(weeks: Int) {
        selectDay(_selectedDayMillis.value + weeks * 7L * 24 * 3600 * 1000L)
    }

    /** 月视图切换月份。对应 iOS CalendarView monthNavigator。 */
    fun shiftMonth(months: Int) {
        val current = Instant.ofEpochMilli(_monthMillis.value)
            .atZone(ZoneId.systemDefault()).toLocalDate()
        _monthMillis.value = current.plusMonths(months.toLong()).withDayOfMonth(1)
            .atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
    }

    /**
     * 切换待办完成态。对应 iOS ScheduleView.allDayTodoRow 的 V32Checkbox：
     * 成功 Haptic 由调用方处理；失败弹「操作失败」。
     */
    fun toggleTodo(todo: TodoEntity) {
        if (_togglingIds.value.contains(todo.id)) return
        _togglingIds.value = _togglingIds.value + todo.id
        viewModelScope.launch {
            try {
                todoRepo.toggleComplete(todo)
            } catch (e: Exception) {
                _error.value = ScheduleError("操作失败", "事项状态未改变，请重试。")
            }
            delay(300)
            _togglingIds.value = _togglingIds.value - todo.id
        }
    }
}

/** 日程页错误弹窗数据。 */
data class ScheduleError(val title: String, val message: String)

/** 当天 0 点 millis → LocalDate（系统默认时区）。 */
internal fun localDateOf(millis: Long): LocalDate =
    Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate()
