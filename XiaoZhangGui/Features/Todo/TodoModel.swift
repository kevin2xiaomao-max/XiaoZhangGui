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

/// V3.9.1 P1-7 · 待办计数单次遍历(与 TodoFilter 各 Tab 谓词逐项一致)。
struct TodoCounts {
    let today: Int
    let done: Int
    let overdue: Int
    let pendingTotal: Int

    static func build(todos: [Todo], now: Date = Date()) -> TodoCounts {
        let todayStart = now.startOfDay
        let todayEnd = now.endOfDay
        var today = 0, done = 0, overdue = 0, pendingTotal = 0
        for todo in todos {
            if todo.isCompleted { done += 1; continue }
            pendingTotal += 1
            if todo.dueDate == nil || (todo.dueDate! >= todayStart && todo.dueDate! <= todayEnd) {
                today += 1
            }
            if let due = todo.dueDate, due < todayStart { overdue += 1 }
        }
        return TodoCounts(today: today, done: done, overdue: overdue, pendingTotal: pendingTotal)
    }
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

    /// V3.8 PR-D C1：空态副文案按 tab 语义区分（原先所有 tab 共用同一句，
    /// 在「已完成」等 tab 语义错位）。口径与 EmptyState 组件一致：一句行动指引。
    static func emptyMessage(for tab: TodoTab) -> String {
        switch tab {
        case .today: return "点右上角 + 安排今天的事"
        case .tomorrow: return "提前安排，明天更从容"
        case .overdue: return "继续保持，安排好截止时间就不怕逾期"
        case .done: return "完成的事项会留档在这里"
        case .records: return "记下的备忘会出现在这里"
        }
    }
}
