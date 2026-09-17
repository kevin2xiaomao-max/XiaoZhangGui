import Foundation
import SwiftData

// MARK: - V3.3 Lite · 本地经营数据读取（READ 唯一数据来源）
//
// - 位于 AI 目录之外，是 BusinessContextProviding 的真实实现；
// - 只产出 ScopedBusinessContext 最小投影（数量 / 标题），
//   电话、地址、图片、内部 ID、备注等敏感字段一律不进入投影；
// - 投影之后还必须经过 ContextRedactor 才能（未来）进入 Provider；
//   Lite 的 READ 全部本地模板回答，0 Token、数据不出设备。

@MainActor
final class RepositoryBusinessContextReader: BusinessContextProviding {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func scopedContext(for kinds: [BusinessRecordKind]) async -> ScopedBusinessContext {
        guard !kinds.isEmpty else { return .empty }

        var total: Double?
        var count: Int?
        var todos: [String]?
        var memos: [String]?
        var expiring: [String]?
        var pending: Int?
        var delivering: Int?

        for kind in Set(kinds) {
            do {
                switch kind {
                case .revenueToday:
                    let (sum, n) = try todaysRevenue()
                    total = sum; count = n
                case .todoToday:
                    todos = try todaysTodos()
                case .recentMemo:
                    memos = try recentMemos()
                case .expiringGoods:
                    expiring = try upcomingExpiry()
                case .delivery:
                    let (p, d) = try todaysDeliveries()
                    pending = p; delivering = d
                }
            } catch {
                // 单类查询失败不拖垮整体：该类保持 nil（回答层显示空态）
                continue
            }
        }

        return ScopedBusinessContext(
            revenueTodayTotal: total,
            revenueTodayCount: count,
            todoTodayTitles: todos,
            recentMemoTitles: memos,
            expiringTitles: expiring,
            deliveryPendingCount: pending,
            deliveryDeliveringCount: delivering
        )
    }

    // MARK: 查询

    private func dayBounds(_ date: Date = Date()) throws -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private func todaysRevenue() throws -> (total: Double, count: Int) {
        let (start, end) = try dayBounds()
        let descriptor = FetchDescriptor<Performance>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let rows = try context.fetch(descriptor)
        return (rows.reduce(0) { $0 + $1.amount }, rows.count)
    }

    private func todaysTodos() throws -> [String] {
        let (_, end) = try dayBounds()
        let descriptor = FetchDescriptor<Todo>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        descriptor.fetchLimit = 20
        let rows = try context.fetch(descriptor)
        return rows
            .filter { ($0.dueDate ?? .distantFuture) <= end }
            .prefix(5)
            .map(\.title)
    }

    private func recentMemos() throws -> [String] {
        var descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        return try context.fetch(descriptor).map(\.title)
    }

    private func upcomingExpiry() throws -> [String] {
        let today = calendar.startOfDay(for: Date())
        let horizon = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let descriptor = FetchDescriptor<ExpiryItem>(
            predicate: #Predicate { $0.returnStatus == "待处理" },
            sortBy: [SortDescriptor(\.expiryDate, order: .forward)]
        )
        descriptor.fetchLimit = 30
        return try context.fetch(descriptor)
            .filter { $0.expiryDate <= horizon }
            .prefix(8)
            .map { item in
                let days = item.daysLeft(from: Date())
                if days < 0 { return "\(item.name)（已过期 \(-days) 天）" }
                if days == 0 { return "\(item.name)（今天到期）" }
                return "\(item.name)（剩 \(days) 天）"
            }
    }

    private func todaysDeliveries() throws -> (pending: Int, delivering: Int) {
        let (start, end) = try dayBounds()
        let descriptor = FetchDescriptor<CustomerRequest>(
            predicate: #Predicate { $0.createdAt >= start && $0.createdAt < end }
        )
        let rows = try context.fetch(descriptor)
        let pending = rows.filter { $0.status == CustomerStatus.pending.rawValue }.count
        let delivering = rows.filter { $0.status == CustomerStatus.delivering.rawValue }.count
        return (pending, delivering)
    }
}
