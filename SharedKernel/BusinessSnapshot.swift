import Foundation

// MARK: - 经营快照（App 写入 App Group UserDefaults，Widget 读取）
// 纯 Codable 值类型，不依赖 SwiftData / WidgetKit，供双 target 编译

struct BusinessSnapshot: Codable, Equatable {
    var generatedAt: Date = Date()

    // 今日经营
    var todayRevenue: Double = 0
    var todayGoalPercent: Int = 0

    // 待办
    var todayTodoCount: Int = 0
    var overdueTodoCount: Int = 0
    var nextTodoTitle: String?
    var nextTodoTime: Date?

    // 客户需求
    var deliveringCustomerCount: Int = 0

    // 临期
    var urgentExpiryCount: Int = 0
    var nextExpiryName: String?
    var nextExpiryDays: Int?

    // V3.3 Widget 2.0：Medium「现在最该做什么」最多 2 条（追加字段，
    // 带默认值 → 旧 JSON 解码走 decodeIfPresent，老快照/老 App 双向兼容）
    var focusItems: [WidgetFocusItem] = []

    var hasContent: Bool {
        todayRevenue > 0 || todayTodoCount > 0 || overdueTodoCount > 0
            || deliveringCustomerCount > 0 || urgentExpiryCount > 0
            || nextTodoTitle != nil || nextExpiryName != nil
    }
}

extension BusinessSnapshot {
    // MARK: 向后兼容解码
    // 所有字段 decodeIfPresent + 默认值：V3.2/V3.3-Foundation 旧 JSON（无 focusItems，
    // 甚至早期缺字段）都能解出；老 App 读到含 focusItems 的新 JSON 也会忽略未知键。
    // 自定义 init 放在 extension 中，保留合成 memberwise init（sample 等仍可用）。
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
        todayRevenue = try c.decodeIfPresent(Double.self, forKey: .todayRevenue) ?? 0
        todayGoalPercent = try c.decodeIfPresent(Int.self, forKey: .todayGoalPercent) ?? 0
        todayTodoCount = try c.decodeIfPresent(Int.self, forKey: .todayTodoCount) ?? 0
        overdueTodoCount = try c.decodeIfPresent(Int.self, forKey: .overdueTodoCount) ?? 0
        nextTodoTitle = try c.decodeIfPresent(String.self, forKey: .nextTodoTitle)
        nextTodoTime = try c.decodeIfPresent(Date.self, forKey: .nextTodoTime)
        deliveringCustomerCount = try c.decodeIfPresent(Int.self, forKey: .deliveringCustomerCount) ?? 0
        urgentExpiryCount = try c.decodeIfPresent(Int.self, forKey: .urgentExpiryCount) ?? 0
        nextExpiryName = try c.decodeIfPresent(String.self, forKey: .nextExpiryName)
        nextExpiryDays = try c.decodeIfPresent(Int.self, forKey: .nextExpiryDays)
        focusItems = try c.decodeIfPresent([WidgetFocusItem].self, forKey: .focusItems) ?? []
    }
}

extension BusinessSnapshot {
    /// 存取 key（App Group UserDefaults）
    static var storageKey: String { "business_snapshot_v1" }

    func encode() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }

    static func load() -> BusinessSnapshot? {
        guard let defaults = XZGShared.sharedDefaults,
              let data = defaults.data(forKey: storageKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(BusinessSnapshot.self, from: data)
    }

    func save() {
        guard let defaults = XZGShared.sharedDefaults,
              let data = encode() else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
