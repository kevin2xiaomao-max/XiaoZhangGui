import Foundation

struct TodaySummary: Equatable {
    let revenue: Double
    let yesterdayRevenue: Double
    let todos: [Todo]
    let deliveries: [CustomerRequest]
    let pendingExpiry: [ExpiryItem]
    let trend: [TrendPoint]

    var changePercent: Double? {
        guard yesterdayRevenue > 0 else { return nil }
        return (revenue - yesterdayRevenue) / yesterdayRevenue * 100
    }

    static func build(
        performances: [Performance],
        todos: [Todo],
        customers: [CustomerRequest],
        expiryItems: [ExpiryItem],
        now: Date = Date()
    ) -> TodaySummary {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let revenue = performances.filter { $0.date.isToday }.reduce(0) { $0 + $1.amount }
        let yesterdayRevenue = performances.filter { $0.date.isSameDay(as: yesterday) }.reduce(0) { $0 + $1.amount }
        let todayTodos = todos.filter { !$0.isCompleted && ($0.dueDate == nil || $0.dueDate?.isToday == true) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let deliveries = customers.filter { $0.statusEnum != .done }
        let expiry = expiryItems.filter { $0.status == .pending }
        return TodaySummary(
            revenue: revenue,
            yesterdayRevenue: yesterdayRevenue,
            todos: todayTodos,
            deliveries: deliveries,
            pendingExpiry: expiry,
            trend: PerformanceTrend.last7Days(performances: performances, now: now)
        )
    }
}
