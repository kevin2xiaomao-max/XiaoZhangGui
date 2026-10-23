import Foundation

/// V3.8 重建 R3 · 日历密度（月/周）。
///
/// 只描述网格的展示密度，不携带任何业务语义：周密度展示的仍是同一月历
/// 网格中选中日期所在的那一周真实日期，不生成、不推测任何周数据。
enum V38ScheduleDensity: String, CaseIterable, Equatable {
    case month
    case week
}

/// V3.8 重建 R3 · 月历网格布局（纯逻辑，无 SwiftUI 依赖，可单元测试）。
///
/// 对应 `Docs/V38-Page-Motion-Spec.md` §3 的锚点模型：
/// - 日期格子 = 几何锚点。选中日期在网格中的 (row, col) 在月/周两种密度
///   下完全一致，选中格的像素位置不因密度切换而漂移。
/// - 周密度下：选中行保持完整展示；选中行**上方**的行保留高度但内容
///   淡出（ghost，保证选中格 Y 坐标不变）；选中行**下方**的行高度收起
///   （collapsed，使下方详情/摘要上移，容器行高发生过渡）。
/// - 网格日期算法与 V3.7.1 `ScheduleView.gridDates` 逐格一致（周日起始、
///   首尾 nil 补位、总格数为 7 的倍数），仅搬移为可测纯函数，口径不变。
enum V38ScheduleLayout {

    /// 一周行（7 格）的展示形态。
    enum RowPresentation: Equatable {
        /// 完整展示（月密度的全部行 + 周密度的选中行）。
        case full
        /// 保留高度、内容隐藏（周密度下选中行之上的行）。
        case ghost
        /// 高度收起（周密度下选中行之下的行）。
        case collapsed
    }

    struct WeekRow: Equatable {
        let index: Int
        /// 恰好 7 格（月外日期为 nil 占位，与 V3.7.1 网格一致）。
        let cells: [Date?]
        let presentation: RowPresentation
        let containsSelectedDate: Bool
    }

    /// 月历网格日期（首尾补 nil 空位，总格数为 7 的倍数）。
    /// 与 V3.7.1 `ScheduleView.gridDates(for:)` 同一算法。
    static func gridDates(month: Date, calendar: Calendar) -> [Date?] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1 // 0 = 周日
        let totalCells = Int(ceil(Double(firstWeekday + daysInMonth) / 7.0)) * 7

        var cells: [Date?] = Array(repeating: nil, count: totalCells)
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells[firstWeekday + day - 1] = date
            }
        }
        return cells
    }

    /// 选中日期在网格中的格子下标（不在网格内时为 nil）。
    static func selectedCellIndex(grid: [Date?], selectedDate: Date, calendar: Calendar) -> Int? {
        grid.firstIndex { cell in
            guard let cell else { return false }
            return calendar.isDate(cell, inSameDayAs: selectedDate)
        }
    }

    /// 全部周行及其在当前密度下的展示形态。
    static func rows(month: Date, calendar: Calendar, selectedDate: Date, density: V38ScheduleDensity) -> [WeekRow] {
        let grid = gridDates(month: month, calendar: calendar)
        let selectedIndex = selectedCellIndex(grid: grid, selectedDate: selectedDate, calendar: calendar)
        let selectedRow = selectedIndex.map { $0 / 7 }

        return stride(from: 0, to: grid.count, by: 7).map { start in
            let rowIndex = start / 7
            let presentation: RowPresentation
            switch density {
            case .month:
                presentation = .full
            case .week:
                if let selectedRow {
                    if rowIndex < selectedRow {
                        presentation = .ghost
                    } else if rowIndex > selectedRow {
                        presentation = .collapsed
                    } else {
                        presentation = .full
                    }
                } else {
                    // 选中日期不在本月网格：不收起任何行（防御性回退）
                    presentation = .full
                }
            }
            return WeekRow(
                index: rowIndex,
                cells: Array(grid[start..<min(start + 7, grid.count)]),
                presentation: presentation,
                containsSelectedDate: selectedRow == rowIndex
            )
        }
    }

    /// 选中日期在周密度下可见的那一行（即包含选中日期的周行）。
    /// 周密度不构造新的一周，只从月网格中取既有行 —— 无假造数据。
    static func weekRowContainingSelectedDate(month: Date, calendar: Calendar, selectedDate: Date) -> WeekRow? {
        rows(month: month, calendar: calendar, selectedDate: selectedDate, density: .week)
            .first { $0.containsSelectedDate }
    }

    /// V3.8 P1-B1：ghost 行「二次沉降」的最终展示形态（纯函数，可单测）。
    ///
    /// 锚点过渡期间 ghost 行保留高度（保证选中格像素位置不变）；
    /// 过渡完成（`weekSettled == true`）后 ghost 行按 collapsed 收起，
    /// 消除周密度稳态下选中行上方的大片透明空白。
    /// 月密度不受影响（本来全为 full）。
    static func settledPresentation(for row: WeekRow, density: V38ScheduleDensity, weekSettled: Bool) -> RowPresentation {
        guard density == .week, weekSettled, row.presentation == .ghost else { return row.presentation }
        return .collapsed
    }
}
