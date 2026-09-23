import SwiftUI

// V21Components.swift（V3.7.1）：仅保留仍被引用的 PageBackground；
// 其余 V21 旧 presentation（GlassSurface / PriorityDot / PillTabRow /
// V21FAB / EmptyStateView / BottomContentPaddingModifier）已零引用，移除。

struct PageBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Color(.systemGroupedBackground)
                    V21.background.opacity(0.55)
                }
                .ignoresSafeArea()
            }
    }
}
