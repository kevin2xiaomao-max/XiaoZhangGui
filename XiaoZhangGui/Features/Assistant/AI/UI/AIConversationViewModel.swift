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
    /// 启动时为 Foundation 预览 Agent；Integration 层在 onAppear 时用 live Agent 替换。
    private(set) var agent: AgentCore
    /// 对话代数：清空对话 +1；进行中的旧请求回来时若发现代数已变，丢弃结果并再次清空。
    private var generation = 0

    /// V3.3 真机 hotfix：短语音面板展示 / 聆听期间隐藏底部导航（Dock），
    /// 面板完整使用底部安全区；取消 / 完成 / 失败关闭后恢复。
    var isBottomDockHidden: Bool { showVoicePanel }

    init(agent: AgentCore? = nil) {
        let core = agent ?? AgentCore(.foundationPreview())
        self.agent = core
        self.voice = ShortVoiceSession()
        Task { await hydrate() }
    }

    /// 由 AI 目录外的 AILiveEnvironmentModifier 注入真实 Agent（含 Repository 执行器）。
    func attach(live newAgent: AgentCore) {
        self.agent = newAgent
        Task { await hydrate() }
    }

    /// 远端 Provider 是否已保存 Key（不代表连接可用；连接状态以设置页真实测试为准）
    var isRemoteConfigured: Bool { AISettings.shared.isPrimaryKeySaved }

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
        let requestGeneration = generation
        Task {
            let result = await agent.send(content)
            guard requestGeneration == generation else {
                // 请求期间用户已清空对话：丢弃本次结果并再次清空，保证最终为空
                await agent.clearConversation()
                proposals.removeAll()
                messages = []
                isProcessing = false
                return
            }
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

    // MARK: 清空 / 新建对话

    /// Lite 只有单个会话，「新对话」与「清空当前对话」行为一致：
    /// 清空消息与未确认 ActionCard；已保存的营业额 / 待办 / 备忘 / 配送绝不删除。
    func clearConversation() {
        generation += 1
        input = ""
        isProcessing = false
        Task {
            await agent.clearConversation()
            proposals.removeAll()
            messages = []
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
