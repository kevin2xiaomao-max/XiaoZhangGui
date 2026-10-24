import Foundation

/// External capabilities are deliberately separate from business ToolName.
/// They are read-only unless a future capability explicitly declares a write
/// action and returns through the existing ActionCard gate.
enum AICapability: String, CaseIterable, Codable, Sendable {
    case generalAssistant
    case webSearch
    case urlReading
    case vision
    case documentUnderstanding
}

enum AICapabilityAvailability: String, Codable, Sendable {
    case live
    case foundationOnly
    case notConfigured
}

struct AICapabilityDescriptor: Codable, Equatable, Sendable {
    let capability: AICapability
    let availability: AICapabilityAvailability
    let displayName: String
}

struct AICapabilitySource: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let url: URL
}

struct AICapabilityResult: Equatable, Sendable {
    let capability: AICapability
    let text: String
    let sources: [AICapabilitySource]
    let provider: String
    let retrievedAt: Date

    init(
        capability: AICapability,
        text: String,
        sources: [AICapabilitySource] = [],
        provider: String = "local",
        retrievedAt: Date = .now
    ) {
        self.capability = capability
        self.text = text
        self.sources = sources
        self.provider = provider
        self.retrievedAt = retrievedAt
    }

    /// Markdown keeps the existing chat UI unchanged while making live
    /// sources visible and tappable in the assistant response.
    var userFacingText: String {
        guard !sources.isEmpty else { return text }
        let links = sources.map { "- [\($0.title)](\($0.url.absoluteString))" }
        return "\(text)\n\n来源（\(provider)）：\n\(links.joined(separator: "\n"))"
    }
}

enum AICapabilityError: LocalizedError, Equatable, Sendable {
    case notConfigured(AICapability)
    case invalidURL
    case invalidImage
    case invalidDocument
    case noResults
    case malformedResponse
    case networkFailure
    case timeout
    case cancelled
    case unavailable
    /// 服务端明确拒绝这次输入：多半是当前模型不支持图片/长文件。
    case unsupportedModel(AICapability)
    /// Key 无效或没有该模型权限。
    case credentialRejected
    /// 单次请求体太大（图片/文件超过 4 MB）。
    case payloadTooLarge
    case rateLimited
    case serverUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "这项外部能力尚未配置。"
        case .invalidURL: return "这个链接无法读取，请检查地址。"
        case .invalidImage: return "这张图片无法理解，请重新选择图片。"
        case .invalidDocument: return "这个文件无法读取，请选择有效的文档。"
        case .noResults: return "没有找到相关结果。"
        case .malformedResponse: return "外部服务返回了无法识别的结果。"
        case .networkFailure: return "联网服务暂时不可用，请稍后重试。"
        case .timeout: return "读取链接超时，请稍后重试。"
        case .cancelled: return "读取已取消。"
        case .unavailable: return "暂时无法读取这个链接，请稍后重试。"
        case let .unsupportedModel(capability):
            switch capability {
            case .vision:
                return "当前模型不支持图片理解，请到「AI 设置」换一个支持图片输入的模型。"
            case .documentUnderstanding:
                return "当前模型无法处理这个文件，请换一个上下文更长的模型再试。"
            default:
                return "当前模型不支持这项输入，请到「AI 设置」更换模型。"
            }
        case .credentialRejected: return "API Key 无效或没有该模型权限，请到「AI 设置」重新填写。"
        case .payloadTooLarge: return "图片或文件太大，请压缩后再试（单次上限 4 MB）。"
        case .rateLimited: return "请求太频繁，请等几秒再试。"
        case .serverUnavailable: return "AI 服务暂时不可用，请稍后重试。"
        }
    }
}

/// The registry is intentionally declarative. Provider credentials and
/// network clients are injected by the integration layer, never stored here.
struct AICapabilityRegistry: Sendable {
    let descriptors: [AICapabilityDescriptor]

    static let foundation = AICapabilityRegistry(descriptors: [
        .init(capability: .generalAssistant, availability: .live, displayName: "普通问答"),
        .init(capability: .webSearch, availability: .notConfigured, displayName: "联网搜索"),
        .init(capability: .urlReading, availability: .live, displayName: "网页阅读"),
        .init(capability: .vision, availability: .foundationOnly, displayName: "图片理解"),
        .init(capability: .documentUnderstanding, availability: .foundationOnly, displayName: "文件理解")
    ])
}

struct AICapabilityRequest: Sendable, Equatable {
    let capability: AICapability
    let input: String
}
