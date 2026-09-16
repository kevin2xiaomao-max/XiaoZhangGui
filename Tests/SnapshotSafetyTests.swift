import XCTest
import SwiftData
@testable import XiaoZhangGui

/// P1-4：快照安全
/// - 查询失败时 buildSnapshot 返回 nil，不得返回空快照
/// - commit(snapshot: nil) 必须保留上一次有效快照，Widget / Live Activity 不被清零
@MainActor
final class SnapshotSafetyTests: XCTestCase {

    private func makeEmptyContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }

    func testBuildSnapshotSucceedsWithRealData() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let cal = Calendar.current
        let now = Date()
        // 用「当前时间 +1 小时」作为下一条待办，保证它在任何执行时刻都位于未来，
        // 不依赖固定钟点（修复 CI UTC 17:xx 执行时 15:00 已过导致的顺序相关 flaky）。
        let futureDue = Date(timeIntervalSinceNow: 3600)
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: now))!
        let inThreeDays = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: now))!

        ctx.insert(Todo(title: "盘点进货", dueDate: futureDue, priority: 1))          // 下一条（未来）
        ctx.insert(Todo(title: "昨日逾期", dueDate: yesterday, priority: 0))          // 逾期
        ctx.insert(Todo(title: "已完成", dueDate: futureDue, isCompleted: true,
                        completedAt: now))                                            // 不计待办
        ctx.insert(Performance(amount: 100, note: "门店", date: now,
                               incomeSource: IncomeSource.store.rawValue))
        ctx.insert(Performance(amount: 50, note: "美团", date: now,
                               incomeSource: IncomeSource.meituan.rawValue))
        ctx.insert(ExpiryItem(name: "鲜奶", category: "", quantity: 1, expiryDate: inThreeDays))
        ctx.insert(CustomerRequest(customer: "王姐", roomOrAddress: "", phone: "",
                                   content: "配送中订单", status: CustomerStatus.delivering.rawValue))
        try ctx.save()

        let snapshot = try XCTUnwrap(SnapshotSyncManager.buildSnapshot(context: ctx))
        XCTAssertEqual(snapshot.todayRevenue, 150, accuracy: 0.001)
        // 今日待办数按执行时刻的日历实时计算（跨午夜边界也成立）
        let expectedTodayCount = cal.isDateInToday(futureDue) ? 1 : 0
        XCTAssertEqual(snapshot.todayTodoCount, expectedTodayCount)
        XCTAssertEqual(snapshot.overdueTodoCount, 1)
        XCTAssertEqual(snapshot.urgentExpiryCount, 1)
        XCTAssertEqual(snapshot.nextExpiryName, "鲜奶")
        XCTAssertEqual(snapshot.deliveringCustomerCount, 1)
        XCTAssertEqual(snapshot.nextTodoTitle, "盘点进货")
    }

    func testBuildSnapshotReturnsNilWhenFetchFails() {
        // 数据源抛错（模拟 SwiftData 查询失败）：必须返回 nil，
        // 而不是吞错后返回全 0 空快照让上层误存
        struct FetchFailure: Error {}
        let snapshot = SnapshotSyncManager.buildSnapshot { throw FetchFailure() }
        XCTAssertNil(snapshot)
    }

    func testCommitNilKeepsPreviousSnapshot() throws {
        guard let defaults = XZGShared.sharedDefaults else {
            throw XCTSkip("测试环境无法访问 App Group UserDefaults")
        }

        // 先写入一份「上次有效快照」
        var previous = BusinessSnapshot()
        previous.todayRevenue = 888
        previous.todayTodoCount = 7
        previous.deliveringCustomerCount = 3
        previous.save()

        // 失败路径：commit(nil) 不得覆盖
        SnapshotSyncManager.commit(snapshot: nil)
        let retained = try XCTUnwrap(BusinessSnapshot.load())
        XCTAssertEqual(retained.todayRevenue, 888, accuracy: 0.001)
        XCTAssertEqual(retained.todayTodoCount, 7)
        XCTAssertEqual(retained.deliveringCustomerCount, 3)

        // 成功路径：commit(非 nil) 正常覆盖
        var fresh = BusinessSnapshot()
        fresh.todayRevenue = 123
        SnapshotSyncManager.commit(snapshot: fresh)
        let updated = try XCTUnwrap(BusinessSnapshot.load())
        XCTAssertEqual(updated.todayRevenue, 123, accuracy: 0.001)

        // 还原，避免污染后续测试
        defaults.removeObject(forKey: BusinessSnapshot.storageKey)
    }
}
