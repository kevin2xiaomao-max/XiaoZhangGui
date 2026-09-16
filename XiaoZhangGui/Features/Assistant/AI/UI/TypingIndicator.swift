import SwiftUI

// MARK: - 小掌柜「正在输入」指示（克制动画，Reduce Motion 下静止）

struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(V32.textTertiary)
                    .frame(width: 7, height: 7)
                    .opacity(animating || reduceMotion ? 1 : 0.35)
                    .scaleEffect(reduceMotion ? 1 : (animating ? 1 : 0.8))
                    .animation(
                        reduceMotion
                            ? nil
                            : V32Motion.quick.repeatForever().delay(0.12 * Double(index)),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(V32.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(V32.cardOutline, lineWidth: 1)
                )
        )
        .onAppear {
            if !reduceMotion {
                animating = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("小掌柜正在思考")
    }
}
