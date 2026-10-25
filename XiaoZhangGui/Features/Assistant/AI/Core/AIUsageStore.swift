import Foundation

// MARK: - V3.9.3 D · AI 用量计量（轻量本地统计，绝不虚构 token / 费用）
//
// 计量口径（诚实声明）：
// - 每次 ProviderChain 尝试记 1 条：槽位（primary / fallback）+ 档位 + 结果
//   （成功 / 失败 / 取消）。这是次数级统计，不是 token 级账单。
// - token 与费用字段目前恒为 nil：第三方 LLMResponse 的 usage 结构尚未在仓内核实，
//   在核实前绝不填充、绝不按字符换算冒充 token 数、绝不硬编码价格。
//   设置页因此明确显示「不可用（服务商未返回用量数据）」，而不是假数字。
// - 记录绝不含原始聊天内容、图片原文、经营数据与 Key；仅槽位 / 档位 / 结果 / 时间。
// - 本地 UserDefaults 存储，上限 200 条（超限丢最旧），不上传、不进备份文案。

enum AIUsageOutcome: String, Codable, Sendable {
    case success
    case failed
    case cancelled
}

struct AIUsageRecord: Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var slot: String
    var tier: String
    var outcome: AIUsageOutcome
    var createdAt: Date = Date()
    /// 服务商返回的用量（未核实前恒为 nil；核实后由 Provider 层填充，绝不在此估算）。
    var inputTokens: Int? = nil
    var outputTokens: Int? = nil
    /// 费用估算（无可信价格配置时恒为 nil；设置页显示「不可用」，绝不硬编码单价）。
    var costEstimate: Double? = nil
}

struct AIUsageSummary: Equatable, Sendable {
    var total: Int
    var success: Int
    var failed: Int
    var cancelled: Int
    var bySlot: [String: Int]
    var lastRecordAt: Date?
    /// 是否有任何一条记录带 token 数据（目前恒为 false，见文件头声明）。
    var hasTokenData: Bool
    var hasCostData: Bool
}

actor AIUsageStore {
    static let shared = AIUsageStore()

    private let userDefaults: UserDefaults
    private let key = "xzg.ai.usage.records.v1"
    private let maxRecords = 200
    private var records: [AIUsageRecord]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([AIUsageRecord].self, from: data) {
            self.records = decoded
        } else {
            self.records = []
        }
    }

    func record(slot: String, tier: ModelTier, outcome: AIUsageOutcome) {
        records.append(AIUsageRecord(slot: slot, tier: tier.rawValue, outcome: outcome))
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }
        persist()
    }

    func summary() -> AIUsageSummary {
        var bySlot: [String: Int] = [:]
        for record in records { bySlot[record.slot, default: 0] += 1 }
        return AIUsageSummary(
            total: records.count,
            success: records.filter { $0.outcome == .success }.count,
            failed: records.filter { $0.outcome == .failed }.count,
            cancelled: records.filter { $0.outcome == .cancelled }.count,
            bySlot: bySlot,
            lastRecordAt: records.last?.createdAt,
            hasTokenData: records.contains { $0.inputTokens != nil || $0.outputTokens != nil },
            hasCostData: records.contains { $0.costEstimate != nil }
        )
    }

    /// 仅测试用：清空本实例的全部记录。
    func reset() {
        records = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            userDefaults.set(data, forKey: key)
        }
    }
}
