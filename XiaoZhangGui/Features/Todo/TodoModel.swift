import Foundation

// MARK: - 待办派生数据（语义对齐 Android TodoViewModel.todosForTab）

enum TodoTab: String, CaseIterable, Identifiable, Hashable {
    case today = "今天"
    case tomorrow = "明天"
    case overdue = "逾期"
    case done = "已完成"
    case records = "备忘"

    var id: String { rawValue }
}

enum TodoFilter {
    /// 按 Tab 过滤并按时间排序
    static func todos(for tab: TodoTab, in all: [Todo], now: Date = Date()) -> [Todo] {
        let cal = Calendar.current
        let todayStart = now.startOfDay
        let todayEnd = now.endOfDay
        let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let tomorrowEnd = tomorrowStart.endOfDay

        switch tab {
        case .today:
            return all
                .filter { !$0.isCompleted && ($0.dueDate == nil || ($0.dueDate! >= todayStart && $0.dueDate! <= todayEnd)) }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .tomorrow:
            return all
                .filter { !$0.isCompleted && $0.dueDate != nil && $0.dueDate! >= tomorrowStart && $0.dueDate! <= tomorrowEnd }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .overdue:
            return all
                .filter { !$0.isCompleted && $0.dueDate != nil && $0.dueDate! < todayStart }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .done:
            return all
                .filter { $0.isCompleted }
                .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        case .records:
            return []
        }
    }

    /// 时间轴分组：上午 / 下午 / 晚上 / 待安排（对齐 Android 分组逻辑）
    static func grouped(_ todos: [Todo]) -> [(label: String, items: [Todo])] {
        var morning: [Todo] = []
        var afternoon: [Todo] = []
        var evening: [Todo] = []
        var unscheduled: [Todo] = []
        for todo in todos {
            guard let due = todo.dueDate else {
                unscheduled.append(todo)
                continue
            }
            switch due.dayPeriod {
            case .morning: morning.append(todo)
            case .afternoon: afternoon.append(todo)
            case .evening: evening.append(todo)
            }
        }
        var groups: [(String, [Todo])] = []
        if !morning.isEmpty { groups.append(("上午", morning)) }
        if !afternoon.isEmpty { groups.append(("下午", afternoon)) }
        if !evening.isEmpty { groups.append(("晚上", evening)) }
        if !unscheduled.isEmpty { groups.append(("待安排", unscheduled)) }
        return groups
    }

    static func emptyText(for tab: TodoTab) -> String {
        switch tab {
        case .today: return "今天没有待办，去休息一下吧"
        case .tomorrow: return "明天暂无待办"
        case .overdue: return "没有逾期事项，真棒"
        case .done: return "还没有已完成的任务"
        case .records: return "暂无备忘"
        }
    }
}
