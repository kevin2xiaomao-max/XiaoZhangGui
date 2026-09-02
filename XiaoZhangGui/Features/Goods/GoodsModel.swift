import Foundation
import SwiftUI

// MARK: - 临时商品派生数据（对齐 Android GoodsScreen：搜索/分类/统计/状态）

enum GoodsCategory {
    /// 展示分类（首项为"全部"过滤项）
    static let known = ["饮料", "零食", "日用品", "烟酒", "其他"]
    static let filters = ["全部"] + known
}

enum GoodsStats {
    /// 7 天内临期
    static func expiringSoon(_ goods: [Goods], now: Date = Date()) -> Int {
        let week = now.addingTimeInterval(7 * 86400)
        return goods.filter { $0.expiryDate != nil && $0.expiryDate! >= now && $0.expiryDate! <= week }.count
    }

    static func lowStock(_ goods: [Goods]) -> Int {
        goods.filter { $0.isLowStock }.count
    }

    static func totalStock(_ goods: [Goods]) -> Int {
        goods.reduce(0) { $0 + max($1.stock, 0) }
    }
}

/// 搜索 + 分类过滤（对齐 Android：其他 = 分类为"其他"或不在已知分类）
enum GoodsFilter {
    static func filtered(goods: [Goods], query: String, category: String) -> [Goods] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return goods
            .filter { item in
                let matchesCategory =
                    category == "全部" ||
                    item.category == category ||
                    (category == "其他" && !GoodsCategory.known.contains(item.category))
                let matchesQuery = keyword.isEmpty ||
                    item.name.localizedCaseInsensitiveContains(keyword) ||
                    (!item.barcode.isEmpty && item.barcode.contains(keyword))
                return matchesCategory && matchesQuery
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

/// 商品状态：已过期 / 即将到期(7天) / 库存不足 / 正常
enum GoodsState {
    case expired, expiringSoon, lowStock, normal

    var label: String {
        switch self {
        case .expired: return "已过期"
        case .expiringSoon: return "即将到期"
        case .lowStock: return "库存不足"
        case .normal: return "正常"
        }
    }

    var color: Color {
        switch self {
        case .expired: return V21.danger
        case .expiringSoon, .lowStock: return V21.warning
        case .normal: return V21.brandGreen
        }
    }

    static func of(_ goods: Goods, now: Date = Date()) -> GoodsState {
        if let expiry = goods.expiryDate {
            if expiry < now { return .expired }
            if expiry <= now.addingTimeInterval(7 * 86400) { return .expiringSoon }
        }
        if goods.isLowStock { return .lowStock }
        return .normal
    }
}
