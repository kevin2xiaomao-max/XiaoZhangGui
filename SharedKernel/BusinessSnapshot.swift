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

    var hasContent: Bool {
        todayRevenue > 0 || todayTodoCount > 0 || overdueTodoCount > 0
            || deliveringCustomerCount > 0 || urgentExpiryCount > 0
            || nextTodoTitle != nil || nextExpiryName != nil
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
