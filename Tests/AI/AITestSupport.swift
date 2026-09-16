import Foundation
import XCTest
@testable import XiaoZhangGui

// MARK: - AI 测试支持件（成功态 Mock 执行器只允许存在于测试 target）

/// 按队列返回结果的脚本 Provider（用于 fallback / 失败链测试）
actor ScriptedAIProvider: AIProvider {
    nonisolated let id: String
    private var queue: [Result<ProviderTurn, Error>]
    private(set) var callCount = 0

    init(id: String = "scripted", _ results: [Result<ProviderTurn, Error>]) {
        self.id = id
        self.queue = results
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        let index = min(callCount, queue.count - 1)
        callCount += 1
        switch queue[index] {
        case .success(let turn): return turn
        case .failure(let error): throw error
        }
    }
}

/// 测试专用：记录调用并返回成功（App target 内不存在此类，Release 无法假成功）
actor SuccessToolExecutor: ToolExecuting {
    private(set) var executed: [ToolCall] = []

    func execute(_ call: ToolCall) async -> ToolExecutionResult {
        executed.append(call)
        return .executed(recordID: "rec-\(call.id)", summary: "测试已记录")
    }
}

enum AITestFactory {
    /// 装配一套全内存、全 Mock 的 Foundation 预览 Agent
    @MainActor
    static func preview(
        provider: (any AIProvider)? = nil
    ) -> (agent: AgentCore, journal: InMemoryExecutionJournal, pending: InMemoryPendingActionStore,
          conversation: InMemoryConversationStore) {
        let journal = InMemoryExecutionJournal()
        let pending = InMemoryPendingActionStore()
        let conversation = InMemoryConversationStore()
        let chain = provider ?? ProviderChain(
            primary: MockAIProvider(id: "mock-primary"),
            fallback: MockAIProvider(id: "mock-fallback")
        )
        let env = AgentEnvironment(
            provider: chain,
            intentRouter: IntentRouter(),
            modelRouter: FreeFirstModelRouter(),
            contextProvider: UnavailableBusinessContextProvider(),
            redactor: ContextRedactor(),
            toolExecutor: PreviewToolExecutor(),
            journal: journal,
            conversation: conversation,
            pending: pending,
            gate: .preview,
            tier: .freeFirst
        )
        return (AgentCore(env), journal, pending, conversation)
    }

    static func makeToolCall(_ arguments: ToolArguments) -> ToolCall {
        ToolCall(id: ToolCall.makeID(), name: arguments.toolName, arguments: arguments)
    }
}
