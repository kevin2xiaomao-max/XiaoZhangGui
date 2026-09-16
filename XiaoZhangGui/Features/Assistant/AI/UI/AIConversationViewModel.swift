import Foundation
import Observation

// MARK: - V3.3 Lite · 小掌柜聊天 ViewModel
//
// 只做 UI 状态编排：消息列表、ActionCard、输入、短语音面板。
// 业务理解 / 工具 / 存储全部在 AgentCore 与各 Service；本类不 import SwiftData。

@MainActor
@Observable
final class AIConversationViewModel {
    private(set) var messages: [AIMessage] = []
    private(set) var proposals: [UUID: ActionProposal] = [:]
    var input: String = ""
    private(set) var isProcessing = false
    private(set) var showVoicePanel = false

    let voice: ShortVoiceSession
    private let agent: AgentCore

    init(agent: AgentCore? = nil) {
        let core = agent ?? AgentCore(.foundationPreview())
        self.agent = core
        self.voice = ShortVoiceSession()
        Task { await hydrate() }
    }

    // MARK: 恢复

    func hydrate() async {
        messages = await agent.messages()
        for proposal in await agent.pendingProposals() {
            proposals[proposal.id] = proposal
        }
    }

    // MARK: 发送（文字 / 语音 final 走同一入口）

    func send(_ preset: String? = nil) {
        let content = (preset ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isProcessing else { return }
        input = ""
        isProcessing = true
        Task {
            let result = await agent.send(content)
            await refresh()
            if let proposal = result.proposal {
                proposals[proposal.id] = proposal
            }
            isProcessing = false
        }
    }

    func retryLastFailed() {
        // 找到最后一条错误回复之前的用户原文，重新发送
        guard let errorIndex = messages.lastIndex(where: { $0.isError }),
              errorIndex > 0 else { return }
        for index in stride(from: errorIndex - 1, through: 0, by: -1) {
            if messages[index].role == .user {
                send(messages[index].content)
                return
            }
        }
    }

    // MARK: ActionCard

    func confirm(_ proposalID: UUID) {
        Task {
            if let updated = await agent.confirm(proposalID: proposalID) {
                proposals[updated.id] = updated
            }
        }
    }

    func cancelCard(_ proposalID: UUID) {
        Task {
            await agent.cancel(proposalID: proposalID)
            proposals[proposalID] = nil
            await refresh()
        }
    }

    func modifyCard(_ proposalID: UUID) {
        Task {
            if let original = await agent.modify(proposalID: proposalID) {
                input = original
            }
            proposals[proposalID] = nil
            await refresh()
        }
    }

    // MARK: 短语音

    var voiceAvailable: Bool { voice.isAvailable }

    func startVoice() {
        showVoicePanel = true
        voice.start { [weak self] final in
            self?.handleVoiceFinal(final)
        }
    }

    func stopVoice() {
        voice.stop()
    }

    func cancelVoice() {
        voice.cancel()
        showVoicePanel = false
    }

    /// 语音失败后：保留原文，填回输入框，由用户改写后发送（不丢话）
    func retainVoiceTranscriptToInput() {
        let text = voice.consumeRetainedTranscript()
        voice.finish()
        showVoicePanel = false
        if !text.isEmpty { input = text }
    }

    var voicePhase: ShortVoicePhase { voice.phase }
    var liveTranscript: String { voice.liveTranscript }

    private func handleVoiceFinal(_ text: String) {
        voice.finish()
        showVoicePanel = false
        send(text)
    }

    private func refresh() async {
        messages = await agent.messages()
        for proposal in await agent.pendingProposals() {
            proposals[proposal.id] = proposal
        }
    }
}
