import Foundation
import SwiftData

// MARK: - V3.3 Lite · 本地经营数据读取（READ 唯一数据来源）
//
// - 位于 AI 目录之外，是 BusinessContextProviding 的真实实现；
// - 只产出 ScopedBusinessContext 最小投影（数量 / 标题），
//   电话、地址、图片、内部 ID、备注等敏感字段一律不进入投影；
// - 投影之后还必须经过 ContextRedactor 才能（未来）进入 Provider；
//   Lite 的 READ 全部本地模板回答，0 Token、数据不出设备。
//
// 查询约定（与全工程 Repository / 基线测试一致）：
// - 只使用裸 FetchDescriptor 拉取后在 Swift 侧过滤 / 排序；
// - 不使用 #Predicate / SortDescriptor，与全工程既有用法保持一致，
//   规避 in-memory 测试宿主上的兼容 / 挂起风险（含可选 keypath 排序）。
@MainActor
final class RepositoryBusinessContextReader: BusinessContextProviding {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func scopedContext(for kinds: [BusinessRecordKind]) async -> ScopedBusinessContext {
        scopedContextSync(for: kinds)
    }

    func goods(named query: String) async -> [GoodsSummary] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let rows = try? context.fetch(FetchDescriptor<Goods>()) else { return [] }
        return rows
            .filter { normalized.contains($0.name) || $0.name.contains(normalized) }
            .map { GoodsSummary(name: $0.name, purchasePrice: $0.purchasePrice, salePrice: $0.salePrice, stock: $0.stock, minStock: $0.minStock) }
    }

    /// 同步测试接缝：查询本身无异步等待，同步实现便于单测与 AgentCore 共用同一份派生逻辑。
    func scopedContextSync(for kinds: [BusinessRecordKind]) -> ScopedBusinessContext {
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
                // 单类查询失败不拖垮整体：该类保持 nil（回答层显示空值）。
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

    private func dayBounds(_ date: Date = Date()) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private func todaysRevenue() throws -> (total: Double, count: Int) {
        let (start, end) = dayBounds()
        let rows = try context.fetch(FetchDescriptor<Performance>())
        let today = rows.filter { $0.date >= start && $0.date < end }
        return (today.reduce(0) { $0 + $1.amount }, today.count)
    }

    private func todaysTodos() throws -> [String] {
        let (_, end) = dayBounds()
        let rows = try context.fetch(FetchDescriptor<Todo>())
        return rows
            .filter { !$0.isCompleted && ($0.dueDate ?? .distantFuture) <= end }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .prefix(5)
            .map(\.title)
    }

    private func recentMemos() throws -> [String] {
        let rows = try context.fetch(FetchDescriptor<Memo>())
        return rows
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map(\.title)
    }

    private func upcomingExpiry() throws -> [String] {
        let today = calendar.startOfDay(for: Date())
        let horizon = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let rows = try context.fetch(FetchDescriptor<ExpiryItem>())
        return rows
            .filter { $0.returnStatus == ReturnStatus.pending.rawValue && $0.expiryDate <= horizon }
            .sorted { $0.expiryDate < $1.expiryDate }
            .prefix(8)
            .map { item in
                let days = item.daysLeft(from: Date())
                if days < 0 { return "\(item.name)（已过期 \(-days) 天）" }
                if days == 0 { return "\(item.name)（今天到期）" }
                return "\(item.name)（剩 \(days) 天）"
            }
    }

    private func todaysDeliveries() throws -> (pending: Int, delivering: Int) {
        let (start, end) = dayBounds()
        let rows = try context.fetch(FetchDescriptor<CustomerRequest>())
        let today = rows.filter { $0.createdAt >= start && $0.createdAt < end }
        let pending = today.filter { $0.status == CustomerStatus.pending.rawValue }.count
        let delivering = today.filter { $0.status == CustomerStatus.delivering.rawValue }.count
        return (pending, delivering)
    }
}
