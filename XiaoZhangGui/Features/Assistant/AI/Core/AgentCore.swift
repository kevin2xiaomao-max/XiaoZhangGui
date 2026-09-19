import Foundation

// MARK: - V3.3 Lite · AgentCore（薄层编排）
//
// 职责（且仅这些）：
// 用户输入 → 意图分类 → 最小上下文（脱敏）→ 模型路由 → Provider →
//   文本回复 或 单个 ToolCall → 参数 / 权限 / 幂等校验 → ActionCard（CREATE 必确认）
// AgentCore 不 import SwiftData、不持有 Repository；执行只经 ToolExecuting。
// F0 已放弃 Fathom：Lite 是单意图 / 单卡确认，不需要多步 Orchestrator（留 V3.4）。

/// 写闸门：preview = Foundation 只预览；live = FINAL 经 ToolRouter 真实落库。
enum WriteGate: Sendable {
    case preview
    case live
}

struct AgentTurnResult: Sendable {
    let userMessage: AIMessage
    let assistantMessage: AIMessage?
    let proposal: ActionProposal?
}

/// 依赖装配。所有第三方能力都藏在 AIProvider 背后。
struct AgentEnvironment: Sendable {
    let provider: any AIProvider
    let intentRouter: IntentRouter
    let modelRouter: any ModelRouting
    let contextProvider: any BusinessContextProviding
    let redactor: ContextRedactor
    let toolExecutor: any ToolExecuting
    let journal: any ExecutionJournaling
    let conversation: any ConversationStoring
    let pending: any PendingActionStoring
    let gate: WriteGate
    let tier: ModelTier

    // MARK: Foundation 预览装配（全 Mock + 预览执行器，不写业务库）

    static func foundationPreview(
        conversation: any ConversationStoring = FileConversationStore(),
        pending: any PendingActionStoring = FilePendingActionStore(),
        journal: any ExecutionJournaling = FileExecutionJournal()
    ) -> AgentEnvironment {
        AgentEnvironment(
            provider: ProviderChain(
                primary: MockAIProvider(id: "mock-primary"),
                fallback: MockAIProvider(id: "mock-fallback")
            ),
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
    }

    // MARK: FINAL 正式装配（失败闭合：缺真实依赖 / 误塞 Mock 都拒绝创建）

    static func makeLive(
        provider: any AIProvider,
        fallback: (any AIProvider)?,
        contextProvider: any BusinessContextProviding,
        toolExecutor: any ToolExecuting,
        conversation: any ConversationStoring,
        pending: any PendingActionStoring,
        journal: any ExecutionJournaling,
        modelRouter: any ModelRouting = FreeFirstModelRouter(),
        tier: ModelTier = .freeFirst
    ) throws -> AgentEnvironment {
        // Release 红线：live 环境绝不允许 Mock 假装成功
        if provider is MockAIProvider || fallback is MockAIProvider {
            throw AgentError.notConfigured
        }
        if toolExecutor is PreviewToolExecutor {
            throw AgentError.notConfigured
        }
        return AgentEnvironment(
            provider: ProviderChain(primary: provider, fallback: fallback),
            intentRouter: IntentRouter(),
            modelRouter: modelRouter,
            contextProvider: contextProvider,
            redactor: ContextRedactor(),
            toolExecutor: toolExecutor,
            journal: journal,
            conversation: conversation,
            pending: pending,
            gate: .live,
            tier: tier
        )
    }
}

@MainActor
final class AgentCore {
    private let env: AgentEnvironment
    private let toolDefinitions = ToolCatalog.definitions()
    /// Free First 第一道：高置信本地规则直接出卡 / 追问（0 Token）
    private let localParser = LocalBusinessParser()

    init(_ env: AgentEnvironment) {
        self.env = env
    }

    // MARK: 读

    func messages() async -> [AIMessage] {
        await env.conversation.load().messages
    }

    func pendingProposals() async -> [ActionProposal] {
        await env.pending.pending()
    }

    // MARK: 一轮对话

    func send(_ raw: String) async -> AgentTurnResult {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = AIMessage(role: .user, content: text)
        // 1) 用户原文先持久化（失败也不丢话）
        await env.conversation.append(userMessage)

        guard !text.isEmpty else {
            return AgentTurnResult(userMessage: userMessage, assistantMessage: nil, proposal: nil)
        }

        do {
            return try await runTurn(text: text, userMessage: userMessage)
        } catch {
            // 2) 失败：保留原文，追加可见的错误回复，提供重试，不脑补。
            // ProviderFailure / URLError 等经统一映射成明确中文
            // （API Key 无效 / 余额不足 / 超时 / 没有网络…），不显示原始错误描述。
            let content: String = {
                if let agentError = error as? AgentError {
                    return agentError.errorDescription ?? "处理失败，请重试（你刚说的话已保留）"
                }
                return UserFacingAIError.message(for: error)
            }()
            let errorMessage = AIMessage(
                role: .assistant,
                content: content,
                isError: true
            )
            await env.conversation.append(errorMessage)
            return AgentTurnResult(userMessage: userMessage, assistantMessage: errorMessage, proposal: nil)
        }
    }

