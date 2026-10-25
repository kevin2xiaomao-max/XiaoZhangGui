import XCTest
import SwiftData
@testable import XiaoZhangGui

// MARK: - V3.9.3 · 5000 条性能实测（可复现种子做法 + 实测时间打印到 test.log）
//
// 种子：内存容器中插入 5000 条 Performance（日期分散在近 90 天、来源美团/门店交替）、
// 各 500 条 Todo / CustomerRequest / Memo / Goods / ExpiryItem；单次 save 后分别计时：
// ① 全局搜索 ② 经营聚合（IncomeSourceSummary）③ groundingPack 全量聚合。
// 阈值放宽（搜索/聚合 < 5s、grounding < 60s），防慢速 runner 误杀；真实耗时以打印为准。

@MainActor
final class V393PerformanceTests: XCTestCase {

    func testFiveThousandRecordsSearchAggregationAndGrounding() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()
        let calendar = Calendar.current
        for index in 0..<5000 {
            let day = calendar.date(byAdding: .day, value: -(index % 90), to: now)!
            let source = index % 2 == 0 ? "美团" : "门店"
            context.insert(Performance(amount: Double((index % 500) + 1), note: source, date: day, incomeSource: source))
        }
        for index in 0..<500 {
            context.insert(Todo(title: "事项\(index)", detail: "详情\(index)", dueDate: now, priority: 0))
            context.insert(CustomerRequest(customer: "客户\(index)", roomOrAddress: "\(100 + index)", phone: "", content: "怡宝两箱"))
            context.insert(Memo(title: "备忘\(index)", content: "内容\(index) 怡宝"))
            context.insert(Goods(name: "商品\(index)", category: "水", stock: 10, minStock: 5, purchasePrice: 10, salePrice: 15))
            context.insert(ExpiryItem(name: "临期\(index)", category: "食品", quantity: 1,
                                      expiryDate: calendar.date(byAdding: .day, value: 3, to: now)!))
        }
        try context.save()

        let reader = RepositoryBusinessContextReader(context: context)

        let searchStart = CFAbsoluteTimeGetCurrent()
        let searchResults = await reader.searchGlobal(
            GlobalSearchQuery(terms: ["怡宝"], period: nil, status: nil))
        let searchElapsed = CFAbsoluteTimeGetCurrent() - searchStart

        let aggregationStart = CFAbsoluteTimeGetCurrent()
        let allPerformances = try context.fetch(FetchDescriptor<Performance>())
        let monthStart = calendar.dateInterval(of: .month, for: now)!.start
        let monthEnd = calendar.dateInterval(of: .month, for: now)!.end
        let summaries = IncomeSourceSummary.compute(
            performances: allPerformances,
            range: (start: monthStart, end: monthEnd.addingTimeInterval(-1)))
        let aggregationElapsed = CFAbsoluteTimeGetCurrent() - aggregationStart

        let groundingStart = CFAbsoluteTimeGetCurrent()
        let pack = await reader.groundingPack()
        let groundingElapsed = CFAbsoluteTimeGetCurrent() - groundingStart

        print("V393Perf: records=5000 performances + 500x5 others; "
            + "search=\(String(format: "%.3f", searchElapsed))s results=\(searchResults.count); "
            + "aggregation=\(String(format: "%.3f", aggregationElapsed))s sources=\(summaries.count); "
            + "grounding=\(String(format: "%.3f", groundingElapsed))s periodSummaries=\(pack.periodSummaries.count)")

        XCTAssertGreaterThan(searchResults.count, 0, "500 条含怡宝的备忘/配送应被命中")
        XCTAssertLessThan(searchElapsed, 5, "5000 条量级下全局搜索应 < 5s")
        XCTAssertLessThan(aggregationElapsed, 5, "经营聚合应 < 5s")
        XCTAssertLessThan(groundingElapsed, 60, "groundingPack 全量聚合应 < 60s（慢速 runner 宽限）")
    }
}
