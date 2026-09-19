import Foundation

// MARK: - V3.3 Lite · Provider 抽象（业务代码只依赖本协议）
//
// 第三方库（LLMProviderKit 等）一律经 XZGAIProviderAdapter 适配到本协议；
// Features/UI/Agent 层禁止直接 import 第三方 Provider 类型。
// Provider 只产出文本或结构化 ToolCall，绝不接触 SwiftData / Repository。

/// 提供给模型的工具描述（provider 中立；schema 为 JSON Data 以保证 Sendable）。
struct ProviderToolDefinition: Sendable, Equatable {
    let name: ToolName
    let jsonSchema: Data
}

/// 已脱敏的业务上下文载荷。worldChat 时必须为 nil / 空（0 经营数据外发）。
struct ProviderContextPayload: Sendable, Equatable {
    /// 最小必要字段的 JSON（由 ContextRedactor 产出）
    let json: Data?
    static let empty = ProviderContextPayload(json: nil)
}

struct ProviderRequest: Sendable {
    let messages: [AIMessage]
    let tools: [ProviderToolDefinition]
    let route: ModelRoute
    let context: ProviderContextPayload

    init(
        messages: [AIMessage],
        tools: [ProviderToolDefinition],
        route: ModelRoute,
        context: ProviderContextPayload = .empty
    ) {
        self.messages = messages
        self.tools = tools
        self.route = route
        self.context = context
    }

    var lastUserText: String? {
        messages.last { $0.role == .user }?.content
    }
}

/// Provider 一轮返回：普通文本，或一个结构化工具调用（Lite 每轮至多一个）。
enum ProviderTurn: Sendable, Equatable {
    case text(String)
    case toolCall(ToolCall)
}

protocol AIProvider: Sendable {
    /// 稳定标识（"mock-primary" / 未来 "openai-compat" / "gemini"）
    var id: String { get }
    func complete(_ request: ProviderRequest) async throws -> ProviderTurn
}

// MARK: - Provider 错误分类（决定是否允许 fallback）

enum ProviderFailure: Error, Equatable {
    case network(String)
    /// 设备当前无网络（区别于一般网络错误，文案提示「当前没有网络」）
    case offline
    case timeout
    case http(status: Int, body: String)
    case decoding(String)
    case cancelled
    case other(String)

    /// 401 / 403 等鉴权错误不允许悄悄换链重试（避免把无效 Key 轮询到多家）；
    /// 网络 / 无网络 / 超时 / 5xx / 429 才允许跳到唯一 fallback。
    var allowsFailover: Bool {
        switch self {
        case .http(let status, _):
            return (500...599).contains(status) || status == 429
        case .network, .offline, .timeout:
            return true
        case .decoding, .cancelled, .other:
            return false
        }
    }
}
