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
            .filter { GoodsLookupSkill.matchesGoods(query: normalized, goodsName: $0.name) }
            .map { GoodsSummary(name: $0.name, purchasePrice: $0.purchasePrice, salePrice: $0.salePrice, stock: $0.stock, minStock: $0.minStock) }
    }

    func groundingPack() async -> GroundingPack {
        do {
            let now = Date()
            let startToday = calendar.startOfDay(for: now)
            let startTomorrow = calendar.date(byAdding: .day, value: 1, to: startToday) ?? now
            let startYesterday = calendar.date(byAdding: .day, value: -1, to: startToday) ?? startToday
            let startSevenDays = calendar.date(byAdding: .day, value: -6, to: startToday) ?? startToday

            let revenues = try context.fetch(FetchDescriptor<Performance>())
            let todos = try context.fetch(FetchDescriptor<Todo>())
            let customers = try context.fetch(FetchDescriptor<CustomerRequest>())
            let expiry = try context.fetch(FetchDescriptor<ExpiryItem>())
            let goodsRows = try context.fetch(FetchDescriptor<Goods>())
            let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
            let memos = (try? context.fetch(FetchDescriptor<Memo>())) ?? []

            let todayRows = revenues.filter { $0.date >= startToday && $0.date < startTomorrow }
            let yesterdayRows = revenues.filter { $0.date >= startYesterday && $0.date < startToday }
            let trend = (0..<7).compactMap { offset -> DailyRevenueSummary? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: startSevenDays),
                      let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
                return DailyRevenueSummary(
                    date: day,
                    amount: revenues.filter { $0.date >= day && $0.date < next }.reduce(0) { $0 + $1.amount }
                )
            }
            let unfinished = todos
                .filter { todo in
                    guard !todo.isCompleted, let due = todo.dueDate else { return false }
                    return due < startTomorrow
                }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                .prefix(5).map(\.title)
            let todayDeliveries = customers.filter { $0.createdAt >= startToday && $0.createdAt < startTomorrow }
            let expiryTitles = expiry
                .filter { $0.returnStatus == ReturnStatus.pending.rawValue }
                .sorted { $0.expiryDate < $1.expiryDate }
                .prefix(5).map(\.name)
            let goods = goodsRows
                .sorted { lhs, rhs in
                    let lhsLow = lhs.stock <= lhs.minStock
                    let rhsLow = rhs.stock <= rhs.minStock
                    return lhsLow == rhsLow ? lhs.name < rhs.name : lhsLow && !rhsLow
                }
                .prefix(8)
                .map { GoodsSummary(name: $0.name, purchasePrice: $0.purchasePrice,
                                    salePrice: $0.salePrice, stock: $0.stock, minStock: $0.minStock) }

            let input = BusinessAssistantInput(
                now: now, monthGoal: 0, performances: revenues, expenses: expenses,
                todos: todos, memos: memos, customers: customers, expiryItems: expiry, weather: nil)
            let localSummary = await BusinessAssistantEngine().analyze(input).summary.text
            let periodParser = BusinessPeriodParser()
            let periods: [BusinessPeriod] = [.today, .yesterday, .lastSevenDays, .thisMonth, .lastMonth, .lastThreeMonths, .lastSixMonths, .thisMonthComparedWithLastMonth, .lastThreeMonthsComparedWithThisMonth]
            let periodSummaries = periods.compactMap { period -> BusinessPeriodSummary? in
                guard let bounds = periodParser.bounds(for: period, now: now, calendar: calendar) else { return nil }
                let isThreeMonthComparison = period == .lastThreeMonthsComparedWithThisMonth
                let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? bounds.start
                let rows = isThreeMonthComparison
                    ? revenues.filter { $0.date >= currentMonthStart && $0.date <= now }
                    : revenues.filter { $0.date >= bounds.start && $0.date < bounds.end }
                let comparison: Double? = {
                    guard period == .thisMonthComparedWithLastMonth || period == .lastThreeMonthsComparedWithThisMonth else { return nil }
                    let previousStart = period == .thisMonthComparedWithLastMonth
                        ? (calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart)
                        : (calendar.date(byAdding: .month, value: -3, to: currentMonthStart) ?? currentMonthStart)
                    let previousRows = revenues.filter { $0.date >= previousStart && $0.date < currentMonthStart }
                    return previousRows.reduce(0) { $0 + $1.amount }
                }()
                let comparisonMonthCount: Int? = isThreeMonthComparison ? (0..<3).reduce(0) { count, offset in
                    guard let monthStart = calendar.date(byAdding: .month, value: -offset - 1, to: currentMonthStart),
                          let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart),
                          revenues.contains(where: { $0.date >= monthStart && $0.date < monthEnd }) else { return count }
                    return count + 1
                } : nil
                let comparisonAverageAmount = comparison.map { amount in
                    let divisor = max(comparisonMonthCount ?? 1, 1)
                    return amount / Double(divisor)
                }
                return BusinessPeriodSummary(period: period, amount: rows.reduce(0) { $0 + $1.amount }, count: rows.count, comparisonAmount: comparison, comparisonMonthCount: comparisonMonthCount, comparisonAverageAmount: comparisonAverageAmount)
            }

            return GroundingPack(
                todayRevenue: todayRows.isEmpty ? nil : todayRows.reduce(0) { $0 + $1.amount },
                yesterdayRevenue: yesterdayRows.isEmpty ? nil : yesterdayRows.reduce(0) { $0 + $1.amount },
                sevenDayRevenue: revenues.isEmpty ? [] : trend,
                unfinishedTodoTitles: Array(unfinished),
                deliveryPendingCount: todayDeliveries.filter { $0.statusEnum == .pending }.count,
                deliveryDeliveringCount: todayDeliveries.filter { $0.statusEnum == .delivering }.count,
                expiryTitles: Array(expiryTitles), goods: goods, localSummary: localSummary,
                periodSummaries: periodSummaries
            )
        } catch {
            return .empty
        }
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
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let rows = try context.fetch(FetchDescriptor<Todo>())
        return rows
            .filter { todo in
                guard !todo.isCompleted, let due = todo.dueDate else { return false }
                return due < tomorrowStart
            }
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
