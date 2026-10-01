package com.xiaozhanggui.app.paparazzi

import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpenseCategory
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.GoodsCategory
import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.domain.CalendarDayData
import com.xiaozhanggui.app.domain.CustomerDeliveryInfo
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.EventFlag
import com.xiaozhanggui.app.domain.ai.ActionProposal
import com.xiaozhanggui.app.domain.ai.AiRole
import com.xiaozhanggui.app.domain.ai.AiUiMessage
import com.xiaozhanggui.app.domain.ai.RevenueArguments
import com.xiaozhanggui.app.domain.ai.ToolArguments
import com.xiaozhanggui.app.domain.ai.ToolName
import com.xiaozhanggui.app.ui.screens.home.HomeInboxUiItem
import com.xiaozhanggui.app.ui.screens.home.HomeUiState
import com.xiaozhanggui.app.ui.screens.home.InboxRoute
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleAllDay
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleDay
import com.xiaozhanggui.app.ui.screens.schedule.ScheduleEvent

/**
 * 页面截图测试共用假数据（WorkerA：11 个页面 Light/Dark）。
 *
 * 约定：
 * - 全部手写假数据，不碰数据库 / DataStore / 网络；
 * - id 固定，保证多次录制产物稳定；
 * - 时间以"今天 0 点"为锚点派生，跨天重录 golden 会漂移（已知 caveat）。
 */
internal object ScreenshotFixtures {

    const val DAY_MILLIS = 24 * 3600 * 1000L

    fun todayStart(now: Long = System.currentTimeMillis()): Long = DateExt.startOfDay(now)

    fun todos(now: Long = System.currentTimeMillis()): List<TodoEntity> {
        val t0 = todayStart(now)
        return listOf(
            TodoEntity(
                id = "todo-1",
                title = "给 302 房送两箱怡宝",
                detail = "客户电话 13800001111",
                dueDate = t0 + 10 * 3600 * 1000L + 30 * 60 * 1000L,
                priority = 2,
                createdAt = t0 - 2 * 3600 * 1000L
            ),
            TodoEntity(
                id = "todo-2",
                title = "盘点饮料冰柜",
                dueDate = t0,
                priority = 1,
                createdAt = t0 - 3600 * 1000L
            ),
            TodoEntity(
                id = "todo-3",
                title = "交上月水电费",
                dueDate = t0 - DAY_MILLIS,
                priority = 2,
                createdAt = t0 - 2 * DAY_MILLIS
            ),
            TodoEntity(
                id = "todo-4",
                title = "补充货架零食",
                isCompleted = true,
                completedAt = t0 - 3600 * 1000L,
                createdAt = t0 - 3 * 3600 * 1000L
            )
        )
    }

    fun memos(now: Long = System.currentTimeMillis()): List<MemoEntity> {
        val t0 = todayStart(now)
        return listOf(
            MemoEntity(
                id = "memo-1",
                title = "供应商电话",
                content = "王经理 13900002222，每周三送货，可谈账期。",
                createdAt = t0 - 3600 * 1000L,
                updatedAt = t0 - 3600 * 1000L
            ),
            MemoEntity(
                id = "memo-2",
                title = "冰柜温度",
                content = "2 号冰柜调到 -18℃，晚上检查一次。",
                createdAt = t0 - 2 * DAY_MILLIS,
                updatedAt = t0 - DAY_MILLIS
            ),
            MemoEntity(
                id = "memo-3",
                title = "新品试卖",
                content = "气泡水摆收银台旁边，观察一周销量。",
                createdAt = t0 - 5 * DAY_MILLIS,
                updatedAt = t0 - 5 * DAY_MILLIS
            )
        )
    }

    fun customerRequests(now: Long = System.currentTimeMillis()): List<CustomerRequestEntity> {
        val t0 = todayStart(now)
        return listOf(
            CustomerRequestEntity(
                id = "cr-1",
                customer = CustomerDeliveryStorage.encode(
                    CustomerDeliveryInfo(
                        deliveryTime = t0 + 18 * 3600 * 1000L,
                        note = "怡宝两箱",
                        legacyCustomer = "302 房张先生"
                    )
                ),
                roomOrAddress = "3 栋 302",
                phone = "13800001111",
                content = "怡宝 4.8L 两箱",
                status = CustomerStatus.PENDING,
                createdAt = t0 - 3600 * 1000L,
                updatedAt = t0 - 3600 * 1000L
            ),
            CustomerRequestEntity(
                id = "cr-2",
                customer = "李阿姨",
                roomOrAddress = "小区门口",
                phone = "13700002222",
                content = "代收快递 3 件",
                status = CustomerStatus.DELIVERING,
                createdAt = t0 - 2 * 3600 * 1000L,
                updatedAt = t0 - 3600 * 1000L
            ),
            CustomerRequestEntity(
                id = "cr-3",
                customer = "王大爷",
                roomOrAddress = "5 栋 101",
                content = "上门维修水龙头",
                status = CustomerStatus.DONE,
                createdAt = t0 - DAY_MILLIS,
                updatedAt = t0 - 2 * 3600 * 1000L
            )
        )
    }

