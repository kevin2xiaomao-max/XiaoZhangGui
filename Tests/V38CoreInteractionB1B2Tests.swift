import XCTest
import SwiftUI
@testable import XiaoZhangGui

/// V3.8 PR-B：核心交互与图表口径真实业务测试。
///
/// 覆盖：
/// - B1 周密度 ghost 行「二次沉降」纯函数（锚点过渡期不变、沉降后收起）；
/// - B2 周口径真实化（近4周逐周汇总、周边界归属、空数据）；
/// - B2 图表点按取消选中策略（绘图区内外、重复点按、切换）；
/// - B1 日历页两段式勾选复用的源码回归钉（真实状态机已由
///   V38TodoRebuildTests / V38MotionCoreTests 覆盖，此处只钉复用事实）。
final class V38CoreInteractionB1B2Tests: XCTestCase {

    // MARK: - B1 · ghost 行沉降（V38ScheduleLayout.settledPresentation）

    private func makeWeekRows(selectedRow: Int, now: Date = Date()) -> [V38ScheduleLayout.WeekRow] {
        var cal = Calendar.current
        cal.firstWeekday = 1
        // 构造一个选中行落在第 5 周的月份（2026-08：31 天、8/1 起始周六 → 6 行网格，
        // 选中 8/31 位于最后一行），覆盖「月末第 5 周」的真实空白场景。
        let aug2026 = cal.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        return V38ScheduleLayout.rows(
            month: aug2026.startOfMonth,
            calendar: cal,
            selectedDate: aug2026,
            density: .week
        )
    }

    func testGhostRowsKeepHeightBeforeSettle() {
        let rows = makeWeekRows(selectedRow: 5)
        XCTAssertTrue(rows.contains { $0.presentation == .ghost }, "构造前提：选中行上方必须存在 ghost 行")
        // 沉降前（锚点过渡期间）：ghost 保持 ghost —— 选中格像素位置不变量不受影响。
        for row in rows where row.presentation == .ghost {
            XCTAssertEqual(
                V38ScheduleLayout.settledPresentation(for: row, density: .week, weekSettled: false),
                .ghost
            )
        }
    }

    func testGhostRowsCollapseAfterSettle() {
        let rows = makeWeekRows(selectedRow: 5)
        // 沉降后：ghost → collapsed，稳态空白消失。
        for row in rows where row.presentation == .ghost {
            XCTAssertEqual(
                V38ScheduleLayout.settledPresentation(for: row, density: .week, weekSettled: true),
                .collapsed
            )
        }
    }

    func testSelectedAndBelowRowsUnaffectedBySettle() {
        let rows = makeWeekRows(selectedRow: 5)
        for row in rows where row.presentation != .ghost {
            XCTAssertEqual(
                V38ScheduleLayout.settledPresentation(for: row, density: .week, weekSettled: true),
                row.presentation,
                "选中行（full）与下方（collapsed）不受沉降影响"
            )
        }
    }

    func testMonthDensityNeverSettlesAway() {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let aug2026 = cal.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let rows = V38ScheduleLayout.rows(
            month: aug2026.startOfMonth, calendar: cal, selectedDate: aug2026, density: .month
        )
        XCTAssertTrue(rows.allSatisfy { $0.presentation == .full }, "月密度下全部行 full")
        for row in rows {
            XCTAssertEqual(
                V38ScheduleLayout.settledPresentation(for: row, density: .month, weekSettled: true),
                .full,
                "月密度不受沉降逻辑影响"
            )
        }
    }

    // MARK: - B2 · 周口径真实化（PerformanceTrend.last4Weeks）

