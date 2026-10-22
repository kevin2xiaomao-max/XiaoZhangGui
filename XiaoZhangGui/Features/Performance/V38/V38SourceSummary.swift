import Foundation

/// V3.8 重建 · 经营页收入分类选择（纯逻辑，可单测）。
///
/// 只做展示层选择，不参与任何金额计算：金额全部来自既有模型
/// `IncomeSourceSummary.compute`（收入分类与公式零改动，红线）。
enum V38SourceSelection: Hashable, Identifiable, CaseIterable {
    case all
    case store
    case meituan
    case other

    var id: String {
        switch self {
        case .all: return "all"
        case .store: return "store"
        case .meituan: return "meituan"
        case .other: return "other"
        }
    }

    var title: String {
        switch self {
        case .all: return "全部"
        case .store: return IncomeSource.store.rawValue
        case .meituan: return IncomeSource.meituan.rawValue
        case .other: return IncomeSource.other.rawValue
        }
    }

    /// 对应的收入分类；`.all` 为 nil（表示不筛选）。
    var source: IncomeSource? {
        switch self {
        case .all: return nil
        case .store: return .store
        case .meituan: return .meituan
        case .other: return .other
        }
    }

    /// UI 自动化 identifier 后缀（挂在 chip 按钮本身，不挂容器）。
    var identifier: String { "v38.performance.source.\(id)" }
}

/// 分类汇总派生值：给定模型汇总与当前选择，得到要展示的金额与占比。
///
/// 口径不变量（验收 G5）：各分类金额之和 == 总额；`.all` 的金额 == 总额。
struct V38SourceSummary: Equatable {
    let total: Double
    let amount: Double
    let ratio: Double

    static func make(summaries: [IncomeSourceSummary], selection: V38SourceSelection) -> V38SourceSummary {
        let total = summaries.reduce(0) { $0 + $1.amount }
        guard let source = selection.source else {
            return V38SourceSummary(total: total, amount: total, ratio: total > 0 ? 1 : 0)
        }
        let matched = summaries.first { $0.source == source }
        return V38SourceSummary(
            total: total,
            amount: matched?.amount ?? 0,
            ratio: matched?.ratio ?? 0
        )
    }
}
