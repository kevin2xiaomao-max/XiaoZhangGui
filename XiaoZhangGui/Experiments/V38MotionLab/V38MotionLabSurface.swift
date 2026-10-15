import SwiftUI
import UIKit

/// Transient controls only. Never apply this to business content or Revenue Hero.
/// When glass isn't available or transparency is reduced, the hit geometry remains identical.
struct V38MotionLabSurface<Content: View>: View {
    let radius: CGFloat
    let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
