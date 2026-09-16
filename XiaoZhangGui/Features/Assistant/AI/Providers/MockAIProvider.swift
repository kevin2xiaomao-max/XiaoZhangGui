import Foundation

// MARK: - V3.3 Lite · Mock Provider（Foundation 全 Mock 闭环）
//
// - 确定性、无网络、无 Key、不写库；
// - 四个 CREATE 范例句经 MockBusinessParser 产出 ToolCall，仅用于 ActionCard 预览；
// - 普通聊天返回明确标注的内置回复；
// - 仅允许在 DEBUG / 预览 / 测试，以及 Foundation 预览环境（writeGate = .preview）装配；
//   Release 的 .live 环境禁止回落到本类（见 AgentEnvironment.live 与 ProductionGuardTests）。

struct MockAIProvider: AIProvider {
    let id: String
    private let parser = MockBusinessParser()
    private let router = IntentRouter()
    /// 测试 / 故障演练：让本次 complete 抛出指定错误
    var failure: (any Error & Sendable)?
    /// 模拟思考延迟（UI Typing 状态验证用）
    var latency: TimeInterval

    init(id: String = "mock-primary", failure: (any Error & Sendable)? = nil, latency: TimeInterval = 0) {
        self.id = id
        self.failure = failure
        self.latency = latency
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        if latency > 0 {
            try? await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        }
        if let failure { throw failure }

        guard let text = request.lastUserText?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw AgentError.emptyTranscript
        }

        let intent = router.classify(text)
        if let parsed = parser.parse(text, intent: intent) {
            switch parsed {
            case .tool(let arguments):
                let call = ToolCall(id: ToolCall.makeID(), name: arguments.toolName, arguments: arguments)
                return .toolCall(call)
            case .clarify(let message):
                return .text(message)
            }
        }

        // 普通聊天：明确标注为内置回复，不伪装成联网 AI
        return .text(Self.cannedReply(for: text))
    }

    static func cannedReply(for text: String) -> String {
        "（预览版内置回复）我收到了：「\(text)」。\nFoundation 阶段我能把营业款、待办、备忘、配送整理成确认卡；正式版会接入免费优先的 AI，也能回答日常问题。"
    }
}
