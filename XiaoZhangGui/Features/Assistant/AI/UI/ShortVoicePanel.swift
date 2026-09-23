import SwiftUI

// MARK: - 小掌柜短语音面板（单事项；复用 SpeechService · V3.7.1）
//
// Foundation 只做入口与链路：聆听 → final transcript → 与文字相同的 Agent 流程。
// 失败保留原文，可一键填入输入框改写重发。不做长语音 / 多段合并（V3.4）。
// V371：底部 sheet 式 solid group 面，轻量 waveform/状态 + 转写 + 操作。

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
        .padding(.horizontal, V371.Space.page)
        .padding(.top, 22)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: V371.Radius.group, bottomLeading: 0,
                                   bottomTrailing: 0, topTrailing: V371.Radius.group),
                style: .continuous
            )
            .fill(V371.Colors.group)
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: V371.Radius.group, bottomLeading: 0,
                                       bottomTrailing: 0, topTrailing: V371.Radius.group),
                    style: .continuous
                )
                .strokeBorder(V371.Colors.divider, lineWidth: 1)
            )
        )
        .shadow(color: V371.Shadow.floating.color, radius: V371.Shadow.floating.radius,
                y: -V371.Shadow.floating.y)
    }

    private var listeningContent: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(V371.Colors.tinted(V371.Colors.blue))
                    .frame(width: 84, height: 84)
                    .scaleEffect(reduceMotion ? 1 : (pulsing ? 1.12 : 0.94))
                    .opacity(reduceMotion ? 1 : (pulsing ? 0.55 : 1))
                    .animation(
                        reduceMotion ? nil : V32Motion.softSpring.repeatForever(autoreverses: true),
                        value: pulsing
                    )
                Image(systemName: phase == .finalizing ? "sparkles" : "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(V371.Colors.blue)
            }
            .frame(height: 92)

            Text(displayTranscript.isEmpty ? "正在听…说一件事，例如：今晚8点给302送两箱怡宝" : displayTranscript)
                .font(.body)
                .foregroundStyle(displayTranscript.isEmpty ? V371.Colors.textTertiary : V371.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 8)

            Text(phase == .finalizing ? QuickCaptureSemantic.processing : "停顿后会自动识别，也可手动停止")
                .font(.caption)
                .foregroundStyle(V371.Colors.textTertiary)

            HStack(spacing: 14) {
                Button {
                    Haptic.light()
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(V371.Colors.textSecondary)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(V371.Colors.groupSecondary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消语音")

                Button {
                    Haptic.medium()
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(V371.Colors.blue))
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(V371.Colors.orange)
                .frame(width: 56, height: 56)
                .background(V371.Colors.tinted(V371.Colors.orange), in: Circle())
                .accessibilityHidden(true)
            Text("\(QuickCaptureSemantic.failed)：\(message)")
                .font(.subheadline)
                .foregroundStyle(V371.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if !liveTranscript.isEmpty {
                Text("已保留：\(liveTranscript)")
                    .font(.caption)
                    .foregroundStyle(V371.Colors.textTertiary)
                    .lineLimit(2)
            }
            HStack(spacing: 10) {
                Button {
                    Haptic.light()
                    onEditText()
                } label: {
                    Label("填入文字", systemImage: "keyboard")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(V371.Colors.blue)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .fill(V371.Colors.tinted(V371.Colors.blue))
                        )
                }
                .buttonStyle(.plain)
                Button {
                    Haptic.light()
                    onCancel()
                } label: {
                    Label("关闭", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(V371.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .fill(V371.Colors.groupSecondary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var displayTranscript: String {
        liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
