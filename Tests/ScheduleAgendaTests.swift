import XCTest
@testable import XiaoZhangGui

final class ScheduleAgendaTests: XCTestCase {

    private var calendar: Calendar { Calendar.current }

    private func todayAt(_ hour: Int, _ minute: Int = 0) -> Date {
        let c = calendar
        let start = c.startOfDay(for: Date())
        return c.date(byAdding: .hour, value: hour, to: start)!
            .addingTimeInterval(TimeInterval(minute * 60))
    }

    private var todayStart: Date { calendar.startOfDay(for: Date()) }

    private func makeDayData(
        todos: [Todo] = [],
        performances: [Performance] = [],
        expenses: [Expense] = [],
        expiryItems: [ExpiryItem] = [],
        customers: [CustomerRequest] = [],
        memos: [Memo] = []
    ) -> CalendarDayData {
        CalendarAgenda.dayData(
            date: todayStart,
            todos: todos,
            performances: performances,
            expenses: expenses,
            expiryItems: expiryItems,
            customers: customers,
            memos: memos
        )
    }

    private func makeDelivery(customer: String, content: String, createdAt: Date) -> CustomerRequest {
        CustomerRequest(customer: customer, roomOrAddress: "", phone: "", content: content, createdAt: createdAt, updatedAt: createdAt)
    }

    // MARK: 1. 无时间数据不产生定时事件

    func testNoTimeDataGoesAllDay() {
        let noDueTodo = Todo(title: "无截止待办")
        let dateLevelTodo = Todo(title: "日期级待办", dueDate: todayStart) // 当天 00:00
        let expiry = ExpiryItem(name: "牛奶", expiryDate: todayStart)
        let memo = Memo(title: "备忘", content: "内容")
        let walkIn = makeDelivery(customer: "王姐", content: "矿泉水 1 箱", createdAt: todayStart)

        let day = ScheduleAgenda.make(
            from: makeDayData(
                todos: [noDueTodo, dateLevelTodo],
                expiryItems: [expiry],
                customers: [walkIn],
                memos: [memo]
            ),
            undatedTodos: [noDueTodo]
        )

        XCTAssertTrue(day.timedEvents.isEmpty, "无真实钟点的数据不得进入时间轴")
        XCTAssertEqual(Set(day.allDay.todos.map(\.title)), ["无截止待办", "日期级待办"])
        XCTAssertEqual(day.allDay.expiry.count, 1)
        XCTAssertEqual(day.allDay.memos.count, 1)
        XCTAssertEqual(day.allDay.deliveries.count, 1)
    }

    func testUndatedTodoOnlyInjectedForToday() {
        let otherDay = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let noDueTodo = Todo(title: "无截止待办")
        let data = CalendarAgenda.dayData(
            date: otherDay,
            todos: [], performances: [], expenses: [], expiryItems: [], customers: [], memos: []
        )
        let day = ScheduleAgenda.make(from: data, undatedTodos: [noDueTodo])
        XCTAssertTrue(day.allDay.todos.isEmpty, "无截止待办只属于今天，不应注入到其它日期")
    }

    // MARK: 2. 流水只进摘要、永不进时间轴

    func testRevenueAndExpenseOnlyAggregate() {
        let revenue = Performance(amount: 1280, note: "营业额", date: todayAt(14))
        let expense = Expense(amount: 230.5, category: "进货", note: "矿泉水", date: todayAt(15))

        let day = ScheduleAgenda.make(
            from: makeDayData(performances: [revenue], expenses: [expense])
        )

        XCTAssertTrue(day.timedEvents.isEmpty, "Performance/Expense 不得逐笔进入时间轴")
        XCTAssertEqual(day.summary.revenue, 1280, accuracy: 0.001)
        XCTAssertEqual(day.summary.expense, 230.5, accuracy: 0.001)
        XCTAssertEqual(day.summary.net, 1049.5, accuracy: 0.001)

        // 编译期语义保障：定时事件枚举只有 todo/delivery 两类
        for event in day.timedEvents {
            switch event {
            case .todo, .delivery: break
            }
        }
    }

