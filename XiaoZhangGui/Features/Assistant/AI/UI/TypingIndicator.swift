import SwiftUI
import ThinkingOrbsKit

// MARK: - 小掌柜「正在思考」指示（V3.7.1）
//
// 由真实 AI 请求状态驱动，而非独立循环动画：
// AIChatView 仅在 `model.isProcessing` 为真时展示本视图，而该标志由
// AIConversationViewModel 在请求真正开始（send / analyzeImage / analyzeDocument）
// 时置位，并在「返回结果 / 失败 / 清空对话（取消）」后立即归位——
// 视图随之从层级中移除，不存在脱离请求的常驻转动。
//
// Light/Dark：ThinkingOrb 的 `.auto` 主题跟随 colorScheme。
// Reduce Motion：显式传入 paused，且 ThinkingOrb 自身也会在 Reduce Motion 下
//   渲染确定性静态帧（其内部判定为 `reduceMotion || paused`）。
// VoiceOver：整块合并为一个元素，朗读「小掌柜 + 当前处理文案」。

struct TypingIndicator: View {
    var label = "正在思考"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ThinkingOrb(
            state: .composing,
            size: .px20,
            theme: .auto,
            paused: reduceMotion,
                displaySize: 24
            )
            Text(label)
                .font(.caption)
                .foregroundStyle(V371.Colors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(V371.Colors.group)
                .overlay(Capsule().strokeBorder(V371.Colors.divider, lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("小掌柜\(label)")
        .accessibilityIdentifier("ai.typing")
    }
}
