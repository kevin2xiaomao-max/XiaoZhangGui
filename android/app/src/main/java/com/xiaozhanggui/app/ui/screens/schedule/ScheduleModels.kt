package com.xiaozhanggui.app.ui.screens.schedule

import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.domain.CalendarDayData
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.domain.Format

/**
 * 日程派生模型。对应 iOS `Schedule/ScheduleAgenda.swift` 的派生口径，
 * 由 [CalendarAgenda.dayData] 的聚合结果派生（禁止另建数据模型）：
 * - 时间轴（timedEvents）：① dueDate 含真实钟点（非当天 00:00）的 Todo；
 *   ② 有真实 deliveryTime 的配送。
 * - 全天（allDay）：dueDate 为 nil/当天 00:00 的 Todo；无配送时间的客户单
 *   （按 createdAt 落当天）；临期（expiryDate 同日）；备忘（createdAt 同日）。
 * - Performance/Expense 永不逐笔进入时间轴，只聚合为当日收入/支出/净额。
 * - 仅查看「今天」时：全部未完成且无截止时间的 Todo 注入今天全天。
 * - 全天 todos 排序：优先级降序，同级 createdAt 升序。
 */

/** 定时事件。对应 iOS ScheduleEvent。 */
sealed interface ScheduleEvent {
    val date: Long

    data class Todo(val todo: TodoEntity) : ScheduleEvent {
        override val date: Long get() = todo.dueDate ?: 0L
    }

    data class Delivery(val request: CustomerRequestEntity, override val date: Long) : ScheduleEvent
}

/** 全天事项分组。对应 iOS ScheduleAllDay。 */
data class ScheduleAllDay(
    val todos: List<TodoEntity> = emptyList(),
    val deliveries: List<CustomerRequestEntity> = emptyList(),
    val expiry: List<ExpiryItemEntity> = emptyList(),
    val memos: List<MemoEntity> = emptyList()
) {
    val isEmpty: Boolean
        get() = todos.isEmpty() && deliveries.isEmpty() && expiry.isEmpty() && memos.isEmpty()

    val count: Int
        get() = todos.size + deliveries.size + expiry.size + memos.size
}

/** 当日日程。对应 iOS ScheduleDay。 */
data class ScheduleDay(
    val dateMillis: Long,
    val timedEvents: List<ScheduleEvent> = emptyList(),
    val allDay: ScheduleAllDay = ScheduleAllDay(),
    val revenue: Double = 0.0,
    val expense: Double = 0.0
) {
    val net: Double get() = revenue - expense
    val isEmpty: Boolean get() = timedEvents.isEmpty() && allDay.isEmpty
}

/**
 * 由 [CalendarAgenda.dayData] 的聚合结果派生日程视图数据。
 * 对应 iOS `ScheduleAgenda.make(from:undatedTodos:)`。
 *
 * @param dayData 选中日期的 [CalendarDayData] 聚合结果。
 * @param allTodos 全量待办（仅用于「今天」时注入无截止时间的未完成待办）。
 * @param dayMillis 选中日期的当天 0 点 millis。
 */
fun deriveScheduleDay(
    dayData: CalendarDayData,
    allTodos: List<TodoEntity>,
    dayMillis: Long
): ScheduleDay {
    val timedTodos = mutableListOf<TodoEntity>()
    val dayLevelTodos = mutableListOf<TodoEntity>()
    for (todo in dayData.todos) {
        val due = todo.dueDate
        if (due != null && DateExt.hasClock(due)) timedTodos.add(todo) else dayLevelTodos.add(todo)
    }
    if (DateExt.isToday(dayMillis)) {
        dayLevelTodos.addAll(allTodos.filter { !it.isCompleted && it.dueDate == null })
    }

    val timedDeliveries = mutableListOf<ScheduleEvent.Delivery>()
    val dayLevelDeliveries = mutableListOf<CustomerRequestEntity>()
    for (request in dayData.customers) {
        val deliveryTime = CustomerDeliveryStorage.decode(request.customer).deliveryTime
        if (deliveryTime != null && DateExt.hasClock(deliveryTime)) {
            timedDeliveries.add(ScheduleEvent.Delivery(request, deliveryTime))
        } else {
            dayLevelDeliveries.add(request)
        }
    }

    val timedEvents: List<ScheduleEvent> =
        (timedTodos.map { ScheduleEvent.Todo(it) } + timedDeliveries).sortedBy { it.date }

    val sortedDayTodos = dayLevelTodos.sortedWith(
        compareByDescending<TodoEntity> { it.priority }.thenBy { it.createdAt }
    )

    return ScheduleDay(
        dateMillis = dayMillis,
        timedEvents = timedEvents,
        allDay = ScheduleAllDay(
            todos = sortedDayTodos,
            deliveries = dayLevelDeliveries,
            expiry = dayData.expiryItems,
            memos = dayData.memos
        ),
        revenue = dayData.performances.sumOf { it.amount },
        expense = dayData.expenses.sumOf { it.amount }
    )
}

