import SwiftData
import XCTest
@testable import XiaoZhangGui

/// V3.8 重建 R4 · Performance 经营页业务口径保护测试。
///
/// 核心验收（Worker C 规格 §4 / G5）：
/// - **口径测试**：切换分类前后，总额 == 各分类之和；分类金额来自既有模型
///   `IncomeSourceSummary.compute`，重建不得改动收入分类与公式。
/// - **图表终态**：`PerformanceTrend` 图表点值与模型逐日合计一致。
/// - 动效 token：Reduce Motion 下为 nil（直接终态）。
final class V38PerformanceRebuildTests: XCTestCase {

    // MARK: - 样本数据（当月，混合来源，全部走既有分类规则）

    /// 门店 100（独立字段）+ 美团 50（独立字段）+ 其他 30（note 派生）
    /// + 美团 20（扫呗 paymentMethod 派生）= 总额 200。
    private func makeSamplePerformances(now: Date) -> [Performance] {
        [
            Performance(amount: 100, note: "门店消费", date: now, incomeSource: "门店"),
            Performance(amount: 50, note: "美团外卖", date: now, incomeSource: "美团"),
            Performance(amount: 30, note: "其他渠道", date: now, incomeSource: ""),
            Performance(amount: 20, note: "扫呗", date: now, paymentMethod: "美团", incomeSource: ""),
        ]
    }

    private var monthRange: (start: Date, end: Date) {
        (Date().startOfMonth, Date().endOfDay)
    }

    // MARK: - 口径测试：分类之和 == 总额（关键）

    func testCategoryAmountsSumToTotal() {
        let now = Date()
        let performances = makeSamplePerformances(now: now)
        let summaries = IncomeSourceSummary.compute(performances: performances, range: monthRange)

        let total = performances.reduce(0) { $0 + $1.amount }
        let categorySum = summaries.reduce(0) { $0 + $1.amount }

        XCTAssertEqual(total, 200, accuracy: 0.001, "样本总额应为 200")
        XCTAssertEqual(categorySum, total, accuracy: 0.001, "口径：各分类之和必须等于总额")

        let bySource = Dictionary(uniqueKeysWithValues: summaries.map { ($0.source, $0.amount) })
        XCTAssertEqual(bySource[.store] ?? -1, 100, accuracy: 0.001, "门店应为 100")
        XCTAssertEqual(bySource[.meituan] ?? -1, 70, accuracy: 0.001, "美团应为 50+20=70")
        XCTAssertEqual(bySource[.other] ?? -1, 30, accuracy: 0.001, "其他应为 30")

        let ratioSum = summaries.reduce(0) { $0 + $1.ratio }
        XCTAssertEqual(ratioSum, 1, accuracy: 0.001, "各分类占比之和必须为 1")
    }

    func testSourceSelectionSummaryPreservesTotals() {
        let now = Date()
        let performances = makeSamplePerformances(now: now)
        let summaries = IncomeSourceSummary.compute(performances: performances, range: monthRange)

        // 「全部」：金额 == 总额，且等于各分类手算之和。
        let all = V38SourceSummary.make(summaries: summaries, selection: .all)
        XCTAssertEqual(all.total, 200, accuracy: 0.001)
        XCTAssertEqual(all.amount, all.total, accuracy: 0.001, "全部口径：汇总金额必须等于总额")
        XCTAssertEqual(all.ratio, 1, accuracy: 0.001)

        // 逐个分类切换：金额必须等于该分类在模型汇总中的金额（不重算、不漂移）。
        for selection in [V38SourceSelection.store, .meituan, .other] {
            let picked = V38SourceSummary.make(summaries: summaries, selection: selection)
            let expected = summaries.first { $0.source == selection.source }?.amount ?? -1
            XCTAssertEqual(picked.amount, expected, accuracy: 0.001, "\(selection.title) 金额必须与模型汇总一致")
            XCTAssertEqual(picked.total, 200, accuracy: 0.001, "切换分类不得改变总额口径")
        }

        // 切换一圈后各分类金额再求和，仍等于「全部」金额（切换无损）。
        let roundTrip = [V38SourceSelection.store, .meituan, .other]
            .map { V38SourceSummary.make(summaries: summaries, selection: $0).amount }
            .reduce(0, +)
        XCTAssertEqual(roundTrip, all.amount, accuracy: 0.001, "口径：分类金额之和必须等于全部金额")
    }

