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
    func testInboxCapsAtFourAndRanksUrgentFirst() throws {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 20)) ?? Date()
        let container = DemoCatalog.makeContainer(now: now)
        let context = ModelContext(container)
        let todos = try context.fetch(FetchDescriptor<Todo>())
        let customers = try context.fetch(FetchDescriptor<CustomerRequest>())
        let expiry = try context.fetch(FetchDescriptor<ExpiryItem>())
        let summary = TodaySummary.build(performances: [], todos: todos, customers: customers, expiryItems: expiry, now: now)
        let items = HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries, expiryItems: summary.pendingExpiry, limit: 4)
        XCTAssertLessThanOrEqual(items.count, 4)
        XCTAssertFalse(items.contains { DisplayText.isEncoded($0.title) || DisplayText.isEncoded($0.subtitle) })
        XCTAssertEqual(items.first?.route, .expiry)
        // 排序稳定：按 rank 升序
        let ranks = items.map(\.rank)
        XCTAssertEqual(ranks, ranks.sorted())
    }

    @MainActor
    func testInboxExcludesStripDeliveriesButKeepsOthers() throws {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 20)) ?? Date()
        let container = DemoCatalog.makeContainer(now: now)
        let context = ModelContext(container)
        let todos = try context.fetch(FetchDescriptor<Todo>())
        let customers = try context.fetch(FetchDescriptor<CustomerRequest>())
        let expiry = try context.fetch(FetchDescriptor<ExpiryItem>())
        let summary = TodaySummary.build(performances: [], todos: todos, customers: customers, expiryItems: expiry, now: now)

        // 与 HomeView.topDeliveries 同口径：配送中优先 -> 待处理按更新时间，最多 2 单
        let strip = Array(summary.deliveries.sorted { lhs, rhs in
            if lhs.statusEnum != rhs.statusEnum {
                return lhs.statusEnum == .delivering && rhs.statusEnum != .delivering
            }
            return lhs.updatedAt > rhs.updatedAt
        }.prefix(2))
        let stripIDs = Set(strip.map { "delivery-\($0.notificationID)" })

        let all = HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries,
                                  expiryItems: summary.pendingExpiry, limit: 4)
        let filtered = HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries,
                                       expiryItems: summary.pendingExpiry, limit: 4,
                                       excludingDeliveryIDs: stripIDs)

        // 横卡配送不重复出现在今日事项
        XCTAssertFalse(filtered.contains { stripIDs.contains($0.id) })
        // 总数仍 <=4
        XCTAssertLessThanOrEqual(filtered.count, 4)
        // demo 有多个待处理配送：未在横卡的其它配送仍保留可入列
        XCTAssertFalse(summary.deliveries.isEmpty)
        let nonStrip = summary.deliveries.filter { !stripIDs.contains("delivery-\($0.notificationID)") }
        XCTAssertFalse(nonStrip.isEmpty)

        // 全部配送 ID 排除后今日事项不再出现客户路由；且 todo/临期项不丢失（超集关系）
        let allDeliveryIDs = Set(summary.deliveries.map { "delivery-\($0.notificationID)" })
        let noDeliveries = HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries,
                                          expiryItems: summary.pendingExpiry, limit: 4,
                                          excludingDeliveryIDs: allDeliveryIDs)
        XCTAssertFalse(noDeliveries.contains { $0.route == .customer })
        let nonDeliveryInAll = Set(all.filter { $0.route != .customer }.map(\.id))
        XCTAssertTrue(nonDeliveryInAll.isSubset(of: Set(noDeliveries.map(\.id))))
    }

    private func date(hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: hour)) ?? Date()
    }
}
