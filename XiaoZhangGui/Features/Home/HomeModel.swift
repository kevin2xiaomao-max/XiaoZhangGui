import Foundation

// MARK: - 首页派生数据（对齐 Android HomeViewModel 计算逻辑）

struct HomeStats {
    /// 今日营业额（当天记录求和）
    let todayRevenue: Double
    /// 今日待办：未完成 且（无截止 或 截止在今天）
    let todayTodos: [Todo]
    /// 紧急临期：7 天内到期且待处理
    let urgentExpiryCount: Int
    /// 今日目标完成度百分比（按月目标 / 30 折算日均）
    let goalProgressPercent: Int

    static func compute(
        todos: [Todo],
        performances: [Performance],
        expiryItems: [ExpiryItem],
        monthGoal: Double,
        now: Date = Date()
    ) -> HomeStats {
        let todayRevenue = performances
            .filter { $0.date.isToday }
            .reduce(0) { $0 + $1.amount }

        let todayTodos = todos
            .filter { !$0.isCompleted && ($0.dueDate == nil || $0.dueDate?.isToday == true) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        let urgentExpiry = expiryItems
            .filter { item in
                item.status == .pending
                    && item.daysLeft(from: now) >= 0
                    && item.daysLeft(from: now) <= 7
            }
            .count

        let dailyGoal = monthGoal / 30
        let progress = dailyGoal > 0 ? Int(todayRevenue / dailyGoal * 100) : 0

        return HomeStats(
            todayRevenue: todayRevenue,
            todayTodos: todayTodos,
            urgentExpiryCount: urgentExpiry,
            goalProgressPercent: progress
        )
    }
}