    fun expiryItems(now: Long = System.currentTimeMillis()): List<ExpiryItemEntity> {
        val t0 = todayStart(now)
        return listOf(
            ExpiryItemEntity(
                id = "ex-1",
                name = "鲜牛奶 250ml",
                category = "乳制品",
                quantity = 12,
                expiryDate = t0 + 3 * DAY_MILLIS,
                remindDaysBefore = 7,
                note = "放前排促销",
                returnStatus = ReturnStatus.PENDING,
                createdAt = t0 - DAY_MILLIS
            ),
            ExpiryItemEntity(
                id = "ex-2",
                name = "三明治",
                category = "短保",
                quantity = 6,
                expiryDate = t0 - DAY_MILLIS,
                remindDaysBefore = 3,
                returnStatus = ReturnStatus.PENDING,
                createdAt = t0 - 4 * DAY_MILLIS
            ),
            ExpiryItemEntity(
                id = "ex-3",
                name = "酸奶大果粒",
                category = "乳制品",
                quantity = 8,
                expiryDate = t0 - 2 * DAY_MILLIS,
                returnStatus = ReturnStatus.RETURNED,
                returnedAt = t0 - DAY_MILLIS,
                createdAt = t0 - 10 * DAY_MILLIS
            ),
            ExpiryItemEntity(
                id = "ex-4",
                name = "饼干礼盒",
                category = "零食",
                quantity = 20,
                expiryDate = t0 + 90 * DAY_MILLIS,
                createdAt = t0 - 2 * DAY_MILLIS
            )
        )
    }

    fun goods(): List<GoodsEntity> {
        return listOf(
            GoodsEntity(
                id = "g-1",
                name = "怡宝 4.8L",
                category = GoodsCategory.DRINK,
                barcode = "6923450601234",
                stock = 3,
                minStock = 10,
                purchasePrice = 8.5,
                salePrice = 12.0
            ),
            GoodsEntity(
                id = "g-2",
                name = "可口可乐 500ml",
                category = GoodsCategory.DRINK,
                stock = 48,
                minStock = 24,
                purchasePrice = 2.2,
                salePrice = 3.5
            ),
            GoodsEntity(
                id = "g-3",
                name = "卫龙大刀肉",
                category = GoodsCategory.SNACK,
                stock = 60,
                minStock = 30,
                purchasePrice = 0.8,
                salePrice = 1.5
            ),
            GoodsEntity(
                id = "g-4",
                name = "抽纸 3 层 100 抽",
                category = GoodsCategory.DAILY,
                stock = 25,
                minStock = 20,
                purchasePrice = 6.0,
                salePrice = 9.9
            )
        )
    }

    fun performances(now: Long = System.currentTimeMillis()): List<PerformanceEntity> {
        val t0 = todayStart(now)
        return listOf(
            PerformanceEntity(id = "p-1", amount = 128.5, note = "散客", date = t0 + 9 * 3600 * 1000L, incomeSource = "微信"),
            PerformanceEntity(id = "p-2", amount = 860.0, note = "302 房月结", date = t0 + 11 * 3600 * 1000L, incomeSource = "支付宝"),
            PerformanceEntity(id = "p-3", amount = 300.0, note = "团购", date = t0 + 14 * 3600 * 1000L, incomeSource = "美团"),
            PerformanceEntity(id = "p-4", amount = 1120.0, note = "昨日", date = t0 - 5 * 3600 * 1000L, incomeSource = "现金"),
            PerformanceEntity(id = "p-5", amount = 2560.0, note = "上周", date = t0 - 6 * DAY_MILLIS, incomeSource = "微信")
        )
    }

