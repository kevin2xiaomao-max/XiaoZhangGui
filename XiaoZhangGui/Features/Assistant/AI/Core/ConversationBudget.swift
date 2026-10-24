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
