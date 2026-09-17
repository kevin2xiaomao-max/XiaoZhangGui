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

protocol BusinessContextProviding: Sendable {
    /// 按问题需要的种类取最小上下文；kinds 为空必须返回空上下文（0 数据外发）。
    func scopedContext(for kinds: [BusinessRecordKind]) async -> ScopedBusinessContext
}

/// Foundation：尚未接 Repository，统一返回空上下文。
/// FINAL 由 Repository 聚合实现（仅 Performance/Todo/Memo/Customer 的只读重载）。
struct UnavailableBusinessContextProvider: BusinessContextProviding {
    func scopedContext(for kinds: [BusinessRecordKind]) async -> ScopedBusinessContext {
        guard !kinds.isEmpty else { return .empty }
        // 预览阶段不读取业务库
        return .empty
    }
}
