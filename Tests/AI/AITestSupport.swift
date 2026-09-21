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

actor CapturingAIProvider: AIProvider {
    nonisolated let id = "capturing"
    private(set) var requests: [ProviderRequest] = []
    private let response: ProviderTurn

    init(response: ProviderTurn = .text("测试回复")) {
        self.response = response
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        requests.append(request)
        return response
    }

    func requestCount() -> Int { requests.count }
    func firstRequest() -> ProviderRequest? { requests.first }
}

/// 测试专用：记录调用并返回成功（App target 内不存在此类，Release 无法假成功）
actor SuccessToolExecutor: ToolExecuting {
    private(set) var executed: [ToolCall] = []

    func execute(_ call: ToolCall) async -> ToolExecutionResult {
        executed.append(call)
        return .executed(recordID: "rec-\(call.id)", summary: "测试已记录")
    }
}

/// 包装另一个 Provider 并计数，用于验证 Local First 是否真的 0 Token
actor CountingAIProvider: AIProvider {
    nonisolated let id: String
    private let wrapped: any AIProvider
    private(set) var callCount = 0

    init(wrapping wrapped: any AIProvider) {
        self.id = "counting-\(wrapped.id)"
        self.wrapped = wrapped
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        callCount += 1
        return try await wrapped.complete(request)
    }
}

/// 脚本化业务上下文（不碰 SwiftData，用于本地 READ 测试）
actor ScriptedBusinessContextProvider: BusinessContextProviding {
    private let context: ScopedBusinessContext
    private let pack: GroundingPack
    private(set) var requestedKinds: [[BusinessRecordKind]] = []

    init(_ context: ScopedBusinessContext, pack: GroundingPack = .empty) {
        self.context = context
        self.pack = pack
    }

    func scopedContext(for kinds: [BusinessRecordKind]) async -> ScopedBusinessContext {
        requestedKinds.append(kinds)
        guard !kinds.isEmpty else { return .empty }
        return context
    }

    func groundingPack() async -> GroundingPack { pack }
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
        // 注入自定义 Provider（故障演练）时不再挂 Mock fallback：
        // 否则 timeout 等可换链错误会被 fallback 吞掉，无法验证「失败可见、原文保留」。
        let chain: any AIProvider = provider ?? ProviderChain(
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

    /// 装配 live 闸门的内存 Agent（真实执行器 / 脚本 Provider，不碰 SwiftData）。
    /// 与 Preview 的区别：CREATE 确认后走 toolExecutor，READ 走 contextProvider 本地回答。
    @MainActor
    static func live(
        provider: any AIProvider,
        fallback: (any AIProvider)? = nil,
        contextProvider: any BusinessContextProviding = UnavailableBusinessContextProvider(),
        toolExecutor: any ToolExecuting = SuccessToolExecutor(),
        webSearchCapability: WebSearchCapability = WebSearchCapability()
    ) -> (agent: AgentCore, journal: InMemoryExecutionJournal, pending: InMemoryPendingActionStore,
          conversation: InMemoryConversationStore) {
        let journal = InMemoryExecutionJournal()
        let pending = InMemoryPendingActionStore()
        let conversation = InMemoryConversationStore()
        let env = try! AgentEnvironment.makeLive(
            provider: provider,
            fallback: fallback,
            contextProvider: contextProvider,
            toolExecutor: toolExecutor,
            conversation: conversation,
            pending: pending,
            journal: journal,
            webSearchCapability: webSearchCapability
        )
        return (AgentCore(env), journal, pending, conversation)
    }

    static func makeToolCall(_ arguments: ToolArguments) -> ToolCall {
        ToolCall(id: ToolCall.makeID(), name: arguments.toolName, arguments: arguments)
    }
}
