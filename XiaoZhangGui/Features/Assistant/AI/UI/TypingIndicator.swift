import SwiftUI

// MARK: - 小掌柜「正在输入」指示（V3.7.1）
//
// 克制动画，Reduce Motion 下静止；内容区 solid 胶囊，不做 material。

struct TypingIndicator: View {
    var label = "正在思考"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(V371.Colors.textTertiary)
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
            Capsule()
                .fill(V371.Colors.group)
                .overlay(Capsule().strokeBorder(V371.Colors.divider, lineWidth: 1))
        )
        .onAppear {
            if !reduceMotion {
                animating = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("小掌柜\(label)")
    }
}
