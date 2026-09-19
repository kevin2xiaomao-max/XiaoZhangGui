import Foundation

// MARK: - V3.3 Lite · AI 基础 DTO（Foundation / 逻辑 Build 29，实际 build 31）
//
// 红线：
// - 本文件及整个 AI 层只描述「AI 的理解结果 / 待确认动作」，不 import SwiftData；
// - AI 只能产生结构化 ToolCall，CREATE 必须经 ActionCard 用户确认；
// - Foundation 阶段动作只做预览（isPreviewOnly = true），不允许真实写库。

enum AIRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

/// 会话消息。用户原始文字 / 语音 transcript 在调用 Provider 前就落盘，
/// Provider 失败时消息仍保留（isError 标记助手失败回复）。
struct AIMessage: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var role: AIRole
    var content: String
    var createdAt: Date
    /// 关联的待确认动作（Lite：一条助手消息至多一个）
    var proposalID: UUID?
    /// 助手失败回复标记（用户原文永不标失败、永不丢失）
    var isError: Bool

    init(
        id: UUID = UUID(),
        role: AIRole,
        content: String,
        createdAt: Date = .now,
        proposalID: UUID? = nil,
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.proposalID = proposalID
        self.isError = isError
    }
}

// MARK: - 工具定义

/// Lite 只注册 5 个工具：1 个 READ + 4 个 CREATE。
/// addExpiry / update / delete 不注册（V3.4+ 再议，且需更高级确认）。
enum ToolName: String, Codable, Sendable, CaseIterable {
    case searchRecords
    case recordRevenue
    case createTodo
    case createMemo
    case createDelivery

    var permission: ToolPermission {
        switch self {
        case .searchRecords:
            return .read
        case .recordRevenue, .createTodo, .createMemo, .createDelivery:
            return .create
        }
    }

    /// ActionCard / 日志里的中文名
    var displayName: String {
        switch self {
        case .searchRecords: return "查询经营记录"
        case .recordRevenue: return "记录营业额"
        case .createTodo: return "新建待办"
        case .createMemo: return "新建备忘"
        case .createDelivery: return "新建配送"
        }
    }
}

/// 工具权限分级：
/// - read：Agent 可自动执行，但结果必须经 BusinessContextProvider + ContextRedactor
///   最小字段裁剪后才能进入 Provider（READ 自动执行 ≠ 原始数据可外发）。
/// - create：必须 ActionCard 用户确认后才执行。
enum ToolPermission: String, Codable, Sendable {
    case read
    case create
}

// MARK: - 四类 CREATE + 一类 READ 参数（全部 Codable / Sendable / 可单测）

struct RevenueArguments: Codable, Equatable, Sendable {
    var amount: Double?
    /// 来源：美团 / 饿了么 / 现金 / 微信 / 支付宝 …
    var source: String?
    var date: Date?
    var note: String?
}

struct TodoArguments: Codable, Equatable, Sendable {
    var title: String?
    var detail: String?
    var dueDate: Date?
    /// 对齐现有 Todo.priority：0 普通 / 1 重要 / 2 紧急
    var priority: Int?
}

struct MemoArguments: Codable, Equatable, Sendable {
    var title: String?
    var content: String?
}

struct DeliveryArguments: Codable, Equatable, Sendable {
    /// 客户 / 房号，如 "302"
    var customer: String?
    var roomOrAddress: String?
    var phone: String?
    /// 商品完整描述，如 "怡宝两箱"
    var content: String?
    /// 商品名，如 "怡宝"
    var goodsName: String?
    /// 数量原文，如 "两箱"
    var quantity: String?
    var deliveryTime: Date?
    /// 时间原文，如 "今晚8点"
    var deliveryTimeText: String?
    var note: String?
    /// 配送 / 商品总金额（P0-2，如「一共45元」→ 45）。缺省 nil，旧 JSON 无此字段可正常解码。
    var amount: Double? = nil
}

enum BusinessRecordKind: String, Codable, Sendable, CaseIterable {
    case revenueToday
    case todoToday
    case recentMemo
    /// 临期 / 到期商品
    case expiringGoods
    case delivery
}

struct SearchRecordsArguments: Codable, Equatable, Sendable {
    var query: String?
    var kinds: [BusinessRecordKind]
}

/// 工具参数（合成 Codable；关联值均为 Codable）。
enum ToolArguments: Codable, Equatable, Sendable {
    case searchRecords(SearchRecordsArguments)
    case recordRevenue(RevenueArguments)
    case createTodo(TodoArguments)
    case createMemo(MemoArguments)
    case createDelivery(DeliveryArguments)

    var toolName: ToolName {
        switch self {
        case .searchRecords: return .searchRecords
        case .recordRevenue: return .recordRevenue
        case .createTodo: return .createTodo
        case .createMemo: return .createMemo
        case .createDelivery: return .createDelivery
        }
    }
}

/// 一次结构化工具调用。`id` 即 toolCallID，是幂等第一键。
struct ToolCall: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: ToolName
    var arguments: ToolArguments

    static func makeID() -> String {
        "call_\(UUID().uuidString)"
    }
}

// MARK: - ActionCard 提案

enum ProposalStatus: String, Codable, Sendable {
    /// 等待用户确认
    case pending
    /// 用户已确认（FINAL：随后执行；Foundation：仅预览态）
    case confirmed
    /// 用户删除 / 取消该项
    case cancelled
    /// FINAL：真实落库成功
    case executed
    /// FINAL：执行失败（可重试，不丢卡）
    case failed
    /// 幂等折叠：与已存在调用 / 业务指纹重复
    case duplicate
}

/// ActionCard 数据。Lite 一次只承载一个 ToolCall（无 ActionBatch）。
struct ActionProposal: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var call: ToolCall
    var status: ProposalStatus
    var createdAt: Date
    /// Foundation 恒为 true：只预览，确认也不写库；FINAL 为 false。
    var isPreviewOnly: Bool
    /// Foundation 下用户点过「确认记录」后，展示的预览说明（不声称已保存）
    var previewAcknowledged: Bool
    /// FINAL 真实执行结果摘要
    var resultText: String?

    init(
        id: UUID = UUID(),
        call: ToolCall,
        status: ProposalStatus = .pending,
        createdAt: Date = .now,
        isPreviewOnly: Bool,
        previewAcknowledged: Bool = false,
        resultText: String? = nil
    ) {
        self.id = id
        self.call = call
        self.status = status
        self.createdAt = createdAt
        self.isPreviewOnly = isPreviewOnly
        self.previewAcknowledged = previewAcknowledged
        self.resultText = resultText
    }
}

// MARK: - Agent 错误

enum AgentError: LocalizedError, Equatable {
    /// 正式环境未配置真实 Provider / ToolRouter，必须失败闭合，禁止 Mock 假成功
    case notConfigured
    case providerFailed(String)
    case invalidResponse(String)
    case emptyTranscript
    case unsupportedTool(String)
    /// Foundation 预览闸门：CREATE 不允许真实落库
    case mutationRejectedInFoundation

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI 服务尚未配置，已阻止操作（不会假装成功）"
        case .providerFailed(let reason):
            return "AI 服务暂时不可用：\(reason)"
        case .invalidResponse(let reason):
            return "AI 返回无法识别：\(reason)"
        case .emptyTranscript:
            return "没有听清，请再试一次"
        case .unsupportedTool(let name):
            return "当前版本暂不支持该操作：\(name)"
        case .mutationRejectedInFoundation:
            return "预览版不会真实保存，正式版将在你确认后记录"
        }
    }
}
