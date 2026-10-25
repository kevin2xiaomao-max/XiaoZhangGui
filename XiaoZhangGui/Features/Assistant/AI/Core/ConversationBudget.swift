import Foundation

// MARK: - V3.9.2 · 会话上下文预算
//
// 之前 remoteTurn 把整段会话（含全部历史轮次）原样上送模型：
// 轮次越多 Token 成本越高，早年无关话术还会稀释当前意图。
// 这里按「最近 N 条 + 必须从用户发言起手 + 丢掉失败回执」做确定性裁剪，
// 纯函数、零依赖、可单测（AI 层不 import SwiftData）。

enum ConversationBudget {
    /// 单轮上送的最大消息条数（一条用户 + 一条助手 = 2 条）。
    static let maxMessages = 16

    /// 单次回复的 completion 上限，防止话痨式输出拉高成本。
    static let maxCompletionTokens = 2048

    /// V3.9.3 · 本地估算输入预算（token 数为估算，非服务商限额、非计费口径）。
    /// 估算规则（文档化、可复现）：ASCII 字符约 0.25 token，非 ASCII 字符约 1 token；
    /// 中文按字计，精度有限，仅作成本护栏参考，绝不冒充真实 token 计数。
    static let maxEstimatedInputTokens = 8000

    /// 估算一批消息的输入 token 数（见上：启发式估算，非真实计量）。
    static func estimatedInputTokens(for messages: [AIMessage]) -> Int {
        var total = 0.0
        for message in messages {
            for scalar in message.content.unicodeScalars {
                total += scalar.isASCII ? 0.25 : 1.0
            }
        }
        return Int(total.rounded(.up))
    }

    /// 在 16 条截断之上再做输入预算裁剪，且绝不丢：
    /// - 最后一条用户发言（当前意图）；
    /// - 挂着待确认卡的消息（待确认操作）；
    /// - 最近 2 条消息。
    /// 实在超限且只剩受保护消息时，对最长消息做尾部截断并标注（不静默丢内容）。
    static func trimmedForInputBudget(
        _ messages: [AIMessage],
        maxTokens: Int = ConversationBudget.maxEstimatedInputTokens
    ) -> [AIMessage] {
        var result = trimmed(messages)
        guard estimatedInputTokens(for: result) > maxTokens else { return result }
        // 以消息 ID 锚定最后一条用户发言（裁剪删除会移动下标，绝不能用旧下标保护）。
        let lastUserID = result.last(where: { $0.role == .user })?.id
        func isProtected(_ index: Int, in list: [AIMessage]) -> Bool {
            let message = list[index]
            if message.id == lastUserID { return true }
            if index >= list.count - 2 { return true }
            return message.proposalID != nil || !message.compositeProposalIDs.isEmpty
        }
        var guardIterations = 0
        while estimatedInputTokens(for: result) > maxTokens, guardIterations < 100 {
            guardIterations += 1
            if let dropIndex = result.indices.first(where: { !isProtected($0, in: result) }) {
                result.remove(at: dropIndex)
                continue
            }
            // 只剩受保护消息：截断最长一条（优先不动最后一条用户发言）。
            let candidates = result.indices.filter { result[$0].id != lastUserID }
            guard let longest = (candidates.isEmpty ? result.indices : candidates)
                .max(by: { result[$0].content.count < result[$1].content.count }) else { break }
            var message = result[longest]
            let keep = max(message.content.count / 2, 1)
            message.content = String(message.content.prefix(keep)) + "…（已按输入预算截断）"
            result[longest] = message
            // 截断一次仍超限时继续循环会再次减半；100 次护栏内必然收敛。
            if message.content.count <= 1 { break }
        }
        return result
    }

    /// 裁剪会话：保留尾部窗口，窗口必须从用户发言开始，失败回执不进上下文。
    static func trimmed(_ messages: [AIMessage], maxMessages: Int = ConversationBudget.maxMessages) -> [AIMessage] {
        guard maxMessages > 0 else { return [] }
        // 失败回执（红色错误气泡）是本地 UI 文案，不是对话内容，喂回模型只会干扰。
        let usable = messages.filter { !($0.role == .assistant && $0.isError) }
        guard usable.count > maxMessages else { return usable }
        let window = Array(usable.suffix(maxMessages))
        // 窗口若以助手发言起手，模型会看到「无来由的回答」：从第一条用户发言重新截。
        guard let firstUser = window.firstIndex(where: { $0.role == .user }) else { return window }
        return Array(window[firstUser...])
    }
}
