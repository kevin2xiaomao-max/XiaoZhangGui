import Foundation

// MARK: - V3.9.1 P1-7 · 首页单次聚合
//
// 旧 HomeView 每次 body 求值时对 performances/todos 做 20+ 次全量 filter:
// TodaySummary(今日/昨日/今日待办/配送/临期/7 日趋势各一遍) + 趋势 + 来源 + 月收入
// + 逾期/今日计数各一遍。改为一次遍历产出全部首页派生数据,body 内只求值一次并
// 下发给各区块函数,不得再各自重复聚合。
//
// 口径承诺(与旧计算逐项等价,见 V391P1Tests.testHomeAggregatesMatchesLegacy):
// - 今日/昨日/月收入:与 TodaySummary / MonthlyBusinessMetrics 同谓词
//   (今日 = isToday,昨日 = 与昨日同日,本月 = startOfMonth...endOfDay)。
// - 趋势:与 PerformanceTrend.last7Days 同口径(近 7 日逐日,标签 M/d)。
// - 来源:与 IncomeSourceSummary.compute(本月区间)同口径。
// - 今日待办:与 TodaySummary 同谓词(未完成且无截止或截止在今天)。
// - 逾期计数:与 TodoFilter.overdue 同谓词(未完成且截止 < 今日 0 点)。
// - 今日待办计数:与 TodoFilter.today 同谓词(未完成且无截止或截止在今日区间内)。
// - handlingItems:复用 HomeInbox.items(limit: 3),不改排序/截断语义。

struct HomeAggregates {
    let todayRevenue: Double
    let yesterdayRevenue: Double
    let monthRevenue: Double
    let monthGoal: Double
    let changePercent: Double?
    let trendPoints: [TrendPoint]
    let sourceSummaries: [IncomeSourceSummary]
    let todayTodoCount: Int
    let overdueCount: Int
    let pendingExpiryCount: Int
    let deliveryCount: Int
    let handlingItems: [HomeInboxItem]

    static func build(
        performances: [Performance],
        todos: [Todo],
        customers: [CustomerRequest],
        expiryItems: [ExpiryItem],
        monthGoal: Double,
        now: Date = Date()
    ) -> HomeAggregates {
        let cal = Calendar.current
        let todayStart = now.startOfDay
        let todayEnd = now.endOfDay
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let monthStart = now.startOfMonth

        var todayRevenue = 0.0
        var yesterdayRevenue = 0.0
        var monthRevenue = 0.0
        var trendByDay: [Date: Double] = [:]
        var sourceByKind: [IncomeSource: Double] = [:]
        var sourceTotal = 0.0
        // 近 7 日桶(今日起往前 6 天),键为当日 0 点。
        var trendDays: [Date] = []
        for offset in (0..<7).reversed() {
            if let day = cal.date(byAdding: .day, value: -offset, to: todayStart) {
                trendDays.append(day)
                trendByDay[day] = 0
            }
        }
        for performance in performances {
            let date = performance.date
            // 今日/昨日判定与旧 TodaySummary 完全一致(isToday / 与昨日同日,不用 now 重算)。
            if date.isToday { todayRevenue += performance.amount }
            if date.isSameDay(as: yesterday) { yesterdayRevenue += performance.amount }
            if date >= monthStart && date <= todayEnd {
                monthRevenue += performance.amount
                let kind = IncomeSource.from(performance: performance)
                sourceByKind[kind, default: 0] += performance.amount
                sourceTotal += performance.amount
            }
            let dayStart = cal.startOfDay(for: date)
            if trendByDay[dayStart] != nil {
                trendByDay[dayStart, default: 0] += performance.amount
            }
        }
        let trendPoints = trendDays.enumerated().map { index, day in
            let c = cal.dateComponents([.month, .day], from: day)
            return TrendPoint(id: index, label: "\(c.month ?? 0)/\(c.day ?? 0)",
                              value: trendByDay[day] ?? 0, date: day)
        }
        let sourceSummaries = IncomeSource.allCases.map { kind in
            let amount = sourceByKind[kind] ?? 0
            return IncomeSourceSummary(source: kind, amount: amount,
                                       ratio: sourceTotal > 0 ? amount / sourceTotal : 0)
        }

        var todayTodos: [Todo] = []
        var todayTodoCount = 0
        var overdueCount = 0
        for todo in todos where !todo.isCompleted {
            if todo.dueDate == nil || (todo.dueDate! >= todayStart && todo.dueDate! <= todayEnd) {
                todayTodoCount += 1
            }
            if let due = todo.dueDate, due < todayStart { overdueCount += 1 }
            if todo.dueDate == nil || todo.dueDate!.isToday {
                todayTodos.append(todo)
            }
        }
        todayTodos.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        // 单测 now != 今天时,TodaySummary 的 isToday 谓词与 now 谓词可能分叉;
        // handlingItems 仍以 TodaySummary 谓词(todayTodos)为准,保持与旧首页一致。
        let deliveries = customers.filter { $0.statusEnum != .done }
        let pendingExpiry = expiryItems.filter { $0.status == .pending }
        let handlingItems = HomeInbox.items(todos: todayTodos, deliveries: deliveries,
                                            expiryItems: pendingExpiry, limit: 3)
        return HomeAggregates(
            todayRevenue: todayRevenue,
            yesterdayRevenue: yesterdayRevenue,
            monthRevenue: monthRevenue,
            monthGoal: monthGoal,
            changePercent: yesterdayRevenue > 0 ? (todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100 : nil,
            trendPoints: trendPoints,
            sourceSummaries: sourceSummaries,
            todayTodoCount: todayTodoCount,
            overdueCount: overdueCount,
            pendingExpiryCount: pendingExpiry.count,
            deliveryCount: deliveries.count,
            handlingItems: handlingItems
        )
    }
}
