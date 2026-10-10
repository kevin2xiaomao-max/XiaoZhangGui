import XCTest
import SwiftData
@testable import XiaoZhangGui

@MainActor
final class DemoCatalogTests: XCTestCase {
    func testDemoContainerIsMemoryOnlyAndHasRichData() throws {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 20)) ?? Date()
        let container = DemoCatalog.makeContainer(now: now)
        let context = ModelContext(container)

        let performances = try context.fetch(FetchDescriptor<Performance>())
        let todos = try context.fetch(FetchDescriptor<Todo>())
        let customers = try context.fetch(FetchDescriptor<CustomerRequest>())
        let expiry = try context.fetch(FetchDescriptor<ExpiryItem>())
        let memos = try context.fetch(FetchDescriptor<Memo>())

        XCTAssertGreaterThanOrEqual(performances.count, 20)
        XCTAssertGreaterThanOrEqual(todos.count, 15)
        XCTAssertGreaterThanOrEqual(customers.count, 8)
        XCTAssertGreaterThanOrEqual(expiry.count, 7)
        XCTAssertGreaterThanOrEqual(memos.count, 8)

        let todayRevenue = performances.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(todayRevenue, 2680.50, accuracy: 0.01)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayRevenue = performances.filter { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(yesterdayRevenue, 2381.20, accuracy: 0.01)
    }

    func testDemoImportPreviewDoesNotNeedFile() {
        let preview = DemoImportPreview.parseResult()
        XCTAssertEqual(preview.sourceFileName, "扫呗交易明细_2026-09-14.csv")
        XCTAssertEqual(preview.rows.count, 5)
        XCTAssertEqual(DemoImportPreview.fakeCommit.inserted, 304)
        XCTAssertEqual(DemoImportPreview.fakeCommit.duplicates, 12)
    }

    func testDemoModeKeyIsIsolatedFromRepositories() {
        XCTAssertEqual(DemoMode.userDefaultsKey, "xzg_demo_mode_enabled")
    }

    func testMonthlyMetricsUseQueriedRecordsAndModeSpecificGoal() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 12))!
        let thisMonth = Performance(amount: 2_500, note: "本月", date: now)
        let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
        let lastMonth = Performance(amount: 9_999, note: "上月", date: lastMonthDate)

        XCTAssertEqual(
            MonthlyBusinessMetrics.revenue(from: [thisMonth, lastMonth], now: now),
            2_500,
            accuracy: 0.001
        )
        XCTAssertEqual(
            MonthlyBusinessMetrics.goal(isDemoEnabled: true, settingsGoal: 88_000),
            DemoCatalog.monthlyGoal
        )
        XCTAssertEqual(
            MonthlyBusinessMetrics.goal(isDemoEnabled: false, settingsGoal: 88_000),
            88_000
        )
    }

    func testDemoMonthlyMetricComesFromIsolatedContainer() throws {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 20))!
        let container = DemoCatalog.makeContainer(now: now)
        let performances = try ModelContext(container).fetch(FetchDescriptor<Performance>())
        let derived = MonthlyBusinessMetrics.revenue(from: performances, now: now)

        XCTAssertGreaterThan(derived, 0)
        XCTAssertNotEqual(derived, 68_400, "月营业额必须来自演示容器查询，不能回退到旧固定值")
    }
}
