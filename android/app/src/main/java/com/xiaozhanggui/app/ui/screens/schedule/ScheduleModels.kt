package com.xiaozhanggui.app.ui.screens.schedule

import com.xiaozhanggui.app.data.db.CustomerRequestEntity
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
    data class Todo(val todo: TodoEntity) : ScheduleEvent
    data class Delivery(val request: CustomerRequestEntity, val date: Long) : ScheduleEvent

    val date: Long
        get() = when (this) {
            is Todo -> todo.dueDate ?: 0L
            is Delivery -> date
        }
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
