import SwiftUI

// MARK: - 小掌柜「正在输入」指示（克制动画，Reduce Motion 下静止）

struct TypingIndicator: View {
    var label = "正在思考"
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
        .modifier(ThinkingSurface(reduceTransparency: false))
        .onAppear {
            if !reduceMotion {
                animating = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("小掌柜\(label)")
    }
}

private struct ThinkingSurface: ViewModifier {
    let reduceTransparency: Bool

    @Environment(\.accessibilityReduceTransparency) private var environmentReduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let reduce = reduceTransparency || environmentReduceTransparency
        if #available(iOS 26.0, *), !reduce {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(
                Capsule()
                    .fill(V32.card)
                    .overlay(Capsule().strokeBorder(V32.cardOutline, lineWidth: 1))
            )
        }
    }
}
