import XCTest
@testable import XiaoZhangGui

/// V3.8.1 真机纠偏 · 线 B（Performance 图表）回归测试。
///
/// - **P0-3**：月趋势 X 轴日期标签重叠 —— 断言轴标签按策略抽稀
///   （月 ≤6 个、含首尾、顺序一致），且**数据点一个不少**
///   （30 天仍是 30 个点，柱形数据零删减）；周视图 7 个日期标签完整保留。
/// - **P1-7**：选中读数按标签查找真实数据点（同一模型数据，无第二来源）。
final class V38PerformanceChartCorrectionTests: XCTestCase {

    /// 构造 n 个连续日期点（标签 "9/25"…"10/24" 风格，与 TrendPoint 同形）。
    private func makePoints(_ count: Int) -> [TrendPoint] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(count - 1), to: Date().startOfDay) ?? Date()
        return (0..<count).map { i in
            let date = cal.date(byAdding: .day, value: i, to: start) ?? start
            let c = cal.dateComponents([.month, .day], from: date)
            return TrendPoint(
                id: i,
                label: "\(c.month ?? 0)/\(c.day ?? 0)",
                value: Double((i + 1) * 10),
                date: date
            )
        }
    }

    // MARK: - P0-3：月视图标签抽稀，数据点零删减

    func testMonthAxisLabelsThinnedWhileAllDataPointsKept() {
        let points = makePoints(30)
        let chart = V38TrendBarChart(points: points)

        XCTAssertEqual(chart.points.count, 30, "红线：月视图数据点必须仍是 30 个，一天不能少")
        XCTAssertLessThanOrEqual(
            chart.axisLabelValues.count, V38AxisLabelPolicy.maxAxisLabels,
            "月视图轴标签必须抽稀到 ≤\(V38AxisLabelPolicy.maxAxisLabels) 个，实际 \(chart.axisLabelValues.count)"
        )
        XCTAssertGreaterThanOrEqual(chart.axisLabelValues.count, 2, "至少保留首尾标签")
        XCTAssertEqual(chart.axisLabelValues.first, points.first?.label, "必须含首日标签")
        XCTAssertEqual(chart.axisLabelValues.last, points.last?.label, "必须含末日（今日）标签")

        // 标签必须是数据点标签的有序子集（不编造日期、不乱序）。
        let indices = chart.axisLabelValues.compactMap { label in
            points.firstIndex { $0.label == label }
        }
        XCTAssertEqual(
            indices.count, chart.axisLabelValues.count,
            "每个轴标签都必须来自真实数据点"
        )
        XCTAssertEqual(indices, indices.sorted(), "轴标签顺序必须与日期顺序一致")
        XCTAssertEqual(Set(indices).count, indices.count, "轴标签不得重复")
    }

    func testMonthTrendModelStillProducesThirtyPoints() {
        // 数据层回归（防抽稀误伤数据）：模型口径不变，月 = 30 点。
        let now = Date()
        XCTAssertEqual(PerformanceTrend.last30Days(performances: [], now: now).count, 30)
        XCTAssertEqual(PerformanceTrend.points(for: .month, performances: [], now: now).count, 30)
    }

    // MARK: - P0-3：周/日视图标签完整保留

    func testWeekAxisLabelsKeepAllSevenDates() {
        let points = makePoints(7)
        let chart = V38TrendBarChart(points: points)
        XCTAssertEqual(chart.points.count, 7)
        XCTAssertEqual(
            chart.axisLabelValues, points.map(\.label),
            "周视图 7 个日期标签必须完整保留，不得抽稀"
        )
    }

    func testAxisLabelPolicyBoundaries() {
        XCTAssertEqual(V38AxisLabelPolicy.labeledIndices(pointCount: 0), [])
        XCTAssertEqual(V38AxisLabelPolicy.labeledIndices(pointCount: 1), [0])
        XCTAssertEqual(V38AxisLabelPolicy.labeledIndices(pointCount: 2), [0, 1])
        XCTAssertEqual(
            V38AxisLabelPolicy.labeledIndices(pointCount: V38AxisLabelPolicy.maxAxisLabels),
            Array(0..<V38AxisLabelPolicy.maxAxisLabels),
            "点数等于上限时全部显示"
        )
        let month = V38AxisLabelPolicy.labeledIndices(pointCount: 30)
        XCTAssertEqual(month.count, V38AxisLabelPolicy.maxAxisLabels)
        XCTAssertEqual(month.first, 0)
        XCTAssertEqual(month.last, 29)
        XCTAssertEqual(month, month.sorted())
        XCTAssertEqual(Set(month).count, month.count)
        // 大于 30 的点数同样受上限约束（策略与具体周期解耦）。
        let larger = V38AxisLabelPolicy.labeledIndices(pointCount: 90)
        XCTAssertLessThanOrEqual(larger.count, V38AxisLabelPolicy.maxAxisLabels)
        XCTAssertEqual(larger.last, 89)
    }

    // MARK: - P1-7：选中读数查找真实数据点

    func testSelectionLookupReturnsRealPoint() {
        let points = makePoints(7)
        let chart = V38TrendBarChart(points: points)

        let target = points[3]
        let found = chart.point(forLabel: target.label)
        XCTAssertEqual(found?.label, target.label)
        XCTAssertEqual(found?.value ?? -1, target.value, accuracy: 0.001, "选中金额必须等于模型点值")
        XCTAssertEqual(found?.date, target.date)

        XCTAssertNil(chart.point(forLabel: nil), "无选中时不得凭空给出数据点")
        XCTAssertNil(chart.point(forLabel: "1/1"), "不存在的日期不得命中任何数据点")
    }

    func testSelectionLookupOnMonthData() {
        // 月视图抽稀后，未显示标签的日期仍是真实数据点，选中查找照常命中。
        let points = makePoints(30)
        let chart = V38TrendBarChart(points: points)
        let hiddenLabelPoint = points[7]
        XCTAssertFalse(chart.axisLabelValues.contains(hiddenLabelPoint.label), "下标 7 的标签应已被抽稀")
        XCTAssertEqual(
            chart.point(forLabel: hiddenLabelPoint.label)?.value ?? -1,
            hiddenLabelPoint.value, accuracy: 0.001,
            "标签抽稀不得影响数据点本身的选中读取"
        )
    }
}
