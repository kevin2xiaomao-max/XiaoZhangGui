import XCTest
@testable import XiaoZhangGui

/// V3.8 重建 R3 · 日历锚点布局保护测试。
///
/// 验证 `V38ScheduleLayout`（Spec §3 锚点模型的纯逻辑层）：
/// - 网格日期算法与 V3.7.1 `gridDates` 逐格一致（周日起始、nil 补位）
/// - 月密度下全部行完整展示
/// - 周密度下：选中行完整、上方行 ghost（保留高度）、下方行 collapsed
/// - **锚点不变量**：任意日期在两种密度下 (row, col) 完全一致，
///   密度切换 20 次后选中格位置与选中日期均不漂移
final class V38ScheduleRebuildTests: XCTestCase {

    /// 与生产 `ScheduleView.monthCalendar` 一致：周日起始。
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - 网格算法与 V3.7.1 一致

    func testGridDatesOctober2026Shape() {
        // 2026-10-01 为周四（周日起始偏移 4），31 天 → 35 格 = 5 行。
        let grid = V38ScheduleLayout.gridDates(month: date(2026, 10, 1), calendar: calendar)
        XCTAssertEqual(grid.count, 35)
        XCTAssertEqual(grid.count % 7, 0)
        for i in 0..<4 { XCTAssertNil(grid[i], "月初补位应为 nil") }
        XCTAssertEqual(grid[4], date(2026, 10, 1))
        XCTAssertEqual(grid[25], date(2026, 10, 22))
        XCTAssertEqual(grid[34], date(2026, 10, 31))
    }

    func testGridDatesFebruaryLeapYear() {
        // 2028-02-01 为周二（偏移 2），闰年 29 天 → 2+29=31 → 35 格。
        let grid = V38ScheduleLayout.gridDates(month: date(2028, 2, 1), calendar: calendar)
        XCTAssertEqual(grid.count, 35)
        XCTAssertNil(grid[0]); XCTAssertNil(grid[1])
        XCTAssertEqual(grid[2], date(2028, 2, 1))
        XCTAssertEqual(grid[30], date(2028, 2, 29))
        XCTAssertNil(grid[31])
    }

    func testGridDatesMonthStartingOnSunday() {
        // 2026-11-01 为周日（偏移 0），30 天 → 35 格。
        let grid = V38ScheduleLayout.gridDates(month: date(2026, 11, 1), calendar: calendar)
        XCTAssertEqual(grid[0], date(2026, 11, 1))
        XCTAssertEqual(grid[29], date(2026, 11, 30))
        XCTAssertEqual(grid.count, 35)
    }

    // MARK: - 月密度：全部行完整

    func testMonthDensityAllRowsFull() {
        let rows = V38ScheduleLayout.rows(
            month: date(2026, 10, 1), calendar: calendar,
            selectedDate: date(2026, 10, 22), density: .month
        )
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(rows.allSatisfy { $0.presentation == .full })
        XCTAssertEqual(rows.filter { $0.containsSelectedDate }.count, 1)
        XCTAssertEqual(rows[3].cells[4], date(2026, 10, 22))
    }

    // MARK: - 周密度：ghost / full / collapsed 分布

    func testWeekDensityPresentations() {
        // 选中 10-22（row 3）：rows 0–2 ghost、row 3 full、row 4 collapsed。
        let rows = V38ScheduleLayout.rows(
            month: date(2026, 10, 1), calendar: calendar,
            selectedDate: date(2026, 10, 22), density: .week
        )
        XCTAssertEqual(rows.map(\.presentation), [.ghost, .ghost, .ghost, .full, .collapsed])
        XCTAssertTrue(rows[3].containsSelectedDate)
        // 周行展示的仍是月网格既有日期（同一批 Date，无构造数据）
        XCTAssertEqual(rows[3].cells, Array(
            V38ScheduleLayout.gridDates(month: date(2026, 10, 1), calendar: calendar)[21..<28]
        ))
    }

    func testWeekDensitySelectedInFirstRow() {
        // 选中 10-01（row 0）：无 ghost 行，其余全部 collapsed。
        let rows = V38ScheduleLayout.rows(
            month: date(2026, 10, 1), calendar: calendar,
            selectedDate: date(2026, 10, 1), density: .week
        )
        XCTAssertEqual(rows.map(\.presentation), [.full, .collapsed, .collapsed, .collapsed, .collapsed])
    }

