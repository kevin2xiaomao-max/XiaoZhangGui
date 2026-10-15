package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.domain.CustomerDeliveryInfo
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.ui.screens.schedule.CompletedDeliveriesForDay
import com.xiaozhanggui.app.ui.screens.schedule.CompletedTodosForDay
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleAllDay
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleDay
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleEvent
import com.xiaozhanggui.app.ui.screens.schedule.completedDeliveries
import com.xiaozhanggui.app.ui.screens.schedule.completedDeliveriesForDay
import com.xiaozhanggui.app.ui.screens.schedule.completedTodos
import com.xiaozhanggui.app.ui.screens.schedule.completedTodosForDay
import com.xiaozhanggui.app.ui.screens.schedule.mergeCompletedForDay
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P0-2：「当天完成」口径回归测试。
 * 逐项对应 iOS `Tests/CompletedItemsTests.swift`（P1-1：首页「今日已完成」与日程「当天完成」口径一致性）：
 * - Todo 按 completedAt 归属当天；Customer 按 status==DONE + updatedAt 归属当天；
 * - 首页计数（[completedTodos]/[completedDeliveries]）与日程可追踪明细
 *   （[completedTodosForDay]/[completedDeliveriesForDay]/[mergeCompletedForDay]）总数一致。
 */
class ScheduleCompletedItemsTest {

    private val now = System.currentTimeMillis()
    private val todayStart: Long = DateExt.startOfDay(now)
    private fun todayAt(hour: Int): Long = todayStart + hour * 3600 * 1000L
    private fun day(offset: Int): Long = todayStart + offset * 24 * 3600 * 1000L

    private fun todo(
        title: String,
        dueDate: Long? = null,
        isCompleted: Boolean = false,
        completedAt: Long? = null
    ) = TodoEntity(
        id = "todo-$title",
        title = title,
        dueDate = dueDate,
        isCompleted = isCompleted,
        completedAt = completedAt,
        createdAt = todayStart,
        notificationId = "n-$title"
    )

    private fun delivery(
        content: String,
        status: String,
        deliveryTime: Long?,
        updatedAt: Long,
        notificationId: String = "d-$content"
    ) = CustomerRequestEntity(
        id = "cr-$content",
        customer = CustomerDeliveryStorage.encode(
            CustomerDeliveryInfo(deliveryTime = deliveryTime, legacyCustomer = content)
        ),
        content = content,
        status = status,
        createdAt = day(-1),
        updatedAt = updatedAt,
        notificationId = notificationId
    )

    // ---------- Todo ----------

    @Test
    fun `todo completed today but due tomorrow counted today and trackable in schedule`() {
        // 明天到期，今天提前完成（iOS P1-1 报告中的核心错配场景）
        val earlyDone = todo("提前完成的明天事项", dueDate = day(1), isCompleted = true, completedAt = todayAt(16))

        // 首页计数口径：今天 +1
        assertEquals(1, completedTodos(listOf(earlyDone), todayStart).size)

        // 今天日程可见（dueDate 非今天 → 全天区，不消失）
        val today: CompletedTodosForDay = completedTodosForDay(listOf(earlyDone), todayStart)
        assertTrue(today.timed.isEmpty())
        assertEquals(listOf("提前完成的明天事项"), today.allDay.map { it.title })

        // 明天日程不再把它算作「明天完成」
        val tomorrow = completedTodosForDay(listOf(earlyDone), day(1))
        assertTrue(tomorrow.timed.isEmpty())
        assertTrue(tomorrow.allDay.isEmpty())
    }

    @Test
    fun `todo completed yesterday not counted today`() {
        val doneYesterday = todo(
            "昨天完成", dueDate = day(-1) + 9 * 3600 * 1000L,
            isCompleted = true, completedAt = day(-1) + 10 * 3600 * 1000L
        )
        assertEquals(0, completedTodos(listOf(doneYesterday), todayStart).size)
        val yesterday = completedTodosForDay(listOf(doneYesterday), day(-1))
        // dueDate/completedAt 都是昨天 09:00（真实钟点）→ 昨天日程的 timed
        assertTrue(yesterday.allDay.isEmpty())
        assertEquals(1, yesterday.timed.size)
        val event = yesterday.timed[0]
        assertTrue(event is ScheduleEvent.Todo)
        assertEquals("昨天完成", (event as ScheduleEvent.Todo).todo.title)
    }

    @Test
    fun `legacy todo without completedAt only attributed to today`() {
        val legacy = todo("历史已完成无时间戳", isCompleted = true) // completedAt == null
        // 查看今天：保守归入（与首页可见的遗留项一致）
        assertEquals(1, completedTodos(listOf(legacy), todayStart).size)
        // 查看任意历史/未来日：不猜测归属
        assertEquals(0, completedTodos(listOf(legacy), day(-3)).size)
        assertEquals(0, completedTodos(listOf(legacy), day(2)).size)
    }

    @Test
    fun `pending todo never counted as completed`() {
        val pending = todo("未完成", dueDate = todayAt(9), isCompleted = false)
        assertEquals(0, completedTodos(listOf(pending), todayStart).size)
    }

    // ---------- Delivery ----------