/**
 * 客户配送展示名：编码串用 [DisplayLogic.visible] 隐藏，
 * fallback = 解码出的 legacyCustomer（再 fallback 为「客户」）。
 * 对应 iOS CustomerRequest.displayTitle 口径。
 */
fun customerDisplayName(request: CustomerRequestEntity): String {
    val decoded = CustomerDeliveryStorage.decode(request.customer)
    return DisplayLogic.visible(
        request.customer,
        decoded.legacyCustomer.trim().ifEmpty { "客户" }
    )
}

/** 配送副标题：地址 · 状态。编码串不显示。对应 iOS 事件副标题口径。 */
fun customerSubtitle(request: CustomerRequestEntity): String =
    listOf(
        DisplayLogic.visible(request.roomOrAddress, ""),
        request.status
    ).filter { it.isNotEmpty() }.joinToString(" · ")

/**
 * 日历详情行用的配送行文本：`HH:mm 地址`；未设配送时间显示「未设配送时间」。
 * 对应 iOS `CalendarView.swift:199-246` 的客户需求行。
 */
fun customerDeliveryLine(request: CustomerRequestEntity): String {
    val deliveryTime = CustomerDeliveryStorage.decode(request.customer).deliveryTime
    val timePart = if (deliveryTime != null && DateExt.hasClock(deliveryTime)) {
        Format.time(deliveryTime)
    } else {
        "未设配送时间"
    }
    val address = DisplayLogic.visible(request.roomOrAddress, "")
    return if (address.isEmpty()) timePart else "$timePart $address"
}

/**
 * 「当天完成」口径（P0-2）。逐字对应 iOS `ScheduleAgenda.swift:127-201`（P1-1），
 * 与首页「今日已完成」（[DailyReportSheet.build] 的 completedTodos）同一事实源：
 * - Todo：isCompleted 且 completedAt 落在当天；completedAt 缺失的历史数据
 *   （toggleComplete 现总会写入）仅在查看「今天」时归入，非今天不猜测归属。
 * - Customer：status == DONE 且 updatedAt 落在当天（每次状态流转都更新 updatedAt）。
 * 纯函数，可单测；不改 `CalendarAgenda.dayData` / eventFlags 口径、不碰 Room。
 */

/** 当天完成的 Todo（按 completedAt 归属）。函数契约自带 isCompleted 守卫。 */
fun completedTodos(todos: List<TodoEntity>, dayMillis: Long): List<TodoEntity> =
    todos.filter { todo ->
        if (!todo.isCompleted) return@filter false
        val completedAt = todo.completedAt
        if (completedAt != null) DateExt.isSameDay(completedAt, dayMillis)
        else DateExt.isToday(dayMillis)
    }

/** 当天完成的配送（按 updatedAt 归属）。 */
fun completedDeliveries(
    customers: List<CustomerRequestEntity>,
    dayMillis: Long
): List<CustomerRequestEntity> =
    customers.filter { it.status == CustomerStatus.DONE && DateExt.isSameDay(it.updatedAt, dayMillis) }

/** [completedTodosForDay] 的分类结果：同一项只落一个桶，不重复。 */
data class CompletedTodosForDay(
    val timed: List<ScheduleEvent>,
    val allDay: List<TodoEntity>
)

