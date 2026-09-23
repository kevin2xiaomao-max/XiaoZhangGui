import SwiftUI

// MARK: - 小掌柜输入栏（文字 + 麦克风 + 发送 · V3.7.1）
//
// §10.2：input bar 紧凑、keyboard-safe。S3 overlay 样式（§3.2 允许 AI command
// 用 material）；Reduce Transparency 下退化为 solid group 面。

struct ChatInputBar: View {
    @Binding var text: String
    let voiceAvailable: Bool
    let isProcessing: Bool
    let onSend: () -> Void
    let onVoice: () -> Void
    let onPhoto: () -> Void
    let onFile: () -> Void

    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button(action: onPhoto) { Label("选择图片", systemImage: "photo") }
                Button(action: onFile) { Label("选择文件", systemImage: "doc") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(V371.Colors.blue)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("添加图片或文件")
            .disabled(isProcessing)

            Button(action: onVoice) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(voiceAvailable ? V371.Colors.blue : V371.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(V371.Colors.tinted(V371.Colors.blue)))
            }
            .buttonStyle(.plain)
            .disabled(!voiceAvailable)
            .accessibilityLabel("语音输入")

            TextField("问小掌柜…（如：今天美团680）", text: $text, axis: .vertical)
                .focused($focused)
                .lineLimit(1...4)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: V371.Radius.tile, style: .continuous)
                        .fill(V371.Colors.group)
                        .overlay(
                            RoundedRectangle(cornerRadius: V371.Radius.tile, style: .continuous)
                                .strokeBorder(focused ? V371.Colors.blue.opacity(0.5) : V371.Colors.divider, lineWidth: 1)
                        )
                )
                .onSubmit(sendAndDismiss)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完成") { focused = false }
                    }
                }
                .animation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion)), value: focused)
                .accessibilityIdentifier("ai.input")

            Button(action: sendAndDismiss) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(canSend ? V371.Colors.blue : V371.Colors.gray.opacity(0.35))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("发送")
            .accessibilityIdentifier("ai.send")
        }
        .padding(.horizontal, V371.Space.page)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(composerBackground)
    }

    /// S3 overlay：允许 material；Reduce Transparency 下用 solid group。
    private var composerBackground: some View {
        Group {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                    .fill(V371.Colors.group)
            } else {
                RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .shadow(color: V371.Shadow.floating.color, radius: V371.Shadow.floating.radius,
                y: V371.Shadow.floating.y)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    private func sendAndDismiss() {
        Haptic.light()
        onSend()
        focused = false
    }
}