    private func runTurn(text: String, userMessage: AIMessage) async throws -> AgentTurnResult {
        let intent = env.intentRouter.classify(text)

        switch intent {
        case .businessAction:
            // Free First：本地高置信规则 0 Token 直接出卡 / 追问；
            // 本地无把握（返回 nil）才允许上云。
            if let local = localParser.parse(text, intent: intent) {
                switch local {
                case .tool(let arguments):
                    let call = ToolCall(id: ToolCall.makeID(), name: arguments.toolName, arguments: arguments)
                    return try await handleToolCall(call, userMessage: userMessage)
                case .clarify(let reply):
                    return try await appendAssistant(reply, userMessage: userMessage)
                }
            }
            return try await remoteTurn(intent: intent, userMessage: userMessage)

        case .businessQuery(let kind):
            // Lite：四类 READ 全部本地聚合回答（0 Token，数据不出设备）。
            // 预览环境未接业务库，保留 Foundation 的固定说明。
            if env.gate == .preview {
                return try await appendAssistant(
                    "预览版还没有接入你的经营数据；正式版可以在这里查询今日营业额、待办、临期商品和配送。",
                    userMessage: userMessage)
            }
            let scoped = await env.contextProvider.scopedContext(for: [kind])
            return try await appendAssistant(
                BusinessAnswerComposer.answer(for: kind, context: scoped),
                userMessage: userMessage)

        case .worldChat, .localZeroToken:
            return try await remoteTurn(intent: intent, userMessage: userMessage)
        }
    }

    /// 上云一轮：仅在本地无把握（CREATE）或普通聊天时调用。
    /// Lite 不把经营数据随云端 CREATE / 聊天外发（READ 已本地回答），context 恒空。
    private func remoteTurn(intent: IntentKind, userMessage: AIMessage) async throws -> AgentTurnResult {
        let task: ModelTask = {
            switch intent {
            case .businessAction: return .toolCall
            case .businessQuery: return .businessAnswer
            case .localZeroToken: return .simpleExtraction
            case .worldChat: return .chat
            }
        }()
        let route = env.modelRouter.route(task: task, intent: intent, tier: env.tier)
        let history = await env.conversation.load().messages
        let request = ProviderRequest(messages: history, tools: toolDefinitions, route: route, context: .empty)

        let turn: ProviderTurn
        do {
            turn = try await env.provider.complete(request)
        } catch let agentError as AgentError {
            // notConfigured 等 AgentError 原样上抛，保留 fail-closed 语义与文案
            throw agentError
        } catch {
            // ProviderFailure / URLError 保留类型化错误直接上抛：
            // 由 send() 经 UserFacingAIError 统一映射成中文，
            // 不再压成 generic localizedDescription。
            throw error
        }

        switch turn {
        case .text(let reply):
            return try await appendAssistant(reply, userMessage: userMessage)
        case .toolCall(let call):
            return try await handleToolCall(call, userMessage: userMessage)
        }
    }

    private func appendAssistant(_ content: String, userMessage: AIMessage, isError: Bool = false)
        async throws -> AgentTurnResult {
        let message = AIMessage(role: .assistant, content: content, isError: isError)
        await env.conversation.append(message)
        return AgentTurnResult(userMessage: userMessage, assistantMessage: message, proposal: nil)
    }