    @Test
    fun `completed deliveries attributed by updatedAt`() {
        val doneToday = delivery("今天完成的配送", CustomerStatus.DONE, null, todayAt(15))
        val doneYesterday = delivery("昨天完成", CustomerStatus.DONE, null, day(-1) + 11 * 3600 * 1000L)
        val delivering = delivery("配送中", CustomerStatus.DELIVERING, null, todayAt(14))

        val today = completedDeliveries(listOf(doneToday, doneYesterday, delivering), todayStart)
        assertEquals(listOf("今天完成的配送"), today.map { it.content })
        assertEquals(1, completedDeliveries(listOf(doneYesterday), day(-1)).size)
    }

    @Test
    fun `completed deliveries for day deduplicates and backfills`() {
        // d1：今天完成、配送时间在昨天 → dayData 不会收进今天，应补进今天全天区
        val d1 = delivery(
            "昨天预约今天送完", CustomerStatus.DONE,
            day(-1) + 10 * 3600 * 1000L, todayAt(15)
        )
        // d2：今天完成、配送时间今天 09:00 → dayData 已收进今天时间线，去重不重复
        val d2 = delivery("今早配送", CustomerStatus.DONE, todayAt(9), todayAt(9))

        val result: CompletedDeliveriesForDay = completedDeliveriesForDay(
            listOf(d1, d2),
            todayStart,
            alreadyIncludedIds = setOf("delivery-${d2.notificationId}")
        )
        assertTrue(result.timed.isEmpty())
        assertEquals(listOf("昨天预约今天送完"), result.allDay.map { it.content })

        // 空去重集合时 d2 按真实钟点进 timed
        val full = completedDeliveriesForDay(listOf(d1, d2), todayStart, emptySet())
        assertEquals(1, full.timed.size)
        assertEquals(1, full.allDay.size)
    }

    // ---------- 首页计数 == 日程可追踪明细总数 ----------

    @Test
    fun `home count matches schedule trackable items`() {
        val earlyDone = todo("提前完成", dueDate = day(1), isCompleted = true, completedAt = todayAt(16))
        val doneTodayDelivery = delivery("今日完成配送", CustomerStatus.DONE, null, todayAt(17))
        val delivering = delivery("还在送", CustomerStatus.DELIVERING, null, todayAt(14))

        // 首页计数（与首页「今日已完成」同一派生）
        val homeCount = completedTodos(listOf(earlyDone), todayStart).size +
            completedDeliveries(listOf(doneTodayDelivery, delivering), todayStart).size
        assertEquals(2, homeCount)

        // 日程今天：Todo 在全天区；跨天完成的配送在补齐区——两项全部可追踪
        val todoBucket = completedTodosForDay(listOf(earlyDone), todayStart)
        val deliveryBucket = completedDeliveriesForDay(
            listOf(doneTodayDelivery, delivering), todayStart, emptySet()
        )
        val scheduleCount = todoBucket.timed.size + todoBucket.allDay.size +
            deliveryBucket.timed.size + deliveryBucket.allDay.size
        assertEquals(homeCount, scheduleCount)
    }

    // ---------- mergeCompletedForDay 接线 ----------

    @Test
    fun `mergeCompletedForDay merges done items into schedule day without duplication`() {
        val earlyDone = todo("提前完成", dueDate = day(1), isCompleted = true, completedAt = todayAt(16))
        val timedDone = todo(
            "今天14点到期已完成", dueDate = todayAt(14),
            isCompleted = true, completedAt = todayAt(13)
        )
        // d2：今天完成、配送时间今天 09:00——已在时间线（模拟 dayData 收录），不得重复
        val d2 = delivery("今早配送", CustomerStatus.DONE, todayAt(9), todayAt(9))
        val base = ScheduleDay(
            dateMillis = todayStart,
            timedEvents = listOf(ScheduleEvent.Delivery(d2, todayAt(9))),
            allDay = ScheduleAllDay()
        )

        val merged = mergeCompletedForDay(
            base,
            todos = listOf(earlyDone, timedDone),
            customers = listOf(d2),
            selectedDayMillis = todayStart
        )

        val timedTodos = merged.timedEvents.filterIsInstance<ScheduleEvent.Todo>()
        assertEquals(listOf("今天14点到期已完成"), timedTodos.map { it.todo.title })
        assertEquals(listOf("提前完成"), merged.allDay.todos.map { it.title })
        // d2 去重：时间线仍只有 1 个配送事件
        assertEquals(1, merged.timedEvents.filterIsInstance<ScheduleEvent.Delivery>().size)
        assertTrue(merged.allDay.deliveries.isEmpty())
    }

    @Test
    fun `mergeCompletedForDay backfills done delivery with non-today delivery time`() {
        // 今天完成但配送时间在昨天 → 补进今天全天区
        val d1 = delivery(
            "昨天预约今天送完", CustomerStatus.DONE,
            day(-1) + 10 * 3600 * 1000L, todayAt(15)
        )
        val base = ScheduleDay(dateMillis = todayStart)

        val merged = mergeCompletedForDay(base, emptyList(), listOf(d1), todayStart)

        assertTrue(merged.timedEvents.isEmpty())
        assertEquals(listOf("昨天预约今天送完"), merged.allDay.deliveries.map { it.content })
    }
}
