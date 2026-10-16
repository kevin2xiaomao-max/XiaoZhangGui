import SwiftUI

/// V3.8 重建 · Home 生产级玻璃表面。
///
/// 三档渲染（与 PoC `V38MotionLabSurface` 同语义，生产路径无 QA 覆盖）：
/// - Reduce Transparency 开启 → 不透明背景，保证内容可读
/// - iOS 26+ → `glassEffect(.regular)`
/// - iOS 18–25 → `.ultraThinMaterial` 回退
///
/// 仅用于 AI 入口、快捷操作等瞬态控件，不用于业务内容区与 Revenue Hero。
struct V38HomeGlassSurface<Content: View>: View {
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
