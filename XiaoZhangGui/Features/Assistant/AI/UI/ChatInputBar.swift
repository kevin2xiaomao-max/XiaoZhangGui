import SwiftUI

// MARK: - 小掌柜输入栏（文字 + 麦克风 + 发送）

struct ChatInputBar: View {
    @Binding var text: String
    let voiceAvailable: Bool
    let isProcessing: Bool
    let onSend: () -> Void
    let onVoice: () -> Void

    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onVoice) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(voiceAvailable ? V32.brand : V32.textTertiary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(V32.brandSoft))
            }
            .buttonStyle(V32PressButtonStyle())
            .disabled(!voiceAvailable)
            .accessibilityLabel("语音输入")

            TextField("问小掌柜…（如：今天美团680）", text: $text, axis: .vertical)
                .focused($focused)
                .lineLimit(1...4)
                .v32Text(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(V32.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(focused ? V32.brand.opacity(0.5) : V32.cardOutline, lineWidth: 1)
                        )
                )
                .onSubmit(onSend)
                .animation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion)), value: focused)
                .accessibilityIdentifier("ai.input")

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(canSend ? V32.brand : V32.textTertiary.opacity(0.35))
                    )
            }
            .buttonStyle(V32PressButtonStyle())
            .disabled(!canSend)
            .accessibilityLabel("发送")
            .accessibilityIdentifier("ai.send")
        }
        .padding(.horizontal, V32Layout.pageMargin)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .modifier(ComposerControlSurface(reduceTransparency: reduceTransparency))
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }
}

private struct ComposerControlSurface: ViewModifier {
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content.background(reduceTransparency ? AnyShapeStyle(V32.card) : AnyShapeStyle(.ultraThinMaterial))
        }
    }
}