/**
 * 把「当天完成的 Todo」分类为 timed / all-day 展示。只看传入数据，不读数据库。
 * 展示分桶仍按 dueDate 形态：有真实钟点且与 selectedDayMillis 同日 → timed，其余 → all-day。
 */
fun completedTodosForDay(
    todos: List<TodoEntity>,
    selectedDayMillis: Long
): CompletedTodosForDay {
    val timed = mutableListOf<ScheduleEvent>()
    val allDay = mutableListOf<TodoEntity>()
    for (todo in completedTodos(todos, selectedDayMillis)) {
        val due = todo.dueDate
        if (due != null && DateExt.hasClock(due) && DateExt.isSameDay(due, selectedDayMillis)) {
            timed.add(ScheduleEvent.Todo(todo))
        } else {
            allDay.add(todo)
        }
    }
    return CompletedTodosForDay(timed, allDay)
}

/** [completedDeliveriesForDay] 的分类结果。 */
data class CompletedDeliveriesForDay(
    val timed: List<ScheduleEvent>,
    val allDay: List<CustomerRequestEntity>
)

/** 配送去重键。对应 iOS `"delivery-\(request.notificationID)"`。 */
internal fun deliveryDedupeKey(request: CustomerRequestEntity): String =
    "delivery-${request.notificationId}"

/**
 * 「当天完成的配送」中尚未出现在当天时间线/全天区的部分（dayData 已按 deliveryTime/createdAt
 * 收录当天配送含 done，这里只补齐「今天完成、但配送时间不在今天」的单，避免重复）。
 * - 配送时间为真实钟点且在当天 → timed；其余（无时间/他天时间）→ allDay。
 */
fun completedDeliveriesForDay(
    customers: List<CustomerRequestEntity>,
    selectedDayMillis: Long,
    alreadyIncludedIds: Set<String>
): CompletedDeliveriesForDay {
    val timed = mutableListOf<ScheduleEvent>()
    val allDay = mutableListOf<CustomerRequestEntity>()
    for (request in completedDeliveries(customers, selectedDayMillis)) {
        if (deliveryDedupeKey(request) in alreadyIncludedIds) continue
        val deliveryTime = CustomerDeliveryStorage.decode(request.customer).deliveryTime
        if (deliveryTime != null && DateExt.hasClock(deliveryTime) &&
            DateExt.isSameDay(deliveryTime, selectedDayMillis)
        ) {
            timed.add(ScheduleEvent.Delivery(request, deliveryTime))
        } else {
            allDay.add(request)
        }
    }
    return CompletedDeliveriesForDay(timed, allDay)
}

/**
 * 日程页派生：把「当天完成」合并进 [deriveScheduleDay] 的结果。
 * 对应 iOS `ScheduleView.scheduleDay`（P1-1）：已完成项按 completedAt/updatedAt 归属当天，
 * 当天完成但 dueDate/deliveryTime 不在当天的项补入对应桶（去重），保证
 * 「首页今日完成计数点进来后每一项都能在当天日程追踪到」。
 */
fun mergeCompletedForDay(
    day: ScheduleDay,
    todos: List<TodoEntity>,
    customers: List<CustomerRequestEntity>,
    selectedDayMillis: Long
): ScheduleDay {
    val doneTodos = completedTodosForDay(todos, selectedDayMillis)
    val timedWithTodos = day.timedEvents + doneTodos.timed
    val existingDeliveryIds = timedWithTodos
        .filterIsInstance<ScheduleEvent.Delivery>()
        .map { deliveryDedupeKey(it.request) }.toSet() +
        day.allDay.deliveries.map { deliveryDedupeKey(it) }
    val doneDeliveries = completedDeliveriesForDay(customers, selectedDayMillis, existingDeliveryIds)
    return day.copy(
        timedEvents = (timedWithTodos + doneDeliveries.timed).sortedBy { it.date },
        allDay = day.allDay.copy(
            todos = day.allDay.todos + doneTodos.allDay,
            deliveries = day.allDay.deliveries + doneDeliveries.allDay
        )
    )
}
