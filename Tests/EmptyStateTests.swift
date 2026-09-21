import XCTest

final class EmptyStateTests: XCTestCase {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testCustomerAndExpiryEmptyStatesOfferExistingCreateFlows() throws {
        let customer = try source("XiaoZhangGui/Features/Customer/CustomerView.swift")
        XCTAssertTrue(customer.contains("requests.isEmpty"))
        XCTAssertTrue(customer.contains("V32PrimaryButton(title: \"新增配送\""))
        XCTAssertTrue(customer.contains("showNewEditor = true"))

        let expiry = try source("XiaoZhangGui/Features/Expiry/ExpiryView.swift")
        XCTAssertTrue(expiry.contains("V32PrimaryButton(title: \"新增临期商品\""))
        XCTAssertTrue(expiry.contains("showNewEditor = true"))
    }

    func testFilteredCustomerEmptyStateIsDistinctFromDatabaseEmpty() throws {
        let source = try source("XiaoZhangGui/Features/Customer/CustomerView.swift")
        XCTAssertTrue(source.contains("当前筛选暂无结果"))
        XCTAssertTrue(source.contains("暂无客户需求"))
    }

    func testScheduleAndPerformanceEmptyStatesRemainLightweight() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        XCTAssertTrue(schedule.contains("该日期暂无事项"))
        XCTAssertTrue(schedule.contains("这一天还没有安排"))

        let performance = try source("XiaoZhangGui/Features/Performance/PerformanceView.swift")
        XCTAssertTrue(performance.contains("V32PrimaryButton(title: \"记一笔\""))
    }
}
