import XCTest
import SwiftData
@testable import XiaoZhangGui

/// V3.9.1 P0:月报同期口径 / 深色固定色对比度 / 备份去重与事务语义。
final class V391P0Tests: XCTestCase {

    private func fixedDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = 12
        return Calendar.current.date(from: comps)!
    }

    private func perf(_ amount: Double, _ date: Date, _ note: String = "", _ source: String = "门店") -> Performance {
        Performance(amount: amount, note: note, date: date, incomeSource: source)
    }

    // MARK: - P0-1 月报同期

    func testSamePeriodLabelAndRange() {
        let report = MonthlyReportBuilder.build(
            performances: [perf(1000, fixedDate(2026, 6, 10)), perf(500, fixedDate(2026, 5, 15))],
            expenses: [], todos: [], now: fixedDate(2026, 6, 15))
        XCTAssertEqual(report.comparisonLabel, "较上月同期")
        XCTAssertEqual(report.previousPeriodLabel, "5月1日–5月15日")
        XCTAssertEqual(report.revenueChangePercent ?? 0, 100, accuracy: 0.01)
    }

    func testPrevSampleOutsideSamePeriodIsExcluded() {
        // now=3月15日,上期同期为2月1–15日:2月20日的样本必须排除,上期为0则无百分比。
        let report = MonthlyReportBuilder.build(
            performances: [perf(600, fixedDate(2026, 3, 10)), perf(9999, fixedDate(2026, 2, 20))],
            expenses: [], todos: [], now: fixedDate(2026, 3, 15))
        XCTAssertEqual(report.revenue, 600, accuracy: 0.001)
        XCTAssertNil(report.revenueChangePercent, "同期外样本不得计入上期,上期为零时不得显示虚假百分比")
        XCTAssertEqual(report.previousPeriodLabel, "2月1日–2月15日")
    }

    func testShortMonthClampsToPrevMonthEnd() {
        // now=3月31日,上月2月只有28天:同期钳制到2月28日,2月28日样本计入。
        let report = MonthlyReportBuilder.build(
            performances: [perf(900, fixedDate(2026, 3, 31)), perf(400, fixedDate(2026, 2, 28))],
            expenses: [], todos: [], now: fixedDate(2026, 3, 31))
        XCTAssertEqual(report.revenue, 900, accuracy: 0.001)
        XCTAssertEqual(report.revenueChangePercent ?? 0, 125, accuracy: 0.01, "(900-400)/400")
        XCTAssertEqual(report.previousPeriodLabel, "2月1日–2月28日")
    }

    func testLeapYearFeb29IsIncluded() {
        // 2024 为闰年:now=3月31日,上期同期为2月1–29日,2月29日样本计入。
        let report = MonthlyReportBuilder.build(
            performances: [perf(600, fixedDate(2024, 3, 10)), perf(300, fixedDate(2024, 2, 29))],
            expenses: [], todos: [], now: fixedDate(2024, 3, 31))
        XCTAssertEqual(report.revenueChangePercent ?? 0, 100, accuracy: 0.01)
        XCTAssertEqual(report.previousPeriodLabel, "2月1日–2月29日")
    }

    func testCrossYearSamePeriod() {
        // now=2026年1月15日,上期同期为2025年12月1–15日。
        let report = MonthlyReportBuilder.build(
            performances: [perf(800, fixedDate(2026, 1, 10)), perf(400, fixedDate(2025, 12, 10))],
            expenses: [], todos: [], now: fixedDate(2026, 1, 15))
        XCTAssertEqual(report.revenueChangePercent ?? 0, 100, accuracy: 0.01)
        XCTAssertEqual(report.previousPeriodLabel, "12月1日–12月15日")
    }

    func testZeroPrevPeriodShowsNoPercent() {
        let report = MonthlyReportBuilder.build(
            performances: [perf(500, fixedDate(2026, 6, 10))],
            expenses: [], todos: [], now: fixedDate(2026, 6, 15))
        XCTAssertNil(report.revenueChangePercent, "上期为零不得显示虚假增长百分比")
        XCTAssertEqual(report.revenue, 500, accuracy: 0.001, "收入本身不受对比修复影响")
        XCTAssertEqual(report.net, 500, accuracy: 0.001)
    }

    func testDisplayPercentsSumTo100() {
        let summaries = IncomeSourceSummary.compute(
            performances: [perf(100, fixedDate(2026, 6, 10), "", "门店"),
                           perf(100, fixedDate(2026, 6, 10), "", "美团"),
                           perf(100, fixedDate(2026, 6, 10), "", "其他")],
            range: (fixedDate(2026, 6, 1), fixedDate(2026, 6, 30)))
        XCTAssertEqual(IncomeSourceSummary.displayPercents(for: summaries).reduce(0, +), 100,
                       "三个 1/3 逐项四舍五入会得 99%,最大余数法必须补到 100%")
    }

    // MARK: - P0-2 对比度(WCAG AA 4.5:1)

    func testFixedHeroColorsMeetWCAGAA() {
        let gold = (r: 0.906, g: 0.788, b: 0.514)
        let ink = (r: 0.086, g: 0.137, b: 0.235)
        let darkCard = (r: 0.157, g: 0.184, b: 0.325)
        XCTAssertGreaterThanOrEqual(V39Palette.wcagContrast(gold, darkCard), 4.5,
                                    "固定香槟金在深蓝卡面上必须达 AA")
        XCTAssertGreaterThanOrEqual(V39Palette.wcagContrast(ink, gold), 4.5,
                                    "金底深色字(分享按钮)必须达 AA,旧白字仅约 1.6:1")
        // 回归锚点:旧分享按钮白字在金底上确实不及格,证明修法针对真实问题。
        XCTAssertLessThan(V39Palette.wcagContrast((r: 1, g: 1, b: 1), gold), 4.5)
    }

    // MARK: - P0-3 备份去重

    private func makeEmptyContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }

    private func sampleData() throws -> Data {
        let now = fixedDate(2026, 6, 10)
        let data = try BackupService.exportData(
            todos: [Todo(title: "进货", detail: "", dueDate: now, priority: 1, createdAt: now)],
            memos: [],
            performances: [Performance(amount: 680, note: "美团", date: now, incomeSource: "美团")],
            expenses: [Expense(amount: 20, category: "其他", note: "杂费", date: now, createdAt: now)],
            expiryItems: [], customers: [], goods: [], exportedAt: now)
        return data
    }

    @MainActor
    func testRestoreTwiceIsIdempotent() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let data = try sampleData()
        let first = try BackupService.restoreDetailed(context: ctx, from: data)
        XCTAssertEqual(first.inserted, 3)
        XCTAssertEqual(first.skipped, 0)
        let second = try BackupService.restoreDetailed(context: ctx, from: data)
        XCTAssertEqual(second.inserted, 0, "同一文件第二次恢复不得新增")
        XCTAssertEqual(second.skipped, 3)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Performance>()), 1, "营业额不得翻倍")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Todo>()), 1)
    }

    @MainActor
    func testOldBackupWithoutIDsStillDedups() throws {
        // 剥掉 v3 id,模拟 v1/v2 旧备份:现算指纹仍须去重。
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        var payload = try JSONSerialization.jsonObject(with: sampleData()) as! [String: Any]
        var records = payload["records"] as! [[String: Any]]
        records = records.map { var r = $0; r.removeValue(forKey: "id"); return r }
        payload["records"] = records
        let oldData = try JSONSerialization.data(withJSONObject: payload)
        let first = try BackupService.restoreDetailed(context: ctx, from: oldData)
        XCTAssertEqual(first.inserted, 3)
        let second = try BackupService.restoreDetailed(context: ctx, from: oldData)
        XCTAssertEqual(second.inserted, 0, "旧备份第二次恢复也不得重复")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Performance>()), 1)
    }

    @MainActor
    func testLegitSameAmountTransactionsAreKept() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let day = fixedDate(2026, 6, 10)
        let data = try BackupService.exportData(
            todos: [], memos: [],
            performances: [Performance(amount: 100, note: "午市", date: day, incomeSource: "门店"),
                           Performance(amount: 100, note: "晚市", date: day, incomeSource: "门店"),
                           Performance(amount: 100, note: "午市", date: fixedDate(2026, 6, 11), incomeSource: "门店")],
            expenses: [], expiryItems: [], customers: [], goods: [], exportedAt: day)
        let result = try BackupService.restoreDetailed(context: ctx, from: data)
        XCTAssertEqual(result.inserted, 3, "同额但备注/日期不同的合法交易不得被去重删除")
        let again = try BackupService.restoreDetailed(context: ctx, from: data)
        XCTAssertEqual(again.inserted, 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Performance>()), 3)
    }

    @MainActor
    func testDuplicateRecordsInsideOneFileInsertOnce() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        var payload = try JSONSerialization.jsonObject(with: sampleData()) as! [String: Any]
        var records = payload["records"] as! [[String: Any]]
        records.append(records[0])
        records.append(records[1])
        payload["records"] = records
        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = try BackupService.restoreDetailed(context: ctx, from: data)
        XCTAssertEqual(result.inserted, 3, "文件内重复记录只插一次")
        XCTAssertEqual(result.skipped, 2)
    }

    @MainActor
    func testPreviewCountsMatchRestore() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let data = try sampleData()
        let previewBefore = try BackupService.previewRestore(context: ctx, from: data)
        XCTAssertEqual(previewBefore.toInsert, 3)
        XCTAssertEqual(previewBefore.skipped, 0)
        _ = try BackupService.restoreDetailed(context: ctx, from: data)
        let previewAfter = try BackupService.previewRestore(context: ctx, from: data)
        XCTAssertEqual(previewAfter.toInsert, 0)
        XCTAssertEqual(previewAfter.skipped, 3)
    }

    @MainActor
    func testCorruptFileThrowsWithoutInserting() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        XCTAssertThrowsError(try BackupService.restoreDetailed(context: ctx, from: Data("not json".utf8)))
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Performance>()), 0, "非法文件不得落库")
        XCTAssertThrowsError(try BackupService.restoreDetailed(
            context: ctx, from: Data(#"{"app":"x"}"#.utf8)))
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Performance>()), 0)
    }

    @MainActor
    func testUnknownRecordTypeCountsAsFailedNotCrash() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        var payload = try JSONSerialization.jsonObject(with: sampleData()) as! [String: Any]
        var records = payload["records"] as! [[String: Any]]
        records.append(["type": "mystery", "title": "未知"])
        payload["records"] = records
        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = try BackupService.restoreDetailed(context: ctx, from: data)
        XCTAssertEqual(result.inserted, 3, "未知类型只计失败,不得中断其余记录")
        XCTAssertEqual(result.failed, 1)
    }
}
