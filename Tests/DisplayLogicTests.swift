import XCTest
import SwiftData
@testable import XiaoZhangGui

final class DisplayLogicTests: XCTestCase {
    func testGreetingByLocalHour() {
        XCTAssertEqual(Greeting.phrase(at: date(hour: 7), owner: "掌柜"), "早上好，掌柜")
        XCTAssertEqual(Greeting.phrase(at: date(hour: 11), owner: "掌柜"), "中午好，掌柜")
        XCTAssertEqual(Greeting.phrase(at: date(hour: 14), owner: "掌柜"), "下午好，掌柜")
        XCTAssertEqual(Greeting.phrase(at: date(hour: 18), owner: "掌柜"), "晚上好，掌柜")
        XCTAssertEqual(Greeting.phrase(at: date(hour: 10), owner: "  "), "早上好")
    }

    func testDisplayTextHidesDeliveryPayload() {
        XCTAssertEqual(DisplayText.visible("xzg-delivery-v1:abc", fallback: "客户"), "客户")
        XCTAssertEqual(DisplayText.visible("张老板", fallback: "客户"), "张老板")
        XCTAssertTrue(DisplayText.isEncoded("xzg-delivery-v1:YmFzZTY0"))
        XCTAssertEqual(DisplayText.joined("张老板", "温泉路 18 号"), "张老板 · 温泉路 18 号")
        XCTAssertEqual(DisplayText.joined("xzg-delivery-v1:abc", "温泉路 18 号"), "温泉路 18 号")
    }

    func testRecordSourceNeverShowsOther() {
        XCTAssertEqual(RecordSourceLabel.display(importSource: "saobei", note: "微信"), "扫呗")
        XCTAssertEqual(RecordSourceLabel.display(importSource: "扫呗", paymentMethod: "支付宝"), "扫呗")
        XCTAssertEqual(RecordSourceLabel.display(note: "手动"), "手动")
        XCTAssertEqual(RecordSourceLabel.display(note: "营业额", category: "其他"), "手动")
        XCTAssertEqual(RecordSourceLabel.display(category: "水电"), "水电")
        XCTAssertNotEqual(RecordSourceLabel.display(note: "其他"), "其他")
    }

    func testTodoGroupsByPeriod() {
        let morning = Todo(title: "早", dueDate: date(hour: 9))
        let afternoon = Todo(title: "午", dueDate: date(hour: 15))
        let evening = Todo(title: "晚", dueDate: date(hour: 21))
        let groups = TodoFilter.grouped([evening, morning, afternoon])
        XCTAssertEqual(groups.map(\.label), ["上午", "下午", "晚上"])
        XCTAssertEqual(groups[0].items.first?.title, "早")
    }

    @MainActor
    func testInboxCapsAtFiveAndRanksUrgentFirst() throws {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 20)) ?? Date()
        let container = DemoCatalog.makeContainer(now: now)
        let context = ModelContext(container)
        let todos = try context.fetch(FetchDescriptor<Todo>())
        let customers = try context.fetch(FetchDescriptor<CustomerRequest>())
        let expiry = try context.fetch(FetchDescriptor<ExpiryItem>())
        let summary = TodaySummary.build(performances: [], todos: todos, customers: customers, expiryItems: expiry, now: now)
        let items = HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries, expiryItems: summary.pendingExpiry)
        XCTAssertLessThanOrEqual(items.count, 5)
        XCTAssertFalse(items.contains { DisplayText.isEncoded($0.title) || DisplayText.isEncoded($0.subtitle) })
        XCTAssertEqual(items.first?.route, .expiry)
    }

    private func date(hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: hour)) ?? Date()
    }
}