    private func handleToolCall(_ call: ToolCall, userMessage: AIMessage) async throws -> AgentTurnResult {
        guard ToolCatalog.isRegistered(call.name) else {
            throw AgentError.unsupportedTool(call.name.rawValue)
        }
        // READ：权限允许自动执行，但结果只在本机聚合回答（0 Token、不出设备）。
        if call.name == .searchRecords {
            if env.gate == .preview {
                return try await appendAssistant(
                    "预览版还没有接入经营数据；正式版可以在这里查询今日营业额、待办、临期商品和配送。",
                    userMessage: userMessage)
            }
            let kinds: [BusinessRecordKind] = {
                if case .searchRecords(let args) = call.arguments, !args.kinds.isEmpty {
                    return args.kinds
                }
                return [.revenueToday, .todoToday, .recentMemo, .expiringGoods, .delivery]
            }()
            let scoped = await env.contextProvider.scopedContext(for: kinds)
            return try await appendAssistant(
                BusinessAnswerComposer.answer(for: kinds, context: scoped),
                userMessage: userMessage)
        }

        let validationErrors = ToolArgumentValidator.validate(call)
        guard validationErrors.isEmpty else {
            let message = AIMessage(
                role: .assistant,
                content: "信息还不完整：\(validationErrors.joined(separator: "、"))。你可以补充后再发一次。",
                isError: true)
            await env.conversation.append(message)
            return AgentTurnResult(userMessage: userMessage, assistantMessage: message, proposal: nil)
        }

        let fingerprint = ToolIdempotency.fingerprint(for: call)
        if await env.journal.isFingerprintUsed(fingerprint) {
            let message = AIMessage(role: .assistant, content: "这条记录已经处理过，不会重复保存。")
            await env.conversation.append(message)
            return AgentTurnResult(userMessage: userMessage, assistantMessage: message, proposal: nil)
        }

        let proposal = ActionProposal(call: call, isPreviewOnly: env.gate == .preview)
        await env.pending.upsert(proposal)
        await env.journal.append(JournalEntry(
            toolCallID: call.id, fingerprint: fingerprint, toolName: call.name.rawValue,
            status: ProposalStatus.pending.rawValue, recordID: nil, createdAt: .now))

        let lead = proposal.isPreviewOnly
            ? "准备记录（预览版不会真实保存）："
            : "准备记录，请确认："
        let message = AIMessage(role: .assistant, content: lead, proposalID: proposal.id)
        await env.conversation.append(message)
        return AgentTurnResult(userMessage: userMessage, assistantMessage: message, proposal: proposal)
    }

    // MARK: 清空对话

    /// 清空当前聊天：消息 + 未确认 ActionCard 全部清除并持久化，重启后仍为空。
    /// 刻意不清 ExecutionJournal：已真实写入业务库的数据与幂等防重记录绝不受影响。
    func clearConversation() async {
        await env.conversation.clearConversation()
        await env.pending.clear()
    }

    // MARK: ActionCard 操作

    /// 用户点「确认记录」。Foundation：只标记预览已确认，绝不写库。
    @discardableResult
    func confirm(proposalID: UUID) async -> ActionProposal? {
        guard var proposal = await env.pending.proposal(id: proposalID),
              proposal.status == .pending else { return nil }

        if env.gate == .preview {
            proposal.previewAcknowledged = true
            proposal.resultText = "预览版不会真实保存；正式版确认后才会写入。"
            await env.pending.upsert(proposal)
            return proposal
        }

        // FINAL：真实执行（live 执行器在 Foundation 不会被装配）
        let result = await env.toolExecutor.execute(proposal.call)
        switch result {
        case .previewNotPersisted:
            proposal.status = .failed
            proposal.resultText = "执行器未正确配置"
        case .executed(let recordID, let summary):
            proposal.status = .executed
            proposal.resultText = summary
            // markExecuted 为 upsert：执行器可能已写入 executed（替换 pending）；
            // 测试替身执行器未写账本时由这里兜底推进状态。
            await env.journal.markExecuted(JournalEntry(
                toolCallID: proposal.call.id,
                fingerprint: ToolIdempotency.fingerprint(for: proposal.call),
                toolName: proposal.call.name.rawValue,
                status: ProposalStatus.executed.rawValue, recordID: recordID, createdAt: .now))
        case .duplicate(let existingID):
            proposal.status = .duplicate
            proposal.resultText = "与已处理的操作 \(existingID) 重复，已跳过"
        case .failed(let reason):
            proposal.status = .failed
            proposal.resultText = reason
        }
        await env.pending.upsert(proposal)
        return proposal
    }

    /// 用户删除待确认项
    func cancel(proposalID: UUID) async {
        guard var proposal = await env.pending.proposal(id: proposalID) else { return }
        proposal.status = .cancelled
        await env.pending.upsert(proposal)
    }

    /// 用户点「修改」：取消当前卡，返回原始用户输入以便改写重发
    func modify(proposalID: UUID) async -> String? {
        guard let proposal = await env.pending.proposal(id: proposalID) else { return nil }
        await cancel(proposalID: proposal.id)
        // 找到该卡对应的上一条用户原文
        let messages = await env.conversation.load().messages
        if let assistantIndex = messages.lastIndex(where: { $0.proposalID == proposalID }),
           assistantIndex > 0 {
            for index in stride(from: assistantIndex - 1, through: 0, by: -1) {
                if messages[index].role == .user { return messages[index].content }
            }
        }
        return nil
    }
}
