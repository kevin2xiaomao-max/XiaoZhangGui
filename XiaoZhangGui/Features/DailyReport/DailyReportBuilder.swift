import Foundation

struct DailyReport: Equatable {
    let date: Date
    let todayRevenue: Double
    let yesterdayRevenue: Double
    let completedTodos: Int
    let pendingTodos: Int
    let deliveries: Int
    let pendingExpiry: Int

    var changeText: String {
        guard yesterdayRevenue > 0 else { return "昨日暂无营业额，无法对比" }
        let change = (todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100
        if abs(change) < 0.05 { return "与昨日基本持平" }
        return String(format: "较昨日%@ %.1f%%", change >= 0 ? "增长" : "下降", abs(change))
    }

    var shareText: String {
        """
        【今日经营日报】\(Fmt.formatDate(date))
        今日营业额：\(Fmt.money(todayRevenue))
        \(changeText)
        待办：完成 \(completedTodos) 件，未完成 \(pendingTodos) 件
        配送：待处理 \(deliveries) 单
        临时商品待处理：\(pendingExpiry) 件
        """
    }

    static func build(
        now: Date = Date(),
        performances: [Performance],
        todos: [Todo],
        customers: [CustomerRequest],
        expiryItems: [ExpiryItem]
    ) -> DailyReport {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let todayRevenue = performances.filter { cal.isDate($0.date, inSameDayAs: now) }.reduce(0) { $0 + $1.amount }
        let yesterdayRevenue = performances.filter { cal.isDate($0.date, inSameDayAs: yesterday) }.reduce(0) { $0 + $1.amount }
        let completed = todos.filter { $0.completedAt.map { cal.isDate($0, inSameDayAs: now) } ?? false }.count
        let pending = todos.filter { !$0.isCompleted && ($0.dueDate == nil || cal.isDate($0.dueDate!, inSameDayAs: now)) }.count
        let deliveries = customers.filter { $0.statusEnum != .done }.count
        let expiry = expiryItems.filter { $0.status == .pending }.count
        return DailyReport(
            date: now,
            todayRevenue: todayRevenue,
            yesterdayRevenue: yesterdayRevenue,
            completedTodos: completed,
            pendingTodos: pending,
            deliveries: deliveries,
            pendingExpiry: expiry
        )
    }
}
