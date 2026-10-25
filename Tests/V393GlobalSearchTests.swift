import XCTest
import SwiftData
@testable import XiaoZhangGui

// MARK: - V3.9.3 F · 全局自然语言搜索：解析、匹配、脱敏、只读。

final class V393GlobalSearchTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private var now: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 28
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func record(_ category: GlobalSearchCategory, title: String, snippet: String,
                        date: Date?, status: GlobalSearchStatus? = nil) -> GlobalSearchRecord {
        GlobalSearchRecord(id: "\(category.rawValue)-\(title)", category: category,
                           title: title, snippet: snippet, date: date, status: status)
    }

    // MARK: 解析

    func testParseStripsTimeStatusAndCategoryWords() {
        let query = GlobalSearchEngine.parse("搜索 上周 302 的配送", now: now, calendar: calendar)
        XCTAssertEqual(query.period, .lastWeek)
        XCTAssertEqual(query.terms, ["302"], "时间词与类别词剥离后只剩关键词")
        let done = GlobalSearchEngine.parse("搜索已完成 302 配送", now: now, calendar: calendar)
        XCTAssertEqual(done.status, .done)
        XCTAssertEqual(done.terms, ["302"])
        let simple = GlobalSearchEngine.parse("搜索 怡宝", now: now, calendar: calendar)
        XCTAssertEqual(simple.terms, ["怡宝"])
        XCTAssertNil(simple.period)
        XCTAssertTrue(GlobalSearchEngine.isGlobalSearch("搜索 怡宝"))
        XCTAssertTrue(GlobalSearchEngine.isGlobalSearch("查找 302"))
        XCTAssertFalse(GlobalSearchEngine.isGlobalSearch("怡宝多少钱"))
    }

    func testRouterRoutesSearchTriggerToGlobalSearch() {
        XCTAssertEqual(IntentRouter().classify("搜索 怡宝"), .globalSearch("搜索 怡宝"))
        XCTAssertEqual(IntentRouter().classify("查找 302 的配送"), .globalSearch("查找 302 的配送"))
    }

    // MARK: 匹配

    func testSearchMatchesAllTermsAndFiltersByPeriodAndStatus() {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let records = [
            record(.delivery, title: "阿东", snippet: "怡宝两箱 302", date: today, status: .pending),
            record(.delivery, title: "阿东", snippet: "怡宝两箱 302", date: yesterday, status: .delivering),
            record(.memo, title: "怡宝补货", snippet: "记得进货", date: today),
            record(.todo, title: "盘点", snippet: "", date: today, status: .overdue),
        ]
        let byRoom = GlobalSearchEngine.search(
            GlobalSearchQuery(terms: ["302"], period: nil, status: nil),
            in: records, now: now, calendar: calendar)
        XCTAssertEqual(byRoom.count, 2, "房号 302 应命中两条配送")
        let todayOnly = GlobalSearchEngine.search(
            GlobalSearchQuery(terms: ["302"], period: .today, status: nil),
            in: records, now: now, calendar: calendar)
        XCTAssertEqual(todayOnly.count, 1, "今天筛选必须排除昨日记录")
        let pendingOnly = GlobalSearchEngine.search(
            GlobalSearchQuery(terms: ["302"], period: nil, status: .pending),
            in: records, now: now, calendar: calendar)
        XCTAssertEqual(pendingOnly.count, 1, "待处理筛选必须排除配送中")
        let overdue = GlobalSearchEngine.search(
            GlobalSearchQuery(terms: ["盘点"], period: nil, status: .overdue),
            in: records, now: now, calendar: calendar)
        XCTAssertEqual(overdue.count, 1)
        let none = GlobalSearchEngine.search(
            GlobalSearchQuery(terms: ["不存在的商品"], period: nil, status: nil),
            in: records, now: now, calendar: calendar)
        XCTAssertTrue(none.isEmpty, "无匹配时返回空态，不编造结果")
    }

    // MARK: Reader 集成：脱敏与只读

    @MainActor
    func testReaderSearchExcludesPhoneAndWritesNothing() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Memo(title: "怡宝补货", content: "周五进怡宝二十箱"))
        context.insert(CustomerRequest(customer: "阿东", roomOrAddress: "302", phone: "13800001111", content: "怡宝两箱"))
        context.insert(Goods(name: "怡宝", category: "水", stock: 10, minStock: 5, purchasePrice: 10, salePrice: 15))
        try context.save()
        let reader = RepositoryBusinessContextReader(context: context)
        let beforeMemos = try context.fetch(FetchDescriptor<Memo>()).count
        let results = await reader.searchGlobal(GlobalSearchQuery(terms: ["怡宝"], period: nil, status: nil))
        XCTAssertGreaterThanOrEqual(results.count, 3, "备忘、配送、商品三类都应命中怡宝")
        XCTAssertFalse(results.contains(where: { $0.record.title.contains("138") || $0.record.snippet.contains("138") }),
                       "电话绝不能进搜索结果")
        XCTAssertFalse(results.contains(where: { $0.record.snippet.contains("138") }))
        XCTAssertEqual(try context.fetch(FetchDescriptor<Memo>()).count, beforeMemos, "搜索只读，不得写入")
        XCTAssertTrue(results.map(\.record.category).contains(.goods))
        XCTAssertTrue(results.map(\.record.category).contains(.delivery))
        XCTAssertTrue(results.map(\.record.category).contains(.memo))
    }

    // MARK: AgentCore 对话内搜索：只读、无卡

    @MainActor
    func testAgentCoreGlobalSearchAnswersWithoutCard() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Goods(name: "怡宝", category: "水", stock: 10, minStock: 5, purchasePrice: 10, salePrice: 15))
        try context.save()
        let journal = InMemoryExecutionJournal()
        let env = try AgentEnvironment.makeLive(
            provider: UnconfiguredRemoteProvider(), fallback: nil,
            contextProvider: RepositoryBusinessContextReader(context: context),
            toolExecutor: RepositoryToolExecutor(context: context, journal: journal),
            conversation: InMemoryConversationStore(),
            pending: InMemoryPendingActionStore(),
            journal: journal)
        let agent = AgentCore(env)
        let turn = await agent.send("搜索 怡宝")
        XCTAssertNil(turn.proposal, "只读搜索不得产生 ActionCard")
        let content = turn.assistantMessage?.content ?? ""
        XCTAssertTrue(content.contains("怡宝"), "回答必须含命中结果")
        XCTAssertTrue(content.contains("商品"), "回答必须含类别")
    }
}
