package com.xiaozhanggui.app.domain

import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoEntity

/**
 * 日历聚合。对应 iOS CalendarModel.CalendarAgenda.dayData。
 * 某日条目 = 当日未完成待办（dueDate 同天）+ Performance/Expense（date 同天）
 * + 到期临期（pending 且 expiryDate 同天）+ 当日客户需求（deliveryTime 解码值或 createdAt 同天）
 * + 备忘（createdAt 同天）。
 */
data class CalendarDayData(
    val todos: List<TodoEntity>,
    val performances: List<PerformanceEntity>,
    val expenses: List<ExpenseEntity>,
    val expiryItems: List<ExpiryItemEntity>,
    val customers: List<CustomerRequestEntity>,
    val memos: List<MemoEntity>
) {
    /** 日期状态点颜色：绿=有收入/支出、蓝=有待办、橙=有临期、灰=有客户 */
    val eventFlags: Set<EventFlag>
        get() = buildSet {
            if (performances.isNotEmpty() || expenses.isNotEmpty()) add(EventFlag.MONEY)
            if (todos.isNotEmpty()) add(EventFlag.TODO)
            if (expiryItems.isNotEmpty()) add(EventFlag.EXPIRY)
            if (customers.isNotEmpty()) add(EventFlag.CUSTOMER)
        }
}

enum class EventFlag { MONEY, TODO, EXPIRY, CUSTOMER }

object CalendarAgenda {
    fun dayData(
        dayMillis: Long,
        todos: List<TodoEntity>,
        performances: List<PerformanceEntity>,
        expenses: List<ExpenseEntity>,
        expiryItems: List<ExpiryItemEntity>,
        customers: List<CustomerRequestEntity>,
        memos: List<MemoEntity>
    ): CalendarDayData {
        val sameDay: (Long) -> Boolean = { DateExt.isSameDay(it, dayMillis) }
        return CalendarDayData(
            todos = todos.filter { !it.isCompleted && it.dueDate != null && sameDay(it.dueDate) },
            performances = performances.filter { sameDay(it.date) },
            expenses = expenses.filter { sameDay(it.date) },
            expiryItems = expiryItems.filter {
                it.returnStatus == com.xiaozhanggui.app.data.db.ReturnStatus.PENDING && sameDay(it.expiryDate)
            },
            customers = customers.filter { c ->
                val deliveryTime = CustomerDeliveryStorage.decode(c.customer).deliveryTime
                sameDay(deliveryTime ?: c.createdAt)
            },
            memos = memos.filter { sameDay(it.createdAt) }
        )
    }
}
