import XCTest
@testable import XiaoZhangGui

/// P1-1：首页「今日已完成」与日程「当天完成」口径一致性
/// 规则：Todo 按 completedAt 归属当天；Customer 按 status==done + updatedAt 归属当天。
final class CompletedItemsTests: XCTestCase {

    private var calendar: Calendar { Calendar.current }
    private var todayStart: Date { calendar.startOfDay(for: Date()) }
    private func todayAt(_ hour: Int) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: todayStart)!
    }
    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: todayStart)!
    }

    // MARK: Todo

    func testTodoCompletedTodayButDueTomorrowCountedTodayAndTrackableInSchedule() {
        // 明天到期，今天提前完成（P1-1 报告中的核心错配场景）
        let earlyDone = Todo(title: "提前完成的明天事项",
                             dueDate: day(1),
                             isCompleted: true,
                             completedAt: todayAt(16))

        // 首页计数口径：今天 +1
        XCTAssertEqual(ScheduleAgenda.completedTodos([earlyDone], on: Date()).count, 1)

        // 今天日程可见（dueDate 非今天 → 全天区，不消失）
        let today = ScheduleAgenda.completedTodosForDay([earlyDone], date: todayStart, calendar: calendar)
        XCTAssertTrue(today.timed.isEmpty)
        XCTAssertEqual(today.allDay.map(\.title), ["提前完成的明天事项"])

        // 明天日程不再把它算作「明天完成」
        let tomorrow = ScheduleAgenda.completedTodosForDay([earlyDone], date: day(1), calendar: calendar)
        XCTAssertTrue(tomorrow.timed.isEmpty)
        XCTAssertTrue(tomorrow.allDay.isEmpty)
    }

    func testTodoCompletedYesterdayNotCountedToday() {
        let doneYesterday = Todo(title: "昨天完成", dueDate: yesterdayDue(),
                                 isCompleted: true, completedAt: day(-1).addingTimeInterval(3600 * 10))
        XCTAssertEqual(ScheduleAgenda.completedTodos([doneYesterday], on: Date()).count, 0)
        let yesterday = ScheduleAgenda.completedTodosForDay([doneYesterday], date: day(-1), calendar: calendar)
        // dueDate/completedAt 都是昨天 09:00（真实钟点）→ 昨天日程的 timed
        XCTAssertTrue(yesterday.allDay.isEmpty)
        XCTAssertEqual(yesterday.timed.count, 1)
        if case .todo(let todo) = yesterday.timed[0] {
            XCTAssertEqual(todo.title, "昨天完成")
        } else {
            XCTFail("应是 todo 事件")
        }
    }

    func testLegacyTodoWithoutCompletedAtOnlyAttributedToToday() {
        let legacy = Todo(title: "历史已完成无时间戳", isCompleted: true) // completedAt == nil
        // 查看今天：保守归入（与首页可见的遗留项一致）
        XCTAssertEqual(ScheduleAgenda.completedTodos([legacy], on: todayStart).count, 1)
        // 查看任意历史/未来日：不猜测归属
        XCTAssertEqual(ScheduleAgenda.completedTodos([legacy], on: day(-3)).count, 0)
        XCTAssertEqual(ScheduleAgenda.completedTodos([legacy], on: day(2)).count, 0)
    }

    func testPendingTodoNeverCountedAsCompleted() {
        let pending = Todo(title: "未完成", dueDate: todayAt(9), isCompleted: false)
        XCTAssertEqual(ScheduleAgenda.completedTodos([pending], on: Date()).count, 0)
    }

    // MARK: Delivery

    func testCompletedDeliveriesAttributedByUpdatedAt() {
        let doneToday = CustomerRequest(customer: "王姐", roomOrAddress: "", phone: "",
                                        content: "今天完成的配送", status: CustomerStatus.done.rawValue,
                                        createdAt: day(-1), updatedAt: todayAt(15))
        let doneYesterday = CustomerRequest(customer: "李哥", roomOrAddress: "", phone: "",
                                            content: "昨天完成", status: CustomerStatus.done.rawValue,
                                            createdAt: day(-2), updatedAt: day(-1).addingTimeInterval(3600 * 11))
        let delivering = CustomerRequest(customer: "陈姨", roomOrAddress: "", phone: "",
                                         content: "配送中", status: CustomerStatus.delivering.rawValue,
                                         createdAt: todayStart, updatedAt: todayAt(14))

        let today = ScheduleAgenda.completedDeliveries(
            [doneToday, doneYesterday, delivering], on: Date(), calendar: calendar
        )
        XCTAssertEqual(today.map(\.content), ["今天完成的配送"])
        XCTAssertEqual(ScheduleAgenda.completedDeliveries([doneYesterday], on: day(-1)).count, 1)
    }

    func testCompletedDeliveriesForDayDeduplicatesAndBackfills() {
        // d1：今天完成、配送时间在昨天 → dayData 不会收进今天，应补进今天全天区
        let d1Encoded = CustomerDeliveryStorage.encode(
            existingValue: "王姐", deliveryTime: day(-1).addingTimeInterval(3600 * 10), note: ""
        )
        let d1 = CustomerRequest(customer: d1Encoded, roomOrAddress: "", phone: "",
                                 content: "昨天预约今天送完", status: CustomerStatus.done.rawValue,
                                 createdAt: day(-1), updatedAt: todayAt(15))

        // d2：今天完成、配送时间今天 09:00 → dayData 已收进今天时间线，去重不重复
        let d2Encoded = CustomerDeliveryStorage.encode(
            existingValue: "李哥", deliveryTime: todayAt(9), note: ""
        )
        let d2 = CustomerRequest(customer: d2Encoded, roomOrAddress: "", phone: "",
                                 content: "今早配送", status: CustomerStatus.done.rawValue,
                                 createdAt: todayStart, updatedAt: todayAt(9))

        let result = ScheduleAgenda.completedDeliveriesForDay(
            [d1, d2],
            date: todayStart,
            alreadyIncludedIDs: ["delivery-\(d2.notificationID)"],
            calendar: calendar
        )
        XCTAssertTrue(result.timed.isEmpty, "d2 已在时间线，不得重复；d1 配送时间是昨天不得进今天 timed")
        XCTAssertEqual(result.allDay.map(\.content), ["昨天预约今天送完"])

        // 空去重集合时 d2 按真实钟点进 timed
        let full = ScheduleAgenda.completedDeliveriesForDay(
            [d1, d2], date: todayStart, alreadyIncludedIDs: [], calendar: calendar
        )
        XCTAssertEqual(full.timed.count, 1)
        XCTAssertEqual(full.allDay.count, 1)
    }

    // MARK: 首页口径 == 日程明细总数

    func testHomeCountMatchesScheduleTrackableItems() {
        let earlyDone = Todo(title: "提前完成", dueDate: day(1), isCompleted: true, completedAt: todayAt(16))
        let doneTodayDelivery = CustomerRequest(
            customer: "王姐", roomOrAddress: "", phone: "", content: "今日完成配送",
            status: CustomerStatus.done.rawValue, createdAt: day(-1), updatedAt: todayAt(17)
        )
        let delivering = CustomerRequest(customer: "陈姨", roomOrAddress: "", phone: "",
                                         content: "还在送", status: CustomerStatus.delivering.rawValue)

        // 首页计数（与 HomeView.todayCompletedCount 同一派生）
        let homeCount = ScheduleAgenda.completedTodos([earlyDone], on: Date()).count
            + ScheduleAgenda.completedDeliveries([doneTodayDelivery, delivering], on: Date()).count
        XCTAssertEqual(homeCount, 2)

        // 日程今天：Todo 在全天区；跨天完成的配送在补齐区——两项全部可追踪
        let todoBucket = ScheduleAgenda.completedTodosForDay([earlyDone], date: todayStart, calendar: calendar)
        let deliveryBucket = ScheduleAgenda.completedDeliveriesForDay(
            [doneTodayDelivery, delivering], date: todayStart, alreadyIncludedIDs: [], calendar: calendar
        )
        let scheduleCount = todoBucket.timed.count + todoBucket.allDay.count
            + deliveryBucket.timed.count + deliveryBucket.allDay.count
        XCTAssertEqual(scheduleCount, homeCount)
    }

    // MARK: Helpers

    private func yesterdayDue() -> Date {
        day(-1).addingTimeInterval(3600 * 9)
    }
}
