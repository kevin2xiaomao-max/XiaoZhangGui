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
}
