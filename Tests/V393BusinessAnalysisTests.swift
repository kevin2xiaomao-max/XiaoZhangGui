import XCTest
@testable import XiaoZhangGui

// MARK: - V3.9.3 A · 经营分析助手：自然周口径、含今日的 3/6 月区间、
// 建议 / 最高最低日 / 来源占比 / 支出净额（执行数以 CI test.log 为准）。

final class V393BusinessAnalysisTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    /// 2026-10-28（周三）12:00 +08:00；本周一为 2026-10-26。
    private var wednesdayNoon: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 28
        components.hour = 12
        return calendar.date(from: components)!
    }

    // MARK: 口径

    func testThisWeekIsMondayStartNaturalWeek() {
        let parser = BusinessPeriodParser()
        XCTAssertEqual(parser.parse("本周生意怎么样"), .thisWeek)
        XCTAssertEqual(parser.parse("这一周业绩"), .thisWeek)
        XCTAssertEqual(parser.parse("上周业绩"), .lastWeek)
        // 「最近一周 / 过去 7 天」仍走过去 7 天，不被自然周吞掉。
        XCTAssertEqual(parser.parse("最近一周的生意"), .lastSevenDays)
        XCTAssertEqual(parser.parse("过去7天收入"), .lastSevenDays)
        XCTAssertEqual(parser.parse("过去一周收入"), .lastSevenDays)

        let week = try! XCTUnwrap(parser.bounds(for: .thisWeek, now: wednesdayNoon, calendar: calendar))
        XCTAssertEqual(calendar.component(.weekday, from: week.start), 2, "自然周必须周一起始")
        XCTAssertEqual(week.end.timeIntervalSince(week.start), 7 * 24 * 3600, accuracy: 1)
        let lastWeek = try! XCTUnwrap(parser.bounds(for: .lastWeek, now: wednesdayNoon, calendar: calendar))
        XCTAssertEqual(lastWeek.end, week.start, "上周区间必须紧贴本周起点")
        XCTAssertTrue(week.contains(wednesdayNoon))
        XCTAssertFalse(lastWeek.contains(wednesdayNoon))
    }

    func testLastThreeAndSixMonthsIncludeToday() {
        let parser = BusinessPeriodParser()
        let today = calendar.startOfDay(for: wednesdayNoon)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        for period in [BusinessPeriod.lastThreeMonths, BusinessPeriod.lastSixMonths] {
            let bounds = try! XCTUnwrap(parser.bounds(for: period, now: wednesdayNoon, calendar: calendar))
            XCTAssertEqual(bounds.end, tomorrow, "\(period) 的 end 必须含今日全天（tomorrow 0 点）")
            XCTAssertTrue(bounds.contains(wednesdayNoon), "\(period) 必须含今日")
        }
        let six = try! XCTUnwrap(parser.bounds(for: .lastSixMonths, now: wednesdayNoon, calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.month], from: six.start, to: six.end).month, 6)
    }

    // MARK: Composer

    private func packForComposer() -> GroundingPack {
        let day = { (offset: Int, amount: Double) -> DailyRevenueSummary in
            DailyRevenueSummary(
                date: self.calendar.date(byAdding: .day, value: offset, to: self.calendar.startOfDay(for: self.wednesdayNoon))!,
                amount: amount)
        }
        return GroundingPack(
            todayRevenue: 500, yesterdayRevenue: 400,
            sevenDayRevenue: [day(-6, 100), day(-5, 300), day(-4, 200), day(-3, 0), day(-2, 150), day(-1, 400), day(0, 500)],
            unfinishedTodoTitles: ["联系供应商", "盘点"],
            deliveryPendingCount: 2, deliveryDeliveringCount: 1,
            expiryTitles: ["牛奶"],
            goods: [GoodsSummary(name: "怡宝", purchasePrice: 10, salePrice: 15, stock: 1, minStock: 5)],
            localSummary: nil,
            periodSummaries: [
                BusinessPeriodSummary(period: .thisMonth, amount: 1000, count: 5, comparisonAmount: nil, comparisonMonthCount: nil, comparisonAverageAmount: nil)
            ],
            expenseTotals: [.thisMonth: 300],
            sourceShares: [
                SourceShareSummary(name: "美团", amount: 600, percent: 60),
                SourceShareSummary(name: "门店", amount: 400, percent: 40)
            ])
    }

    func testAdviceIsNonEmptyAndLabelsSpeculation() {
        let answer = BusinessAnswerComposer.answer(for: .advice, pack: packForComposer())
        XCTAssertFalse(answer.isEmpty, "advice 绝不能再返回空串")
        XCTAssertTrue(answer.contains("怡宝"), "建议必须基于已知低库存事实")
        XCTAssertTrue(answer.contains("推测"), "推测部分必须明确标注")
        XCTAssertFalse(answer.contains("利润"), "不得虚构利润")
        XCTAssertFalse(answer.contains("客流"), "不得虚构客流")
    }

    func testExtremesFromSevenDayRevenue() {
        let answer = BusinessAnswerComposer.answer(for: .extremes, pack: packForComposer())
        XCTAssertTrue(answer.contains("最高"), "必须给出最高日")
        XCTAssertTrue(answer.contains("最低"), "必须给出最低日")
        XCTAssertTrue(answer.contains("¥500"), "最高日金额应为今日 500")
        XCTAssertTrue(answer.contains("¥100"), "最低日金额应为 100（0 元空日不计入）")
    }

    func testExtremesEmptyStatesNoData() {
        XCTAssertTrue(BusinessAnswerComposer.answer(for: .extremes, pack: .empty).contains("还没有营业额记录"))
    }

    func testSourceShareAnswer() {
        let answer = BusinessAnswerComposer.answer(for: .sourceShare, pack: packForComposer())
        XCTAssertTrue(answer.contains("美团 60%"))
        XCTAssertTrue(answer.contains("门店 40%"))
        XCTAssertTrue(BusinessAnswerComposer.answer(for: .sourceShare, pack: .empty).contains("暂无"))
    }

    func testPeriodAnswerIncludesExpenseAndNet() {
        let answer = BusinessAnswerComposer.answer(for: .period(.thisMonth), pack: packForComposer())
        XCTAssertTrue(answer.contains("¥1,000") || answer.contains("¥1000"), "收入合计")
        XCTAssertTrue(answer.contains("支出"), "有支出记录时必须追加支出")
        XCTAssertTrue(answer.contains("¥300"), "支出金额")
        XCTAssertTrue(answer.contains("净额"), "必须给出净额")
        XCTAssertTrue(answer.contains("¥700"), "净额 = 1000 - 300")
    }

    // MARK: 路由

    func testIntentRoutesExtremesAndSourceShareAndThisWeek() {
        let router = IntentRouter()
        XCTAssertEqual(router.classify("本周最高营业日是哪天"), .businessInsight(.extremes))
        XCTAssertEqual(router.classify("本月收入来源占比"), .businessInsight(.sourceShare))
        XCTAssertEqual(router.classify("本周生意怎么样"), .businessInsight(.period(.thisWeek)))
        XCTAssertEqual(router.classify("上周生意怎么样"), .businessInsight(.period(.lastWeek)))
    }

    // MARK: Reader 集成：支出合计与自然周摘要

    @MainActor
    func testReaderExpenseTotalsAndThisWeekSummary() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()
        context.insert(Performance(amount: 800, note: "门店", date: now, incomeSource: "门店"))
        context.insert(Expense(amount: 120, category: "进货", note: "怡宝", date: now))
        try context.save()
        let pack = await RepositoryBusinessContextReader(context: context).groundingPack()
        XCTAssertEqual(pack.expenseTotals[.today] ?? -1, 120, accuracy: 0.001)
        XCTAssertTrue(pack.periodSummaries.contains(where: { $0.period == .thisWeek }),
                      "groundingPack 必须含本周（自然周）摘要")
        XCTAssertTrue(pack.periodSummaries.contains(where: { $0.period == .lastWeek }))
        XCTAssertEqual(pack.sourceShares.first(where: { $0.name == "门店" })?.amount ?? -1, 800, accuracy: 0.001)
    }
}
