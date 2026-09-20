import Foundation

// MARK: - V3.3 Lite · 业务上下文（最小必要字段）
//
// 隐私红线：
// - 世界知识 / 普通聊天 → 不取任何经营数据（kinds 为空，payload 为 .empty）；
// - searchRecords 即使是 READ 可自动执行，原始结果也必须先经 BusinessContextProvider
//   聚合、再经 ContextRedactor 脱敏，才能进入 Provider；
// - 客户完整电话、完整地址、图片 Data、无关备注、其它日期数据默认禁止进入 payload。

/// 已按问题裁剪到最小字段的经营上下文（仍可能含需脱敏文本，交给 Redactor）。
struct ScopedBusinessContext: Equatable, Sendable {
    var revenueTodayTotal: Double?
    var revenueTodayCount: Int?
    /// 仅标题，不含详情 / 备注；上限由 Redactor 截断
    var todoTodayTitles: [String]?
    /// 仅备忘标题
    var recentMemoTitles: [String]?
    /// 仅临期商品名称（不含备注 / 图片）
    var expiringTitles: [String]? = nil
    var deliveryPendingCount: Int?
    var deliveryDeliveringCount: Int?

    static let empty = ScopedBusinessContext()
}

/// AI 侧商品只保留可回答问题所需的数值投影，不携带图片、备注或 SwiftData 对象。
struct GoodsSummary: Equatable, Sendable {
    let name: String
    let purchasePrice: Double
    let salePrice: Double
    let stock: Int
    let minStock: Int
}

struct DailyRevenueSummary: Equatable, Sendable {
    let date: Date
    let amount: Double
}

struct BusinessPeriodSummary: Equatable, Sendable {
    let period: BusinessPeriod
    let amount: Double
    let count: Int
    let comparisonAmount: Double?
    let comparisonMonthCount: Int?
    let comparisonAverageAmount: Double?
}

/// AI 2.0 唯一经营上下文入口。只保留聚合值和短标题，不承载 SwiftData 对象或客户隐私。
struct GroundingPack: Equatable, Sendable {
    var todayRevenue: Double?
    var yesterdayRevenue: Double?
    var sevenDayRevenue: [DailyRevenueSummary]
    var unfinishedTodoTitles: [String]
    var deliveryPendingCount: Int
    var deliveryDeliveringCount: Int
    var expiryTitles: [String]
    var goods: [GoodsSummary]
    var localSummary: String?
    var periodSummaries: [BusinessPeriodSummary] = []

    static let empty = GroundingPack(
        todayRevenue: nil, yesterdayRevenue: nil, sevenDayRevenue: [],
        unfinishedTodoTitles: [], deliveryPendingCount: 0, deliveryDeliveringCount: 0,
        expiryTitles: [], goods: [], localSummary: nil
    )

    var hasBusinessData: Bool {
        todayRevenue != nil || yesterdayRevenue != nil || sevenDayRevenue.contains { $0.amount != 0 }
            || periodSummaries.contains { $0.amount != 0 }
            || !unfinishedTodoTitles.isEmpty || deliveryPendingCount > 0
            || deliveryDeliveringCount > 0 || !expiryTitles.isEmpty || !goods.isEmpty
    }
}

enum BusinessInsightKind: Equatable, Sendable {
    case overview
    case comparison
    case sevenDayTrend
    case inventory
    case advice
    case period(BusinessPeriod)
}

protocol BusinessContextProviding: Sendable {
    /// 按问题需要的种类取最小上下文；kinds 为空必须返回空上下文（0 数据外发）。
    func scopedContext(for kinds: [BusinessRecordKind]) async -> ScopedBusinessContext
    func goods(named query: String) async -> [GoodsSummary]
    func groundingPack() async -> GroundingPack
}

extension BusinessContextProviding {
    func goods(named query: String) async -> [GoodsSummary] { [] }
    func groundingPack() async -> GroundingPack { .empty }
}

/// Foundation：尚未接 Repository，统一返回空上下文。
/// FINAL 由 Repository 聚合实现（仅 Performance/Todo/Memo/Customer 的只读重载）。
struct UnavailableBusinessContextProvider: BusinessContextProviding {
    func scopedContext(for kinds: [BusinessRecordKind]) async -> ScopedBusinessContext {
        guard !kinds.isEmpty else { return .empty }
        // 预览阶段不读取业务库
        return .empty
    }

    func goods(named query: String) async -> [GoodsSummary] { [] }
    func groundingPack() async -> GroundingPack { .empty }
}