    func testSourceSelectionEmptyDataIsZero() {
        let summaries = IncomeSourceSummary.compute(performances: [], range: monthRange)
        let picked = V38SourceSummary.make(summaries: summaries, selection: .all)
        XCTAssertEqual(picked.total, 0, accuracy: 0.001)
        XCTAssertEqual(picked.amount, 0, accuracy: 0.001)
        XCTAssertEqual(picked.ratio, 0, accuracy: 0.001, "无数据时占比为 0，不得出现 NaN")
    }

    // MARK: - 图表终态：趋势点值与模型一致

    func testTrendPointsMatchDailyModelTotals() {
        let now = Date()
        let cal = Calendar.current
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now
        let performances = [
            Performance(amount: 100, note: "今日", date: now, incomeSource: "门店"),
            Performance(amount: 50, note: "今日2", date: now, incomeSource: "美团"),
            Performance(amount: 70, note: "前日", date: twoDaysAgo, incomeSource: "门店"),
        ]

        let points = PerformanceTrend.last7Days(performances: performances, now: now)
        XCTAssertEqual(points.count, 7, "近7日趋势必须有 7 个点")
        XCTAssertEqual(points.last?.value ?? -1, 150, accuracy: 0.001, "今日终态值 = 当日记录合计")
        XCTAssertEqual(points[points.count - 3].value, 70, accuracy: 0.001, "两天前终态值 = 当日记录合计")
        XCTAssertEqual(
            points.reduce(0) { $0 + $1.value }, 220, accuracy: 0.001,
            "图表全部点值之和 = 区间内总营业额"
        )

        // 周期映射（V3.8 P1-B2 真实口径）：日 → 近7日逐日 7 点；
        // 周 → 近4周逐周 4 点（不再与日重复）；月 → 近30日 30 点。
        XCTAssertEqual(PerformanceTrend.points(for: .day, performances: performances, now: now).count, 7)
        XCTAssertEqual(PerformanceTrend.points(for: .week, performances: performances, now: now).count, 4)
        XCTAssertEqual(PerformanceTrend.points(for: .month, performances: performances, now: now).count, 30)
    }

    func testBarChartDomainIsStableNiceCeiling() {
        // 量程取 nice ceiling：680 → 1000；小幅变化（680→700）不改变量程，坐标轴不跳。
        let chartA = V38TrendBarChart(points: [TrendPoint(id: 0, label: "10/1", value: 680, date: Date())])
        let chartB = V38TrendBarChart(points: [TrendPoint(id: 0, label: "10/1", value: 700, date: Date())])
        XCTAssertEqual(chartA.domainMax, 1000, accuracy: 0.001)
        XCTAssertEqual(chartB.domainMax, 1000, accuracy: 0.001, "小幅数据变化不得改变量程")
        let empty = V38TrendBarChart(points: [])
        XCTAssertEqual(empty.domainMax, 100, accuracy: 0.001, "无数据时量程回退为 100")
    }

    // MARK: - 动效与样式 tokens

    func testMotionTokensReduceMotionYieldsStatic() {
        // 规格 §4：Reduce Motion 下图表/数字直接终态（animation = nil）。
        XCTAssertNil(V38MotionTokens.animation(for: .contentChange, reduceMotion: true))
        XCTAssertNil(V38MotionTokens.animation(for: .expand, reduceMotion: true))
        XCTAssertNotNil(V38MotionTokens.animation(for: .contentChange, reduceMotion: false))
        XCTAssertNotNil(V38MotionTokens.animation(for: .expand, reduceMotion: false))
    }

    func testHeroAmountFontTokenExists() {
        // 设计规范：本页最重点金额 54pt SF Rounded 等宽（V38PerformanceStyle.heroAmount）。
        XCTAssertNotNil(V38PerformanceStyle.heroAmount)
        XCTAssertNotNil(V38PerformanceStyle.summaryAmount)
    }

    // MARK: - SwiftData 端到端：真实容器中的分类口径

    @MainActor
    func testCategoryTotalsWithRealContainer() throws {
        let schema = Schema([Performance.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let now = Date()
        for performance in makeSamplePerformances(now: now) {
            context.insert(performance)
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Performance>())
        let summaries = IncomeSourceSummary.compute(performances: fetched, range: monthRange)
        let summary = V38SourceSummary.make(summaries: summaries, selection: .all)
        XCTAssertEqual(summary.amount, 200, accuracy: 0.001, "真实容器口径：总额 200")
        XCTAssertEqual(
            summaries.reduce(0) { $0 + $1.amount }, summary.total, accuracy: 0.001,
            "真实容器口径：分类之和 == 总额"
        )
    }
}
