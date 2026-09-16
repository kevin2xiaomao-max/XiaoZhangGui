import XCTest
import SwiftData
@testable import XiaoZhangGui

/// P0-3：美团收入来源单元测试
/// 覆盖：
///   - IncomeSource.from(performance:) 优先用独立字段
///   - 空字符串 fallback 到 note 派生
///   - 普通营业收入 100 + 美团 50 = 今日营业额 150
///   - 月汇总正确
///   - IncomeSourceSummary.compute 拆分金额与比例
final class IncomeSourceTests: XCTestCase {

    // MARK: - 派生逻辑

    func testFromPerformancePrefersStoredIncomeSource() {
        let p = Performance(amount: 100, note: "门店消费", date: Date(), incomeSource: "美团")
        XCTAssertEqual(IncomeSource.from(performance: p), .meituan)
    }

    func testFromPerformanceFallsBackToNoteWhenEmpty() {
        let p = Performance(amount: 100, note: "美团外卖", date: Date(), incomeSource: "")
        XCTAssertEqual(IncomeSource.from(performance: p), .meituan)

        let q = Performance(amount: 100, note: "到店支付", date: Date(), incomeSource: "")
        XCTAssertEqual(IncomeSource.from(performance: q), .store)

        let r = Performance(amount: 100, note: "其他渠道", date: Date(), incomeSource: "")
        XCTAssertEqual(IncomeSource.from(performance: r), .other)
    }

    func testFromPerformanceFallsBackToPaymentMethodForSaobei() {
        // 扫呗导入：incomeSource 空，但 paymentMethod = "美团"
        let p = Performance(
            amount: 50,
            note: "扫呗",
            date: Date(),
            paymentMethod: "美团",
            orderNo: "S123",
            importSource: "saobei",
            incomeSource: ""
        )
        XCTAssertEqual(IncomeSource.from(performance: p), .meituan)
    }

    // MARK: - 今日总营业额 + 月汇总（端到端）

    @MainActor
    func testTodayRevenueIncludesMeituan() throws {
        let now = Date()
        let container = try makeEmptyContainer()
        let context = container.mainContext

        let store = Performance(amount: 100, note: "门店", date: now, incomeSource: "门店")
        let meituan = Performance(amount: 50, note: "美团外卖", date: now, incomeSource: "美团")
        context.insert(store)
        context.insert(meituan)
        try context.save()

        let all = try context.fetch(FetchDescriptor<Performance>())
        XCTAssertEqual(all.count, 2)

        let todayRevenue = all
            .filter { $0.date.isToday }
            .reduce(0) { $0 + $1.amount }
        XCTAssertEqual(todayRevenue, 150, accuracy: 0.001)

        // 月汇总
        let monthStart = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        let monthEnd = Calendar.current.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? now
        let monthRevenue = all
            .filter { $0.date >= monthStart && $0.date <= monthEnd }
            .reduce(0) { $0 + $1.amount }
        XCTAssertEqual(monthRevenue, 150, accuracy: 0.001)
    }

    // MARK: - IncomeSourceSummary 拆分金额与比例

    @MainActor
    func testSourceSummarySplitsStoreAndMeituan() throws {
        let now = Date()
        let container = try makeEmptyContainer()
        let context = container.mainContext

        context.insert(Performance(amount: 100, note: "门店", date: now, incomeSource: "门店"))
        context.insert(Performance(amount: 50, note: "美团外卖", date: now, incomeSource: "美团"))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Performance>())
        let range = (start: Calendar.current.startOfDay(for: now), end: now)
        let summaries = IncomeSourceSummary.compute(performances: all, range: range)

        let storeItem = summaries.first { $0.source == .store }
        let meituanItem = summaries.first { $0.source == .meituan }
        let otherItem = summaries.first { $0.source == .other }

        XCTAssertEqual(storeItem?.amount ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(meituanItem?.amount ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(otherItem?.amount ?? 0, 0)

        // 比例合计为 1
        let totalRatio = summaries.map(\.ratio).reduce(0, +)
        XCTAssertEqual(totalRatio, 1.0, accuracy: 0.001)
    }

    // MARK: - PerformanceStats.compute（今日 / 月 / 年净额）

    @MainActor
    func testPerformanceStatsTodayAggregatesAcrossSources() throws {
        let now = Date()
        let container = try makeEmptyContainer()
        let context = container.mainContext

        context.insert(Performance(amount: 100, note: "门店", date: now, incomeSource: "门店"))
        context.insert(Performance(amount: 50, note: "美团", date: now, incomeSource: "美团"))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Performance>())
        let stats = PerformanceStats.compute(
            performances: all,
            expenses: [],
            period: .today,
            customStart: now,
            customEnd: now
        )

        XCTAssertEqual(stats.totalRevenue, 150, accuracy: 0.001)
        XCTAssertEqual(stats.totalExpense, 0)
        XCTAssertEqual(stats.net, 150, accuracy: 0.001)
    }

    // MARK: - Helpers

    /// 空的 in-memory container，不预填演示数据
    @MainActor
    private func makeEmptyContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }
}

// MARK: - Date 辅助（对齐 Swift 内建语义）

fileprivate extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
