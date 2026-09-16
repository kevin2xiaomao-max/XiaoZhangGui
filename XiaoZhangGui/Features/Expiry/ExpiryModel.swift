import Foundation
import SwiftUI

// MARK: - 临期派生数据（语义对齐 Android ExpiryScreen 分组；按 02 文档补齐已过期/已退货）

enum ExpiryGroup {
    case expired      // 已过期（< 0 天，待处理）
    case urgent3      // 紧急 · 3天内（0...3）
    case urgent7      // 注意 · 7天内（4...7）
    case safe30       // 安全 · 30天内（8...30）
    case later        // 较远 · 30天外（> 30）
    case returned     // 已退货

    var label: String {
        switch self {
        case .expired: return "已过期"
        case .urgent3: return "紧急 · 3天内"
        case .urgent7: return "注意 · 7天内"
        case .safe30: return "安全 · 30天内"
        case .later: return "较远 · 30天外"
        case .returned: return "已退货"
        }
    }

    @MainActor var color: Color {
        switch self {
        case .expired, .urgent3: return V32.danger
        case .urgent7: return V32.amber
        case .safe30: return V32.brand
        case .later, .returned: return V32.textTertiary
        }
    }

    static let allCases: [ExpiryGroup] = [.expired, .urgent3, .urgent7, .safe30, .later, .returned]
}

// MARK: - 统计与分组（纯值计算，View 每次 body 重算）

struct ExpiryStats {
    /// 非空分组（已排序）
    let groups: [(group: ExpiryGroup, items: [ExpiryItem])]
    /// 副标题：7 天内到期件数（待处理 0...7 天）
    let expiringSoonCount: Int
    /// 三格统计：3 天 / 7 天 / 30 天（仅待处理）
    let urgentCount: Int
    let warningCount: Int
    let safeCount: Int

    init(items: [ExpiryItem]) {
        let pending = items
            .filter { $0.status == .pending }
            .sorted { $0.expiryDate < $1.expiryDate }
        let returned = items
            .filter { $0.status == .returned }
            .sorted { ($0.returnedAt ?? $0.expiryDate) > ($1.returnedAt ?? $1.expiryDate) }

        func inRange(_ range: ClosedRange<Int>) -> [ExpiryItem] {
            pending.filter { range.contains($0.daysLeft()) }
        }

        let buckets: [ExpiryGroup: [ExpiryItem]] = [
            .expired: pending.filter { $0.daysLeft() < 0 },
            .urgent3: inRange(0...3),
            .urgent7: inRange(4...7),
            .safe30: inRange(8...30),
            .later: pending.filter { $0.daysLeft() > 30 },
            .returned: returned
        ]

        groups = ExpiryGroup.allCases
            .compactMap { group in
                buckets[group].flatMap { items in items.isEmpty ? nil : (group, items) }
            }

        expiringSoonCount = inRange(0...7).count
        urgentCount = inRange(0...3).count
        warningCount = inRange(4...7).count
        safeCount = inRange(8...30).count
    }
}

// MARK: - 剩余天数徽标文案与颜色

enum ExpiryBadge {
    static func text(for item: ExpiryItem) -> String {
        if item.status == .returned { return "已退货" }
        let days = item.daysLeft()
        return days >= 0 ? "还剩 \(days) 天" : "已过期 \(-days) 天"
    }

    @MainActor static func color(for item: ExpiryItem) -> Color {
        if item.status == .returned { return V32.textTertiary }
        let days = item.daysLeft()
        if days <= 3 { return V32.danger }
        if days <= 7 { return V32.amber }
        return V32.brand
    }
}