    private func mondayStartCalendar() -> Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }

    func testLast4WeeksBucketsByNaturalWeek() throws {
        let cal = mondayStartCalendar()
        // 固定时区构造：2026-10-21 是周三，所在周为 10-19（周一）~ 10-25（周日）。
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12)))
        let thisMonday = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 0)))
        let lastTuesday = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 9)))
        let threeWeeksAgoFriday = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 15)))

        let performances = [
            Performance(amount: 100, note: "本周", date: thisMonday, incomeSource: "门店"),
            Performance(amount: 50, note: "本周二", date: now, incomeSource: "美团"),
            Performance(amount: 70, note: "上周", date: lastTuesday, incomeSource: "门店"),
            Performance(amount: 30, note: "前三周", date: threeWeeksAgoFriday, incomeSource: "其他"),
        ]

        let points = PerformanceTrend.last4Weeks(performances: performances, now: now)
        XCTAssertEqual(points.count, 4, "近4周必须有 4 个点")
        XCTAssertEqual(points.map(\.label), ["前3周", "上周", "前2周", "本周"], "按时间升序：前3周 → 本周")
        XCTAssertEqual(points.last?.value ?? -1, 150, accuracy: 0.001, "本周 = 周一 100 + 周三 50")
        XCTAssertEqual(points[2].value, 70, accuracy: 0.001, "上周 = 70")
        XCTAssertEqual(points[0].value, 30, accuracy: 0.001, "前3周 = 30")
        XCTAssertEqual(points[1].value, 0, accuracy: 0.001, "前2周无记录 = 0")
        XCTAssertEqual(points.reduce(0) { $0 + $1.value }, 250, accuracy: 0.001, "周点值之和 = 区间内总营业额")
    }

    func testLast4WeeksWeekBoundaryAttribution() throws {
        let cal = mondayStartCalendar()
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12)))
        // 边界 1：本周周一 00:00 整，属本周。
        let mondayZero = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 0, minute: 0)))
        // 边界 2：本周周日 23:59:59，仍属本周（自然周含尾日全天）。
        let sundayEnd = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 59, second: 59)))
        // 边界 3：上周周日 23:59，属上周而非本周。
        let lastSundayEnd = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 23, minute: 59)))

        let performances = [
            Performance(amount: 10, note: "周一零点", date: mondayZero, incomeSource: "门店"),
            Performance(amount: 20, note: "周日尾", date: sundayEnd, incomeSource: "门店"),
            Performance(amount: 40, note: "上周日尾", date: lastSundayEnd, incomeSource: "门店"),
        ]
        let points = PerformanceTrend.last4Weeks(performances: performances, now: now)
        XCTAssertEqual(points.last?.value ?? -1, 30, accuracy: 0.001, "周一00:00 与 周日23:59 同属本周")
        XCTAssertEqual(points[2].value, 40, accuracy: 0.001, "上周日 23:59 属上周")
    }

    func testLast4WeeksEmptyDataYieldsFourZeroPoints() {
        let points = PerformanceTrend.last4Weeks(performances: [], now: Date())
        XCTAssertEqual(points.count, 4)
        XCTAssertTrue(points.allSatisfy { $0.value == 0 }, "无记录时 4 个零点，图表仍有稳定形态")
    }

    func testPeriodTotalLabelsMatchRealBasis() {
        // 合计行文案与真实口径一一对应（周 ≠ 近7日）。
        XCTAssertEqual(PerformanceChartPeriod.day.trendTotalLabel, "近7日合计")
        XCTAssertEqual(PerformanceChartPeriod.week.trendTotalLabel, "近4周合计")
        XCTAssertEqual(PerformanceChartPeriod.month.trendTotalLabel, "近30日合计")
    }

    // MARK: - B2 · 图表点按取消选中策略

    func testTapOutsidePlotDeselects() {
        let plot = CGRect(x: 10, y: 0, width: 300, height: 100)
        // 四周留白 / 轴区的典型落点都视为绘图区外。
        XCTAssertFalse(V38ChartSelectionTapPolicy.isInsidePlot(x: 5, y: 50, plotRect: plot), "左侧留白")
        XCTAssertFalse(V38ChartSelectionTapPolicy.isInsidePlot(x: 320, y: 50, plotRect: plot), "右侧轴区")
        XCTAssertFalse(V38ChartSelectionTapPolicy.isInsidePlot(x: 150, y: -5, plotRect: plot), "上缘外")
        XCTAssertFalse(V38ChartSelectionTapPolicy.isInsidePlot(x: 150, y: 105, plotRect: plot), "下缘外")
        // 边界含端点。
        XCTAssertTrue(V38ChartSelectionTapPolicy.isInsidePlot(x: 10, y: 0, plotRect: plot))
        XCTAssertTrue(V38ChartSelectionTapPolicy.isInsidePlot(x: 310, y: 100, plotRect: plot))
    }

    func testTappingSelectedBarDeselects() {
        XCTAssertNil(
            V38ChartSelectionTapPolicy.selectedLabel(afterTapOn: "10/21", current: "10/21"),
            "再次点中已选柱 → 取消选中"
        )
    }

    func testTappingOtherBarSwitchesSelection() {
        XCTAssertEqual(
            V38ChartSelectionTapPolicy.selectedLabel(afterTapOn: "10/22", current: "10/21"),
            "10/22"
        )
        XCTAssertNil(
            V38ChartSelectionTapPolicy.selectedLabel(afterTapOn: nil, current: nil),
            "未命中柱且无选中 → 维持无选中"
        )
        XCTAssertEqual(
            V38ChartSelectionTapPolicy.selectedLabel(afterTapOn: nil, current: "10/21"),
            "10/21",
            "未命中柱但有选中 → 维持原选中（由外层区域判断负责取消）"
        )
    }

    // MARK: - B1 · 日历页复用两段式 + 新建入口（源码回归钉）

    func testScheduleViewReusesTwoStageToggleAndHasPlusEntry() throws {
        let source = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        XCTAssertTrue(
            source.contains("V38TodoToggleFlow.begin(from:)") && source.contains("V38TodoToggleFlow.resolve"),
            "日历页勾选必须复用 V38TodoToggleFlow 两段式状态机（G5：持久化前不宣告成功）"
        )
        XCTAssertFalse(
            source.contains("try TodoRepository(context: modelContext).toggleComplete(todo)\n        } catch {\n            Haptic.error()"),
            "日历页不得回退为无保存中相位的单段式直写"
        )
        XCTAssertTrue(
            source.contains("TodoEditorSheet(todo: nil, initialDate: selectedDate)"),
            "日历页「+」必须带入当前选中日期预填（P1-B1 回归钉）"
        )
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
