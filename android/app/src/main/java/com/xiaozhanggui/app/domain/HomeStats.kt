package com.xiaozhanggui.app.domain

import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoEntity

/**
 * 首页统计。对应 iOS HomeModel.HomeStats.compute。
 * goalProgressPercent = Int(todayRevenue / (monthGoal / 30) * 100)
 */
data class HomeStats(
    val todayRevenue: Double,
    val todayTodos: List<TodoEntity>,
    val urgentExpiryCount: Int,
    val goalProgressPercent: Int
) {
    companion object {
        fun compute(
            performances: List<PerformanceEntity>,
            todos: List<TodoEntity>,
            expiryItems: List<ExpiryItemEntity>,
            monthGoal: Double,
            nowMillis: Long = System.currentTimeMillis()
        ): HomeStats {
            val todayStart = DateExt.startOfDay(nowMillis)
            val todayEnd = todayStart + 24 * 3600 * 1000L
            // 今日收入：按业务 date 落在今日区间（GATE C：用 date 不用 createdAt）
            val todayRevenue = performances
                .filter { it.date in todayStart until todayEnd }
                .sumOf { it.amount }
            // 今日待办：未完成且（无截止 或 截止在今日区间）
            val todayTodos = todos.filter { t ->
                !t.isCompleted && (t.dueDate == null || t.dueDate in todayStart until todayEnd)
            }
            // 紧急临期：待处理且 0 <= daysLeft <= 7
            val urgentExpiryCount = expiryItems.count { item ->
                ExpiryGroup.of(item, nowMillis) == ExpiryGroup.URGENT_3 ||
                    ExpiryGroup.of(item, nowMillis) == ExpiryGroup.URGENT_7
            }
            val goalProgressPercent =
                if (monthGoal > 0) (todayRevenue / (monthGoal / 30) * 100).toInt() else 0
            return HomeStats(todayRevenue, todayTodos, urgentExpiryCount, goalProgressPercent)
        }
    }
}

/** 首页待办收件箱：limit=4，按 rank 升序、同 rank 按日期升序 */
fun buildHomeInbox(
    todos: List<TodoEntity>,
    nowMillis: Long = System.currentTimeMillis()
): List<HomeInboxItem> {
    // 简化版：未完成待办按 rank 排序。完整 rank（含临期/配送）由调用方在 Phase 3 组合。
    return todos.filter { !it.isCompleted }
        .map { t ->
            val rank = if (t.priority == 2) 1 else 4
            HomeInboxItem(
                id = "todo-${t.notificationId}",
                title = t.title,
                subtitle = DisplayLogic.dayTimeLabel(t.dueDate, "待安排"),
                rank = rank,
                sortDate = t.dueDate ?: Long.MAX_VALUE
            )
        }
        .sortedWith(compareBy({ it.rank }, { it.sortDate }))
        .take(4)
}
