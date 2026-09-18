import Foundation

// MARK: - Widget 2.0 快捷工作台 · 展示用轻量事项
//
// 只含展示 metadata 与稳定 ID（待办 = Todo.notificationID），
// 不含图片/正文等大字段；随 BusinessSnapshot 存 App Group UserDefaults。
// 纯 Codable 值类型，App / Widget Extension / 测试 三方共用。

enum WidgetFocusKind: String, Codable {
    case todoOverdue
    case todoToday
    case delivery
    case expiry

    /// 行首图标（非交互行使用；待办圆圈由 AppIntent 按钮承载）
    var sfSymbol: String {
        switch self {
        case .todoOverdue: return "exclamationmark.circle.fill"
        case .todoToday: return "circle"
        case .delivery: return "person.2.fill"
        case .expiry: return "calendar.badge.exclamationmark"
        }
    }
}

struct WidgetFocusItem: Codable, Equatable, Identifiable {
    /// 稳定标识：
    /// - 待办：Todo.notificationID（UUID）
    /// - 配送："delivery-" + CustomerRequest.notificationID
    /// - 临期："expiry-" + ExpiryItem.notificationID
    var id: String
    var kind: WidgetFocusKind
    var title: String
    var detail: String?
    /// 仅待办可在 Widget 上直接勾选完成（Interactive Widget → AppIntent）
    var completable: Bool

    init(
        id: String,
        kind: WidgetFocusKind,
        title: String,
        detail: String? = nil,
        completable: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.completable = completable
    }
}

/// Widget 2.0 纯展示规则（无 SwiftData / WidgetKit 依赖，可确定性单测）
enum WidgetDashboard {
    /// Medium 最多展示条数
    static let focusItemLimit = 2

    /// 按优先级选取事项：逾期待办 → 今日待办 → 客户配送 → 紧急临期。
    /// - 最多 `limit` 条；按稳定 id 跨类别去重；各类别内部顺序由调用方排好。
    static func selectFocusItems(
        overdueTodos: [WidgetFocusItem],
        todayTodos: [WidgetFocusItem],
        deliveries: [WidgetFocusItem],
        expiries: [WidgetFocusItem],
        limit: Int = WidgetDashboard.focusItemLimit
    ) -> [WidgetFocusItem] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        var result: [WidgetFocusItem] = []
        result.reserveCapacity(limit)
        for candidate in overdueTodos + todayTodos + deliveries + expiries {
            if seen.contains(candidate.id) { continue }
            seen.insert(candidate.id)
            result.append(candidate)
            if result.count >= limit { break }
        }
        return result
    }

    /// Small 底部一行轻量状态（不是数据仪表盘）；全部为 0 时返回 nil。
    static func statusLine(
        overdueTodos: Int,
        todayTodos: Int,
        deliveries: Int,
        urgentExpiry: Int
    ) -> String? {
        if overdueTodos > 0 { return "\(overdueTodos) 个逾期待办" }
        if todayTodos > 0 { return "\(todayTodos) 个待办" }
        if deliveries > 0 { return "\(deliveries) 个配送" }
        if urgentExpiry > 0 { return "\(urgentExpiry) 件临期" }
        return nil
    }

    /// 营业额展示格式：整数加千分位（2680 → "2,680"；268000 → "268,000"），
    /// 非整数保留两位（88.5 → "88.50"），0 直接显示 "0"。
    static func formatRevenue(_ value: Double) -> String {
        if value <= 0 { return "0" }
        if value.rounded() == value {
            return integerFormatter.string(from: NSNumber(value: value)) ?? String(Int(value))
        }
        return fractionFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static let integerFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        return f
    }()

    private static let fractionFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return f
    }()
}

/// Widget 2.0 快捷工作台 Deep Link（App / Widget Extension 共用，避免各处手写 URL）
enum XZGWidgetLink {
    /// 直达小掌柜 AI 输入页（App 端 AppDeepLink 解析 "ai" → 切到 assistant Tab，非仅打开首页）
    static let ai = URL(string: "xzg://ai")!
    /// 直达现有语音快速记录（App 端解析 "voice" → VoiceView，onAppear 即 beginListening）
    static let voice = URL(string: "xzg://voice")!
}
