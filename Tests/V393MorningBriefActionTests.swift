import XCTest
@testable import XiaoZhangGui

// MARK: - V3.9.3 E · 晨报行动化：行动项构成、时间标注、无数据不制造提醒。

final class V393MorningBriefActionTests: XCTestCase {

    private var cal: Calendar { Calendar.current }

    private func at(_ hour: Int, _ day: Int, month: Int = 10, year: Int = 2026) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: 30))!
    }

    func testActionItemsCoverTodoDeliveryAndExpiry() {
        let now = at(8, 28)
        let brief = MorningBriefBuilder.build(
            performances: [],
            todos: [
                Todo(title: "逾期盘点", detail: "", dueDate: at(9, 26), priority: 0),
                Todo(title: "今日补货", detail: "", dueDate: at(9, 28), priority: 0),
            ],
            expiryItems: [
                ExpiryItem(name: "牛奶", category: "乳品", quantity: 1,
                           expiryDate: cal.date(byAdding: .day, value: 3, to: now)!)
            ],
            customers: [
                CustomerRequest(customer: "阿东", roomOrAddress: "302", phone: "", content: "怡宝两箱")
            ],
            monthGoal: 0, now: now
        )
        let destinations = brief.actionItems.map(\.destination)
        XCTAssertTrue(destinations.contains(.todo(title: "逾期盘点")), "逾期待办必须进行动项")
        XCTAssertTrue(destinations.contains(.todo(title: "今日补货")))
        XCTAssertTrue(destinations.contains(.delivery(customer: "阿东", room: "302")), "未完成配送必须进行动项")
        XCTAssertTrue(destinations.contains(.expiry(name: "牛奶")), "临期商品必须进行动项")

        let overdue = brief.actionItems.first(where: { $0.destination == .todo(title: "逾期盘点") })!
        XCTAssertTrue(overdue.detail.contains("已逾期"), "逾期必须标注，不能只显示时间")
        let today = brief.actionItems.first(where: { $0.destination == .todo(title: "今日补货") })!
        XCTAssertEqual(today.detail, "09:30", "有钟点用 Fmt.time（hasClock 口径）")
        let delivery = brief.actionItems.first(where: { $0.destination == .delivery(customer: "阿东", room: "302") })!
        XCTAssertTrue(delivery.detail.contains("待处理"), "配送状态必须明示")
        XCTAssertFalse(brief.actionItems.contains(where: { $0.title.contains("138") || $0.detail.contains("138") }),
                       "行动项绝不能带电话")
    }

    func testMidnightTodoShowsAllDay() {
        let now = at(8, 28)
        let midnight = cal.startOfDay(for: now)
        let brief = MorningBriefBuilder.build(
            performances: [],
            todos: [Todo(title: "全天事项", detail: "", dueDate: midnight, priority: 0)],
            expiryItems: [], customers: [], monthGoal: 0, now: now
        )
        let item = brief.actionItems.first(where: { $0.destination == .todo(title: "全天事项") })
        XCTAssertEqual(item?.detail, "全天", "00:00 无钟点（hasClock 为假）时显示全天")
    }

    func testEmptyDataProducesNoActionItems() {
        let brief = MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [], customers: [],
            monthGoal: 0, now: at(8, 28)
        )
        XCTAssertTrue(brief.actionItems.isEmpty, "无数据时绝不能制造提醒")
    }

    func testActionItemsAreCappedAtSix() {
        let now = at(8, 28)
        let todos = (0..<10).map { Todo(title: "事项\($0)", detail: "", dueDate: now, priority: 0) }
        let brief = MorningBriefBuilder.build(
            performances: [], todos: todos, expiryItems: [], customers: [],
            monthGoal: 0, now: now
        )
        XCTAssertLessThanOrEqual(brief.actionItems.count, 6)
    }
}
