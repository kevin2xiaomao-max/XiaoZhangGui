import SwiftUI

// MARK: - 小掌柜短语音面板（单事项；复用 SpeechService）
//
// Foundation 只做入口与链路：聆听 → final transcript → 与文字相同的 Agent 流程。
// 失败保留原文，可一键填入输入框改写重发。不做长语音 / 多段合并（V3.4）。

struct ShortVoicePanel: View {
    let phase: ShortVoicePhase
    let liveTranscript: String
    let onStop: () -> Void
    let onCancel: () -> Void
    let onEditText: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 16) {
            switch phase {
            case .failed(let message):
                failureContent(message)
            case .idle, .listening, .finalizing:
                listeningContent
            }
        }
        .padding(.horizontal, V32Layout.pageMargin)
        .padding(.top, 22)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 26, bottomLeading: 0, bottomTrailing: 0, topTrailing: 26),
                style: .continuous
            )
            .fill(V32.card)
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 26, bottomLeading: 0, bottomTrailing: 0, topTrailing: 26),
                    style: .continuous
                )
                .strokeBorder(V32.cardOutline, lineWidth: 1)
            )
        )
    }

    private var listeningContent: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(V32.brandSoft)
                    .frame(width: 88, height: 88)
                    .scaleEffect(reduceMotion ? 1 : (pulsing ? 1.12 : 0.94))
                    .opacity(reduceMotion ? 1 : (pulsing ? 0.55 : 1))
                    .animation(
                        reduceMotion ? nil : V32Motion.softSpring.repeatForever(autoreverses: true),
                        value: pulsing
                    )
                Image(systemName: phase == .finalizing ? "sparkles" : "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(V32.brand)
            }
            .frame(height: 96)

            Text(displayTranscript.isEmpty ? "正在听…说一件事，例如：今晚8点给302送两箱怡宝" : displayTranscript)
                .v32Text(.body)
                .foregroundStyle(displayTranscript.isEmpty ? V32.textTertiary : V32.textPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 8)

            Text(phase == .finalizing ? QuickCaptureSemantic.processing : "停顿后会自动识别，也可手动停止")
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)

            HStack(spacing: 14) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(V32.textSecondary)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(V32.neutralSoft))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消语音")

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(V32.brand))
                }
                .buttonStyle(.plain)
                .disabled(phase == .finalizing)
                .opacity(phase == .finalizing ? 0.6 : 1)
                .accessibilityLabel("停止并识别")
            }
        }
        .onAppear { if !reduceMotion { pulsing = true } }
    }

    private func failureContent(_ message: String) -> some View {
        VStack(spacing: 14) {
            V32IconBubble(systemName: "exclamationmark.triangle.fill", tone: .amber, size: 56, icon: 24, circular: true)
            Text("\(QuickCaptureSemantic.failed)：\(message)")
                .v32Text(.subhead)
                .foregroundStyle(V32.textSecondary)
                .multilineTextAlignment(.center)
            if !liveTranscript.isEmpty {
                Text("已保留：\(liveTranscript)")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                    .lineLimit(2)
            }
            HStack(spacing: 10) {
                V32SecondaryButton(title: "填入文字", systemName: "keyboard") { onEditText() }
                V32SecondaryButton(title: "关闭", systemName: "xmark") { onCancel() }
            }
        }
    }

    private var displayTranscript: String {
        liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
