import SwiftUI

/// V4 语音视觉。只呈现真实阶段，不计时、不循环、不触发录音或保存。
struct V400VoiceOrb: View {
    var size: CGFloat = 88
    var isListening = false
    var isProcessing = false

    var body: some View {
        ZStack {
            ForEach([1.2, 1.62, 2.1], id: \.self) { scale in
                Circle()
                    .strokeBorder(V400Tokens.brandGreen.opacity(0.35), lineWidth: 1)
                    .frame(width: size * scale, height: size * scale)
            }
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(red: 63 / 255, green: 201 / 255, blue: 138 / 255), location: 0),
                        .init(color: V400Tokens.brandGreen, location: 0.52),
                        .init(color: V400Tokens.primaryButton, location: 1)
                    ],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: 0,
                    endRadius: size
                ))
                .frame(width: size, height: size)
            Image(systemName: isProcessing ? "sparkles" : "mic.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
            if isListening {
                Circle()
                    .strokeBorder(V400Tokens.greenInk, lineWidth: 2)
                    .frame(width: size + 12, height: size + 12)
            }
        }
        .frame(width: size * 2.1, height: size * 2.1)
        .accessibilityHidden(true)
    }
}