    // MARK: 3. 真实钟点 Todo / deliveryTime 定时并排序

    func testTimedEventsWithRealClockSorted() {
        let todo1030 = Todo(title: "记录盘点", dueDate: todayAt(10, 30))
        let todo0800 = Todo(title: "开店准备", dueDate: todayAt(8))
        let payload = CustomerDeliveryStorage.encode(
            existingValue: "李老板",
            deliveryTime: todayAt(9),
            note: ""
        )
        let delivery = makeDelivery(customer: payload, content: "香烟 2 条", createdAt: todayStart)

        let day = ScheduleAgenda.make(
            from: makeDayData(todos: [todo1030, todo0800], customers: [delivery])
        )

        XCTAssertEqual(day.timedEvents.count, 3)
        XCTAssertEqual(day.allDay.todos.count, 0)
        XCTAssertEqual(day.allDay.deliveries.count, 0)

        // 08:00 待办 → 09:00 配送 → 10:30 待办
        switch day.timedEvents[0] {
        case .todo(let todo): XCTAssertEqual(todo.title, "开店准备")
        case .delivery: XCTFail("第一项应为 08:00 待办")
        }
        switch day.timedEvents[1] {
        case .delivery(_, let date):
            XCTAssertEqual(calendar.component(.hour, from: date), 9)
        case .todo: XCTFail("第二项应为 09:00 配送")
        }
        switch day.timedEvents[2] {
        case .todo(let todo): XCTAssertEqual(todo.title, "记录盘点")
        case .delivery: XCTFail("第三项应为 10:30 待办")
        }
    }

    func testHasClockClassification() {
        XCTAssertFalse(ScheduleAgenda.hasClock(nil))
        XCTAssertFalse(ScheduleAgenda.hasClock(todayStart))
        XCTAssertFalse(ScheduleAgenda.hasClock(todayAt(0, 0)))
        XCTAssertTrue(ScheduleAgenda.hasClock(todayAt(0, 5)))
        XCTAssertTrue(ScheduleAgenda.hasClock(todayAt(22, 30)))
    }
    // MARK: b27 T20：已完成 Todo 纯派生分类

    func testCompletedTodosClassifiedTimedAlldayNonTodayNoDuplicate() {
        let timedDone = Todo(title: "已完成定时", dueDate: todayAt(15, 30), isCompleted: true)
        let dayDone = Todo(title: "已完成全天", dueDate: todayStart, isCompleted: true)
        let noDateDone = Todo(title: "已完成无日期", isCompleted: true)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        let otherDayDone = Todo(title: "昨天已完成", dueDate: yesterday, isCompleted: true)

        let result = ScheduleAgenda.completedTodosForDay(
            [timedDone, dayDone, noDateDone, otherDayDone],
            date: todayStart,
            calendar: calendar
        )

        // 已完成 + 真实钟点 -> timed
        XCTAssertEqual(result.timed.count, 1)
        switch result.timed[0] {
        case .todo(let t): XCTAssertEqual(t.title, "已完成定时")
        case .delivery: XCTFail("已完成 Todo 不应是 delivery")
        }
        // 已完成 + 日期级/无日期 -> all-day
        XCTAssertEqual(Set(result.allDay.map(\.title)), ["已完成全天", "已完成无日期"])
        // 非当天已完成不混入当天
        XCTAssertFalse(result.allDay.contains { $0.title == "昨天已完成" })
        XCTAssertFalse(result.timed.contains {
            if case .todo(let t) = $0 { return t.title == "昨天已完成" }
            return false
        })
        // 不产生重复项
        let timedIDs = Set(result.timed.map(\.id))
        let allDayIDs = Set(result.allDay.map { "todo-\($0.notificationID)" })
        XCTAssertTrue(timedIDs.isDisjoint(with: allDayIDs))
    }
}
