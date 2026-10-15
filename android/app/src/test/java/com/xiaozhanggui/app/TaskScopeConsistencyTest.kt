package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.domain.CalendarAgenda
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.ui.screens.home.DailyReport
import com.xiaozhanggui.app.ui.screens.home.homeTodayTodos
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleDay
import com.xiaozhanggui.app.ui.screens.schedule.completedTodos
import com.xiaozhanggui.app.ui.screens.schedule.mergeCompletedForDay
import com.xiaozhanggui.app.ui.screens.todo.TodoTab
import com.xiaozhanggui.app.ui.screens.todo.filterTodos
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P0-2：同一条任务在「日历 / 待办页 / 首页」三处的状态、数量、日期口径一致性锁定测试。
 *
 * 口径（与 iOS 逐字对应）：
 * - 日历 [CalendarAgenda.dayData]：未完成 且 dueDate 落在当天（dueDate==null 不进日历）；
 * - 待办页 [filterTodos]（TODAY）：未完成 且（dueDate==null 或 落在今天）；
 * - 首页 [homeTodayTodos]：未完成 且（dueDate==null 或 与今天同日）；
 * - 「已完成」归属：按 completedAt 落当天（[completedTodos] / 日报 [DailyReport.build]）。
 */
class TaskScopeConsistencyTest {

    private val now = System.currentTimeMillis()
    private val todayStart: Long = DateExt.startOfDay(now)
    private fun todayAt(hour: Int): Long = todayStart + hour * 3600 * 1000L
    private fun day(offset: Int): Long = todayStart + offset * 24 * 3600 * 1000L

    private fun todo(
        id: String,
        dueDate: Long? = null,
        isCompleted: Boolean = false,
        completedAt: Long? = null
    ) = TodoEntity(
        id = id,
        title = "任务-$id",
        dueDate = dueDate,
        isCompleted = isCompleted,
        completedAt = completedAt,
        createdAt = todayStart,
        notificationId = "n-$id"
    )

    private fun dayDataTodos(todos: List<TodoEntity>, dayMillis: Long) =
        CalendarAgenda.dayData(
            dayMillis = dayMillis,
            todos = todos,
            performances = emptyList(),
            expenses = emptyList(),
            expiryItems = emptyList(),
            customers = emptyList(),
            memos = emptyList()
        ).todos

    @Test
    fun `uncompleted todo due today visible in calendar todoPage and home`() {
        val t = todo("due-today", dueDate = todayAt(10) + 30 * 60 * 1000L)

        assertTrue(dayDataTodos(listOf(t), todayStart).any { it.id == t.id })
        assertTrue(filterTodos(listOf(t), TodoTab.TODAY).any { it.id == t.id })
        assertTrue(homeTodayTodos(listOf(t), now).any { it.id == t.id })

        // 不在已完成口径里
        assertFalse(filterTodos(listOf(t), TodoTab.DONE).any { it.id == t.id })
        assertTrue(completedTodos(listOf(t), todayStart).isEmpty())
    }

    @Test
    fun `uncompleted undated todo visible in todoPage and home but not in calendar`() {
        val t = todo("undated", dueDate = null)

        // iOS 口径：dueDate==nil 不进 CalendarAgenda.dayData
        assertFalse(dayDataTodos(listOf(t), todayStart).any { it.id == t.id })
        assertTrue(filterTodos(listOf(t), TodoTab.TODAY).any { it.id == t.id })
        assertTrue(homeTodayTodos(listOf(t), now).any { it.id == t.id })
    }

    @Test
    fun `todo completed today excluded from pending scopes counted once in completed scopes`() {
        // 明天到期、今天提前完成
        val t = todo("early-done", dueDate = day(1), isCompleted = true, completedAt = todayAt(15))

        // 三处待办口径都不再出现
        assertFalse(dayDataTodos(listOf(t), todayStart).any { it.id == t.id })
        assertFalse(filterTodos(listOf(t), TodoTab.TODAY).any { it.id == t.id })
        assertFalse(homeTodayTodos(listOf(t), now).any { it.id == t.id })

        // 已完成口径恰好出现一次
        assertTrue(filterTodos(listOf(t), TodoTab.DONE).any { it.id == t.id })
        assertEquals(1, completedTodos(listOf(t), todayStart).size)
        assertEquals(0, completedTodos(listOf(t), day(1)).size)

        // 日报「已完成待办」与首页事实源一致
        val report = DailyReport.build(now, emptyList(), listOf(t), emptyList(), emptyList())
        assertEquals(1, report.completedTodos)
        assertEquals(0, report.pendingTodos)

        // 今天日程可追踪（dueDate 在明天 → 全天区）
        val merged = mergeCompletedForDay(ScheduleDay(todayStart), listOf(t), emptyList(), todayStart)
        assertTrue(merged.timedEvents.isEmpty())
        assertTrue(merged.allDay.todos.any { it.id == t.id })
    }

    @Test
    fun `todo completed yesterday not attributed to today anywhere`() {
        val t = todo(
            "done-yesterday",
            dueDate = day(-1) + 9 * 3600 * 1000L,
            isCompleted = true,
            completedAt = day(-1) + 10 * 3600 * 1000L
        )

        assertFalse(dayDataTodos(listOf(t), todayStart).any { it.id == t.id })
        assertFalse(filterTodos(listOf(t), TodoTab.TODAY).any { it.id == t.id })
        assertFalse(homeTodayTodos(listOf(t), now).any { it.id == t.id })
        assertTrue(completedTodos(listOf(t), todayStart).isEmpty())

        val report = DailyReport.build(now, emptyList(), listOf(t), emptyList(), emptyList())
        assertEquals(0, report.completedTodos)

        // 昨天日程可追踪（dueDate 昨天 09:00 真实钟点 → timed）
        val mergedYesterday = mergeCompletedForDay(ScheduleDay(day(-1)), listOf(t), emptyList(), day(-1))
        assertEquals(1, mergedYesterday.timedEvents.size)
        assertTrue(mergedYesterday.allDay.todos.isEmpty())
    }

    @Test
    fun `legacy completed todo without completedAt only counted for today`() {
        val t = todo("legacy", dueDate = day(-5), isCompleted = true, completedAt = null)

        // 待办页「已完成」tab 按 isCompleted 收录（与 iOS TodoFilter.done 一致）
        assertTrue(filterTodos(listOf(t), TodoTab.DONE).any { it.id == t.id })

        // 当天完成口径：仅今天保守归入
        assertEquals(1, completedTodos(listOf(t), todayStart).size)
        assertEquals(0, completedTodos(listOf(t), day(-5)).size)
        assertEquals(0, completedTodos(listOf(t), day(2)).size)
    }

    @Test
    fun `overdue uncompleted todo in overdue tab not in today scopes`() {
        val t = todo("overdue", dueDate = day(-2), isCompleted = false)

        assertTrue(filterTodos(listOf(t), TodoTab.OVERDUE).any { it.id == t.id })
        assertFalse(filterTodos(listOf(t), TodoTab.TODAY).any { it.id == t.id })
        assertFalse(homeTodayTodos(listOf(t), now).any { it.id == t.id })
        assertFalse(dayDataTodos(listOf(t), todayStart).any { it.id == t.id })
    }
}