    func testWeekDensitySelectedInLastRow() {
        // 选中 10-31（row 4）：上方全部 ghost，无 collapsed 行。
        let rows = V38ScheduleLayout.rows(
            month: date(2026, 10, 1), calendar: calendar,
            selectedDate: date(2026, 10, 31), density: .week
        )
        XCTAssertEqual(rows.map(\.presentation), [.ghost, .ghost, .ghost, .ghost, .full])
    }

    func testWeekDensitySelectedOutsideGridFallsBackToFull() {
        // 选中日期不在展示月份（如月导航后）：防御性回退为全部完整展示。
        let rows = V38ScheduleLayout.rows(
            month: date(2026, 11, 1), calendar: calendar,
            selectedDate: date(2026, 10, 22), density: .week
        )
        XCTAssertTrue(rows.allSatisfy { $0.presentation == .full })
        XCTAssertTrue(rows.allSatisfy { !$0.containsSelectedDate })
    }

    // MARK: - 锚点不变量（核心）

    func testAnchorInvariantForEveryDayOfMonth() {
        // 任意一天被选中时，其格子下标在月/周密度下必须完全一致；
        // 这是 UI 层「选中格像素位置不变」的布局级保证。
        let grid = V38ScheduleLayout.gridDates(month: date(2026, 10, 1), calendar: calendar)
        for day in 1...31 {
            let selected = date(2026, 10, day)
            let monthRows = V38ScheduleLayout.rows(month: date(2026, 10, 1), calendar: calendar, selectedDate: selected, density: .month)
            let weekRows = V38ScheduleLayout.rows(month: date(2026, 10, 1), calendar: calendar, selectedDate: selected, density: .week)

            let monthIndex = V38ScheduleLayout.selectedCellIndex(grid: grid, selectedDate: selected, calendar: calendar)
            XCTAssertNotNil(monthIndex)
            guard let idx = monthIndex else { continue }
            // 两种密度下，同一 (row, col) 处的日期相同且为选中日期
            XCTAssertEqual(monthRows[idx / 7].cells[idx % 7], selected, "月密度下选中格漂移（\(day) 日）")
            XCTAssertEqual(weekRows[idx / 7].cells[idx % 7], selected, "周密度下选中格漂移（\(day) 日）")
            // 周密度下选中行必须完整展示
            XCTAssertEqual(weekRows[idx / 7].presentation, .full, "周密度下选中行未完整展示（\(day) 日）")
            XCTAssertTrue(weekRows[idx / 7].containsSelectedDate)
        }
    }

    func testAnchorInvariantAfter20DensityToggles() {
        // 模拟 20 次密度切换：布局函数为纯函数，切换不改变选中格位置。
        let selected = date(2026, 10, 22)
        let grid = V38ScheduleLayout.gridDates(month: date(2026, 10, 1), calendar: calendar)
        let expectedIndex = V38ScheduleLayout.selectedCellIndex(grid: grid, selectedDate: selected, calendar: calendar)
        XCTAssertEqual(expectedIndex, 25) // row 3, col 4

        var density: V38ScheduleDensity = .month
        for _ in 1...20 {
            density = density == .month ? .week : .month
            let rows = V38ScheduleLayout.rows(month: date(2026, 10, 1), calendar: calendar, selectedDate: selected, density: density)
            let row = rows[25 / 7]
            XCTAssertEqual(row.cells[25 % 7], selected, "第 \(density) 密度下选中日期漂移")
            if density == .week {
                XCTAssertEqual(row.presentation, .full)
            }
        }
    }

    func testWeekRowContainingSelectedDate() {
        let row = V38ScheduleLayout.weekRowContainingSelectedDate(
            month: date(2026, 10, 1), calendar: calendar, selectedDate: date(2026, 10, 22)
        )
        XCTAssertEqual(row?.index, 3)
        XCTAssertEqual(row?.cells.first ?? nil, date(2026, 10, 18)) // 该周周日为 10-18
        XCTAssertEqual(row?.cells.last ?? nil, date(2026, 10, 24))
    }
}
