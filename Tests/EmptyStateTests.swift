import XCTest

final class EmptyStateTests: XCTestCase {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testCustomerAndExpiryEmptyStatesOfferExistingCreateFlows() throws {
        let customer = try source("XiaoZhangGui/Features/Customer/CustomerView.swift")
        XCTAssertTrue(customer.contains("requests.isEmpty"))
        // 空状态提供新增配送入口（V371 原生 Button，不依赖旧 V32PrimaryButton 名称）
        XCTAssertTrue(customer.contains("Label(\"新增配送\""))
        XCTAssertTrue(customer.contains("showNewEditor = true"))

        let expiry = try source("XiaoZhangGui/Features/Expiry/ExpiryView.swift")
        // 空状态提供新增临期商品入口
        XCTAssertTrue(expiry.contains("Label(\"新增临期商品\""))
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
        // 空状态提供记一笔入口（V371 原生 Button）
        XCTAssertTrue(performance.contains("Label(\"记一笔\""))
    }
}