    fun expenses(now: Long = System.currentTimeMillis()): List<ExpenseEntity> {
        val t0 = todayStart(now)
        return listOf(
            ExpenseEntity(id = "e-1", amount = 520.0, category = ExpenseCategory.STOCK, note = "饮料进货", date = t0 + 8 * 3600 * 1000L),
            ExpenseEntity(id = "e-2", amount = 180.0, category = ExpenseCategory.UTILITY, note = "水电费", date = t0 - DAY_MILLIS)
        )
    }

    fun homeState(now: Long = System.currentTimeMillis()): HomeUiState {
        val todos = todos(now)
        val memos = memos(now)
        return HomeUiState(
            greeting = "晚上好",
            ownerName = "老板",
            dateLabel = "10月2日 星期五",
            todayRevenue = 1288.5,
            changePercent = 15.2,
            trend = listOf(900.0, 1100.0, 760.0, 1340.0, 980.0, 1120.0, 1288.5),
            monthRevenue = 35600.0,
            monthGoal = 120000.0,
            todoCount = 3,
            customerCount = 2,
            expiryCount = 2,
            todoInsight = "有 1 项已逾期，优先处理",
            customerInsight = "2 单待配送，最早今晚 18:00",
            expiryInsight = "2 件临期，鲜牛奶剩 3 天",
            inboxItems = listOf(
                HomeInboxUiItem(
                    id = "todo-1",
                    title = "给 302 房送两箱怡宝",
                    subtitle = "待办 · 10:30",
                    time = "10:30",
                    route = InboxRoute.TODO
                ),
                HomeInboxUiItem(
                    id = "cr-1",
                    title = "302 房张先生",
                    subtitle = "配送 · 今晚 18:00",
                    time = "18:00",
                    route = InboxRoute.CUSTOMER
                ),
                HomeInboxUiItem(
                    id = "ex-1",
                    title = "鲜牛奶 250ml",
                    subtitle = "临期 · 剩 3 天",
                    time = "3天",
                    route = InboxRoute.EXPIRY
                )
            ),
            recentMemos = memos.take(2)
        )
    }

    fun scheduleDay(now: Long = System.currentTimeMillis()): ScheduleDay {
        val t0 = todayStart(now)
        val timed = todos(now).first().copy(id = "todo-1")
        return ScheduleDay(
            dateMillis = t0,
            timedEvents = listOf(ScheduleEvent.Todo(timed)),
            allDay = ScheduleAllDay(
                todos = todos(now).drop(1).take(2),
                deliveries = customerRequests(now).take(1),
                expiry = expiryItems(now).take(2),
                memos = memos(now).take(1)
            ),
            revenue = 1288.5,
            expense = 520.0
        )
    }

    fun calendarDayData(now: Long = System.currentTimeMillis()): CalendarDayData {
        return CalendarDayData(
            todos = todos(now).take(2),
            performances = performances(now).take(2),
            expenses = expenses(now).take(1),
            expiryItems = expiryItems(now).take(1),
            customers = customerRequests(now).take(1),
            memos = memos(now).take(1)
        )
    }

    fun monthStart(now: Long = System.currentTimeMillis()): Long = DateExt.startOfMonth(now)

    fun calendarFlags(now: Long = System.currentTimeMillis()): Map<Long, Set<EventFlag>> {
        val t0 = todayStart(now)
        return mapOf(
            t0 to setOf(EventFlag.MONEY, EventFlag.TODO, EventFlag.EXPIRY, EventFlag.CUSTOMER),
            t0 + DAY_MILLIS to setOf(EventFlag.TODO),
            t0 + 2 * DAY_MILLIS to setOf(EventFlag.EXPIRY)
        )
    }

    fun aiMessages(): List<AiUiMessage> = listOf(
        AiUiMessage(
            id = "m-1",
            role = AiRole.USER,
            text = "今天卖了多少钱？"
        ),
        AiUiMessage(
            id = "m-2",
            role = AiRole.ASSISTANT,
            text = "今日营业额 1,288.5 元，比昨天多 15.2%。要记一笔吗？"
        ),
        AiUiMessage(
            id = "m-3",
            role = AiRole.USER,
            text = "记 128.5，散客微信"
        )
    )

    fun aiProposal(): ActionProposal = ActionProposal(
        id = "ap-1",
        toolName = ToolName.RECORD_REVENUE,
        argumentsJson = ToolArguments.Revenue(
            RevenueArguments(amount = 128.5, source = "微信", note = "散客")
        ).encode()
    )
}
