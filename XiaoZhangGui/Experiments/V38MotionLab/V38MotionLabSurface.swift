import SwiftUI
import UIKit

/// Transient controls only. Never apply this to business content or Revenue Hero.
/// When glass isn't available or transparency is reduced, the hit geometry remains identical.
struct V38MotionLabSurface<Content: View>: View {
    let radius: CGFloat
    let content: Content
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.v38qaReduceTransparencyOverride) private var qaReduceTransparencyOverride
    /// E·QA：CI 用 `--v38-reduce-transparency` 覆盖时取覆盖值，否则取系统真实值。
    private var reduceTransparency: Bool { qaReduceTransparencyOverride ?? systemReduceTransparency }

    init(radius: CGFloat = 26, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if reduceTransparency {
            content
                .background(Color(uiColor: .secondarySystemBackground), in: shape)
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1))
        }
    }
}
